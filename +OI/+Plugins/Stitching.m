classdef Stitching < OI.Plugins.PluginBase
% Provide information required to stitch S1 data.
% The first segment of the reference is used to reference the rest.
properties
    inputs = {OI.Data.Stacks(), OI.Data.PreprocessedFiles()}
    outputs = {OI.Data.StitchingInformation()}
    id = 'Stitching'
end

methods
    function this = run( this, engine, varargin )


        % load inputs
        cat = engine.load( OI.Data.Catalogue() );
        stacks = engine.load( OI.Data.Stacks() );
        preprocessingInfo = engine.load( OI.Data.PreprocessedFiles() );

        % Exit if any of the inputs are empty
        if isempty(cat) || isempty(stacks) || isempty(preprocessingInfo)
            return % engine will enqueue jobs for the missing data, and requeue this job
        end

        % Loop over all stacks
        for stackInd = 1:numel(stacks.stack)



            referenceVisit = stacks.stack(stackInd).reference;
            referenceSegments = referenceVisit.segments;
            nSegments = numel(referenceSegments.burst);
            segmentMetadata = this.get_segment_metadata(cat, ...
                preprocessingInfo, referenceSegments);

            % Use the slowtime/fasttime of the segment to determine its offset wrt the first segment.
            segmentOffsets = zeros(nSegments,2);
            for i = 2:nSegments
                segmentOffsets(i,:) = this.offsets_from_timing( ...
                    segmentMetadata(i), segmentMetadata(1));
            end
            % Set the bottom left of the scene as the reference
            segmentOffsets = round(segmentOffsets - min(segmentOffsets));

            % Get the start and end positions of the segments
            segmentSizes = zeros(nSegments,2);
            for i = 1:nSegments 
                segmentSizes(i,:) = [ segmentMetadata(i).timing.linesPerBurst, ...
                    segmentMetadata(i).timing.samplesPerBurst ];
            end
            segmentStarts = segmentOffsets + 1;
            segmentEnds = segmentOffsets + segmentSizes;




            % Crop the data. Start by cropping to the valid data extent.
            segmentCropping = zeros(nSegments,4); % bottom, top, left, right
            % start az, end az, start rg, end rg
            for i = 1:nSegments
                segmentCropping(i,:) = [ ...
                    segmentMetadata(i).validSamples.firstAzimuthLine, ...
                    segmentMetadata(i).validSamples.lastAzimuthLine, ...
                    segmentMetadata(i).validSamples.firstRangeSample, ...
                    segmentMetadata(i).validSamples.lastRangeSample ...
                    ];
            end

            % Find the overlaps between segments
            overlap = cell(nSegments,nSegments);
            for i = 1:nSegments
                for j = 1:nSegments
                    overlap{i,j} = this.rectangular_overlap( ...
                        segmentStarts(i,:), segmentEnds(i,:), ...
                        segmentStarts(j,:), segmentEnds(j,:) );
                end
            end





            % Assign to structs
            this.output{1}.stack(stackInd) = stackStitchInfo;
        end

    end
end % methods

