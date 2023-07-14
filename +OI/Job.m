classdef Job

properties
    name = 'EmptyJob';
    target = '';
    arguments = {};
end

properties (SetAccess = private, GetAccess = private)
    validFields = { 'name', 'target', 'arguments'};
end
%#ok<*AGROW> - jobs as strings are small, so we can grow them

methods 
    function obj = Job(varargin)

        if nargin == 0 || (nargin == 1 && isempty(varargin{1}))
            return
        end

        if nargin == 1
            if ischar(varargin{1})
                arg = varargin{1};
                if numel(arg)<3 || ~strcmp(arg(1:3),'Job')
                    obj.name = arg;
                else
                    obj = parse_from_string(obj,varargin{1});
                end
            elseif isstruct(varargin{1})
                obj = parse_from_struct(obj,varargin{1});
            elseif isa(varargin{1},'Job')
                obj = varargin{1};
            else
                error('Job:Job','Job constructor requires a string, struct, Job object, or even number property/value pairs');
            end
        
        elseif mod(nargin,2) == 0
            % check the args match the properties
            if mod(nargin,2) ~= 0
                error('Job:Job','Unknown arguments to Job constructor requires an even number of arguments (property,value)');
            end

            for i = 1:2:nargin
                if ~isprop(obj,varargin{i})
                    warning('Job:Job','Ignoring Job property ''%s'': does not exist',varargin{i})
                    continue
                end
                obj.(varargin{i}) = varargin{i+1};
            end
        else 

        end

    end

    function keysAsCsv = get_arg_keys( this )
        keysAsCsv = '';
        for i = 1:2:length(this.arguments)
            keysAsCsv = [keysAsCsv this.arguments{i} ','];
        end
        keysAsCsv = keysAsCsv(1:end-1);
    end

    function this = parse_from_string(this,jobStr)
        % parse a string into a Job object
        % jobStr should be of the form:
        % Job('name','target',{'arg1','arg2',...})

        % remove the Job() wrapper
        jobStr = jobStr(5:end-1);

        % split the string into name, target, and arguments
        [jobName,jobStr] = strtok(jobStr,',');
        [jobTarget,jobStr] = strtok(jobStr,',');
        
        % remove the quotes
        jobName = jobName(2:end-1);
        jobTarget = jobTarget(2:end-1);
        % remove the braces
        jobStr = jobStr(3:end-1);
        jobArguments = strsplit(jobStr,',');
        
        for i = 1:length(jobArguments)
            if isempty(jobArguments{i})
                continue
            end
            % if quotes, string, else numeric
            if jobArguments{i}(1) == '''' && jobArguments{i}(end) == ''''
                jobArguments{i} = jobArguments{i}(2:end-1);
            else
                jobArguments{i} = str2num(jobArguments{i}); %#ok<ST2NM>
            end
        end

        % set the properties
        this.name = jobName;
        this.target = jobTarget;
        this.arguments = jobArguments;
    end

    function this = parse_from_struct(this,jobStruct)
        % parse a struct into a Job object
        % jobStruct should be of the form:
        % struct('name','name','target','target','arguments',{'arg1','arg2',...})

        % check the fields
        if ~all(isfield(jobStruct,this.validFields))
            error('Job:parse_from_struct','Job struct must have fields ''name'', ''target'', and ''arguments''');
        end

        % set the properties
        this.name = jobStruct.name;
        this.target = jobStruct.target;
        this.arguments = jobStruct.arguments;
    end

    function jobStr = to_string(this)
        jobStr = sprintf('Job(''%s'',''%s'',{',this.name,this.target);
        for i = 1:length(this.arguments)
            % append empty args as ''
            if isempty(this.arguments{i})
                jobStr = [jobStr ''','];
                continue
            end
            switch class (this.arguments{i})
                case 'char'
                    jobStr = [jobStr '''' this.arguments{i} ''','];
                case {'double', 'single', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64', 'logical'}
                    % determine required precision
                    if isinteger(this.arguments{i}) | all(this.arguments{i} == round(this.arguments{i})) %#ok<OR2> not scalar, shut up
                        jobStr = [jobStr num2str(this.arguments{i}) ','];
                    else
                        jobStr = [jobStr num2str(this.arguments{i},'%0.16f') ','];
                    end
                otherwise
                    error('Job:to_string','Job arguments must be strings or numeric/bool');
            end
            % jobStr = [jobStr '''' d ''','];
        end
        jobStr = [jobStr(1:end-1) '})'];
    end

    function tf = eq(this,that)
        thisStr = this.to_string();
        thatStr = that.to_string();

        tf = strcmpi(thisStr,thatStr);
    end

end

end%classdef