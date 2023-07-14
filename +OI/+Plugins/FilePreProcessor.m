classdef FilePreProcessor < OI.Plugins.PluginBase
% FilePreProcessor - Plugin to perform pre-processing on the data
%   Parameter extraction, initial geocoding, orbit interpolation, etc.

properties
    inputs = {OI.Data.Catalogue(), OI.Data.Orbit()}
    outputs = {OI.Data.PreprocessedFiles()}
    datetime = '';
    platform = '';
    id = 'FilePreProcessor'
end

properties (Constant)
    metadataNameFormatStr = 'Metadata_for_catalogue_entry_%s_%d';
end

methods

    function this = FilePreProcessor
        this.isArray = true;
    end
    
    function this = run(this, engine, varargin)

        varargin = varargin{1};
        cat = engine.load( OI.Data.Catalogue() );
        projObj = engine.load( OI.Data.ProjectDefinition() );
        if isempty(cat) || isempty(projObj)
            'empty cat'
            return
        end
        aoi = projObj.AOI.to_area();

        % find the varagin key value pairs provided, and set them.
        % PreProcessing takes a date and a platform and uses this to
        % find the file to process.
        for i = 1:2:length(varargin)
            switch varargin{i}
                case {'date', 'datetime', 'time'}
                    argIn = varargin{i+1};
                    if ischar(argIn)
                        argIn = str2double(argIn);
                    end
                    this.datetime = OI.Data.Datetime(argIn);
                case 'platform'
                    this.platform = varargin{i+1};
                case 'DesiredOutput' % ignore this not used here
                otherwise
                    engine.ui.log('debug','Unknown key value pair %s\n', varargin{i});
            end% switch
        end% for

        % If no platform or datetime is provided, then we need to create
        % jobs for each file in the catalogue.
        if isempty(this.datetime)
            % first call, create jobs.
            jobsAdded = 0;
            
            % for each safe in the catalogue
            for ii=1:numel(cat.safes)
                % get the datetime & platform
                safeDatetime = cat.safes{ii}.date;
                safePlatform = cat.safes{ii}.platform;
                % check if we have the metadata in the database
                metadataName = sprintf( ...
                    this.metadataNameFormatStr, ...
                    safePlatform, ...
                    ii ...
                );
                existing = engine.database.fetch( metadataName );
                % if no metadata, add a job to generate them:
                if isempty(existing)
                    engine.requeue_job('platform', safePlatform, ...
                        'datetime', safeDatetime.datenum());
                    jobsAdded = jobsAdded + 1;
                else % add the data to an array, to save later if complete
                    fns = fieldnames(existing);
                    for fn = fns(:)'
                        this.outputs{1}.metadata(ii).(fn{1}) = ...
                            existing.(fn{1});
                    end
                end
            end % for safes

            % if no jobs were added, then we're done 
            % save the collected data
            if jobsAdded == 0 
                engine.save(this.outputs{1});
                this.isFinished = true;
            end
            return
        end

        % get the safe for this datetime and platform
        times = cellfun( @(x) x.date.datenum(), cat.safes);
        % disqualify any that are not the right platform
        platforms = cellfun( @(x) x.platform, cat.safes, 'UniformOutput', false );
        rightPlatform = strcmp( this.platform, platforms );
        times(~rightPlatform) = -1e9;
        % find best match, in case we're off by a few seconds
        [~,closest] = min(abs(times - this.datetime.datenum()));
        safe = cat.safes{closest};

        safe = safe.deplaceholder(projObj);

        metadataName = sprintf( ...
            this.metadataNameFormatStr, ...
            this.platform, ...
            closest ...
        );

        % check if we have the coordinates in the database already
        existing = engine.database.fetch( metadataName );
        % exit if so
        if ~isempty(existing)
            this.isFinished = true;
            return;
        end

        % check we have orbit files available
        if isempty(safe.orbitFile)
            job = OI.Job( OI.Data.Orbit().generator );
            job.target = '1';
            engine.queue.add_job( job );
            return;
        end
        % Otherwise, we need to preprocess
        % save details


        metadata = this.preprocess_safe( safe, aoi );
        metadata.name = metadataName;
        metadata.platform = this.platform;
        metadata.index = closest;
        
        % add to database
        engine.database.add(metadata, metadataName);

        this.isFinished = true;

    end % run

