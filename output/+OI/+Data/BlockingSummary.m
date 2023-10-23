classdef BlockingSummary < OI.Data.DataObj
    properties
        generator = 'Blocking'
        id = 'BlockingSummary'
    end % properties

    methods
        function this = BlockingSummary( varargin )
            this.hasFile = true;
            this.filepath = '$WORK$/BlockingSummary';
        end
    end % methods

    methods (Static = true)
       
    end % methods (Static = true)

end % classdef