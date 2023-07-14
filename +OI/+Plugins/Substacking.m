classdef Substacking < OI.Plugins.PluginBase
    
 properties
        inputs = {OI.Data.Stacks(), ...
            OI.Data.PreprocessedFiles(), ...
            OI.Data.DEM(), ...
            OI.Data.GeocodingSummary()}
        outputs = {OI.Data.SubstackingSummary()}
        id = 'Substacking'
        referenceSegmentIndex 
        trackIndex
        blocks
        formatStr = 'sss_%i_%i'

    end
    
    methods
        function this = Substacking( varargin )
            this.isArray = true;
            this.isFinished = false;
        end    
% Different approaches:
% ideally we'd load each burst image once, and then append the data to the
% appropriate block. But then we'd be doing ~100 writes to the disk, which
% is bad for the HPC system. So we'll load the images one by one for each 
% block, and then write the data to the disk once per block. This is a lot
% slower but in fact that helps us not crash the HPC.
function this = run(this, engine, varargin)
engine.ui.log('debug','%s loading inputs\n', ...
    this.id)

cat = engine.load( OI.Data.Catalogue() );
preprocessingInfo = engine.load( OI.Data.PreprocessedFiles() );
stacks = engine.load( OI.Data.Stacks() );
projObj = engine.load( OI.Data.ProjectDefinition() );
aoi = projObj.AOI.to_area();

BLOCK_SIZE = projObj.BLOCK_SIZE; % in meters, square area.

% coregSummary = engine.load( OI.Data.CoregistrationSummary() );
if isempty(preprocessingInfo) || ...
        isempty(stacks) || ...
        isempty(cat) % ...
        % || isempty(coregSummary)
    return;
end


% what polarisations do we need?
requestedPol = {'HH','HV','VH','VV'};

if ~isempty(projObj.POLARIZATION)
    keepPol = zeros(size(requestedPol));
    ii=0;
    for POLARIZATION = requestedPol
        ii = ii+1;
        if any(strfind(projObj.POLARIZATION,POLARIZATION{1}))
            keepPol(ii) = 1;
        end
    end
    requestedPol = requestedPol(keepPol==1);
end

if isempty(this.trackIndex)
    this = this.run_first_and_last( engine, stacks, cat, preprocessingInfo, requestedPol, aoi );
    return % winner winner
end

trackInd = this.trackIndex;
refSegInd = this.referenceSegmentIndex;
engine.ui.log('info','Doing substacks/blocking for Segment %i %i\n', ...
    trackInd, refSegInd)
segProcessingStartTime = tic;

% get safe ind
safeIndex = stacks.stack(trackInd).reference.segments.safe(refSegInd);
% get swath ind
swathIndex = stacks.stack(trackInd).reference.segments.swath(refSegInd);

% get metadata
safe = cat.safes{safeIndex};
swathInfo = ...
    preprocessingInfo.metadata( safeIndex ).swath( swathIndex );
% get the dimensions of the stack
[lpb,spb] = ...
    OI.Plugins.Geocoding.get_parameters( swathInfo );
sz = [lpb, spb, numel(stacks.stack(trackInd).correspondence(refSegInd,:))];


% get lat lon
geocodingData = OI.Data.LatLonEleForImage();
geocodingData.STACK = num2str(trackInd);
geocodingData.SEGMENT_INDEX = num2str(refSegInd);
geocodingData.identify(engine);
lle = engine.load( geocodingData );

if isempty(lle)
    engine.ui.log('info','Segment not geocoded %i %i\n',trackInd, refSegInd)
    return % segment not geocoded, throw back to the engine
end

% TODO coreg obj by track/seg/(all visits) only
% coregSummary = engine.load( OI.Data.CoregisteredSegment.configure( ...
%     'STACK', trackInd,
%     'SEGMENT_INDEX', refSegInd) );
% if isempty( coregSummary )
%     engine.ui.log('info','Segment not Coregistered %i %i\n',trackInd, refSegInd)
%     return % segment not geocoded, throw back to the engine
% end

