classdef Queue < handle

properties (SetAccess = private, GetAccess = public)
    jobArray;
end

methods 

    function this = add_job(this, jobObj, idx)
        if ~isa(jobObj, 'OI.Job')
            % if it's not a job object, try to make it one
            jobObj = OI.Job(jobObj);
            if ~isa(jobObj, 'OI.Job')
                error('Invalid input type');
            end
        end
        % check for duplicate
        for k = 1:length(this.jobArray)
            if this.jobArray{k}.eq(jobObj)
                disp('not adding duplicate job');
                return;
            end
        end

        if nargin > 2 && idx>0 && idx<=length(this.jobArray)
            if idx == 0
                warning('Oct/Mat use 1 indexing.')
                idx = 1;
            end
            this.jobArray = [this.jobArray(1:idx-1) jobObj this.jobArray(idx:end)];
        else
            this.jobArray{end+1} = jobObj;
        end
    end

    function tf = is_empty( this )
        tf = isempty(this.jobArray);
    end

    function n = length( this )
        n = length( this.jobArray );
    end

    function nextJob = next_job( this )
        nextJob = [];
        if ~this.is_empty()
            nextJob = this.jobArray{1};
        end
    end

    function this = prioritise_argument(this, key, val, inPlace)
        % in place is whether to push these to front of queue or sort
        % matching jobs along their initial set of positions.
        if nargin < 4
            inPlace = false;
        end
        
        matchKeyFun = @(x) strcmpi(class(x),class(key)) & strcmpi(x,key);
        if OI.Compatibility.is_string( val )
            matchValFun = @(x) matchKeyFun(x);
        elseif isnumeric(val)
            matchValFun = @(x) strcmpi(class(x),class(val)) & all(x==val);
        else 
            error('Unhandled key typ %s', class(key));
        end

        args = cellfun(@(x) x.arguments , this.jobArray, 'UniformOutput', false);
        [hasCorrectVal, hasArg] = deal(zeros(size(args)));
        for ii = 1:numel(args)
            argInd = find(cellfun(@(x) matchKeyFun(x), args{ii}));
            if ~isempty(argInd)
                hasArg(ii) = argInd;
                hasCorrectVal(ii) = matchValFun( args{ii}{hasArg(ii)+1} );
            end
        end
        % i dont think hasArg / hasCorrect need to be doubles... can be
        % logical arrays directly
        if ~inPlace
            correctJobs = this.jobArray( hasCorrectVal > 0 );
            this.jobArray( hasCorrectVal > 0 ) = [];
            this.jobArray = [correctJobs, this.jobArray];
        else
            rightArgJobs = this.jobArray( hasArg > 0 );
            rightArgRightVal = hasCorrectVal( hasArg > 0) > 0;
            sortedJobs = [rightArgJobs(rightArgRightVal) rightArgJobs(~rightArgRightVal)];
            this.jobArray( hasArg > 0 ) = sortedJobs;
        end
    end

    function this = remove_job( this, job )
        % accepts either a job object or a job index
        if isa(job, 'OI.Job')
            for k = 1:length(this.jobArray)
                if this.jobArray{k}.eq(job)
                    this.jobArray(k) = [];
                    break;
                end
            end
        elseif isnumeric(job)
            % idx = this.jobArray{job}
            idx = job;
            this.jobArray(idx) = [];
        else
            error('Invalid input type');
        end
    end

    function this = promote_job(this, idx)
        if ~isnumeric(idx)
            % assume its a job object or job string
            % find job will error if not
            idx = this.find_job(idx);
            if isempty(idx)
                error('Job not found in queue');
            end
        end

        if idx>1 && idx<=length(this.jobArray)
            if idx == 0
                warning('Oct/Mat use 1 indexing.')
                idx = 1;
            end
            newJobArray = cell(size(this.jobArray));
            for k = 1:length(this.jobArray)
                if k == idx
                    newJobArray{1} = this.jobArray{idx};
                elseif k < idx
                    newJobArray{k+1} = this.jobArray{k};
                elseif k > idx
                    newJobArray{k} = this.jobArray{k};
                end
            end
            this.jobArray = newJobArray;
        else
            error('Invalid index');
        end
    end

    function [idx, job] = find_job(this, job)
        idx = [];
        % accepts either a job object or a job index
        if isa(job, 'OI.Job')
            % OK
        elseif OI.Compatibility.is_string(job)
            job = OI.Job(job);
        elseif isnumeric(job)
            idx = this.jobArray{job};
            job = this.jobArray{idx};
            return
        else
            error('Invalid input type');
        end

        
        for k = 1:length(this.jobArray)
            if this.jobArray{k}.eq(job)
                idx = k;
                job = this.jobArray{k}; %??? Just in case???
                break;
            end
        end
    end

    function this = populate(this, ~)
        warning('Not yet implemented')
        % switch schema
        %     case 'PSI'
                
        % end

        % if ~iscell(tJobArray)
        %     error('Invalid input type');
        % end
        % for k = 1:length(tJobArray)
        %     this.add_job(tJobArray{k});
        % end
    end

    function overview(this)
        names = struct();
        for ii=1:this.length()
            job = this.jobArray{ii};
            jn = job.name;
            if isfield(names,jn)
                names.(jn) = names.(jn) + 1;
            else
                names.(jn) = 1;
            end
        end
    end

    function clear(this)
        this.jobArray = {};
    end
end

end