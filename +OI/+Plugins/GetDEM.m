classdef GetDEM < OI.Plugins.PluginBase
    
    properties
        inputs = {OI.Data.Stacks(), OI.Data.PreprocessedFiles()}
        outputs = {OI.Data.DEM()}
        id = 'GetDEM'
    end
    
    methods

        function this = run( this, engine, varargin )
            

            stacks = engine.load( OI.Data.Stacks() );
			if isempty( stacks )
				return
			end
				
            maxLat = -90;
            minLat = 90;
            maxLon = -180;
            minLon = 180;

            for stackInd = 1:numel(stacks.stack)
                maxLat = max([stacks.stack(stackInd).segments.lat(:); maxLat]);
                minLat = min([stacks.stack(stackInd).segments.lat(:); minLat]);
                maxLon = max([stacks.stack(stackInd).segments.lon(:); maxLon]);
                minLon = min([stacks.stack(stackInd).segments.lon(:); minLon]);
            end

            % directory to save
            workPath = engine.database.fetch('workingDirectory');
            demDir = fullfile(workPath, 'DEM');
            uName = engine.database.fetch('NasaUsername');
            pWord = engine.database.fetch('NasaPassword');

            % Get the DEM
            this.outputs{1}.tiles = OI.Functions.get_srtm_tiles( minLat, maxLat, minLon, maxLon, demDir, uName, pWord);

            % replace platform specific file paths
            projObj = engine.database.fetch('project');
            for ii = 1:numel(this.outputs{1}.tiles)
                % replace with relative path
                this.outputs{1}.tiles{ii} = OI.Data.DataObj.replaceholder(this.outputs{1}.tiles{ii},projObj);
                % replace '\' with '/' for windows compatibility
                this.outputs{1}.tiles{ii} = strrep(this.outputs{1}.tiles{ii},'\','/');
            end
            
            % calculate extents and such
            this.outputs{1} = this.outputs{1}.configure();
            % TODO control this with some option
            % Make previews for each tile
            % for ii = 1:numel(this.outputs{1}.tiles)
            %     previewDir = fullfile(workPath,'preview','DEM');
            %     tileExtent = ...
            %         this.outputs{1}.srtm1_tile_extent( this.outputs{1}.tiles{ii} );
            %     [this.outputs{1}, tileData] = ...
            %         this.outputs{1}.load_tile(ii);
            %     [~, tileId] = fileparts(this.outputs{1}.tiles{ii});
            %     tileName = sprintf('DemTile_%d_%s', ...
            %         ii,tileId);
            %     tileExtent.save_kml_with_image( ...
            %         fullfile(previewDir, [tileName,'.kml']), ...
            %         tileData);
            % end
            engine.save( this.outputs{1} );

        end

    end

    methods (Static = true)
        function dem = get_srtm_dem( minLat, maxLat, minLon, maxLon )
            % Get the DEM
            dem = OI.Data.DEM();
            
            
        end
    end
end
