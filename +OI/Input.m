classdef Input < handle

properties (SetAccess = private)
    history = {};

end

methods 

function strEntered = str(this, prompt )
    strEntered = input( prompt, 's' );
    this.history{end+1} = strEntered;
end

end%methods

end%classdef