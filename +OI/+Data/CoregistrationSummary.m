classdef CoregistrationSummary < OI.Data.DataObj
    properties
        generator = 'Coregistration'
        id = 'CoregistrationSummary'
        formatStr = 'coreg_%i_%i'

    end % properties

    methods
        function this = CoregistrationSummary( varargin )
            this.hasFile = true;
            this.filepath = '$WORK$/CoregistrationSummary';
        end
    end % methods

    methods (Static = true)
       
    end % methods (Static = true)

end % classdef