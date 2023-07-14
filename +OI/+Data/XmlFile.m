classdef XmlFile < OI.Data.DataObj


properties
    numberOfElements = 0;
    rawXml = "";

    numberOfCharacters

    eleHeaderStarts = []
    eleHeaderEnds = []
    eleIsEmpty = OI.Data.BoolArray([])
    eleIsInstruction = OI.Data.BoolArray([])

    tagStarts = []
    tagEnds = []
    tagLengths = []
    maxTagLength = []

    atrStarts = []
    atrEnds = []
    contStarts = []
    contEnds = []
    valStarts = []
    valEnds = []

    parentElement = []
    childElement = []
    siblingElement = []

    rawXmlLevel
    elementLevels
    elementClosers
    elementOpeners
end

methods
    function this = XmlFile( inputArgument )
        this.hasFile = 1;
        this.isUniqueName = 1;
        this.fileextension = 'xml';


        switch class( inputArgument )
            % Can be either Xml string or a filepath.
            case {'char', 'string'}
                if inputArgument(1)=='<' %all xml starts with a <?
                    this.rawXml = inputArgument;
                else
                    this.filepath = inputArgument;

                    % if the file extension is not xml, change it.
                    [~,~,ext] = fileparts(this.filepath);
                    if ~isempty(ext) && ~strcmpi(ext, this.fileextension)
                        this.fileextension = ext(2:end);
                    end
                    % this.fileextension
                    this.rawXml = this.load();
                end
            % can be a file object
            case {"OI_TextFile", "OI_XmlFile"}
                this.rawXml = inputArgument.load();
        end

        % Strip out any comments
        this.rawXml = this.strip_comments( this.rawXml );

        % General info
        this.numberOfCharacters = numel( this.rawXml );
        % Find where elements start and end
        this = this.find_markup();
        % Use the <,>,/,? characters to work out distance from the root node:
        this.rawXmlLevel = this.get_content_heirarchy( ...
                            this.rawXml, ...
                            this.maxTagLength ...
        );
        this.rawXmlLevel = this.get_content_depth();
        this.elementLevels = this.rawXmlLevel( this.eleHeaderStarts );
%

        % Get the content of each element and their values
        this = this.get_content();
        % Work out who's who in the family tree
        this = this.get_tree();
    end

    function this = get_content(this)
        % Set some defaults so our stuff is the right size.
        [this.valStarts,this.valEnds,this.contStarts, this.contEnds] = ...
            deal(zeros(1,this.numberOfElements));
        % The element contents starts after the tag and attributes:
        this.contStarts = this.atrEnds + 2 + (1*this.eleIsEmpty.mask()); % +1 for empties
        % Empty elements are easy as they have no content.
        this.contEnds(this.eleIsEmpty.mask()) = this.contStarts(this.eleIsEmpty.mask());% + tagLengths(eleIsEmpty);


        % Find where content finishes:
        % Find the '<' character which closes content at each level.
        charOffsets = 1:this.numberOfCharacters;
        closerCharOffsets = charOffsets(this.elementClosers);
        closerCharLevel = this.rawXmlLevel(closerCharOffsets);
        elementsWithContent = find(~this.eleIsEmpty.mask());
        r= this.rawXml;
        for ii = elementsWithContent
            %if eleIsEmpty(ii), continue; end
            myStart = this.eleHeaderStarts(ii);
            myDepth = this.elementLevels(ii);
            % Check all the arrows. Our closer is after us and at our level.
            isAfterMe = closerCharOffsets > myStart;
            isRightLevel = closerCharLevel == myDepth;
            myCloserIndex = find(isRightLevel & isAfterMe,1);
            this.contEnds(ii) = closerCharOffsets( myCloserIndex ) - 1;
            %-1 to include arrow.
        end

        % Get the values. Ignore all enclosing whitespace (this is an xml rule).
        for ii = elementsWithContent
            % get the pointers to out content
            myContentInds = this.contStarts(ii):this.contEnds(ii);
            % filter content outside our level (e.g. ignore child elements)
            myDepth = this.elementLevels(ii);
            myContentDepth = this.rawXmlLevel( ...
                this.contStarts(ii):this.contEnds(ii) ...
            );
            myContentInds = myContentInds(myContentDepth == myDepth);
            % ignore space and other nonsense (Anything less than !)
            % see ascii table.
            myContentInds(this.rawXml(myContentInds)<uint8('!')) = [];

