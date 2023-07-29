function [C,v]=invert_velocity_q(data,phasePerMeterVsTime,oneSidedLimit,numModels)
% One sided limit is deformation rate in meters per annum.

if nargin<3
    oneSidedLimit=0.03;
end
if nargin<4
    numModels=26;
end

% Generate periodograms
linv=(linspace(-sqrt(oneSidedLimit),sqrt(oneSidedLimit),numModels).^2).';
linv=linv.*sign(linspace(-sqrt(oneSidedLimit),sqrt(oneSidedLimit),numModels))';

periodogram=exp(1i.*phasePerMeterVsTime.*linv);

% Get size of input data
sz=size(data);

% Normalise if necessary
if sum(abs(data(:,1)))~=sz(1)||sum(abs(data(1,:)))~=sz(2)
    mask0=data==0;
    data=OI.Functions.normalise(data);
    data(mask0)=0;
    data(isnan(data))=0;
end

% init the answers
[C, vi]=deal(zeros(sz(1),1));

% Find the best models
for jj=1:sz(1)
[C(jj), vi(jj)]=max(abs(sum((data(jj,:).*periodogram),2)));
end

% Convert from index to rate
v=linv(vi);
% Convert C to coherence
C = C./sz(2);
