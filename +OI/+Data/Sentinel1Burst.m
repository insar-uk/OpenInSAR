classdef Sentinel1Burst < OI.Data.DataObj

properties
    meta = struct;
    orbit = struct;
end

methods

    function this = parse_orbits(this, O)
        this.orbit.x = O.orbit.x;
        this.orbit.y = O.orbit.y;
        this.orbit.z = O.orbit.z;

        this.orbit.vx = O.orbit.vx;
        this.orbit.vy = O.orbit.vy;
        this.orbit.vz = O.orbit.vz;

        this.orbit.t = O.orbit.t;
    end

    function this = parse_annotations( this, A )
        % get common paramaters fromt he annotation file
        % so we don't have to load it so many times
        % A is the annotation file as a structure
        s2n = @str2double;
        c = 299792458;
        % Product spec:
        % https://sentinel.esa.int/documents/247904/1877131/Sentinel-1-Product-Specification.pdf

        % Basics
        this.meta.Ascending = (annotations.generalAnnotation.productInformation.pass.value_(1) == 'A');
        this.meta.Descending = (annotations.generalAnnotation.productInformation.pass.value_(1) == 'D');
        this.meta.Mission = annotations.adsHeader.missionId.value_(1:3);
        this.meta.AON = s2n(annotations.adsHeader.absoluteOrbitNumber.value_);
        if this.meta.Mission(3) == 'A'
            this.meta.RON = mod(this.meta.AON-73,175)+1;
        else
            this.meta.RON = mod(this.meta.AON-27,175)+1;
        end
        this.meta.track = this.meta.RON;
        this.meta.swath = annotations.adsHeader.swath.value_;
        this.meta.Polarization = A.imageAnnotation.imageInformation.polarisationChannels.value_(1:2);

        % See https://sentinel.esa.int/documents/247904/1653442/Guide-to-Sentinel-1-Geocoding.pdf
        % Table 4 Sentinel-1 product parameters required for range-Doppler geocoding
        this.meta.azSpacing = s2n(A.imageAnnotation.imageInformation.azimuthPixelSpacing.value_);
        this.meta.startTime = OI.Data.Datetime(A.imageAnnotation.imageInformation.productFirstLineUtcTime.value_);
        this.meta.endTime = OI.Data.Datetime(A.imageAnnotation.imageInformation.productLastLineUtcTime.value_);
        this.meta.fastTime = s2n(A.imageAnnotation.imageInformation.slantRangeTime.value_);
        this.meta.lineTimeInterval = s2n(A.imageAnnotation.imageInformation.azimuthTimeInterval.value_);
        this.meta.radarFreq = s2n(A.generalAnnotation.productInformation.radarFrequency.value_);
        this.meta.rgSampleRate = s2n(A.generalAnnotation.productInformation.rangeSamplingRate.value_);
        this.meta.swathHeight = s2n(A.imageAnnotation.imageInformation.numberOfLines.value_);
        this.meta.swathWidth = s2n(A.imageAnnotation.imageInformation.numberOfSamples.value_);
        this.meta.heading = s2n(A.generalAnnotation.productInformation.platformHeading.value_);

        % Forward geocoding
        this.meta.nearRange = s2n(annotations.imageAnnotation.imageInformation.slantRangeTime.value_)*c/2;   
        this.meta.rgSampleRate = s2n(annotations.generalAnnotation.productInformation.rangeSamplingRate.value_);
        this.meta.rgPixelSpacing = c/(2*rgSampleRate);
    
        % geolocation grid points:
        this.meta.geo = annotations.imageAnnotation.geolocationGrid.geolocationGridPointList.geolocationGridPoint;
    end

end

methods (Static)
    
end % classdef
