PROJECT_FILE = 'P:/Stew/Derna.oi';
BLOCK = 16;
STACK = 2;
DO_NPSD = true;


% ignore
this.STACK = STACK;
this.BLOCK = BLOCK;

if ~exist('firstTimeSetupComplete','var')
    oi = OpenInSAR();
    engine = oi.engine;
    engine.load_project(PROJECT_FILE)
    
    % load('P:\HAR\BlockMap.mat')
    blockMap = engine.load( OI.Data.BlockMap() );
    projObj = engine.load( OI.Data.ProjectDefinition() );

    % load('P:\HAR\stacks.mat')
    % load('P:\HAR\blocks\baseline\stack_1_block_39_baseline_information.mat')

%     load('P:\Derna\stack_1_polarisation_VV_block_47.mat')
%   blockData = data_;
    baselinesObjectTemplate = OI.Data.BlockBaseline().configure( ...
        'STACK', num2str(this.STACK), ...
        'BLOCK', num2str(this.BLOCK) ...
    ).identify( engine );
    baselinesObject = engine.load( baselinesObjectTemplate );
    
    

    

    blockObj = OI.Data.Block().configure( ...
        'POLARISATION', 'VV', ...
        'STACK',num2str( this.STACK ), ...
        'BLOCK', num2str( this.BLOCK ) ...
    ).identify( engine );
    
    blockData=oi.engine.load( blockObj);
sz = size(blockData);
    coherenceObj = OI.Data.BlockResult( blockObj, 'Coherence');


    C0 = load(coherenceObj.identify(engine));
cohMask = C0>.5;
imagesc(cohMask)

    firstTimeSetupComplete = true;
    
    amp = log(mean(abs(blockData),3));
    blockData = reshape(blockData,[],sz(3));

    ampStabObj = OI.Data.BlockResult( blockObj, 'AmplitudeStability' );
    amplitudeStability = engine.load( ampStabObj );

    blockGeocode = OI.Data.BlockGeocodedCoordinates().configure( ...
'STACK', num2str(this.STACK), ...
'BLOCK', num2str(this.BLOCK) ...
);
bg = engine.load(blockGeocode);

end


