classdef TestSuite
% Base class for batteries of test cases
% This class is intended to be subclassed to create a test suite.
% 
% The subclass should define a set of test cases, each of which is a method
% that returns a TestResult object.
%
% The subclass should also define a run method, which registers the test cases.
% 
% Test cases are handled by the add_case method, which takes a function handle.
% Test cases that finish will pass by default. 
% If a test case throws and error, the result will be marked as failed 
% unless the expect_error property is set to true.
% 
% Example:
% classdef MyTestSuite < TestSuite
%     methods
%         function this = MyTestSuite()
%             this = this@TestSuite();
%         end
%
%         function this = run(this)
%             this = this.add_case(@this.test_case_1);
%             this = this.add_case(@this.test_case_2);
%         end
%
%         function result = test_case_1(this)
%             % do some stuff
%             if rand() > 0.5
%                 error('example runtime error')
%             end
%             result = TestResult();
%         end

% Add a test case via:
%  > obj.case(@test_function);
% unless logic specifies otherwise, the case will run and the result will be
% stored in the results property.
properties
    results = {};
    expect_error = false;
    expected_error_message = '';
    errors = {};
end

methods
    function this = TestSuite()
    end

    function this = add_case(this, test_function, expectedError)
        % if expected error is specified
        if nargin > 2
            this.expect_error = true;
            this.expected_error_message = expectedError;
            if strcmpi(expectedError, 'any')
                this.expected_error_message = '';
            end
        else
            this.expect_error = false;
            this.expected_error_message = '';
        end

        % Run the test function
        result = OI.TestResult();
        try
            result = test_function();
            result = result.passed();
            result = this.handle_expected_error(result);
        % If the test function throws an error,
        % check if the error was expected
        catch errorObj
            errorObj = OI.Compatibility.CompatibleError(errorObj);
            result = result.failed(errorObj.message);
            result = this.handle_expected_error(result, errorObj);
            if ~result.hasPassed()
                % if the error wasn't expected, store it
                this.errors{end+1} = errorObj; % let caller decide what to do with the error
            end
        end

        % populate the results property
        % get the name of the calling function
        dbs = dbstack;
        if numel(dbs) >1
            fullpath = dbs(2).file;
            % get just the filename no extension
            [~, result.testName, ~] = fileparts(fullpath);
        end

        nameOfTestFunction = func2str(test_function);
        % remove some cruft matlab adds to the name
        nameOfTestFunction = strrep(nameOfTestFunction, '@(varargin)this.', '');
        nameOfTestFunction = strrep(nameOfTestFunction, 'varargin{:}', '');
        result.caseName = nameOfTestFunction;

        % store the result
        this.results{end+1} = result;
     end

     function result = handle_expected_error(this, result, errMsg)
        expectedErr = this.expect_error;
        gotErr = nargin > 2;

        % No error:
        if ~gotErr
            if expectedErr
                result = result.failed(sprintf('Expected error %s but got none', this.expected_error_message));
            else
                result = result.passed();
            end
            % No error, so we're done
            return;
        end

        % Error:
        if expectedErr
            result = result.passed();
        else 
            result = result.failed(sprintf('%s', errMsg.message));
            return;
        end
        
        % Check if the error message matches the expected error message
        isExpectingSpecificError = ~isempty(this.expected_error_message);
        % messageDoesntMatch = ~strcmp(this.expected_error_message, errMsg.message);
        messageDoesntMatch = ~OI.Compatibility.contains(errMsg.message, this.expected_error_message);

        if  isExpectingSpecificError && messageDoesntMatch
            result = result.failed(sprintf('Expected error message "%s" but got "%s"', this.expected_error_message, errMsg.message));
        end
     end

end

end%classdef