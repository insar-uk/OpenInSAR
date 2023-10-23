classdef Kml
% create a KML file from multiple polygons

properties
    polygons = {}; % cell array of polygons
    name = 'KML'; % name of the KML file
end

methods 
    function obj = Kml()
    end

    function obj = addPolygon(obj, polygon)
        % add a polygon to the KML file
        obj.polygons{end+1} = polygon;
    end

    function obj = addPolygons(obj, polygons)
        % add multiple polygons to the KML file
        for i = 1:length(polygons)
            obj = obj.addPolygon(polygons{i});
        end
    end

    function obj = write(obj, filename, optionalImagePath)

        if strcmpi(obj.name,'KML') % if name not configured
            if nargin > 2
                [~, filepartName] = fileparts(optionalImagePath);
                obj.name = filepartName;
            else
                [~, filepartName] = fileparts(filename);
                obj.name = filepartName;
            end
        end

        % write the KML file
        if nargin < 2
            filename = obj.name;
        end
        % if optionalImagePath is specified, add the image to the KML file
        % this is done by adding a <GroundOverlay> element
        % with the image as the <Icon> element and <href> subelement
        if numel(filename) < 5 || ~strcmpi(filename(end-3:end),'.kml')
            filename = [filename '.kml'];
        end
        fid = fopen(filename, 'w');
        fprintf(fid, '<?xml version="1.0" encoding="UTF-8"?>\n');
        fprintf(fid, '<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">\n');
        if nargin == 2
            fprintf(fid, '<Document>\n');
            fprintf(fid, '<name>%s</name>\n', obj.name);
            for i = 1:length(obj.polygons)
                fprintf(fid, '<Placemark>\n');
                fprintf(fid, '<name>%s</name>\n', obj.polygons{i}.name);
                fprintf(fid, '<Polygon>\n');
                fprintf(fid, '<outerBoundaryIs>\n');
                fprintf(fid, '<LinearRing>\n');
                fprintf(fid, '<coordinates>\n');
                % for j = 1:size(obj.polygons{i}.lat, 1)
                    if ~isfield(obj.polygons{i}, 'alt')
                        obj.polygons{i}.alt = 0 .* obj.polygons{i}.lat;
                    end
                    vertex = [obj.polygons{i}.lon, ...
                        obj.polygons{i}.lat, ...
                        obj.polygons{i}.alt];
                    fprintf(fid, '%f,%f,%f\n', vertex');
                % end
                fprintf(fid, '</coordinates>\n');
                fprintf(fid, '</LinearRing>\n');
                fprintf(fid, '</outerBoundaryIs>\n');
                fprintf(fid, '</Polygon>\n');
                fprintf(fid, '</Placemark>\n');
            end
            fprintf(fid, '</Document>\n');
        elseif nargin == 3
            fprintf(fid, '<GroundOverlay>\n');
            fprintf(fid, '<name>%s</name>\n', obj.name);
            fprintf(fid, '<Icon>\n');
            fprintf(fid, '<href>%s</href>\n', optionalImagePath);
            fprintf(fid, '<viewBoundScale>0.75</viewBoundScale>\n');
            fprintf(fid, '</Icon>\n');
            % use lat lon quad to specify the image location
            % <gx:LatLonQuad>
            % <coordinates>
            %     -4.179990468750646,51.1453099378578,0 -2.851792080416179,51.30643582018996,0 -2.903249846221575,51.49133072391042,0 -4.244850372318767,51.3339326292886,0 
            % </coordinates>
            % </gx:LatLonQuad>
            fprintf(fid, '<gx:LatLonQuad>\n');
            fprintf(fid, '<coordinates>\n');
            for ii = 1:length(obj.polygons)
                for jj = 1:length(obj.polygons{ii}.lat)
                    fprintf(fid, '%f,%f,0 ', obj.polygons{ii}.lon(jj), obj.polygons{ii}.lat(jj));
                end
            end
            fprintf(fid, '</coordinates>\n');
            fprintf(fid, '</gx:LatLonQuad>\n');
            fprintf(fid, '</GroundOverlay>\n');
        end
        fprintf(fid, '</kml>\n');
        fclose(fid);
    end

end

end %classdef