classdef Query

    properties
        url = ''
        inputStruct = struct()
        username = ''
        password = ''
        status
    end

    %#ok<*AGROW> - Queries are not expected to be large

    methods 
        function this = Query( url, inputStruct )
            % check inputs
            if ~OI.Compatibility.is_string(url)
                error('url must be a string');
            end
            if ~isstruct(inputStruct)
                error('inputStruct must be a struct');
            end

            % copy the struct
            this.url = url;
            this.inputStruct = inputStruct;
        end

        function str = to_string(this, doItGently)
            if nargin<2
                doItGently = false;
            end
            % convert the fields to a HTML query string
            str = '';
            fields = fieldnames(this.inputStruct);
            for i = 1:length(fields)
                if i > 1
                    str = [str '&'];
                end
                if doItGently
                    key = this.http_format_gently(fields{i});
                    value = this.http_format_gently(this.inputStruct.(fields{i}));
                else
                    key = this.http_format(fields{i});
                    value = this.http_format(this.inputStruct.(fields{i}));
                end
                str = [str key '=' value];
            end
        end

        function str = format_url(this, url)
            if nargin < 2
                url = this.url;
            end
            if isempty(url)
                error('No url specified');
            end

            % format the url with the query string
            str = [url '?' this.to_string()];
        end

        function str = format_url_gently(this, url)
            if nargin < 2
                url = this.url;
            end
            if isempty(url)
                error('No url specified');
            end

            % format the url with the query string
            str = [url '?' this.to_string(true)];
        end

        function [response, this] = get_response(this)
            % get the response from the url
            str = this.format_url_gently();

            if ~isunix
                req = ['curl -g -s -L "' str '"'];
                % add username and password if they exist
                if ~isempty(this.username)
                    req = [req ' --user ' this.username ':' this.password];
                end
                [this.status, response] = system(req); 
            else % use wget
                req = ['wget -qO-'];
                % add username and password if they exist
                if ~isempty(this.username)
                    req = [req ' --http-user=' this.username ' --http-password=' this.password];
                end
                req = [req ' "' str '"'];
                [this.status, response] = system(req);
            end

        end
    end

    methods (Static)

        function str = http_format_gently(str)
            % just do spaces and parenths
            str = strrep(str, ' ', '%20');
            str = strrep(str, '(', '%28');
            str = strrep(str, ')', '%29');
        end

        function str = http_format(str)
            % convert a string to be http friendly
            str = strrep(str, '%%', '%25');
            str = strrep(str, '&', '%26');
            str = strrep(str, '#', '%23');
            str = strrep(str, '+', '%2B');
            str = strrep(str, ' ', '%20');
            str = strrep(str, '"', '%22');
            str = strrep(str, '<', '%3C');
            str = strrep(str, '>', '%3E');
            str = strrep(str, '{', '%7B');
            str = strrep(str, '}', '%7D');
            str = strrep(str, '|', '%7C');
            str = strrep(str, '\', '%5C');
            str = strrep(str, '^', '%5E');
            str = strrep(str, '~', '%7E');
            str = strrep(str, '[', '%5B');
            str = strrep(str, ']', '%5D');
            str = strrep(str, '`', '%60');
            str = strrep(str, ';', '%3B');
            str = strrep(str, '/', '%2F');
            str = strrep(str, '?', '%3F');
            str = strrep(str, ':', '%3A');
            str = strrep(str, '@', '%40');
            str = strrep(str, '=', '%3D');
            str = strrep(str, '$', '%24');
            str = strrep(str, ',', '%2C');
            str = strrep(str, '''', '%27');
            str = strrep(str, '!', '%21');
            str = strrep(str, '(', '%28');
            str = strrep(str, ')', '%29');
            str = strrep(str, '*', '%2A');
            str = strrep(str, '-', '%2D');
            str = strrep(str, '.', '%2E');
            str = strrep(str, '_', '%5F');
        end
        function str = http_unformat(str)
            % convert a string back to its original form
            str = strrep(str, '%20', ' ');
            str = strrep(str, '%2B', '+');
            str = strrep(str, '%23', '#');
            str = strrep(str, '%26', '&');
            str = strrep(str, '%25', '%%');
            str = strrep(str, '%22', '"');
            str = strrep(str, '%3C', '<');
            str = strrep(str, '%3E', '>');
            str = strrep(str, '%7B', '{');
            str = strrep(str, '%7D', '}');
            str = strrep(str, '%7C', '|');
            str = strrep(str, '%5C', '\');
            str = strrep(str, '%5E', '^');
            str = strrep(str, '%7E', '~');
            str = strrep(str, '%5B', '[');
            str = strrep(str, '%5D', ']');
            str = strrep(str, '%60', '`');
            str = strrep(str, '%3B', ';');
            str = strrep(str, '%2F', '/');
            str = strrep(str, '%3F', '?');
            str = strrep(str, '%3A', ':');
            str = strrep(str, '%40', '@');
            str = strrep(str, '%3D', '=');
            str = strrep(str, '%24', '$');
            str = strrep(str, '%2C', ',');
            str = strrep(str, '%27', '''');
            str = strrep(str, '%21', '!');
            str = strrep(str, '%28', '(');
            str = strrep(str, '%29', ')');
            str = strrep(str, '%2A', '*');
            str = strrep(str, '%2D', '-');
            str = strrep(str, '%2E', '.');
            str = strrep(str, '%5F', '_');
        end
    end


end