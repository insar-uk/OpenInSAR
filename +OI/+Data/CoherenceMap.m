classdef CoherenceMap < OI.Data.DataObj
    properties
        generator = 'CoherenceMapping'
        id = 'CoherenceMap'
    end % properties

    methods
        function this = CoherenceMap(varargin)
            this.hasFile = true;
            this.filepath = '$WORK$/$id$';
        end
    end % methods

end % classdef