classdef SubsetMask < OI.Data.DataObj
    properties
        Mask
        height
        width
        polygon
    end
    
    methods
        function obj = SubsetMask(mask)
            % take a binary mask, and convert it to polygon
            % mask is a binary image

            obj.Mask = mask;

            [obj.height, obj.width] = size(mask);

            % convert to polygon
            boundaryPix = bwboundaries(mask);
            vertexInds = convhull(boundaryPix(:,1),boundaryPix(:,2),'Simplify',true);
            obj.polygon = boundaryPix(vertexInds,:);
        end
    end

end