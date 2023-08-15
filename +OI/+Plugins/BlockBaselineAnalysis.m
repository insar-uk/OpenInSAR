classdef BlockBaselineAnalysis < OI.Plugins.PluginBase
    
properties
    inputs = {OI.Data.BlockMap()}
    outputs = {OI.Data.BlockBaselineSummary()}
    id = 'BlockBaselineAnalysis'
    STACK = []
    BLOCK = []
end

methods
    function this = BlockBaselineAnalysis( varargin )
        this.isArray = true;
        this.isFinished = false;
    end    


    function this = run(this, engine, varargin)

        % Queue jobs if no parameters are set
        if isempty(this.BLOCK) || isempty(this.STACK)
            this = this.queue_jobs(engine);
            return
        end

        blockIndex = this.BLOCK;
        stackIndex = this.STACK;

        blockMap = engine.load( OI.Data.BlockMap() );
        preprocessingInfo = engine.load( OI.Data.PreprocessedFiles() );
        cat = engine.load( OI.Data.Catalogue() );
        stacks = engine.load( OI.Data.Stacks() );


        % return if any of the inputs are empty
        if isempty(blockMap) || isempty(preprocessingInfo) || isempty(cat) || isempty(stacks)
            return
        end

        stack = stacks.stack( stackIndex );

        % define the current block
        blockInfo = blockMap.stacks(stackIndex).blocks(blockIndex);

        % find the reference segment from the block map
        referenceSegmentIndex = blockInfo.segmentIndex;

        % Get the segment addresses and corresponding safes
        segmentInds = stack.correspondence(referenceSegmentIndex,:);
        segmentInds(segmentInds==0) = []; % skip missing data
        
        safeInds = stack.segments.safe(segmentInds);
        safeCellArray=cat.safes(safeInds);

        timeSeries = arrayfun(@(x) x.date.datenum, [cat.safes{safeInds}]);


        % Get the reference index, safe, and orbit file
        referenceSafeIndex = stack.reference.segments.safe( referenceSegmentIndex );
        referenceSwathIndex = stack.reference.segments.swath(referenceSegmentIndex );
        referenceBurstIndex = stack.reference.segments.burst( referenceSegmentIndex );
        referenceSafe = cat.safes{referenceSafeIndex};
        referenceOrbitFile = referenceSafe.orbitFile;
        referenceMetadata = preprocessingInfo.metadata(referenceSafeIndex);

        % Get the orbit object for the reference image
        referenceOrbitObject = OI.Data.Orbit(referenceOrbitFile);

        % Get the burst timing information for the reference image
        referenceSwathMetadata = referenceMetadata.swath( referenceSwathIndex );
        referenceBurstMetadata = referenceSwathMetadata.burst( referenceBurstIndex );
        referenceStartTime = referenceBurstMetadata.startTime;
        lpb = referenceSwathMetadata.linesPerBurst;
        ati = referenceSwathMetadata.azimuthTimeInterval;
        referenceOrbitTime = referenceStartTime:ati/86400:...
            referenceStartTime + (lpb-1)*ati/86400;
        % Interpolate the orbit to the burst times
        referenceInterpOrbit = referenceOrbitObject.interpolate( referenceOrbitTime );

        % Convert the mean block position to XYZ
        blockXYZ = OI.Functions.lla2xyz( blockInfo.meanLat, blockInfo.meanLon, blockInfo.meanEle );
        [~,orbitLineIndex] = min(sum((blockXYZ-referenceInterpOrbit.xyz()).^2,2));
        referenceOrbitXYZ = referenceInterpOrbit.xyz(orbitLineIndex); 

        % Get the sensing direction and azimuth direction, use these to
        % determine the perpendicular baseline
        sensingVector = blockXYZ - referenceOrbitXYZ;
        sensingVector = sensingVector/norm(sensingVector);
        azimuthVector = referenceInterpOrbit.v(orbitLineIndex);
        azimuthVector = azimuthVector/norm(azimuthVector);
        perpVector = cross( sensingVector, azimuthVector );


        % Preallocate the baseline arrays
        spatialBaseline = zeros( numel( safeCellArray ), 3 );
        perpendicularBaseline = zeros( numel( safeCellArray ), 1 );


        % Loop through the visits and determine the perpendicular baseline
        for visitInd = 1:numel( safeCellArray )
            engine.ui.log( 'Debug', sprintf( 'Processing visit %d of %d\n', visitInd, numel( safeCellArray ) ) );
            visitTic=tic;
            safe = safeCellArray{visitInd};
            orbitFile = safe.orbitFile;
            orbitObject = OI.Data.Orbit(orbitFile);

            % address of the data in the catalogue and metadata
            segInd = segmentInds(visitInd);
            safeIndex = stack.segments.safe( segInd );
            swathIndex = stack.segments.swath( segInd );
            burstIndex = stack.segments.burst( segInd );

            safeMetadata = preprocessingInfo.metadata( safeIndex );
            swathMetadata = safeMetadata.swath( swathIndex );
            burstMetadata = swathMetadata.burst( burstIndex );

            startTime = burstMetadata.startTime;
            lpb = swathMetadata.linesPerBurst;
            ati = swathMetadata.azimuthTimeInterval;

            orbitTime = startTime:ati/86400:...
                startTime + (lpb-1)*ati/86400;

            interpOrbit = orbitObject.interpolate( orbitTime );
            [~,orbitLineIndex] = min(sum((blockXYZ-interpOrbit.xyz()).^2,2));
            orbitXYZ = interpOrbit.xyz(orbitLineIndex);

            % Get the spatial baseline
            spatialBaseline(visitInd,:) = orbitXYZ - referenceOrbitXYZ;
            % Get the perpendicular baseline
            perpendicularBaseline(visitInd) = dot( spatialBaseline(visitInd,:), perpVector );
            toc( visitTic )
        end

        c = 299792458;
        lambda = c/referenceSwathMetadata.radarFrequency;
        R = sum( (referenceOrbitXYZ - blockXYZ).^2 ).^0.5;
        theta = acos(dot(blockXYZ./norm(blockXYZ),-sensingVector));
        k = -(4.*pi/lambda) .* perpendicularBaseline / R .* sin( theta );

        fprintf('theta = %f\n',rad2deg(theta))
        fprintf('theta in metadata = %f\n',referenceSwathMetadata.incidenceAngle)

        % Save the results
        baselineInfo = OI.Data.BlockBaseline();
        baselineInfo.BLOCK = num2str(blockIndex);
        baselineInfo.STACK = num2str(stackIndex);

        baselineInfo.k = k;
        baselineInfo.spatialBaseline = spatialBaseline;
        baselineInfo.perpendicularBaseline = perpendicularBaseline;
        baselineInfo.sensingVector = sensingVector;
        baselineInfo.azimuthVector = azimuthVector;
        baselineInfo.perpendicularVector = perpVector;
        baselineInfo.orbitXYZ = referenceOrbitXYZ;
        baselineInfo.blockXYZ = blockXYZ;
        baselineInfo.blockInfo = blockInfo;
        
        baselineInfo.heading = referenceSwathMetadata.heading;
        baselineInfo.direction = preprocessingInfo.metadata( safeIndex ).pass;
        baselineInfo.meanIncidenceAngle = acosd(dot(blockXYZ./norm(blockXYZ),-sensingVector));
        
        baselineInfo.timeSeries = timeSeries;

        engine.save( baselineInfo );
        this.isFinished = true;

    end % run

    function this = queue_jobs(this, engine)
        % Determine which blocks are in the AOI
        blockMap = engine.load( OI.Data.BlockMap() );
        stacks = engine.load( OI.Data.Stacks() );
        cat = engine.load( OI.Data.Catalogue() );
        if isempty(blockMap) || isempty(cat) || isempty(stacks)
            return
        end

        % Do each stack
        jobCount = 0;
        allComplete = true;
        for stackInd = 1:numel( blockMap.stacks )
            % Loop through the list of useful blocks
            for blockInd = blockMap.stacks(stackInd).usefulBlockIndices(:)'
                % Create the block object template
                blockObj = OI.Data.BlockBaseline().configure( ...
                    'STACK',num2str(stackInd), ...
                    'BLOCK', num2str( blockInd ) ...
                    ).identify( engine );
                blockInDatabase = engine.database.find( blockObj );
                
                % If file not found, create a job to generate it
                if isempty(blockInDatabase)
                    jobCount = jobCount+1;
                    % Create a job to generate the block
                    engine.requeue_job_at_index( ...
                        jobCount, ...
                        'BLOCK', blockInd, ...
                        'STACK', stackInd ...
                    )
                    allComplete = false;
                end
            end % block loop
        end % stack loop

        % Save and exit if all jobs are complete
        if allComplete
            this.isFinished = true;
            engine.save( this.outputs{1} );
        end
    end % queue_jobs

end % methods

end % classdef