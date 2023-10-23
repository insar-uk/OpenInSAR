function [amplitudeStability, mu, sigma] = amplitude_stability(data, dimension)
% amplitude_stability calculates the amplitude stability of a signal
%   amplitude_stability(data) calculates mu / sigma along the last dimension
%   of data.

if nargin < 2
    dimension = ndims(data);
end

mu = mean(data, dimension);
sigma = std(data, 0, dimension);
amplitudeStability = mu ./ sigma;
end % amplitude_stability