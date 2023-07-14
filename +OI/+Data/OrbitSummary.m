classdef OrbitSummary < OI.Data.DataObj
    properties
        generator = 'GetOrbits'
        id = 'OrbitSummary'
        fileCount = 0;
        sceneCount = 0;
    end % properties

    methods
        function this = OrbitSummary( varargin )
            this.hasFile = false;
            this.isUniqueName = false;
        end
    end % methods

    methods (Static = true)
       
    end % methods (Static = true)

end % classdef