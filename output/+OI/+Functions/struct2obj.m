function obj = struct2obj(s)
    % use the class_ field to determine what object it should be.
    % then use the rest of the fields to set the properties of the object.
    % this is a recursive function, so it will work for nested objects.
    % the class_ field is not set as a property of the object.
    % the class_ field is removed from the struct before it is returned.
    % if the struct does not have a class_ field, it is returned as is.
    % if we're parsing an OI.Data.XmlNode then there is some additional
    % logic regarding attributes. 'matlab_type_' is used to convert.

    if isfield(s,'class_') % this should be an object
        if isstruct(s.class_) || isa(s.class_,'OI.Data.XmlNode')
            obj = feval(s.class_.value_);
        else
            obj = feval(s.class_); % create the object
        end
    else % the object is just a struct
        obj = s;
    end % but we still want to check the fields

    fieldNames = fieldnames(s); % get the field names

    for i = 1:length(fieldNames) % loop through the fields
        % if the fieldname is value_ replace the field with this?
        if strcmpi(fieldNames{i},'value_') && ~isempty(s.value_)
            s = s.value_;
            obj = s; %?
            break;
        end
        % skip the class_ field
        if strcmp(fieldNames{i},'class_')
            continue
        end % if ~strcmp(fieldnames{i},'class_')


        % check if s is a non-scalar struct
        if numel(s) > 1 && isstruct(s)
            % if it is, loop through and call this function recursively
            for j = 1:numel(s)
                obj(j) = OI.Functions.struct2obj(s(j));
            end % for j = 1:numel(s)
            return
        % check if the field is a struct
        elseif isstruct(s.(fieldNames{i}))
            % s.(fieldNames{i}).class_.value_
            % if it is a struct, call this function recursively
            obj.(fieldNames{i}) = OI.Functions.struct2obj(s.(fieldNames{i}));
        elseif iscell( s.(fieldNames{i}) ) % it might be an object array
            % (cell array of structs for octave)
            % loop through and convert each element if it is a struct
            for j = 1:length(s.(fieldNames{i}))
                if isstruct(s.(fieldNames{i}){j})
                    obj.(fieldNames{i}){j} = OI.Functions.struct2obj(s.(fieldNames{i}){j});
                else
                    obj.(fieldNames{i}){j} = s.(fieldNames{i}){j};
                end % if isstruct(s.(fieldnames{i}){j})
            end % for j = 1:length(s.(fieldnames{i}))
        elseif isa( s.(fieldNames{i} ), 'OI.Data.XmlNode' )
            1;
            % !! TODO. TYPE HANDLING.
            typeOfThis = [];
            attributes = s.(fieldNames{i}).attributes_; % = matlab_type_="double"
            if ~isempty(attributes)
                % try and get the value of the matlab_type_ attribute
                split = strsplit(attributes,'=');
                % find if any of the split strings contain matlab_type_
                idx = find(~cellfun(@isempty,strfind(split,'matlab_type_'))); 
                if ~isempty(idx)
                    % get the value of the matlab_type_ attribute
                    typeOfThis = split{idx+1};
                    % remove the quotes
                    typeOfThis = typeOfThis(2:end-1);
                end
            end
            % 
            if isempty(typeOfThis) || ... 
               strcmpi(typeOfThis,'char') || ...
               strcmpi(typeOfThis,'string')
                obj.(fieldNames{i}) = s.(fieldNames{i}).value_;
            else
                switch typeOfThis
                case 'double'
                    obj.(fieldNames{i}) = str2double(s.(fieldNames{i}).value_);
                case 'logical'
                    obj.(fieldNames{i}) = logical(str2double(s.(fieldNames{i}).value_));
                end
                
            end
            
        else % otherwise
            % if isprop(obj,(fieldNames{i})) || isstruct(obj)
            if isstruct(obj) || ...
               any(cellfun(@(x) strcmpi(x,fieldNames{i}), properties(obj)))
                obj.(fieldNames{i}) = s.(fieldNames{i});
            else
                if ~isempty(s.(fieldNames{i}))
                    warning('Couldnt set property %s of %s\n',fieldNames{i},class(obj))
                end
            end
        end % if isstruct(s.(fieldnames{i}))
    end

end
%#ok<*STRCLFH> - Octave compatibility