%            % skip elements without content
            if isempty(myContentInds), continue; end
            % Start of non-space content to end of non-space content:
            this.valStarts(ii) = myContentInds(1);
            this.valEnds(ii) = myContentInds(end);
        end
    end

    function this = get_tree(this)
        % assign some zeros to stop array growth, OOR errors etc.
        [ this.parentElement, this.childElement, this.siblingElement ] = ...
            deal( zeros(this.numberOfElements,1) );

        % get the children, assign me as parent.
        for ii = 1:numel(this.eleHeaderStarts)
            myContStart = this.contStarts(ii);
            myContEnd = this.contEnds(ii);
            isMyDescendent = this.eleHeaderStarts >= myContStart & this.eleHeaderStarts <= myContEnd;
            isDirect = this.elementLevels == this.elementLevels(ii)+1;
            isMyChild = isDirect & isMyDescendent;
            myChildren = find(isMyChild(:))';


            % if we don't have children this will skip, otherwise it will set info about
            % us being a parent and neighbouring elements being 'siblings'
            for childInd = myChildren
                this.parentElement(childInd) = ii;
                lastChild = childInd;

                % store info about siblings in a chain
                if childInd>myChildren(1)
                    this.siblingElement(childInd) = lastChild;
                    lastChild = childInd;
                else
                    eldest = childInd;
                    this.childElement(ii) = childInd;
                end

                % give the first child the ind of the last child to complete
                % a ring.
                if childInd>myChildren(1)&&childInd==myChildren(end)
                    this.siblingElement(eldest) = lastChild;
                end
            end
        end
    end

    function eleStruct = get_ele_struct( this )
        for ii=1:this.numberOfElements
            ele = this.makeEle(ii);
            eleStruct.ele(ii) = ele;
        end
    end

    function tags = get_tags( this, eleStruct )
        tags = zeros(this.numberOfElements,this.maxTagLength);
        for ii = 1:this.numberOfElements
            tags(ii,1:this.tagLengths(ii)) = eleStruct.ele(ii).tag_;
        end
    end

    function multiplicity = get_multiplicity( this, tags )

        multiplicity = ones(this.numberOfElements,1);
        EL = this.elementLevels;
        maxDepth = max(EL);

        multiplicity(EL == min(EL)) = 1;
        for dep = min(EL)+1:maxDepth
            ATD = EL == dep;
            TATD = tags(ATD,:);
            occATD = ones(1,sum(ATD));
            PATD = this.parentElement(ATD);
            [~,isDuplicateParent] = this.get_duplicates(PATD);
            UPATD=unique(PATD(isDuplicateParent==1));
            % NOT JUST SAME PARENT BUT SAME NAME TOO.
            for UP = UPATD(:)'

                TUP = PATD==UP;
                nTUP = sum(TUP);
                multTUP = ones(1,nTUP);
                checked = zeros(1,nTUP);
                IT = TATD(TUP,:);
                for jj=1:size(IT,1)
                    if checked(jj)
                        continue
                    end
                    isMatch = all(IT==IT(jj,:),2)';
                    checked(isMatch) = 1;
                    multTUP(isMatch) = 1:sum(isMatch);
                end
                occATD(TUP) = multTUP;
            end
            multiplicity(ATD) = occATD;
        end

    end

    function root = to_struct(this)

        eleStruct = this.get_ele_struct();
        eleStruct = eleStruct.ele;    
        % get the parents using arrayfun
        parents = arrayfun(@(x) x.parent_, eleStruct);
        childrenCellArray = cell(numel(eleStruct), 1);
        % loop through the elements, assign kids to parents
        for i = 1:numel(eleStruct)
            % get the parent
            parent = parents(i);
            % if the parent is not empty
            if (~isempty(parent)) && parent % root is 0, and we're 1 indexed
                % add the index to the childrenCellArray
                childrenCellArray{parent} = [childrenCellArray{parent} i];
            end
        end
        % do the fun recursive thing
        root = OI.Data.XmlFile.to_nodestruct(eleStruct,childrenCellArray,1);

        % elements = eleStruct.ele;
        % 
        % root = struct();
        % 
        % % start with the first element.s
        % % create a struct for it
        % startInd = 1;
        % root.(elements(startInd).tag_) = struct();
        % parents = arrayfun(@(x) x.parent_,elements);
        % tags = arrayfun(@(x) x.tag_,eleStruct.ele,'UniformOutput',0);
        % depths = arrayfun(@(x) x.depth_,elements);
        % 
        % % find any elements that have this as a parent.
        % thisChildren = find(parents == startInd);
        % 
        % % while there are unassigned eles
        % unassigned = true(1,numel(elements));
        % 
        % while any(unassigned)
        %     % get the max depth of unassigned eles
        %     maxDepth = max(depths(unassigned));
        % 
        %     % get the unassigned eles at this depth
        %     theseEles = find(unassigned & depths == maxDepth);
        % 
        %     % determine how many individual parents there are
        %     theseParents = parents(theseEles);
        %     uniqueParents = unique(theseParents);
        %     nUniqueParents = numel(uniqueParents);
        % 
        %     % for each parent
        %     for ii = 1:nUniqueParents
            %     % get the eles that have this parent
            %     thisParent = uniqueParents(ii);
            %     thisParentEles = theseEles(theseParents == thisParent);
        % 
            %     % get the parent tag
            %     thisParentTag = tags{thisParent};
            %     % assign each child of this unique parent
            %     for jj = 1:numel(thisParentEles)
                %     % get the child tag
                %     thisChildTag = tags{thisParentEles(jj)};
                %     % assign the child to the parent
                %     root.(thisParentTag).(thisChildTag) = struct();
                %     % mark this child as assigned
                %     unassigned(thisParentEles(jj)) = false;
            %     end
        %     end
        % end
        % 

