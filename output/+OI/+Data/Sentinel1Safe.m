classdef Sentinel1Safe < OI.Data.DataObj

properties
    name
    id= 'Sentinel1Safe'

    platform
    mode
    datatype %should be SLC
    polarization

    date
    RON
    productUniqueIdentifier

    direction % asc/desc
    footprintFromManifest % footprint from manifest.safe
    estimatedCoverageFromManifest % estimated coverage from manifest.safe

    strips % OI.Data.Sentinel1Strip objects
    corners % a struct with geographic corners @ extent
    % safe.corners.lat
    % safe.corners.lon
    % safe.corners.strips(X).lat
    % safe.corners.strips(X).lon
    % safe.corners.strips(X).bursts(Y).lat
    % safe.corners.strips(X).bursts(Y).lon
    orbitFile

    generator = 'DownloadSentinel1Data'

end% properties

methods
    function this = Sentinel1Safe()
        this.fileextension = 'SAFE';
        this.hasFile = true;
    end% function

    function relativeOrbitNumber = decode_relative_orbit(this, ...
        absoluteOrbitNumber)
        % get a relative orbit from an absolute orbit number
        % if sentinel 1a mod(AON-73,175)+1;
        % if sentinel 1b mod(AON-27,175)+1;
        
        % make sure its an int
        if ischar(absoluteOrbitNumber)
            absoluteOrbitNumber = str2double(absoluteOrbitNumber);
        end% if
        
        switch this.platform
            case 'S1A'
                relativeOrbitNumber = mod(absoluteOrbitNumber-73,175)+1;
            case 'S1B'
                relativeOrbitNumber = mod(absoluteOrbitNumber-27,175)+1;
            otherwise
                error('Unknown platform')
        end% switch
    end% decode_relative_orbit


    function this = get_info_from_manifest( this, aoi )
        % get the manifest
        manifestText = this.get_manifest();
        this.strips = OI.Data.Sentinel1Strip.from_manifest(manifestText);
        for ii = 1:numel(this.strips)
            this.strips{ii}.safePath = this.filepath;
        end
        this = get_coverage_from_manifest(this, manifestText, aoi);
    end

    function manifestText = get_manifest(this)
        % get the manifest.safe file
        manifestFile = fullfile(this.filepath,'manifest.safe');
        manifestText = fileread(manifestFile);
    end% get_manifest

    function this = get_coverage_from_manifest(this, manifestText, aoi)
        % convert the aoi object to a geographic area polygon if it isn't already
        if ~isa(aoi,'OI.Data.GeographicArea')
            aoi = aoi.to_area();
        end
        
        % get the pass while we're at it
        pass = regexp(manifestText,'<s1:pass>(.*?)</s1:pass>','tokens');
        this.direction = pass{1}{1};

        % get the footprint from the manifest
        footprintGml = regexp(manifestText,'<gml:coordinates>(.*?)</gml:coordinates>','tokens');

        this.footprintFromManifest = OI.Data.GeographicArea.from_gml(footprintGml{1}{1});

        % get the estimated coverage by intersecting the aoi with the footprint
        estimationGridSize = [250,250];
        this.estimatedCoverageFromManifest = OI.Functions.coverage( ...
                aoi.scale(1.1), ...
                this.footprintFromManifest, ...
                estimationGridSize ...
            );
    end

    function tiffPath = get_tiff_path(this, swathIndex, polarisation)
        % find correct strip and its filepath
        for stripInd = 1:numel(this.strips)
            strip = this.strips{stripInd};
            if strip.swath == swathIndex && ...
                strcmpi(strip.polarization,polarisation)
                break
            end
        end
        tiffPath = this.strips{stripInd}.getFilepath();
    end

    function annotationPath = get_annotation_path(this, stripIndex)
        if nargin < 2
            stripIndex = 1;
        end
        % get the path to the annotation file
        safeFolderPath = this.filepath;
        % pull out a strip
        strip = this.strips{stripIndex};
        % pull out an annotation filepath
        annotationPath = strip.annotationPath;
        % usually the first two chars is './' which works (on win?) but lets be safe
        if strcmp(annotationPath(1:2), './')
            annotationPath = annotationPath(3:end);
        end
        % get the full path to the annotation file
        annotationPath = fullfile(safeFolderPath, annotationPath);
    end% get_annotation_path
    

    function this = deplaceholder(this, projObj)
        % subsitute placeholder for absolutie path from project
        % variable
        for field = {'filepath','orbitFile'}
            
            pathToFix = deal(this.(field{1}));
            if isempty(pathToFix)
                continue
            end
    
            % replace windows path seperators, other direction works.
            if OI.OperatingSystem.isUnix
                pathToFix = ...
                    strrep(pathToFix,'\',filesep);
            end
    
            % subsitute placeholder for absolutie path from project
            % variable
            for placeholderPath=projObj.pathVars(:)'
                if ~any(pathToFix == '$')
                    break
                end
                pathToFix = ...
                    strrep(pathToFix, ...
                        ['$' placeholderPath{1} '$'], ...
                        projObj.(placeholderPath{1}));
            end
            this.(field{1}) = pathToFix;
        end

        for ii=1:numel(this.strips)
            this.strips{ii}.safePath = this.filepath;
            if OI.OperatingSystem.isUnix
                this.strips{ii}.safePath = ...
                    strrep(this.strips{ii}.safePath,'\',filesep);
            end
        end
    end
end% methods

% S1A_IW_SLC__1SDV_20230301T175029_20230301T175056_047454_05B27C_89DC.SAFE
methods (Static)
    % generate info from the SAFE folder filepath
    function this = from_filepath(filepath)
        this = OI.Data.Sentinel1Safe();

        
        this.name = filepath(end-71:end-5);
        this.filepath = filepath;

        % slit the name into parts
        parts = strsplit(this.name,'_');
        this.platform = parts{1};
        this.mode = parts{2};
        this.datatype = parts{3};
        this.polarization = this.decode_polarisation(parts{4}(3:4));
        this.date = OI.Data.Datetime(parts{5});
        this.RON = this.decode_relative_orbit(parts{7});
        this.productUniqueIdentifier = parts{9};

        
    end% function

    function pol = decode_polarisation(polCode)
        switch polCode
            case 'DV'
                pol = 'VVVH';
            case 'DH'
                pol = 'HHHV';
            case 'SV'
                pol = 'VV';
            case 'SH'
                pol = 'HH';
            otherwise
                error('Unknown polarization %s', polCode)
        end% switch
    end% decode_polarisation

    function relativeOrbitNumber = aon_to_ron(platform, ...
        absoluteOrbitNumber)
        % get a relative orbit from an absolute orbit number
        % if sentinel 1a mod(AON-73,175)+1;
        % if sentinel 1b mod(AON-27,175)+1;
        
        % make sure its an int
        if ischar(absoluteOrbitNumber)
            absoluteOrbitNumber = str2double(absoluteOrbitNumber);
        end% if
        
        switch platform
            case 'S1A'
                relativeOrbitNumber = mod(absoluteOrbitNumber-73,175)+1;
            case 'S1B'
                relativeOrbitNumber = mod(absoluteOrbitNumber-27,175)+1;
            otherwise
                error('Unknown platform')
        end% switch
    end% decode_relative_orbit



end% methods (Static)



end% classdef


% this.platform = this.name(1:3);
% this.datatype = this.name(8:11);
% this.mode = this.name(13:15);
% this.RON = this.name(5:6);
% this.date = OI.Data.Datetime(this.name(18:25),'yyyymmdd');
% this.orbit = this.name(27:31);

    %   % Get SAFE folders
    %     % rightNumberOfChars = arrayfun( @(x) numel(x.name), inputScenes ) == 72;
    %     isSAFE = arrayfun( @(x) numel(x.name)>4 && strcmpi(x.name(end-4:end),'.SAFE'), inputScenes );
    %     inputScenes = inputScenes( isSAFE );

    %     % Ignore HH for now, not enough data
    %     isHH = arrayfun( @(x) x.name(16)=='H', inputScenes );
    %     inputScenes = inputScenes( ~isHH );

    %     %Get date from filename
    %     dateNumbers = arrayfun( @(x) ...
    %         OI.Data.Datetime(x.name(18:25),'yyyymmdd').datenum(), ...
    %         inputScenes);

    %     %Check it's the right date range (within period of interest)
    %     dateQualifier = dateNumbers >= project.START_DATE.datenum() & ...
    %         dateNumbers <= project.END_DATE.datenum();
    %     inputScenes = inputScenes( dateQualifier )