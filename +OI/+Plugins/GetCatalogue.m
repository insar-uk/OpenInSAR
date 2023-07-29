classdef GetCatalogue < OI.Plugins.PluginBase
% TODO catalogue should be renamed repositiory or something that indicates
% it's a list of files available rather than a list of files being used

properties
    inputs = {OI.Data.ProjectDefinition()}
    outputs = {OI.Data.Catalogue()}
    id = 'GetCatalogue'
end% properties


methods

    function this = run( this, engine, varargin )
        % get SAFE files from a directory and create a catalogue
        % .SAFE names are e.g.
        % S1A_IW_SLC__1SDH_20150409T061430_20150409T061500_005403_006DED_FAF7.SAFE

        % get the project
        project = engine.load(OI.Data.ProjectDefinition());

        % load the list of files to download
        dlList = engine.load( OI.Data.Sentinel1DownloadList() );

        if isempty(dlList)
            return % no list of files to download provided
        end

        % get the input data directory
        inputDir = project.INPUT_DATA_DIR;

        %Get data folder contents
        inputScenes=dir(inputDir);

        % Get rid of symbol links to here and parent ('.' and '..')
        inputScenes(1:2)=[];

        % Get SAFE folders
        % rightNumberOfChars = arrayfun( @(x) numel(x.name), inputScenes ) == 72;
        isSAFE = arrayfun( @(x) numel(x.name)>4 && strcmpi(x.name(end-4:end),'.SAFE'), inputScenes );
        inputScenes = inputScenes( isSAFE );

        % Ignore HH for now, not enough data
        isHH = arrayfun( @(x) x.name(16)=='H', inputScenes );
        inputScenes = inputScenes( ~isHH );

        %Get date from filename
        dateNumbers = arrayfun( @(x) ...
            OI.Data.Datetime(x.name(18:25),'yyyymmdd').datenum(), ...
            inputScenes);

        % Get the date order, earliest first
        [dateNumbers, dateOrder] = sort( dateNumbers );
        inputScenes = inputScenes( dateOrder );

        %Check it's the right date range (within period of interest)
        dateQualifier = dateNumbers >= project.START_DATE.datenum() & ...
            dateNumbers <= project.END_DATE.datenum();

        % Check if there are any tracks specified
        tracksToKeep = project.TRACKS; % if empty, keep all
        if ~isnumeric(tracksToKeep)
            tracksToKeep = str2num( tracksToKeep ); %#ok<ST2NM>
        end
        trackQualifier = true(size(dateQualifier));
        if ~isempty(tracksToKeep)
            for ii = 1:numel(trackQualifier)
            % Get the track number from the filename
                splitName = strsplit(inputScenes(ii).name,'_');
                ron = OI.Data.Sentinel1Safe.aon_to_ron( ...
                    splitName{1},... %S1A, S1B
                    str2num(splitName{7})); %#ok<ST2NM>  %AON 
                if ~any(tracksToKeep==ron)
                    trackQualifier(ii)=false;
                end
            end
        end% if
        
        % inputScenes = inputScenes( dateQualifier );

        % create a catalogue
        catalogue = OI.Data.Catalogue();
        % create a list for rejected scenes
        rejectedScenes = OI.Data.Catalogue();

        % Loop through SAFES, add them to the catalogue according to date
        for ii = 1:numel(inputScenes)
            % get the file struct
            fileStruct = inputScenes(ii);
            % get the filepath
            filepath = fullfile(fileStruct.folder, fileStruct.name); 
            % create the scene
            safe = OI.Data.Sentinel1Safe.from_filepath(filepath);
            % check the date
            if ~dateQualifier(ii)
                % add the scene to the rejected scenes
                rejectedScenes = rejectedScenes.add_safe(safe, 'Rejected by date');
                continue
            end
            if ~trackQualifier(ii)
                % add the scene to the rejected scenes
                rejectedScenes = rejectedScenes.add_safe(safe, 'Rejected, not a specified track');
                continue
            end

            % Get info from manifest and check the coverage
            safe = safe.get_info_from_manifest( project.AOI );
            % check the coverage is ok
            if safe.estimatedCoverageFromManifest <= 0
                % add the scene to the rejected scenes
                rejectedScenes = rejectedScenes.add_safe(safe, 'Rejected by coverage');
            else
                % add the scene to the catalogue
                catalogue = catalogue.add_safe(safe);
            end
        end% for
        
        % error here if no data
        if ~numel(catalogue.safes) > 3
            error('No data catlogued?')
        end 
        % Get info about the scenes in each orbital track
        catalogue = catalogue.get_track_info();
        engine.database.add(rejectedScenes);
        engine.database.add(catalogue);

        catalogue = catalogue.make_filepaths_portable(project);
        engine.save(catalogue, catalogue);
        this.isFinished = true;
    end% run

end% methods

end % classdef
