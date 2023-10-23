% recursively make directories for a file
function mkdirs( filepath )
    dirs = strsplit( filepath, {'\','/'} );
    hasMountPoint = isempty(dirs{1});
    if hasMountPoint
        isUnixMount = filepath(1) == '/';
        isWinNetworkMount = numel(filepath)>=2 && strcmp(filepath(1:2), '\\');
        if isUnixMount
            dirs{1} = filesep; % /some/linux/mount/point/
        elseif isWinNetworkMount
            dirs{1} = [filesep filesep]; % \\some\windows\mount\point\
        end
    end

    % Create directories. Start with deepest.
    for ii = length( dirs ) - 1 : -1 : 2
        % If dir exists, we can exit
        if exist( fullfile( dirs{ 1 : ii } ), 'dir' )
            return
        else
            fprintf(1,'Creating directory %s\n', fullfile( dirs{ 1 : ii } ));
            mkdir( fullfile( dirs{ 1 : ii } ) );
        end
    end
end