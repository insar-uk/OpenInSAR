classdef GetOrbits < OI.Plugins.PluginBase

properties
    inputs = {OI.Data.Catalogue()}
    outputs = {OI.Data.OrbitSummary()}
    datetime % to get the orbit file for
    platform % to get the orbit file for
    id = 'GetOrbits';
end % properties
%#ok<*DATST> - allow datestr() for Octave

methods
    function this = GetOrbits(varargin)

    end

    function this = run(this, engine, varargin)
        varargin = varargin{1};

        % find the varagin key value pairs
        for i = 1:2:length(varargin)-1
            switch varargin{i}
                case {'date', 'datetime', 'time'}
                    argIn = varargin{i+1};
                    if ischar(argIn)
                        argIn = str2double(argIn);
                    end
                    % engine.ui.log('trace', 'GetOrbits: datetime set to %s\n', num2str(argIn))
                    this.datetime = OI.Data.Datetime(argIn);
                case 'platform'
                    % engine.ui.log('trace', 'GetOrbits: platform set to %s\n', varargin{i+1})
                    this.platform = varargin{i+1};
                case {'finalise','final','finish','finalize'}
                    % pass
                otherwise
                    engine.ui.log('debug','Unknown key value pair');
            end% switch
        end% for

       
        % if no specific orbit requested, make a job for each orbit in catalogue
        if (isempty(this.datetime) || isempty(this.platform))
            % check the orbit directory
            project = engine.load( OI.Data.ProjectDefinition() );
            % make if not
            if ~exist(project.ORBITS_DIR, 'dir')
                OI.Functions.mkdirs(project.ORBITS_DIR);
            end
            % get the files
            orbitFiles = dir(project.ORBITS_DIR);
            orbitFiles = orbitFiles(3:end);

            % get the catalogue
            catalogue = engine.load( OI.Data.Catalogue() );

            jobCount = 0;
            % for each safe in the catalogue
            for ii=1:numel(catalogue.safes)
                % get the datetime
                targetDatetime = catalogue.safes{ii}.date;
                % get the platform
                targetPlatform = catalogue.safes{ii}.platform;

                % dbstop if error
                % error('asd')
                % see if the orbit file exists in the orbit directory
                orbitFile = OI.Data.Orbit().find(targetPlatform, targetDatetime, orbitFiles);

                if isempty( orbitFile )
                    jobCount = jobCount+1;
                    % create a job with the date and platform
                    engine.requeue_job_at_index( ...
                        jobCount, ...
                        'datetime', targetDatetime.datenum(), ...
                        'platform', targetPlatform);
                else
                    % add the orbit file to the catalogue
                    catalogue.safes{ii}.orbitFile = orbitFile;
                    % Make the orbit file cross-platform by specifying root

                end
            end

            % check if any safe is missing an orbit file
            try
                hasOrbitForSafe = cellfun(@(x) ~isempty(x.orbitFile), catalogue.safes);
            catch
            end
            
            if jobCount
                % requeue this job
                % engine.requeue_job();
                this.isFinished = false;
            else
                % save the catalogue
                catalogue.overwrite = true;
                try
                    engine.ui.log('info', 'GetOrbits finishing... Saving catalogue with %d orbit files\n', sum(hasOrbitForSafe))
                catch
                end
                    
                catalogue = catalogue.make_filepaths_portable(project);
                engine.save(catalogue,catalogue);
                this.outputs{1} = OI.Data.OrbitSummary();
                this.outputs{1}.configure('fileCount',numel(orbitFiles))
                engine.save( this.outputs{1} );
                this.isFinished = true;
            end

            return
        end

        if ~isa(this.datetime,'OI.Data.Datetime')
            this.datetime=OI.Data.Datetime( this.datetime );
        end

        this.outputs{1} = OI.Data.Orbit();

        % fill in some details
        [name, link] = this.api_check();
        this.outputs{1}.id = name;
        this.outputs{1}.link = link;
        this.outputs{1}.platform = this.platform;

        % generate filepath for orbit file
        this.outputs{1}.nameOfPoeFile = name;
        this.outputs{1}.link = link;
        fp = this.outputs{1}.filepath;
        this.outputs{1}.filepath = this.outputs{1}.string_interpolation(fp, engine);

        % does the orbit file exist?
        existsAlready = this.outputs{1}.exists();

        % download if not
        if ~existsAlready
            status = this.download();
            if status
                error('Download failed with curl status code %d', status)
            end
        end

        % save the orbit file
        engine.save(this.outputs{1});
        this.isFinished = true;

    end % run(

    function [name, link] = api_check(this)
        orbitDatenum = this.datetime.datenum();

        % create the query
        qString = sprintf('(beginPosition:[%sT00:00:00.000Z TO %sT23:59:59.999Z] AND endPosition:[%sT00:00:00.000Z TO %sT23:59:59.999Z] ) AND ( (platformname:%s AND producttype:AUX_POEORB))', ...
            datestr(orbitDatenum-1, 'yyyy-mm-dd'), datestr(orbitDatenum, 'yyyy-mm-dd'), ...
            datestr(orbitDatenum, 'yyyy-mm-dd'), datestr(orbitDatenum+1, 'yyyy-mm-dd'), ...
            'Sentinel-1');
        params = struct('q', qString, 'rows', '100', 'start', '0', 'format', 'json');

        query = OI.Query( 'https://scihub.copernicus.eu/gnss/search' , params );
        query.username = 'gnssguest';
        query.password = 'gnssguest';


        % get the results
        % TODO - This isn't doing anything?? Should it be??
        % str = query.format_url_gently();
        [results, query] = query.get_response();

        if isempty(results)
            error('No orbit files found for %s on %s\nQuery url:\n%s\n', this.platform, datestr(this.datetime.datenum(), 'yyyy-mm-dd'), query.url)
        end
        % parse the json
        json = jsondecode(results);

        if ~isfield(json.feed, 'entry')
            disp(json)
            error('No orbit files found for %s on %s\nQuery url:\n%s\n', this.platform, datestr(this.datetime.datenum(), 'yyyy-mm-dd'), query.url)
        end
        % get the etries
        entries = json.feed.entry;

        % check we got some results
        if isempty(entries)
            error('No orbit files found for %s on %s\nQuery url:\n%s\n', this.platform, datestr(this.datetime.datenum(), 'yyyy-mm-dd'), query.url)
        end
        % loop through the entries
        for entryIndex = 1:numel(entries)
            entry = entries(entryIndex);
            % get the title
            name = entry.title;
            % check if platform is correct
            rightPlatform = strcmpi(name(1:3), this.platform);
            if rightPlatform
                % get the link
                link = entry.link{1}.href;
                break
            end
        end
    end % api_check

    function status = download(this)
        url = this.outputs{1}.link;
        filename = [this.outputs{1}.filepath '.' this.outputs{1}.fileextension];

        dir = fileparts(filename);
        if ~exist(dir, 'dir')
            OI.Functions.mkdirs(dir);
        end

        % download the orbit file
        % status = webread(filename, url);
        if ~isunix
            curlCommand = sprintf('curl -u gnssguest:gnssguest -o %s %s', filename, url);
            [status, ~] = system(curlCommand);
        else
            % wget --user=gnssguest --password=gnssguest -O output_file *URL*
            % url
            % url = strrep(url,'$','\\$');
            % wgetCommand = sprintf('wget --user=%s --password=%s -O %s "%s"', 'gnssguest', 'gnssguest', filename, url);
            % [status, result] = system(wgetCommand);
            % result
            url = this.outputs{1}.link;
            url = strrep(url,'$','\$');
            wgetCommand = sprintf('wget --no-check-certificate --user=gnssguest --password=gnssguest -O %s "%s"', filename, url);
            % wgetCommand
            [status, ~] = system(wgetCommand);
            % status
            % result
        end
        % status
        % result
    end % download

end % methods

end % classdef

% Response = {"feed":{"xmlns":"http://www.w3.org/2005/Atom","xmlns:opensearch":"http://a9.com/-/spec/opensearch/1.1/","title":"Sentinels GNSS RINEX Hub search results for: (beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))","subtitle":"Displaying 1 results. Request done in 0 seconds.","updated":"2023-03-31T17:00:24.814Z","author":{"name":"Sentinels GNSS RINEX Hub"},"id":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))","opensearch:totalResults":"1","opensearch:startIndex":"0","opensearch:itemsPerPage":"100","opensearch:Query":{"startPage":"1","searchTerms":"(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))","role":"request"},"link":[{"href":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))&start=0&rows=100&format=json","type":"application/json","rel":"self"},{"href":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))&start=0&rows=100&format=json","type":"application/json","rel":"first"},{"href":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))&start=0&rows=100&format=json","type":"application/json","rel":"last"},{"href":"opensearch_description.xml","type":"application/opensearchdescription+xml","rel":"search"}],"entry":{"title":"S1A_OPER_AUX_POEORB_OPOD_20230219T080751_V20230129T225942_20230131T005942","link":[{"href":"https://scihub.copernicus.eu/gnss/odata/v1/Products('4d94ac07-481d-4470-a01c-3586f27661d3')/$value"},{"rel":"alternative","href":"https://scihub.copernicus.eu/gnss/odata/v1/Products('4d94ac07-481d-4470-a01c-3586f27661d3')/"},{"rel":"icon","href":"https://scihub.copernicus.eu/gnss/odata/v1/Products('4d94ac07-481d-4470-a01c-3586f27661d3')/Products('Quicklook')/$value"}],"id":"4d94ac07-481d-4470-a01c-3586f27661d3","summary":"Date: 2023-01-29T22:59:42Z, Instrument: , Satellite: Sentinel-1, Size: 4.43 MB","ondemand":"false","date":[{"name":"generationdate","content":"2023-02-19T08:07:51Z"},{"name":"beginposition","content":"2023-01-29T22:59:42Z"},{"name":"endposition","content":"2023-01-31T00:59:42Z"},{"name":"ingestiondate","content":"2023-02-19T08:40:11.504Z"}],"str":[{"name":"format","content":"EOF"},{"name":"size","content":"4.43 MB"},{"name":"platformname","content":"Sentinel-1"},{"name":"platformshortname","content":"S1"},{"name":"platformnumber","content":"A"},{"name":"platformserialidentifier","content":"1A"},{"name":"filename","content":"S1A_OPER_AUX_POEORB_OPOD_20230219T080751_V20230129T225942_20230131T005942.EOF"},{"name":"producttype","content":"AUX_POEORB"},{"name":"filedescription","content":"Precise Orbit Ephemerides (POE) Orbit File"},{"name":"fileclass","content":"OPER"},{"name":"creator","content":"OPOD"},{"name":"creatorversion","content":"3.1.0"},{"name":"identifier","content":"S1A_OPER_AUX_POEORB_OPOD_20230219T080751_V20230129T225942_20230131T005942"},{"name":"uuid","content":"4d94ac07-481d-4470-a01c-3586f27661d3"}]}}}
