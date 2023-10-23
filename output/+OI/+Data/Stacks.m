classdef Stacks < OI.Data.DataObj
    properties
        generator = 'Stacking'
        stack = struct();
        id = 'Stacks'
    end % properties

    methods
        function this = Stacks(varargin)
            this.hasFile = true;
            this.filepath = '$workingDirectory$/stacks';
        end

        function tf = needs_load(this)
            tf = numel(fieldnames(this.stack)) == 0;
        end
    end % methods


end % classdef