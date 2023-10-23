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
            engine.ui.log('debug','No catalogue or project definition loaded\n')
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
                    jobsAdded = jobsAdded + 1;
                    engine.requeue_job_at_index(jobsAdded, ...
                        'platform', safePlatform, ...
                        'datetime', safeDatetime.datenum());
                    
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
        % There was an issue here:
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