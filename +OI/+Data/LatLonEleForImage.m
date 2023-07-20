classdef LatLonEleForImage < OI.Data.DataObj

properties
    % name = 'AsfQueryResults';
    id = 'LatLonEleForImage_stack_$STACK$_segment_$SEGMENT_INDEX$';
    generator = 'Geocoding';
    STACK = '';
    SEGMENT_INDEX = '';
end%properties

methods
    function this = LatLonEleForImage( ~ )
        this.hasFile = true;
        this.filepath = '$WORK$/geocoding/$id$';
        % this.fileextension = 'tiff'; % TODO, get Tiff working!
        this.fileextension = 'mat';
        this.isUniqueName = true;
    end%ctor
end%methods

end%classdef