% parents = arrayfun(@(x) x.parent_,eleStruct.ele);
% tagStr = arrayfun(@(x) x.tag_,eleStruct.ele,'UniformOutput',0);
% sibs = arrayfun(@(x) x.sibling_,eleStruct.ele);

%         % THIS METHOD FAILS BECAUSE OF NESTED NON_SCALAR STRUCTURES:
%         % fundamentally it tries to build the bottom generation up
%         % but we build one layer at a time
%         % and the connections from a bottom layer might be to different 
%         % root elements several layers up.
%         % so we cant relate 10 greatgrandchildren named sarah to 10
%         % individual seperate greatgrandparents named Tony because we only
%         % have access to the layer above, and not the greatgrandparents 
%         % generation
%         tags = this.get_tags( eleStruct );
%         occurance = this.get_multiplicity( tags );

%         root = struct();
%         branches = struct();
%         maxDepth = max(this.elementLevels);

%         % We have to do this from leaf-to-root rather than root-to-leaf due to
%         % difficulties in passing by reference with Mat/Oct: There's no obvious way to
%         % do root to leaf without long, expensive, statements like
%         % root.(level1).(level2) ... (levelN) = "ipsum".
%         for ii=maxDepth:-1:1
%             [root,branches] = this.level_up_branches(root,branches,eleStruct);

