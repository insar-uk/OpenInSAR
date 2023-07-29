classdef BlockResult < OI.Data.Block

properties
    type = '';
end%properties

methods
    function this = BlockResult( block, type)
        this.hasFile = true;
        this.id = 'stack_$STACK$_result_$type$_block_$BLOCK$';
        this.filepath = '$WORK$/blocks/$type$/$id$';
        this.fileextension = 'mat';

        this.STACK = block.STACK;
        this.BLOCK = block.BLOCK;
        
        this.type = type;
        
    end%ctor
end%methods

end