classdef PluginBase

properties
    isReady = false;
    isFinished = false;
    isArray = false;
    isOverwriting = false;
end

methods
    function this = PluginBase(  engine  )
    end

    function this = configure(this, engine, argCell)
        % set any key/value argument in varargin that matches a
        % property of this class
        for ii = 1:2:numel(argCell)
            if isprop(this, argCell{ii})
                this.(argCell{ii}) = argCell{ii+1};
            end
        end
    end


    function [this, data] = run( this, engine, varargin )
        % This is the main function that should be overloaded by the plugin
        % varargin used to pass args from job
        data = [];
        warning('PluginBase:run', 'PluginBase:run should be overloaded by the plugin');
    end

    function this = validate(this, engine)
    % We want to check all the inputs exist,
    % and add them to the queue via engine.load if they don't
    % We also want to check the outputs don't exist, but without queueing

        this.isReady = false;
        engine.ui.log('info', 'Validating %s plugin\n', this.id);

        
        % Check the outputs don't exist
        % What happens if an output depends on this param to add itself to the queue?
        % We will get a duplicate entry in the queue?
        priorQueue = engine.queue;
        missingOutput = false;
        for ii = 1:numel(this.outputs)
            this.outputs{ii} = this.outputs{ii}.copy_parameters( this );
            this.outputs{ii} = this.outputs{ii}.identify( engine );

            % database.find will add missing outputs to the database
            foundOutput = engine.database.find(this.outputs{ii});
            if isempty(foundOutput)
                missingOutput = true;
                break;
            else
                engine.ui.log('info', 'Already have output %s for %s\n', this.outputs{ii}.id, this.id)
            end
        end
        % reset queue
        engine.queue = priorQueue;

        % If we have all the outputs, we don't need to do anything
        if ~missingOutput
            this.isFinished = true;
            engine.ui.log('info', 'Already have outputs from %s\n', this.id)
            return
        end

        % check we have inputs and outputs
        if ~isprop(this, 'inputs') || ~isprop(this, 'outputs')
            engine.ui.log('error', 'Plugin %s does not have inputs and outputs properties\n', this.id)
            return
        end

        % %% TODO. I DONT THINK WE NEED THIS AS LOADING WILL BE HANDLED WITHIN PLUGIN.
        % % Check the inputs exist
        % for ii = 1:numel(this.inputs)
        %     this.inputs{ii} = this.inputs{ii}.copy_parameters( this );    
        %     this.inputs{ii} = this.inputs{ii}.identify( engine );

        %     foundInput = engine.database.find(this.inputs{ii});
        %     if isempty(foundInput)
        %         engine.ui.log('info', 'Inputs %s is not ready for %s\n Path: %s\n', this.inputs{ii}.id, this.id, strrep(this.inputs{ii}.filepath,'\','\\'))
                
        %         % if the input is an array, call its special jobifier
        %         if this.inputs{ii}.isArray
        %             jobs = this.inputs{ii}.create_array_job( engine );
        %         else
        %             % otherwise do the normal jobifier
        %             jobs = this.inputs{ii}.create_job( engine );
        %             for jj = 1:numel(jobs)
        %                 engine.queue.add_job(jobs{jj});
        %             end
        %         end%if
        %     end%if
        % end%for
        
        
        % If we get here, we have all the inputs and not all the outputs
        this.isReady = true;

    end

end

end