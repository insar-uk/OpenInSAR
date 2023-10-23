function tilepaths = get_srtm_tiles(minLat, maxLat, minLon, maxLon, directory, username, password)
    % address for srtm download
    % note trailing /
    NASA_URL = 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/'; 

    if nargin < 5
        directory = fullfile(pwd,'srtm1');
    end
    % make sure the directory exists
    if ~exist(directory,'dir')
        OI.Functions.mkdirs(fullfile(directory,'1'));
    end

    % SRTM1_TILE_SZ = [3601,3601]; % SRTM1 tile size
    

    %SRTM is in integer lat/lon squares
    latIntegers = floor(minLat):floor(maxLat);
    lonIntegers = floor(minLon):floor(maxLon);

    % Get all the tiles needed via meshgrid
    [latGrid,lonGrid] = meshgrid(latIntegers,lonIntegers);
    lat = latGrid(:);
    lon = lonGrid(:);

    % files to download and save
    tilenames = cell(size(lat));
    tileurls = cell(size(lat));

    % Result cell:
    tilepaths = cell(size(lat));
    
    % Name format:
    hgtFormatStr = '%s%s.hgt';
    urlFormatStr = '%s%s%s.SRTMGL1.hgt.zip';
    % Determine the formatted filename
    for n = 1:numel(tilenames)
        if lat(n) < 0
            slat = sprintf('S%02d',-lat(n));
        else
            slat = sprintf('N%02d',lat(n));
        end
        if lon(n) < 0
            slon = sprintf('W%03d',-lon(n));
        else
            slon = sprintf('E%03d',lon(n));
        end
        tilenames{n} = sprintf(hgtFormatStr,slat,slon);
        tileurls{n} = sprintf(urlFormatStr,NASA_URL,slat,slon);
        tilepaths{n} = fullfile(directory, tilenames{n});
    end % for each tile

    % Check if the file already exists
    needsDownload = zeros(n,1);
    needsUnzip = zeros(n,1);
    for n = 1:numel(tilepaths)
        fileExists = exist(tilepaths{n},'file');
        zipExists = exist([tilepaths{n},'.zip'],'file');
        
        needsDownload(n) = ~zipExists && ~fileExists;
        needsUnzip(n) = needsDownload(n) || (zipExists && ~fileExists);
    end

    % download and unzip the file
    for n = 1:numel(tilepaths)
        if needsDownload(n)
            remoteaddress = tileurls{n};
            localaddress = [tilepaths{n}, '.zip'];
            % cURLCommand = sprintf('curl -u %s:%s -o %s %s',...
            %     username,password,...
            %     localaddress, ...
            %     remoteaddress ...
            % );
            % [s,w] = system(cURLCommand);
            wgetCommand = sprintf( ...
                "wget -c -q -O %s --user=%s --password=%s %s --no-check-certificate", ...
                localaddress, username, password, remoteaddress);
            [s,w] = system(wgetCommand);
            if s==6
                error( [ 'USERNAME/PASSWORD ERROR ' ...
                        ' URL:\n%s\nUSERNAME: %s' ], ...
                    NASA_URL, ...
                    username );
            end

            if s
                warning('Error code %d',s);
                disp(w);
            end
        end % if needsDownload

        if needsUnzip(n)
            inputPath = [tilepaths{n}, '.zip'];
            if OI.OperatingSystem.isUnix
                unzipCommand = sprintf('unzip -DD -o %s -d %s', ...
                    inputPath, ...
                    directory ...
                );
            else
                unzipCommand = sprintf('powershell -Command "Expand-Archive -Path ''%s'' -DestinationPath ''%s''"', inputPath ,directory);
            end

            [s,w] = system(unzipCommand);
            if s
                disp(w)
                % rename the failed zip file
                oneInAMillion = num2str(floor(mod(now(),1)*1000000));
                movefile([tilepaths{n}, '.zip'], ...
                    [tilepaths{n}, '.zip.failed', oneInAMillion]);
                error('TODO: Handle this by recursion somehow.')
            else
                % delete the zip
                delete([tilepaths{n}, '.zip']);
            end
        end % if needsUnzip
    end % for each tile
end

%#ok<*TNOW1> - Octave compatibility


