function I = sdscale3(I,n)

    if nargin < 2
        n=3;
    end
    for ii=1:size(I,3)
        I(:,:,ii) = OI.Functions.sdscale(I(:,:,ii),n);
    end
end

