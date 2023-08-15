function [C,q,qi]=invert_height(data,KFr,oneSidedLimit,numModels,doNormalise)
% [C,q,qi]=invert_height_error(data,KFr,oneSidedLimit,numModels)
% One sided limit is estimated height error of DEM in meters

normz = @(x) x./abs(x);

if nargin<3
    oneSidedLimit=100;
end
if nargin<4
    numModels=26;
end
if nargin<5 
    doNormalise=true;
end

% Make K Factor a [1xN] array
KFr = KFr(:)';

% Get size of input data
sz=size(data);
mask1=sum(data,2)==0|sum(isnan(data),2)==sz(2);
validInds = find(~mask1)';
% Normalise if necessary
if doNormalise ...
        && ( sum(abs(data(:,1)))~=sz(1) || sum(abs(data(1,:)))~=sz(2) )
    mask0=data==0;
    data=normz(data);
    data(mask0)=0;
    data(isnan(data))=0;
    
end


% Generate periodograms
linq=linspace(-oneSidedLimit,oneSidedLimit,numModels).';
if size(KFr,1)==1
    periodogram=exp(1i.*KFr.*linq);
end
% Get size of input data
sz=size(data);

% % Normalise if necessary
% if sum(abs(data(:,1)))~=sz(1)||sum(abs(data(1,:)))~=sz(2)
%     data=normz(data);
% end

% init the answers
[C, qi]=deal(zeros(sz(1),1));
qi=qi+1;

% Find the best models
if size(KFr,1)==1
    for jj=validInds
    [C(jj), qi(jj)]=max(abs(sum(data(jj,:).*periodogram,2)));
    end
else
    for jj=validInds
    [C(jj), qi(jj)]=max(abs(sum(data(jj,:).*exp(1i.*KFr(jj,:).*linq),2)));
    end
end

% Convert from index to rate
q=linq(qi);

% Convert C to coherence
C = C./sz(2);