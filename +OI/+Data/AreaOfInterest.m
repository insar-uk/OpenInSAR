classdef AreaOfInterest < OI.Data.DataObj
properties
    northLimit = 0;
    eastLimit = 0;
    southLimit = 0;
    westLimit = 0;
    coordinateSystem = 'WGS84';
    id = 'AreaOfInterest'
end

methods
    function this = AreaOfInterest( strOrDoubleArray )

        if nargin == 0, return; end

        if OI.Compatibility.is_string( strOrDoubleArray );
            % replace all non numeric with space
            str = regexprep( strOrDoubleArray, '[^0-9\.\-]', ' ' );
            % split on space
            a = str2double( strsplit( str ) );
            a = a(~isnan(a));
        else
            a = strOrDoubleArray;
        end
        this.northLimit = a(1);
        this.eastLimit = a(2);
        this.southLimit = a(3);
        this.westLimit = a(4);
    end

    function str = to_string( this )
        str = sprintf( '%f %f %f %f', this.northLimit, this.eastLimit, this.southLimit, this.westLimit );
    end

    function str = asf_bbox( this )
        str = sprintf( '%f,%f,%f,%f', this.westLimit, this.southLimit, this.eastLimit, this.northLimit );
    end

    function geoArea = to_area( this )

        % convert the bounding box limits to gml coordinates
        gmlString = sprintf( '%f,%f %f,%f %f,%f %f,%f %f,%f', ...
            this.northLimit, this.westLimit, ...
            this.northLimit, this.eastLimit, ...
            this.southLimit, this.eastLimit, ...
            this.southLimit, this.westLimit, ...
            this.northLimit, this.westLimit ...
            );

        % convert the gml polygon to a geographic area
        geoArea = OI.Data.GeographicArea.from_gml( gmlString );
        
    end

    function preview_kml( this, filepath )
        % preview the area of interest as a kml file
        % convert the area of interest to a geographic area
        area = this.to_area();

        % create the kml file
        area.to_kml( filepath );
    end
end

end

