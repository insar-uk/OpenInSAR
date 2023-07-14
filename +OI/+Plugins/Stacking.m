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
                trackPriorityInd = prioritise_opposite_look( ...
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

            % get all the useful data segments/bursts in this reference.
            segCount = 0;
            segments = struct('index',[],'safe',[],'swath',[],'burst',[]);
            % loop through safes, swaths, bursts in this visit.
            % Starting from: earliest safe, closest swath, earliest burst
            for safeInd = reference.safeInds
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
                            disp(distance'./1e3)
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
            stack.cat = cat;
           
            if ~isstruct( this.outputs{1}.stack ) || ... 
               isempty( fieldnames( this.outputs{1}.stack ) ) 
                this.outputs{1}.stack = stack;
            else
                this.outputs{1}.stack(referenceTrackInd) = stack;
            end
        end
            engine.save( this.outputs{1} );

            %  assign

            % Start an array of info.
            % and find the corresponding bursts in the others.

            


            % coverage is now handled in FilePreprocessing
            % % get the coverage
            % %   for each data segment (burst)
            % %   in each swath
            % %   in each safe
            % %   in each visit
            % %   in each track
            % safeCoverageTotals = cell(1,numel(visitsForEachTrack));
            % for trackInd = 1:numel(visitsForEachTrack)
            %     visitsInThisTrack = visitsForEachTrack{trackInd};
            %     safeCoverageTotals{trackInd} = zeros( 1, ...
            %         visitsInThisTrack );
            %     for visitInd = 1:numel(visitsInThisTrack)
            %         visitSafes = visitsInThisTrack{visitInd};
            %         for safeInd = visit{1}
            %             safe = cat.safes{safeInd};
            %             meta = preprocessingInfo.metadata( safeInd );
            %             coverage = ...
            %                 this.get_coverage_array_from_metadata( meta, aoi );
            %         end
            %     end
            % end

                % coverageScores = this.get_coverage_scores( coords, aoi );
            % end
            % use this to determine the best track
            % trackPriority = this.get_track_priority( cat, coverageScores );
            % group available data into unique visits 
            % (e.g. if multiple .SAFE files for the AOI are consecutive, group)
            % visits = this.get_visits( cat, trackPriority );
        end

        % 
        % function coverageScores = get_coverage_scores( coords, aoi )
        % 
        %     coverageScores = struct();
        %     estimationGridSize = [250,250];
        % 
        %     for catalogueInd = numel(coords.coordinates):-1:1
        %         theseCoords = coords.coordinates( catalogueInd );
        %         swaths = arrayfun(@(x) x.index, theseCoords.swath );
        %         for swathInd = swaths
        %             thisSwath = theseCoords.swath( swathInd );
        %             for burstInd = 1:numel(thisSwath.burst )
        %                 g.lat = thisSwath.burst(bInd).lat;
        %                 g.lon = thisSwath.burst(bInd).lon;
        %                 coverageScores(catalogueInd,swathInd,burstInd).value = OI.Functions.coverage( ...
        %                         aoi.scale(1), ...
        %                         g, ...
        %                         estimationGridSize ...
        %                     );
        %             end
        %         end
        %     end
        % 
        % end
        % 
        % function trackPriority = get_track_priority( cat, coverageScores )
        % 
        % 
        %     % get the best catalogue entry
        %     for catalogueInd = numel(coords.coordinates):-1:1
        %         thisCatsScores = arrayfun(@(x) x.cInd == cInd, score);
        %         cScore(cInd) = sum(scoreVals(thisCatsScores));
        %     end
        % 
        %     % get the best track
        %     trackMatrix = cat.trackNumbersBySafe(:) == cat.trackNumbers(:)';
        %     trackScoreBySafe = zeros(numel(theseSafeInds), size(trackMatrix,2));
        % 
        %     % each column is a unique track, the bool indicates a matching row
        %     for trackInd = size(trackMatrix,2):-1:1
        %         theseSafeInds = trackMatrix(:,trackInd);
        %         trackScoreBySafe(theseSafeInds,trackInd) = cScore(theseSafeInds);
        %     end
        %     nInTrack = sum(trackScoreBySafe>0);
        %     meanInTrack = sum(trackScoreBySafe)./nInTrack;
        %     trackScore = sum(trackScoreBySafe).*(0.1+(nInTrack>1));
        % 
        %     [~, sortedInd] = sort(trackScore);
        %     trackPriority = fliplr(cat.trackNumbers(sortedInd));
        % 
        %     % Hack to make the second priotity track the opposite look
        %     for tInd = numel(cat.trackNumbers):-1:1
        %         % get the index for a safe in the track
        %         thisTrackInd = find(cat.trackNumbersBySafe == trackPriority(tInd),1);
        %         manStr = cat.safes{ thisTrackInd }.get_manifest();
        %         pass = regexp( manStr, ['<s1:pass>(.*)</s1:pass>'],'match');
        %         trackDir(tInd) = pass{1}(10);
        %     end       
        %     % find the first track with different direction to the best one:
        %     nextTrack = find(trackDir~=trackDir(1),1);
        %     if nextTrack ~= 2
        %         wasSecond = trackPriority(2);
        %         trackPriority(2) = trackPriority(nextTrack);
        %         trackPriority(nextTrack) = wasSecond;
        %     end
        % end
        % 
    end

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
            % 
            [~,trackPriorityInd] = sort( trackScore , 'descend');
            
            % trackPriority = fliplr(cat.trackNumbers(trackPriorityInd));
            % 
            % 
            % % Hack to make the second priority track the opposite look
            % for tInd = numel(cat.trackNumbers):-1:1
            %     % get the index for a safe in the track
            %     thisTrackInd = find(cat.trackNumbersBySafe == trackPriority(tInd),1);
            %     manStr = cat.safes{ thisTrackInd }.get_manifest();
            %     pass = regexp( manStr, ['<s1:pass>(.*)</s1:pass>'],'match');
            %     trackDir(tInd) = pass{1}(10);
            % end       
            % % find the first track with different direction to the best one:
            % nextTrack = find(trackDir~=trackDir(1),1);
            % if nextTrack ~= 2
            %     wasSecond = trackPriority(2);
            %     wasSecondInd = trackPriorityInd(2);
            % 
            %     trackPriority(2) = trackPriority(nextTrack);
            % 
            % 
            %     trackPriority(nextTrack) = wasSecond;
            % 
            % end
        end

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
        end

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



        end
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

        end
    end
end


% projObj = engine.load( OI.Data.ProjectDefinition() );
% cat = engine.load( OI.Data.Catalogue() );
% coords = engine.load( OI.Data.S1SafeCoordinateArray() );

% % find a reference scene
% score = struct();

% aoi = projObj.AOI.to_area();

% estimationGridSize = [250,250];
% g = OI.Data.GeographicArea();

% engine.ui.log('info','getting coverages\n');
% dookCount=0;

% bigBurstStruct = struct();
% bigBurstLatArray = zeros( ...
%     numel(coords.coordinates), ...
%     3, ...
%     12 ...
%    );
% bigBurstLonArray = bigBurstLatArray;

% for cInd = numel(coords.coordinates):-1:1
%     theseCoords = coords.coordinates( cInd );
%     swaths = arrayfun(@(x) x.index, theseCoords.swath );
    
%     for swInd = swaths
%         thisSwath = theseCoords.swath( swInd );
%         for bInd = 1:numel(thisSwath.burst )
%             g.lat = thisSwath.burst(bInd).lat;
%             g.lon = thisSwath.burst(bInd).lon;
            
%             % bigBurstStruct(cInd,swInd,bInd).lat = g.lat;
%             % bigBurstStruct(cInd,swInd,bInd).lon = g.lon;

%             dookCount = dookCount + 1;
%             score( dookCount ).cInd = cInd;
%             score( dookCount ).swInd = swInd;
%             score( dookCount ).bInd = bInd;
%             score( dookCount ).value = OI.Functions.coverage( ...
%                     aoi.scale(1), ...
%                     g, ...
%                     estimationGridSize ...
%                 );

%             bigBurstLatArray(cInd,swInd,bInd) = mean(g.lat);
%             bigBurstLonArray(cInd,swInd,bInd) = mean(g.lon);
%             bigBurstCoverageArray(cInd,swInd,bInd) = ...
%                 score(dookCount).value;
%         end
%     end
% end

% engine.ui.log('info','getting scores\n');

% % extract just scores
% scoreVals = arrayfun(@(x) x.value,score);
% % get the best catalogue entry
% for cInd = numel(coords.coordinates):-1:1
%     thisCatsScores = arrayfun(@(x) x.cInd == cInd, score);
%     cScore(cInd) = sum(scoreVals(thisCatsScores));
% end

% % get the best track
% trackMatrix = cat.trackNumbersBySafe(:) == cat.trackNumbers(:)';
% trackScoreBySafe = zeros(numel(theseSafeInds), size(trackMatrix,2));

% % each column is a unique track, the bool indicates a matching row
% for trackInd = size(trackMatrix,2):-1:1
%     theseSafeInds = trackMatrix(:,trackInd);
%     trackScoreBySafe(theseSafeInds,trackInd) = cScore(theseSafeInds);
% end
% nInTrack = sum(trackScoreBySafe>0);
% meanInTrack = sum(trackScoreBySafe)./nInTrack;
% trackScore = sum(trackScoreBySafe).*(0.1+(nInTrack>1));

% [~, sortedInd] = sort(trackScore);
% trackPriority = fliplr(cat.trackNumbers(sortedInd));
% % make the second priotity track the opposite look
% for tInd = numel(cat.trackNumbers):-1:1
%     % get the index for a safe in the track
%     thisTrackInd = find(cat.trackNumbersBySafe == trackPriority(tInd),1);
%     manStr = cat.safes{ thisTrackInd }.get_manifest();
%     pass = regexp( manStr, ['<s1:pass>(.*)</s1:pass>'],'match');
%     trackDir(tInd) = pass{1}(10);
% end

% % find the first track with different direction to the best one:
% nextTrack = find(trackDir~=trackDir(1),1);
% if nextTrack ~= 2
%     wasSecond = trackPriority(2);
%     trackPriority(2) = trackPriority(nextTrack);
%     trackPriority(nextTrack) = wasSecond;
% end

% % Get the safes for the best track
% safesInBestTrackBool =  cat.trackNumbersBySafe == trackPriority(1) ;
% safesInBestTrackInd = find(safesInBestTrackBool);
% safesInBestTrack = cat.safes(safesInBestTrackInd);

% % get the dates for these
% datenums = cellfun(@(x) x.date.datenum(), safesInBestTrack);
% % reference date is this:
% deltaDate = datenums-datenums';
% [~, bestDate] = max(-mean(abs(deltaDate)))

% % get the best burst in this safe
% bestSafeInd = safesInBestTrackInd(bestDate);
% bestSafeScores = score(arrayfun(@(x) x.cInd == bestSafeInd, score));
% [~,bestBurstInd] = max(arrayfun(@(x) x.value,bestSafeScores));
% bestBurst = bestSafeScores(bestBurstInd);

% % save this info for reference
% reference.track = trackPriority(1);
% reference.safeInd = bestSafeInd;
% reference.swathInd =  bestBurst.swInd;
% reference.burstInd = bestBurst.bInd;
% reference.filepath = cat.safes{bestSafeInd}.filepath;
% reference.name = cat.safes{bestSafeInd}.name;
% reference.date = cat.safes{bestSafeInd}.date;
% reference.lat = ...
%     bigBurstLatArray(bestBurst.cInd,bestBurst.swInd,bestBurst.bInd);
% reference.lon = ...
%     bigBurstLonArray(bestBurst.cInd,bestBurst.swInd,bestBurst.bInd);

% % group 
% distance = 1e5.*( (bigBurstLonArray-bestBurstLL(2)).^2 + ...
%             (bigBurstLonArray-bestBurstLL(2)).^2 ).^.5;

% % for all of the bursts in this safe, pull out their position
% % bigBurstLatArray(bigBurstLatArray==0)=nan;
% bestSafeLats = bigBurstLatArray(bestSafe,:,:);
% bestSafeLons = bigBurstLonArray(bestSafe,:,:);

% rshp = @(x) x(:);
% % bestSafeCoverages = bigBurstCoverageArray(bestSafe,:,:);
% % usefulBurstMap = bestSafeCoverages>0;

% % get a list of safes with useful coverage
% % and then hence a list of useful safes and capture dates
% for safeInd = safesInBestTrackInd(:)'
%     hasUsefulCoverage(safeInd) = ...
%         any( rshp( bigBurstCoverageArray(safeInd,:,:) ) > 0 );
% end
% nUsefulSafes = sum(hasUsefulCoverage);
% for usefulSafeInds = rshp(find(hasUsefulCoverage))'

% end

% if hasUsefulCoverage
%     usefulSafesInBestTrack

% % start an array of all the useful bursts
% % referenceBursts = [bestSafe]

% % dataCollection = OI.Data.SarDataCollection();
% dataCollection = struct();

% dataCollection.trackNumbers = trackPriority;

% % for each safe, sorted by time (first first, latest last)
% burstIndex = 0;
% for safes
%     % for each swath, nearest first (same as ESA index)
%     for swathInd = 1:3
%         % for bursts, sorted by time (first first, latest last)
%         for burstInd = 1:numel(burstsInThisSwath)
%             burstIndex = burstIndex + 1;
%             dataCollection.bursts(1).index = 1;
%             dataCollection.bursts(1).safeIndex = 1;
%             dataCollection.bursts(1).swathIndex = ... % first useful swath
%     find(sum(squeeze(usefulBurstMap),2),1);


% % 
% % Start a big map of bursts, the first burst, in the first used swath of the first safe of the best burst is BURST 1.
% % from there on, the numbering proceeds accoriding to be
% % - safe timing
% % - swath numbering
% % - burst timing
% % 
% % from this array of correspondence we can coreg the individual bursts'
% % 
% % By first geocoding the references
% % 
% % then comparing the shifts to the other bursts
% % we find all the useful bursts on the same date as the bestburst

% % we then find corresponding bursts in other safes and add them to the array

% % scatter(bigBurstLonArray(:),bigBurstLatArray(:),50,sum(([bigBurstLatArray(:),bigBurstLonArray(:)]-bestBurstLL).^2,2),'filled')

% % bigBurstStruct()
% % 
% % cInd = 3
% % thisCatsScores = arrayfun(@(x) x.cInd == cInd, score);
% % thisCatS=score(thisCatsScores)
% % for ss = thisCatS
% % OO(ss.swInd,ss.bInd) = ss.value;
% % end