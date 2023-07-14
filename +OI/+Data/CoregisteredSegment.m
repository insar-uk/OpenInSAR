classdef CoregisteredSegment < OI.Data.DataObj

properties
    % name = 'AsfQueryResults';
    id = 'CoregisteredSegment_stack_$STACK$_segment_$REFERENCE_SEGMENT_INDEX$_visit_$VISIT_INDEX$_polarization_$POLARIZATION$';
    generator = 'Coregistration';
    STACK = '';
    REFERENCE_SEGMENT_INDEX = '';
    SEGMENT_INDEX = '';
    VISIT_INDEX = '';
    POLARIZATION = '';
end%properties

methods
    function this = CoregisteredSegment( engine )
        this.hasFile = true;
        this.filepath = '$WORK$/coregistration/$id$';
        % this.fileextension = 'tiff'; % TODO, get Tiff working!
        this.fileextension = 'mat';
        this.isUniqueName = true;
    end%ctor
end%methods

end%classdef