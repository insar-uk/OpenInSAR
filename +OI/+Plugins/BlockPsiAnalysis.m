classdef BlockPsiAnalysis < OI.Plugins.PluginBase
    
properties
    inputs = {OI.Data.BlockBaselineSummary()}
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

        blockMap = engine.load( OI.Data.BlockMap() );
        projObj = engine.load( OI.Data.ProjectDefinition() );
        stacks = engine.load( OI.Data.Stacks() );
        if isempty(blockMap) || isempty(projObj) 
            % No block map
            return
        end

        if isempty(this.BLOCK)
            % Queue up all blocks
            this = this.queue_jobs(engine, blockMap);
            return
        end

        stack = stacks.stack( this.STACK );
        thisSegment = blockMap.stacks(this.STACK).blocks( this.BLOCK ).segmentIndex;
        thisReferenceVisit = stack.reference.segments.visit( thisSegment ); %#ok<*NASGU>

        % Find missing data visits
        missingData = stack.correspondence(thisSegment, :)' == 0;
        
        % Create the block object template
        blockObj = OI.Data.Block().configure( ...
            'POLARISATION', 'VV', ...
            'STACK',num2str( this.STACK ), ...
            'BLOCK', num2str( this.BLOCK ) ...
            ).identify( engine );
        
        % Create data objects
        ampStabObj = OI.Data.BlockResult( blockObj, 'AmplitudeStability' );
        coherenceObj = OI.Data.BlockResult( blockObj, 'Coherence');
        velocityObject = OI.Data.BlockResult( blockObj, 'Velocity' );
        heightErrorObject = OI.Data.BlockResult( blockObj, 'HeightError' );
        psPhaseObject = OI.Data.BlockResult( blockObj, 'InitialPsPhase' );
        

        % Get the time series and baselines
        baselinesObjectTemplate = OI.Data.BlockBaseline().configure( ...
            'STACK', num2str(this.STACK), ...
            'BLOCK', num2str(this.BLOCK) ...
            ).identify( engine );
        baselinesObject = engine.load( baselinesObjectTemplate );

        if isempty( baselinesObject )
            return % needs generating
        end

        blockInfo = blockMap.stacks(this.STACK).blocks(this.BLOCK);

        if ~psPhaseObject.identify(engine).exists()

            
            
            timeSeries = baselinesObject.timeSeries(:)';
            kFactors = baselinesObject.k(:)';

            % Load the block data
            blockData = engine.load( blockObj );
            
            if isempty(blockData)
                % No data for this block
                return
            end
            sz = size(blockData);
            baddies = squeeze(sum(sum(blockData))) == 0;
        
            % Get PSC
            amplitudeStability = ...
                OI.Functions.amplitude_stability( ...
                    abs(blockData(:,:,~baddies)) ...
                    );
            pscMask = amplitudeStability(:)>3;

            

            % Save the amplitude stability
            engine.save( ampStabObj, amplitudeStability );

            %% Do the inversion
            qToPhase = @(q) exp(1i.*q.*kFactors);
            vToPhase = @(v) exp(1i.*v.*timeSeries);
            normz = @(x) x./abs(x);
            mean_coherence = @(phase2d) mean(abs(sum(normz(phase2d),2)))./size(phase2d,2);
            blockData = reshape(blockData,[],sz(3));
            blockData = normz(blockData);

            
            % Candidate Stuff
            candidateThreshold = 2;
            candidateMask = amplitudeStability > candidateThreshold;
            candidatePhase = blockData( candidateMask, :);

            % Remove missing data
            blockData = blockData(:,~missingData);

            % avfilt = @(I,x,y) imfilter((I),fspecial('average',[x,y]));

            % APS
            fprintf(1,'Number of PSC: %i\n',sum(pscMask(:)))
            pscCm = blockData(pscMask,:)'*blockData(pscMask,:);
            [eVec, eVal] = eig(pscCm);
            [~, bestPairIndex] = max(diag(eVal));
            aps = normz(eVec(:,bestPairIndex).');

            % Height error: remove aps
            blockData = blockData.*aps;
            [Cq, q0, qi] = OI.Functions.invert_height(blockData,kFactors); %#ok<*ASGLU>
            
            % Velocity: remove q, aps already removed
            blockData = blockData.*qToPhase(q0);
            [Cv,v0] = OI.Functions.invert_velocity(blockData,timeSeries);
            % remove velocity
            blockData = blockData.*vToPhase(v0);
            % q, v, and aps now form our initial model
            % lets improve each in turn
            psMask = Cv>.75;

            % APS residual
            psResidual = blockData(psMask,:);
            psCm = psResidual'*psResidual;
            [eVec, eVal] = eig(psCm);
            [~, bestPairIndex] = max(diag(eVal));
            apsResidual = normz(eVec(:,bestPairIndex).');
            blockData = blockData.*apsResidual;

            % Add height back on and reestimate
            blockData = blockData.*qToPhase(-q0);
            [Cq, q, qi] = OI.Functions.invert_height(blockData,kFactors);
            blockData = blockData.*qToPhase(q);

            % Add velocity back on and reestimate
            blockData = blockData.*vToPhase(-v0);
            [Cv,v] = OI.Functions.invert_velocity(blockData,timeSeries);

            % Add all the errors back on, and save the raw phase of the highly coherent points.
            blockData = blockData.*qToPhase(-q).*vToPhase(-v0).*conj(aps).*conj(apsResidual);
            blockData = blockData(Cv>.5,:);
            psPhaseObject = OI.Data.BlockResult( blockObj, 'InitialPsPhase' );
            

            fprintf(1,'Mean coherence after constant aps analysis: %.3f\n',mean_coherence(blockData))
            
            % % Lets improve the aps by spatial filtering
            % for iteration = 1:3
            %     for visitInd = sz(3):-1:1
            %         apsBlock(:,:,visitInd) = avfilt(reshape( ...
            %             data_residual(:,thisReferenceVisit) ...
            %             .* conj(data_residual(:,visitInd)), ...
            %             sz(1:2) ) ... % reshape size
            %             ,50,200); % filter size
            %     end
            %     aps2d = reshape(normz(apsBlock),[],sz(3));
            %     data_residual = data_residual.*aps2d;
        
            %      % Height
            %     data_residual = data_residual.*qToPhase(-q);
            %     [Cq, q, qi] = OI.Functions.invert_height(data_residual,kFactors); %#ok<*ASGLU>
            %     data_residual = data_residual.*qToPhase(q);
        
            %     % Velocity
            %     data_residual = data_residual.*vToPhase(-v);
            %     [Cv,v] = OI.Functions.invert_velocity(data_residual,timeSeries);
            %     data_residual = data_residual.*vToPhase(v);
            %     fprintf(1,'Mean coherence after iter %i: %.3f\n',iteration,mean_coherence(data_residual))
            % end

            
            % Save the PSI outputs
            C = reshape(Cv,sz(1:2));
            v = reshape(v,sz(1:2));
            q = reshape(q,sz(1:2));
            engine.save( coherenceObj, C );
            engine.save( velocityObject, v );
            engine.save( heightErrorObject, q );

            % coherence;
            % scattererPhaseOffset;
            % velocity;
            % displacement;
            % heightError;
            % amplitudeStability;
            % block;

            [meshRg,meshAz]=meshgrid(...
                blockInfo.rgOutputStart:blockInfo.rgOutputEnd, ...
                blockInfo.azOutputStart:blockInfo.azOutputEnd);

            candidateAz=meshAz(candidateMask);
            candidateRg=meshRg(candidateMask);

            psPhaseStruct = struct( ...
                'type', 'initial block', ...
                'coherence', C, ...
                'velocity', v, ...
                'heightError', q, ...
                'amplitudeStability', amplitudeStability, ...
                'displacement', [], ...
                'candidateStabilityThreshold', candidateThreshold, ...
                'candidateStability', amplitudeStability(candidateMask), ...
                'candidatePhase', candidatePhase, ...
                'candidateAz', candidateAz, ...
                'candidateRg', candidateRg, ...
                'candidateMask', candidateMask, ...
                'blockInfo', blockInfo ...
            );

            engine.save( psPhaseObject, psPhaseStruct );

        else
            C = engine.load( coherenceObj );
            v = engine.load( velocityObject );
            q = engine.load( heightErrorObject );
        end


        
        
        % Save a preview of the v, C and q
        mask0s = @(x) OI.Functions.mask0s(x);
        blockInfo = blockMap.stacks(this.STACK).blocks(this.BLOCK);

        % Fix for legacy blockInfo which missed this field
        if ~isfield(blockInfo,'indexInStack')
            overallIndex = blockInfo.index;
            blockInfo.indexInStack = ...
                find(arrayfun(@(x) x.index == overallIndex, ...
                    blockMap.stacks( this.STACK ).blocks));
        end

        if baselinesObject.azimuthVector(3) > 0 % ascending
            OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, flipud(C), 'Coherence');
            OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, flipud(v .* mask0s(C>.5)), 'Velocity');
            OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, flipud(q .* mask0s(C>.5)), 'HeightError');
        else % descending
            OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, fliplr(C), 'Coherence');
            OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, fliplr(v .* mask0s(C>.5)), 'Velocity');
            OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, fliplr(q .* mask0s(C>.5)), 'HeightError');
        end
        
        % Get block lat/;pm
        overallBlockIndex = blockMap.stacks(this.STACK).blocks( this.BLOCK ).index;
        blockGeocode = OI.Data.BlockGeocodedCoordinates().configure( ...
            'STACK', num2str(this.STACK), ...
            'BLOCK', num2str(overallBlockIndex) ...
        );
        bg = engine.load(blockGeocode);
        if isempty(bg)
            return
        end

        % Create a shapefile of the block
        blockName = sprintf('Stack_%i_block_%i',this.STACK,this.BLOCK);
        blockFilePath = fullfile( projObj.WORK, 'shapefiles', this.id, blockName);
        
        cohMask = C>.5;
        OI.Functions.ps_shapefile( ...
            blockFilePath, ...
            bg.lat(cohMask), ...
            bg.lon(cohMask), ...
            [], ... % displacements 2d Array
            {}, ... % datestr(timeSeries(1),'YYYYMMDD')
            q(cohMask), ...
            v(cohMask), ...
            C(cohMask));

        this.isFinished = true;
    end % run

    function this = queue_jobs(this, engine, blockMap)
        allDone = true;
        jobCount = 0;
        projObj = engine.load( OI.Data.ProjectDefinition() );
        % Queue up all blocks
        for stackIndex = 1:numel(blockMap.stacks)
            stackBlocks = blockMap.stacks( stackIndex );
            for blockIndex = stackBlocks.usefulBlockIndices(:)'
                blockInfo = stackBlocks.blocks( blockIndex );
                if ~isfield(blockInfo,'indexInStack')
                    overallIndex = blockInfo.index;
                    blockInfo.indexInStack = ...
                        find(arrayfun(@(x) x.index == overallIndex, ...
                            blockMap.stacks( stackIndex ).blocks));
                end
                
                % Create the block object template
                blockObj = OI.Data.Block().configure( ...
                    'STACK',num2str( stackIndex ), ...
                    'BLOCK', num2str( blockInfo.indexInStack ) ...
                    );
                resultObj = OI.Data.BlockResult(blockObj, 'InitialPsPhase').identify( engine );

                % Create a shapefile of the block
                blockName = sprintf('Stack_%i_block_%i',stackIndex,blockIndex);
                blockFilePath = fullfile( projObj.WORK, 'shapefiles', this.id, blockName);

                % Check if the block is already done
                priorObj = engine.database.find( resultObj );
                if ~isempty(priorObj) && exist(blockFilePath,'file')
                    % Already done
                    continue
                end
                jobCount = jobCount+1;
                allDone = false;
                engine.requeue_job_at_index( ...
                    jobCount, ...
                    'BLOCK', blockIndex, ...
                    'STACK', stackIndex);
            end
        end

        if allDone
            engine.save( this.outputs{1} )
        end
        
    end % queue_jobs

    function datetimes = get_time_series(engine, stackInd, segInd)
        cat = engine.load( OI.Data.Catalogue() );
        stacks = engine.load( OI.Data.Stacks() );
        segmentInds = stacks.stack( stackInd ).correspondence( segInd,:);
        safeInds = stacks.stack( stackInd ).segments.safe(segmentInds);
        datetimes = arrayfun(@(x) x.date.datenum, [cat.safes{safeInds}]);
    end