stackInd = 2
    tic
    % Get the phase, stability and location of all PSCs in the stack
    stackBlocks = blockMap.stacks( stackInd );
    blocksToDo = stackBlocks.usefulBlockIndices(:)';
    pscAz = [];
    pscRg = [];
    pscPhi = [];
    pscAS = [];
    pscBlock = [];
    missingData =[];
    
    blockCount = 1;
    blockInd = 39;

    pAzAxis = 1:sz(1);
    pRgAxis = 1:sz(2);
    [pRgGrid, pAzGrid] = meshgrid(pRgAxis,pAzAxis);
    
    MASK = cohMask(:);

    % DATA GOES HERE
    pscAz = pAzGrid(MASK);
    pscRg = pRgGrid(MASK);
    pscPhi = blockData(MASK,:);
    pscAS = amplitudeStability(MASK);
    pscBlock = blockInd.*ones(numel(pscAz),1);

    temp = sum(pscPhi);
    missingData(blockCount,:) = temp == 0 | isnan(temp);
    kFactors(blockCount,:) = baselinesObject.k(:)';
    timeSeries(blockCount,:) = baselinesObject.timeSeries(:)';

    % Save PSC locations
    % pscObj = OI.Data.PscLocations().configure( blockMap, stackIndex );
    % engine.save( pscObj, [pscAz, pscRg] );

    % normalise the phase
    normz = @(x) OI.Functions.normalise(x);
    pscPhi(:,~(sum(missingData)==0))=[];
    pscPhi = normz(pscPhi);
    pscPhi(isnan(pscPhi))=0;

    % Get a first estimate of the APS from the most stable PSC
    [maxAS maxASInd] = max(pscAS);
    aps0 = pscPhi(maxASInd,:);

    % Remove initial aps estimate from reference
    pscPhi = pscPhi .* conj(aps0);

    % Split the stack into a lower resolution grid
    maxRg = max(pscRg);
    maxAz = max(pscAz);
    minRg = min(pscRg);
    minAz = min(pscAz);

    % Determine the number of pixels in the grid
    memoryLimit = 1e8;
    bytesPerComplexDouble = 16;
    % grid point resolution in metres
    gridRes = 300;
    azSpacing = 12;
    rgSpacing = 3;

    % Determine the stride required to acheieve the desired grid resolution
    rgStride = floor(gridRes/rgSpacing);
    azStride = floor(gridRes/azSpacing);

    % The grid should encompass all PSCs and be a multiple of the stride
    maxGridRg = ceil(maxRg/rgStride)*rgStride;
    maxGridAz = ceil(maxAz/azStride)*azStride;
    minGridRg = floor(minRg/rgStride)*rgStride;
    minGridAz = floor(minAz/azStride)*azStride;

    % Define the grid
    rgGridAxis = minGridRg:rgStride:maxGridRg;
    azGridAxis = minGridAz:azStride:maxGridAz;
    [rgGrid,azGrid]=meshgrid(rgGridAxis,azGridAxis);

    % Determine the number of grid points
    nRgGrid = numel(rgGridAxis);
    nAzGrid = numel(azGridAxis);
    nGrid = nRgGrid * nAzGrid;

    % Determine the number of bytes required for a correlation matrix
    % for each grid point
    % matsize = npoints^2 * bytesPerComplexDouble
    nTraining = floor(sqrt(memoryLimit/bytesPerComplexDouble));

    % Hence determine N
    nTraining = min(nTraining,numel(pscRg));


    % for each lower resolution grid point find the nearest N PSCs
    [pscNeighbourhoodIndices, pscNeighbourhoodDistances] = ...
        deal(zeros(nGrid,nTraining));

    d2C = @(d) exp(-d./300);

    apsEst = zeros(nGrid,size(pscPhi,2));

    gridTic = tic;
    lowPass = normz(conj(movmean(pscPhi,11,2)));
    CC = abs(mean(lowPass,2));
    varEst = -2*log(CC);
    phiNoD = pscPhi.*lowPass;
    
    diagMask = diag(ones(nTraining,1))==1;
    
    for gridInd = numel(rgGrid):-1:1
        if mod(gridInd,round(numel(rgGrid)./20))==0 || gridInd == 1
            ttt=toc(gridTic);
            propdone = gridInd./numel(rgGrid);
            timeRemaining = ttt./propdone-ttt;
            fprintf('%f done, %i remaining\n',propdone,timeRemaining);
            clf
            hold on
            scatter(pscRg,pscAz,10,angle(phiNoD(:,111)),'*')
            scatter(rgGrid(:),azGrid(:),50,angle(apsEst(:,111)),'filled');
           
            drawnow()
        end
        % Calculate the distance for each PSC to the grid point
        dist = sqrt((rgGrid(gridInd)-pscRg).^2 + (azGrid(gridInd)-pscAz).^2);
        % Sort the distances
        [sortedDist,sortedInd] = sort(dist);
        % Select the N closest PSCs
        inds = sortedInd(1:nTraining);
        dists = sortedDist(1:nTraining);
        % pscNeighbourhoodIndices(gridInd,:) = inds;
        % pscNeighbourhoodDistances(gridInd,:) = sortedDist(1:nTraining);

        % calculate the distance matrix between the PSCs
        tPscAz = pscAz(inds);
        tPscRg = pscRg(inds);
        distMat = sqrt((tPscRg-tPscRg').^2 + (tPscAz-tPscAz').^2);

        % Calculate the correlation matrix
        CI = CC(inds);
        C = d2C(distMat).*sqrt(CI.*CI');
        if DO_NPSD
            C = npsd(C);
        end

        % Calculate the weights
        X = d2C(dists).*CI;
        w = C \ X;
        w = w./sum(w);

        iVals = phiNoD(inds,:);

        % Take the conjugate of the negative weights
        iVals(w<0)=conj(iVals(w<0));
        w=abs(w);

        % Calculate the weighted mean phase
        apsEst(gridInd,:) = w' * iVals;
        gridInd

    end
    
    O = nan(sz(1),sz(2));
    pscNoAps = pscPhi;
    blahs = pscNoAps;
    for ii=1:size(pscPhi,2)
        blah = interp2(rgGrid,azGrid,reshape(apsEst(:,ii),size(rgGrid,1),size(rgGrid,2),[]),pscRg,pscAz);
        blahs(:,ii) = normz(blah);
        pscNoAps(:,ii) = pscPhi(:,ii).*conj(blahs(:,ii));
        O(cohMask) = angle(pscNoAps(:,ii) .* conj(pscNoAps(:,max(1,ii-1))));
        imagesc(O)
    end

    pscNoAps = normz(pscNoAps);
    displacement = movmean(pscNoAps,11,2);
    displacement = normz(displacement);
    pscNoApsNoDisp = pscNoAps .* conj(displacement);
    [Cq,q]=OI.Functions.invert_height(pscNoApsNoDisp,kFactors(1,:));
    pscNoApsNoQ = displacement.*pscNoApsNoDisp.*exp(1i.*q.*kFactors(1,:));
    pscNoApsNoQ = normz(pscNoApsNoQ);
    [Cv,v]=OI.Functions.invert_velocity(pscNoApsNoQ,timeSeries(1,:));
    
    % NoANoQ was used for v
    % So disp - exp(1i v) is the residual
    res = displacement.*conj(displacement(:,round(mean(size(displacement,2)))));
    res = res.*conj(normz(mean(res)));

    % Remove v and unwrap
    res = res.*exp(-1i.*timeSeries.*(4*pi/(365.25.*0.055)).*v);
    res = res .* conj(normz(mean(res,2)));
    res = res.*conj(normz(mean(res)));
    uwres = unwrap(angle(res)')';
    uwres = uwres-uwres(:,1);
    uwres = uwres .* (0.055 ./ (4*pi) );

    [Cv4,v4]=OI.Functions.invert_velocity(res,timeSeries,0.01,51);
    [Cv5,v5]=OI.Functions.invert_velocity(normz(blahs),timeSeries,0.001,51);
    % 
    % ignorethese = Cv4<.5 | v4 == max(v4) | v4 == min(v4);

    datestrCells = cell(length(timeSeries),1);
    for ii = 1:length(timeSeries)
        datestrCells{ii} = datestr(timeSeries(ii),'YYYYmmDD'); %#ok<DATST>
    end

    [~,fnout,~]=fileparts(PROJECT_FILE);

    % // free some mem
    blockData = [];
    blahs = [];
    displacement = [];
    lowPass = [];
    phiNoD = [];
    pscNoAps = [];
    pscNoApsNoQ = [];
    pscNoApsNoDisp = [];
    
    fnout = [fnout '_krigged_' num2str(this.STACK) '_' num2str(this.BLOCK) '.shp'];
    OI.Functions.ps_shapefile( ...
        fnout, ...
        bg.lat(cohMask), ...
        bg.lon(cohMask), ...
        uwres, ... % displacements 2d Array
        datestrCells, ... % datestr(timeSeries(1),'YYYYMMDD')
        q, ...
        v4, ...
        Cv4);
    O(cohMask)=v;
    imagesc(O)

   