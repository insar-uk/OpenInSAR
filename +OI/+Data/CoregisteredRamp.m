classdef CoregisteredRamp < OI.Data.DataObj

properties
    id = 'CoregisteredRamp_stack_$STACK$_segment_$SEGMENT_INDEX$';
    generator = 'Coregistration';
    STACK = '';
    SEGMENT_INDEX = '';
end%properties

methods
    function this = CoregisteredRamp( engine )
        this.hasFile = true;
        this.filepath = '$WORK$/coregistration/$id$';
        % this.fileextension = 'tiff'; % TODO, get Tiff working!
        this.fileextension = 'mat';
        this.isUniqueName = true;
    end%ctor
end%methods

end%classdef