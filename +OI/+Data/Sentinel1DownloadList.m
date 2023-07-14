classdef Sentinel1DownloadList < OI.Data.DataObj

properties
    % name = 'Sentinel1DownloadList';
    id = 'Sentinel1DownloadList';
    generator = 'GetSentinel1DownloadList';

end%properties

methods
    function this = Sentinel1DownloadList( )
        this.hasFile = true;
        this.fileextension = 'txt';
        this.filepath = [this.filepath, 'Sentinel1DownloadList'];
    end%ctor
end%methods

end%classdef