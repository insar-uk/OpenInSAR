classdef GetAsfQuery < OI.Plugins.PluginBase

properties
    inputs = {OI.Data.ProjectDefinition()}
    outputs = {OI.Data.AsfQueryResults()}
    id = 'GetAsfQuery'
    queryUrl = '';
    url = 'https://api.daac.asf.alaska.edu/services/search/param';
    response = '';
    mode = 'DEFAULT';
    maxResults = 5000;
end% properties

methods

    function this = run( this, engine, varargin )

        % get the project
        project = engine.load(OI.Data.ProjectDefinition());
        if isempty(project)
            ui.log('error','No project found in database. Please load the project first.');
        end

        params = struct( ... 
            'bbox', project.AOI.asf_bbox(), ...
            'platform', 'SENTINEL-1', ...
            'start', project.START_DATE.asf_datetime(), ...
            'end', project.END_DATE.asf_datetime(), ...
            'beamMode', 'IW', ...
            'processingLevel', 'SLC', ...
            'maxResults', num2str(this.maxResults), ...
            'output', 'json' ...
        );

        query = OI.Query( this.url , params );
        this.queryUrl = query.format_url_gently();

    this.outputs{1} = this.outputs{1}.resolve_filename( engine );
    fn = [this.outputs{1}.filepath '.json'];

        if OI.OperatingSystem.isUnix
            req = sprintf( ...
                "wget -c -q --no-check-certificate -O %s %s", ...
                fn, ...
                strrep(this.queryUrl,'&','\&'));
        else
            req = ['curl -s -L "' this.queryUrl '"'];
        end

    engine.ui.log( 'info', 'Making ASF query. This may take a minute.')
        if ~strcmpi(this.mode,'TEST')
            [status, reply] = system(req);
            if OI.OperatingSystem.isUnix
                reply = fileread(fn);
            end
            if status ~= 0
                engine.ui.log( 'error', 'ASF query failed.')
                return
            end
            engine.save( this.outputs{1}, reply );
        else
            reply = './test/res/test_asf_json.json';
            engine.save( this.outputs{1}, reply );
        end
        engine.ui.log( 'info', 'ASF query complete.')

    end

    
end% methods

end % classdef
