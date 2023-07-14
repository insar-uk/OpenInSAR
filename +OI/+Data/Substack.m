classdef Substack < OI.Data.DataObj

properties
    % name = 'AsfQueryResults';
    id = 'Substack_stack_$STACK$_polarization_$POLARIZATION$_segment_$REFERENCE_SEGMENT_INDEX$_block_$BLOCK$';
    generator = 'Substacking';
    STACK = '';
    REFERENCE_SEGMENT_INDEX = '';
    SEGMENT_INDEX = '';
    BLOCK = '';
    POLARIZATION = '';
end%properties

methods
    function this = Substack( engine )
        this.hasFile = true;
        this.filepath = '$WORK$/substacks/$id$';
        % this.fileextension = 'tiff'; % TODO, get Tiff working!
        this.fileextension = 'mat';
        this.isUniqueName = true;
    end%ctor

    function this = configure(this, varargin)
        % Set the properties of the DataObj via key value pairs
        for i = 1:2:length(varargin)
            switch upper(varargin{i})
                case {'STACK','TRACK'}
                    this.STACK = varargin{i+1};
                case {'SEGMENT','BURST','REFERENCE_SEGMENT_INDEX'}
                    this.REFERENCE_SEGMENT_INDEX = varargin{i+1};
                case {'BLOCK'}
                    this.BLOCK = varargin{i+1};
                case {'POL', 'POLARISATION', 'POLARIZATION'}
                    this.POLARIZATION = varargin{i+1};
                otherwise
                    if isprop(this, varargin{i})
                        this.(varargin{i}) = varargin{i+1};
                    else
                        warning('Property %s does not exist for %s', varargin{i}, this.id)
                    end
            end
        end
    end

end%methods

end