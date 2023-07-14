classdef GetMetaData < OI.Plugins.PluginBase
% TODO delete this, unused
properties
    inputs = {OI.Data.Catalogue()}
    outputs = {OI.Data.Orbit()}
    datetime % to get the orbit file for
    platform % to get the orbit file for
    safeIndex = [];
    id = 'GetOrbits';
end % properties

methods
    function this = GetMetaData(varargin)

    end

    function this = run(this, engine, varargin)
        % get key value pairs from varargin
        for i = 1:2:length(varargin)
            argKey = varargin{i};
            argVal = varargin{i+1};
            switch argKey
                case 'safeIndex'
                    this.safeIndex = argVal;
                case 'datetime'
                    this.datetime = argVal;
                case 'platform'
                    this.platform = argVal;
                otherwise
                    warning('Unknown argument key: %s', argKey);
                    this.(varargin{i}) = varargin{i+1};
            end
        end

        cat = engine.load( inputs{1} );

        if is_empty(this.safeIndex) % create jobs if first time
            outstanding = 0;
            for safeInd = 1:length(cat.safes)
                this.safeIndex = safeInd;
                engine.requeue_job( 'safeIndex', safeInd );
            end

        end

        orbitFile = cat.safes{this.safeIndex}.orbitFile;
        % load
        T = OI.Data.TextFile(orbitFile).load();
        % convert to struct full of OSVs
        O = OI.Functions.parse_s1_orbit_file(T);
        % interpolate OSVs
        timeStr = vertcat(O.OSV.UTC);
        % just days hours mins
        dayTMinHourSec = timeStr(:,13:end-7);
        time = datenum(dayTMinHourSec, 'ddTHH:MM:SS');
        secFraction = str2double(timeStr(:,end-6:end-1)); % usually 0 for osv
        % covert to days
        time = time + secFraction./86400;

        % get x y z
        x = arrayfun(@(o) str2double(o.X), O.OSV);
        y = arrayfun(@(o) str2double(o.Y), O.OSV);
        z = arrayfun(@(o) str2double(o.Z), O.OSV);
        % get vx vy vz
        vx = arrayfun(@(o) str2double(o.VX), O.OSV);
        vy = arrayfun(@(o) str2double(o.VY), O.OSV);
        vz = arrayfun(@(o) str2double(o.VZ), O.OSV);

        % save all these in a stuct
        meta = struct();
        meta.t = time;
        meta.x = x;
        meta.y = y;
        meta.z = z;
        meta.vx = vx;
        meta.vy = vy;
        meta.vz = vz;
        
        % load the annotation file
        annFile = cat.safes{this.safeIndex}.annotationFile;
        % Use OI.Data.XmlFile to convert
        xml = OI.Data.XmlFile(annFile).load();
        % get start and end time
        meta.startTime = xml.productList.product.generalAnnotation.productInformation.productStartTime;
        meta.endTime = xml.productList.product.generalAnnotation.productInformation.productStopTime;



    end % run(

end % methods

end % classdef
