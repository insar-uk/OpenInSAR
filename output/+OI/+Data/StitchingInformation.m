classdef StitchingInformation < OI.Data.DataObj
    properties
        generator = 'Stitching'
        stack = struct();
        id = 'StitchingInformation'
        
    end

    methods
        function this = StitchingInformation()
            this.filepath = '$WORK$/StitchingInformation';
            this.fileextension = 'mat';
            this.hasFile = true;
        end
    end

end