end % methods

methods (Static)
    function metadata = preprocess_safe( safe, aoi  )
        % aoi is optional, for calculating coverage
        if nargin == 1
            aoi = [];
        end
       metadata = struct();
        % for each swath
        for swathInd = 1:3

            % find a matching strip
            swathIndex = find( cellfun(@(x) x.swath == swathInd, safe.strips) , 1);
            % get the coordinates
            [metadata.swath(swathInd), A] = ...
                OI.Plugins.FilePreProcessor.preprocess_safe_swath( ...
                    safe, swathIndex, aoi );
            % safe.corners.swath(swathInd).index = swathInd;
        end
        if ~isempty(aoi)
            % figure(1);clf;hold on
            % scatter(aoi.lon,aoi.lat,100,'k*')
            metadata.coverage = 0;
            for swathInd = 1:3
                metadata.coverage = metadata.coverage + ...
                    metadata.swath(swathInd).coverage;
                % colo = zeros(1,3);
                % colo(swathInd) = 1;
                % scatter(metadata.swath(swathInd).lon,metadata.swath(swathInd).lat,20,colo,'filled')
            end
            % title( metadata.coverage )
            metadata.coverage = min(1,metadata.coverage);
        end

        % pull anything we need from a swath annotation that applies ...
        % to the whole safe:
        % absolute orbit number:
        metadata.AON =str2double( A.adsHeader.absoluteOrbitNumber );
        metadata.platform = A.adsHeader.missionId;
        % relative orbit number:
        if metadata.platform(3) == 'A'
            metadata.RON = mod(metadata.AON-73,175)+1;
        else
            metadata.RON = mod(metadata.AON-27,175)+1;
        end
        % ascending/descending:
        metadata.pass = A.generalAnnotation.productInformation.pass;


    end

    function [swathMetadata, A] = preprocess_safe_swath( ...
            safe, swathIndex, aoi )
        % aoi is optional, for calculating coverage
        if nargin == 1
            aoi = [];
        end
        swathMetadata = struct();
        swathMetadata.index = swathIndex;
        % get the annotation path
        annotationPath = safe.get_annotation_path( swathIndex );
        % get the annotation
        A = OI.Data.XmlFile( annotationPath ).to_struct();
        
        % get the orbit file
        orbitFile = safe.orbitFile;
        % get the orbit
        O = OI.Data.Orbit(orbitFile);

        % Parse the metadata for useful values, see:
        % https://sentinel.esa.int/documents/247904/1653442/Guide-to-Sentinel-1-Geocoding.pdf
        % Table 4 Sentinel-1 product parameters required for range-Doppler geocoding
        s2n = @str2double;
        swathMetadata.startTime = OI.Data.Datetime( ...
            A.imageAnnotation.imageInformation.productFirstLineUtcTime);
        swathMetadata.endTime = OI.Data.Datetime( ...
            A.imageAnnotation.imageInformation.productLastLineUtcTime);
        [~, swathMetadata.azSpacing ] = deal( s2n( ...
            A.imageAnnotation.imageInformation.azimuthPixelSpacing ));
        [~, swathMetadata.rgSpacing ] = deal( s2n( ...
                A.imageAnnotation.imageInformation.rangePixelSpacing));
        [~, swathMetadata.fastTime ] = deal( s2n( ...
                A.imageAnnotation.imageInformation.slantRangeTime));
        [~, swathMetadata.azimuthTimeInterval ] = deal( s2n( ...
            A.imageAnnotation.imageInformation.azimuthTimeInterval));
        [~, swathMetadata.radarFrequency ] = deal( s2n( ...
            A.generalAnnotation.productInformation.radarFrequency));
        [rsr, swathMetadata.rangeSamplingRate ] = deal( s2n( ...
            A.generalAnnotation.productInformation.rangeSamplingRate));
        [srt, swathMetadata.slantRangeTime ] = deal( s2n( ...
            A.imageAnnotation.imageInformation.slantRangeTime));
        [swathHeight, swathMetadata.swathHeight ] = deal( s2n( ...
            A.imageAnnotation.imageInformation.numberOfLines));
        [swathWidth, swathMetadata.swathWidth ] = deal( s2n( ...
            A.imageAnnotation.imageInformation.numberOfSamples ));
        [~, swathMetadata.heading ] = deal( s2n( ...
            A.generalAnnotation.productInformation.platformHeading ));
        [nBursts, swathMetadata.nBursts] = deal( numel( ...
            A.swathTiming.burstList.burst ));
        [~, swathMetadata.linesPerBurst] = deal( s2n( ...
            A.swathTiming.linesPerBurst ));
        [~, swathMetadata.samplesPerBurst] = deal( s2n( ...
            A.swathTiming.samplesPerBurst ));
            % ati = A.imageAnnotation.imageInformation.azimuthTimeInterval.value_;
            % lpb = A.swathTiming.linesPerBurst.value_;
            % nr = str2double(annotations.imageAnnotation.imageInformation.slantRangeTime.value_)*c/2;   
            % rsr = str2double(annotations.generalAnnotation.productInformation.rangeSamplingRate.value_);
        swathMetadata.incidenceAngle = ...
            s2n(A.imageAnnotation.imageInformation.incidenceAngleMidSwath);

        % get the orbit for the start time
        OSwath = O.interpolate(linspace( ...
            swathMetadata.startTime.datenum(), ...
            swathMetadata.endTime.datenum(), ...
            swathHeight));

        % corners of the swath
        swathCorners = [                ...
            1, 1;                       ...
            1, swathWidth;              ...
            swathHeight, swathWidth;    ...
            swathHeight, 1              ...
        ];

        % get the lat/lon coordinates of the swath corners
        [lat, lon] = OI.Functions.forward_geocode(...
            OSwath, ...
            swathCorners, ...
            srt, ...
            rsr ...
        );
        swathMetadata.lat = lat;
        swathMetadata.lon = lon;
        swathCoverage = 0;
        % for each burst in the swath
        for burstInd = 1:nBursts
            swathMetadata.burst( burstInd ) = ...
                OI.Plugins.FilePreProcessor.preprocess_burst( ...
                    A, ...
                    O, ...
                    burstInd, ...
                    aoi ...
                );
            if ~isempty(aoi)
                swathCoverage = swathCoverage + ...
                    swathMetadata.burst( burstInd ).coverage;
            end
        end

        if ~isempty(aoi)
            swathMetadata.coverage = min(swathCoverage,1);
        end
    end % get_corner_coordinates

    function burstMetadata = preprocess_burst( A, O, burstIndex, aoi )
        if nargin < 4
            aoi = [];
        end

        burstMetadata = struct();
        s2n = @(x) str2double(x);
        % dimensions
        lpb = s2n( A.swathTiming.linesPerBurst );
        spb = s2n( A.swathTiming.samplesPerBurst );
        % timing
        rsr = s2n( A.generalAnnotation.productInformation.rangeSamplingRate );
        srt = s2n( A.imageAnnotation.imageInformation.slantRangeTime );
        ati = s2n( A.imageAnnotation.imageInformation.azimuthTimeInterval );
        % get the burst start and end time
        % !!!BLAME!!
        % burstStartTime = OI.Data.Datetime( ...
        %     A.swathTiming.burstList.burst(burstIndex).sensingTime.value_ ...
        %     ).datenum();
        % The correction for elctronic steering or some other affect might
        % not have been applied to the sensingTime value? Whatever the
        % cause, it is off by ~1 sec and azimuthTime is accurate
        burstStartTime = OI.Data.Datetime( ...
            A.swathTiming.burstList.burst(burstIndex).azimuthTime ...
            ).datenum();
        burstEndTime = burstStartTime + ...
            (ati * lpb)/86400; % secs to days
        % get the orbit for the burst time
        OBurst = O.interpolate(linspace( ...
            burstStartTime, ...
            burstEndTime, ...
            lpb ));

        % corners of the burst
        burstCorners = [ ...
            1, 1; ...
            1, spb; ...
            lpb, spb; ...
            lpb, 1 ...
        ];

        % get the burst corners
        [lat,lon] = OI.Functions.forward_geocode(...
            OBurst, burstCorners, srt, rsr);

        % add to the metadata struct
        burstMetadata.lat = lat;
        burstMetadata.lon = lon;
        burstMetadata.index = burstIndex;
        burstMetadata.startTime = burstStartTime;
        burstMetadata.endTime = burstEndTime;

        % calculate coverage if an aoi is provided
        if ~isempty(aoi)
                g = OI.Data.GeographicArea();
                g.lat = lat;
                g.lon = lon;
                burstMetadata.coverage = ...
                    OI.Functions.coverage(aoi,g);
        end
    end

