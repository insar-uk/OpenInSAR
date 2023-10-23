classdef TextFile < OI.Data.DataObj


methods 

function obj = TextFile(filename)
    [tPath, tName, obj.fileextension] = fileparts(filename);
    obj.filepath = fullfile(tPath, tName);
    obj.isUniqueName = true;
    obj.hasFile = true;
end % constructor

function [OK, bytes] = write(obj, content)
    OK = false;
    if ~ischar(content)
        error('OI:Data:TextFile:write', 'Content must be a string');
    end
    fp = obj.filepath;
    if ~isempty(obj.fileextension)
        fp = [fp, '.', obj.fileextension];
    end
    fid = fopen(fp, 'w');
    bytes = fprintf(fid, '%s', content);
    fclose(fid);
    if bytes > 0
        OK = true;
    end
end % write

end % methods

end % classdef