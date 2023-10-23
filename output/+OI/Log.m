classdef Log < handle

properties
    messageHistory = {};
    printLevel = 3;
    streamId = 1;
    fileId = 0;
end%properties

properties (Constant = true)

    FATAL = 0;
    ERROR = 1;
    WARNING = 2;
    INFO = 3;
    DEBUG = 4;
    TRACE = 5;

    DEFAULT_LOG_LEVEL = 3;

end%properties

methods 
    function this = Log( printLevel, streamId, filename )
        if nargin > 0 && ~isempty( printLevel )
            this.printLevel = printLevel;
        end%if
        if nargin > 1 && ~isempty( streamId )
            this.streamId = streamId;
        end%if
        if nargin > 2 && ~isempty( filename )
            this = this.write_to_file( filename );
        end%if
    end%function

    function this = log( this, level, message, varargin )

        if nargin == 2 % different usage, default to info level
            if OI.Compatibility.is_string(level)
                message = level;
                message = strrep(message, '\', '\\');
            else
                
                if ~OI.Compatibility.isOctave
                    % just disp and be done
                    disp(level)
                    return
                end
                message = disp(level);
                message = strrep(message, '\', '\\');
                message = [message, '\n'];  
            end%if
            
            level = OI.Log.DEBUG;
        else % normal usage
            level = this.check_level( level );
        end

        % print file and line number if debugging
        if this.printLevel > OI.Log.INFO && level <= this.printLevel
            stack = dbstack;
            % +1 for this function, +1 for the interface function
            if length(stack) > 2
                file = stack(3).file;
                % Get the file name only
                filename = fileparts(file);
                if OI.Compatibility.isOctave
                    filename = file( length(filename)+2:end );
                else
                    filename = file( length(filename)+1:end );
                end
                
                % print 80 dashes
                fprintf(this.streamId, '%s\n', repmat('-', 1, 80));
                fprintf(this.streamId, '# %s : %d : %s\n', filename, stack(3).line, file);

            end%if
        end%if

        % add to history to debug if formatting fails
        this.messageHistory{end+1} = message;

        % format the message
        if nargin > 3
            message = sprintf(message, varargin{:});
        end

        % Replace with formatted message
        this.messageHistory{end} = message;

        % print the message if the log is verbose enough
        if level <= this.printLevel
            fprintf( this.streamId, message);
            if this.fileId ~= 0
                fprintf( this.fileId, message);
            end%if
        end%if
    end%function

    function this = set_debug_level( this, level )
        % check if its a string
        level = this.check_level( level );
        this.printLevel = level;
    end%function
    
end%methods

methods (Access = private)
    function this = write_to_file( this, filename )
        if nargin < 2
            filename = 'log.txt';
        end%if
        % append to this file
        this.fileId = fopen( filename, 'a' );
    end%function

    function level = check_level( this, level )
        if ischar(level)
            level = upper(level);
            if isprop(OI.Log, level)
                level = OI.Log.(level);
            else
                warning( 'Unknown log level %s,Log level must be a string or a number between 0 and 5', level );
                level = this.DEFAULT_LOG_LEVEL;
            end%if
        else 
            if level < 0 || level > 5
                warning( 'Log level must be between 0 and 5' );
            end%if
        end%if
    end%function
end%methods

end%classdef