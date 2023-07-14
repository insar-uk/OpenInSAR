classdef GeocodingSummary < OI.Data.DataObj
    properties
        generator = 'Geocoding'
        id = 'GeocodingSummary'

    end % properties

    methods
        function this = GeocodingSummary( varargin )
            this.hasFile = true;
            this.filepath = '$WORK$/GeocodingSummary';
        end
    end % methods

    methods (Static = true)
       
    end % methods (Static = true)

end % classdef