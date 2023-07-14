classdef Test
    % Test runner for OI modules.
    % Test('module1', 'module2', ...) runs tests for the specified modules.
    % Test() or Test('all') runs tests for all modules.
    % Options:
    %  'all' - run all tests
    %  '-q' or '--quiet' - suppress output
    properties 
        results = {}; % cell array of OI.TestResult
        timings = []; % array of dubs
    end

    properties (Access = private)
        isRunningAllTests = false; % boolean
        isSummarising = true; % boolean
        isPrintingErrors = true; % boolean
        isThrowingErrors = false; % boolean
        testList = {}; % cell array of strings
        clargs = {}; % cell array of strings
        startTime = now(); % datenum
        lastTestStartTime = now(); % datenum
    end

    properties (Constant = true, Access = private)
        SUFFIX = '_tests'; % string
        DIRECTORY = fullfile('..','test'); % string
    end
%#ok<*AGROW> - Test arrays are pretty small, so preallocation is not necessary
%#ok<*TNOW1> - now() is better compatibility w/ Octave
%#ok<*FXSET> - Since when was changing a loop index a bad thing?s
%#ok<*FXSET>
    methods
        function this = Test( varargin )

            this = this.config(varargin{:});
            this.testList = this.get_test_list();
            
            
            for currentTest = this.testList
                idx = numel(this.results) + 1;
                this.lastTestStartTime = now();
                currentTest = currentTest{1}; 
                % find the corresponding test
                try
                    testHandle = this.find_test(currentTest);
                    testObj = testHandle(); %#ok<NASGU> - we're just testing initialization
                    % run the test
                    currentResults = this.run_test(testHandle);
                    % append results to this.results
                    this.results = [this.results(:)', currentResults(:)'];% Check this works with Octave rather than {this.results{:}, currentResults{:}};
                catch errorObj
                    errMsg = sprintf('Error : %s not found or could not complete its tests ', currentTest);
                    this.results{end+1} = OI.TestResult(currentTest, 'error', errMsg, errorObj);
                    this.handle_error(errorObj);
                    this.timings(idx) = (now()-this.lastTestStartTime) * 24*60*60;
                    this.timings(idx+1:numel(this.results)) = nan;
                    continue
                end
                this.timings(idx) = (now()-this.lastTestStartTime) * 24 * 60 * 60;
                this.timings(idx+1:numel(this.results)) = nan;
            end

            % Print summary
            if this.isSummarising
                this.print_summary();
            end
        end

        function print_summary( this )
            lastTest = '';
            % get the maximum length of the test name
            maxTestNameLength = 0;
            for ii=1:numel(this.results)
                % get timing string
                timeString = '';
                if ~isnan(this.timings(ii))
                    timeString = sprintf('%.3f s ', this.timings(ii));
                end
                
                strLength = numel(this.results{ii}.testName) + numel(timeString) + 1;
                maxTestNameLength = max(maxTestNameLength, strLength);
                
            end

            % print the results
            for ii=1:numel(this.results)
                % get timing string
                timeString = '';
                if ~isnan(this.timings(ii))
                    timeString = sprintf('%.3f s ', this.timings(ii));
                end
                nTimeString = numel(timeString);

                % Only print test name once if it has multiple cases
                if ~strcmpi(lastTest,this.results{ii}.testName)
                    lastTest = this.results{ii}.testName;
                else
                    % replace with blanks
                    this.results{ii}.testName = blanks(numel(this.results{ii}.testName));
                end
                % pad the test name
                padding = blanks(maxTestNameLength-numel(this.results{ii}.testName));
                this.results{ii}.testName = [this.results{ii}.testName, padding];
                % add the timing string at the end
                this.results{ii}.testName(end-nTimeString+1:end) = timeString;
                
                % Do print
                strSummary = this.results{ii}.get_summary();
                fprintf(1, '%s', strSummary)
            end
            daysToSeconds = 24*60*60;
            fprintf(1, 'Total time: %.3f s\n', (now()-this.startTime) * daysToSeconds);
        end
    end

    methods (Access = private)


        function results = run_test( this,  testHandle )
            % testHandle: function handle
            % results: cell array of OI.TestResult
            results = {};
            try
                % convert the handle to an _tests object
                testObj = testHandle();
                % run the tests
                fprintf(1, 'Running %s\n', func2str(testHandle))
                testObj = testObj.run();               
                results = testObj.results;
                for errorObj = testObj.errors
                    this.handle_error(errorObj{1});
                end
            catch errorObj
                % Default error result
                if isempty(results)
                    results = {OI.TestResult(func2str(testHandle), 'error', 'Test failed to run', errorObj)};
                end
                this.handle_error(errorObj);
            end
        end

        function this = config(this,varargin)
            this.add_test_dir();
            this.clargs = varargin;
            if isempty(this.clargs)
                this.isRunningAllTests = true;
            end
        end

        function testList = get_test_list(this)
            testList = this.testList;
            % get list of tests to run
            if this.isRunningAllTests
                testList = this.get_all_tests();
            else
                for clarg = this.clargs
                    clarg = clarg{1};
                    if isempty(clarg)
                        continue
                    end
                    if strcmp(clarg, 'all')||strcmp(clarg, '-a')||strcmp(clarg, '--all')
                        testList = this.get_all_tests();
                        return
                    end
                    if clarg(1) == '-'
                        continue
                    end
                    testList{end+1} = clarg;
                end
            end
        end

        function handle_error( this, errorObj )
            if this.isPrintingErrors
                OI.Compatibility.print_error_stack(errorObj);
            end
            if this.isThrowingErrors
                rethrow(errorObj)
            end
        end

        
    end% private methods

    methods (Static = true)

        function testHandle = find_test( testName )
            % testName: string
            % testHandle: function handle
            % ensure string
            assert(ischar(testName), 'testName must be a string');
            % make sure suffix matches
            needsSuffix =  numel(testName)<numel(OI.Test.SUFFIX) || ...
                ~strcmpi(testName(end-numel(OI.Test.SUFFIX)+1:end), OI.Test.SUFFIX);
            if needsSuffix 
                testName = [testName, OI.Test.SUFFIX];
            end
            % convert to test function handle
            testHandle = str2func(testName);
        end

        function add_test_dir()
            % add test directory to path
            parentDir = fileparts(fileparts(mfilename('fullpath')));
            testDir = fullfile(parentDir, 'test');
            addpath(testDir);
        end

        function testList = get_all_tests()
            % Get the test directory
            pathOfThisFile = fileparts(mfilename('fullpath'));
            relPath = [pathOfThisFile, filesep, OI.Test.DIRECTORY];
            assert( exist(relPath, 'dir') == 7,'Test directory %s not found.', relPath);

            % Look for all files in test directory
            testList = dir(relPath);
            valid = zeros(numel(testList),1,'logical');

            % get rid of the file extensions
            for ii = 1:numel(testList)
                if testList(ii).isdir || numel(testList(ii).name) < 2
                    continue
                else 
                    if strcmpi(testList(ii).name(end-1:end),'.m')
                        testList(ii).name = testList(ii).name(1:end-2);
                    end
                end
            end

            for ii = 1:numel(testList)
                testFile = testList(ii);
                valid(ii) = OI.Test.valid_test_file( testFile );
                ii = ii + 1;
            end
            testList(~valid) = [];

            % convert to cell array of strings
            testList = {testList.name};
        end

        
        % check a given file has "_tests.m" at end indicating its a test file
        function tf = valid_test_name( str )
            %check number of chars
            expected = OI.Test.SUFFIX;
            nExpect = numel(expected);

            % check we have enough chars then compare to '_TEST'.
            tf = ( numel(str) > nExpect )  && ...
                ( strcmpi(str(end-nExpect+1:end),expected) );
            % also return valid if we've left the .m on for whatever reason
            tf = tf || ...
                ( numel(str) > nExpect + 2)  && ...
                strcmpi(str(end-1:end),'.m') && ...
                ( strcmpi(str(end-nExpect+-1:end-2),expected) );
        end

        function tf = valid_test_file( testFile )
            tf = false;
            isFile = ~testFile.isdir;
            % ensure valid test file via its name
            if isFile && OI.Test.valid_test_name(testFile.name)
                tf = true;
            end
        end
    end

end