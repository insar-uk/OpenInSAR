classdef Sentinel1DownloadSummary < OI.Data.DataObj
    properties
        generator = 'DownloadSentinel1Data'
        id = 'Sentinel1DownloadSummary'
        folders = ''
        files = ''
    end % properties

    methods
        function this = Sentinel1DownloadSummary( varargin )
            this.hasFile = true;
            this.filepath = '$WORK$/$id$';
        end
    end % methods

end % classdef