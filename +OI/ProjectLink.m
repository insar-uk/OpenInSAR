classdef ProjectLink

properties
    projectPath = ''
    projectLink = 'CurrentProject.xml'
end

properties ( GetAccess = private, SetAccess = private )
    startDirectory = pwd
    repoDirectory = OI.Functions.abspath( fileparts( mfilename('fullpath') ) )
    unix_path = ''
    windows_path = ''
    xmlStruct = struct()
end

methods
    function this = ProjectLink( pathToProjectLink )
        if nargin == 0
            % Use the default path
        elseif nargin == 1
            this.projectLink = pathToProjectLink;
        else
            error( [ ...
            'Incorrect number of arguments\n', ...
            'Either provide no arguments, for the default path %s\n', ...
            'Or provide a path to a project link file\n%s' ...
            ], this.projectLink, this.get_help_text() );
        end
        this = this.debugging_projects();
        if ~isempty(this.projectPath)
            this = this.resolve_relative_path();
        else
            this = this.parse_link_file();
        end
        this.check_project_file_exists();
    end % ProjectLink

    function this = set_new_project(this, ~)
        % this.projectPath = pathToProjectFile;
        % this = this.resolve_relative_path(this);
        % this.check_project_file_exists();
        % OI.Data.XmlFile( this.projectLink )
        warning('Not yet implemented! Needs some changes to XML handling.')
    end % get_project_path

end % methods

methods ( Access = private )
    function this = debugging_projects(this)
        % Set certain default projects depending on specific users who are
        % testing the system on various OSs

        % Define the mapping of user/OS combinations to file paths
        userPaths = containers.Map();
        % userPaths('stewl_windows') = '\\rds.imperial.ac.uk\rds\user\saa116\ephemeral\test_2023_06_21.oi';
        % userPaths('saa116_unix') = '../test_2023_06_21.oi';

        % userPaths('11915_windows') = '\\rds.imperial.ac.uk\rds\user\ws121\ephemeral\test_2023_06_21.oi';
        % userPaths('ws121_unix') = '../test_2023_06_21.oi';

        % Example usage
        if OI.OperatingSystem.isWindows
            OS = 'windows';
            user = getenv('USERNAME');
        elseif OI.OperatingSystem.isUnix
            OS = 'unix';
            user = getenv('USER');
        end

        % Construct the key based on the user and OS
        key = [user, '_', OS];

        % check if the key exists in the map
        if isKey(userPaths, key)
            % Get the file path based on the key
            this.projectPath = userPaths(key);
            return
        end
        % If not, carry on as if nothing happened


    end

    function this = parse_link_file(this)
        % Get the relevant path from the current project file
        try
            this.xmlStruct = OI.Data.XmlFile( this.projectLink ).to_struct();
        catch ERR
            disp(ERR)
            error('Project link file does not appear to be a valid xml file\n%s\n',this.get_help_text());
        end
        % If a relative path is given, resolve it instead of the OS specific ones
        if ~isempty(this.xmlStruct.relative_path)
            this.projectPath = this.xmlStruct.relative_path;
            this = resolve_relative_path(this);
        else
            if OI.compatability.isWindows()
                this = resolve_windows_path(this);
            elseif OI.compatability.isUnix()
                this = resolve_unix_path(this);
            else
                warning('Only Windows and Unix have been tested for this package.')
                this = resolve_unix_path(this);
            end
        end
    end % parse_link_file

    function this = get_project_path(this)
        this = resolve_os_specific_path(this);
    end % get_project_path

    function this = resolve_relative_path(this)
        % resolve any relative paths
        this.projectPath = OI.Functions.abspath( this.projectPath );
    end

    function this = check_project_file_exists(this)
        isProjectFileAvailable = exist(this.projectPath,'file');
        assert( isProjectFileAvailable~=0, sprintf('Project file not found: %s', this.projectPath))
    end % check_project_file_exists

    function this = resolve_os_specific_path( this )
        % Platform specific path
        if OI.compatability.isWindows()
            this = resolve_windows_path(this);
        elseif OI.compatability.isUnix()
            this = resolve_unix_path(this);
        else
            warning('Only Windows and Unix have been tested for this package.')
            this = resolve_unix_path(this);
        end
    end % resolve_os_specific_path

    function this = resolve_unix_path(this)
        % Platform specific path
        try
            this.projectPath = curProjStruct.unix_path;
        catch ERR
            disp(ERR)
            error('No element tagged as ''unix_path'' found.\n%s\n', this.get_help_text());
        end
        this = resolve_relative_path(this);
    end % resolve unix_path

    function this = resolve_windows_path(this)
        try
            this.projectPath = curProjStruct.windows_path;
        catch ERR
            disp(ERR)
            error('No element tagged as ''windows_path'' found.\n%s\n',...
                linkHelpText);
        end
        this = resolve_relative_path(this);
    end % resolve_windows_path

    function helpText = get_help_text( this )
        helpText = sprintf( [ ...
            'Please create a file called %s in the repo root, which contains', ...
            ' a path to a valid project file.', ...
            'Please see the Git repo for an example and further instructions\n'
            ], this.projectLink);
    end % get_help_text

    % function OK = write(this)
    %     % pass - NOT YET IMPLEMENTED
    % end
end % methods ( Access = private )

end % classdef
