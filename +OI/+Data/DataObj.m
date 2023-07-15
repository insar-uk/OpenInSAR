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

classdef DataObj
%#ok<*MCNPR>
%#ok<*MCNPN>
%#ok<*PROP>
%#ok<*PROPLC>
properties

    filepath = '$workingDirectory$/general/';
    fileextension = 'mat';
    % generator = '';
    hasFile = false; % If the DataObj is very large we save it to a file
    isParameter = false; % if the DataObj is very simple...
    value = []; % ...we store simple values here
    isUniqueName = false; % check when unique name has been called
    isArray = false;
    overwrite = false;
end

methods
    function obj = DataObj()
    end

    function tf = needs_load( ~ )
        % overload this to provide logic which determines if a data object
        % needs additional files to be loaded in order to be fully defined.
        tf = true;
    end

    function this = resolve_filename(this, engine)
        this.id = this.string_interpolation(this.id, engine); 
        this.filepath = this.string_interpolation(this.filepath, engine);
        this.fileextension = this.string_interpolation(this.fileextension, engine);
    end

    function [this, jobs] = identify(this, engine)
        jobs = {}; % pass
        this.id = this.string_interpolation(this.id, engine); 
        this.filepath = this.string_interpolation(this.filepath, engine);
        if ~any(find(this.filepath=='$')) && ~any(find(this.id=='$'))
            this.isUniqueName = true;
            return % we have the name and we're getting out
        end

        % If a file should exist and doesn't, create a job to produce it
        if this.hasFile
            engine.ui.log('info', 'Checking for %s\n', strrep(this.filepath, '\', '\\' ) );
            % dbstop in easy_debug at 1
            % easy_debug
            thisShouldBeMe = engine.database.fetch(this);
            if isempty(thisShouldBeMe)
                engine.ui.log('info', 'File %s does not exist, creating job to produce it\n', this.id);
                jobs = this.create_job( engine );
            else
                engine.ui.log('info', 'Object %s found in database\n', this.id);
                this = thisShouldBeMe;
            end
        end
    end

    function this = configure(this, varargin)
        % Set the properties of the DataObj via key value pairs
        for i = 1:2:length(varargin)
            if isprop(this, varargin{i})
                this.(varargin{i}) = varargin{i+1};
            else
                warning('Property %s does not exist for %s', varargin{i}, this.id)
            end
        end
    end

    function tf = exists(this)
        tf = false;
        nameIsResolved = ~any(find(this.filepath=='$')) ;

        if this.hasFile && nameIsResolved
            filepath = [this.filepath]; 
            if ~isempty( this.fileextension )
                filepath = [filepath '.' this.fileextension];
            end
            tf = exist(filepath, 'file');
        end
    end

    function jobs = create_job(obj, engine)
        engine.ui.log('info', 'create_job method called on obj %s\n', obj.id);
        engine.ui.log('info', 'Creating job to produce %s\n', strrep(obj.filepath, '\', '\\' ) );
        if isprop(obj,'id')
            jobs = {OI.Job('name',obj.generator,'arguments',{'DesiredOutput',obj.id})};
        else
            jobs = {OI.Job('name',obj.generator)};
        end
    end

    function [data, jobs] = load(obj, engine)
        data = [];
        jobs = {};

        isLogging = nargin > 1;


        if ~obj.isUniqueName
            error('run identify on this obj first')
        end
        if obj.hasFile
            filepath = [obj.filepath]; 
            if ~isempty( obj.fileextension )
                % dont add the extension if its already there...
                if ~strcmp(obj.fileextension, obj.filepath(end-length(obj.fileextension)+1:end))
                    if obj.fileextension(1) == '.'
                        obj.fileextension = obj.fileextension(2:end);
                    end
                    filepath = [filepath '.' obj.fileextension];
                end
            end

            % if the file doesn't exist, create a job to produce it
            % filepath
            if ~exist(filepath, 'file')
                if isLogging
                    engine.ui.log('info', 'File %s does not exist, creating job to produce it\n', filepath);
                end
                if any(filepath=='$')
                    if nargin < 2
                        error('Placeholders in object path but no info supplied to fix them');
                    end
                end
                if nargin < 2
                    error('File %s does not appear to exist, and no oi.engine was supplied to create a job.\n', filepath);
                end
                jobs = obj.create_job( engine );
                return
            end

            if isLogging
                engine.ui.log('debug', 'Loading %s\n', strrep(filepath, '\', '\\' ) );
            end

            switch obj.fileextension
                case {'mat',''}
                    data = load(filepath);
                    if isstruct(data) && isfield(data, 'data_')
                        data = data.data_;
                    end
                    % if OI.Compatibility.isOctave
                    %   easy_debug
                    if isnumeric(data)
                        % thats it
                        return
                    end
                      data = OI.Functions.struct2obj(data);
                    % end%if
                case 'tif'
                    data = imread(filepath);
                case {'txt', 'csv', 'json', 'xml', 'EOF' }
                    % read plain text
                    fid = fopen(filepath, 'r');
                    % preserver newlines
                    data = fread(fid, '*char')';
                    fclose(fid);
                case {'SAFE'}
                    % get the project to replace the vars
                    projObj = engine.database.fetch('project');
                    % return the object
                    data = obj;
                    obj.filepath = obj.deplaceholder( obj.filepath, projObj );
                    obj.orbitFile = obj.deplaceholder( obj.orbitFile, projObj );
                otherwise
                    error('Unknown file extension %s', obj.fileextension)
            end%switch
        else
            data = obj.value;
        end
    end

    function status = save(obj, data_, engine)
        status = 'not saved'; %#ok<NASGU>
        filepath = [obj.filepath];
        if ~isempty( obj.fileextension )
            filepath = [filepath '.' obj.fileextension];
        end
        engine.ui.log('info', 'Saving %s\n', strrep(filepath, '\', '\\' ) );


        OI.Functions.mkdirs(obj.filepath);
        switch obj.fileextension
            case {'mat',''}
                % if OI.Compatibility.isOctave && isobject( data_ )

                if isobject( data_ )
                    % easy_debug
                    data_ = OI.Functions.obj2struct(data_);
                end
                % dbstop here
                % here
                fp = [obj.filepath, '.' obj.fileextension];
                if ~exist(fileparts(fp),'dir')

                    OI.Functions.mkdirs(fp);
                end
                save(fp, 'data_','-v7');
                status = 'saved';
            case {'tif','tiff'}
                imwrite(data_, obj.filepath);
                status = 'saved';
            case {'txt', 'csv', 'json'}
                % write plain text
                fid = fopen(filepath, 'w');
                % ensure all \n characters are converted to newlines
                data_ = strrep(data_, '\n', sprintf('\n')); %#ok<SPRINTFN>
                fprintf(fid, '%s', data_);
                fclose(fid);

                status = 'saved';
            otherwise
                error('Unknown file extension %s', obj.fileextension)
        end
    end

    function this = deplaceholder(this, projObj)

        newString = this.filepath;
        for placeholderPath=projObj.pathVars(:)'
            if ~any(newString == '$')
                break
            end
            newString = ...
                strrep(oldString, ...
                    ['$' placeholderPath{1} '$'], ...
                    projObj.(placeholderPath{1}));
        end
        this.filepath = newString;

    end

    % replace variables in the filepath with the actual values
    function str = string_interpolation(this, str, engine)

        % If there are no variables, return
        if ~any(find(str=='$')), return; end
        % Find all variables in the string
        var_regex = '\$[a-zA-Z0-9_]+\$';
        vars = regexp(str, var_regex, 'match');

        % Loop through all variables and replace them with the actual values
        % from this object
        props = properties(this);
        for v = vars
            var = v{1};
            vName = var(2:end-1); % remove the $ signs
            if any(strcmp(props, vName))
                value = this.(vName);
                if ~isempty(value)
                    str = strrep(str, var, value);
                end
            end
        end

        % Exit if no more variables
        if ~any(find(str=='$')), return; end
        % or if we don't have means to get variables from database
        if nargin<3, return; end
        % update otherwise
        vars = regexp(str, var_regex, 'match');

        for v = vars
            var = v{1};
            vName = var(2:end-1); % remove the $ signs

            value = engine.database.fetch_parameter(vName);
            % if isempty(value)
            %     warning('this is silly, make sure you put the param in the database rather than relying on reflection')
            %     % try to parameterise the variable
            %     vObj = this.object_from_name(vName);
            %     % if we somehow managed to get a DataObj
            %     if ~isempty(vObj)
            %         vObj = vObj.copy_parameters(this);
            %         % OI load will add to queue if missing
            %         value = engine.load(vObj);
            %     end
            % end

            if isempty(value)
            %     warning('Could not find value for variable %s', vName)
                return;
            end

            str = strrep(str, var, value);
        end
    end

    function this = copy_parameters( this, templateObj )
        % Copy the parameters from the template object to the data object
        % if the property exists in the data object
        template_props = properties(templateObj);
        props = properties(this);

        % loop through the properties
        for p = props
            prop = p{1};
            if any(strcmp(prop, {'id', 'generator', 'filepath', 'fileextension'}))
                continue;
            end
            % if the property is in the template
            if any(strcmp(template_props, prop))
                % copy the value
                this.(prop) = templateObj.(prop);
            end
        end
    end
end


methods (Static)

    function newString = replaceholder(oldString, projObj)
        for placeholderPath=projObj.pathVars(:)'
            newString = ...
                strrep(oldString, ...
                    projObj.(placeholderPath{1}), ...
                    ['$' placeholderPath{1} '$']);
            if numel(newString) < numel(oldString)
                break
            end
        end
    end

    function newString = deplaceholder_string(oldString, projObj)
        newString = oldString;
        if ~any(find(oldString=='$')), return; end
        
        for placeholderPath=projObj.pathVars(:)'
            newString = ...
                strrep(newString, ...
                    ['$' placeholderPath{1} '$'], ...
                    projObj.(placeholderPath{1}));
        end
    end

    function dataObj = object_from_name( vName )
        % get the class name
        className = vName;

        % anything following a hyphen is a parameter not the class name
        hyphen = find(vName=='-');
        if ~isempty(hyphen)
            className = vName(1:hyphen-1);
        end

        % remove file extension
        dot = find(className=='.',1,'last');
        if ~isempty(dot)
            className = className(1:dot-1);
        end

        % remove any path
        slashes = sum( uint8(className) == [uint8('/'); uint8('\')] );
        slash = find(slashes,1,'last');
        if ~isempty(slash)
            className = className(slash+1:end);
        end


        try
            % get the constructor
            constructor = str2func(className);
            % construct the object
            dataObj = constructor();
        catch
            warning('Could not find constructor for %s',className)
        end
        try
            % try with OI.Data.
            constructor = str2func(['OI.Data.' className]);
            dataObj = constructor();
        catch
            warning('Could not find constructor for OI.Data.%s',className)
        end
        if ~exist('dataObj','var')
            dataObj = [];
            warning('Could not find class %s', className)
        end
    end

end% methods (Static)

end% classdef
