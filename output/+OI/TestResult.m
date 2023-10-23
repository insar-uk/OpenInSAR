classdef TestResult

    properties
        testName = ''
        caseName = ''
    end

    properties (SetAccess = private)
        status = 'FAILED'
        message = ''
        isPassed = false;
        errorObj = [];
    end

    methods
        function this = TestResult( testHandle, status, message, errorObj )
            % TestResult constructor
            % test: function handle
            % status: string
            % message: string
            if nargin < 3
                return
            end
            this.testName = testHandle;
            this.status = status;
            this.message = message;
            if nargin == 4
                this.errorObj = errorObj;
            end
        end

        function this = passed( this )
            % Set the status to passed
            this.status = 'OK';
            this.isPassed = true;
            this.message = '';
        end

        function this = failed( this, message )
            % Set the status to failed
            this.status = 'FAILED';
            this.message = message;
            this.isPassed = false;
        end

        function tf = hasPassed( this )
            % Return true if the test has passed
            tf = this.isPassed;
        end

        function summary = get_summary( this )
            summary = sprintf('%s - %s : %s %s\n', ...
                this.testName, this.caseName, this.status, this.message);
        end
    end



end%classdef