
classdef Engine < handle

properties
    queue = OI.Queue();
    database = OI.Database();
    ui = OI.UserInterface();
    currentJob = '';   
    plugin
    priorJobNames = {}
    priorJobArgs = {}
    priorJobTiming = []
end

methods
    function this = Engine( varargin )
        % pass thru queue, database, ui objects if you want to use your own
        % with name Object pairs
        % e.g. OI.Engine('queue', myQueue, 'database', myDatabase, 'ui', myUI)
        for i = 1:2:length(varargin)
            % check correct
            if ~isprop(this, varargin{i})
                error('OI:Engine:InvalidProperty', 'Invalid property %s\n', varargin{i})
            end
            this.(varargin{i}) = varargin{i+1};
        end
    end

    function throw_error_if_no_project_loaded(this)
        if isempty(this.database.fetch('project'))
      error('Please load a project before doing any work.');
        end
    end

    function load_project(this, project_filepath)
        % Load a project from the database via the project filepath
        status = this.database.load_project(project_filepath);
        this.ui.log('info', 'Loaded project %s\n', strrep(project_filepath,'\','\\'));
        this.ui.log('debug', '%s\n', status);
        % clear the queue
        this.queue.clear();
    end

    function run_next_job( this )
        this.throw_error_if_no_project_loaded();
        nextJob = this.queue.next_job();
        if ~isempty(nextJob)
            this.ui.log('debug', 'Running job %s\n', nextJob.to_string());
            this.currentJob = nextJob.to_string();
            this.run_job(nextJob);
        else
            this.ui.log('info', 'No jobs in queue\n');
        end
    end

    function run_job( this, job )
        this.throw_error_if_no_project_loaded();
        % if its a string, convert to a job object
        if ischar(job)
            this.ui.log('debug', 'Converting %s to job object\n', job')
            job = OI.Job(job);
        end
        this.currentJob = job.to_string();
        % convert the named job to a plugin
        pluginHandle = OI.PluginFactory.get_plugin_handle( job.name );
        if isempty(pluginHandle)
            error('Could not resolve plugin %s', job.name)
        end
        this.plugin = pluginHandle();
        
        % prior queue length
        priorQueueSize = this.queue.length();
        % send the engine to the plugin so it can acccess config parameters
        this.plugin = this.plugin.configure( this, job.arguments);
        % if queue has grown, then the plugin has added jobs
        if this.queue.length() > priorQueueSize
            this.ui.log('info', 'Plugin %s defered until later, it added new jobs to queue\n', this.plugin.id);
            return
        end

        this.plugin = this.plugin.validate( this );

        if this.plugin.isFinished
            this.ui.log('info', 'Plugin %s already finished\n', this.plugin.id);
            this.queue.remove_job(job);
            return
        end

        if this.plugin.isReady
            this.ui.log('info', 'Running plugin %s, %i jobs currently in queue.\n', this.plugin.id, this.queue.length());
            % time the plugin run
            ticPlugin = tic;
            % actually run the plugin!
            this.run_plugin( job );
            % log the time
            tocPlugin = toc(ticPlugin);
            this.finish_job(job, tocPlugin)
        else
            % plugin declared it wasn't ready, so we add it to the back of the queue
            assert( this.queue.length() > priorQueueSize, 'Queue should have grown' )
            % push to back of queue
            this.queue.remove_job(job);
            this.queue.add_job(job);
            this.ui.log('debug', 'Plugin %s added to back of queue, not ready\n', this.plugin.id')
        end
    end


    function finish_job(this, job, timeJobTook)
        this.handle_job_timing(job, timeJobTook);
        if ~this.plugin.isFinished
            this.ui.log('debug', 'Plugin %s finished property is false\n', this.plugin.id);
            % check the output files exist
            outputsExist = true;
            for output = this.plugin.outputs
                outputObj = this.database.find( output{1} );
                if isempty(outputObj)
                    this.ui.log('debug', 'Output %s not found in database\n', strrep(output{1}.id,'\','\\'));
                    outputsExist = false;
                    break
                end
            end
            if outputsExist
                this.ui.log('debug', 'Plugin %s outputs exist, setting finished\n', this.plugin.id);
                this.plugin.isFinished = true;
            end
        end

        if this.plugin.isFinished
            this.ui.log('info', 'Plugin %s finished, removing job\n', this.plugin.id);
            this.queue.remove_job(job);
        else
            this.ui.log('debug', 'Plugin %s not finished, re-adding the job to queue\n', this.plugin.id);
            this.queue.remove_job(job);
            this.queue.add_job(job);
            this.ui.log('debug', 'Plugin %s added to back of queue\n', this.plugin.id')
        end
    end

    function requeue_job(this, varargin)
        
        job = OI.Job(this.currentJob);
        % concat any new args
        newArgs = {};
        nTotalArgs = 0;

        % octave bug, empty cell array is not empty
        if numel(job.arguments) && isempty(job.arguments{1})
        else % add the existing job args
            for existingIndex = 1:length(job.arguments)
                nTotalArgs = nTotalArgs + 1;
                newArgs{nTotalArgs} = ... %#ok<AGROW>
                    job.arguments{existingIndex}; %#ok<AGROW>
            end
        end

        % add the new args
        for newArgIndex = 1:length(varargin)
            nTotalArgs = nTotalArgs + 1;
            newArgs{nTotalArgs} = varargin{newArgIndex}; %#ok<AGROW>
        end
        if numel(newArgs) > 1
            job.target = '1'; % target distribution
        end
        job.arguments = newArgs;
        this.queue.add_job(job);
    end

    
    function requeue_job_at_index(this, index, varargin)
        
        job = OI.Job(this.currentJob);
        % concat any new args
        newArgs = {};
        nTotalArgs = 0;

        % octave bug, empty cell array is not empty
        if numel(job.arguments) && isempty(job.arguments{1})
        else % add the existing job args
            for existingIndex = 1:length(job.arguments)
                nTotalArgs = nTotalArgs + 1;
                newArgs{nTotalArgs} = ... %#ok<AGROW>
                    job.arguments{existingIndex}; %#ok<AGROW>
            end
        end

        % add the new args
        for newArgIndex = 1:length(varargin)
            nTotalArgs = nTotalArgs + 1;
            newArgs{nTotalArgs} = varargin{newArgIndex}; %#ok<AGROW>
        end
        if numel(newArgs) > 1
            job.target = '1'; % target distribution
        end
        job.arguments = newArgs;
        this.queue.add_job(job, index);
    end

    function handle_job_timing(this, jobThatJustFinished, timeJobTook)
        % add the time to the job history
        % if isa(jobThatJustFinished, 'OI.Job') % conv to string
        %     jobThatJustFinished = jobThatJustFinished.to_string();
        % end
        timeForThis = tic;
        this.priorJobNames{end+1} = jobThatJustFinished.name;
        this.priorJobArgs{end+1} = jobThatJustFinished.get_arg_keys();
        this.priorJobTiming(end+1) = timeJobTook;

        % print how long the last job took
        formattedJobString = strrep(jobThatJustFinished.to_string(),'Job(','');
        formattedJobString = formattedJobString(1:end-1);
        this.ui.log('info', 'Job %s took %.2f seconds\n', formattedJobString, timeJobTook);

        % print the total time taken
        totalTime = sum(this.priorJobTiming);
        this.ui.log('info', 'Total time taken %.2f seconds\n', totalTime);

        % look up remaining jobs in the queue
        remainingJobs = this.queue.jobArray;
        % for each remaining job, see find jobs with the same name
        %    'Job('FilePreProcessor','1',{'DesiredOutput','PreprocessedFiles','platform','S1A','datetime',737223.7484722222434357})'
        totalTime = 0;
        nUnknownJobs = 0;
        for ii = 1:numel( remainingJobs )
            rJobName = remainingJobs{ii}.name;
            rJobArgs = remainingJobs{ii}.get_arg_keys();
            nPriorExample = 0;
            tPriorExamples = 0;
            for jj = 1:numel(this.priorJobNames)
                if strcmp(rJobName, this.priorJobNames{jj}) ...
                    && strcmp(rJobArgs, this.priorJobArgs{jj})
                        % this job has already been run
                    nPriorExample = nPriorExample + 1;
                    tPriorExamples = tPriorExamples + this.priorJobTiming(jj);
                end
            end
            meanTimeForJob = tPriorExamples / nPriorExample;
            if meanTimeForJob > 0
                totalTime = totalTime + meanTimeForJob;
            else
                nUnknownJobs = nUnknownJobs + 1;
            end
        end

        % Vary the message based on how long
        reportTime = totalTime;
        unitToReport = 'seconds';
        timingTemplate = 'Estimated time remaining %d %s\n';
        if reportTime > 60 * 60 % more than an hour
            reportTime = reportTime / (60 * 60);
            unitToReport = 'hours';
        elseif reportTime > 60 % more than a minute
            reportTime = reportTime / 60;
            unitToReport = 'minutes';
        end
        timingMessage = sprintf(timingTemplate,reportTime,unitToReport);
        % This isn't working for distributed queues, so we'll quiten the output for now.
        this.ui.log('debug',timingMessage);
        
        if nUnknownJobs %> 0
            this.ui.log('debug', 'Plus %i jobs without timing information available\n', nUnknownJobs);
        end
        this.ui.log('debug', 'Estimated time of completion %s\n', datetime('now') + totalTime/86400);
        this.ui.log('debug', 'timing loop took %.3f secs itself.\n',toc(timeForThis));
    end

    function [data, dataObj] = load(this, dataObj)
        % Load data generated by this project
        % If the specific file corresponding to the provided object
        % is undefined, or the specific file is not found, 
        % the relevant jobs will be added to this engine's queue.
        % data is returned empty if the data is not found
        % in which case generally the queue should have grown
        % dbstop if error
        % warning('dbstop if error')
        % dataObj has to be an object

        this.throw_error_if_no_project_loaded();

        if ischar(dataObj)
            error('OI:Engine:InvalidDataObject', ...
                ['Data object must be an object, not a string:\n' ...
                '\t'' %s '' was given'], dataObj );
        else
            this.ui.log('trace', 'Loading %s\n', class(dataObj));
        end
        data = [];

        % Find the specific filename for this object, if this isnt
        % possible then add necessary jobs to the queue 
        [dataObj, outstandingJobs] = dataObj.identify(this);
        
        % if theres jobs, lets add them to the queue and return
        if numel(outstandingJobs) > 0
            this.ui.log('debug', 'Not enough information for loading %s\n', dataObj.id')
            this.ui.log('debug', 'Calling identify on %s produced %d extra jobs\n Current job is: %s\n', dataObj.id,numel(outstandingJobs),this.currentJob);
            % Add any outstanding jobs to the queue
            for jobInd = 1:length(outstandingJobs)
                this.ui.log('debug', 'Adding job %s to queue\n', outstandingJobs{jobInd}.to_string());
                this.queue.add_job( outstandingJobs{jobInd} );
            end
            % try to create the intended job
            this.ui.log('debug', 'Trying to create job for %s\n', dataObj.id')
            job = dataObj.create_job(this);
            this.queue.add_job( job{1} );
            return
        end

        data = this.database.fetch(dataObj.id);
        inDb = ~isempty(data);
        if ~inDb
            this.ui.log('debug', 'No entry found in db for %s\n', dataObj.id');
        else 
            this.ui.log('debug', 'Found entry in db for %s\n', dataObj.id');
        end

        % if we have data, does it need loading?
        % If we have a filename, load the data
        if inDb && ~data.needs_load()
            this.ui.log('debug', '%s has been copied from memory\n', ...
                dataObj.id);
        elseif dataObj.hasFile && ~isempty(dataObj.filepath)
            this.ui.log('debug', 'Checking disk to try and load data from %s\n', strrep(dataObj.filepath,'\','\\'));
            [data, moreOutstandingJobs] = dataObj.load( this );
            outstandingJobs = [outstandingJobs, moreOutstandingJobs];
            if ~isempty(data) && ~inDb % if not in database, add it
                % but only if its a oi data obj
                if isa(data,'OI.Data.DataObj')
                    this.ui.log('debug', 'Adding %s to database after load from disk\n', dataObj.id');
                    % edge case where the file is an OI data object
                    if isa(data,'OI.Data.DataObj')
                        data.id = dataObj.id;
                        data.filepath = dataObj.filepath;
                    end
                    this.database.add(data);
                else % otherwise add the dataObj as a record
                    this.database.add(dataObj);
                end
            end
        end
     
        % Add any outstanding jobs to the queue
        nNewJobs = numel(outstandingJobs);
        if nNewJobs
            this.ui.log('debug', ...
                ['Calling LOAD on %s produced %d extra jobs\n', ...
                'Current job is: %s\n'], dataObj.id,nNewJobs,this.currentJob);
        end
        for jobInd = 1:nNewJobs
            % Add the job to the queue, in the order they came in.
            this.ui.log('debug', 'Adding job %s to queue\n', outstandingJobs{jobInd}.to_string())
            this.queue.add_job( outstandingJobs{jobInd}, jobInd );
        end

        % Remeber to handle empty data in the calling function !!
        if isempty(data)
            this.ui.log('debug', 'No data found for %s\n', dataObj.id')
            % if we dont have a file, and we dont have data, 
            % and we havent added jobs yet then we should add the job to the queue
            if isempty(outstandingJobs) && ~dataObj.hasFile
                this.ui.log('debug', 'Lack of file returned by engine.load with arg %s\n Current job is: %s\n', dataObj.id,this.currentJob);
                this.ui.log('debug', 'Adding job %s to queue, in order to later load it\n', dataObj.id');
                jobs =  dataObj.create_job( this );
                this.queue.add_job( jobs{1} );
            end
        end

        % Make paths cross-platform here, e.g. for catalogue
        if ~isempty(data) && isa(dataObj,'OI.Data.Catalogue')

            projObj = this.database.fetch('project');

            for ii=1:numel(data.safes)
                data.safes{ii} = data.safes{ii}.deplaceholder(projObj);
            end
        end

        % Make paths cross-platform here for DEM
        if ~isempty(data) && isa(dataObj,'OI.Data.DEM')
            projObj = this.database.fetch('project');
            data.filepath =  OI.Data.DataObj.deplaceholder_string(data.filepath,projObj);
            for tileInd = 1:numel(data.tiles)
                data.tiles{tileInd} = OI.Data.DataObj.deplaceholder_string(data.tiles{tileInd}, projObj);
            end
        end
    end

    function save(this, dataObj, data)
        
        % Save data generated by this project
        % If the specific file corresponding to the provided object
        % is undefined, or the specific file is not found, 
        % the relevant jobs will be added to this engine's queue.
        this.ui.log('debug', 'Saving %s with id %s\nCurrent job: %s\n', class(dataObj) , dataObj.id, this.currentJob);
        
        % if only one dataObj is provided
        % the data is the object itself
        if nargin < 3
            data = dataObj;
        end
        dataObj = dataObj.resolve_filename(this); 
        if strfind(dataObj.filepath, '$')
            this.ui.log('warning', 'Filepath is undefined, not saving %s\n', strrep(dataObj.filepath,'\','\\'));
            return
        end

        % Save a file if we can and want to:
        if dataObj.hasFile && ~isempty(dataObj.filepath)
            doOverwrite = ... % if obj or struct
                ( ( isobject(dataObj) && isprop(dataObj,'overwrite') ) || ...
                ( isstruct(dataObj) && isfield(dataObj,'overwrite') ) ) && ...
                dataObj.overwrite; % and overwrite is set


            this.ui.log('trace', 'Start of save. File %s exists: %d\n', strrep(dataObj.filepath,'\','\\'), dataObj.exists());
            % if overwriting or file doesnt exist
            if doOverwrite || ~dataObj.exists() 
                this.ui.log('trace','Actually saving %s\n', strrep(dataObj.filepath,'\','\\'));
                dataObj.save(data, this);
            end
        end % if dataObj.hasFile

        % Add to database
        this.database.add(dataObj);
        this.ui.log('trace', 'End of save. File %s exists: %d\n', strrep(dataObj.filepath,'\','\\'), dataObj.exists());
    end
end

methods (Access = protected)

    function run_plugin(this, job)
        this.throw_error_if_no_project_loaded();
        if isa(job,'OI.Job')
            % run the plugin
            this.plugin = this.plugin.run( this, job.arguments );
        else
            warning('You should send a job argument to the plugin')
            this.plugin = this.plugin.run( this, job );
        end
    end

end

end
