classdef Datetime < OI.Data.DataObj
properties
    daysSinceZero = now();
end

methods
    function this = Datetime( datenumOrString, format)
        % Datetime constructor.  Can be called with a string or a datenum.
        if nargin == 0
          return
        end%if
        % if no format is specified:
        if ischar(datenumOrString) && nargin == 1
            % try to guess format
            switch numel(datenumOrString)
                % Sentinel SAFE:
                case 15 % yyyymmddThhMMss
                    fmt = 'yyyymmddTHHMMSS';
                    this.daysSinceZero = datenum(datenumOrString,fmt);
                % Sentinel Orbits:
                case 16 % yyyymmddThhMMssZ
                    fmt = 'yyyymmddTHHMMSSZ';
                    this.daysSinceZero = datenum(datenumOrString,fmt);
                case 26 % sentinel 1 EOF orbit data
                    % oct/mat formatting not precise enough:
                    dtAndFraction = strsplit(datenumOrString,'.');
                    % get the normal datetime
                    dt = dtAndFraction{1};
                    fmt = 'yyyy-mm-ddTHH:MM:SS';
                    this.daysSinceZero = datenum(dt,fmt);
                    % add the fractional second:
                    fraction = str2double(['0.' dtAndFraction{2}]);
                    % convert fractional seconds to days
                    this.daysSinceZero = this.daysSinceZero + fraction/86400;
                otherwise
                    this.daysSinceZero = datenum(datenumOrString);
            end
        % if a format is specified:
        elseif ischar(datenumOrString) && nargin > 1
            % check for uppercase MM gotcha
            if numel(format) > 5 && strcmp(format(5:6),'MM')
                warning('Datetime:invalidInput', ...
                    ['Datetime format string contains ''MM'' (mins) ' ...
                    'in typical month location.\n' ...
                    'Did you mean ''mm'' (months)?'])
            end
            this.daysSinceZero = datenum(datenumOrString, format);
        % if a number is specified:
        else
            dateNumber = datenumOrString;
            assert(isnumeric(dateNumber), 'Datetime:invalidInput', 'Datetime must be a string or a datenum');
            assert(numel(dateNumber)==1, 'Datetime:invalidInput', 'Datetime must be a scalar')
            assert(dateNumber>0 && dateNumber<1e6, 'Datetime:invalidInput', 'Datetime must be a valid datenum')
            this.daysSinceZero = datenumOrString;
        end
    end

    function dateString = to_string(this, format)
        if nargin<2
            format = 'yyyy-mm-dd HH:MM:SS';
        end
        dateString = datestr(this.daysSinceZero,format);
    end

    function dateString = asf_datetime( this )
        dateString = datestr(this.daysSinceZero,'yyyy-mm-ddTHH:MM:SSZ');
    end

    function dateString = datestr( this, format )
        if nargin<2
            format = 'yyyymmddtHHMMSS';
        end
        dateString = datestr(this.daysSinceZero,format);
    end

    function dn = datenum( this )
        dn = this.daysSinceZero;
    end
end

end

