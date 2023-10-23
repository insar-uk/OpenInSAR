classdef GetSentinel1DownloadList < OI.Plugins.PluginBase

properties
    inputs = {OI.Data.AsfQueryResults()}
    outputs = {OI.Data.Sentinel1DownloadList()}
    id = 'GetSentinel1DownloadList'
end% properties

methods

    function this = run(this, engine, varargin)
        this.inputs{1} = this.inputs{1}.identify( engine );
        [asfResults, jobs] = this.inputs{1}.load(engine);
        if isempty(asfResults)
            engine.queue.add_job(jobs{1});
            return
        end% if
        
        % parse the json, extract the downloadUrl property from each entry
        resultStruct = jsondecode(asfResults);

        parsedText = '';
        for i = 1:length(resultStruct)
            downloadUrl = resultStruct(i).downloadUrl;
            % add line to text file
            parsedText = [parsedText downloadUrl '\n'];  %#ok<AGROW> - this is a small file, so it's ok
        end% for
        engine.save( this.outputs{1}, parsedText );
    end% run

end% methods

end % classdef

% response example:
% [
%   [
%     {
%       "absoluteOrbit": "47804",
%       "beamMode": "IW",
%       "beamModeType": "IW",
%       "beamSwath": null,
%       "browse": null,
%       "catSceneId": null,
%       "centerLat": "53.8273",
%       "centerLon": "-1.0183",
%       "collectionName": null,
%       "configurationName": "Interferometric Wide. 250 km swath, 5 m x 20 m spatial resolution and burst synchronization for interferometry. IW is considered to be the standard mode over land masses.",
%       "doppler": "0",
%       "downloadUrl": "https://datapool.asf.alaska.edu/SLC/SA/S1A_IW_SLC__1SDV_20230325T175029_20230325T175056_047804_05BE4F_59A4.zip",
%       "farEndLat": "54.821419",
%       "farEndLon": "0.713377",
%       "farStartLat": "53.20895",
%       "farStartLon": "1.129648",
%       "faradayRotation": null,
%       "fileName": "S1A_IW_SLC__1SDV_20230325T175029_20230325T175056_047804_05BE4F_59A4.zip",
%       "finalFrame": "1077",
%       "firstFrame": "1077",
%       "flightDirection": "ASCENDING",
%       "flightLine": null,
%       "formatName": null,
%       "frameNumber": "172",
%       "frequency": null,
%       "granuleName": "S1A_IW_SLC__1SDV_20230325T175029_20230325T175056_047804_05BE4F_59A4",
%       "granuleType": "SENTINEL_1A_FRAME",
%       "groupID": "S1A_IWDV_0173_0178_047804_132",
%       "incidenceAngle": null,
%       "insarGrouping": null,
%       "insarStackSize": null,
%       "lookDirection": "R",
%       "masterGranule": null,
%       "md5sum": "a2a5499b966906a04fa8f4bf3ebe9c1c",
%       "missionName": null,
%       "nearEndLat": "54.412128",
%       "nearEndLon": "-3.227422",
%       "nearStartLat": "52.803574",
%       "nearStartLon": "-2.660347",
%       "offNadirAngle": null,
%       "percentCoherence": null,
%       "percentTroposphere": null,
%       "percentUnwrapped": null,
%       "platform": "Sentinel-1A",
%       "pointingAngle": null,
%       "polarization": "VV+VH",
%       "processingDate": "2023-03-25T17:50:29.000000",
%       "processingDescription": "Sentinel-1A Single Look Complex product",
%       "processingLevel": "SLC",
%       "processingType": "L1",
%       "processingTypeDisplay": "L1 Single Look Complex (SLC)",
%       "productName": "S1A_IW_SLC__1SDV_20230325T175029_20230325T175056_047804_05BE4F_59A4",
%       "product_file_id": "S1A_IW_SLC__1SDV_20230325T175029_20230325T175056_047804_05BE4F_59A4-SLC",
%       "relativeOrbit": "132",
%       "sarSceneId": null,
%       "sceneDate": "2023-03-25T17:50:56.000000",
%       "sceneDateString": null,
%       "sceneId": "S1A_IW_SLC__1SDV_20230325T175029_20230325T175056_047804_05BE4F_59A4",
%       "sensor": "C-SAR",
%       "sizeMB": "4122.887258529663",
%       "slaveGranule": null,
%       "startTime": "2023-03-25T17:50:29.000000",
%       "status": null,
%       "stopTime": "2023-03-25T17:50:56.000000",
%       "stringFootprint": "POLYGON((0.713377 54.821419,1.129648 53.208950,-2.660347 52.803574,-3.227422 54.412128,0.713377 54.821419))",
%       "thumbnailUrl": null,
%       "track": "132",
%       "varianceTroposphere": null
%     }
%   ]
% ]
