classdef Block < OI.Data.DataObj

properties
    % name = 'AsfQueryResults';
    id = 'stack_$STACK$_polarisation_$POLARISATION$_block_$BLOCK$';
    generator = 'Blocking';
    STACK = '';
    BLOCK = '';
    POLARISATION = '';
    blockInfo = struct();
end%properties

methods
    function this = Block( ~ )
        this.hasFile = true;
        this.filepath = '$WORK$/blocks/data/$id$';
        this.fileextension = 'mat';
    end%ctor
end%methods

end