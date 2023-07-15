classdef GeographicArea < OI.Data.DataObj
% convert common formats such as GML coordinates into a polygon of lat/lon points

properties
    name
    lat
    lon
end
%#ok<*ST2NM> - Octave compatibility
methods
    function obj = GeographicArea()
    end

    function [minLat,maxLat,minLon,maxLon] = limits(this)
        minLat = min(this.lat);
        maxLat = max(this.lat);
        minLon = min(this.lon);
        maxLon = max(this.lon);
    end

    function to_kml(this, filename)
        % Save the polygon as a kml file

        % if name is empty, and no filename is given
        % call it a random human name
        if isempty(this.name) && nargin < 2
            rn = randi(10);
            tenHumanNames = {'Alice', 'Bob', 'Charlie', 'David', 'Eve', 'Frank', 'Grace', 'Hannah', 'Ivan', 'Judy'};
            this.name = tenHumanNames{rn};
        end

        % get the name
        if isempty(this.name)
            [~, this.name, ~] = fileparts(filename);
        end
        
        % if filename is empty just call it name.kml
        if nargin < 2 || isempty(filename)
            filename = [this.name '.kml'];
        else % make sure the filename ends in .kml
            [~, ~, ext] = fileparts(filename);
            if ~strcmp(ext, '.kml')
                filename = [filename '.kml'];
            end
        end

        % create a KML string
        kmlStr = ['<?xml version="1.0" encoding="UTF-8"?>' newline ...
            '<kml xmlns="http://earth.google.com/kml/2.0">' newline ...
            '<Document>' newline ...
            '<name>' this.name '</name>' newline ...
            '<Style id="polygonStyle">' newline ...
            '<LineStyle>' newline ...
            '<color>ff0000ff</color>' newline ...
            '<width>2</width>' newline ...
            '</LineStyle>' newline ...
            '<PolyStyle>' newline ...
            '<color>7f0000ff</color>' newline ...
            '</PolyStyle>' newline ...
            '</Style>' newline ...
            '<Placemark>' newline ...
            '<name>' this.name '</name>' newline ...
            '<styleUrl>#polygonStyle</styleUrl>' newline ...
            '<Polygon>' newline ...
            '<outerBoundaryIs>' newline ...
            '<LinearRing>' newline ...
            '<coordinates>'];

        % add coordinates
        for i = 1:length(this.lat)
            kmlStr = [kmlStr num2str(this.lon(i)) ',' num2str(this.lat(i)) ',0 ']; %#ok<AGROW>
        end
        kmlStr = [kmlStr newline '</coordinates>' newline ...
            '</LinearRing>' newline ...
            '</outerBoundaryIs>' newline ...
            '</Polygon>' newline ...
            '</Placemark>' newline ...
            '</Document>' newline ...
            '</kml>'];

        % write to file


        % Create a KML file.
        fid = fopen(filename, 'w');
        fprintf(fid, '%s', kmlStr);
        fclose(fid);
    end

    function [this, rotation, newOrder] = make_counter_clockwise(this)
        % make sure the lat/lon points are in counter clockwise order
        % with the first point being the lower left corner

        origOrder = (1:numel(this.lat))';
        newOrder = origOrder;
        % find the center of the polygon
        lat_center = mean(this.lat);
        lon_center = mean(this.lon);

        % find the angle of each point from the center
        angles = atan2(this.lat - lat_center, this.lon - lon_center);

        % check if the polygon is clockwise or counter clockwise
        % by checking the sign of the cross product of the first
        % and last point with the center
        cross_product = (this.lat(1) - lat_center) * (this.lon(end) - lon_center) - (this.lat(end) - lat_center) * (this.lon(1) - lon_center);
        isReversed = false;
        if cross_product > 0
            % clockwise
            % reverse the order of the points
            this.lat = flipud(this.lat);
            this.lon = flipud(this.lon);
            newOrder = flipud(origOrder);
            % recalculate the angles
            angles = atan2(this.lat - lat_center, this.lon - lon_center);
            isReversed = true;
        end

        % sort the points by the angle from the center
        [sortedAngles, sortedInds] = sort(angles, 'ascend');
        this.lat = this.lat(sortedInds);
        this.lon = this.lon(sortedInds);
        newOrder = newOrder(sortedInds);
        % determine the overall rotation of the polygon
        % by finding the angle between the first point and the
        % lower left corner
        if isReversed
            rotation = sortedAngles(1) - pi/2;
        else
            rotation = sortedAngles(1) + pi/2;
        end
    end

    function save_kml_with_image( this, filepath, imgData, cLims )
        % kml requires a specific poly order
        % [this, rotation, newOrder] = this.make_counter_clockwise();
        % % if the rotation is not zero, rotate the image
        % if rotation ~= 0
        %     imgData = imrotate(imgData, -rotation*180/pi, 'bilinear', 'crop');
        % end

        % write the image to a file
        imgPath = strrep(filepath, '.kml', '.jpeg');
        OI.Functions.mkdirs(imgPath);
        if nargin < 4 % no lims provided, jyst normalise
            
        else
            imgData(imgData<cLims(1)) = cLims(1);
            imgData(imgData>cLims(2)) = cLims(2);
        end
        OI.Functions.imwrite(imgData, imgPath, true);

        kml = OI.Data.Kml();
        kml = kml.addPolygon( ...
            OI.Functions.obj2struct(this));
        % As we're saving the KML alongside the image, we can use relative
        % image path which is more portable for e.g. network paths.
        [imgDir, imgName, imgExt] = fileparts(imgPath); %#ok<ASGLU> maybe need
        imgPath = [imgName, imgExt];
        kml.write( filepath, imgPath );

        
    end

    function this = rectangularise(this)
        this = OI.Data.GeographicArea.from_limits(min(this.lat), max(this.lat), min(this.lon), max(this.lon));
    end

    function this = encompass(this, points)
        if isa(points, 'OI.Data.GeographicArea')
            gA = points;
            points = zeros(numel(gA.lat),2); % needed to change type
            points(:,2) = gA.lon;
            points(:,1) = gA.lat;
        end
        % expand the polygon to encompass the points provided
        % points should be a 2 column array of lat/lon points
        this.lat = [this.lat; points(:,1)];
        this.lon = [this.lon; points(:,2)];
    end

    function tf = contains(obj, lat, lon)
        % test if a point is contained within the polygon
        % example: lat = 48.5, lon = -122.5
        tf = inpolygon(lon, lat, obj.lon, obj.lat);
    end

    function this = simplify(this)
        % use convhull to simplify the polygon
        % this is a good way to remove duplicate points
        K = convhull(this.lon, this.lat, 'simplify', true);
        this.lon = this.lon(K);
        this.lat = this.lat(K);
    end

    function this = scale(this, scale)
        % scale the polygon by a factor
        
        % find the center of the polygon
        lat_center = mean(this.lat);
        lon_center = mean(this.lon);

        % translate the polygon so that the center is at the origin
        this.lat = this.lat - lat_center;
        this.lon = this.lon - lon_center;

        % scale the polygon
        this.lat = this.lat * scale;
        this.lon = this.lon * scale;

        % translate the polygon back to its original center
        this.lat = this.lat + lat_center;
        this.lon = this.lon + lon_center;

    end

    function tf = overlaps(this, other)
        % check if any part of the polygon overlaps with another polygon
        % we do this by checking if any of the points are inside the other
        % polygon, or if any of the segments intersect

        % check if one polygon is completely inside the other
        if any(this.contains(other.lat, other.lon)) || ...
            any(other.contains(this.lat, this.lon))
            tf = true;
            return
        end

        % check if any of the segments intersect
        for i = 1:length(this.lat)-1
            for j = 1:length(other.lat)-1
                tf = OI.Data.GeographicArea.segments_intersect(...
                    this.lat(i), this.lon(i), this.lat(i+1), this.lon(i+1), ...
                    other.lat(j), other.lon(j), other.lat(j+1), other.lon(j+1));
                if tf
                    return
                end
            end
        end
    end