end % methods static
end% classdef




% classdef GetOrbits < OI.Plugins.PluginBase

% properties
%     inputs = {OI.Data.Catalogue()}
%     outputs = {OI.Data.Orbit()}
%     datetime % to get the orbit file for
%     platform % to get the orbit file for
%     id = 'GetOrbits';
% end % properties

% methods
%     function this = GetOrbits(varargin)

%     end

%     function this = run(this, engine, varargin)
%         varargin = varargin{1};
%         doStartup = false;
%         doFinalise = false;

%         % find the varagin key value pairs
%         for i = 1:2:length(varargin)
%             switch varargin{i}
%                 case {'date', 'datetime', 'time'}
%                     argIn = varargin{i+1};
%                     if ischar(argIn)
%                         argIn = str2double(argIn);
%                     end
%                     % engine.ui.log('trace', 'GetOrbits: datetime set to %s\n', num2str(argIn))
%                     this.datetime = OI.Data.Datetime(argIn);
%                 case 'platform'
%                     % engine.ui.log('trace', 'GetOrbits: platform set to %s\n', varargin{i+1})
%                     this.platform = varargin{i+1};
%                 case {'finalise','final','finish','finalize'}
%                     % engine.ui.log('trace', 'GetOrbits: validate set to %s\n', varargin{i+1})
%                     doFinalise = true;
%                 otherwise
%                     engine.ui.log('debug','Unknown key value pair');
%             end% switch
%         end% for

