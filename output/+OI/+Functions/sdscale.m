function A=sdscale(A,n)
% centre and scale an array according to its mean and standard deviation.

v=A(:); % vectorise
% remove nan and inf
badSamples = isnan(v(:)) | isinf(v(:));
v(badSamples)=[];



% centre and scale
A = (A-mean(v)) ./ ( var(v).^.5 );
if nargin>1
%    n=3; % default scale to +/- 3 standard deviations
% end
% threshold
A(A>n)=n;
A(A<-n)=-n;
A(badSamples)=-n; % set baddies to minimum
end