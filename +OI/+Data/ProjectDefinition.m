% This is a software for processing MTI deformation data.
% The main 'OpenInSAR' entry point takes command line arguments.
% -project: path to a project file which will be loaded.
% -run: name of a plugin to run.

% Loading a project will initialise a database.
% The database will check for existing files (when requested)
% By instantiating the data object requested, and determining its unique filename
% (which is a method of the data object) which is with respect to the paticulars of the project (such as where the project work directory is)
% A plugin will check it has all available inputs, and then run.
% A plugin runner (in the main entrypoint) will by default check for the existence of the output files, and if they all exist, not run the plugin.

% OpenInSAR:
%   load project into db
%   configure
%   run plugin

% Database
%   check for existing files

% DataObj
%   get filename
%   report missing files and variables
%   create a job to produce a given dataObj

% Plugin
%    validate:
%       check for missing files and variables, add jobs to queue where needed
%    run:
%       run the plugin, produce the output dataObjs

% Engine
%    run jobs in queue
%    run plugins in queue

% % Load a project and request results
% OpenInSAR('project', 'project.xml', 'get', 'PSI_Velocity');
% % This calls a DataFactory to create a PSI_Velocity object
% % This creates a PSI_Velocity object

% % OpenInSAR then calls Engine.load( PSI_Velocity )
% % which calls Database.get(PSI_Velocity)
% % which makes use of the PSI_Velocity.getFilename( engine / project ) method
% % Any variables needed to get the filename are accessed via Engine.load( variable )
% % Database checks for the existence of the file, and if it exists, returns the filename
% % If it doesn't exist, it creates a job to produce it, and adds it to the engine.queue
% % via Engine.addJob(PSI_Velocity)
% % which calls PSI_Velocity.createJob( engine );
% % which can be adapted to take into account paticular settings in the database, such as if theres any different methods requested
% % The engine proceeds to run the next job in the queue.
% % Which is something like CreatePsiVelocityMaps
% % This calls Engine.load( PsiInversionResults ) or something

% % after each call to load we need to handle the output, and return if further work is needed beforehand

% % Eventually we will find something we have data for.
% % Database.get( ProjectDefinition ) will return the project structure

% % Database is just a structure mapping the unique name of an object to its DataObj and filename
% Calling Load will do different things depending on something in the DataObj?

classdef ProjectDefinition < OI.Data.DataObj

properties
    id = 'ProjectDefinition';

    PROJECT_NAME
    
    AOI
    START_DATE
    END_DATE

    TRACKS
    INPUT_DATA_LIST
    POLARIZATION = 'VV,VH,HH';
    PROCESSING_SCHEME

    BLOCK_SIZE = 5000; %m
    MASK_SEA = 1;
    
    HERE
    ROOT
    WORK
    INPUT_DATA_DIR
    OUTPUT_DATA_DIR
    ORBITS_DIR = '$WORK$/Orbits/'
    pathVars = {'HERE','ROOT','WORK','INPUT_DATA_DIR','OUTPUT_DATA_DIR','ORBITS_DIR'}


    SECRETS_FILEPATH = '$HERE$/secrets.txt'
end

methods 

    function this = ProjectDefinition( filename )
        if nargin > 0
            this = OI.Data.ProjectDefinition.load_from_file( filename );
        end
    end

    
    function str = to_string( this )
        str = sprintf( '# Project Definition:\n' );
        props = properties( this );
        for i = 1:length(props)
            switch props{i}
                case 'filepath'
                    continue;
                case 'name'
                    continue;
                case 'generator'
                    continue;
                case 'fileextension'
                    continue;
                case 'ROOT'
                    continue;
                case 'WORK'
                    continue;
                case 'HERE'
                    continue;
                case 'hasFile'
                    continue;
                
                otherwise
                    if OI.Compatibility.is_string( this.(props{i}) )
                        str = sprintf( '%s\t%s=%s\n', str, props{i}, this.(props{i}) );
                    else
                        str = sprintf( '%s\t%s=%s\n', str, props{i}, this.(props{i}).to_string() );
                    end
            end
        end
    end%to_string