[blockStruct, blocksInAoi, ~, blockMap] = OI.Plugins.Substacking.get_blocks_in_aoi(engine, swathInfo,lle, aoi, sz, BLOCK_SIZE);

blocksToDo = this.blocks;
if isempty( blocksToDo )
    blocksToDo = blocksInAoi;
end

if isempty(blocksToDo)
    engine.ui.log('debug','No blocks in aoi\n');
    this = this.save_and_exit( engine, segProcessingStartTime, safe, trackInd, refSegInd, blocksInAoi, swathInfo, sz, BLOCK_SIZE );
    return % none in extent
end

% Skip any blocks that are already done.
allDone = true;
doneBlocks = 0.*blocksToDo;
for blockIndLocal = 1:numel(blocksToDo)
    haveAllObjects = true; % assume we have it
    for POLARIZATION = requestedPol
        if ~any(strfind(safe.polarization,POLARIZATION{1}))
            engine.ui.log('debug','No %s pol in segment\n',...
                POLARIZATION{1});
            continue % this polarization is not in the segment
        end
        blockObj = OI.Data.Substack().configure( ...
            'POLARIZATION',POLARIZATION{1}, ...
            'STACK',num2str(trackInd), ...
            'REFERENCE_SEGMENT_INDEX',num2str(refSegInd), ...
            'BLOCK', num2str( blocksToDo(blockIndLocal) ) );
            blockObj = blockObj.identify( engine );
            priorObj = engine.database.find( blockObj );
            % report if missing
            if isempty(priorObj)
                engine.ui.log('debug','Missing block %s\n',blockObj.id);
            end
            % latch this to false if any are missing
            haveAllObjects = haveAllObjects && ~isempty(priorObj);
    end
    if haveAllObjects
        engine.ui.log('debug','done block %s already\n',blockObj.id);
        doneBlocks(blockIndLocal) = 1;
    else
        allDone = false;
    end
end

if allDone
    engine.ui.log('debug','No blocks left\n');
    this = this.save_and_exit( engine, segProcessingStartTime, safe, trackInd, refSegInd, blocksInAoi, swathInfo, sz, BLOCK_SIZE );
    return % none remaining
end
blocksToDo( doneBlocks > 0 ) = []; % remove existing

nBlocksToDo = numel(blocksToDo);
blockData = cell( numel(blocksToDo), 1 );
% preallocate the block data
for localBlockIndInGroup = 1:nBlocksToDo
    block = blockStruct( blocksToDo(localBlockIndInGroup) );
    blockSizeAzRg = [block.azEnd-block.azStart+1, block.rgEnd-block.rgStart+1 , sz(3)];
    blockData{localBlockIndInGroup} = zeros( blockSizeAzRg );
    blockData{localBlockIndInGroup}(1) = 1i; % make sure it's complex
end

