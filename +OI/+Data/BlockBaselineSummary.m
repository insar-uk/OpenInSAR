classdef BlockBaselineSummary < OI.Data.DataObj
    properties
        generator = 'BlockBaselineAnalysis'
        id = 'BlockBaselineSummary'
    end % properties

    methods
        function this = BlockingSummary( varargin )
            this.hasFile = true;
            this.filepath = '$WORK$/$id$';
        end
    end % methods

    methods (Static = true)
       
    end % methods (Static = true)a

end % classdef