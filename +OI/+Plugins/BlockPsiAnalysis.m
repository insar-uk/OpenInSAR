classdef BlockPsiAnalysis < OI.Plugins.PluginBase
    
properties
    inputs = {OI.Data.Blocking()}
    outputs = {OI.Data.BlockPsiSummary()}
    id = 'BlockPsiAnalysis'
    STACK = []
    BLOCK = []
end

methods
    function this = BlockPsiAnalysis( varargin )
        this.isArray = true;
        this.isFinished = false;
    end    


    function this = run(this, engine, varargin)

        blockMap = oi.engine.load( OI.Data.BlockMap() );
        projObj = oi.engine.load( OI.Data.ProjectDefinition() );
        if isempty(blockMap) || isempty(projObj)
            % No block map
            return
        end

        if isempty(this.BLOCK)
            % Queue up all blocks
            this = this.queue_jobs(engine, blockMap);
            return
        end

        blockData = oi.engine.load( OI.Data.Block().configure('STACK',num2str(this.STACK),'POLARISATION','VV','BLOCK', num2str(this.BLOCK) ) );
        if isempty(blockData)
            % No data for this block
            return
        end

        % Create the block object template
        blockObj = OI.Data.Block().configure( ...
            'POLARISATION', 'VV', ...
            'STACK',num2str( this.STACK ), ...
            'BLOCK', num2str( this.BLOCK ) ...
            ).identify( engine );

        error('TODO write ampstab func')
        amplitudeStability = OI.Functions.block_amplitude_stability(blockData);
        
        % Create data objects
        error('TODO specify these objects')
        error('Make sure there is a copy method for each of these')
        ampStabObj = OI.Data.BlockAmplitudeStability().copy( blockObj );
        coherenceObj = OI.Data.BlockCoherence().copy( blockObj );
        velocityObject = OI.Data.BlockVelocity().copy( blockObj );
        heightErrorObject = OI.Data.BlockHeightError().copy( blockObj );
        
        % Save the amplitude stability
        engine.save( ampStabObj, amplitudeStability );

        error('TODO get time series and baseline')
        % Get the time series and baselines
        timeSeries = OI.Functions.block_time_series(blockData);
        baselines = OI.Functions.block_baselines(blockData);

        % Do the inversion
        error('TODO check inversion func')
        [C, v, q] = OI.Functions.invert_block(blockData, timeSeries, baselines);


        warning('TODO Resize these here?')
        % Save the PSI outputs
        engine.save( coherenceObj, C );
        engine.save( velocityObject, v );
        engine.save( heightErrorObject, q );

        % Save a preview of the v, C and q
        error('TODO implement modified block preview')
        this.preview_block(blockMap, blockInfo, v, 'velocity')
        this.preview_block(blockMap, blockInfo, C, 'coherence')
        this.preview_block(blockMap, blockInfo, q, 'height_error')

        % Create a shapefile of the block
        warning('TODO Name this elsewhere?')
        blockName = sprintf('Stack_%i_block_%i',this.STACK,this.BLOCK);
        blockFilePath = fullfile( projObj.WORK, 'shapefiles', [blockName '.shp'] );
        error('TODO implement save shapefile')
        blockObj.save_shapefile( { ...
            'Name', blockName, ...
            'timeSeries', timeSeries, ...
            'baselines', baselines, ...
            'fileName', blockFilePath, ...
            'Coherence', C, ...
            'Velocity', v, ...
            'HeightError', q, ...
            'AmplitudeStability', amplitudeStability ...
            } );

        this.isFinished = true;

    end % run

    function this = queue_jobs(this, engine, blockMap)
        allDone = true;
        % Queue up all blocks
        for stackIndex = 1:blockMap.numStacks
            stackBlocks = blockMap.stacks( stackIndex );
            for blockIndex = 1:stackBlocks.usefulBlockIndices

                % Check if the block is already done
                error('TODO implement / specifiy output object')
                priorObj = engine.database.find( outputObj );
                if ~isempty(priorObj)
                    % Already done
                    continue
                end

                allDone = false;
                block = stackBlocks.blocks( blockIndex );
                engine.requeue_job( ...
                    'BLOCK', block.index, ...
                    'STACK', block.stackIndex);
            end
        end
    end % queue_jobs

end % methods


methods (Static = true)
    function previewKmlPath = preview_block(projObj, blockInfo, dataToPreview, dataCategory, cLims)
        % get the block extent
        sz = blockInfo.size;
        dataToPreview = reshape(dataToPreview, sz(1), sz(2), []);
      
        blockExtent = OI.Data.GeographicArea().configure( ...
            'lat', blockInfo.latCorners, ...
            'lon', blockInfo.lonCorners );
        blockExtent = blockExtent.make_counter_clockwise();

        % preview directory
        previewDir = fullfile(projObj.WORK,'preview','block', dataCategory);
        blockName = sprintf('%s_stack_%i_block_%i',dataCategory, blockInfo.stackIndex, blockInfo.index);

        previewKmlPath = fullfile( previewDir, [blockName '.kml']);
        previewKmlPath = OI.Functions.abspath( previewKmlPath );
        OI.Functions.mkdirs( previewKmlPath );
        % save the preview
        if nargin < 5
            cLims = [0 1];
        end

        blockExtent.save_kml_with_image( ...
            previewKmlPath, fliplr(dataToPreview), cLims);
    end
end % methods (Static = true)

end % classdef