%             % at this depth we have some elements.
%             % they need to be attached to their parents
%             atThisDepth = this.elementLevels == ii;
%             ss = eleStruct.ele(atThisDepth);
%             % Anything that has child elements will have been rolled up from prior
%             % iterations.
% %            hasKids = arrayfun(@(x) x.child_,ss) > 0; % bug in octave?
%              hasKids = zeros(1,numel(ss),"logical");
%             for jj=1:numel(ss)
%                 if (ss(jj).child_); hasKids(jj) = true; end
%             end
%             ss=ss(~hasKids);

%             [branches] = this.build_branches(ss,eleStruct,branches,occurance);
%         end
%         topLevel = fieldnames(branches);
%         if numel(topLevel) > 1
%             root = branches;
%         else
%             switch topLevel{1}
%             case 'product' % trim S1 xml so we dont have to write product every time
%                 root = branches.product;
%             end
%         end 

    end

    function this = find_markup( this )
        x = this.rawXml;
        lArrow = find(x == '<');
        rArrow = find(x == '>');
        if length(lArrow) ~= length(rArrow)
            error("I'm having trouble reading this xml file %s")
        end

        % convert markups into elements %
        % any closing tags are not elements.
        % any empty elements have slightly different format.
        % Empty elements end with "/>"
        % guard edge case where file starts with '>'...
        if isempty(rArrow)||rArrow(1)==0, error("bad xml"); end
        isMarkupEmptyElement = x(rArrow-1) == '/';

        % Closing markup starts with "</"
        % guard edge case where file ends with '<'...
        if lArrow(end)==length(x), error("bad xml"); end
        isMarkupCloser = x(lArrow+1) == '/';
        this.elementClosers = lArrow(isMarkupCloser);
        % If its not a closer its an opener
        isInstruction = x(lArrow+1) == '?';
        isMarkupOpener = ~isMarkupCloser & ~isInstruction;
        this.elementOpeners = lArrow(isMarkupOpener);

        % Elements are defined by an open-close pair of markup tags.
        % We will assume the file is valid and simply go off opener markup tags.
        this.numberOfElements = sum(isMarkupOpener);
        this.eleIsInstruction = OI.Data.BoolArray( ...
                            isInstruction(isMarkupOpener) );
        this.eleIsEmpty = OI.Data.BoolArray( ...
                            isMarkupEmptyElement(isMarkupOpener) );

        nOpens =    sum( isMarkupOpener );
        nCloses =   sum(isMarkupCloser) + ...
                    sum(isMarkupOpener & isMarkupEmptyElement);
        if  nOpens ~= nCloses
            msg = sprintf(['There appears to be %i open tags versus ' ...
                            '%i close tags. This may not be valid xml.\n'], ...
                            nOpens, nCloses ...
                            );
            warning(msg)
        end

        this.eleHeaderStarts = lArrow(isMarkupOpener);
        % adjust empty elements by 1 for '/' at end:
        this.eleHeaderEnds = rArrow(isMarkupOpener) - (1*this.eleIsEmpty.mask());

        % now we know the number of elements, lets init some space for info
        [this.valStarts,this.valEnds,this.contEnds, this.parentElement, ...
         this.siblingElement,this.childElement                      ] = ...
             deal(zeros(1,this.numberOfElements));

        % The first space we find after the start of the element is the end of the tag.
        this.tagLengths = this.get_tag_length(...
            x, this.eleHeaderStarts, this.eleHeaderEnds);
        this.maxTagLength = max(this.tagLengths);
        this.tagStarts = this.eleHeaderStarts+1;
        this.tagEnds = this.eleHeaderStarts+this.tagLengths;

        % the attibutes are the end of the tag until the end of the element header
        this.atrStarts = this.tagEnds + 2; % space and one for 1-index
        this.atrEnds = this.eleHeaderEnds - 1; % minus one for '>'
    end


    function ele = makeEle(this,ii)

        thisVal = '';
        c = this.rawXml;

        vRange = this.valStarts(ii):this.valEnds(ii);
        if vRange %#ok<*BDSCI,BDLGI> nonsense warning.
            thisVal = c(vRange);
        end
        thisTag = this.replace_illegal_characters( ...
                    c(this.tagStarts(ii):this.tagEnds(ii)) ...
        );
        aRange = this.atrStarts(ii):this.atrEnds(ii);
        theseAttributes = c(aRange);
        ele = OI.Data.XmlNode( ...
                            thisTag, ...
                            thisVal,...
                            theseAttributes, ...
                            ii, ...
                            this.parentElement(ii), ...
                            this.childElement(ii), ...
                            this.siblingElement(ii), ...
                            this.elementLevels(ii) ...
                );