end % methods


methods (Static = true)
    function previewKmlPath = preview_block(projObj, blockInfo, dataToPreview, dataCategory)
        % get the block extent
        sz = blockInfo.size;
        dataToPreview = reshape(dataToPreview, sz(1), sz(2), []);
        
        if nargin < 5
            cLims = [0 1];
        end

        imageColormap = jet(256);
        imageColormap(1,:) = [0 0 0];

        switch dataCategory
            case 'Coherence'
                imageColormap = gray(256);
            case 'Velocity'
                clims = [-1 1] * 0.01; % typical vals
            %     jet = imageColormap;
            case 'HeightError'
                clims = [-1 1] * 80; % typical vals
            %     jet = imageColormap;
            otherwise

        end
        dataToPreview = OI.Functions.grayscale_to_rgb(dataToPreview, imageColormap);
      
        blockExtent = OI.Data.GeographicArea().configure( ...
            'lat', blockInfo.latCorners, ...
            'lon', blockInfo.lonCorners );
        blockExtent = blockExtent.make_counter_clockwise();

        % preview directory
        previewDir = fullfile(projObj.WORK,'preview','block', dataCategory);
        blockName = sprintf('%s_stack_%i_block_%i',dataCategory, blockInfo.stackIndex, blockInfo.indexInStack);

        previewKmlPath = fullfile( previewDir, [blockName '.kml']);
        previewKmlPath = OI.Functions.abspath( previewKmlPath );
        OI.Functions.mkdirs( previewKmlPath );

        % save the preview kml
        blockExtent.save_kml_with_image( ...
            previewKmlPath, dataToPreview, cLims);
    end

    function I = grayscale_to_rgb( grayImage, cmap )
        minValue = double(min(grayImage(:)));
        maxValue = double(max(grayImage(:)));
        normalized_array = (your_2d_array - minValue) / (maxValue - minValue);
        
        % Get the colormap and rescale it to match the grayscale image limits
        cmapIndex = round(1 + (size(cmap, 1) - 1) * normalized_array);
        cmapIndex = max(cmapIndex, 1);
        cmapIndex = min(cmapIndex, size(cmap, 1));
        
        % Convert the grayscale image to an RGB image using the colormap
        I = ind2rgb(cmapIndex, cmap);
    end

end % methods (Static = true)

end % classdef