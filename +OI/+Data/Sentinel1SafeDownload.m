classdef Sentinel1SafeDownload < OI.Data.DataObj

properties
    id = 'Sentinel1SafeDownload';
    generator = 'DownloadSentinel1Data';
    zippath = '';
end%properties

methods
    function this = Sentinel1SafeDownload()
        this.hasFile = true;
        this.isArray = true;
        this.zippath = ['$INPUT_DATA_DIR$', '#name needs replacing at runtime#'];
        this.filepath = ['$INPUT_DATA_DIR$', '#name needs replacing at runtime#'];
        this.fileextension = '';
    end%ctor

    function jobs = create_array_job( this, engine )
        jobs = {};  

        projObj = engine.load( OI.Data.ProjectDefinition() );
        dlList = engine.load( OI.Data.Sentinel1DownloadList() );
        
        % This should be in plugin.
        % return if no list
        if isempty(projObj) || isempty( dlList )
            return;
        end

        % split the list into lines and format
        dlLines = strsplit( dlList, newline );
        % format the dlList
        for i = 1:numel( dlLines )
            line = strtrim(dlLines{i});
            % skip lines starting with # (comments)
            if isempty(line) || line(1) == '#'
                line = '';
            end
            dlLines{i} = line;
        end
        % remove empty lines
        dlLines = dlLines(~cellfun('isempty',dlLines));
        
        if ~isempty( dlLines )
            % check if there is any instructions from project
            projObj = engine.load( OI.Data.ProjectDefinition() );
            if isprop(projObj,'TRACKS') && ~isempty(projObj.TRACKS)
                tracksToDl = str2num(projObj.TRACKS); %#ok<ST2NM>
            else
                tracksToDl = [];
            end

            if ~isempty(tracksToDl)
                % sort the tracks to download
                oldList = dlLines;
                newList = {};
                ron = zeros(numel(oldList),1);
                for i = 1:numel(oldList)
                    safeSplit = strsplit(oldList{i},'_');
                    trackNum = str2num(safeSplit{7}); %#ok<ST2NM>
                    platform = safeSplit{1}(end-2:end);
                    ron(i) = OI.Data.Sentinel1Safe.aon_to_ron(platform,trackNum);
                end
                % append all tracks with corresponding ron
                for i = 1:numel(tracksToDl)
                    newList = [newList; oldList(ron==tracksToDl(i))];
                    %#ok<*AGROW>
                end
                dlLines = newList;
            end

            % create jobs
            for i = 1:numel( dlLines )
                job = this.create_job_from_url( dlLines{i} );
                job.target = '1';
                % check if the file already exists
                inputDataPath = projObj.INPUT_DATA_DIR;
                ffp = fullfile(inputDataPath,job.arguments{4});
                safePath = strrep(ffp,'.zip','.SAFE');
                manifest = fullfile(safePath,'manifest.safe');
                measurement = fullfile(safePath,'measurement');

                if exist(ffp,'file') && exist(safePath,'dir') && exist(manifest,'file')
                    measureDir = dir(measurement);
                    % check that there are files in the measurement directory
                    if numel(measureDir) > 4
                        allBig = true;
                        total = 0;
                        for ii = 3:numel(measureDir)
                            total = total + measureDir(ii).bytes;
                            if measureDir(ii).bytes < 600e6 % two bursts?
                                allBig = false;
                            end
                        end
                        if allBig || (total > 3e9)
                            engine.ui.log('debug',...
                                ['File already exists.,' ...
                                ' Skipping download of %s \n'],...
                                strrep(ffp,'\','\\'));
                            continue
                        end
                    end
                end
                jobs{end+1} = job;
            end%for
        end%if
    end%array_jobs

    function jobs = create_job( this, engine )
        % create a job to download a single file
        % varargin should be a URL
        jobs = create_array_job( this, engine );
    end%create_job

    function job = create_job_from_url(obj, url)
        % get filename from URL 
        % https://datapool.asf.alaska.edu/SLC/SA/S1A_IW_SLC__1SDV_20230325T175029_20230325T175056_047804_05BE4F_59A4.zip\n
        filename = strsplit( url, '/' );
        filename = filename{end};
        % remove \n
        filename = strrep(filename,'\n','');
        
        job = OI.Job('name',obj.generator,'arguments',{'DesiredOutput',obj.id,'filename',filename,'URL',url});
    end

end%methods

end%classdef