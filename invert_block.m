% import OI.Functions.*

% load('P:\Substack_stack_1_polarization_VV_segment_4_block_20.mat')
d=data_;

stacks = oi.engine.load( OI.Data.Stacks() );
segmentInds = stacks.stack.correspondence(1,:);
safeInds = stacks.stack.segments.safe(segmentInds);

cat = oi.engine.load( OI.Data.Catalogue() );
datetimes = arrayfun(@(x) x.date.datenum, [cat.safes{safeInds}]);



sz=size(d);
rd=reshape(d,[],sz(3));
rmu=mean(abs(rd),2);
rsigma=var(abs(rd),0,2).^.5;
rpsc=rmu./rsigma>3;
pscphi = rd(rpsc,:);

[aps_evec, aps_eval] = eig(pscphi'*pscphi);
[~,maxEigvalIndex] = max(diag(aps_eval));
aps = aps_evec(:, maxEigvalIndex);

dnoaps = d .* reshape(aps,1,1,[]);
[C,v] = OI.Functions.invert_velocity_q(...
    reshape(dnoaps,[],sz(3)),datetimes*4*pi/(0.055),0.01,41);
C=C./sz(3);