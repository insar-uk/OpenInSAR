classdef BlockMapping < OI.Plugins.PluginBase

properties 
    inputs = {OI.Data.StitchingInformation()}
    outputs = {OI.Data.BlockMap()}
    id = 'BlockMapping'

end % properties

methods
    function this = run(this, engine, varargin )
        stitchInfo = engine.load( OI.Data.StitchingInformation() );
        projObj = engine.load( OI.Data.ProjectDefinition() );

        if isempty(stitchInfo) || isempty(projObj)
            return % Throw back to engine to provide inputs.
        end

        BLOCK_SIZE = projObj.BLOCK_SIZE; % in meters, square area.
        blockMap = OI.Data.BlockMap();

        % define a block structure
        blockStruct = struct( ...
            'index', -1, ...
            'segmentIndex', -1, ...
            'indexInSegment', -1, ...
            'stackIndex', -1, ...
            'azDataStart', -1, ...
            'azDataEnd', -1, ...
            'rgDataStart', -1, ...
            'rgDataEnd', -1, ...
            'azOutputStart', -1, ...
            'azOutputEnd', -1, ...
            'rgOutputStart', -1, ...
            'rgOutputEnd', -1, ...
            'latCorners', [], ...
            'lonCorners', [], ...
            'eleCorners', [], ...
            'meanLat', -1, ...
            'meanLon', -1, ...
            'meanEle', -1, ...
            'blockInAOI', true, ...
            'blockInSea', false, ...
            'size', [0,0] ...
        );
        blockCount = 0;

        for stackInd = 1:numel( stitchInfo.stack )
            segmentsInStack = stitchInfo.stack( stackInd ).segments;
            blocksInStack = [];
            for segmentInd = 1:numel( segmentsInStack )
                engine.ui.log('info','Breaking segment %i of %i in stack %i into blocks\n', segmentInd, numel( segmentsInStack ), stackInd);
                thisSeg = segmentsInStack(segmentInd);

                % Segment info
                segmentSz = [ ...
                    thisSeg.timing.linesPerBurst, ...
                    thisSeg.timing.samplesPerBurst ];

                % We want to subdivide each segment into 5km^2 blocks
                segmentStartAz = thisSeg.position.cropStartAzimuth;
                segmentEndAz = thisSeg.position.cropEndAzimuth;
                segmentStartRg = thisSeg.position.cropStartRange;
                segmentEndRg = thisSeg.position.cropEndRange;

                % Calculate the size of the segment in meters
                segmentSizeAz = (segmentEndAz - segmentStartAz) * thisSeg.timing.azSpacing;
                segmentSizeRg = (segmentEndRg - segmentStartRg) * thisSeg.timing.rgSpacing;

                % Calculate the number of blocks in each direction
                nBlocksAz = ceil( segmentSizeAz / BLOCK_SIZE );
                nBlocksRg = ceil( segmentSizeRg / BLOCK_SIZE );

                % Find the indices of the block starts and ends, in the data
                azBlockStarts = floor(linspace( ...
                    thisSeg.position.firstCroppedAzimuthLine, ...
                    thisSeg.position.lastCroppedAzimuthLine+1, ...
                    nBlocksAz+1));
                azBlockEnds = azBlockStarts(2:end) - 1;
                azBlockStarts(end) = [];

                rgBlockStarts = floor(linspace( ...
                    thisSeg.position.firstCroppedRangeSample, ...
                    thisSeg.position.lastCroppedRangeSample+1, ...
                    nBlocksRg+1));
                rgBlockEnds = rgBlockStarts(2:end) - 1;
                rgBlockStarts(end) = [];

                % Get geocoding info
                geocodingData = OI.Data.LatLonEleForImage().configure( ...
                    'STACK', num2str(stackInd), ...
                    'SEGMENT_INDEX', num2str(segmentInd) ...
                    ).identify(engine);
                % Load this large file
                latLonEle = engine.load( geocodingData ); 

                % Record the blocks
                blocks = repmat( blockStruct, nBlocksAz*nBlocksRg, 1 );
                for ai = 1:nBlocksAz
                    for ri = 1:nBlocksRg
                        ii = (ai-1)*nBlocksRg + ri;
                        blockCount = blockCount + 1;

                        blocks(ii).indexInSegment = ii;
                        blocks(ii).index = blockCount;
                        blocks(ii).segmentIndex = segmentInd;
                        blocks(ii).stackIndex = stackInd;
                        
                        blocks(ii).azDataStart = azBlockStarts(ai);
                        blocks(ii).azDataEnd = azBlockEnds(ai);
                        blocks(ii).rgDataStart = rgBlockStarts(ri);
                        blocks(ii).rgDataEnd = rgBlockEnds(ri);

                        blocks(ii).size = [ ...
                            azBlockEnds(ai) - azBlockStarts(ai) + 1, ...
                            rgBlockEnds(ri) - rgBlockStarts(ri) + 1 ];

                        % Convert subscripts of block into index in overall segment
                        [rgGrid, azGrid] = meshgrid( ...
                            rgBlockStarts(ri):rgBlockEnds(ri), ...
                            azBlockStarts(ai):azBlockEnds(ai));
                        inds = sub2ind( segmentSz, azGrid(:), rgGrid(:) );


                        cornerSubs = [ ...
                            azBlockStarts(ai), rgBlockStarts(ri); ...
                            azBlockStarts(ai), rgBlockEnds(ri); ...
                            azBlockEnds(ai), rgBlockStarts(ri); ...
                            azBlockEnds(ai), rgBlockEnds(ri) ];
                        cornerInds = sub2ind( segmentSz, ...
                            cornerSubs(:,1), cornerSubs(:,2) );
                        % 
                        % Get the lat/lon of the corners
                        blocks(ii).latCorners = latLonEle(cornerInds,1);
                        blocks(ii).lonCorners = latLonEle(cornerInds,2);
                        blocks(ii).meanLat = mean( latLonEle(inds,1) );
                        blocks(ii).meanLon = mean( latLonEle(inds,2) );
                        blocks(ii).meanEle = mean( latLonEle(inds,3) );
                        blocks(ii).latCorners = latLonEle(cornerInds,1);
                        blocks(ii).lonCorners = latLonEle(cornerInds,2);
                        blocks(ii).eleCorners = latLonEle(cornerInds,3);

                        aoiArea = projObj.AOI.to_area();
                        blockArea = OI.Data.GeographicArea();
                        blockArea.lat = latLonEle(cornerInds,1);
                        blockArea.lon = latLonEle(cornerInds,2);
                        blocks(ii).blockInAOI = any( ...
                            aoiArea.overlaps( blockArea ) );
                        blocks(ii).blockInSea = all( latLonEle(inds,3) <= 0 );

                        % Recreate the position of the block in the output mosaic by
                        % subtracting the first cropped line/sample

                        % Position of block in data, relative to (minus) the start of the
                        % data (i.e. start of blocks), plus the start of
                        % the segment
                        blocks(ii).azOutputStart = ...
                            azBlockStarts(ai) + thisSeg.position.azOutputStart - thisSeg.position.firstCroppedAzimuthLine;
                        blocks(ii).azOutputEnd = ...
                            azBlockEnds(ai) + thisSeg.position.azOutputStart - thisSeg.position.firstCroppedAzimuthLine;
                        blocks(ii).rgOutputStart = ...
                            rgBlockStarts(ri) + thisSeg.position.rgOutputStart - thisSeg.position.firstCroppedRangeSample;
                        blocks(ii).rgOutputEnd = ...    
                            rgBlockEnds(ri) + thisSeg.position.rgOutputStart - thisSeg.position.firstCroppedRangeSample;

   
                    end
                end

                % Add these blocks to the output
                blocksInStack = [blocksInStack(:); blocks(:);] ;
                % bb = [bb(:);blocks(:)];
                mAz=0;mRg=0;
                for ii=1:numel(blocksInStack)
                mAz=max(mAz,blocksInStack(ii).azOutputEnd);
                mRg=max(mRg,blocksInStack(ii).rgOutputEnd);
                end
                blockMapArray=zeros(mAz,mRg);
                for ii=1:numel(blocksInStack)
                blockMapArray(blocksInStack(ii).azOutputStart:blocksInStack(ii).azOutputEnd,blocksInStack(ii).rgOutputStart:blocksInStack(ii).rgOutputEnd)=ii;
                end
                % figure(808);clf;
                % imagesc(blockMapArray)
                % drawnow()
                % title(sprintf('Stack %i seg %i',stackInd,segmentInd));

               
            end % segment loop

            if stackInd==1
                blockMap.stacks = struct('blocks',blocksInStack,'map',blockMapArray);
            else
                blockMap.stacks(stackInd) = struct('blocks',blocksInStack,'map',blockMapArray);
            end

            % Collect blocks in AOI
            bInA = arrayfun(@(x) x.blockInAOI, blockMap.stacks(stackInd).blocks);
            bInC = arrayfun(@(x) x.blockInSea, blockMap.stacks(stackInd).blocks);
            isUsefulBlock = bInA; %zeros(size(bInA),'logical');
            % If we are masking out areas of sea, do that here
            if projObj.MASK_SEA
                isUsefulBlock = isUsefulBlock & ~bInC;
            end
            blockMap.stacks(stackInd).usefulBlockIndices = find(isUsefulBlock);
            blockMap.stacks(stackInd).usefulBlocks = ...
                blockMap.stacks(stackInd).blocks(find(isUsefulBlock));


        end % stack loop

        % Save the block map
        engine.save( blockMap );

    end % run

