function A = mask0s( A, tol )
% Set zero values in array A to nan
if nargin == 1
    A=double(A);
    A(isnan(A))=0;
    A(A==0) = nan;
    return
end

if nargin == 2
    A(A < tol) = nan;
end

end

