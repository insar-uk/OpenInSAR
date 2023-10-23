classdef BlockBaselineSummary < OI.Data.DataObj
    properties
        generator = 'BlockBaselineAnalysis'
        id = 'BlockBaselineSummary'
    end % properties

    methods
        function this = BlockBaselineSummary( varargin )
            this.hasFile = true;
            this.filepath = '$WORK$/$id$';
        end
    end % methods

end % classdef