%         % if no specific orbit requested, make a job for each orbit in catalogue
%         if (isempty(this.datetime) || isempty(this.platform))
%             % check the orbit directory
%             project = engine.load( OI.Data.ProjectDefinition() );
%             % make if not
%             if ~exist(project.ORBITS_DIR, 'dir')
%                 OI.Functions.mkdirs(project.ORBITS_DIR);
%             end
%             % get the files
%             orbitFiles = dir(project.ORBITS_DIR);
%             orbitFiles = orbitFiles(3:end);

%             % get the catalogue
%             catalogue = engine.load( OI.Data.Catalogue() );

%             % for each safe in the catalogue
%             for ii=1:numel(catalogue.safes)
%                 % get the datetime
%                 datetime = catalogue.safes{ii}.date;
%                 % get the platform
%                 platform = catalogue.safes{ii}.platform;

%                 % see if the orbit file exists in the orbit directory
%                 orbitFile = OI.Data.Orbit().find(platform, datetime, orbitFiles);

%                 if isempty( orbitFile )
%                     % create a job with the date and platform
%                     engine.requeue_job('datetime', datetime.datenum(), 'platform', platform);
%                 else
%                     % add the orbit file to the catalogue
%                     catalogue.safes{ii}.orbitFile = orbitFile;
%                 end
%             end

