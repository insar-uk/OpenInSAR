function [realphi, realdemod, lagPhase] = deramp_demod_sentinel1( swathInfo, burstIndex,  orbit, safe, azOff )
    if nargin==0
        disp(1)
        return
    end
    % deramp_sentinel1 - Deramp and demodulate Sentinel-1 data
    %  realphi = deramp_sentinel1( swathInfo, burstIndex,  orbit, safe )
    %  Deramp and demodulate Sentinel-1 data
    %  Inputs:
    %   swathInfo - swath information structure
    %   burstIndex - index of burst to deramp
    %   orbit - OI.Data.Orbit object
    %   safe - SAFE file information structure
    %  Outputs:
    %   realphi - asbolute phase of the ramp
    %
    % See esa guide for more information:
    % https://sentinel.esa.int/documents/247904/1653442/sentinel-1-tops-slc_deramping
    
    % phi = - pi * kt(tau) * (eta - etaref(tau))^2
    % where:
    %   kt is doppler centroid rate (Hz/s)
    %   eta the zero-doppler azimuth time (slow time, s) of the pixel
    %   tau is the range time (fast time, s) of the pixel
    % kt(tau) = (ka(tau) * ks) / (ka(tau) - ks)
    % where:
    %   ks is the unfocused time rate (Hz/s)
    %   ka(tau) is the FM azimuth rate in time (Hz/s)
    %       this is provided in annotation files as a polynomial of tau
    %   ks = 2 * v / lambda * kphi (approx) 
    %       is the azimuth steering doppler rate (Hz/s)
    %   kphi is the actual steering of the antenna beam in radians per second
    %       provided in annotations
    %   v is the velocity of the satellite in m/s, which can be taken from
    %       the middle of the burst
    % eta for line index 'n' is calculated as:
    %   eta = time_mid_burst + (n - n_mid_burst) * time_per_line
    % tau is calculated for range sample index 'n' as:
    %   tau = t0 + (n - 1) * time_per_sample
    %   t0 is the slant range time (s) of the first range sample, which is
    %      provided in the annotation files
    
    % helper functions:
    s2n = @str2num;
    
    % get the annotation file
    annotationPath = safe.get_annotation_path( swathInfo.index );
    ant = OI.Data.XmlFile( annotationPath ).to_struct();
    
    %% GEOMETRY
    lpb = swathInfo.linesPerBurst;
    spb = swathInfo.samplesPerBurst;
    
    %% General Variables
    c = 299792458;
    % Carrier (central) frequency of radar
    fc = swathInfo.radarFrequency;
    % Angular shift in azimuth pointing per second
    % TODO add to file preprocessor
    kpsi = ant.generalAnnotation.productInformation.azimuthSteeringRate; 
    kpsi = s2n(kpsi)*pi/180; %in rads.
    
    %% TIMING
    rsr = swathInfo.rangeSamplingRate; % Range sampling rate
    rti = 1./rsr; % time between range samples
    ati = swathInfo.azimuthTimeInterval;
    % The zero-doppler azimuth time of each line in the burst
    btime = mod(swathInfo.burst( burstIndex ).startTime , 1) * (60*60*24);
    azimuthLineTime = (btime : ati : btime+(lpb-1) * ati)';
    % Azimuth time eta (vs mid burst)
    tMidBurst = mean(azimuthLineTime);
    eta = azimuthLineTime - tMidBurst;
    % Range time tao (vs first sample)
    tao0 = swathInfo.slantRangeTime;
    tao = tao0 + rti*(0:spb-1); % zero indexed, according to ESA guide
    
    %% 6.2: Doppler Centroid Rate Introduced by the Scanning Antenna (ks)
    % Velocity
    % orbits use a different time format currently
    orbitTime = swathInfo.burst( burstIndex ).startTime:ati/86400:...
        swathInfo.burst( burstIndex ).startTime + (lpb-1)*ati/86400;
    interpOrbit = orbit.interpolate( orbitTime );
    velocity = sqrt(sum( ...
        [ interpOrbit.vx(:), ...
        interpOrbit.vy(:), ...
        interpOrbit.vz(:) ] .^2 ...
        , 2)); 
    % Also:
    % /product/generalAnnotation/orbitList/orbit/velocity
    % Steering rate (phase rad / s)
    ks = velocity * 2 * kpsi * fc / c;
    
    %% 6.3: Doppler FM Rate (ka)
    % Find the closest estimate to the middle of the burst
    % TODO add to file preprocessor
    afrList = ant.generalAnnotation.azimuthFmRateList.azimuthFmRate;
    nAfrEstimates = numel(afrList);
    tAfrEstimate = arrayfun(@(x) OI.Data.Datetime( ...
        afrList(x).azimuthTime ).datenum(), 1:nAfrEstimates);
    tAfrEstimate = mod(tAfrEstimate,1) * (60*60*24);
    [~, nearestAfrEstimate] = min(abs(tAfrEstimate - tMidBurst));
    % Get the doppler FM rate from polynomial
    afrEst = afrList(nearestAfrEstimate);
    if isfield(afrEst,'azimuthFmRatePolynomial')
        if isfield(afrEst.azimuthFmRatePolynomial,'value_') % legacy XML
            afrEstimatePoly = ...
                fliplr(s2n(afrEst.azimuthFmRatePolynomial.value_));
        else
            afrEstimatePoly = ...
                fliplr(s2n(afrEst.azimuthFmRatePolynomial));
        end
    elseif isfield(afrEst,'c0') % old format
        afrEstimatePoly = [s2n(afrEst.c2), s2n(afrEst.c1), s2n(afrEst.c0)];
    elseif isfield(afrEst,'value_') % bug in my xml code?
        afrEstimatePoly = fliplr(s2n(afrEst.value_));
    else
        error('Unknown format for fm rate estimate poly in annotations %s',...
            annotationPath);
    end
    % Ka is relative to tao (fast time), which is given in polynomial annotation
    ka = polyval(afrEstimatePoly, tao-s2n(afrEst.t0));
    
    %% 6.4: Doppler Centroid Rate in the Focussed TOPS SLC Data (kt)
    % Find the closest estimate to the middle of the burst
    % TODO add these details to swathInfo file preprocessor
    dcEstList = ant.dopplerCentroid.dcEstimateList.dcEstimate;
    nDcfEstimates=numel(dcEstList);
    tDcfEstimate = arrayfun(@(x) OI.Data.Datetime( ...
        dcEstList(x).azimuthTime ).datenum(), 1:nDcfEstimates);
    tDcfEstimate = mod(tDcfEstimate,1) * (60*60*24);
    [~, nearestDcfEstimate] = min(abs(tDcfEstimate - tMidBurst));
    % Get the doppler centroid frequency from polynomial
    dcEst = dcEstList( nearestDcfEstimate );
    if isfield(dcEst,'dataDcPolynomial')
        if isfield(dcEst.dataDcPolynomial,'value_') % legacy XML
            dcEstimatePoly = ...
                fliplr(s2n(dcEst.dataDcPolynomial.value_));
        else
            dcEstimatePoly = ...
                fliplr(s2n(dcEst.dataDcPolynomial));
        end
    elseif isfield(dcEst,'c0') % old format
        dcEstimatePoly = [s2n(dcEst.c2), s2n(dcEst.c1), s2n(dcEst.c0)];
    elseif isfield(dcEst,'value_') % bug in my xml code?
        dcEstimatePoly = fliplr(s2n(dcEst.value_));
    else
        error('Unknown format for dc estimate poly in annotations %s',...
            annotationPath);
    end
    % Doppler centroid is given relative to polynomial origin
    fnc = polyval(dcEstimatePoly, tao - s2n(dcEst.t0));

    %% 6.6: Reference zero-Doppler Azimuth Time etaref
    etaref = -fnc ./ ka;
    etaref = etaref - etaref(round(spb/2));
    
    % finally...
    kt=(ka.*ks)./(ka-ks);

    % phi phase
    realphi=-pi*kt.*(eta-etaref).^2;
    realdemod=-2*pi.*kt.*(eta - etaref);
    
    % Check if azimuth offsets were provided
    % INTERFEROMETRIC PROCESSING OF SLC SENTINEL-1 TOPS DATA
    % Raphael Grandin, ESA Fringe 2015
    % https://proceedings.esa.int/files/116.pdf
    if nargin > 4
        % adjust for azimuth misregistration
        etalagPoly = polyfit(1:size(azOff,1),ati.*azOff(:,1),1);
        etalagPoly(end)=0;
        etalag = polyval(etalagPoly,1:lpb);
        lagPhase = 2*pi*kt.*eta.*etalag';
    else
        lagPhase = 0;
    end