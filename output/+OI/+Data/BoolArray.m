classdef BoolArray

properties
    arr=uint8([]);
end

methods
    % Octave HATES when you have logical arrays (binary masks) as class member
    % variables. This is a blunt workaround.
    function this = BoolArray( bool )
        this.arr = uint8(bool);
    end

    function out = mask(this)
        out = this.arr == 1;
    end
end

end%classdef
