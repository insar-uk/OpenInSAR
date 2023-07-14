classdef Sentinel1Strip < OI.Data.DataObj

properties
    name
    number 
    swath

    safePath
    annotationPath
    annotation

    md5
    polarization
    startTime
    endTime
    

    orbit
end % properties

methods
    %./measurement/s1a-iw2-slc-vh-20230318t175815-20230318t175841-047702-05baed-002.tiff"
    function this = Sentinel1Strip()
        this.fileextension = 'tiff';
    end

    function fullpath = getFilepath(this)
        fullpath = fullfile( this.safePath, ...
            strrep(strrep(this.filepath,'./','/'),'.\','\') ...
            );
    end

    function A = get_annotations( this )
        if isempty(this.annotatioPath)
            error('not initialised correctly')
        end
        tAnnotationPath = this.annotationPath;
        % usually the first two chars is './' which works (on win?) but lets be safe
        if strcmp(tAnnotationPath(1:2), './')
            tAnnotationPath = tAnnotationPath(3:end);
        end
        % get the full path to the annotation file
        tAnnotationPath = fullfile(safeFolderPath, tAnnotationPath);
        A = OI.Data.XmlFile( tAnnotationPath ).to_struct();
    end

end % methods

methods (Static)

    
    function strips = from_manifest( manifestText )
        % split the manifest into lines
        lines = strsplit( manifestText, newline );
        % find the lines that contain '<fileLocation'
        fileLineIndex = cellfun( @(x) ~isempty( strfind( x, '<fileLocation' ) ) , lines );
        fileLines = lines( fileLineIndex );
        % the lines after are the md5s
        md5Lines = lines( fileLineIndex+1 );

        % remove everything before "./"
        fileLines = cellfun( @(x) x( strfind( x, './' ):end ), fileLines, 'UniformOutput', false );

        % get measurement tiffs
        tiffLineIndix = cellfun( @(x) ~isempty( strfind( x, '.tiff' ) ), fileLines );
        tiffLines = fileLines( tiffLineIndix );
        % remove everything after ".tiff"
        tiffLines = cellfun( @(x) x( 1:strfind( x, '.tiff' )+4 ), tiffLines, 'UniformOutput', false );

        % get the md5s for the tiffs
        tiffMd5Lines = md5Lines( tiffLineIndix );
        % strip everything before "MD5"> inclusive and </checksum after
        tiffMd5Lines = cellfun( @(x) x( strfind( x, 'MD5">' )+5:strfind( x, '</checksum' )-1 ), tiffMd5Lines, 'UniformOutput', false );

        % get annotation xmls
        % annotationLines = fileLines( cellfun( @(x) ~isempty( strfind( x, '.xml' ) ), fileLines ) );
        % but not /calibration/ or /rfi/. Just files begining with "s1"
        annotationLines = fileLines( cellfun( @(x) ~isempty( strfind( x, '/annotation/s1' ) ), fileLines ) );
        % remove everything after ".xml"
        annotationLines = cellfun( @(x) x( 1:strfind( x, '.xml' )+3 ), annotationLines, 'UniformOutput', false );

        % make a strip for each tiff
        nStrips = length( tiffLines );
        strips = cell( nStrips, 1 );
        for ii = 1:nStrips
            % make a new strip object
            strips{ii} = OI.Data.Sentinel1Strip();
            
            % assign filepath and name
            strips{ii}.filepath = tiffLines{ii};
            lastSlash = strfind( tiffLines{ii}, '/' );
            lastSlash = lastSlash(end);
            strips{ii}.name = tiffLines{ii}( lastSlash+1:end );

            % get the number of the strip from the tiff filename
            % e.g. s1a-iw2-slc-vh-20230318t175815-20230318t175841-047702-05baed-002.tiff
            % 002 is the strip number
            stripNum = str2double( tiffLines{ii}( end-6:end-4 ) );
            strips{ii}.number = stripNum;

            % find the annotation file that matches this tiff
            annotationLine = annotationLines{ cellfun( @(x) ~isempty( strfind( x, sprintf( '-%03d.xml', stripNum ) ) ), annotationLines ) };
            strips{ii}.annotationPath = annotationLine;
            
            % get the md5 for this tiff
            strips{ii}.md5 = tiffMd5Lines{ii};
            
            % get the polarization from the tiff filename
            strips{ii}.polarization = strips{ii}.name( 13:14 );

            % get the swath from the tiff filename
            namebits = strsplit(strips{ii}.name,'-');
            strips{ii}.swath = str2double(namebits{2}(3));
            % s1a-iw1-slc-vh-20181223t063110-20181223t063135-025149-02c70a-001.tiff
        end

    end
end % methods

end % classdef