end

methods (Static)
    
    function obj = from_limits(minLat,maxLat,minLon,maxLon)
        obj = OI.Data.GeographicArea();
        % create a rectangular ring of corners from the limits provided:
        obj.lat = [minLat; maxLat; maxLat; minLat; minLat];
        obj.lon = [minLon; minLon; maxLon; maxLon; minLon];
    end

    function tf = segments_intersect(...
            aStartX, aStartY, aEndX, aEndY, bStartX, bStartY, bEndX, bEndY)
        % Given two straight lines a and b, with start and end coordinates
        % do they intersect?
        % https://en.wikipedia.org/wiki/Line%E2%80%93line_intersection#Given_two_points_on_each_line
        % 
        % figure(1)
        % clf
        % rr = reshape([aStartX, aStartY, aEndX, aEndY, bStartX, bStartY, bEndX, bEndY ],2,[])';
        % plot(rr(1:2,2),rr(1:2,1))
        % hold on
        % plot(rr(3:4,2),rr(3:4,1))
        % legend({'a','b'})
        % grid minor
        % scatter(rr(:,2),rr(:,1),'filled','k')

        % check for equality first
        % this helps avoid divide by zero errors
        if aStartX == bStartX || aStartY == bStartY || aEndX == bEndX || aEndY == bEndY
            tf = true;
            return
        end

        % calculate the determinants
        Px_numerator = (aStartX * aEndY - aStartY * aEndX) * (bStartX - bEndX) - ...
            (aStartX - aEndX) * (bStartX * bEndY - bStartY * bEndX);
        Px_denominator = (aStartX - aEndX) * (bStartY - bEndY) - ...
            (aStartY - aEndY) * (bStartX - bEndX);
        Py_numerator = (aStartX * aEndY - aStartY * aEndX) * (bStartY - bEndY) - ...
            (aStartY - aEndY) * (bStartX * bEndY - bStartY * bEndX);
        Py_denominator = (aStartX - aEndX) * (bStartY - bEndY) - ...
            (aStartY - aEndY) * (bStartX - bEndX);

        % check for divide by zero
        if Px_denominator == 0 || Py_denominator == 0
            tf = false;
            return
        end

        % calculate the intersection point
        Px = Px_numerator / Px_denominator;
        Py = Py_numerator / Py_denominator;

        % check if the intersection point is on the line segments
        % there are two ways to do this:
        % 1. check if the intersection point is within the bounding box of
        %    the line segments
        % 2. check if the intersection point is on the line segment
        % option 2 is easier because there is floating point error in the
        % intersection point calculation, so some tolerance is needed

        % method 1
        % if Px < min(aStartX, aEndX) || Px > max(aStartX, aEndX) || ...
        %         Px < min(bStartX, bEndX) || Px > max(bStartX, bEndX) || ...
        %         Py < min(aStartY, aEndY) || Py > max(aStartY, aEndY) || ...
        %         Py < min(bStartY, bEndY) || Py > max(bStartY, bEndY)
        %     tf = false;
        %     return
        % end

        tolerance = 1e-9;
        offsetFromMin = @(p,s,e) p - min(s,e);
        offsetFromMax = @(p,s,e) p - max(s,e);
        isBetween = @(p,s,e) offsetFromMin(p,s,e) > -tolerance && offsetFromMax(p,s,e) < tolerance;

        tf = isBetween(Px, aStartX, aEndX) && isBetween(Py, aStartY, aEndY) && ...
            isBetween(Px, bStartX, bEndX) && isBetween(Py, bStartY, bEndY);

        % title(num2str(tf))
        % 1;
        % method 2
        % check if the intersection point is on the line segment
        % https://en.wikipedia.org/wiki/Distance_from_a_point_to_a_line#Line_defined_by_two_points
        % calculate the distance from the intersection point to each line
        % segment
        % This calculates the area of a triangle between the starting point, end and intersection point.
        % distA = abs( ( aStartX - Px ) * ( aEndY - aStartY) - ( aStartX - aEndX ) * ( Py - aStartY ) );
        % distB = abs( ( bStartX - Px ) * ( bEndY - bStartY) - ( bStartX - bEndX ) * ( Py - bStartY ) );

        % % have the tolerance be a percentage of the length of the line
        % % segment
        % if distA > 0.0001 * sqrt((aEndX - aStartX)^2 + (aEndY - aStartY)^2) ...
        %    || distB > 0.0001 * sqrt((bEndX - bStartX)^2 + (bEndY - bStartY)^2)
        %     tf = false;
        %     return
        % end

        
        % if we get here, the lines must intersect


    end


    function obj = from_gml(gml)
        obj = OI.Data.GeographicArea();
        % parse GML coordinates into a polygon of lat/lon points
        % example: gml = '48.0 -123.0 48.0 -122.0 49.0 -122.0 49.0 -123.0 48.0 -123.0'
        coords = str2num(gml); 
        obj.lat = coords(1:2:end);
        obj.lon = coords(2:2:end);
    end

    function obj = from_GeoJSON(geojson)
        obj = OI.Data.GeographicArea();
        % parse GeoJSON coordinates into a polygon of lat/lon points
        % example: geojson = '[[[-123.0,48.0],[-122.0,48.0],[-122.0,49.0],[-123.0,49.0],[-123.0,48.0]]]'
        geojson = jsondecode(geojson);
        coords = geojson.coordinates{1};
        obj.lat = coords(:,2);
        obj.lon = coords(:,1);
    end

end

end% classdef