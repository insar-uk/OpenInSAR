
classdef Database < handle

    properties
        data = {}
        entryNames = {}
        entryMap = struct()
    end

    methods

        function this = Database()
            this.add(pwd,'workingDirectory');
        end%constructor

        function status = load_project( this, projectFilepath )
            projObj = OI.Data.ProjectDefinition(projectFilepath);
            
            this.clear();
            
            addProjStatus = this.add(projObj,'ProjectDefinition');
            addProjAliasStatus = this.add(projObj,'project');
            addDirStatus = this.add(projObj.OUTPUT_DATA_DIR,'workingDirectory');
            % add each property of projObj as an entry in the database
            projProps = properties(projObj);
            for i = 1:length(projProps)
                if strcmpi( projProps{i}, 'id' )
                    continue;
                end
                this.add(projObj.(projProps{i}), projProps{i});
            end

            status = sprintf('%s\n%s\n%s\n', addProjStatus,addProjAliasStatus, addDirStatus);

            % open prototype/secrets.txt
            % read in the secrets
            % add each secret to the database
            if ~isprop(projObj,'SECRETS_FILEPATH')
                error('No secrets fp in project definition')
            end
            
            if exist( projObj.SECRETS_FILEPATH, 'file' )
                
                secrets = fileread( projObj.SECRETS_FILEPATH );
                secrets = strsplit( secrets, sprintf('\n') ); %#ok<SPRINTFN>
                for i = 1:length(secrets)
                    kv = strsplit( secrets{i}, '=' );
                    this.add( strtrim(kv{2}), strtrim(kv{1}) );
                end
            else
                error('I expected to find a ''secrets'' file containing login data for various services at this location:\n%s\n ...but it was not found',secretsFilepath);
            end

            % preview the aoi
            aoiPreviewFilepath = fullfile( projObj.OUTPUT_DATA_DIR, 'aoi.kml' );
            if ~exist( aoiPreviewFilepath, 'file')
                projObj.AOI.preview_kml( aoiPreviewFilepath );
            end

        end%load_project

        function status = add(this, dataObj, optionalId)

            if ~isa(dataObj, 'OI.Data.DataObj')
                status = sprintf(...
                    'Added a %s called %s to database', ...
                    class(dataObj) , optionalId); %#ok<NASGU>
            end
            
            if nargin > 2
                uName = optionalId;
            else
                uName = dataObj.id;
            end

            if ~isfield(this.entryMap, uName)
                this.entryMap.(uName) = length(this.data) + 1;
                this.data{end+1} = dataObj;
                this.entryNames{end+1} = uName;
                status = sprintf('Added %s to database', uName);
            else
                this.data{this.entryMap.(uName)} = dataObj;
                status = sprintf('Added %s to existing database entry', uName);
            end

        end%add
        
        function dataObj = fetch(this, id)
            if isfield(this.entryMap, id)
                dataObj = this.data{this.entryMap.(id)};
            else
                dataObj = [];
            end
        end%fetch

        function value = fetch_parameter(this, id)
            objOrValue = this.fetch(id);
            if strcmpi(OI.Compatibility.typeinfo(objOrValue), 'object')
                value = objOrValue.value;
            else % pray that it's a value
                value = objOrValue;
            end
        end%fetch

        function entry = find( this, dataObj )
            % Find an entry in the database matching the given data object
            % If the object has a file, check if it exists 
            % and add the data object to the database if it does
            entry = [];
            % Check the database
            if isfield(this.entryMap, dataObj.id)
                entry = this.data{this.entryMap.(dataObj.id)};
                return;
            end
            % Check the file
            if dataObj.hasFile
                if ~dataObj.isUniqueName
                    return
                    %error('OI:Database:find:nonUniqueName', ...
                    %    'Get a unique name before calling this message on obj %s', dataObj.id')
                end
                fp = dataObj.filepath;
                if ~isempty( dataObj.fileextension )
                    fp = [fp '.' dataObj.fileextension];
                end

                tfExists = exist( fp, 'file');
 
                % Add it in if the file exists
                if tfExists
                    if ~dataObj.isArray
                        this.add(dataObj);
                        entry = dataObj;
                    else
                        if dataObj.isUniqueName
                            this.add(dataObj);
                            entry = dataObj;
                        else
                            warning('?!?!123')
                        % DO SOME ARRAY STUFF
                        % TO GET A UNAME
                        end
                    end
                end
            end
        end%find

        function this = clear_database_manually(this)
            yn = input('Do you really want to do that? [y/n]\n','s');
            if ~isempty(yn) && lower(yn(1)) == 'y'
                this = this.clear;
            end
        end

    end

    
    methods (Access = private)
        function this = clear(this)
            this.entryNames = {};
            this.entryMap = struct();
            this.data = {};

        end
    end%private methods
end