end % methods

end % classdef


% swathInfo = stitchInfo.stack(stackInd).segments(segmentInd);
% swathInfo = ...
%     preprocessingInfo.metadata( safeIndex ).swath( swathIndex );

% azMeters = swathInfo.azSpacing;
% rgMeters = swathInfo.rgSpacing;
% lpb = swathInfo.linesPerBurst;
% spb = swathInfo.samplesPerBurst;
% distanceAz = (1:lpb) * azMeters;
% distanceRg = (1:spb) * rgMeters ./ sind( swathInfo.incidenceAngle );
% % do rg
% nBlocksAz = 1;
% nBlocksRg = 1;
% while true
%     % increase the bkock size until it is less than the minimum
%     if (distanceAz(end)-distanceAz(1))/nBlocksAz > minimumBlockAxis
%         nBlocksAz = nBlocksAz + 1;
%         continue
%     end
%     if (distanceRg(end)-distanceRg(1))/nBlocksRg > minimumBlockAxis
%         nBlocksRg = nBlocksRg + 1;
%         continue
%     end
%     break;
% end
% nBlocks = nBlocksAz * nBlocksRg;

% % now we have the number of blocks in each direction
% % output the block structures
% % these detail the start and end of each block 
% % in terms of rg and az
% blockStruct = struct( ...
%     'rgStart', [], ...
%     'rgEnd', [], ...
%     'azStart', [], ...
%     'azEnd', [] ...
%     );
% % Preallocate the block array
% blockArray = zeros(nBlocksAz, 4);