%         ele = struct( ...
%                 "value",thisVal, ...
%                 "parent",this.parentElement(ii), ...
%                 "sibling",this.siblingElement(ii), ...
%                 "child", this.childElement(ii), ...
%                 "index",ii, ...
%                 "tag",thisTag, ...
%                 "attributes",theseAttributes ...
%         );
    end

    % return a struct of eles.
    function structOfEles = find( this , tagName )
        tagName = char(tagName);
        nChars = numel(tagName);
        rightLength = find(this.tagLengths == nChars);
        rightStr = 0.*rightLength;
        for ii=numel(rightLength):-1:1
            eleInd = rightLength(ii);
            eleTag = this.rawXml(this.tagStarts(eleInd):this.tagEnds(eleInd));
            if eleTag == tagName
                rightStr(ii) = true;
            end
        end
        rightTag = rightLength(rightStr == 1);
        ii = numel(rightTag);
        if ~ii
            structOfEles = [];
            return;
        end
%         structOfEles = struct();
        for ii=numel(rightTag):-1:1
            eleInd = rightTag(ii);
            structOfEles(ii) = this.makeEle(eleInd);
        end
    end

    function d = get_content_depth( this )
        t = this.rawXml;

        closerLength = this.get_tag_length( ...
                t, ...
                this.elementClosers, ...
                this.elementClosers+this.maxTagLength+2 ...
        );

        dd = [0.*t,0,0];
        dd(this.elementOpeners) = 1;
        dd(this.elementClosers+closerLength+2) = ...
            dd(this.elementClosers+closerLength+2) -1;
        emptyEle = this.elementOpeners(this.eleIsEmpty.mask);

        emptyLength = this.get_tag_length( ...
                t, ...
                emptyEle, ...
                emptyEle+this.maxTagLength+2 ...
        );

        % empty might be <aTag /> or <aTag/> so we need
%         hasSpace = (t(emptyEle + emptyLength + 1));
        endOfEmptyEle = this.eleHeaderEnds( this.eleIsEmpty.mask )+2;
        dd( endOfEmptyEle ) = dd( endOfEmptyEle ) -1;
        d= cumsum(dd);
        d=d(1:end-2);
    end

end


