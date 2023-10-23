classdef CoregOffsets < OI.Data.DataObj

properties
    % name = 'AsfQueryResults';
    id = 'CoregOffsets_stack_$STACK$_segment_$REFERENCE_SEGMENT_INDEX$_visit_$VISIT_INDEX$';
    generator = 'Coregistration';
    STACK = '';
    SEGMENT_INDEX = '';
    VISIT_INDEX = '';
    REFERENCE_SEGMENT_INDEX = '';
    
    lat
    lon
    inds
    polygon
    
    isCropped
end%properties

methods
    function this = CoregOffsets( ~ )
        this.hasFile = true;
        this.filepath = '$WORK$/coregistration/$id$';
        % this.fileextension = 'tiff'; % TODO, get Tiff working!
        this.fileextension = 'mat';
        this.isUniqueName = true;
    end%ctor
end%methods

end%classdef