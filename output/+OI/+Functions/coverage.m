function [coverageRatio, coverageMap, rowCoords, colCoords] = coverage(polygonA, polygonB, gridSize)
% Latitude is the first column, longitude is the second column
% This makes X = latitude, Y = longitude
% And for coverage map, rows = X, columns = Y
% 0 = no coverage, 1 = polygon A, 2 = polygon B, 3 = both

% default grid size: 100,100
if nargin < 3
    gridSize = [100 100];
else
    % if a scalar, make it a 1x2 vector
    if isscalar(gridSize)
        gridSize = [gridSize gridSize];
    end
    assert(all(size(gridSize)==[1 2]), 'gridSize must be a scalar or a 1x2 vector')
end

% if an OI.Data.GeographicArea, convert to polygon
if isa(polygonA, 'OI.Data.GeographicArea')
    polygonA = [polygonA.lat(:), polygonA.lon(:)];
end
if isa(polygonB, 'OI.Data.GeographicArea')
    polygonB = [polygonB.lat(:), polygonB.lon(:)];
end

% Get the bounding box of the polygon A
aXmin = min(polygonA(:,1));
aXmax = max(polygonA(:,1));
aYmin = min(polygonA(:,2));
aYmax = max(polygonA(:,2));

% make the grid
rowCoords = linspace(aXmin, aXmax, gridSize(1));
colCoords = linspace(aYmin, aYmax, gridSize(2));
[X, Y] = meshgrid(colCoords, rowCoords);

% determine which points are inside the polygon
inA = inpolygon(X, Y, polygonA(:,2), polygonA(:,1));
inB = inpolygon(X, Y, polygonB(:,2), polygonB(:,1))*2;

% coverage map
coverageMap = inA + inB;

% determine the coverage ratio
coverageRatio = sum(coverageMap(:)==3) / max(1,sum(inA(:)));