%             % check if any safe is missing an orbit file
%             hasOrbitForSafe = cellfun(@(x) ~isempty(x.orbitFile), catalogue.safes);
%             hasOrbitForSafe
%             if ~all(hasOrbitForSafe)
%                 % requeue this job
%                 % engine.requeue_job();
%                 this.isFinished = false;
%             else
%                 % save the catalogue
%                 catalogue.overwrite = true;
%                 'calling it '
%                 engine.save(catalogue,catalogue);
%                 this.isFinished = true;
%             end


%             return
%         end

%         engine.queue.jobArray



%         % fill in some deets
%         [name, link] = this.api_check();
%         this.outputs{1}.id = name;
%         this.outputs{1}.link = link;
%         % this.outputs{1}.datetime = this.datetime;
%         this.outputs{1}.platform = this.platform;

%         % generate filepath for orbit file
%         this.outputs{1}.nameOfPoeFile = name;
%         this.outputs{1}.link = link;
%         fp = this.outputs{1}.filepath;
%         this.outputs{1}.filepath = this.outputs{1}.string_interpolation(fp, engine);

%         % does the orbit file exist?
%         existsAlready = this.outputs{1}.exists();

%         % download if not
%         if ~existsAlready
%             status = this.download();
%             if status
%                 error('Download failed with curl status code %d', status)
%             end
%         end

%         % save the orbit file
%         engine.save(this.outputs{1});


%         %[poefilepath, POEfile, POEfilename]=ICS_3_1_GetPreciseOrbitsFilePath(datetofind,s1AB,Settings,flt,POEFS,POEfilenames);

