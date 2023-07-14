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

            % Data from the valid rectangle will now be mapped into an
            % overall mosaic for the whole stack. We start by simply
            % finding the corresponding location in a mosaic


            % Offset of the valid data in segments, overlapping in a
            % mosaic:
            [segSize, segOff] = deal(zeros(nSegments,2));
            refValidSampOffsets = segmentMetadata(1).validSamples;
           

            getOffset = @(a,b) this.offsets_from_timing(...
                segmentMetadata(a).timing, ...
                segmentMetadata(b).timing);

            for segmentInd = 1:nSegments
                bulkOffset = round(getOffset(segmentInd,1));
                validSamples = segmentMetadata(segmentInd).validSamples;
                validOffset = [...
                    validSamples.firstAzimuthLine - ...
                    refValidSampOffsets.firstAzimuthLine, ...
                    validSamples.firstRangeSample - ...
                    refValidSampOffsets.firstRangeSample ...
                    ];
                segSize(segmentInd,:) = validSamples.size;
                segOff(segmentInd,:) = bulkOffset + validOffset;
            end
            segOff=segOff-min(segOff);
            segStarts = segOff + 1;
            segEnds = segStarts + segSize - 1;
            overlaps = segEnds(1:end-1,:)-segStarts(2:end,:);


            % % TEST
            % mosaic=zeros(max(segOff)+validSampOffsets.size);
            % for ii=1:nSegments
            %     img=load(['localimg' num2str(ii)]).img';
            %     img = min(max(log(abs(img)),3.5),5.5);
            %     vs = segmentMetadata(ii).validSamples;
            %     sz = vs.size;
            %     mosaic((1:sz(1)) + segOff(ii,1), (1:sz(2)) + segOff(ii,2)) = ...
            %         img(vs.firstAzimuthLine:vs.lastAzimuthLine, ...
            %         vs.firstRangeSample:vs.lastRangeSample);
            %     imagesc(mosaic)
            %     drawnow()
            % end
            
            stackStitchInfo = struct(...
                'segments', segmentMetadata, ...
                'reference', referenceVisit, ...
                'stitchStarts', segStarts, ...
                'stitchEnds', segEnds, ...
                'overlaps', overlaps ...
                ); 
            % Assign to structs
            this.output{1}.stack(stackInd) = stackStitchInfo;
        end

    end
end % methods

methods (Static = true)

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
    % 
    % function segmentTimingData = get_segment_timing( segmentMetadata )
    %     nSegments = numel( segmentMetadata );
    %     for segmentInd = nSegments:-1:1
    %         segmentMetadata( segmentInd ) = ...
    %             OI.Plugins.Stitching.get_one_segment_timing( segmentMetadata, segmentInd );
    %     end % segment loop
    % end
    % 
    % function segmentTimingdata = get_one_segment_timing(swathMetadata, ...
    %         burstIndexInSwath)
    % 
    %         if nargin
    % 
    %         segmentTimingdata = struct( ...
    %         'startTime', swathMetadata.burst(burstIndexInSwath).startTime, ...
    %         'slantRangeTime', swathMetadata.slantRangeTime, ...
    %         'azimuthTimeInterval', swathMetadata.azimuthTimeInterval, ...
    %         'rangeSamplingRate', swathMetadata.rangeSamplingRate ...
    %         );
    % 
    % end

    function azRgOffset = offsets_from_timing(thisSegmentMetadata, ...
            referenceSegmentMetadata )

        % assuming that 'this' swath is offset due to the size of the
        % data in the reference swath
        thisSlowTime = thisSegmentMetadata.startTime;
        thisFastTime = thisSegmentMetadata.slantRangeTime;
        referenceSlowTime = referenceSegmentMetadata.startTime;
        referenceFastTime = referenceSegmentMetadata.slantRangeTime;
        azimuthTimeInterval = referenceSegmentMetadata.azimuthTimeInterval;
        rangeSamplingRate = referenceSegmentMetadata.rangeSamplingRate;

        azRgOffset = [ ...
            (thisSlowTime - referenceSlowTime) / azimuthTimeInterval, ...
            (thisFastTime - referenceFastTime) * rangeSamplingRate ...
            ];

    end

end % methods (Static = true)

end
