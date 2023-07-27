classdef BlockPsiAnalysis < OI.Plugins.PluginBase
    
properties
    inputs = {OI.Data.Blocking()}
    outputs = {OI.Data.BlockPsiSummary()}
    id = 'BlockPsiAnalysis'
    STACK = ''
    BLOCK = []
end

methods
    function this = Blocking( varargin )
        this.isArray = true;
        this.isFinished = false;
    end    


    function this = run(this, engine, varargin)
    end

end % methods

end % classdef