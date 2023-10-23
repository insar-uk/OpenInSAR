classdef CoherenceMapping < OI.Plugins.PluginBase

properties
inputs = {OI.Data.BlockPsiSummary()}
outputs = {OI.Data.CoherenceMap()}
id = 'CoherenceMapping'
end

methods

function obj = run(obj,engine,~)

    blockMap = engine.load( OI.Data.BlockMap );

    % for each stack
    for stackInd = 1:numel(blockMap.stacks)
        stack = blockMap.stacks(stackInd);
        blocksInStack = stack.usefulBlockIndices;
        [~, maxAz, ~, maxRg] = blockMap.get_stack_limits(stackInd);
        blockMapArray = zeros(maxAz,maxRg);

        % for each block
        for blockInd = blocksInStack(:)'
            block = stack.blocks( blockInd );
            blockObj = OI.Data.Block().configure( ...
                'STACK',num2str( stackInd ), ...
                'POLARISATION','VV',...
                'BLOCK', num2str( blockInd ) ...
                );
            coherenceObj = OI.Data.BlockResult( blockObj, 'Coherence');
            C = engine.load( coherenceObj );
            blockMapArray( block.azOutputStart:block.azOutputEnd, ...
                            block.rgOutputStart:block.rgOutputEnd) = C;

        end % for blockInd
        1;
    end % for stackInd
    
end % CoherenceMapping

end % methods

end % classdef