if ~exist('J','var')
    J = 0;
end
disp(J)

[~,startDirectory,~]=fileparts(pwd);

if strcmpi(startDirectory,'ICL_HPC')
    cd('..')
end
addpath('ICL_HPC')

projectPath = OI.ProjectLink().projectPath;

oi = OpenInSAR('-log','trace','-project', projectPath);
    
% load the project object
projObj = oi.engine.load( OI.Data.ProjectDefinition() );
oi.engine = DistributedEngine();
oi.engine.connect( projObj );


oi.engine.postings = oi.engine.postings.reset_workers();

oi.engine.postings.report_ready(0)
nextWorker = 0;
assignment = {};

thingToDoList = { OI.Data.Sentinel1SafeDownload(), ... %1
    OI.Data.Catalogue(), ... %0
    OI.Data.OrbitSummary() , ... %0
    OI.Data.PreprocessedFiles(), ... %0
    OI.Data.GeocodingSummary(), ... %1
    OI.Data.CoregistrationSummary(), ... %1
    OI.Data.SubstackingSummary() }; %1

for thingToDo = thingToDoList
    oi.ui.log('info','Jobs remaining in queue:\n');
    oi.engine.queue.overview()
    % oi.engine.load( thingToDo{1} )
    matcher = @(posting, x) numel(posting) >= numel(x) && any(strfind(posting(1:numel(x)), x));

    assignment = cell(1, 100);

    while true

        while nextWorker == 0
            oi.engine.postings = oi.engine.postings.find_workers();
            % assignment{ numel(oi.engine.postings.workers) } = '';

            % clean up old jobs and add the results to database
            for ii = 1:length(oi.engine.postings.workers)
  
                % get the filepath
                JJ = oi.engine.postings.workers(ii);
                if JJ==0
                    continue
                end
                fp = oi.engine.postings.get_posting_filepath(JJ);
                % load the posting file
                fid = fopen(fp);
                posting = fread(fid,inf,'*char')';
                fclose(fid);
                % what is it?
                if matcher( posting, 'READY')
                    fprintf(1, 'Worker %i is ready\n', JJ);
                    assignment{JJ} = '';
                    nextWorker = JJ; %#ok<NASGU>
                end
                % running
                if matcher( posting, 'RUNNING')
                    fprintf(1, 'Worker %i : %s\n', JJ,posting);
                    jobstr = strsplit(posting, 'Job(');
                    jobstr = ['Job(' jobstr{2}];
                    assignment{JJ} = OI.Job(jobstr);
                end
                % finished
                if matcher( posting, 'FINISHED') || OI.Compatibility.contains(posting,'_FINISHED')
                    fprintf(1, 'Worker %i : %s\n', JJ,posting);
                    ss = strsplit(posting, '_ANSWER=');
                    if numel(ss)>1
                        answer = ss{2};
                        try
                            resultXmlParsed = OI.Data.XmlFile( answer );
                            resultAsStructFromXml = resultXmlParsed.to_struct();
                            dataObj = OI.Functions.struct2obj( resultAsStructFromXml );
                            if isa(dataObj,'OI.Data.DataObj')
                                oi.engine.database.add( dataObj );
                            elseif isstruct(dataObj)
                                oi.engine.database.add( dataObj, dataObj.name );
                            end

                        catch ERR
                            oi.engine.ui.log( OI.Compatibility.CompatibleError(ERR) )
                            oi.engine.ui.log('error',['failed to add result:' answer(:)'])
                        end
                    end
                    postingNoAnswer = ss{1};
                    finishedJob = strsplit(postingNoAnswer,'JOB=');
                    if numel(finishedJob) > 1
                        finishedJob = finishedJob{2};
                        oi.engine.queue.remove_job( OI.Job(finishedJob) );
                    end
    
                    fp = oi.engine.postings.get_posting_filepath(JJ);
                    fid = fopen(fp,'w');
                    fwrite(fid,'');
                    fclose(fid);

                    % Remove the job
                end
                % error
                if matcher( posting, 'ERROR')
                    fprintf(1, 'Worker %i : %s\n', JJ, posting);
                    oi.engine.ui.log('error',posting);
                    warning(posting);
                    assignment{JJ} = '';
                end
            end

            nextWorker = oi.engine.postings.get_next_worker(); 
            if nextWorker == 0
                nextJob = oi.engine.queue.next_job();
                if ~isempty(nextJob) && ~isempty(nextJob.target) && nextJob.target
                    % jobs require assignment, but
                    % still no workers, lets wait a bit
                    oi.ui.log('info','%s\n',datestr(now())) %#ok<TNOW1,DATST>
                    oi.ui.log('info','All workers busy or none running. Waiting.\n');
                    if isunix
                        system('qstat')
                    end
                    pause(5)
                    continue
                else
                    break %?? Why would we wait and loop back here ??
                    % lets break and check for leader jobs?
                end
            end
        end

        oi.ui.log('info','Jobs remaining in queue:\n');
        oi.engine.queue.overview()

        % check the job isn't already running
        nextJob = oi.engine.queue.next_job();
        
        if isempty(nextJob)
            % try loading our target
            oi.engine.load( thingToDo{1} )
            nextJob = oi.engine.queue.next_job();
            if isempty(nextJob)
                oi.engine.ui.log('info',...
                    'No more jobs for leader at this step');
                break
            end
        end

        while isempty(nextJob.target)
            % we can carry on running jobs that don't have a target
            oi.engine.run_next_job()
            % try loading our target
            oi.engine.load( thingToDo{1} )
            nextJob = oi.engine.queue.next_job();
            if isempty(nextJob)
                % 'No more jobs for leader.'
                oi.engine.ui.log('info',...
                    ['No more jobs for leader at this step,'... 
                    'running distributed jobs']);
                break
            end
        end
        if isempty(nextJob)
            continue
        end

        tfClash = false;
        nJobsAssigned = 0;
        allJobsAssigned = false;
        firstJob = nextJob;
        
        for ii = 1:numel(assignment)
            if ~isempty(assignment{ii}) 
                if assignment{ii}.eq(nextJob)
                    nJobsAssigned = nJobsAssigned + 1;
                    oi.engine.ui.log('debug',...
                        'Removed an already assigned job - %s', ...
                        nextJob.to_string());
                    oi.engine.queue.remove_job(1);
                    oi.engine.queue.add_job(nextJob); %add to back
                    tfClash = true;
                    nextJob = oi.engine.queue.next_job();
                    if nextJob.eq(firstJob)
                        allJobsAssigned = true;
                        break
                    end
                end
            end
        end


        if ~tfClash
            oi.engine.run_next_job()
            if oi.engine.lastPostee
                assignment{ oi.engine.lastPostee } = OI.Job( oi.engine.currentJob );
            end
        else
            % Job already assigned?
            if numel(oi.engine.queue.jobArray) < numel(oi.engine.postings.workers)
                oi.engine.ui.log('debug',...
                    'Jobs assigned and more workers than jobs, waiting.')
                nextWorker = 0;
                pause(10)
                if allJobsAssigned
                    oi.engine.ui.log('debug',...
                        'all jobs assigned');
                    pause(10)
                end
                continue;
            else
                oi.engine.ui.log('Error','Some conflict has arrisen?!')
                warning('Somehow multiple jobs have been assigned? Please investigate')
                % ' wait for the clash to be resolved'
                pause(20); % wait for the clash to be resolved
            end
        end

        nextWorker = 0;
        if oi.engine.queue.is_empty()
            % 'WINNER!'
            oi.engine.ui.log('info',...
                'Step %s from %s is complete!', ...
                thingToDo{1}.id,thingToDo{1}.generator);
            break
        else 
            fprintf(1, 'Queue length: %i\n', oi.engine.queue.length());
        end
    end
end
