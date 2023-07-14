classdef OperatingSystem
properties (Constant = true)
    isUnix = isunix;
    isWindows = ispc;
    isMac = ismac;
end%properties

    methods (Static = true)
        function tempdir = get_usr_dir()
            if isunix
                tempdir=getenv('HOME');
            else
                tempdir=getenv('HOME');
                % try again...
                if isempty(tempdir)
                    tempdir = [getenv('homedrive') getenv('homepath')];
                end
                if ~exist(tempdir,'dir')
                    error(" Where is your home directory? ");
                end
            end
        end

        function info = system_info()
        % Get system information
        %    Inputs: none
        %    Outputs: structure
            info.os = OI.OperatingSystem.os_str();
            info.username =  getenv("USERNAME");
            info.machinename = getenv("COMPUTERNAME");
            info.processor = getenv("PROCESSOR_IDENTIFIER");
            [sysCallStatusCode, sysCallResponse] = system("VER");
            if ~sysCallStatusCode
                info.version = strtrim(sysCallResponse);
            else
                info.version = "Unknown Windows";
            end
        end

        function osStr = os_str()
            if OI.OperatingSystem.isUnix; osStr = "unix"; end
            if OI.OperatingSystem.isWindows; osStr = "windows"; end
            if OI.OperatingSystem.isMac; osStr = "mac"; end
        end

        function isOct = is_octave()
            isOct = exist('OCTAVE_VERSION','builtin')>0;
        end
    end
end
