function [x, y, z] = lla2xyz(lat, lon, alt)
% converts latitude, longitude, and altitude (LLA) coordinates to 
% Earth-Centered Earth-Fixed (ECEF) Cartesian coordinates (x, y, z) 
% using Helmert's formula. The input can be either an [N x 3] matrix of 
% latitude, longitude, and altitude, with the latitude and longitude values
% in degrees, or three [N x 1] columns. The output can be either an [N x 3]
% matrix or three [N x 1] columns, with the ECEF coordinates in meters.

R0 = 6378137; %semi-major axis
eccentricity = 8.1819190842622e-2; % eccentricity

% expand args and convert to rads
if nargin == 3
    lat = lat * 2 * pi / 360;
    lon = lon * 2 * pi / 360;
elseif nargin == 1
    lon = lat(:,2) * 2 * pi / 360;
    alt = lat(:,3);
    % has to be last to avoid overwriting!
    lat = lat(:,1) * 2 * pi / 360;
end

ellipsoidHeight = R0 ./ sqrt(1 - eccentricity^2 * sin(lat) .^2 ) ;

if nargout == 3
    x = (ellipsoidHeight + alt) .*  cos(lat) .* cos(lon);
    y = (ellipsoidHeight + alt) .*  cos(lat) .* sin(lon);
    z = ( (1 - eccentricity^2) .* ellipsoidHeight + alt) .* sin(lat);
elseif nargout == 1
    x(:,1) = (ellipsoidHeight + alt) .*  cos(lat) .* cos(lon);
    x(:,2) = (ellipsoidHeight + alt) .*  cos(lat) .* sin(lon);
    x(:,3) = ( (1 - eccentricity^2) .* ellipsoidHeight + alt) .* sin(lat);
end
% 
% e2 = f * (2 - f);
% N  = a ./ sqrt(1 - e2 * sinphi.^2);
% rho = (N + h) .* cosphi;
% z = (N*(1 - e2) + h) .* sinphi;