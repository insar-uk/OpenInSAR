classdef Stacking < OI.Plugins.PluginBase
%STACKING Summary of this class goes here
%   Detailed explanation goes here

properties
    inputs = {OI.Data.Catalogue(), OI.Data.PreprocessedFiles()}
    outputs = {OI.Data.Stacks()}
    id = 'Stacking'
end

methods
    function this = run( this, engine, varargin )
        
        cat = engine.load( OI.Data.Catalogue() );
        preprocessingInfo = engine.load( OI.Data.PreprocessedFiles() );
        % check inputs are available
        if  isempty(cat) || isempty(preprocessingInfo)
            return
        end


        % group the available data according to the unique visits
        [visitsForEachTrack, visitDatenums] = this.get_visits( cat );
        
        % pull the coverage values from each safe into an array
        safeCoverages = ...
            arrayfun(@(x) x.coverage, preprocessingInfo.metadata);

        % prioritise the tracks with the best coverage, these will be
        % first in an array
        [trackPriorityInd, trackCoverageByVisit] = ...
            this.get_track_priority( ...
                cat, visitsForEachTrack, safeCoverages);

        % force the second track to be opposing look dir if possible
        if numel( trackPriorityInd ) > 1
            trackPriorityInd = OI.Plugins.Stacking.prioritise_opposing_look( ...
                trackPriorityInd, cat, visitsForEachTrack);
        end        

        
        % choose the best date in the best track as reference
        % loop thru tracks
        
        for referenceTrackInd = trackPriorityInd
                
            bestVisitScore = max(trackCoverageByVisit{referenceTrackInd});
            bestVisits = find( bestVisitScore == ...
                trackCoverageByVisit{referenceTrackInd} );
            % get the datenums of the best visits
            bestVisitsDatenums = ...
                visitDatenums{referenceTrackInd}(bestVisits);
            % choose the visit closest to the mean
            [~, bestVisitOutOfThese] = min(abs( ...
                bestVisitsDatenums - mean(bestVisitsDatenums) ));
            bestVisit = bestVisits( bestVisitOutOfThese );


            % get the reference data
            reference = struct();
            reference.track = cat.trackNumbers(referenceTrackInd);
            reference.date = ...
                OI.Data.Datetime( visitDatenums{referenceTrackInd}(bestVisit) );
            reference.safeInds = ...
                visitsForEachTrack{referenceTrackInd}{bestVisit};
            reference.safeMeta = ...
                preprocessingInfo.metadata(reference.safeInds(1));

            % get all the useful data segments/bursts in this reference.
            segCount = 0;
            segments = struct('index',[],'safe',[],'swath',[],'burst',[]);
            % loop through safes, swaths, bursts in this visit.
            % Starting from: earliest safe, closest swath, earliest burst
            for safeInd = reference.safeInds(:)'
                safeMeta = preprocessingInfo.metadata(safeInd);
                for swathInd = 1:numel(safeMeta.swath)
                    swath = safeMeta.swath( swathInd );
                    if swath.coverage == 0
                        continue
                    end
                    burstHasCoverage = arrayfun(@(x) ...
                        x.coverage>0 ,safeMeta.swath( swathInd ).burst);
                    burstInds = find(burstHasCoverage);
                    if isempty(burstInds)
                        continue
                    end
                    index = segCount+1:segCount+numel(burstInds);
                    segCount = segCount + numel(burstInds);
                    segments.index(index) = index;
                    segments.visit(index) = bestVisit;
                    segments.safe(index) = safeInd;
                    segments.swath(index) = swathInd;
                    segments.burst(index) = burstInds;
                end
            end
            segments.lat = zeros(segCount,4);
            segments.lon = zeros(segCount,4);
            % use the segments structure to address the bursts
            % and get the lat/lon coords
            for segInd = 1:segCount
                segments.lat(segInd,:) = ...
                    preprocessingInfo.metadata( ...
                        segments.safe(segInd) ).swath( ...
                        segments.swath(segInd) ).burst( ...
                        segments.burst(segInd) ).lat;
                segments.lon(segInd,:) = ...
                    preprocessingInfo.metadata( ...
                        segments.safe(segInd) ).swath( ...
                        segments.swath(segInd) ).burst( ...
                        segments.burst(segInd) ).lon;
            end
            reference.segments = segments;

            stack = struct();
            stack.track = reference.track;
            stack.reference = reference;
            stack.segments = segments;
            
            % loop through all the visits for this track
            theseVisits = visitsForEachTrack{referenceTrackInd};
            % match any bursts/segments which have near identical lat/lon
            stack.correspondence = zeros(segCount, numel(theseVisits));
            stack.correspondence(:,bestVisit) = segments.index;

            refLat = reference.segments.lat(:,1);
            refLon = reference.segments.lon(:,1);
            for visitInd = 1:numel(theseVisits)
                if visitInd == bestVisit
                    continue % done already
                end
                visitSafes = theseVisits{visitInd};
                for safeInd = visitSafes(:)'
                    safeMeta = preprocessingInfo.metadata(safeInd);
                    for swathInd = 1:numel(safeMeta.swath)
                        swath = safeMeta.swath( swathInd );
                        if swath.coverage == 0
                            continue
                        end
                        burstHasCoverage = arrayfun(@(x) ...
                            x.coverage>0 ,safeMeta.swath( swathInd ).burst);
                        burstInds = find(burstHasCoverage);
                        if isempty(burstInds)
                            continue
                        end
                        % loop through the bursts in this swath
                        for burstInd = burstInds
                            % get the lat/lon coords for this burst
                            burstLat = safeMeta.swath( ...
                                swathInd ).burst( burstInd ).lat;
                            burstLon = safeMeta.swath( ...
                                swathInd ).burst( burstInd ).lon;
                            % find the segments with near identical coords
                            % (within 1e-4 degrees)
                            distance = sum(( 1.11e5 .* (...
                                [refLat refLon] - ...
                                [burstLat(1) burstLon(1)] )).^2,2).^.5;

                            [minDist, refSegInd] = min(distance);
                            % disp(distance'./1e3)
                            if minDist > 5e3 % anything more than this is
                                % another segment
                                continue
                            end
                            % This segment corresponds to one in the reference
                            % so add it to the list of segments
                            segCount = segCount + 1;
                            stack.segments.index(segCount) = segCount;
                            stack.segments.visit(segCount) = visitInd;
                            stack.segments.safe(segCount) = safeInd;
                            stack.segments.swath(segCount) = swathInd;
                            stack.segments.burst(segCount) = burstInd;
                            stack.segments.lat(segCount,:) = burstLat;
                            stack.segments.lon(segCount,:) = burstLon;

                            % And record the geographical correspondence
                            stack.correspondence(refSegInd,visitInd) = ...
                                segCount;
                        end
                    end
                end
            end
            stack.segmentCount = segCount;
            stack.visits = theseVisits;
            % stack.cat = cat;
            
            if ~isstruct( this.outputs{1}.stack ) || ... 
                isempty( fieldnames( this.outputs{1}.stack ) ) 
                this.outputs{1}.stack = stack([],1);
            end
            this.outputs{1}.stack(referenceTrackInd) = stack;
        end
        engine.save( this.outputs{1} );

    end % function run

end % methods

methods (Static = true)

    function [trackPriorityInd, trackCoverageByVisit] = ...
            get_track_priority(cat, visitsForEachTrack, safeCoverages )
        % return the track numbers in descending order of importance.
        % so the track with the best coverage should be the first
        % element of trackPriority.
        % cat is OI.Data.Catalogue(); other vars should be defined in
        % this.

        trackCoverageByVisit = cell(1,numel(visitsForEachTrack));
        trackScore = zeros(1,numel(visitsForEachTrack));
        for trackInd = 1:numel(visitsForEachTrack)
            visitsInThisTrack = visitsForEachTrack{trackInd};
            % get the coverages for the safes in the visits
            covArray = ... 
                cellfun(@(x) sum(safeCoverages(x)), visitsInThisTrack);
            covArray = min(1,covArray);
            trackCoverageByVisit{trackInd} = covArray;
            trackScore(trackInd) = sum(covArray);
        end

        if numel(cat.trackNumbers) < 2
            % 1 or empty
            trackPriorityInd = find(cat.trackNumbers);
            return
        end

        [~,trackPriorityInd] = sort( trackScore , 'descend');

    end % function get_track_priority

    function trackPriorityInd = prioritise_opposing_look( ...
            trackPriorityInd, cat, visitsForEachTrack)
        
        firstSafeInTracks = cellfun( @(x) x{1}(1), visitsForEachTrack);
        trackDirections = cellfun(@(x) x.direction(1), ...
            cat.safes(firstSafeInTracks));
        nextOpposingTrack = ...
            find(trackDirections~=trackDirections(1),1);
        if nextOpposingTrack ~= 2
            trackPriorityInd(nextOpposingTrack) = trackPriorityInd(2);
            trackPriorityInd(2) = nextOpposingTrack;
        end
    end % function prioritise_opposing_look

    function [visits, visitDatenums] = get_visits( cat)
        % loop through tracks
        visits = cell(1,numel(cat.trackNumbers));
        visitDatenums = visits;

        for track = cat.trackNumbers(:)'
            trackInd = find(cat.trackNumbers == track,1);
            theseSafeInds = cat.catalogueIndexByTrack(:,trackInd);
            theseSafeInds = theseSafeInds(~isnan(theseSafeInds));
            
            nSafes = numel(theseSafeInds);
            safes = cat.safes(theseSafeInds);

            % loop through timings
            % anything less than 90 min (orbit time) is
            % contiguous.
            datenums = cellfun(@(x) x.date.datenum(), safes); 
            diffDatenums = abs(datenums-datenums');
            sameVisit = diffDatenums < 90/(60*24);
            
            visitIndex = 0;
            
            visited = zeros(nSafes,1);
            for ii=1:numel(visited)
                if visited(ii)
                    continue;
                end
                % else we have a new visit, increment:
                visitIndex = visitIndex + 1;
                % save the relevant safe indices
                visits{trackInd}{visitIndex} = ...
                    theseSafeInds( sameVisit(ii,:) );
                visited( sameVisit(ii,:) ) = 1;
                visitDatenums{trackInd}(visitIndex) = ...
                    mean(datenums(sameVisit(:,ii)));
            end
        end
    end % function get_visits

    function coverageScores = get_coverage_array_from_metadata( ...
            metadataForSafe, aoi )
        % returns a 2d array where each element is a coverage amount of
        % the aoi.
        % rows are swaths, columns are data segments/bursts
        % input 1 is a metadata structure
        % input 2 is a GeographicArea object for the AOI.
        nSwaths = numel(metadataForSafe.swath);
        maxBursts = max(arrayfun( @(x) numel(x.burst), ...
            metadataForSafe.swath));

        coverageScores = nan(nSwaths,maxBursts);
        estimationGridSize = [250,250];

        swaths = arrayfun(@(x) x.index, metadataForSafe.swath );
        g = OI.Data.GeographicArea();
        for swathInd = swaths
            thisSwath = metadataForSafe.swath( swathInd );
            for burstInd = 1:numel(thisSwath.burst )
                g.lat = thisSwath.burst(burstInd).lat;
                g.lon = thisSwath.burst(burstInd).lon;
                coverageScores(swathInd,burstInd) = OI.Functions.coverage( ...
                        aoi.scale(1), ...
                        g, ...
                        estimationGridSize ...
                    );
            end
        end
    end % function get_coverage_array_from_metadata

end % methods (Static = true)

end % classdef