for POLARIZATION = requestedPol

    isPolInSafe = ...
        OI.Plugins.Substacking.is_pol_in_safe( safe, POLARIZATION{1});
    if ~isPolInSafe
        engine.ui.log('debug','No %s pol in segment\n',...
            POLARIZATION{1});
        continue;
    end


    % LOAD THE DATA
    for visitInd = 1:numel(stacks.stack(trackInd).correspondence(refSegInd,:))
        % get safe ind
        loadSegInd = stacks.stack(trackInd).correspondence(refSegInd,visitInd);

        % If the index is 0 it implies there is no data available for the
        % specified visit.
        if ~loadSegInd
            continue
        end

        loadSafeInd = stacks.stack( trackInd ).segments.safe( loadSegInd );
        loadSafe = cat.safes{loadSafeInd};
        % check the polarization is available in the paticular visit
        polInLoadSafe = ...
            OI.Plugins.Substacking.is_pol_in_safe(loadSafe,POLARIZATION{1});
        if ~polInLoadSafe
            % set the data to nan
            for localBlockIndInGroup = 1:nBlocksToDo
                block = blockStruct( blocksToDo(localBlockIndInGroup) );
                blockData{localBlockIndInGroup}(:,:,visitInd) = nan( ...
                    block.azEnd-block.azStart+1, block.rgEnd-block.rgStart+1 );
            end
            continue;
        end

        coregDataObj = OI.Data.CoregisteredSegment().configure( ...
            'POLARIZATION', POLARIZATION{1}, ...
            'STACK',num2str(trackInd), ...
            'REFERENCE_SEGMENT_INDEX',num2str(refSegInd), ...
            'VISIT_INDEX',num2str(visitInd) );
        coregDataObj = coregDataObj.identify( engine );

        coregData = engine.load( coregDataObj );
        % if we get here then this data is requested and should be
        % available, so if its missing we should stop
        if isempty(coregData)
            engine.ui.log('warning', ...
                'No coreged data available! T%i S%i V%i P%s\n', ...
                trackInd, refSegInd, visitInd, POLARIZATION{1});
            return;
            % break; % throw back to the engine, not resampled/coregistered
        end

        % now we have the data for the given pol and visit
        % populate the blocks
        for localBlockIndInGroup = 1:nBlocksToDo
            block = blockStruct( blocksToDo(localBlockIndInGroup) );
            % populate the block
            blockData{localBlockIndInGroup}(:,:,visitInd) = coregData( ...
                block.rgStart:block.rgEnd, ...
                block.azStart:block.azEnd).';
        end % block data assignment
    end % visits

    % Save the blocks
    for localBlockIndInGroup = 1:nBlocksToDo
        blockObj = OI.Data.Substack().configure( ...
            'POLARIZATION',POLARIZATION{1}, ...
            'STACK',num2str(trackInd), ...
            'REFERENCE_SEGMENT_INDEX',num2str(refSegInd), ...
            'BLOCK', num2str( blocksToDo(localBlockIndInGroup) ) );
        blockObj = blockObj.identify( engine );
        engine.save( blockObj(), ...
            blockData{localBlockIndInGroup} );

        % save a preview of the block
        baddies = sum(isnan(blockData{localBlockIndInGroup}),3);
        amp = sum(log(abs(blockData{localBlockIndInGroup})),3,'omitnan');
        amp = amp./(sz(3) - baddies); % roundabout way of doing mean
        amp(isnan(amp)) = 0;

        % get the block extent
        block = blockStruct( blocksToDo(localBlockIndInGroup) );
        blockSizeAzRg = [block.azEnd-block.azStart+1, block.rgEnd-block.rgStart+1 , sz(3)];
        
        % if safe.direction(1) == 'A'
        blockCorners = [1 1; 1 blockSizeAzRg(2); blockSizeAzRg(1) blockSizeAzRg(2); blockSizeAzRg(1) 1; 1 1];
        blockCornerInds = sub2ind( blockSizeAzRg, blockCorners(:,1), blockCorners(:,2) );
        blockLatLon = lle(blockMap == blocksToDo(localBlockIndInGroup),:);
        blockExtent = OI.Data.GeographicArea().configure( ...
            'lat',blockLatLon(blockCornerInds,1), ...
            'lon',blockLatLon(blockCornerInds,2) );

        % preview directory
        previewDir = fullfile(projObj.WORK,'preview','amp');
        previewKmlPath = fullfile( previewDir, [blockObj.id '.kml']);
        previewKmlPath = OI.Functions.abspath( previewKmlPath );
        OI.Functions.mkdirs( previewKmlPath );
        % save the preview
        if all(POLARIZATION{1} == 'VH')
            cLims = [2.5 5];
        else % copol
            cLims = [3 5.5];
        end
        blockExtent.save_kml_with_image( ...
            previewKmlPath, flipud(amp), cLims);

    end % save blocks
end % POLARIZATION

