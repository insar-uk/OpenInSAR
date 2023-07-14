function array = normalise(array, dimension)
    % Specify a float array, and optionaly a number corresponding to the
    % dimension being normalised.
    % if dimension is unspecified, normalise each element by its absolute.
    % otherwise normalise the L2 norm along the dimension specified.

    if nargin == 1
        array = array ./ abs(array);
    elseif nargin == 2
        array = array ./ vecnorm(array, 2, dimension);
    else
        error('incorrect usage'),
    end

end