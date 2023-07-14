function absPath = abspath( inputPath )
    % function absPath = abspath(relativePath)
    % Returns the absolute path of the given relative path.
    % Get the current directory
    currentDir = pwd;
    [relativePath, appendage, ext] = fileparts( inputPath );
    appendage = [appendage ext];

    % if folder doesnt exist, try moving back up the directory tree
    while exist(relativePath, 'dir') ~= 7
        % Get the folder of the file
        lastPath = relativePath;
        [relativePath, f] = fileparts(relativePath);
        
        % if first time and no upper directory, check current directory
        if numel(lastPath) == 0 && numel(relativePath) == 0
            relativePath = pwd;
            break
        end

        % if the root isn't 
        appendage = [f filesep appendage];

        % if we haven't moved we're at a root
        if numel(lastPath) == numel(relativePath)
            % We are at the root, so the path does not exist
            error( [ ...
                'The given path ... \n\t''%s''\n... does not exist. ' ...
                'Its root could not be found.' ...
                ], inputPath);
        end
    end
    
    try
        % Change to the relative path
        cd(relativePath);
    catch ERR % return to initial dir if error
        cd(currentDir);
        rethrow(ERR)
    end

    % Get the absolute path to the valid directory
    absPath = pwd;
    % Change back to the current directory
    cd(currentDir);
    % Append any nonexistent folders/files argued
    absPath = [absPath filesep appendage];
end
