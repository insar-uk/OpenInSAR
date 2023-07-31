% get number of available cores
nCpuEnvVar = getenv('nCpus');
if ~isempty(nCpuEnvVar)
    nCpu = str2num(nCpuEnvVar); %#ok<ST2NM>
else
    nCpu = 4; % Pure guess
end

% Set the number of threads to use
maxNumCompThreads(nCpu);

if ~exist('J','var')
    J = getenv('PBS_ARRAY_INDEX');
    fprintf(1,'J from env variables:')
    disp(J)
    if isempty(J)
        J = 99;
    end
end

if ~isnumeric(J)
    J = str2num(J); %#ok<ST2NM>
end

disp(J)

[~,startDirectory] = fileparts(pwd);

if strcmpi(startDirectory,'ICL_HPC')
    cd('..')
end
addpath('ICL_HPC')

% project file:
% resolve the real path to the project file
fp = OI.ProjectLink().projectPath;
oi = OpenInSAR('-log','trace','-project',fp);
projObj = oi.engine.load( OI.Data.ProjectDefinition() );
postings = Postings(projObj);

% If the worker is #1, have it run as an interactive terminal session
% We can then use it as a debugging tool or leader
if J==1
    fp = OI.ProjectLink().projectPath;
    oi = OpenInSAR('-log','trace','-project',fp);

    terminalInputLocation = fullfile(postings.postingPath,'interactive_input.txt');
    terminalOutputLocation = fullfile(postings.postingPath,'interactive_output.txt');

    % write the input file
    if ~exist(terminalInputLocation,'file')
        OI.Functions.mkdirs(fileparts(terminalInputLocation))
        fid = fopen(terminalInputLocation,'w');
        fwrite(fid,'');
        fclose(fid);
    end

    % start the terminal output
    diary(terminalOutputLocation)
    diary on

    % main loop
    while true
        % read the contents of the input file, eval, then wipe
        inputCommands = fileread(terminalInputLocation);

        if ~isempty(inputCommands)
            % make the input file empty
            fid = fopen(terminalInputLocation,'w');
            fwrite(fid,'');
            fclose(fid);

            fprintf(1,'Received input:\n%s\n',inputCommands)

            try
                eval(inputCommands)
            catch ERR
                disp(ERR)
                errStruct = OI.Functions.obj2struct(ERR);
                disp(OI.Functions.struct2xml(errStruct).to_string())
            end
        end
        % 
        timeToWait = 10;
        tStep = 10;
        while timeToWait > 0
            fprintf(1,'%s - waiting %i seconds...\n', datetime("now"), timeToWait);
            pause(tStep)
            timeToWait = timeToWait - tStep;
        end
    end
end



firstWait = true; % make the first wait shorter
% main loop
while true
    postings.report_ready(J);
    jobstr = '';
    while isempty(jobstr)
        postings = postings.check_jobs(J);
        jobstr = postings.jobline;
        if ~isempty(jobstr)
            disp(jobstr)
            firstWait = true;
            postings.report_recieved(J);
            break
        else
            
            postings.report_ready(J);
            if firstWait
                fprintf(1,'%s - waiting...', datetime("now"));
                pause(10)
                firstWait = false;
            else
                pause(30)
            end
        end
    end

    % Check if jobstr is 'reset'
    if strcmpi(jobstr,'reset')
        disp('resetting')
        clearvars -except J
        restoredefaultpath
        addpath('ICL_HPC')
        worker
        return
    end

    % clear any info asside from JOB
    jobCell=strsplit(jobstr,'JOB=');
    jobstr = jobCell{end};
    % convert to JOB object
    JOB = OI.Job(jobstr);
    % TODO check valid?
    oi.engine.queue.add_job(JOB)
    while ~oi.engine.queue.is_empty()
        postings.report_running(J);
        dbSize = numel(oi.engine.database.data);
        
        try
            oi.engine.run_next_job();
        catch ERR
            try
                disp(ERR)
                oi.engine.ui.log( OI.Compatibility.CompatibleError(ERR) )
                errStruct = OI.Functions.obj2struct(ERR);
                disp(OI.Functions.struct2xml(errStruct).to_string())

                % write the error to a file
                ds = strrep(strrep(datestr(now),':',''),' ','_');
                fid = fopen(fullfile(postings.postingPath,['error' num2str(J) ds '.txt']),'w');
                fwrite(fid, OI.Functions.struct2xml(errStruct).to_string());
                fclose(fid);

                % report the error
                postings.report_error(J, ...
                    OI.Functions.struct2xml(errStruct).to_string())
                clearvars -except J
                restoredefaultpath
                addpath('ICL_HPC')
                worker
            catch ERR2
                warning('cant handle error at all, restarting')
                disp(ERR2)
                clearvars -except J
                restoredefaultpath
                addpath('ICL_HPC')
                worker
                return
            end
        end

        if oi.engine.plugin.isFinished
            if dbSize < numel(oi.engine.database.data)
                % convert the database additions to xml
                resultAsStruct = OI.Functions.obj2struct( oi.engine.database.data{end} );
                resultAsXmlString = OI.Functions.struct2xml( resultAsStruct ).to_string();
                answer = resultAsXmlString;
                postings.report_done(J, answer);
            end
        end

        postings = postings.check_jobs(J);
        jobstr = postings.jobline;
        % Check if jobstr is 'reset'
        if strcmpi(jobstr,'reset')
            disp('resetting')
            clearvars -except J
            restoredefaultpath
            addpath('ICL_HPC')
            worker
            return
        end
        
    end
    answer = '';
    % if ~isempty(oi.engine.plugin.outputs)
    %     answer = OI.Functions.struct2xml( OI.Functions.obj2struct( oi.engine.plugin.outputs{1} ) );
    % end
    % postings.report_done(J, answer);
end
