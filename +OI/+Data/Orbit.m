classdef Orbit < OI.Data.DataObj

properties
    id = 'Orbit';
    generator = 'GetOrbits';
    nameOfPoeFile
    link
    platform
    date
    t
    x
    y
    z
    vx
    vy
    vz
end % properties
methods

    function this = Orbit(varargin)
        this.hasFile = true;
        this.isArray = true;
        this.filepath = ['$ORBITS_DIR$/', '$nameOfPoeFile$'];
        this.fileextension = 'EOF';

        % can initialise with a filename, or a safe object
        if nargin == 1
            if isa(varargin{1},'OI.Data.Sentinel1Safe')
                this.platform = varargin{1}.platform;
                % if we have a orbitFile already...
                if ~isempty(varargin{1}.orbitFile)
                   this.filepath = ...
                       strrep(varargin{1}.orbitFile,'\',filesep);
                else % we need to create a job
                   return % and that can't be handled here
                end
            elseif isa(varargin{1},'char')
                this.filepath = varargin{1};
            end
            assert(~isempty(this.filepath))
            % in which case we load the file
            T = OI.Data.TextFile( this.filepath ).load();
            % convert to struct full of OSVs
            OSV = OI.Functions.parse_s1_orbit_file(T);
            % interpolate OSVs
            timeStr = vertcat(OSV.UTC);
            % just days hours mins
            dayTMinHourSec = timeStr(:,5:end-7);
            time = datenum(dayTMinHourSec, 'yyyy-mm-ddTHH:MM:SS');
            % usually 0 for osv
            secFraction = str2num(timeStr(:,end-6:end-1)); %#ok<ST2NM>
            % covert to days
            % actually, ignore the date
            this.t = time + secFraction./86400;
            
            % get x y z
            this.x = arrayfun(@(o) str2double(o.X), OSV)';
            this.y = arrayfun(@(o) str2double(o.Y), OSV)';
            this.z = arrayfun(@(o) str2double(o.Z), OSV)';
            % get vx vy vz
            this.vx = arrayfun(@(o) str2double(o.VX), OSV)';
            this.vy = arrayfun(@(o) str2double(o.VY), OSV)';
            this.vz = arrayfun(@(o) str2double(o.VZ), OSV)';
        end
    end%ctor

    function jobs = create_array_job( this, engine )
        jobs = {};
        catalogue = engine.load(  OI.Data.Catalogue() );
        if isempty(catalogue)
            job = OI.Job('name','GetOrbits');
            jobs{end+1} = job;
            return
        end%if

        safes = catalogue.safes;
        for i = 1:numel(safes)
            date = safes{i}.date;
            platform = safes{i}.platform;
            job = OI.Job('name','GetOrbits');
            job.arguments = {'datetime',date.datenum(),'platform',platform};
            jobs{end+1} = job;
        end%for
    end%array_jobs

    function this = interpolate(this,newTimes)
        newTimes = newTimes(:);
        this.x = interp1(this.t,this.x,newTimes,'spline');
        this.y = interp1(this.t,this.y,newTimes,'spline');
        this.z = interp1(this.t,this.z,newTimes,'spline');
        this.vx = interp1(this.t,this.vx,newTimes,'spline');
        this.vy = interp1(this.t,this.vy,newTimes,'spline');
        this.vz = interp1(this.t,this.vz,newTimes,'spline');
        this.t = newTimes;
    end%interpolate


    % function jobs = create_job( this, engine )
    %     jobs = create_array_job( this, engine );
    % end%create_job

    function filename = find(this, platform, date, orbitFiles)
        filename = '';
        % easy_debug
        if any(strcmpi(platform,{'S1A','S1B'}))
            for orb = orbitFiles'
                % get rid of the .EOF extension
                [ ~, name, ext ] = fileparts(orb.name);
                % split the name, get the start and end date
                split = strsplit(name,'_');
                % ignore anything thats not a S1 orbit
                if ~strcmpi(split{1},platform) || ...
                    ~strcmpi(split{2},'OPER') || ...
                    ~strcmpi(ext,'.EOF')
                    continue
                end
                % get the start and end date
                startStr = split{end-1};
                startStr = strrep(startStr,'V', '');
                start = OI.Data.Datetime(startStr);
                endStr = split{end};
                dateTimeEnd = OI.Data.Datetime(endStr);
                % check if the date is in the orbit
                targetDatenum = date.datenum();
                if targetDatenum >= start.datenum() && targetDatenum <= dateTimeEnd.datenum()
                    filename = fullfile(orb.folder, orb.name);
                    return
                end
            end
        end
    end

end

end
