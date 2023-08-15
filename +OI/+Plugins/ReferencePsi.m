classdef ReferencePsi < OI.Plugins.PluginBase
    properties
        inputs = { ...
            OI.Data.Sentinel1DownloadSummary(), ...
            OI.Data.Catalogue(), ...
            OI.Data.OrbitSummary() , ...
            OI.Data.PreprocessedFiles(), ...
            OI.Data.GeocodingSummary(), ...
            OI.Data.CoregistrationSummary(), ... % TODO autoload when required
            OI.Data.BlockingSummary(), ... % TODO autoload when required
            OI.Data.BlockBaselineSummary(), ... % TODO autoload when required
            OI.Data.BlockPsiSummary() ...
            }
            % FOR AUTOLOADING TO WORK, WE NEED A WAY TO PREVENT WORKERS FROM DUPLICATING EFFORT IN GOING BACK TO COREGISTER MISSING DATA
            outputs = {OI.Data.PsiSummary()}
        id = 'ReferencePSI'
    end

    methods
        function this = run( this, engine, ~ )
            for ii = 1:numel(this.inputs)
                data = engine.load(this.inputs{ii});
                if isempty(data)
                    engine.ui.log('debug', 'No data found for %s', this.inputs{ii}.id);
                    return % the engine will queue a job to generate the input
                end
            end
            this.isFinished = true;
            engine.save( this.outputs{1} );
        end
    end

end