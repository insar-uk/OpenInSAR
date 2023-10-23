classdef Geocoding < OI.Plugins.PluginBase
     %#ok<*NASGU>
      %#ok<*ASGLU>
 %#ok<*NOPRT>
    properties
        inputs = {OI.Data.Stacks(), OI.Data.PreprocessedFiles(), OI.Data.DEM()}
        outputs = {OI.Data.GeocodingSummary()}
        id = 'Geocoding'
        segmentIndex 
        trackIndex
    end
    
    methods
        function this = Geocoding( varargin )
            this.isArray = true;
        end

        function this = run( this, engine, varargin )
            
            engine.ui.log('info','Begin loading inputs for %s\n',this.id);

            cat = engine.load( OI.Data.Catalogue() );
            preprocessingInfo = engine.load( OI.Data.PreprocessedFiles() );
            stacks = engine.load( OI.Data.Stacks() );
            dem = engine.load( OI.Data.DEM() );
            
            % If missing inputs, return and allow engine to requeue
            if isempty(preprocessingInfo) || isempty(stacks) || isempty(dem) || isempty(cat)
                return;
            end
            
            engine.ui.log('debug','Finished loading for %s\n',this.id);
            if isempty(this.segmentIndex)
                % check if all the data is in the database
                allDone = true;
                jobCount = 0;
                for trackInd = 1:numel(stacks.stack)
                    if isempty( stacks.stack( trackInd ).reference )
                        continue;
                    end
                for segmentInd = stacks.stack( trackInd ).reference.segments.index

                    result = OI.Data.LatLonEleForImage();
                    result.STACK = num2str(trackInd);
                    result.SEGMENT_INDEX = num2str(segmentInd);
                    result = result.identify( engine );
                    resultInDatabase = engine.database.find( result );

                    allDone = allDone && ~isempty( resultInDatabase );
                    if allDone % add to output
                        % if isempty( this.outputs{1}.value )
                        %     this.outputs{1}.value = [trackInd, segmentInd];
                        % else
                        this.outputs{1}.value(end+1,:) = [trackInd, segmentInd];
                        % end
                    else
                        jobCount = jobCount + 1;
                        engine.requeue_job_at_index( ...
                            jobCount, ...
                            'trackIndex',trackInd, ...
                            'segmentIndex', segmentInd);
                    end
                end %
                end %
                if allDone % we have done all the tracks and segments
                    engine.save( this.outputs{1} );
                    this.isFinished = true;
                end
                return;
            end

            % do some magic
            segInd = this.segmentIndex;
            thisRef = stacks.stack(this.trackIndex).reference;

            result = OI.Data.LatLonEleForImage();
            result.STACK = num2str(this.trackIndex);
            result.SEGMENT_INDEX = num2str(this.segmentIndex);
            result = result.identify( engine )

            if ~this.isOverwriting && ...
                    exist([result.filepath '.' result.fileextension],'file')
                % add it to database so we know later
                engine.database.add( result );
                this.isFinished = true;
                return;
            end

            % address of the data in the catalogue and metadata
            safeIndex= stacks.stack(this.trackIndex).segments.safe( segInd );
            swathIndex =stacks.stack(this.trackIndex).segments.swath( segInd );
            burstIndex = stacks.stack(this.trackIndex).segments.burst( segInd );
            % get metadata
            swathInfo = ...
                preprocessingInfo.metadata( safeIndex ).swath( swathIndex );
            
            % get parameters from metadata
            [lpb,spb,nearRange,rangeSampleDistance] = ...
                OI.Plugins.Geocoding.get_parameters( swathInfo );

            % get the orbit
            engine.ui.log('info','Interpolating orbits\n');
            [orbit, lineTimes] = ...
                OI.Plugins.Geocoding.get_poe_and_timings( ...
                    cat, safeIndex, swathInfo, burstIndex );  
                
            if isempty(orbit.t)
                % No orbit file
               return
            end
            tOrbit = orbit.interpolate( repmat(lineTimes,spb,1) );
                satXYZ = [ ...
                        tOrbit.x(:), ...
                        tOrbit.y(:), ...
                        tOrbit.z(:) ...
                    ];
                satV = [ ...
                        tOrbit.vx(:), ...
                        tOrbit.vy(:), ...
                        tOrbit.vz(:) ...
                    ];

            % define this variable because matlab pollutes the namespace
            elevation = 'a variable not a function';
            toleranceProgression = 10.^(0:-1:-1);
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   GEOCODING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Map az,rg to lat,lon,height
            [~, ~, burstCorners, ~,~ ] = ...
            OI.Plugins.Geocoding.get_geometry(lpb,spb);
            inds = (burstCorners(:,1)-1)*spb+burstCorners(:,2);

            % ALIASES TO UPDATE XYZ COORDINATES AND ELEVATION
            xyzUpd = @OI.Functions.lla2xyz;
            eleUpd = @dem.interpolate;

            % INITIAL ESTIMATES OF LAT LON ELE
            [lat, lon] = OI.Plugins.Geocoding.get_initial_geocoding( ...
            swathInfo, burstIndex);
            [dem, elevation] = eleUpd( lat, lon );
            xyz = xyzUpd( lat, lon, elevation );

            % RANGE DOPPLER ERROR ESTIMATES IN TERMS OF AZ/RG INDEX OFFSET
            % AZ ERROR VIA DOPPLER
            dopplerPerAzLine = OI.Plugins.Geocoding.get_doppler_per_line( ...
                    swathInfo, satXYZ, satV, lat, lon, elevation);
            azUpd = @( xyz ) ...
            OI.Functions.doppler_eq( ...
                satXYZ, ...
                satV, ...
                xyz ) ...
            ./ dopplerPerAzLine;
            % RG ERROR
            [lpb,spb,nearRange,rangeSampleDistance] = ...
            OI.Plugins.Geocoding.get_parameters(swathInfo);
            sz=[lpb,spb];
            [rangeSample, azLine] = ...
            OI.Plugins.Geocoding.get_geometry(lpb,spb);
            rgUpd = @(xyz) rangeSample(:) - ...
            (OI.Functions.range_eq( satXYZ, xyz ) ...
            - nearRange ) ...
            ./ rangeSampleDistance;
            rgUpdSubset = @(xyz,subset) rangeSample(subset) - ...
            (OI.Functions.range_eq( satXYZ(subset,:), xyz ) ...
            - nearRange ) ...
            ./ rangeSampleDistance;

            % polynomials for lat/lon
            rgPolyFun = @(r) [r.^3 r.^2 r ones(size(r,1),1)];
            rgCentreScale = @(idx) (idx)/spb - .5;
            azCentreScale = @(idx) (idx)/lpb - .5;
            ind2coeff = @(idx) rgPolyFun( rgCentreScale( idx ) );
            rgCoefficients = ind2coeff( [1:spb]' ); %#ok<NBRAK1>

            latByAzRg = [azCentreScale(azLine(:)) rgCentreScale(rangeSample(:)) ...
            ones(numel(azLine),1) ] \ ...
            lat(:);
            lonByAzRg = [azCentreScale(azLine(:)) rgCentreScale(rangeSample(:)) ...
            ones(numel(azLine),1) ] \ ...
            lon(:);

            errorToLat = @(azErr,rgErr) ...
            [azCentreScale(azErr)+.5, rgCentreScale(rgErr)+.5 0.*rgErr] * latByAzRg;
            errorToLon = @(azErr,rgErr) ...
            [azCentreScale(azErr)+.5, rgCentreScale(rgErr)+.5 0.*rgErr] * lonByAzRg;

            % Progressively narrow the tolerance for error:
            if ~exist('toleranceProgression','var')
            toleranceProgression = 10.^(0:-1:-3);
            end
            for tolerance = toleranceProgression
            engine.ui.log('info','Geocoding to a tolerance of %f pixels\n',tolerance);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   LINES OF ZERO DOPPLER
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % fix the lat lon until there is zero doppler error

            doppIter = 0;
            dopStartTime = tic;
            % Eventually halve the shift to prevent bouncing
            dampingCurve = @(iter) 1/2+exp(-(iter-1).^3/500)/2;
            % Proper newton raphson would probably work better but this is fine.
            while doppIter < 10
                doppIter = doppIter + 1;
                azError = azUpd( xyz ) .* dampingCurve(doppIter);
                % if doppIter>1
                %     improvement = azError./lastAzError;
                % end
                lastAzError = azError;
                rgError = rgUpd( xyz );

                engine.ui.log('info','Max doppler error is now: %f\n',max(abs(azError)));
                engine.ui.log('info','Mean doppler error is now: %f\n',mean(abs(azError)));
                engine.ui.log('info','Max rgError error is now: %f\n',max(abs(rgError)));
                engine.ui.log('info','Mean rgError error is now: %f\n',mean(abs(rgError)));
                if max(abs(azError)) < tolerance
                    engine.ui.log('trace','Doppler error is now within tolerance\n');
                    break
                end
                
                % update lat/lon
                lat = lat + errorToLat(azError, rgError);
                lon = lon + errorToLon(azError, rgError);

                [dem, elevation] = eleUpd( lat, lon );
                xyz = xyzUpd( lat, lon, elevation );
            end % doppler loop
            engine.ui.log('info','Doppler loop took %f seconds\n',toc(dopStartTime));


            % once we have accurate lat/lon coords for zero doppler, fit a
            % polynomial to each az line which describes how lat/lon vary with
            % respect to range.
            % rext = [0:spb-1]'./spb;
            % midRange = mean(rext);
            % rext = rext - midRange;
            % RMAT = [rext.^3, rext.^2 rext ones(spb,1)];
            % latRangePolyByLine = RMAT \ reshape(lat,lpb,spb)';
            % lonRangePolyByLine = RMAT \ reshape(lon,lpb,spb)';
            % latRangePolyByLine = RMAT \ reshape(lat,lpb,spb)';
            % lonRangePolyByLine = RMAT \ reshape(lon,lpb,spb)';


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   RANGE ZERO CROSSINGS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % find the zero range error by triangulating the zero-crossing
                
            rzcStartTime = tic;
            % update lat lon to their best life
            %             maybe update the error to lat lon ones too

            lastLat = lat;
            lastLon = lon;
            lastRgError = rgError;
            % the error functions need to be updated with the new zero doppler
            % polynomials
            latByAzRg = [azCentreScale(azLine(:)) rgCentreScale(rangeSample(:)) ...
                ones(numel(azLine),1) ] \ ...
                lat(:);
            lonByAzRg = [azCentreScale(azLine(:)) rgCentreScale(rangeSample(:)) ...
                ones(numel(azLine),1) ] \ ...
                lon(:);
            errorToLat = @(azErr,rgErr) ...
                [azCentreScale(azErr)+.5, rgCentreScale(rgErr)+.5 0.*rgErr] * latByAzRg;
            errorToLon = @(azErr,rgErr) ...
                [azCentreScale(azErr)+.5, rgCentreScale(rgErr)+.5 0.*rgErr] * lonByAzRg;
            % 
            %     %
            % % get the range error for the test index
            % testIndex = lastRgError(:);
            % lat = lastLat + errorToLat(zeros(spb*lpb,1), testIndex);
            % lon = lastLon + errorToLon(zeros(spb*lpb,1), testIndex);
            % [dem, elevation] = eleUpd( lat, lon );
            % xyz = xyzUpd( lat, lon, elevation );
            % rgError = rgUpd( xyz );
            % imagesc(reshape(rgError,sz));colorbar

            % % this should equal zero:
            % % get the range error for the test index
            % testIndex = zeros(spb*lpb,1);
            % lat = lastLat + errorToLat(zeros(spb*lpb,1), testIndex);
            % lon = lastLon + errorToLon(zeros(spb*lpb,1), testIndex);
            % [dem, elevation] = eleUpd( lat, lon );
            % xyz = xyzUpd( lat, lon, elevation );
            % rgError = rgUpd( xyz );
            % imagesc(reshape(rgError-lastRgError,sz));colorbar

            initBoundsTime = tic;
            [indexWindow, errorWindow, hitCount] = deal(zeros(lpb*spb,2));
            %% NOW WE NEED TO FIND UPPER AND LOWER BOUNDS OF THE ZERO CROSSInG bEFORE BISECTING %%
            % find the zero range error by triangulating the zero-crossing
                % Rmax = max(rgError) + tolerance * 10;
                % Rmin = min(rgError) - tolerance * 10;
                % indexWindow = [Rmin Rmax] .* ones(spb*lpb,1);

            % F(testIndex=0) = lastRgError; 
            isPositiveError = lastRgError > 0;
            isNegativeError = lastRgError < 0;
            % So 0 will be one of our bounds, it remains to find the other one...
            indexWindow(~isPositiveError,1) = lastRgError(~isPositiveError);
            indexWindow(~isNegativeError,2) = lastRgError(~isNegativeError);

            % update the error window, depending on the sign of the error
            errorWindow(isPositiveError,1) = rgError(isPositiveError);
            errorWindow(isNegativeError,2) = rgError(isNegativeError);

            % update the hit count
            hitCount(isPositiveError,1) = hitCount(isPositiveError,1) + 1;
            hitCount(isNegativeError,2) = hitCount(isNegativeError,2) + 1;

            % % These errors should all be positive, but won't be:
            % testIndex = lastRgError(:);
            % lat = lastLat + errorToLat(zeros(spb*lpb,1), testIndex);
            % lon = lastLon + errorToLon(zeros(spb*lpb,1), testIndex);
            % [dem, elevation] = eleUpd( lat, lon );
            % xyz = xyzUpd( lat, lon, elevation );
            % rgError = rgUpd( xyz );
            % imagesc(reshape(rgError,sz));colorbar
                

            % Adjust bounds until we get what we want
            for bound = 1:2
            desiredErrorSign = sign(1.5-bound);
            rangeSearchDirection = -desiredErrorSign;
            testIndex = indexWindow(:,bound);
            adjustment = 0.*indexWindow(:,1);
            badInds = find( (~isPositiveError & (bound==1)) ...
                | (~isNegativeError & (bound==2)));
            while ~isempty(badInds)
                tic
                const0 = zeros(size(badInds));
                badlat = lastLat(badInds) + errorToLat(const0, ...
                    testIndex(badInds) + ...
                    adjustment(badInds));
                badlon = lastLon(badInds) + errorToLon(const0, ...
                    testIndex(badInds) + ...
                    adjustment(badInds)); 
                % some discrepancy occurs if the dem extent changes,
                % maintain same extent
                [dem, badelevation] = eleUpd( ...
                    [min(lat); badlat; max(lat)], ...
                    [min(lon); badlon; max(lon)]  );
                badxyz = xyzUpd( badlat, badlon, badelevation(2:end-1) );
                badrangeError = rgUpdSubset( badxyz, badInds );
                % if the prior adjustment worked, we don't need to update it;
                
                nowOkay = sign(badrangeError) == desiredErrorSign;
                % save any results that are OKAY
                errorWindow(badInds(nowOkay), bound) = badrangeError(nowOkay);
                hitCount(badInds(nowOkay), bound) = ...
                    hitCount(badInds(nowOkay),bound) + 1;

                % adjust any that are not
                adjustment(badInds(~nowOkay)) = adjustment(badInds(~nowOkay)) ...
                    + badrangeError(~nowOkay) * 2 + ...
                    rangeSearchDirection * tolerance * 10;
                badInds = badInds(~nowOkay);
                % 
                % adjustment(badInds) = adjustment(badInds) - ...
                %     tolerance*10 ...
                %     + badrangeError * 10;
                % 
                fprintf(1,'%d ',numel(badInds))
                toc
            end
            % update the bound
            indexWindow(:,bound) = indexWindow(:,bound) + adjustment;
            fprintf(1,'\n');
            end

            % figure(1)
            testIndex = indexWindow(:,1);
            lat = lastLat + errorToLat(zeros(spb*lpb,1), testIndex);
            lon = lastLon + errorToLon(zeros(spb*lpb,1), testIndex);
            [dem, elevation] = eleUpd( lat, lon );
            xyz = xyzUpd( lat, lon, elevation );
            rgError = rgUpd( xyz );
            % imagesc(reshape(rgError,sz));colorbar
            % title(sprintf('Lower bound: %d below 0',sum(rgError<0)))
            assert(~sum(rgError<0))

            % figure(2)
            testIndex = indexWindow(:,2);
            lat = lastLat + errorToLat(zeros(spb*lpb,1), testIndex);
            lon = lastLon + errorToLon(zeros(spb*lpb,1), testIndex);
            [dem, elevation] = eleUpd( lat, lon );
            xyz = xyzUpd( lat, lon, elevation );
            rgError = rgUpd( xyz );
            % imagesc(reshape(rgError,sz));colorbar
            % title(sprintf('Upper bound: %d above 0',sum(rgError>0)))
            assert(~sum(rgError>0))

            engine.ui.log('info','Initialising bounds took %f seconds\n',toc(initBoundsTime));
            %% Now we bisect to find the zero cross to a given tolerance

            bisectZeroCrossingTime = tic;
            isOkay = zeros(lpb*spb,1,'logical');
            rzcIter = 1;
            while rzcIter < 10
                rzcIter = rzcIter + 1;

                proportionalShift = errorWindow(:,1) ./ ...
                            (errorWindow(:,1) - errorWindow(:,2));
                % sometimes one bound will be really close and the other really far
                % away. This causes a lot of repetition. 
                % To fix this, bias it towards the underused bound.
                hitProportion = proportionalShift;
                hitProportion(~isOkay,:) = ...
                    hitCount(~isOkay,1) ...
                    ./(hitCount(~isOkay,1)+hitCount(~isOkay,2));
                proportionalShift = (hitProportion + proportionalShift)/2;
                testIndex = indexWindow(:,1) + ...
                    (indexWindow(:,2) - indexWindow(:,1)) .* proportionalShift;

                % get the range error for the test index
                lat = lastLat + errorToLat(zeros(spb*lpb,1), testIndex);
                lon = lastLon + errorToLon(zeros(spb*lpb,1), testIndex);
                % update xyz and elevation
                [dem, elevation] = eleUpd( lat, lon );
                xyz = xyzUpd( lat, lon, elevation );
                % get the range error
                rgError = rgUpd( xyz );
                isPositiveError = rgError > 0;
                isNegativeError = rgError < 0;

                % update the error window, depending on the sign of the error
                errorWindow(isPositiveError,1) = rgError(isPositiveError);
                errorWindow(isNegativeError,2) = rgError(isNegativeError);

                % update the hit count
                hitCount(isPositiveError,1) = hitCount(isPositiveError,1) + 1;
                hitCount(isNegativeError,2) = hitCount(isNegativeError,2) + 1;

                % update the index window
                indexWindow(isPositiveError,1) = testIndex(isPositiveError);
                indexWindow(isNegativeError,2) = testIndex(isNegativeError);

                % check for convergence
                isOkay = abs(rgError) < tolerance | ...
                    indexWindow(:,2) - indexWindow(:,1) < tolerance;
                fprintf('Found zero crossings for %.2f %% of pixels\n', ...
                    100*sum(isOkay)./(spb*lpb));
                fprintf('Mean range error: %.3f\n',mean(abs(rgError)));
                if all(isOkay)
                    engine.ui.log('trace','Range error is now within tolerance\n');
                    % choose the lowest error
                    lowerBoundIsLowerError = ...
                        abs(errorWindow(:,1)) < abs(errorWindow(:,2));
                    testIndex = indexWindow(:,2);
                    testIndex(lowerBoundIsLowerError) = ...
                        indexWindow(lowerBoundIsLowerError,1);
                    lat = lastLat + errorToLat(zeros(spb*lpb,1), testIndex);
                    lon = lastLon + errorToLon(zeros(spb*lpb,1), testIndex);
                    [dem, elevation] = eleUpd( lat, lon );
                    xyz = xyzUpd( lat, lon, elevation );
                    break % the while loop
                end % check for converge
            end % while
            zcLat = lat;
            zcLon = lon;
            engine.ui.log('info','Triangulating zero crossing took %f seconds\n', ...
                toc(bisectZeroCrossingTime));

            end % tolerance loop

            azError = azUpd( xyz );
            rgError = rgUpd( xyz );
            % save the result
            engine.save(result, [lat(:) lon(:) elevation(:)]);

            % save a preview kml
            projObj = engine.load( OI.Data.ProjectDefinition() );
            previewDir = fullfile(projObj.WORK,'preview','geocoding');
            previewKmlPath = fullfile( previewDir, [result.id '.kml']);
            previewKmlPath = OI.Functions.abspath(previewKmlPath);
            OI.Functions.mkdirs( previewKmlPath );

            % make elevation image
            eleImage = reshape(elevation, sz);
            % scale to 0...1
            eleImage = OI.Functions.normalise_image(eleImage);
            % make a bit smaller
            eleImageRescaleFactor = 1000/max(sz);
            eleImage = imresize( eleImage, eleImageRescaleFactor );
         
            % get burst corners
            [~, ~, ~, ~, ~, cornerInds] = ...
                OI.Plugins.Geocoding.get_geometry(lpb,spb);
            previewImageArea = OI.Data.GeographicArea();
            previewImageArea.lat = lat(cornerInds);
            previewImageArea.lon = lon(cornerInds);
            previewImageArea.save_kml_with_image( ...
                previewKmlPath, ...
                flipud(eleImage) ); 
        end

    end

    methods (Static = true)
        function [lpb,spb,nearRange,rangeSampleDistance] = ...
                get_parameters(swathInfo)
            % parameters
            c = 299792458;
            nearRange = swathInfo.slantRangeTime * c / 2;

            % get image dimensions
            lpb = swathInfo.linesPerBurst;
            spb = swathInfo.samplesPerBurst;
            %
            fastTime = swathInfo.slantRangeTime;
            rangeSampleTime = 1/swathInfo.rangeSamplingRate;
            rangeSampleDistance = c*rangeSampleTime/2;
        end

        function [rangeSample, azLine, burstCorners, sz, nSamps, cornerInds] = ...
                get_geometry(lpb,spb)
            % get meshgrid of range sample and az line 
            [rangeSample, azLine] = meshgrid( 1:spb, 1:lpb );
            sz=[lpb,spb];
            nSamps = prod(sz);
            % corners of the burst
            burstCorners = [ ...
                1, 1; ...
                1, spb; ...
                lpb, spb; ...
                lpb, 1 ...
            ];
            cornerInds = [1 (spb-1)*lpb+1 lpb*spb lpb]';
            % assert(all(rangeSample(cornerInds) == [1 spb spb 1]))
            % assert(all(azLine(cornerInds) == [1 1 lpb lpb]))
        end

        function [orbit, lineTimes] = get_poe_and_timings( ...
                catalogue, safeIndex, swathInfo, burstIndex )
            % get the time of each line in the burst
            lineTimes = linspace( ...
                swathInfo.burst(burstIndex).startTime, ...
                swathInfo.burst(burstIndex).endTime, ...
                swathInfo.linesPerBurst )';

            % orbit file
            safe = catalogue.safes{safeIndex};
            orbit = OI.Data.Orbit( safe );

        end

        function [satXYZ, satV] = get_ephemerides( ...
                catalogue, safeIndex, swathInfo, burstIndex )

            [orbit, lineTimes] = ...
                OI.Plugins.Geocoding.get_poe_and_timings( ...
                    catalogue, safeIndex, swathInfo, burstIndex );

            % interpolate the orbit
            burstOrbit = orbit.interpolate( lineTimes );
            satXYZ = [burstOrbit.x(:) burstOrbit.y(:) burstOrbit.z(:)];
            satV = [burstOrbit.vx(:) burstOrbit.vy(:) burstOrbit.vz(:)];

        end% get ephemerides

        function [lat, lon] = get_initial_geocoding( ...
                swathInfo, burstIndex)

            % get image dimensions
            lpb = swathInfo.linesPerBurst;
            spb = swathInfo.samplesPerBurst;
            
            % get geometry of the 
            [rangeSample, azLine, burstCorners, ~, nSamps] = ...
                OI.Plugins.Geocoding.get_geometry(lpb,spb);

            % get initial estimate of lat/lon
            % X = A\B is the solution to the equation A*X = B
            latLonPerAzRgConst = [burstCorners, ones(4,1)] \ ...
                [swathInfo.burst(burstIndex).lat(:), ...
                swathInfo.burst(burstIndex).lon(:)];

            lat = [azLine(:) rangeSample(:) ones(nSamps,1)] * ...
                latLonPerAzRgConst(:,1);
            lon = [azLine(:) rangeSample(:) ones(nSamps,1)] * ...
                latLonPerAzRgConst(:,2);
        end

        function dopplerPerAzLine = get_doppler_per_line( ...
                swathInfo, satXYZ, satV, lat, lon, ele)
            % get doppler rate over the burst
            midBurstXYZ = OI.Functions.lla2xyz( ...
                mean(lat(:)), ...
                mean(lon(:)),...
                mean(ele(:)));
            
            % get image dimensions
            lpb = swathInfo.linesPerBurst;
            spb = swathInfo.samplesPerBurst;
            
            % get geometry of the corners
            [~, ~, burstCorners, ~, ~] = ...
                OI.Plugins.Geocoding.get_geometry(lpb,spb);
            cornerInds = [1 (spb-1)*lpb+1 lpb*spb lpb];

            % cornerDoppler
            cornerDoppler = OI.Functions.doppler_eq( ...
                    satXYZ(cornerInds,:), ...
                    satV(cornerInds,:), ...
                    midBurstXYZ);

            % regress to find doppler variation
            dopplerPerAzRgConst = [burstCorners ones(4,1)] \ cornerDoppler;
            dopplerPerAzLine = dopplerPerAzRgConst(1);
        end


    end % methods static
end
