classdef S1SafeCoordinateArray < OI.Data.DataObj
    properties
        generator = 'S1SafeGeocoding'
        coordinates = struct();
        id = 'S1SafeCoordinateArray'
        
    end

    methods
        function this = S1SafeCoordinateArray()
            this.filepath = '$WORK$/SafeCoordinates';
            this.fileextension = 'mat';
            this.hasFile = true;
        end
    end

end

