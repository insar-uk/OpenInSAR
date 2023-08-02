classdef BlockPsiAnalysis < OI.Plugins.PluginBase
    
properties
    inputs = {OI.Data.BlockingSummary()}
    outputs = {OI.Data.BlockPsiSummary()}
    id = 'BlockPsiAnalysis'
    STACK = []
    BLOCK = []
end

methods
    function this = BlockPsiAnalysis( varargin )
        this.isArray = true;
        this.isFinished = false;
        % if strcmpi(getenv('USERNAME'),'stewl')
            % this.STACK=1;
            % this.BLOCK=32;
            % this.run();
        % end
    end    


    function this = run(this, engine, varargin)

        blockMap = engine.load( OI.Data.BlockMap() );
        projObj = engine.load( OI.Data.ProjectDefinition() );
        stacks = engine.load( OI.Data.Stacks() );
        if isempty(blockMap) || isempty(projObj) 
            % No block map
            return
        end
        

        % % Set some stuff for debugging
        % if strcmpi(getenv('USERNAME'),'stewl')
        %     % For testing
        %     this.STACK = 1;
        %     this.BLOCK = 32;
        %     blockData = load('P:\\stack_1_polarisation_VV_block_32.mat').data_;
        % end

        if isempty(this.BLOCK)
            % Queue up all blocks
            this = this.queue_jobs(engine, blockMap);
            return
        end

        stack = stacks.stack( this.STACK );
        thisSegment = blockMap.stacks(this.STACK).blocks( this.BLOCK ).segmentIndex;
        thisReferenceVisit = stack.reference.segments.visit( thisSegment ); %#ok<*NASGU>

        % Create the block object template
        blockObj = OI.Data.Block().configure( ...
            'POLARISATION', 'VV', ...
            'STACK',num2str( this.STACK ), ...
            'BLOCK', num2str( this.BLOCK ) ...
            ).identify( engine );

        blockData = engine.load( blockObj );

        if isempty(blockData)
            % No data for this block
            return
        end
        sz = size(blockData);

        % Create data objects
        ampStabObj = OI.Data.BlockResult( blockObj, 'AmplitudeStability' );
        coherenceObj = OI.Data.BlockResult( blockObj, 'Coherence');
        velocityObject = OI.Data.BlockResult( blockObj, 'Velocity' );
        heightErrorObject = OI.Data.BlockResult( blockObj, 'HeightError' );
        
        if ~heightErrorObject.identify(engine).exist()
            % Get the time series and baselines
            baselinesObjectTemplate = OI.Data.BlockBaseline().configure( ...
                'STACK', num2str(this.STACK), ...
                'BLOCK', num2str(this.BLOCK) ...
                ).identify( engine );
            baselinesObject = engine.load( baselinesObjectTemplate );
            timeSeries = baselinesObject.timeSeries(:)';
            kFactors = baselinesObject.k(:)';

            % Get PSC
            amplitudeStability = OI.Functions.amplitude_stability( abs(blockData) );
            pscMask = amplitudeStability(:)>3;
            % Save the amplitude stability
            engine.save( ampStabObj, amplitudeStability );

            %% Do the inversion
            qToPhase = @(q) exp(1i.*q.*kFactors);
            vToPhase = @(v) exp(1i.*v.*timeSeries);
            normz = @(x) x./abs(x);
            mask0s = @(x) OI.Functions.mask0s(x);
            mean_coherence = @(phase2d) mean(abs(sum(normz(phase2d),2)))./size(phase2d,2);
            data2d = reshape(normz(blockData),[],sz(3));
            % avfilt = @(I,x,y) imfilter((I),fspecial('average',[x,y]));

            % APS
            pscCm = data2d(pscMask,:)'*data2d(pscMask,:);
            [eVec, eVal] = eig(pscCm);
            [~, bestPairIndex] = max(diag(eVal));
            aps = eVec(:,bestPairIndex).';

            % height error
            data_residual = data2d.*aps;
            [Cq, q, qi] = OI.Functions.invert_height(data_residual,kFactors); %#ok<*ASGLU>
            
            % velocity
            data_residual = normz(data2d.*aps.*qToPhase(q));
            [Cv,v] = OI.Functions.invert_velocity(data_residual,timeSeries);

            % q, v, and aps now form our initial model
            % lets improve each in turn
            psMask = Cv>.75;

            % APS
            psResidual = data_residual(psMask,:).*conj(aps);
            psCm = psResidual'*psResidual;
            [eVec, eVal] = eig(psCm);
            [~, bestPairIndex] = max(diag(eVal));
            aps = eVec(:,bestPairIndex).';
            data_residual = data2d.*aps.*qToPhase(q).*vToPhase(v);

            % Height
            data_residual = data_residual.*qToPhase(-q);
            [Cq, q, qi] = OI.Functions.invert_height(data_residual,kFactors);
            data_residual = data_residual.*qToPhase(q);

            % Velocity
            data_residual = data_residual.*vToPhase(-v);
            [Cv,v] = OI.Functions.invert_velocity(data_residual,timeSeries);
            data_residual = data_residual.*vToPhase(v);

            fprintf(1,'Mean coherence after constant aps analysis: %.3f\n',mean_coherence(data_residual))
            
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
        else
            C = engine.load( coherenceObj );
            v = engine.load( velocityObject );
            q = engine.load( heightErrorObject );
        end
        
        
        % Save a preview of the v, C and q
        blockInfo = blockMap.stacks(this.STACK).blocks(this.BLOCK);
        OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, C, 'Coherence')
        OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, v .* mask0s(C>.5), 'Velocity')
        OI.Plugins.BlockPsiAnalysis.preview_block(projObj, blockInfo, q .* mask0s(C>.5), 'HeightError')

        % Get block lat/;pm
        blockGeocode = OI.Data.BlockGeocodedCoordinates().configure( ...
            'STACK', num2str(this.STACK), ...
            'BLOCK', num2str(this.BLOCK) ...
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
        % Queue up all blocks
        for stackIndex = 1:numel(blockMap.stacks)
            stackBlocks = blockMap.stacks( stackIndex );
            for blockIndex = stackBlocks.usefulBlockIndices(:)'
                
                % Create the block object template
                blockObj = OI.Data.Block().configure( ...
                    'STACK',num2str( stackIndex ), ...
                    'BLOCK', num2str( blockIndex ) ...
                    );
                coherenceObj = OI.Data.BlockResult(blockObj, 'Coherence').identify( engine );

                % Create a shapefile of the block
                blockName = sprintf('Stack_%i_block_%i',stackIndex,blockIndex);
                blockFilePath = fullfile( projObj.WORK, 'shapefiles', this.id, blockName);

                % Check if the block is already done
                priorObj = engine.database.find( coherenceObj );
                if ~isempty(priorObj) && exist(blockFilePath,'file')
                    % Already done
                    continue
                end

                allDone = false;
                engine.requeue_job( ...
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
    function previewKmlPath = preview_block(projObj, blockInfo, dataToPreview, dataCategory, cLims)
        % get the block extent
        sz = blockInfo.size;
        dataToPreview = reshape(dataToPreview, sz(1), sz(2), []);

        
        switch dataCategory
            case 'Coherence'
                imageColormap = gray(256);
            % case 'Velocity'
            %     jet = imageColormap;
            % case 'HeightError'
            %     jet = imageColormap;
            otherwise
                imageColormap = jet(256);
                imageColormap(1,:) = [0 0 0];
        end

        dataToPreview = OI.Functions.grayscale_to_rgb(dataToPreview, imageColormap);

      
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