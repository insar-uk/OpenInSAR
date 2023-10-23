classdef PreprocessedFiles < OI.Data.DataObj
    properties
        generator = 'FilePreProcessor'
        metadata = struct();
        id = 'PreprocessedFiles'
        
    end

    methods
        function this = PreprocessedFiles()
            this.filepath = '$WORK$/PreprocessedFiles';
            this.fileextension = 'mat';
            this.hasFile = true;
        end
    end

end

