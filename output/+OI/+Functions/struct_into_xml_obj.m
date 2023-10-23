function docElem = struct_into_xml_obj(docNode, docElem, structObj)

% STRUCT_INTO_XML_OBJ - Convert a MATLAB structure into an XML object
%
% struct_into_xml_obj(docNode, docElem, structObj)
% 
% docNode - XML Document object
% docElem - XML Element object
% structObj - MATLAB structure
%
% See also: XMLREAD, XMLWRITE
%

if ~isstruct(structObj)
  error('structObj must be a structure');
end

fnames = fieldnames(structObj);
% nStruct = numel(structObj);

% if its not scalar, then we need to create a new element for each
% element in the structure array
% if nStruct > 1
%     for structInd = 1:nStruct
%         docElem = OI.Functions.struct_into_xml_obj(docNode, docElem, structObj(structInd));
%     end
%     return;
% else
if 1==1
    % add each field
    for fInd = 1:numel(fnames)

        % get the class of the field
        val = structObj.(fnames{fInd});
        fClass = class(val);
        switch fClass
            case 'char'
                newElem = docNode.createElement(fnames{fInd});
                docElem.appendChild(newElem);
                newElem.appendChild(docNode.createTextNode(val));
                % add the field as a text node
            case 'logical'
                % !! TODO TYPE ENCODING
                % add the field as a text node
                newElem = docNode.createElement(fnames{fInd});
                newElem.setAttributeNS('?','matlab_type_','logical');
                docElem.appendChild(newElem);
                newElem.appendChild(docNode.createTextNode(num2str(structObj.(fnames{fInd}))));
            case {'double', 'single', 'int8', 'int16', 'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64'}
                % !! TODO TYPE ENCODING
                if numel(val) == 0
                    1;
                    continue;
                end
                % add the field as a text node
                valSize = size(val);
                str = num2str(val);
                % check if its an array and format the string
                if valSize(1) > 1
                    % its a vector, so add a new line after each value
                    str = [str, '; ' .* ones(valSize(1),1)];
                    str = str';
                    str = str(:)';
                end
                if valSize(2) > 1 || valSize(1) > 1
                    % replace spaces with commas
                    split = strsplit(str, ' ');
                    split(cellfun(@isempty,split))=[];
                    str = strjoin(split,',');
                    str = strrep(str, ';,', ';');
                end
                newElem = docNode.createElement(fnames{fInd});
                newElem.setAttributeNS('?','matlab_type_','double');
                docElem.appendChild(newElem);
                newElem.appendChild(docNode.createTextNode(str));
            case 'struct'
                % add the field as a new element

                if numel(val)>1
                    for ii=1:numel(val)
                        newElem = docNode.createElement(fnames{fInd});
                        docElem.appendChild(newElem);
                        error('element unused here - debug')
                        % newElem = OI.Functions.struct_into_xml_obj(docNode, newElem, structObj.(fnames{fInd})(ii));
                    end
                else
                    newElem = docNode.createElement(fnames{fInd});
                    docElem.appendChild(newElem);
                    docElem = OI.Functions.struct_into_xml_obj(docNode, newElem, structObj.(fnames{fInd}));
                end
            case 'cell'
                % add the field as a new element
                for ii=1:numel(val)
                    newElem = docNode.createElement(fnames{fInd});
                    docElem.appendChild(newElem);
                    docElem = OI.Functions.struct_into_xml_obj(docNode, newElem, structObj.(fnames{fInd}){ii});
                end
            otherwise
                error('Unknown class type: %s', fClass);
        end
    end
end
%#ok<*AGROW> - Limited performance hit