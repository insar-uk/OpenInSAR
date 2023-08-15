classdef BlockPsiAnalysis < OI.Plugins.PluginBase
    
properties
    inputs = {OI.Data.BlockPsiSummary()}
    outputs = {OI.Data.ApsFromPsc()}
    id = 'BlockPsiAnalysis'
    STACK = []
    BLOCK = []
end

methods



    function this = run(this, engine, varargin)

        blockMap = engine.load( OI.Data.BlockMap() );


        stacksToDo = 1;
        for stackInd = stacksToDo
            tic
            stackBlocks = blockMap.stacks( stackInd );
            blocksToDo = stackBlocks.usefulBlockIndices(:)';
            pscAz = [];
            pscRg = [];
            pscPhi = [];
            pscAS = [];
            for blockInd = blocksToDo
                % Configure and load inputs
                blockObj = OI.Data.Block().configure( ...
'STACK',num2str( stackInd ), ...
'POLARISATION','VV',...
'BLOCK', num2str( blockInd ) ...
);
pscResultObj = OI.Data.BlockResult(blockObj,'InitialPsPhase');

                P = engine.load( pscResultObj );

                % append data to the arrays
                pscAz = [pscAz;P.candidateAz];
                pscRg = [pscRg;P.candidateRg];
                pscPhi = [pscPhi;P.candidatePhase];
                pscAS = [pscAS;P.candidateStability];
            end
            toc

            % Save PSC locations
            pscObj = OI.Data.PscLocations().configure( blockMap, stackIndex );
            engine.save( pscObj, [pscAz, pscRg] );

            % Get baseline k-factors
            baselineObj = OI.Data.Baseline().configure( blockMap, stackIndex );
            baseline = engine.load( baselineObj );
            kFactors = baseline.kFactors;
            timeSeries = baseline.timeSeries;

            % normalise the phase
            normz = @(x) OI.Functions.normalise(x);
            pscPhi = normz(pscPhi);

            % Get a first estimate of the APS from the most stable PSC
            [maxAS maxASInd] = max(pscAS);
            aps0 = pscPhi(maxASInd,:);

            % Remove temporally correlated phase
            pscPhi = pscPhi .* conj(aps0);
            % Use a triangular low-pass filter
            filter = triang(11);
            % Multiplication in the frequency domain is convolution in the time domain
            fFilter = fft(filter,size(res,2));
            displacements = ifft(fft(pscPhi,[],2).*fFilter(:)',[],2); % filter along time axis (by row)
            displacements = normz(displacements);
            pscPhi = pscPhi .* conj(displacements);

            % Estimate height error
            [Cq, q] = OI.Functions.invert_height(pscPhi, kFactors);
            % Remove the height error
            pscPhi = pscPhi .* exp(-1i.*q.*kFactors);

            % Any residual mean phase is representative of an offset between the overall scene (or correlated area around the main PSC), e.g. the actual APS
            % Hence add any resudual mean aps back on, weighting by coherence to minimise error from bad PSCs
            aps0 = aps0 .* mean(pscPhi.*Cq);

            % Add the aps back in
            pscPhi = pscPhi .* aps0;

            % This is now ready for use in the APS estimation
            % Save it
            apsObj = OI.Data.ApsFromPsc().configure( blockMap, stackIndex );
            engine.save( apsObj, pscPhi );

            % Each worker will now krig the individual APSs per date

            % We will iteratively improve the APS estimate by iteratively improving estimates of q and displacement.
        end

    end

end % methods


methods (Static = true)
 
end % methods (Static = true)

end % classdef