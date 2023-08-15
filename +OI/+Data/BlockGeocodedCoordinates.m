classdef BlockGeocodedCoordinates < OI.Data.DataObj

properties
    % name = 'AsfQueryResults';
    id = 'stack_$STACK$_block_$BLOCK$_geocoding';
    generator = 'BlockMapping';
    STACK;
    BLOCK;

    lat;
    lon;
    ele;

end%properties

methods
    function this = BlockGeocodedCoordinates( ~ )
        this.hasFile = true;
        this.filepath = '$WORK$/blocks/geocoding/$id$';
        this.fileextension = 'mat';
    end%ctor
end%methods

end