classdef Catalogue < OI.Data.DataObj

properties
    id = 'Catalogue'
    generator = 'GetCatalogue'
    safes = {};
    notes = {}; % e.g. why a scene is rejected
    nSafes = 0;

    coverageBySafe = [];
    trackNumbersBySafe = [];
    
    trackNumbers = [];
    catalogueIndexByTrack = [];
    sceneCountByTrack = [];
    coverageByTrack = [];
end

methods
    function this = Catalogue()
        this.filepath = '$OUTPUT_DATA_DIR$/catalogue';
        this.hasFile = true;
        this.isUniqueName = true;
    end

    function tf = needs_load( this )
        % if our list of safes is complete, then so is this object ...  no
        % more data needs loading
        tf = isempty(this.safes);
    end

    function this = add_safe_from_file_struct(this, fileStruct, projObj)
        filepath = fullfile(fileStruct.folder, fileStruct.name); 
        this.nSafes = this.nSafes + 1;
        if nargin < 3
            warning(['Please provide the project struct as input'...
                'to allow cross platform loading!'])
            this.safes{this.nSafes,1} = ...
                OI.Data.Sentinel1Safe.from_filepath(filepath);
        else
            this.safes{this.nSafes,1} = ...
                OI.Data.Sentinel1Safe.from_filepath(filepath, projObj);
        end
    end

    function this = add_safe(this, safe, note)
        this.nSafes = this.nSafes + 1;
        this.safes{this.nSafes,1} = safe;
        if nargin > 2
            this.notes{this.nSafes,1} = note;
        end
    end

    function tf = is_track_index_ascending(this, trackIndex)
        % check if the track is ascending or descending
        exampleSafe = this.safes{this.catalogueIndexByTrack(1,trackIndex)};
        tf = (exampleSafe.direction(1) == 'A');
    end

    function this = get_track_info(this)
        % get the coverage and track numbers
        for ii=this.nSafes:-1:1
            this.trackNumbersBySafe(ii,1) = this.safes{ii}.RON;
        end
        % get the track numbers
        this.trackNumbers = unique(this.trackNumbersBySafe)';

        % count the number of scenes per track
        this.sceneCountByTrack = sum( this.trackNumbersBySafe == this.trackNumbers );

        % preallocate the registers
        [this.catalogueIndexByTrack, this.coverageByTrack] = deal( nan(max(this.sceneCountByTrack), length(this.trackNumbers)) );
        % get the scene count by track
        for ii=length(this.trackNumbers):-1:1
            nThisTrack = this.sceneCountByTrack(ii);
            this.catalogueIndexByTrack(1:nThisTrack,ii) = find(this.trackNumbersBySafe == this.trackNumbers(ii))';
            this.coverageByTrack(1:nThisTrack,ii) = cellfun(@(x) x.estimatedCoverageFromManifest, this.safes(this.catalogueIndexByTrack(1:nThisTrack,ii)));
        end
    end
    
    function this = make_filepaths_portable(this, projObj)
        % Replace absolute paths with variable ones, where possible, in
        % order that filepaths are portable accross operating systems.
        for ii = 1:numel(this.safes)
            s = this.safes{ii};
            % if we have info available, try replacing the path
            if nargin>1
                s.filepath = s.replaceholder(s.filepath, projObj);
                if  ~isempty(s.orbitFile)
                    s.orbitFile = this.replaceholder(s.orbitFile, projObj);
                end
            end

            % Also replace the individual data strips
            for jj = 1:numel(this.safes{ii}.strips)
                s.strips{jj}.safePath = s.filepath;
            end

            % copy back
            this.safes{ii} = s;

        end
    end
end

end
