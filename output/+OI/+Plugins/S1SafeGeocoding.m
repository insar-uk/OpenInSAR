classdef S1SafeGeocoding < OI.Plugins.PluginBase
    %S1SAFEGEOCODING Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        inputs = {OI.Data.Catalogue()}
        outputs = {OI.Data.S1SafeCoordinateArray()}
        datetime = '';
        platform = '';
        id = 'S1SafeGeocoding'
    end
    
    methods
        function this = run(this, engine,varargin)
            varargin = varargin{1};
            cat = engine.load( OI.Data.Catalogue() );
            % find the varagin key value pairs
            for i = 1:2:length(varargin)
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
                    otherwise
                        engine.ui.log('debug','Unknown key value pair %s\n', varargin{i});
                end% switch
            end% for

            1;

            coordFormatStr = 'CornerCoordinates_%s_%d_InCatalogue';
            if isempty(this.datetime)
                % first call, create jobs.
                jobsAdded = 0;
                
                % for each safe in the catalogue
                for ii=1:numel(cat.safes)
                    % get the datetime & platform
                    targetDatetime = cat.safes{ii}.date;
                    targetPlatform = cat.safes{ii}.platform;
                    % check if we have the coordinates in the database
                    coordName = sprintf(coordFormatStr, targetPlatform, ii);
                    existing = engine.database.fetch(coordName);
                    if isempty(existing)
                        % create a job with the datetime
                        jobsAdded = jobsAdded + 1;
                        engine.requeue_job_at_index( ...
                            jobsAdded, ...
                            'platform', targetPlatform, ...
                            'datetime', targetDatetime.datenum());
                        
                    else
                        % add the data to an array
                        fns = fieldnames(existing);
                        for fn = fns(:)'
                            this.outputs{1}.coordinates(ii).(fn{1}) = ...
                                existing.(fn{1});
                        end
                    end
                end % for safes
                if jobsAdded == 0 
                    % save the struct
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

            coordName = sprintf(coordFormatStr, ...
                this.platform, closest);
            
            existing = engine.database.fetch(coordName);
            if ~isempty(existing)
                % were done
                engine.ui.log('debug', 'S1SafeGeocoding: found existing coordinates for %s\n', coordName);
                this.isFinished = true;
                return;
            end

            % get the orbit file
            orbitFile = safe.orbitFile;
            % for each swath
            for swathInd = 1:3
                % find a matching strip
                stripIndex = find( cellfun(@(x) x.swath == swathInd, safe.strips) , 1);
                % get the annotation path
                annotationPath = safe.get_annotation_path( stripIndex );
                % get the coordinates
                safe.corners.swath(swathInd) = ...
                    this.get_corner_coordinates(annotationPath, orbitFile);
                % safe.corners.swath(swathInd).index = swathInd;
            end
            safe.corners.name = coordName;
            safe.corners.platform = this.platform;
            safe.corners.index = closest;
            % add to database
            engine.database.add(safe.corners, coordName);
            this.isFinished = true;


        end % run

    end % methods

    methods (Static)
        function corners = get_corner_coordinates(annotationPath, orbitFile)
            % get the annotation
            A = OI.Data.XmlFile( annotationPath ).to_struct();
            % get the orbit
            O = OI.Data.Orbit(orbitFile);

            % See https://sentinel.esa.int/documents/247904/1653442/Guide-to-Sentinel-1-Geocoding.pdf
            % Table 4 Sentinel-1 product parameters required for range-Doppler geocoding
            s2n = @str2double;
            % azSpacing = s2n(A.imageAnnotation.imageInformation.azimuthPixelSpacing.value_);
            startTime = OI.Data.Datetime(A.imageAnnotation.imageInformation.productFirstLineUtcTime.value_);
            endTime = OI.Data.Datetime(A.imageAnnotation.imageInformation.productLastLineUtcTime.value_);
            % fastTime = s2n(A.imageAnnotation.imageInformation.slantRangeTime.value_);
            % lineTimeInterval = s2n(A.imageAnnotation.imageInformation.azimuthTimeInterval.value_);
            % radarFreq = s2n(A.generalAnnotation.productInformation.radarFrequency.value_);
            % rgSampleRate = s2n(A.generalAnnotation.productInformation.rangeSamplingRate.value_);
            swathHeight = s2n(A.imageAnnotation.imageInformation.numberOfLines.value_);
            swathWidth = s2n(A.imageAnnotation.imageInformation.numberOfSamples.value_);
            % heading = s2n(A.generalAnnotation.productInformation.platformHeading.value_);
            % get the orbit for the start time
            OSwath = O.interpolate(linspace(startTime.datenum(),endTime.datenum(),swathHeight));

            % corners of the swath
            swathCorners = [                ...
                1, 1;                       ...
                1, swathWidth;              ...
                swathHeight, swathWidth;    ...
                swathHeight, 1              ...
            ];
            corners = struct();
            [lat, lon] = OI.Functions.forward_geocode(...
                OSwath, ...
                swathCorners, ...
                A);
            corners.lat = lat;
            corners.lon = lon;
            corners.index = s2n(A.adsHeader.swath.value_(3)); %swath
            nBursts = numel(A.swathTiming.burstList.burst);
            linesPerBurst = s2n(A.swathTiming.linesPerBurst.value_);
            samplesPerBurst = s2n(A.swathTiming.samplesPerBurst.value_);
            ati = s2n(A.imageAnnotation.imageInformation.azimuthTimeInterval.value_);

            % for each burst in the swath
            for burstInd = 1:nBursts
                % get the burst
                % B = A.swathTiming.burstList.burst(bInd);
                % get the burst start time
                burstStartTime = OI.Data.Datetime( ...
                    A.swathTiming.burstList.burst(burstInd).sensingTime.value_ ...
                    ).datenum();

                % get the burst end time
                burstEndTime = burstStartTime + ...
                    (ati * linesPerBurst)/86400; % secs to days
                % get the orbit for the burst
                OBurst = O.interpolate(linspace(burstStartTime,burstEndTime,linesPerBurst));
                % corners of the burst
                burstCorners = [                ...
                    1, 1;                       ...
                    1, samplesPerBurst;              ...
                    linesPerBurst, samplesPerBurst;    ...
                    linesPerBurst, 1              ...
                ];
                % get the burst corners
                [lat,lon] = OI.Functions.forward_geocode(...
                    OBurst, burstCorners, A);
                % add to the corners struct
                corners.burst(burstInd).lat = lat;
                corners.burst(burstInd).lon = lon;
                corners.burst(burstInd).index = burstInd;
            end
        end % get_corner_coordinates

    end % methods static


end% classdef