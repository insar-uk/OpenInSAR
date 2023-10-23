function [lat, lon] = forward_geocode(...
    orbit, azRg, nearRangeTime, rangeSampleRate, dem)
    % [lat, lon] = forward_geocode( ...
    %     orbit, azRg, annotations, dem)
    %
    % Forward geocode a set of azimuth and range values to lat lon
    % coordinates.
    % 
    % Inputs:
    %   orbit - a structure with fields x, y, z, vx, vy, vz
    %   azRg - a n x 2 matrix of azimuth and range values
    %   annotations - a structure with fields generalAnnotation and
    %       imageAnnotation
    %   dem - a structure with fields lat, lon, alt
    %
    % Outputs:
    %   lat - a n x 1 vector of latitudes
    %   lon - a n x 1 vector of longitudes
    %
    
     % if no dem is provided, use a wgs84 ellipsoid
    if nargin < 5
        ellipsoid = wgs84Ellipsoid('meters');
    end
    
    % get the near range and range pixel spacing
    c = 299792458;

    nearRange = nearRangeTime * c/2;
    rgPixelSpacing = c/(2*rangeSampleRate);

    % results vectors
    [lat, lon] = deal(zeros(4,1));

    % for each point in the image
    for ii = 1:size(azRg,1)

        % get the azimuth and range
        az = azRg(ii,1);
        rg = azRg(ii,2);
            
        % get the orbital position
        xyzSat = [orbit.x(az) orbit.y(az) orbit.z(az)];
        vSatUnit = [orbit.vx(az) orbit.vy(az) orbit.vz(az)];

        % iteratively narrow down the search area until we're close
        searchLat = [-90, 90];
        searchLon = [-180, 180];
        iters = 0;
        lonIters = 0;
        latIters = 0;

        while true
            if iters == 1e2 || any(isnan(xyzSat))
                error('ERROR IN GEOCODING')
            end
            % if no dem is provided, use a wgs84 ellipsoid
            if nargin < 5
                % generate 3d coordinates of the wgs84 ellipsode earth in ecef
                % in the given search range of lat and lon
                [latG, lonG] = meshgrid(...
                    linspace(searchLat(1), searchLat(2), 100), ...
                    linspace(searchLon(1), searchLon(2), 100));
                [x, y, z] = geodetic2ecef(ellipsoid, latG, lonG, 0);
                xyzGround = [x(:) y(:) z(:)];
            else
                % get the dem in the search area
                workingDem = dem;
                isLatInWindow = workingDem.lat >= searchLat(1) & workingDem.lat <= searchLat(2);
                isLonInWindow = workingDem.lon >= searchLon(1) & workingDem.lon <= searchLon(2);

                workingDem.lat = workingDem.lat(isLatInWindow);
                workingDem.lon = workingDem.lon(isLonInWindow);
                workingDem.alt = workingDem.alt(isLatInWindow, isLonInWindow);
                
                % replicate the lat and lon vectors to match the size of the alt
                % matrix
                [workingDem.lat, workingDem.lon] = meshgrid(workingDem.lat, workingDem.lon);
                % generate 3d coordinates of the dem in ecef
                [x, y, z] = geodetic2ecef( ...
                    wgs84Ellipsoid('meters'), ...
                    workingDem.lat(:), ...
                    workingDem.lon(:), ...
                    workingDem.alt(:) ...
                );
                xyzGround = [x(:) y(:) z(:)];
            end
            

    
            % Which way are we looking?:
            % get a unit vector for the velocity
            vSatUnit = vSatUnit./norm(vSatUnit);
            % get a unit vector for the nadir
            xyzSatUnit = xyzSat./norm(xyzSat);
            % get the distance between ground and sat
            xyzDistance = xyzGround - xyzSat;
            % get a unit vector perpendicular to the nadir and velocity
            % perpendicular to track and altitude
            U = cross(vSatUnit,xyzSatUnit);
            U = U./norm(U);
            % distance along this axis
             % positive is 'to the right of track'
            distInU = U*xyzDistance';
    
            % find the range of these coordinates
            rangeError = abs( ...
                OI.Functions.range_eq(xyzSat,xyzGround) - ...
                (nearRange + rg * rgPixelSpacing) );
            % find the doppler of these coordinates
            doppler = OI.Functions.doppler_eq(xyzSat,vSatUnit,xyzGround);
    
            % % find the rank of the doppler values in the same order
            % [~, sortedOrder] = sort(abs(doppler));
            % [~, dopplerRank] = sort(sortedOrder);
            % 
            % % find the rank of the range values in the same order
            % [~, sortedOrder] = sort(abs(rangeError));
            % [~, rangeRank] = sort(sortedOrder);
            
            cost = rangeError+abs(doppler);
            % set the cost to a large number if the point is behind the sat
            cost(distInU<0) = max(cost);
    
            [~, minCostIndex]=min(abs(cost));
            % get the lat lon of the best point
            [lat(ii), lon(ii), ~] = ecef2geodetic( ...
                ellipsoid, ...
                xyzGround(minCostIndex,1), ...
                xyzGround(minCostIndex,2), ...
                xyzGround(minCostIndex,3) ...
            );

            % break if we're within 10 meters and 1khz
            if abs(rangeError(minCostIndex)) < 10 && ...
               abs(doppler(minCostIndex)) < 1e3 || ...
               (diff(searchLon) < 1e-3 && diff(searchLat) < 1e-3 )
                break
            else
                % Otherwise refine the search area
                % if range error is bigger than doppler error, narrow lon
                if abs(rangeError(minCostIndex)) > abs(doppler(minCostIndex))
                    searchLon = [lon(ii) - 5/(2^lonIters), lon(ii) + 5/(2^lonIters)];
                    lonIters = lonIters + 1;
                % else narrow lat
                else
                    searchLat = [lat(ii) - 5/(2^latIters), lat(ii) + 5/(2^latIters)];
                    latIters = latIters + 1;
                end
                % wrap the lon to -180 to 180
                searchLon = mod(searchLon + 180, 360+1e-6) - 180;
                % wrap the lat to -90 to 90
                searchLat = mod(searchLat + 90, 180+1e-6) - 90;

                iters = iters + 1;
            end
        end
    end

    % gg=OI.Data.GeographicArea();
    % gg.lat = lat;
    % gg.lon = lon;
    % aOrD = annotations.generalAnnotation.productInformation.pass.value_(1);
    % aOrB = annotations.adsHeader.missionId.value_(3);
    % AON = str2num(annotations.adsHeader.absoluteOrbitNumber.value_);
    % if aOrB == 'A' %sentinel 1a mod(AON-73,175)+1;
    %     % if sentinel 1b mod(AON-27,175)+1;
    %     ron = mod(AON-73,175)+1;
    % else
    %     ron = mod(AON-27,175)+1;
    % end
    % myNameIs = [ ...
    %     'S1', aOrB, ...
    %     '_Track', num2str(ron), ...
    %     '_', aOrD, ...
    %     '_Swath', annotations.adsHeader.swath.value_, ...
    %     '_', annotations.adsHeader.startTime.value_, ...
    %     '.kml' ...
    %     ];
    % myNameIs = strrep(myNameIs,':','');
    % gg.to_kml(myNameIs);