end% methods

methods (Static)

    function this = load_from_file( filename )
        this = OI.Data.ProjectDefinition();
        this.filepath = filename;

        % get the root directory of the OpenInSAR script
        this.ROOT = fileparts(fileparts(fileparts( mfilename( 'fullpath' ) )));
        % get the directory of the project definition file
        hereFolder = fileparts(filename);
        if isempty(hereFolder)
            hereFolder = pwd;
        end
        this.HERE = fullfile( hereFolder );

        % read in file
        fId = fopen( filename, 'r' );
        file = fread( fId, Inf,  '*char' )';
        fclose( fId );

        % split into lines
        lines = strsplit( file,'\n' );
        
        % remove anything after a # (comments)
        lines = cellfun( @(x) strsplit( x, '#' ), lines, 'UniformOutput', false );
        lines = cellfun( @(x) x{1}, lines, 'UniformOutput', false );

        % remove empty lines
        lines = lines( ~cellfun( @isempty, lines ) );

        % split into key/value pairs
        kv = cellfun( @(x) strsplit( x, '=' ), lines, 'UniformOutput', false );

        % remove spaces
        kv = cellfun( @(x) cellfun( @(y) strtrim(y), x, 'UniformOutput', false ), kv, 'UniformOutput', false );

        % remove empty cells
        kv = cellfun( @(x) x( ~cellfun( @isempty, x ) ), kv, 'UniformOutput', false );


        % Set the properties
        for i = 1:length(kv)
            if isempty( kv{i} )
                continue;
            end
            key = kv{i}{1};
            value = kv{i}{2};
            if numel(value) && value(end) == ';'
                value = value(1:end-1);
            end

            switch key
                case 'PROCESSING_SCHEME'
                    this.PROCESSING_SCHEME = value;
                case 'INPUT_DATA_LIST'
                    this.INPUT_DATA_LIST = value;
                case 'INPUT_DATA_DIR'
                    this.INPUT_DATA_DIR = value;
                case 'OUTPUT_DATA_DIR'
                    this.OUTPUT_DATA_DIR = value;
                    this.WORK = value;
                case 'ORBITS_DIR'
                    this.ORBITS_DIR = value;
                case 'PROJECT_NAME'
                    this.PROJECT_NAME = value;
                    OI.Functions.mkdirs( fullfile( this.HERE, value, 'work' ));
                    OI.Functions.mkdirs( fullfile( this.HERE, value, 'work','preview' ));
                    OI.Functions.mkdirs( fullfile( this.HERE, value, 'input','preview' ));
                    OI.Functions.mkdirs( fullfile( this.HERE, value, 'postings','preview' ));
                case 'AOI'
                    this.AOI = OI.Data.AreaOfInterest( value );
                case 'TRACKS'
                    this.TRACKS = value;
                case {'START_DATE', 'END_DATE'}
                    switch numel(value)
                        case 8
                            this.(key) = OI.Data.Datetime(value,'yyyymmdd');
                        otherwise
                            this.(key) = OI.Data.Datetime(value); % see what we get
                    end
                otherwise
                    try 
                        this.(kv{i}{1}) = kv{i}{2};
                    catch
                        warning( 'Unknown key: %s in file %s', kv{i}{1}, filename );
                    end
            end%switch
        end%read in properties

        % string interpolation of the properties
        props = properties( this );
        for i = 1:length(props)
            if OI.Compatibility.is_string( this.(props{i}) )
                this.(props{i}) = this.string_interpolation( this.(props{i}) );
            end
        end
        % easiest to just do it again...
        for i = 1:length(props)
            if OI.Compatibility.is_string( this.(props{i}) )
                this.(props{i}) = this.string_interpolation( this.(props{i}) );
            end
        end

    end%load constructor
    

end% methods (Static

end