% % Preallocate the block map
% blockMap = zeros(lpb, spb);
% % blockInds = cell(1, nBlocks);
% [blockAz, blockRg] = deal(cell(1,nBlocks));

% % split the axes into blocks
% azBlockStarts = floor(linspace(1, lpb, nBlocksAz+1));
% azBlockEnds = azBlockStarts(2:end) - 1;
% azBlockStarts(end) = [];
% rgBlockStarts = floor(linspace(1, spb, nBlocksRg+1));
% rgBlockEnds = rgBlockStarts(2:end) - 1;
% rgBlockStarts(end) = [];

% % Fill the block map
% for ai = 1:nBlocksAz
% for ri = 1:nBlocksRg
%     blockIndex = (ai-1)*nBlocksRg + ri;
%     blockStruct(blockIndex).rgStart = rgBlockStarts(ri);
%     blockStruct(blockIndex).rgEnd = rgBlockEnds(ri);
%     blockStruct(blockIndex).azStart = azBlockStarts(ai);
%     blockStruct(blockIndex).azEnd = azBlockEnds(ai);

%     blockArray(blockIndex, :) = [rgBlockStarts(ri), rgBlockEnds(ri), azBlockStarts(ai), azBlockEnds(ai)];

%     blockMap(azBlockStarts(ai):azBlockEnds(ai), ...
%         rgBlockStarts(ri):rgBlockEnds(ri)) = blockIndex;
%     blockAz{blockIndex} =  azBlockStarts(ai):azBlockEnds;
%     blockRg{blockIndex} =  rgBlockStarts(ai):rgBlockEnds;

% end
% end