this = this.save_and_exit(engine, segProcessingStartTime, safe, trackInd, refSegInd, blocksToDo, swathInfo, sz, BLOCK_SIZE );
this.isFinished = true;

end % run

function this = save_and_exit( this, engine, segProcessingStartTime, safe, trackInd, refSegInd, blocksDone, swathInfo, sz, BLOCK_SIZE )
    timeTaken = toc(segProcessingStartTime);
    engine.ui.log('info','Processed %d blocks in %.1f secs\n', ...
        numel(blocksDone),timeTaken);
    this.outputs{1} = this.outputs{1}.configure( ...
        'STACK',num2str(trackInd), ...
        'REFERENCE_SEGMENT_INDEX',num2str(refSegInd), ...   
        'blocks',blocksDone, ...
        'timeTaken',timeTaken, ...
        'blockCount',numel(blocksDone),...
        'blockSize',BLOCK_SIZE, ...
        'visitCount', sz(3), ...
        'swathInfo', swathInfo, ...
        'safe', safe );
    
    formattedIdentifier = sprintf(this.formatStr,trackInd,refSegInd);
    this.outputs{1}.id = formattedIdentifier;
    engine.save( this.outputs{1} );
    this.isFinished = true;
end % save_and_exit

function this = run_first_and_last( this, engine, stacks, cat, preprocessingInfo, requestedPol, aoi )
% first time, check whats outstanding
    projObj = engine.load( OI.Data.ProjectDefinition() );
    BLOCK_SIZE = projObj.BLOCK_SIZE; % in meters, square area.

    allDone = true;
    for trackInd = 1:numel(stacks.stack)
    for refSegInd = stacks.stack(trackInd).reference.segments.index
        % get safe ind
        safeIndex = stacks.stack(trackInd).reference.segments.safe(refSegInd);
        % get swath ind
        swathIndex = stacks.stack(trackInd).reference.segments.swath(refSegInd);
        % get reference safe 
        safe = cat.safes{ safeIndex };
        % get metadata
        swathInfo = ...
            preprocessingInfo.metadata( safeIndex ).swath( swathIndex );
        % get the dimensions of the stack
        [lpb,spb] = ...
            OI.Plugins.Geocoding.get_parameters( swathInfo );
        sz = [lpb, spb, numel(stacks.stack(trackInd).correspondence(refSegInd,:))];

        % get lat lon
        geocodingData = OI.Data.LatLonEleForImage().configure( ...
            'STACK', num2str(trackInd), ...
            'SEGMENT_INDEX', num2str(refSegInd)).identify(engine);
        lle = engine.load( geocodingData );

        % get block info
        [~, blocksInAoi, blockGroups, blockMap] = ...
            OI.Plugins.Substacking.get_blocks_in_aoi(engine, swathInfo, lle, aoi, sz, BLOCK_SIZE);
        
        if isempty(blocksInAoi)
			engine.ui.log('debug','No blocks in AOI for track %i segment %i',trackInd, refSegInd);
            continue
        end
        for groupInd = 1:blockGroups(end) % if empty, nothing added
            thisGroupsBlocks = ...
                blocksInAoi(blockGroups == groupInd);

            % check every pol
            for POL = requestedPol
                % if this data isnt possible continue
                if ~OI.Plugins.Substacking.is_pol_in_safe( safe, POL{1} )
                    continue
                end

                % check all of them exist
                allThisGroupExist = true;
                for blockInd = thisGroupsBlocks
                    % see if we can find it
                    blockObj = OI.Data.Substack().configure( ...
                        'POLARIZATION',POL{1}, ...
                        'STACK',num2str(trackInd), ...
                        'REFERENCE_SEGMENT_INDEX',num2str(refSegInd), ...
                        'BLOCK', num2str( blockInd ) );
                    blockObj = blockObj.identify( engine );
                    priorObj = engine.database.find( blockObj );

                    if isempty(priorObj)
                        allThisGroupExist = false;
                    end
                end

                if ~allThisGroupExist
                    allDone = false;
                    % requeue the job
                    engine.ui.log('debug','Requeuing %i %i\n',trackInd, refSegInd)
                    engine.requeue_job( ...
                                'trackIndex',trackInd, ...
                                'referenceSegmentIndex', refSegInd, ...
                                'blocks', thisGroupsBlocks);
                end
            end % polarisation
        end % group of blocks
        if allDone
            engine.ui.log('info','%s done\n', this.id);
            this.outputs{1}.configure( ...
                'hasFile', true, ...
                'STACK',num2str(trackInd), ...
                'REFERENCE_SEGMENT_INDEX',num2str(refSegInd), ...   
                'blocks',blocksInAoi, ...
                'blockCount',numel(blocksInAoi),...
                'blockSize',BLOCK_SIZE, ...
                'visitCount', sz(3), ...
                'swathInfo', swathInfo, ...
                'safe', safe );
            engine.save( this.outputs{1} );
            this.isFinished = true;
        end

    end % segment
    end % stack


