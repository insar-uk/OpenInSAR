function root = x2s (elementStructArray, childrenCellArray, index);
    % let client code handle converting from XmlNode to data
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
        if isempty(childrenCellArray{k})
            % if the element is a leaf, add the data to the struct
            root.(elementStructArray(k).tag_)(thisOne) = ...
                elementStructArray(k);
        else
            % if the element is not a leaf, recurse
            root.(elementStructArray(k).tag_)(thisOne) = ...
                OI.Functions.x2s(elementStructArray, childrenCellArray, k);
        end
    end