methods (Static = true)

    function levelOfRawXml = get_content_heirarchy(rawXml, maxTagLength)
        %% GET CONTENT DEPTH IN THE GRAPH
        % The depth increases where new xml markup opens...
        markupOpens = rawXml=='<';
        dInc = markupOpens;
        % ... but we need to check this markup isn't an element closer.
        fMUO = find(markupOpens);
        nextIsSlash = rawXml(fMUO+1) == '/';
        % ... and ensure these dont increment depth
        dInc( fMUO(nextIsSlash) ) = 0;

        % The depth decreases when markup indicates an element is being closed.
        % Either through an empty element:
        %_________________________EMPTY ELEMENT_________________________________
        dDecEmpty = rawXml == '>' & circshift(rawXml,1) == '/';
        dDecEmpty=circshift(dDecEmpty,1); %shift to just after the "/>"
        % Or the end of a processing instruction "?>"
        %__________________________INSTRUCTION__________________________________
        dDecProc = rawXml == '>' & circshift(rawXml,1) == '?';
        dDecProc=circshift(dDecProc,1); %shift to just after the "?>"
        %____________________________CLOSING____________________________________
        %  Or markup indicating a closing element with "</"
        dDecClosing = rawXml == '<' & circshift(rawXml,-1) == '/';
        % however in this case, we want to line the depth up so it decrements at
        % the end of the close tag, after </something>.
        % Otherwise you get something like:
        % lvl 0: "<document>"<     lvl -1: "/document>"
        % where we'd prefer:
        % lvl 0: <document></document>
        fDC = find(dDecClosing);
        closerLength = OI.Data.XmlFile.get_tag_length( ...
                        rawXml, ...
                        fDC, ...
                        fDC+maxTagLength ...
        );
        fDCplusLength = min(numel(rawXml),fDC + closerLength+2);
        dDecClosing(fDC)=0; % set the start of the markup back to no change.
        % set the corrected locations for depth change.
        dDecClosing(fDCplusLength)=1;
        %_______________________________________________________________________

        % We want to ignore the last delta, as we can't push it beyond the
        % length of the raw Xml. Otherwise we'd get a '>' lopped off oddly.
        % dDecClosing(end)=0;
        deltaDepth = int8(dInc) ...
                        - int8(dDecEmpty) ...
                        - int8(dDecClosing) ...
                        - int8(dDecProc);
        deltaDepth(end)=0;

        levelOfRawXml = cumsum(deltaDepth);