methods (Static = true)

    function overlap = rectangular_overlap( bottomLeftA, topRightA, bottomLeftB, topRightB )
        % Returns the overlap between two rectangles, or empty if there is no overlap.
        % Where each input point is a 2-element vector [x,y]

        overlap = [];
        if bottomLeftA(1) > topRightB(1) || bottomLeftB(1) > topRightA(1)
            return
        end
        if bottomLeftA(2) > topRightB(2) || bottomLeftB(2) > topRightA(2)
            return
        end

        overlap = [ ...
            max(bottomLeftA(1), bottomLeftB(1)), ...
            max(bottomLeftA(2), bottomLeftB(2)), ...
            min(topRightA(1), topRightB(1)), ...
            min(topRightA(2), topRightB(2)) ...
            ];

        % Check for negative overlap
        if overlap(1) > overlap(3) || overlap(2) > overlap(4)
            overlap = [];
        end

    end


    function segmentMetadata = get_segment_metadata(cat, preprocessingInfo, referenceSegments)
        nSegments = numel(referenceSegments.burst);
        for segmentInd = nSegments:-1:1
            % define a struct for segment information
            segmentMetadata( segmentInd ) = ...
                OI.Plugins.Stitching.get_one_segment_metadata( cat, preprocessingInfo, ...
                referenceSegments, segmentInd );
        end % segment loop
    end

    function segmentMetadata = get_one_segment_metadata(cat, preprocessingInfo, referenceSegments, ...
            segmentInd)

        % helpers
        s2n = @str2num;
        findFirst = @(x) find(x+1>0,1);
        findLast = @(x) find(x+1>0,1,'last');
        daysToSecs = 60 * 60 * 24;

        % Get the address of the segment in question
        catSafeInd = referenceSegments.safe(segmentInd);
        catSwathInd = referenceSegments.swath(segmentInd);
        catBurstInd = referenceSegments.burst(segmentInd);
        safe = cat.safes{ catSafeInd };
        address = [catSafeInd, catSwathInd, catBurstInd];

        % Pull out all the necessary metadata
        swathMetadata = ...
            preprocessingInfo.metadata(catSafeInd).swath(catSwathInd);

        % Get timing and size info 
        timing = struct( ...
            'linesPerBurst', swathMetadata.linesPerBurst, ...
            'samplesPerBurst', swathMetadata.samplesPerBurst, ...
            'rangeSamplingRate', swathMetadata.rangeSamplingRate, ...
            'azimuthTimeInterval', swathMetadata.azimuthTimeInterval, ...
            'slantRangeTime', swathMetadata.slantRangeTime, ...
            'startTime', ...
                swathMetadata.burst(address(3)).startTime * daysToSecs ...
            );

        % Find where the valid data begins.
        % four limits are enough to specify the valid data
        % S1 data is very rectangular, 
        % TODO: pull these into metadata struct earlier
        annotationPath = safe.get_annotation_path( catSwathInd );
        annotation = OI.Data.XmlFile( annotationPath ).to_struct();
        burstAnnotation = annotation.swathTiming.burstList.burst( catBurstInd );

        fvsArray = s2n(burstAnnotation.firstValidSample);
        lvsArray = s2n(burstAnnotation.lastValidSample);
        % Assign to struct
        validSamples.firstValidSampleByLine = fvsArray;
        validSamples.lastValidSampleByLine = lvsArray;
        validSamples.firstAzimuthLine = findFirst(fvsArray);
        validSamples.lastAzimuthLine = findLast(fvsArray);
        validSamples.firstRangeSample = mode(fvsArray);
        validSamples.lastRangeSample = mode(lvsArray);
        validSamples.rangeEndOffset = ...
            validSamples.lastRangeSample - ...
            timing.samplesPerBurst;
        validSamples.azimuthEndOffset = ...
            validSamples.lastAzimuthLine - ...
            timing.linesPerBurst;
        validSamples.size = ...
            [validSamples.lastAzimuthLine - ...
            validSamples.firstAzimuthLine + 1, ...
            validSamples.lastRangeSample - ...
            validSamples.firstRangeSample + 1];

        % Define the top-level output struct
        segmentMetadata = struct( ...
            'address', address, ...
            'timing', timing, ...
            'validSamples', validSamples ... % 'absolutePosition', struct() 
            );
    end


    function azRgOffset = offsets_from_timing(thisSegmentMetadata, ...
            referenceSegmentMetadata )

        % assuming that 'this' swath is offset due to the size of the
        % data in the reference swath
        thisSlowTime = thisSegmentMetadata.timing.startTime;
        thisFastTime = thisSegmentMetadata.timing.slantRangeTime;
        referenceSlowTime = referenceSegmentMetadata.timing.startTime;
        referenceFastTime = referenceSegmentMetadata.timing.slantRangeTime;
        azimuthTimeInterval = referenceSegmentMetadata.timing.azimuthTimeInterval;
        rangeSamplingRate = referenceSegmentMetadata.timing.rangeSamplingRate;

        azRgOffset = [ ...
            (thisSlowTime - referenceSlowTime) / azimuthTimeInterval, ...
            (thisFastTime - referenceFastTime) * rangeSamplingRate ...
            ];

    end

    function visualise_stitching( segmentStarts, segmentSizes, overlap )
        % Visualise the stitching information
        nSegments = size(segmentStarts,1);
        % assign a unique color to each segment
        colors = hsv(nSegments);
        
        % Plot the segment positions
        figure(1); clf; hold on
        for i = 1:nSegments
            rectangle('Position', [segmentStarts(i,:), segmentSizes(i,:)], ...
                'EdgeColor', colors(i,:), 'LineWidth', 2);
        end
        grid minor; title('Segment positions');
        % get the extents of the figure
        xlims = xlim(); ylims = ylim();
       
        % Plot the overlaps
        figure(2); clf; hold on
        for i = 1:nSegments
            for j = i+1:nSegments
                if ~isempty(overlap{i,j})
                    % convert the overlap cell [bottomLeftX, bottomLeftY, topRightX, topRightY] into rectangle format [x y w h]
                    overlapXYWH = [overlap{i,j}(1:2), overlap{i,j}(3:4) - overlap{i,j}(1:2)];
                    rectangle('Position', overlapXYWH, ...
                        'EdgeColor', colors(i,:), 'LineWidth', 2);
                end
            end 
        end
        title('Segment overlaps'); xlim(xlims); ylim(ylims); grid minor;
        
    end

end % methods (Static = true)

end
