function doppler = doppler_eq(pXYZ,vXYZ,gXYZ)
    % sensing distance
    s2g = pXYZ-gXYZ;
    % convert to unit vector (direction)
    % s2g = s2g ./ sqrt(sum(s2g.^2,2));
    % elementwise because p and v are nDimensional but correspond to eachother
    doppler =  sum(s2g .* vXYZ,2);
    