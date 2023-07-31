
classdef DistributedEngine < OI.Engine

properties
    postings
    lastPostee = 0
end

methods

    function connect( this, projObj )
        this.postings = Postings( projObj );
    end

end

methods (Access = protected)
    function run_plugin( this, job )
        % run the plugin
        % fprintf(1, 'Running plugin is array: %d\n', this.plugin.isArray);
        % check if its a job?
        % if isa(job, 'OI.Job')
            % fprintf(1, 'Job target: %s\n', job.target);
        % end

        if this.plugin.isArray && ~isempty( job.target )
            nextWorker = this.postings.get_next_worker();
            if nextWorker == 0
                return %??
            end
            this.postings.post_job( nextWorker, job.to_string() );
            this.lastPostee = nextWorker;
        else
            this.plugin = this.plugin.run( this, job.arguments );
        end
    end % 

end % methods

end % classdef