%        elementLevels = levelOfRawXml(eleHeaderStarts);
    end

    function tagLengths = get_tag_length( rawXml, eleHeaderStarts, eleHeaderEnds)
        % The tags are the markup data without the arrows at start and end
        % and without any attributes.
        % Latch true and stop when a terminator ( space or end of eleHead)
        % has been found.
        latch=zeros(1,numel(eleHeaderStarts)) == -1; % array of false
        isTerm = rawXml == '>' | rawXml == ' ';
        tagLengths = eleHeaderEnds - eleHeaderStarts;
        nMax = numel(isTerm);
        maxDiff = max(eleHeaderEnds - eleHeaderStarts);
        % loop through all chars in markup
        for ii=1:maxDiff
            % pointer to char positions, p.
            p = min(nMax,eleHeaderStarts + ii);
            foundTerminator = isTerm( p ) & p <= eleHeaderEnds & ~latch;
            latch( foundTerminator )=true;
            tagLengths( foundTerminator ) = ii;
            if all(latch)
                break;
            end
        end
        tagLengths = tagLengths-1;
    end


    function isSafeChar = safe_characters(tagInt)
        isSafeChar =     ...
                ( tagInt == 45 )                 | ...    %hypen
                ( tagInt > 47 & tagInt < 58 )     | ...    %numbers
                ( tagInt > 64 & tagInt < 91 )    | ...    %uppercase
                ( tagInt == 95 )                 | ...    %underscore
                ( tagInt>96 & tagInt < 123 )     ;        %lowercase
    end

    function safeStructField = replace_illegal_characters(unsafeStructField)
        badChars = ~OI.Data.XmlFile.safe_characters(int8(unsafeStructField));
        unsafeStructField(badChars) = '_';
        safeStructField = unsafeStructField;
    end

    function [duplicates, isDuplicate] = get_duplicates(arr)
        firstOccurance = zeros(max(arr),1);
        isDuplicate = 0.*arr;
        for ii = 1:length(arr)
            key = arr(ii);
            if ~key; continue; end
            if firstOccurance(key)
                isDuplicate(firstOccurance(key)) = true;
                isDuplicate(ii) = true;
            else
                firstOccurance(key) = ii;
            end
        end
        duplicates = find(isDuplicate);

    end

    function branches = build_branches(ss,eleStruct,branches,occ)
        
        parents = arrayfun(@(x) x.parent_,eleStruct.ele);
        tagStr = arrayfun(@(x) x.tag_,eleStruct.ele,'UniformOutput',0);
        sibs = arrayfun(@(x) x.sibling_,eleStruct.ele);
        burstI = cellfun(@(x) strcmpi(x,'burst'),tagStr);

        for eleInd = 1:numel(ss)
            thisEle = ss( eleInd );
            eleTag = thisEle.tag_;
            if (thisEle.parent_)

                par = eleStruct.ele( thisEle.parent_ );
                parTag = par.tag_;

                parOccurance = occ( thisEle.parent_ );
                eleOccurance = occ( thisEle.index_ );

                if parOccurance>1&&~isfield(branches,parTag)
                    branches.(parTag)(1:parOccurance) = struct();
                end

                branches.(parTag)(parOccurance).(eleTag)(eleOccurance).tag_ =...
                    thisEle.tag_;
                branches.(parTag)(parOccurance).(eleTag)(eleOccurance).value_ =...
                    thisEle.value_;
                branches.(parTag)(parOccurance).(eleTag)(eleOccurance).index_ =...
                    thisEle.index_;
                branches.(parTag)(parOccurance).(eleTag)(eleOccurance).parent_ =...
                    thisEle.parent_;
                branches.(parTag)(parOccurance).(eleTag)(eleOccurance).attributes_ =...
                    thisEle.attributes_;
                branches.(parTag)(parOccurance).index_ = par.index_;
                branches.(parTag)(parOccurance).parent_ = par.parent_;
                branches.(parTag)(parOccurance).tag_ = parTag;
                branches.(parTag)(parOccurance).value_ = par.value_;
                branches.(parTag)(parOccurance).attributes_ = par.attributes_;
            else % i think this only happens if we have 1 element??
                branches.(eleTag).tag_ = thisEle.tag_;
                branches.(eleTag).value_ = thisEle.value_;
                branches.(eleTag).index_ = thisEle.index_;
                branches.(eleTag).parent_ = thisEle.parent_;
                branches.(eleTag).attributes_ = thisEle.attributes_;
            end
        end
    end

    function [root,branches] = level_up_branches(root,branches,eleStruct)
        fnb = fieldnames(branches);
        % We need to increase the depth of any branches
        % From the depth below
        for jj=1:numel(fnb)
            fn = fnb{jj};
            if iscell(fn) %mat/oct
                fn =fn{1};
            end

            branchesWithThisName = branches.(fn);
            deleteMeLater = zeros(1,numel(branchesWithThisName));
            for twigInd = numel(branchesWithThisName):-1:1
                thisTwig = branches.(fn)(twigInd);
                if isempty(thisTwig.index_)
                    deleteMeLater(twigInd) = 1;
                    continue
                end
                if  thisTwig.parent_
                    par = eleStruct.ele( thisTwig.parent_ );

                    branches.(par.tag_).(thisTwig.tag_)(twigInd) = thisTwig;
                    branches.(par.tag_).parent_ = par.parent_;
                    branches.(par.tag_).tag_ = par.tag_;
                    branches.(par.tag_).index_ = par.index_;
                    branches.(par.tag_).value_ = par.value_;
                    branches.(par.tag_).attributes_ = par.attributes_;
                    % if theres still twigs with this name, just remove the twig
                    % we moved. Else, remove all twigs with this name (which
                    % shoulf just be one or zero).
                    if twigInd>1
                        branches.(fn)(twigInd) = [];
                    else
                        branches = rmfield(branches,(fn));
                    end
                else
                    root.(thisTwig.tag_)(twigInd) = thisTwig(twigInd);
                end
            end
            % !TODO check depth to avoid deleting <a><a>1</a></a>
            if isfield(branches,fn) && ...
                    ( isempty(branches.(fn).parent_) || ...
                      branches.(fn).parent_ > 0 )
                branches = rmfield(branches,(fn));
            end
        end
    end

    function root = to_nodestruct(...
            elementStructArray, childrenCellArray, index)
        if (nargin < 3)
            index = 1;
        end
    
        root = struct();
    
        % get the child elements
        childEleInds = childrenCellArray{index};
        childEles = elementStructArray(childEleInds);
        % get the tag_ fields using arrayfun
        tags = arrayfun(@(x) x.tag_, childEles, 'UniformOutput', false);
        % identify any duplicate tags and get a logical mask
        [uniqueTags, ~, tagInds] = unique(tags);
        tagIndsThatAreDupes = find(histc(tagInds, 1:numel(uniqueTags)) > 1);
        % Dupe matrix:
        % rows are the tags, columns are the individual duplicates
        % a 1 in the matrix means that the tag is a duplicate corresponding
        % to the column number
        dupeMatrix = tagInds == tagIndsThatAreDupes(:)';
    
        % is a dupe:
        isDupe = any(dupeMatrix, 2);
        % occurance
        numberOfTimesTagHasBeenUsed = cumsum(dupeMatrix);
        % The occurrence of a tag refers to how many times it has appeared among
        % the child elements of a parent element. When a tag is a duplicate, its
        % occurrence count is incremented by 1 for each preceding duplicate, 
        % enabling unique indexing of duplicates.
        tagMultiplicity = ones(size(tags));
        tagMultiplicity(isDupe) = numberOfTimesTagHasBeenUsed(isDupe);
    
        for childInd = 1:numel(childEleInds)
            % get the index of the child element
            k = childEleInds(childInd);
            % get the tag occurance
            thisOne = tagMultiplicity(childInd);
    
            % if the element has no children, add the data to the struct
            % if the element is a leaf, add the data to the struct
            if isempty(childrenCellArray{k})
                val = elementStructArray(k).value_;
                attr = elementStructArray(k).attributes_;
                if isempty(attr) % char?% can only be 1 multi anyway? unless cell?
                    root.(elementStructArray(k).tag_) = ...
                        elementStructArray(k).value_;
                elseif contains(attr,'double') || contains(attr,'logical')
                    if isempty(val)
                        if thisOne == 1
                            root.(elementStructArray(k).tag_) = [];
                        else
                            '??'
                        end
                    elseif contains(attr,'array')
                        if thisOne == 1
                            root.(elementStructArray(k).tag_) = ...
                                str2num(elementStructArray(k).value_);
                        else
                            '???{}?'
                            root.(elementStructArray(k).tag_){thisOne} = ...
                                str2num(elementStructArray(k).value_);
                        end
                    else
                        if thisOne == 1
                            root.(elementStructArray(k).tag_) = ...
                                str2num(elementStructArray(k).value_);
                        else
                            root.(elementStructArray(k).tag_)(thisOne) = ...
                                str2num(elementStructArray(k).value_);
                        end
                    end
                else % both child elements and values??
                    if ~isempty(elementStructArray(k).tag_)
                        root.(elementStructArray(k).tag_) = elementStructArray(k).value_;
                    else
                        'Hopefully unreachable?'
                        warning('debug this')
                        root.value_ = elementStructArray(k).value_;
                    end
                end
                % end
            else % element has children
                % if the element is not a leaf, recurse
                if strcmpi(elementStructArray(k).tag_,'oi_cell')
                    undercell = OI.Data.XmlFile.to_nodestruct(elementStructArray, childrenCellArray, k);
                    nCell = numel(undercell);
                    root = cell(1);
                    root{1} = OI.Data.XmlFile.to_nodestruct(elementStructArray, childrenCellArray, k);
                    for ii = 2:nCell
                        root{ii} = OI.Data.XmlFile.to_nodestruct(elementStructArray, childrenCellArray, k);
                    end
                else
                    root.(elementStructArray(k).tag_)(thisOne) = ...
                        OI.Data.XmlFile.to_nodestruct(elementStructArray, childrenCellArray, k);
                end
            end
        end
    end % xml2nodestruct

    function commentlessXml = strip_comments(xml)
        % remove comments
        commentlessXml = regexprep(xml,'<!--.*?-->','');
    end
end%statics

end%classdef