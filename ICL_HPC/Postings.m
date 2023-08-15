classdef Postings
    properties
        postingPath;
        workPath;
        workers;
        prefix='W';
        suffix='.worker';
        jobline='';
        
    end
    
    methods
        % Constructor from MtiProject object.
        function obj=Postings(project)
            obj.postingPath=fullfile(strrep(project.WORK,'/work','/') ,'postings/');
            obj.workPath=project.WORK;
        end

        function fp = get_posting_filepath(obj, J)
            fp=fullfile(obj.postingPath,sprintf('%s%i%s',obj.prefix,J,obj.suffix));
        end

        function contents = get_posting_contents(obj, J)
            fp=obj.get_posting_filepath(J);
            fid=fopen(fp,'r');
            contents=fgetl(fid);
            if isnumeric(contents) && contents == -1 %???
                contents='';
            end
            fclose(fid);
        end


        function status = post_job(obj, J, jobline)
            fp=obj.get_posting_filepath(J);
            fid=fopen(fp,'w');
            status = fwrite(fid,['JOB=' jobline]);
            fclose(fid);
            fprintf(1,'Worker %i has been assigned: %s\n',J,jobline);
        end

        % Just makes the folder, if necessary
        function first_time_setup(obj)
            if ~exist(obj.postingPath,'dir')
                mkdir(obj.postingPath);
            end
        end
        
        % Look for job requests
        function obj=find_workers(obj)
            wDir=dir(obj.postingPath);
            nFile=numel(wDir);
            isWorker=zeros(nFile,1);
            for ii=1:numel(wDir)
                fName=wDir(ii).name;
                if numel(fName)>8
                   if contains(fName,obj.suffix)
                       split = strsplit(fName,{obj.prefix,obj.suffix});
                       wid=str2num(split{2}); %#ok<ST2NM> - performance ok
                       isWorker(ii)=wid;
                   end
                end
            end
            workerList=unique(isWorker);
            workerList(workerList==0)=[];
            obj.workers=workerList;
        end

        % get the next ready worker
        function [nextReadyWorker, nextWaitingWorker] = get_next_worker(obj)
            nextWaitingWorker = 0;
            nextReadyWorker = 0;
            alreadyFoundWaitingWorker = false;
            for ii=1:numel(obj.workers)
                J=obj.workers(ii);
                [tfReady, tfWaiting]=check_ready(obj,J);
                if (J>0) && tfReady
                    nextReadyWorker = J;
                    return
                end                
                if tfWaiting && ~alreadyFoundWaitingWorker
                    nextWaitingWorker=J;
                    alreadyFoundWaitingWorker = true;
                end
                % else not ready and not waiting
            end
        end
        
        function obj=report_ready(obj,J)
            % check theres not anything useful in the file
            fp = get_posting_filepath(obj, J);
            if exist(fp,'file')
                contents = get_posting_contents(obj, J);
                if ~isempty(contents)
                    if strcmpi(contents,'READY')
                        return
                    end
                    disp(['Worker ' num2str(J) ' has a job: ' contents])
                    while OI.Compatibility.contains(contents,'_ANSWER=')
                        % theres data for someone else to handle here.
                        disp('waiting a bit for someone to accept my answer')
                        pause(10);
                        contents = get_posting_contents(obj, J);
                    end
                end
            end

            fid=fopen(obj.get_posting_filepath(J),'w');
            fwrite(fid,'READY');
            fclose(fid);
            obj.jobline='';
        end
        
        function report_recieved(obj,J)
            fid=fopen(obj.get_posting_filepath(J),'w');
            tempstring=sprintf('RECEIVED%s',obj.jobline);
            fwrite(fid,tempstring);
            fclose(fid);
        end
        
        function report_error(obj,J, errmsg)
            fid=fopen(obj.get_posting_filepath(J),'w');
            tempstring=sprintf('ERROR_%s_%s_ANSWER=',errmsg,obj.jobline);
            fwrite(fid,tempstring);
            fclose(fid);
        end

        function report_running(obj,J)
            fid=fopen(obj.get_posting_filepath(J),'w');
            tempstring=sprintf('RUNNING_TIME_%s_%s',datetime("now"),obj.jobline);
            fwrite(fid,tempstring);
            fclose(fid);
        end

        function report_done(obj,J,answer)
            fid=fopen(obj.get_posting_filepath(J),'w');
            tempstring=sprintf('FINISHED%s',obj.jobline);
            if nargin>2 && ~isempty(answer)
                tempstring=[tempstring sprintf('_ANSWER=%s',answer(:)')];
            end
            fwrite(fid,tempstring);
            fclose(fid);
        end

        function update_timings(obj,J,pctDone,timeLeft)
            fid=fopen(obj.get_posting_filepath(J),'w');
            tempstring=sprintf('RUNNING%s,PROPDONE=%i,SECSLEFT=%i,LASTUPDATE=%s,JWORKER=%i',obj.jobline,pctDone,round(timeLeft),datetime("now"),J);
            fwrite(fid,tempstring);
            fclose(fid);
        end
        
        function [TF, tfWaiting]=check_ready(obj,J)
            TF=false;
            tfWaiting=false;

            myPosting=obj.get_posting_filepath(J);
            if ~exist(myPosting,'file') % if I haven't filed for a job
                return
            end
            
            fid=fopen(myPosting,'r');
            line=fgetl(fid);
            fclose(fid);
            
            if isempty(line)||line(1)==-1
                return
            end
            
            if strcmp(line,'READY')
                TF=true;
                return; % I asked for a job and havent got one yet.
            end

            if numel(line)>8 && strcmpi('FINISHED',line(1:8))
                TF=false;
                tfWaiting=true;
                return; % I've finished my job and am waiting for the next one.
            end
            
        end

        function TF=check_break(obj,J)
            TF=false;
            myPosting=obj.get_posting_filepath(J);
            
            if ~exist(myPosting,'file') % if I haven't filed for a job
                return
            end
            
            fid=fopen(myPosting,'r');
            line=fgetl(fid);
            fclose(fid);
            
            if isempty(line)||line(1)==-1
                return
            end
            
            if any(strcmpi(line,{'CANCEL','BREAK'}))
                TF=true;
                return; % Empty. I asked for a job and havent got one yet.
            end
            
        end


        function obj=check_jobs(obj,J)
            obj.jobline=''; % default do nothing
            myPosting=obj.get_posting_filepath(J);
            
            if ~exist(myPosting,'file') % if I haven't filed for a job
                report_ready(obj,J); % write the file
                return % Empty. Will need to wait for orders.
            end
            
            fid=fopen(myPosting,'r');
            line=fgetl(fid);
            fclose(fid);

            if isempty(line)||line(1)==-1
                % Nothing here. We're ready though.
                report_ready(obj,J); % write the file
                return
            end

            if strcmpi(line,'reset')
                obj.jobline='reset';
                return; % Empty. I asked for a job and havent got one yet.
            end

            if strcmp(line,'READY')
                return; % Empty. I asked for a job and havent got one yet.
            end
            
            if contains(line,'JOB=')
                obj.jobline=line;
                return;
            end
        end

        function obj=force_reset(obj,J)
            fid=fopen(obj.get_posting_filepath(J),'w');
            fwrite(fid,'reset');
            fclose(fid);
        end

        function obj = wipe_error(obj,J)

            fid=fopen(obj.get_posting_filepath(J),'r');
            line=fgetl(fid);
            fclose(fid);

            % Check if the posting is an error
            if ~isempty(line) && numel(line) > 6 && strcmp(line(1:6),'ERROR_')
                fid=fopen(obj.get_posting_filepath(J),'w');
                fwrite(fid,'');
                fclose(fid);
            end
        end

        function obj = wipe_all_errors(obj)
            for ii = 1:numel(obj.workers)
                obj = obj.wipe_error( obj.workers(ii) );
            end
        end

        function obj = force_reset_all(obj)
            for ii = 1:numel(obj.workers)
                obj = obj.force_reset(  obj.workers(ii)  );
            end
        end

        function obj = reset_workers(obj)
            has = @(x,y) OI.Compatibility.contains(lower(x),lower(y));
            postingDir = dir(obj.postingPath);
            isPosting = arrayfun(@(x) numel(x.name)>numel(obj.suffix) && OI.Compatibility.contains(x.name,obj.suffix), postingDir);
            postingFiles = postingDir( isPosting );
            for ii = 1:numel( postingFiles )

                hoursOld = 24 * (now() - postingFiles(ii).datenum); %#ok<TNOW1>

                % If more than 30 mins old, and not ready or finished,
                % delete.
                if hoursOld > .5
                    fp = fullfile(obj.postingPath, ...
                        postingFiles(ii).name);
                    p = fileread(fp);
                    if ~has(p,'READY') && ~has(p,'FINISHED')
                        delete(fp);
                    end

                    % if more than an hour old and 'ready', delete
                    if hoursOld > 1 && ~has(p,'FINISHED')
                        delete(fp)
                    end
                end
            end
            

            obj = obj.find_workers();

        end % reset workers

    end % methods
end % classdef
