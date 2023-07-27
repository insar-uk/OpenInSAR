classdef ReferencePsi < OI.Plugins.PluginBase
    properties
        inputs = {OI.Data.Sentinel1SafeDownload(), ...
            OI.Data.Catalogue(), ...
            OI.Data.OrbitSummary() , ...
            OI.Data.PreprocessedFiles(), ...
            OI.Data.GeocodingSummary(), ...
            OI.Data.CoregistrationSummary(), ...
            OI.Data.BlockingSummary() };
            outputs = {OI.Data.PsiSummary()}
        id = 'ReferencePsi'
    end

    methods
        function this = run( this, engine, ~ )
            for ii = 1:numel(this.inputs)
                data = engine.load(this.inputs{ii});
                if isempty(data)
                    return % the engine will queue a job to generate the input
                end
            end
        end
    end

end