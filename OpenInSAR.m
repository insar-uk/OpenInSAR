% Main entry point
% This will load projects, run plugins, and get data objects
% Handle command line arguments
% -project: path to a project file which will be loaded.
% -run: name of a plugin to run.
% -get: name of a data object to get.
% -job: string defining a specific job to run.
% -help: display help

% Properties are an instance of the engine class
% an instance of a ui for logging
% and a configuration structure
classdef OpenInSAR 

properties
    engine = OI.Engine();
    ui = OI.UserInterface();
    configuration = struct( ...
        'isActive',true, ...
        'isRunningAutomatically',false, ...
        'isDebug',false ...
        );
end

methods
    function this = OpenInSAR(varargin)
        if nargin ~= 0
            % Handle command line arguments
            this = this.parse_args(varargin{:});
        end
        if this.configuration.isActive
            % Run main
            this = this.main();
        end
        this.configure();
    end

    function this = parse_args( this, varargin )

        for i = 1:2:nargin-1
            switch varargin{i}
                case '-auto'
                    % Run in auto mode
                    this.configuration.isRunningAutomatically = true;
                case '-manual'
                    % Run in manual mode
                    this.configuration.isRunningAutomatically = false;
                case '-get'
                    % Get data object
                    this.engine.load_object(varargin{i+1});
                case '-job'
                    % Run a specific job
                    this.engine.run_job(varargin{i+1});
                case '-log'
                    % Set log level of ui
                    this.ui.set_debug_level(varargin{i+1})

                case '-project'
                    % Load project
                    this.engine.load_project(varargin{i+1});
                case '-run'
                    % Run plugin
                    plugin = PluginFactory(varargin{i+1});
                    this.engine.plugin = plugin;

                otherwise
                    % Unknown argument
                    this.ui.log('error', 'Unknown argument: %s', varargin{i})
            end
        end
    end
                                                                    
    function this = load_object( this, varargin )
        % Load a data object
        % This will check the database for any existing files
        % and add any jobs to the queue where needed
        % This will then return the data object, which can be used to get the filename
        % and run the plugin
        this.ui.log('info', 'Loading a data object \n')
        this.engine.load(varargin{:});
    end

    function this = run_next_job( this )
        % Run the next job in the queue
        this.engine.run_next_job();
    end

    function this = configure(this)
        this.engine.ui = this.ui;
    end

    function this = main(this, varargin)
        this.ui.log('info', 'Starting OpenInSAR main\n');
    end

end

end