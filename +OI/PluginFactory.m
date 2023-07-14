classdef PluginFactory

methods (Static)

    function pluginHandle = get_plugin_handle(pluginName, ui)
        % Create a plugin object
        % from the available options in OI.Plugins
        if nargin < 2
            ui = OI.UserInterface();
        end% if


        ui.log('debug', ['Creating plugin ' pluginName '\n']);
        
        switch pluginName
            case {'GetSentinel1DownloadList'}
                pluginHandle = OI.Plugins.GetSentinel1DownloadList;
            case {'GetAsfQuery'}
                pluginHandle = OI.Plugins.GetAsfQuery;
            case {'DownloadSentinel1Data'}
                pluginHandle = OI.Plugins.DownloadSentinel1Data;
            case {'GetCatalogue'}
                pluginHandle = OI.Plugins.GetCatalogue;
            case {'GetOrbits'}
                pluginHandle = OI.Plugins.GetOrbits;
            case {'Geocoding'}
                pluginHandle = OI.Plugins.Geocoding;
            case {'Coregistration'}
                pluginHandle = OI.Plugins.Coregistration;
            case {'Substacking'}
                pluginHandle = OI.Plugins.Substacking;
            otherwise
                ui.log('debug', ['Plugin ' pluginName ' not found' '\n']);
                try
                    pluginHandle = eval(['OI.Plugins.' pluginName]);
                catch ERROR
                    ui.log('error', ['Plugin ' pluginName ' not found or interpreted' '\n']);
                    ERROR.message
                    ui.log('error', ERROR.message);
                    pluginHandle = [];
                end% try
        end% switch

    end

end% methods (Static)

end% classdef