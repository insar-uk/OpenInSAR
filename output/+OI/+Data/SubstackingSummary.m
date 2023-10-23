classdef SubstackingSummary < OI.Data.DataObj
    properties
        generator = 'Substacking'
        id = 'SubstackingSummary'
        STACK = ''
        REFERENCE_SEGMENT_INDEX = ''
        blocks = []
        timeTaken = 0
        blockCount = 0
        blockSize = 0
        visitCount = 0
        swathInfo = []
        safe = []
    end % properties

    methods
        function this = SubstackingSummary( varargin )
            this.hasFile = false;
            this.isUniqueName = false;
        end
    end % methods

    methods (Static = true)
       
    end % methods (Static = true)

end % classdef