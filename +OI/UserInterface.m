classdef UserInterface < handle
% Interface class used to abstract the input and output streams.
% Helpful for testing and debugging.
properties
    m_input = OI.Input();
    m_output = OI.Log();
end

methods
	function command = input( this, prompt )
        if this.get_debug_level() > 3
            dbs = dbstack;
            % print callee and line number
            this.log( 4, sprintf('%s: %d\n', dbs(2).name, dbs(2).line));
        end
        % Read a command from the user. Same as input() in Oct/Mat.
		command = this.m_input.str([prompt newline]);
	end

	function log( this, debugLevel, message, varargin)
        % Log a message to the output stream. Similar to fprintf() in Oct/Mat.
        switch nargin
            case 2
                this.m_output = this.m_output.log( debugLevel);
            case 3
                this.m_output = this.m_output.log( debugLevel, message );
            otherwise
                this.m_output = this.m_output.log( debugLevel, message, varargin{:} );
            % otherwise
            %     error('Invalid number of arguments.');
        end
		
	end

    function set_debug_level(this, debugLevel)
        % Set the debug level of the output stream.
        this.m_output = this.m_output.set_debug_level( debugLevel );
    end

    function msgHistory = get_message_history(this)
        % Get the message history of the output stream.
        msgHistory = this.m_output.messageHistory;
    end

    function debugLevel = get_debug_level(this)
        % Get the debug level of the output stream.
        debugLevel = this.m_output.printLevel;
    end
end

end