%     end % run(

%     function [name, link] = api_check(this)

%         % project = engine.load( OI.Data.ProjectDefinition() );
%         datetime = this.datetime.datenum();
%         % project.ORBITS_DIR

%         % create the query
%         qString = sprintf('(beginPosition:[%sT00:00:00.000Z TO %sT23:59:59.999Z] AND endPosition:[%sT00:00:00.000Z TO %sT23:59:59.999Z] ) AND ( (platformname:%s AND producttype:AUX_POEORB))', ...
%             datestr(datetime-1, 'yyyy-mm-dd'), datestr(datetime, 'yyyy-mm-dd'), ...
%             datestr(datetime, 'yyyy-mm-dd'), datestr(datetime+1, 'yyyy-mm-dd'), ...
%             'Sentinel-1');
%         params = struct('q', qString, 'rows', '100', 'start', '0', 'format', 'json');

%         query = OI.Query( 'https://scihub.copernicus.eu/gnss/search' , params );
%         query.username = 'gnssguest';
%         query.password = 'gnssguest';


%         % get the results
%         results = query.get_response();

%         % parse the json
%         json = jsondecode(results);

%         if ~isfield(json.feed, 'entry')
%             disp(json)
%             error('No orbit files found for %s on %s\nQuery url:\n%s\n', this.platform, datestr(this.datetime.datenum(), 'yyyy-mm-dd'), query.url)
%         end
%         % get the etries
%         entries = json.feed.entry;

%         % check we got some results
%         if isempty(entries)
%             error('No orbit files found for %s on %s\nQuery url:\n%s\n', this.platform, datestr(this.datetime.datenum(), 'yyyy-mm-dd'), query.url)
%         end
%         % loop through the entries
%         for entryIndex = 1:numel(entries)
%             entry = entries(entryIndex);
%             % get the title
%             name = entry.title;
%             % check if platform is correct
%             rightPlatform = strcmpi(name(1:3), this.platform);
%             if rightPlatform
%                 % get the link
%                 link = entry.link{1}.href;
%                 break
%             end
%         end
%     end % api_check

%     function status = download(this)
%         url = this.outputs{1}.link
%         filename = [this.outputs{1}.filepath '.' this.outputs{1}.fileextension]

%         dir = fileparts(filename);
%         if ~exist(dir, 'dir')
%             OI.Functions.mkdirs(dir);
%         end


%         % download the orbit file
%         % status = webread(filename, url);
%         curlCommand = sprintf('curl -u gnssguest:gnssguest -o %s %s', filename, url);
%         [status, result] = system(curlCommand);
%         % status
%         % result
%     end % download

% end % methods

% end % classdef

% % Response = {"feed":{"xmlns":"http://www.w3.org/2005/Atom","xmlns:opensearch":"http://a9.com/-/spec/opensearch/1.1/","title":"Sentinels GNSS RINEX Hub search results for: (beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))","subtitle":"Displaying 1 results. Request done in 0 seconds.","updated":"2023-03-31T17:00:24.814Z","author":{"name":"Sentinels GNSS RINEX Hub"},"id":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))","opensearch:totalResults":"1","opensearch:startIndex":"0","opensearch:itemsPerPage":"100","opensearch:Query":{"startPage":"1","searchTerms":"(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))","role":"request"},"link":[{"href":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))&start=0&rows=100&format=json","type":"application/json","rel":"self"},{"href":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))&start=0&rows=100&format=json","type":"application/json","rel":"first"},{"href":"https://scihub.copernicus.eu/gnss/search?q=(beginPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] AND endPosition:[2023-01-29T00:00:00.000Z TO 2023-01-31T23:59:59.999Z] ) AND ( (platformname:Sentinel-1 AND producttype:AUX_POEORB))&start=0&rows=100&format=json","type":"application/json","rel":"last"},{"href":"opensearch_description.xml","type":"application/opensearchdescription+xml","rel":"search"}],"entry":{"title":"S1A_OPER_AUX_POEORB_OPOD_20230219T080751_V20230129T225942_20230131T005942","link":[{"href":"https://scihub.copernicus.eu/gnss/odata/v1/Products('4d94ac07-481d-4470-a01c-3586f27661d3')/$value"},{"rel":"alternative","href":"https://scihub.copernicus.eu/gnss/odata/v1/Products('4d94ac07-481d-4470-a01c-3586f27661d3')/"},{"rel":"icon","href":"https://scihub.copernicus.eu/gnss/odata/v1/Products('4d94ac07-481d-4470-a01c-3586f27661d3')/Products('Quicklook')/$value"}],"id":"4d94ac07-481d-4470-a01c-3586f27661d3","summary":"Date: 2023-01-29T22:59:42Z, Instrument: , Satellite: Sentinel-1, Size: 4.43 MB","ondemand":"false","date":[{"name":"generationdate","content":"2023-02-19T08:07:51Z"},{"name":"beginposition","content":"2023-01-29T22:59:42Z"},{"name":"endposition","content":"2023-01-31T00:59:42Z"},{"name":"ingestiondate","content":"2023-02-19T08:40:11.504Z"}],"str":[{"name":"format","content":"EOF"},{"name":"size","content":"4.43 MB"},{"name":"platformname","content":"Sentinel-1"},{"name":"platformshortname","content":"S1"},{"name":"platformnumber","content":"A"},{"name":"platformserialidentifier","content":"1A"},{"name":"filename","content":"S1A_OPER_AUX_POEORB_OPOD_20230219T080751_V20230129T225942_20230131T005942.EOF"},{"name":"producttype","content":"AUX_POEORB"},{"name":"filedescription","content":"Precise Orbit Ephemerides (POE) Orbit File"},{"name":"fileclass","content":"OPER"},{"name":"creator","content":"OPOD"},{"name":"creatorversion","content":"3.1.0"},{"name":"identifier","content":"S1A_OPER_AUX_POEORB_OPOD_20230219T080751_V20230129T225942_20230131T005942"},{"name":"uuid","content":"4d94ac07-481d-4470-a01c-3586f27661d3"}]}}}
