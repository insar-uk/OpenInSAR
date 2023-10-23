function s = obj2struct( obj )
    % while octave is buggy we cant save objects
    % so we convert them to structs
    % this is a workaround
    % see http://savannah.gnu.org/bugs/?func=detailitem&item_id=34671

    % get the properties of the object
    p = properties( obj );
    
    if isstruct( obj )
        p = fieldnames( obj );
    end

    % get the number of properties
    n = numel( p );

    % preallocate the struct
    s = struct();
    s.class_ = class( obj );

    % loop over the properties
    for i = 1:n
        % get the property
        prop = p{i};

        % get the value of the property
        val = obj.(prop);

        % if the value is an object
        if isobject( val )
            % convert it to a struct
            val = OI.Functions.obj2struct(val);
        end

        % if the value is a cell array of objects
        % we need to check each cell for objects
        if iscell( val )
            for j = 1:numel( val )
                if isobject( val{j} )
                    val{j} = OI.Functions.obj2struct(val{j});
                end
            end
        end

        % check if struct of objects
        if isstruct( val )
            % get the fields
            f = fieldnames( val );

            % get the number of fields
            n = numel( f );

            % check if nonscalar struct
            nVal = numel( val );

            % if nonscalar struct
            if nVal > 1
                for k = 1:nVal
                    % loop over the fields
                    for j = 1:n
                        % get the field
                        field = f{j};

                        % get the value of the field
                        val2 = val(k).(field);

                        % if the value is an object
                        if isobject( val2 )
                            % convert it to a struct
                            val2 = OI.Functions.obj2struct(val2);
                        end

                        % add the field to the struct
                        val(k).(field) = val2;
                    end
                end
                s.(prop) = val;
                continue;
            else
                % loop over the fields
                for j = 1:n
                    % get the field
                    field = f{j};

                    % get the value of the field
                    if isempty(val)
                        continue
                    else
                        val2 = val.(field);
                    end

                    % if the value is an object
                    if isobject( val2 )
                        % convert it to a struct
                        val2 = OI.Functions.obj2struct(val2);
                    end

                    % add the field to the struct
                    val.(field) = val2;
                end
            end
        end

        % add the property to the struct
        s.(prop) = val;
    end
end
