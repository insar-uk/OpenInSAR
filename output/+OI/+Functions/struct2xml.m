classdef struct2xml

properties
    root = OI.Data.XmlNode( 'root', '', {}, 1, 0, 0, 0, 1);
    % OI.Data.XmlNode( tag, value, attributes, index, parentIndex, firstChildIndex, nextSiblingIndex, depth)
end
%#ok<*AGROW>

methods
    function this = struct2xml( structObj )
        assert(numel(structObj) == 1, ...
            'Only works for scalar struct/obj, wrap structObj into one?')
        this = this.next( structObj );
    end


    function [this, cursor] = next(this, SOMETHING, tag, parent, cursor, depth)
        if nargin == 2
            parent = 0;
            cursor = 0; % will be +1'd
            depth = 0; % will be +1'd
            tag = 'root';
        end
        % the cursor follows the position of the node in the xml string
        % wherever the cursor lands, this is called and there is a new node.
        % To completely define our tree we need to assess all of:
        % tag, - field names are tags,
        % value, - field values without children are values
        % attributes, - ?
        % index, - cursor
        % parentIndex, - cursor of the node which calls this function
        % firstChildIndex, - cursor of the first child of this node
        % nextSiblingIndex, - cursor of the next sibling of this node
        %     assign this while looping in here
        % depth - redundant but convenient. 
        % equal to the stack depth of this function, so +1 every time its called

        % SOMETHING might be a struct, cell, array
        % we call this whenever we're adding a new node
        % we should know everything except 
        % a) first child index (if any)
        % b) next sibling index (if any)
        % c) how to handle the child data passed in
        
        % we're doing depth first so by default depth should increase by 1
        depth = depth + 1;

        % because this is a new element:
        cursor = cursor + 1; % increment cursor...
        % ... and allocate the new node
        this.root(cursor) = ...
            OI.Data.XmlNode( tag, '', {}, cursor, parent, 0, 0, depth);

        % if tag is empty then we're adding a value, inevitably.
        isLeaf = isempty(tag); 

        % if we're not a struct or obj then we can't have children
        isLeaf = isLeaf || ...
            (~isstruct(SOMETHING) && ~isobject(SOMETHING) && ~iscell(SOMETHING));
        % todo , maybe we can have children if we're a cell array? but no tags?
        % tag would have to be something generic like <cell></cell>
        if isLeaf
            % if we're a leaf, then we're a value
            [this.root(cursor).value_, this.root(cursor).attributes_] = ...
                this.format_values(SOMETHING);
            return
        end

        % now, work out if we're one of many siblings
        if numel(SOMETHING) > 1
            % if we're one of many siblings, then we need to add a next sibling
            % and then recurse on each of the siblings
            for ind = 1:numel(SOMETHING)
                % replace the family cursor with the first sibling cursor
                if ind == 1
                    cursor = cursor - 1;
                end
                thisSibling = cursor;
                % handle this siblings individually, at the same depth
                [this, cursor] = this.next( SOMETHING(ind), tag, cursor, cursor,depth -1 ); % parent arg will be assigned, cursor arg will be incremented in the recursion
                % depth is incremented in the recursion, so we need to decrement it here

                this.root(thisSibling).sibling_ = cursor + 1;
                % except for the last sibling, which has no next sibling
                if ind == numel(SOMETHING)
                    this.root(thisSibling).sibling_ = 0;
                end
                
            end
            return
        end

        % so finally, but firstly in terms of return order (barring empties), handle the children
        % we're not a leaf, so we're a struct or object
        % we're not a sibling, so we're the only child
        % we're not empty, so we have children
        % so we need to add a first child and then recurse on each of the children

        % first child is the next node
        this.root(cursor).child_ = cursor + 1;


        if isobject(SOMETHING) 
            fNames = properties(SOMETHING);
        elseif isstruct(SOMETHING) 
            fNames = fieldnames(SOMETHING);
        elseif iscell(SOMETHING)
            if numel( SOMETHING )
                [this, cursor] = this.next(SOMETHING{1}, 'oi:cell', cursor, cursor, depth);
            end
            return
        else
            error('not sure how we got here')
        end

        % handle and remove any unwanted fields, maybe attributes, here:
        %
        %
        % below this every fieldname is a child

        for fInd = 1:numel(fNames)
            fieldname = fNames{fInd};
            if isempty(SOMETHING)
                continue
            end
            fieldvalue = SOMETHING.(fieldname);

            % handle this children
            [this, cursor] = this.next(fieldvalue, fieldname, cursor, cursor, depth); % parent arg will be assigned, cursor arg will be incremented in the recursion
        end

    end

    function print_headers(this)
        N = numel(this.root);
        L = this.root;
        % 0 the depth
        for ii = N:-1:1
            L(ii).depth_ = L(ii).depth_ - L(1).depth_;
        end

        for ii = 1:N
            % print tabs
            depth = L(ii).depth_;
            if depth
                ts = char(reshape(('\t'.*ones(L(ii).depth_,2))',1,[]));
                fprintf(1, ts);
            end
            % print tag
            fprintf(1, '%s:\n', L(ii).tag_);
        end
    end

    function str = to_string( this, doTabsAndNewlines )
        if nargin==1
            doTabsAndNewlines = false;
        end

        str = '';
        N = numel(this.root);
        L = this.root;

        % zero the depth
        for ii = N:-1:1
            L(ii).depth_ = L(ii).depth_ - L(1).depth_;
        end

        closed = false(N,1);

        for ii=1:N

            % add tabs
            if doTabsAndNewlines
                tabs = repmat('\t',1,L(ii).depth_);
                str = [str, tabs];
            end
            % add tag
            str = [str, '<', L(ii).tag_];
            % add attributes
            if ~isempty(L(ii).attributes_)
                str = [str, ' ', L(ii).attributes_];
            end
            % close tag
            str = [str, '>'];
            if doTabsAndNewlines
                str = [str, '\n'];
            end


            % add value
            % make sure its one line
            if ~isempty(L(ii).value_)
                % val = this.format_values(L(ii).value_(:)')';
                val = L(ii).value_;
                if doTabsAndNewlines
                    str = [str, tabs, '\t', val(:)' newline];
                else
                    str = [str val(:)'];
                end
            end

            % check the next node
            % if its a child, then we're done for this iter
            if ii ~= N
                if L(ii+1).depth_ > L(ii).depth_
                    continue
                end
                % if next one is same depth or higher, 
                % then we need to close some tags
                closeToDepth = L(ii+1).depth_;
            else
                % if we're the last node, close all tags
                closeToDepth = 0;
            end

            % search backwards until we find the first node at the same depth
            % close any open nodes with greater depth
            for jj = ii:-1:1
                if ~closed(jj) && L(jj).depth_ >= closeToDepth
                    if doTabsAndNewlines
                        str = [str, repmat('\t',1,L(jj).depth_), '</', L(jj).tag_, '>\n'];
                    else
                        str = [str, '</', L(jj).tag_, '>'];
                    end
                    closed(jj) = true;
                end
                if L(jj).depth_ == closeToDepth
                    break
                end
            end

        end

    end


end % methods

methods (Static = true)
    function [valStr, attrStr] = format_values( values )
        attrStr = '';
        switch class( values )
            case {'double','logical'}
                attrStr = ['oi:' class(values)];
                if numel(values) > 1
                    attrStr = [attrStr '_array'];
                    v = values;
                    % comma separated, semicolon delineated
                    s0 = [num2str(v(:),'%.16f') ','.*ones(numel(v),1)];
                    s1 = reshape(s0',[],size(v,1));
                    s1(end,:)=';';
                    valStr = s1(:)';
                    % remove duplicate spaces
                    valStr = regexprep(valStr,' +',' ');
                else
                    valStr = num2str(values,'%.16f');
                end
            case 'char'
                valStr = values;
            otherwise % we need to handle children
                valStr = [class(values) ' not yet supported'] ;
        end
    end

















    % function [this, cursor] = add_something(this, SOMETHING, cursor, depth)
    %     % SOMETHING might be a struct, cell, array
        
    %     % the cursor follows the position of the node in the xml string
    %     % wherever the cursor lands, we need to assess:
    %     % tag, - field names are tags,
    %     % value, - field values without children are values
    %     % attributes, - ?
    %     % index, - cursor
    %     % parentIndex, - cursor of the node which calls this function
    %     % firstChildIndex, - cursor of the first child of this node
    %     % nextSiblingIndex, - cursor of the next sibling of this node
    %     %     assign this while looping in here
    %     % depth - equal to the stack depth of this function



    %     % We need to do pre-order depth-first traversal to get the order right

    %     % this is depth first so depth has increased by 1
    %     depth = depth + 1;

    %     % if the current node is empty (of children), return:
    %     sClass = class( SOMETHING );
    %     if isobject( SOMETHING )
    %         sClass = 'object';
    %     end

    %     isEmpty = true;
    %     switch sClass
    %         case {'double','logical'}
    %             this.nodelist(cursor).value_ = num2str(SOMETHING);
    %         case 'char'
    %             this.nodelist(cursor).value_ = SOMETHING;
    %         otherwise % we need to handle children
    %             isEmpty = false;
    %     end

    %     if isEmpty
    %         return
    %     end

    %     % so work out multiplicity of SOMETHING
    %     ns = numel( SOMETHING );

    %     if ns>1
    %         for inds = 1:ns % sibling elements
    %             thisSiblingCursor = cursor;
    %             [this, cursor] = this.add_something( SOMETHING(inds).
    %             % if theres more bros and sisters
    %             if inds < ns
    %                 cursor = cursor + 1; % new sis/bro is next in list
    %                 this.nodelist(cursor) = ...
    %                     OI.Data.XmlNode( tag, '', {}, cursor, parentCursor, 0, 0, depth);
    %                 nextSiblingCursor = cursor + 1;
    %                 this.nodelist(thisSiblingCursor).nextSibling_ = nextSiblingCursor;
    %             end
                
    %         end % for same eles

    %         return
    %     end


    %     % but recurse on children first
    %     switch sClass
    %         case {'struct'}
    %             % we need to add a node for each field
    %             fields = fieldnames( SOMETHING(inds) );
    %             % handle any special fields here, otherwise treat fields as children
    %             % if strcmpi( fields{1}, 'attributes' )
    %             % remove any fields that we don't want to be children
    %             % fields(notChildFields) = [];

    %             % add each field as a child
    %             parentCursor = cursor;
    %             if numel(fields)
    %                 % add the first child index
    %                 this.nodelist(cursor).child_ = cursor + 1;
    %             end

                
    %             for indf = 1:numel(fields)
    %                 tag = fields{indf};
    %                 cursor = cursor + 1;
    %                 this.nodelist(cursor) = ...
    %                     OI.Data.XmlNode( tag, '', {}, cursor, parentCursor, 0, 0, depth);
    %                 [this, cursor] = this.add_something( SOMETHING.(fields{indf}), cursor );
    %             end
    %         case {'cell'}

    %         case {'object'}

    %     end % switch

% end % function


end % methods

end % classdef