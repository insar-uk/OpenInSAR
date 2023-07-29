classdef BlockMap < OI.Data.DataObj
    properties
        id = 'BlockMap'
        generator = 'BlockMapping'
        stacks = struct()
    end

    methods
        function this = BlockMap()
            this.filepath = '$WORK$/$id$';
            this.fileextension = 'mat';
            this.hasFile = true;
        end

        function block = find_closest(this, lat, lon, stackInd)
            if nargin == 3
                stackInd = 1;
            end

            latDist = arrayfun(@(x) x.meanLat-lat, ...
                this.stacks(stackInd).blocks);
            lonDist = arrayfun(@(x) x.meanLon-lon, ...
                this.stacks(stackInd).blocks);
            dist = sqrt(latDist.^2+lonDist.^2);
            [~, closestInd] = min(dist);
            block = this.stacks(stackInd).blocks(closestInd);

        end
    end

end
