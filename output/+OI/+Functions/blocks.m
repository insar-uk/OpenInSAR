function [blockStruct, blockArray, blockMap, blockAz, blockRg]= blocks(swathInfo, minimumBlockAxis )
    azMeters = swathInfo.azSpacing;
    rgMeters = swathInfo.rgSpacing;
    lpb = swathInfo.linesPerBurst;
    spb = swathInfo.samplesPerBurst;
    distanceAz = (1:lpb) * azMeters;
    distanceRg = (1:spb) * rgMeters ./ sind( swathInfo.incidenceAngle );
    % do rg
    nBlocksAz = 1;
    nBlocksRg = 1;
    while true
        % increase the bkock size until it is less than the minimum
        if (distanceAz(end)-distanceAz(1))/nBlocksAz > minimumBlockAxis
            nBlocksAz = nBlocksAz + 1;
            continue
        end
        if (distanceRg(end)-distanceRg(1))/nBlocksRg > minimumBlockAxis
            nBlocksRg = nBlocksRg + 1;
            continue
        end
        break;
    end
    nBlocks = nBlocksAz * nBlocksRg;

    % now we have the number of blocks in each direction
    % output the block structures
    % these detail the start and end of each block 
    % in terms of rg and az
    blockStruct = struct( ...
        'rgStart', [], ...
        'rgEnd', [], ...
        'azStart', [], ...
        'azEnd', [] ...
        );
    % Preallocate the block array
    blockArray = zeros(nBlocksAz, 4);

    % Preallocate the block map
    blockMap = zeros(lpb, spb);
    % blockInds = cell(1, nBlocks);
    [blockAz, blockRg] = deal(cell(1,nBlocks));

    % split the axes into blocks
    azBlockStarts = floor(linspace(1, lpb, nBlocksAz+1));
    azBlockEnds = azBlockStarts(2:end) - 1;
    azBlockStarts(end) = [];
    rgBlockStarts = floor(linspace(1, spb, nBlocksRg+1));
    rgBlockEnds = rgBlockStarts(2:end) - 1;
    rgBlockStarts(end) = [];

    % Fill the block map
    for ai = 1:nBlocksAz
    for ri = 1:nBlocksRg
        blockIndex = (ai-1)*nBlocksRg + ri;
        blockStruct(blockIndex).rgStart = rgBlockStarts(ri);
        blockStruct(blockIndex).rgEnd = rgBlockEnds(ri);
        blockStruct(blockIndex).azStart = azBlockStarts(ai);
        blockStruct(blockIndex).azEnd = azBlockEnds(ai);

        blockArray(blockIndex, :) = [rgBlockStarts(ri), rgBlockEnds(ri), azBlockStarts(ai), azBlockEnds(ai)];

        blockMap(azBlockStarts(ai):azBlockEnds(ai), ...
            rgBlockStarts(ri):rgBlockEnds(ri)) = blockIndex;
        blockAz{blockIndex} =  azBlockStarts(ai):azBlockEnds;
        blockRg{blockIndex} =  rgBlockStarts(ai):rgBlockEnds;

    end
    end



end
