classdef DownloadSentinel1Data < OI.Plugins.PluginBase

properties
    inputs = {OI.Data.Sentinel1DownloadList()}
    outputs = {OI.Data.Sentinel1SafeDownload()}
    id = 'DownloadSentinel1Data'
    URL = ''
    currentObj = []
end% properties

methods
    function this = DownloadSentinel1Data()
        % this.name = 'DownloadSentinel1Data';
        this.isArray = true;
    end % constructor

    function this = run(this, engine, varargin)
        varargin = varargin{1};
        % find the varagin key value pairs
        for i = 1:2:length(varargin)
            switch varargin{i}
                case 'URL'
                    this.URL = varargin{i+1};
                    % Set the id of the output to the filename without extension
                    getBaseName = strsplit(this.URL,{filesep,'\','/'});
                    getBaseName = getBaseName{end};
                    this.outputs{1}.id = strrep(getBaseName,'.zip','');
                case 'filename'
                    fp = this.outputs{1}.filepath;
                    firsty = strsplit(fp,'#');
                    firsty = firsty{1};
                    fp = fullfile(firsty,varargin{i+1});
                    this.outputs{1}.zippath = fp;
                    this.outputs{1}.filepath = strrep(fp,'.zip','.SAFE');
                    % Set the id of the output to the filename without extension
                    getBaseName = strsplit(this.outputs{1}.filepath ,{filesep,'\','/'});
                    getBaseName = getBaseName{end};
                    this.outputs{1}.id = strrep(getBaseName,'.SAFE','');
            end% switch
        end% for

        % if a URL isn't specified, this is probably the first call
        % We need to create a load of jobs with each of the URLs
        if isempty(this.URL)
            engine.ui.log('info', 'Creating jobs for downloading Sentinel1 data\n');
            jobs = this.outputs{1}.create_array_job( engine );
            engine.ui.log('info', 'Created %d jobs for downloading Sentinel1 data\n', length(jobs));
            for ii=1:numel(jobs)
                jobs{ii}.target = '1';
                engine.queue.add_job(jobs{ii});
                
            end
            % if no more, set as finished
            if numel(jobs) == 0
                % set the status to complete
                this.isFinished = true;
            else
                this.isFinished = false;
            end
            return

        end% if
        engine.ui.log('info', 'Downloading Sentinel1 data from %s\n', this.URL);

        % download from the url to the output{1}.filepath
        % this will be a zip file
        % call curl
        %  ensure redirects are followed
        %    use username and password
        username = engine.database.fetch('AsfUsername');
        
        password = engine.database.fetch('AsfPassword');

        if isempty(username) || ...
                OI.Compatibility.contains(lower(username),'username')
            error('No username found for ASF')
        end

        username = strtrim(username);
        password = strtrim(password);

        OI.Functions.mkdirs(this.outputs{1}.filepath);
        
        % If the zip file already exists, skip this
        safePath = this.outputs{1}.filepath;
        thisSafeExists = exist(safePath, 'file');
        % easy_debug
        if thisSafeExists
            engine.ui.log('info', 'SAFE Folder %s already exists, skipping download\n', strrep(this.outputs{1}.filepath, '\', '\\'));
        else
            % Create a wget command
            % to download the file
            % continue if the file already exists using -c
            % don't check the certificate

            saferZipPath = this.outputs{1}.zippath;
            % saferZipPath=strrep(saferZipPath,'\','\\');
            sysCall = ...
                sprintf(...
                "wget -c -q -O %s --user=%s --password=%s %s --no-check-certificate", ...
                saferZipPath, username, password, this.URL);
            engine.ui.log('debug','Sys call: %si\n', strrep(sysCall,'\','\\'));
            system(sysCall)
        end% if

        fStruct = dir(safePath);
        startSize = 0;
        if ~isempty(fStruct)
            startSize = fStruct.bytes;
        end
        
        % Check if files are unzipped
        validSafe = ...
            OI.Plugins.DownloadSentinel1Data.check_safe_valid(safePath);

        if validSafe
            engine.ui.log('info', 'File %s already exists, skipping unzip\n', strrep(this.outputs{1}.filepath, '\', '\\'))
            status = 0;
        else
            % unzip the file without making a directory
            outputDirectory = fileparts(this.outputs{1}.filepath);
            
            if OI.OperatingSystem.isUnix
                sysCall = sprintf("unzip -DD -o %s -d %s", this.outputs{1}.zippath, outputDirectory);
                engine.ui.log('debug','Sys call: %si\n', strrep(sysCall,'\','\\'));
                status = system(sysCall);
            else
                sysCall = sprintf('powershell -command "Expand-Archive -Force -Path ''%s'' -DestinationPath ''%s''"',this.outputs{1}.zippath, outputDirectory);
                engine.ui.log('debug','Sys call: %si\n', strrep(sysCall,'\','\\'));
                status = system(sysCall);
            end
        end% if

        engine.ui.log('debug','Status code: %i\n', status);

        % Check if files are unzipped correctly
        validSafe = ...
            OI.Plugins.DownloadSentinel1Data.check_safe_valid(safePath);

        if ~validSafe
            engine.ui.log('error', 'Error unzipping file %s\n', strrep(this.outputs{1}.filepath, '\', '\\'));

            % Wait a min
            pause(30)
            % Check if the size has changed, which indicates its still
            % downloading
            fStruct = dir(safePath);
            endSize = 0;
            if ~isempty(fStruct)
                endSize = fStruct.bytes;
            end
            if endSize == startSize
                engine.ui.log('error', '%s will be deleted\n', strrep(this.outputs{1}.filepath, '\', '\\'));
                % I will try deleting the existing file...
                delete(this.outputs{1}.zippath);
                delete(strrep(this.outputs{1}.zippath,'.zip','.SAFE'));
            end
            this.isFinished = false;
            return;
        end% if

        engine.database.add(this.outputs{1});
        % check the unzipped file exists
        % debug, can remove
        this.currentObj = this.outputs{1};
        this.isFinished = true;

        
    end% run

end% methods

methods (Static = true)

    function idFromUrl = get_id_from_url( url )
        split = strsplit(url,'_');
        split{1} = ['S1' split{1}(end)];
        split(6) = []; % dont need another date
        split(8) = []; % dont need data take id
        [~, split{end}, ~] = fileparts(split{end});
        idFromUrl = strjoin(split,'_');
    end


    function isValid = check_safe_valid( safePath )
        isValid = false;
        manifest = fullfile(safePath,'manifest.safe');
        measurement = fullfile(safePath,'measurement');

        if exist(safePath,'dir') && exist(manifest,'file')
            measureDir = dir(measurement);
            % check that there are files in the measurement directory
            if numel(measureDir) > 4
                allBig = true;
                total = 0;
                for ii = 3:numel(measureDir)
                    total = total + measureDir(ii).bytes;
                    if measureDir(ii).bytes < 500e6 % one burst ish?
                        allBig = false;
                    end
                end
                if allBig || (total > 3e9)
                    % All swaths okay
                    isValid = true;
                end
            end
        end
    end

end

end % classdef