end % run first and last

end % methods

methods (Static = true)

    function tf = is_pol_in_safe( safe, pol ) % this should be in SAFE obj
        polInSafe = reshape(safe.polarization,[],2);
        tf = any( all(polInSafe == pol,2) );
    end

    function [blockStruct, blocksInAoi, blockGroups, blockMap] = get_blocks_in_aoi(engine, swathInfo, lle, aoi, sz, BLOCK_SIZE)
        
        if nargin < 6
        % define the blocks
            projObj = engine.load( OI.Data.ProjectDefinition() );
            BLOCK_SIZE = projObj.BLOCK_SIZE; % in meters, square area.
        end
        [blockStruct, ~, blockMap, ~, ~] = OI.Functions.blocks(swathInfo,BLOCK_SIZE);
        
        % find which blocks are in the aoi
        blockIsInAoi = zeros(numel(blockStruct),1);
        for blockInd = 1:numel(blockStruct)
            block = blockStruct(blockInd);
            blockSize = [block.azEnd-block.azStart+1, block.rgEnd-block.rgStart+1 , sz(3)];
            % check if the block is in the AOI
            blockExtent = OI.Data.GeographicArea();
            blockCorners = [1 1; 1 blockSize(2); blockSize(1) 1; blockSize(1) blockSize(2)];
            blockCornerInds = sub2ind( blockSize, blockCorners(:,1), blockCorners(:,2) );
            blockLatLon = lle(blockMap == blockInd,:);
        
            usefulEle = sum(blockLatLon(:,3) > 2);
            % TODO check around here for land, but blank out OOR errors
            if usefulEle < 100
                mlle = mean(blockLatLon);
                engine.ui.log('debug','Block %i @ %.2f %.2f %.2f in sea but thats okay\n',...
                    blockInd, mlle(1), mlle(2), mlle(3));
                continue; % block in sea
            end
        
            blockExtent.lat = blockLatLon(blockCornerInds,1);
            blockExtent.lon = blockLatLon(blockCornerInds,2);
            if ~blockExtent.overlaps(aoi)
                engine.ui.log('debug','Block %i outside AOI\n',...
                    blockInd);
                continue;
            end
            blockIsInAoi(blockInd) = 1;
        end
        blocksInAoi = find(blockIsInAoi)';

        % each block is about 6mb per day, assuming complex double, 5km^2
        mbPerBlock = prod(blockSize) * 8 * 2 / 1e6;
        % assuming we're on a 16gb machine, and lets say we have about half that
        % available
        blockMemoryCapacity = 8e3 / mbPerBlock; % 8000 mb 
        % how many blocks can we fit in memory?
        blockMemoryCapacity = min( blockMemoryCapacity, numel(blocksInAoi) );
        % split the blocks into groups of blocks that fit in memory
        blockGroups = ceil( (1:numel(blocksInAoi)) / blockMemoryCapacity );
    end % block info
end % static methods

end % classdef