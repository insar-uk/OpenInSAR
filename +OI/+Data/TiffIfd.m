classdef TiffIfd
properties
    NextIfd=0;
    
    NewSubfileType
    SubfileType
    ImageWidth
    ImageLength
    BitsPerSample
    Compression %259
    PhotometricInterpretation %262
    ImageDescription %270
    StripOffsets
    Orientation %274
    SamplesPerPixel
    RowsPerStrip
    StripByteCounts
    XResolution %282
    YResolution %283
    PlanarConfiguration %284
    ResolutionUnit
    Software %305
    DateTime
    ColorMap
    SubIFDs  
    SampleFormat
    
    ModelTiepointTag %33922
    GeoKeyDirectoryTag %34735
    GeoDoubleParamsTag %34736
    GeoAsciiParamsTag %34737
    
    unknownTags
end % properties
    
properties (Constant = true)
    % Map the tiff type code to its Octave type specifier
    typeSpecifier = [   "*uint8";
                        "*char";
                        "*uint16";
                        "*uint32";
                        "*uint32";
                        "*int8";
                        "*uint8";
                        "*int16";
                        "*int32";
                        "*int32";
                        "*single";
                        "*double";
                        "*uint32";    ]
    % Map the tiff type code to its byte count via index
    bytesPerItem = [1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8, 4];
    % Number of vals per type
    multiplicity = [1, 1, 1, 1, 2, 1, 1, 1, 1, 2, 1, 1, 1];
end % properties (Constant = true)

methods
    function this = TiffIfd( fId, offset )
        if nargin == 0 
            return
        end
        fseek(fId,offset,'bof');
        ifdLength = fread(fId,1,'*uint16');
        for ii=1:ifdLength
            this = this.read_tag(fId);
        end
        this.NextIfd = fread(fId,1,'*uint32');
    end % TiffIfd
    
    function this =  read_tag(this,fid)
        code = fread(fid,1,'*uint16');
        type = fread(fid,1,'*uint16');
        count = fread(fid,1,'*uint32');
        
        tagBytes = count.*this.bytesPerItem(type);
        nextTagOffset = ftell(fid) + 4;
        if tagBytes>4
            % read the 4 byte offset for data
            thisDataOffset = fread(fid,1,"*uint32");
            fseek(fid,thisDataOffset,'bof');
        end
        value = fread(fid,count,this.typeSpecifier(type));
        if ~isempty(value)
            this = this.set_tag(code,value);
        end
        fseek(fid,nextTagOffset,'bof');
    end % read_tag
    
    % Octave doesn't have enumerations...
    function this = set_tag( this, code,  value)
        switch (code)
            case 254
                this.NewSubfileType = value;
            case 255
                this.SubfileType = value;
            case 256
                this.ImageWidth = value;
            case 257
                this.ImageLength = value;
            case 258
                this.BitsPerSample = value;
            case 259
                this.Compression = value;
            case 262
                this.PhotometricInterpretation = value;
            case 270
                this.ImageDescription = value;
            case 273
                this.StripOffsets = value;
            case 274
                this.Orientation = value;
            case 277
                this.SamplesPerPixel = value;
            case 278
                this.RowsPerStrip = value;
            case 279
                this.StripByteCounts = value;
            case 280
                % this.MinSampleValue = value;
            case 281 
                % this.MaxSampleValue = value;
            case 284
                this.PlanarConfiguration = value;
            case 305 
                this.Software = value;
            case 306
                this.DateTime = value;
            case 330
                this.SubIFDs = value;
            case 339
                this.SampleFormat = value;
            case 33922
                this.ModelTiepointTag = value;
            case 34665
                this.ExifIFDPointer = value;
            case 34735
                this.GeoKeyDirectoryTag = value;
            case 34736
                this.GeoDoubleParamsTag = value;
            case 34737
                this.GeoAsciiParamsTag = value;
            otherwise
                this.unknownTags.(['code',num2str(code)])=value;
        end
    end % set_tag
    
    function bytes = write_ifd(this, bytes)
% An Image File Directory (IFD) consists of a 2-byte count of the number of direc-
% tory entries (i.e., the number of fields), followed by a sequence of 12-byte field
% entries, followed by a 4-byte offset of the next IFD (or 0 if none). (Do not forget to
% write the 4 bytes of 0 after the last IFD.)
        % count the entries (non-empty fields)
        ifdLength = 0;
        for prop = properties(this)
            if ~isempty(this.(prop{1}))
                ifdLength = ifdLength + 1;
            end
        end

        countBytes = typecast(uint16(ifdLength),'uint8');
        if numel(countBytes) == 1
            countBytes = [countBytes, 0];
        end
        bytes = countBytes;
        for ii=1:ifdLength
            bytes = this.write_tag(bytes,ii);
        end

        % write the 4 byte offset for next IFD
        bytes = [bytes, typecast(uint32(0),'uint8')];
    end % write_ifd

    function bytes = write_tag(this, bytes, tagNum, endian)
        tagNames = fieldnames(this);
        tagName = tagNames{tagNum};
        tagCode = str2num(tagName(5:end));
        tagValue = this.(tagName);
        if isnumeric(tagValue)
            tagType = this.get_type(tagValue);
            tagCount = length(tagValue);
            tagBytes = tagCount.*this.bytesPerItem(tagType);
            if tagBytes>4
                % write the 4 byte offset for data
                bytes = [bytes, typecast(uint32(length(bytes)+4),'uint8')];

            else
                bytes = [bytes, typecast(tagValue,this.typeSpecifier(tagType),endian)];
            end
        else
            % write the 4 byte offset for data
            bytes = [bytes, typecast(uint32(length(bytes)+4),endian)];
            bytes = [bytes, typecast(tagValue,this.typeSpecifier(tagType),endian)];
        end
        bytes = [bytes, typecast(uint16(tagCode),endian)];
        bytes = [bytes, typecast(uint16(tagType),endian)];
        bytes = [bytes, typecast(uint32(tagCount),endian)];
    end % write_tag

    function tagType = get_type(this, tagValue)
        if isinteger(tagValue)
            if tagValue>=0
                if tagValue<=255
                    tagType = 1;
                elseif tagValue<=65535
                    tagType = 3;
                else
                    tagType = 4;
                end
            else
                if tagValue>=-128
                    tagType = 6;
                elseif tagValue>=-32768
                    tagType = 8;
                else
                    tagType = 9;
                end
            end
        else
            if tagValue<=1
                tagType = 11;
            else
                tagType = 10;
            end
        end
    end % get_type

end % methods
end % classdef