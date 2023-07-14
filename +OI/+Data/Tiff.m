classdef Tiff < OI.Data.DataObj

methods 
    function obj = Tiff(varargin)
    end
end

properties (Constant = true)
    formatSpec = [  "uint";
                    "int";
                    "float";
                    "?";
                    "int";
                    "float" ];
end

methods (Static =  true)
    function [data, header] = read( filepath )
        fId = fopen( filepath , 'r' );
        header = OI.Data.TiffHeader.from_stream( fId );
        if header.ifdCount > 0
            data = OI.Data.Tiff.read_image_data_from_stream(fId, header);
        end
        fclose( fId );
    end % read

    function [data, header] = read_cropped( filepath, bands, rows, columns)
        fId = fopen( filepath , 'r' );
        limits = struct('bands',bands,'rows',rows,'columns',columns);
        header = OI.Data.TiffHeader.from_stream( fId );
        if header.ifdCount > 0
            data = OI.Data.Tiff.read_image_data_from_stream(...
                fId, header, limits);
        end
        fclose( fId );
    end

    function imageData = read_image_data_from_stream(fId, header,limits)
        % limits appears to be a struct with :
        %   two element vector of first and last row/col?
        %   not sure about band?
        if nargin < 3
            limits = [];
        end
        % helper function
        isComplex =@(ii) ~isempty(header.ifds(ii).SampleFormat) && ...
            (header.ifds(ii).SampleFormat>4);
        
        % get the size of each image from the IFDs
        nBands = numel(header.ifds);
        outputSize=zeros(nBands,2);
        typeSpec = cell(nBands);
        for iBand=1:nBands
            tIfd = header.ifds(iBand);
            
            isCropped = ~isempty(limits) ...
                && ( ~isempty(limits.bands)  ...
                || ~isempty(limits.rows)        ...
                || ~isempty(limits.columns) ); 
                    
            if (~isCropped)
                outputSize(iBand,1) = tIfd.ImageWidth;
                outputSize(iBand,2) = tIfd.ImageLength;
            else
                %fprintf(1,"wifth %i\n",tIfd.ImageWidth);
                %limits.rows(1)
                if isempty(limits.rows)
                    limits.rows = [1 double(tIfd.ImageLength)]; 
                end
                if isempty(limits.columns)
                    limits.columns = [1 double(tIfd.ImageWidth)]; 
                end

                % initial rows are skipped (-1 converts to 0 index)
                skipVals = int64(tIfd.ImageWidth).*(limits.rows(1)-1);
                % then skip the columns
                skipVals = skipVals + limits.columns(1) - 1;
                outputSize(iBand,1) = limits.columns(2)-limits.columns(1)+1;
                outputSize(iBand,2) = limits.rows(2)-limits.rows(1)+1;
            end             
            tType = char(OI.Data.Tiff.formatSpec( tIfd.SampleFormat ));
            bits = int64(tIfd.BitsPerSample)/int64(1+isComplex(iBand));
            typeSpec{iBand}= ...
                [tType, num2str(bits,'%i')];
        end
        
        % If all bandss are equal it makes things a lot easier as we can
        % output a [X * Y * Z] matrix instead of a VLAs
        % check uniform size:
        nUnique = @(x) numel(unique(x));
        isEqualSizedBands = nUnique(outputSize(:,2)).* ...
            nUnique(outputSize(:,1)) == 1;
        isEqualType = all((cellfun(@(x) strcmp(x,typeSpec{1}),typeSpec)));
        if ( isEqualSizedBands && isEqualType )
            isUniformBands = true;
            % output a [X * Y * Z] matrix
            imageData = ...
                zeros( outputSize(1,1), ...
                outputSize(1,2), ...
                nBands, ...
                typeSpec{iBand});
        else
            isUniformBands = false;
            % output a cell array
            imageData = cell(nBands);
            for iBand=1:nBands
                imageData{iBand} = zeros( outputSize(iBand,1:2), ...
                    typeSpec{iBand});
            end
        end
        
        % read each image band from each IFD
        for iBand=1:nBands
            tIfd = header.ifds(iBand);
            columnSize = outputSize(iBand,1);
            rowSize = outputSize(iBand,2);
            tIfd(iBand).StripByteCounts(1);
            
            % we have a lot of different read scenarios to choose
            isSameOffsets = nUnique(diff(tIfd.StripOffsets)) == 1;
            isSameByteCount = nUnique(diff(tIfd.StripByteCounts)) == 1;
            isUniformStrips = isSameOffsets && isSameByteCount;
            
            flagValue = isUniformBands * 1                  ...
                        + isUniformStrips * 2               ... 
                        + isCropped * 4                     ...
                        + (tIfd.Compression == 1) * 8       ...
                        + isComplex(iBand) * 16;
            
            % read in 2 vals for complex
            multiplicity = 1 + isComplex(iBand);
            freadFormat = ['*' typeSpec{iBand}];
            
            fseek(fId,header.ifds(iBand).StripOffsets(1),'bof');
            bytePerSample = int64(tIfd.BitsPerSample)/int64(8);
            if isCropped
                fseek(fId,skipVals.*bytePerSample,0);
            end

            switch (flagValue)
                % cropped section of uniform uncompressed data:
                case 1 + 2 + 4
                % uncompressed data with uniform output :
                case 1 + 2 + 8
                    bandData=fread( fId, ...
                                    multiplicity*rowSize*columnSize, ...
                                    freadFormat                              );
                    imageData(:,:,iBand)=reshape(bandData,rowSize,columnSize);
                % Complex data (such as Sentinel 1 swath):
                case 1 + 2 + 8 + 16
                    bandData=fread( fId, ...
                                    multiplicity*rowSize*columnSize, ...
                                    freadFormat                              );
                    bandData =  single(bandData(1:2:end)) ...
                                + 1i.*single(bandData(2:2:end));
                    imageData(:,:,iBand)= reshape(bandData, ... 
                        columnSize, rowSize );
                % Cropped complex data:
                case 1 + 2 + 4 + 8 + 16
                    bandData=zeros(rowSize.*columnSize.*multiplicity,1);
                    sofar=1;

                    % TODO check cropping rows and columns? Is this right??
                    firstColumnsSkipBytes = ...
                        uint32( (limits.columns(1) - 1) * bytePerSample );
                    
                    nVals = multiplicity*columnSize*1;
                    
                    for jj=1:rowSize
                    rowOff = limits.rows(1) + jj - 1; % 1507 * (9-1) + 
                    fseek(fId, ...
                        tIfd.StripOffsets(rowOff) + firstColumnsSkipBytes,...
                        'bof');
                    r=fread(fId, ...
                            nVals, ...
                            freadFormat, 0 ...
                            );
                    bandData(sofar:sofar+nVals-1)=r;
                    sofar=sofar+nVals;
                    end
                    
                    bandData =  single(bandData(1:2:end)) ...
                                + 1i.*single(bandData(2:2:end));
                    imageData(:,:,iBand) = ...
                        reshape(bandData,outputSize(iBand,1),outputSize(iBand,2));
            end  % switch
        end % for iBand=1:nBands
    end % read_image_data_from_stream

    % Here is a list of all of the properties accessed from the header in the code above:
    % header.ifdCount
    % header.ifds

    % Here is a list of all of the properties accessed from tIfd in the code above:
    % tIfd.SampleFormat
    % tIfd.ImageWidth
    % tIfd.ImageLength
    % tIfd.BitsPerSample
    % tIfd.StripByteCounts
    % tIfd.StripOffsets
    % tIfd.Compression


    function [status] = write( filepath, data )
        
        header = OI.Data.TiffHeader();

        % Each 2D array in the 3rd dimension of data is a separate band
        % Each band is a separate IFD
        nBands = size(data,3);
        header.ifdCount = nBands;
        header.ifds = OI.Data.TiffIfd();

        % determine the data type, and corresponding Tiff specification SampleFormat code
        % 1 = unsigned integer
        % 2 = twos complement signed integer
        % 3 = IEEE floating point
        % 4 = undefined
        % 5 = complex integer
        % 6 = complex IEEE floating point

        dataType = class(data);
        switch dataType
        case {'uint8', 'uint16', 'uint32', 'uint64'}
            sampleFormat = 1;
        case {'int8', 'int16', 'int32', 'int64'}
            sampleFormat = 2;
        case {'single', 'double'}
            sampleFormat = 3;
        otherwise
            error('Unsupported data type: %s', dataType);
        end
        % add the complex flag if necessary
        if ~isreal(data)
            sampleFormat = sampleFormat * 2;
            isComplex = true;
        end

        % determine the number of bits per sample
        switch dataType
        case {'uint8', 'int8'}
            bitsPerSample = 8;
        case {'uint16', 'int16'}
            bitsPerSample = 16;
        case {'uint32', 'int32', 'single'}
            bitsPerSample = 32;
        case {'uint64', 'int64', 'double'}
            bitsPerSample = 64;
        otherwise
            error('Unsupported data type: %s', dataType);
        end

        fId = fopen( filepath , 'w' );
        bytesForHeader = header.write_header( fId );
        
        % offset to next IFD
        nextIfd = bytesForHeader;
    
        % populate each IFD in the header
        for bandInd = 1:nBands
            tIfd = OI.Data.TiffIfd();

            % get the width (# rows) and length (# columns) of this band
            % confusingly, the 2D arrays are transposed
            % tiff was designed for old paper document scanners
            imageWidth = size(data(:,:,bandInd),1);
            imageLength = size(data(:,:,bandInd),2);

            % each column (1st dimension) of data is:
            % 1. a seperate column in the data file data(:,stripInd);
            % 2. a separate strip in the tiff file tIfd.StripOffsets(stripInd);
            % there are thus imageLength strips, equal to size(data,2);
            % each strip is imageWidth pixels wide, equal to size(data,1);

            % populate the IFD
            tIfd.SampleFormat = sampleFormat;
            tIfd.ImageWidth = imageWidth;
            tIfd.ImageLength = imageLength;
            tIfd.BitsPerSample = bitsPerSample;

            % we'll have to come back and update this later
            % for now we need to know the size of stripOffsets
            % and stripByteCounts
            tIfd.StripByteCounts = ones(1, imageLength) ... 
                .* imageWidth * imageLength * bitsPerSample / 8;
            tIfd.StripOffsets = ones(1, imageLength);
            tIfd.Compression = 1;

            % populate the header
            header.ifds(bandInd) = tIfd;

        end

        allIfdBytes = [];
        for bandInd = 1:nBands
            header.ifds(bandInd).NextIfd = nextIfd;
            thisIfdBytes = header.ifds(bandInd);
            allIfdBytes = [allIfdBytes thisIfdBytes];
            nextIfd = nextIfd + length(thisIfdBytes);
        end

        % get the total number of bytes including the IFDs
        bytesForIfds = length(allIfdBytes);

        for bandInd = 1:nBands
            header.ifds(bandInd).StripOffsets = ...
                header.ifds(bandInd).StripOffsets + ...
                bytesForHeader + ...
                bytesForIfds;
            % write the IFD
            bytes = tIfd.write_ifd( fId , []);
        end
        % write the header
        % header.write_header(fId);

        % write the data
        fwrite(fId, data, dataType);

        fclose(fId);
        status = 0;
    end % write
    %     % populate each IFD in the header
    %     for bandInd = 1:nBands
    %         tIfd = OI.Data.TiffIfd();
    %         % populate the IFD
    %         tIfd.SampleFormat = sampleFormat;
    %         tIfd.ImageWidth = size(data,1); % tiffs are transposed
    %         tIfd.ImageLength = size(data,2); % old document scanner format!
    %         tIfd.BitsPerSample = 
    %         tIfd.StripByteCounts = size(data,1)*size(data,2)*4;
    %         tIfd.StripOffsets = 8;
    %         tIfd.Compression = 1;
    %         % populate the header
    %         header.ifds(bandInd) = tIfd;
    %     end

        

    %     % populate each IFD in the header
    %     for bandInd = 1:nBands
    %         tIfd = OI.Data.TiffIfd();
    %         % populate the IFD


    %         tIfd.SampleFormat

    %         % populate the header
    %         header.ifds(bandInd) = tIfd;
    %     end

    %     % % populate the header
    %     % header.ifdCount = size(data,3);
    %     % header.ifds = OI.Data.TiffIfd();
    %     % for iBand=1:header.ifdCount
    %     %     header.ifds(iBand) = OI.Data.TiffHeader.IFD();
    %     %     header.ifds(iBand).ImageWidth = size(data,1); % tiffs are transposed
    %     %     header.ifds(iBand).ImageLength = size(data,2); % old document scanner format!
    %     %     header.ifds(iBand).BitsPerSample = 32;
    %     %     header.ifds(iBand).Compression = 1;
    %     %     header.ifds(iBand).PhotometricInterpretation = 1;
    %     %     header.ifds(iBand).SamplesPerPixel = 1;
    %     %     header.ifds(iBand).RowsPerStrip = size(data,1);
    %     %     header.ifds(iBand).StripByteCounts = size(data,1).*size(data,2).*4;
    %     %     header.ifds(iBand).StripOffsets = 8;
    %     %     header.ifds(iBand).SampleFormat = 3;
    %     % end

    %     header = OI.Data.TiffHeader.write_to_stream( fId );
    %     if header.ifdCount > 0
    %         data = OI.Data.Tiff.read_image_data_from_stream(fId, header);
    %     end
    %     fclose( fId );
    % end % =



end % methods

end % classdef