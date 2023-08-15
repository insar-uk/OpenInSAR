classdef BlockPsiSummary < OI.Data.DataObj
    properties
        generator = 'BlockPsiAnalysis'
        id = 'BlockPsiSummary'
    end % properties

    methods
        function this = BlockPsiSummary( varargin )
            this.hasFile = true;
            this.filepath = '$WORK$/BlockPsiSummary';
        end
    end % methods
end % classdef