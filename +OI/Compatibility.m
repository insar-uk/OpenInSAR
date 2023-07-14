classdef Compatibility

properties (Constant = true)
    isOctave = OI.OperatingSystem.is_octave();
end

methods (Static = true)
    function errorObject = CompatibleError(err)
        if OI.Compatibility.isOctave
            errorObject = err;
            nObj = numel(err.stack);

            % Weird octave bug with some errors not having a stack trace
            if nObj == 0
                dbs = dbstack();
                nStack = numel(dbs);
                % Get stack from debugger instead:
                for i = 1:nStack
                    errorObject.stack(i).file = dbs(i).file;
                    errorObject.stack(i).name = dbs(i).name;
                    errorObject.stack(i).line = dbs(i).line;
                    errorObject.stack(i).column = 0;
                end
            end

            
        else
            errorObject = err; %err?
        end
    end

    function formatStr = format_error(err)
        if OI.Compatibility.isOctave
            err = OI.Compatibility.CompatibleError(err);
        end
        formatStr = err.message;
        for ii=1:numel(err.stack)
            formatStr = [formatStr, ' | ', ...
                err.stack(ii).file ':' err.stack(ii).name ':' num2str(err.stack(ii).line) ];
        end
    end

    function print_error_stack(errorObject)
        
        errorObject = OI.Compatibility.CompatibleError(errorObject);
        
        if OI.Compatibility.isOctave
            % Print the error message, identifier, and stack trace
            fprintf(1, '%s: %s\n', errorObject.identifier, errorObject.message);
            fprintf(1, 'error: called from\n');
            for i = 1:length(errorObject.stack)
                fprintf(1, '\tDB+%i_ %s : %s at line %d, column %d\n', i-1, errorObject.stack(i).file, errorObject.stack(i).name, errorObject.stack(i).line, errorObject.stack(i).column);
            end
        else 
            % print the stack trace in Matlab from MException
            fprintf(1, '%s\n', errorObject.getReport('extended'));
        end
    end

    function typestr = typeinfo(obj)
        % matlab doesn't have typeinfo, so we use class instead
        if OI.Compatibility.isOctave
            typestr = typeinfo(obj);
        else % return whether its object or
            %check if its an obj:
            if isobject(obj)
                typestr = 'object';
            else 
                typestr = class(obj);
            end
        end
    end
    function tf = is_stringy( s )
        tf = isa(s,'char') || isa(s,'string');
    end
    
	function tf = is_string( s )
        tf = isa(s,'char') || isa(s,'string');
	end

    function txt = xml_stringify( inputStruct )
		if OI.Compatibility.isOctave
			txt = OI_Xml_to_text( inputStruct );
		else
			% convert a struct to xml
            txt = OI.Functions.struct2xml(inputStruct);
		end
	end

	function TF = contains(X1,X2)
		if OI.Compatibility.isOctave
			if iscell(X1)
				for ii=1:numel(X1)
					X1{ii}=lower(X1{ii});
				end
				TF=~cellfun('isempty', strfind(X1, lower(X2))); %#ok<STRCL1>
				return
			end

			if iscell(X2)
				for ii=1:numel(X2)
					if strfind(lower(X1), lower(X2{ii})) %#ok<STRIFCND>
						TF=true;
						return
					end
				end
				TF=false;
				return
			end

			if isstring(X1)||all(ischar(X1))
				TF=strfind(X1, X2);
				if isempty(TF) %#ok<STREMP>
					TF=false;
				else
					TF = true;
				end
				return
			end
		else
			TF = contains(X1,X2);
		end%if isOctave
	end%contains
end

end%classdef