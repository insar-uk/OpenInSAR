classdef AsfQueryResults < OI.Data.DataObj

properties
    % name = 'AsfQueryResults';
    id = 'AsfQueryResults';
    generator = 'GetAsfQuery';
end%properties

methods
    function this = AsfQueryResults( engine )
        this.hasFile = true;
        this.filepath = fullfile( this.filepath, 'AsfQueryResults');
        this.fileextension = 'json';
        this.isUniqueName = true;
    end%ctor
end%methods

end%classdef