end

    % get the corres

    % azTol = 1;
    % rgTol = 1;
    
    % c = 299792458;
    
    % de = OI.Functions.doppler_eq(fxyz(ts(minAz)),fVxyz(ts(minAz)),demXYZ)./dopPerRow;
    
    % startMax = dsz0(1)*4;
    % rMask=ones(prod(dsz0),1);
    % dMask=ones(prod(dsz0),1);
    % iter = 0;
    % while 1
    %     iter = iter+1;
    %     while 1
    %         dMask = rMask&de>=-azTol&de<=azTol;
    %         if sum(dMask)<startMax/2
    %             azTol=azTol.*1.25;
    %             continue
    %         end
    %         if sum(dMask)>startMax
    %             azTol=median(abs(de(dMask)));
    %             continue
    %         end
    %         break
    %     end
    %     rMask = rMask & dMask;
    %     startMax = startMax/4;
    %     if sum(rMask) < 2
    %         break
    %     end
        
    %     if iter == 1
    %         startMax = 100;
    %     end
        
    %     re = (2*rsr/c)* ( range_eq(fxyz(ts(minAz)),demXYZ) - nr ) - minRg;
    %     while 1
    %         rMask = dMask&re>=-rgTol&re<=rgTol;
    %         if sum(rMask)<startMax/2
    %             rgTol=rgTol.*1.25;
    %             continue
    %         end
    %         if sum(rMask)>startMax
    %             rgTol=median(abs(re(rMask)));
    %             continue
    %         end
    %         break
    %     end
    %     rMask = rMask & dMask;
    %     startMax = startMax/4;
    %     if sum(rMask) < 2
    %         break
    %     end
    % end
    
    % dInd = find(rMask,1);
    % [dLat, dLon] = ind2sub(dsz0,dInd);
    