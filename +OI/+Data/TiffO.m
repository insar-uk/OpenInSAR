classdef Tiff
    
properties
    m_filepath
    m_header
    m_limits
    data
end

properties (Constant = true)
    formatSpec = [  "uint";
                    "int";
                    "float";
                    "?";
                    "int";
                    "float" ];
end


methods
    
function [this] = read_tiff(varargin)
   this = this.parse_inputs(varargin);
   this.m_header = tiff_header(this.m_filepath);
   if this.m_header.ifdCount == 0
      return; 
   end
   this.data = read_tiff.read_image_data(this.m_header,this.m_limits);
   return;
end

function this = parse_inputs(varargin)
    args = varargin;
    this=args{1};
    args(1)=[];
    args=args{1};
    
    this.m_limits = struct("bands",[],"rows",[],"columns",[]);
    switch (numel(args))
        case 1
            if (~isstring(args{1}) && ~ischar(args{1}))
                error("bad input data type")
            end
        case 2
            if (isnumeric(args{2}) && numel(args{2}) == 4)
                limitArray = args{2};
                this.m_limits.rows = limitArray(1:2);
                this.m_limits.columns = limitArray(3:4);
            elseif (isstruct(args{2}))
                this.m_limits = args{2};
            else
                error("bad second arg")
            end
        case 5
            this.m_limits.rows(1)=args{2};
            this.m_limits.rows(2)=args{3};
            this.m_limits.columns(1)=args{4};
            this.m_limits.columns(2)=args{5};
        otherwise
            error("dont understand your inputs");
    end
    this.m_filepath = char(args{1});
end
end


methods (Static =  true)
    
function imageData = read_image_data(header,limits)
    % helper function
    isComplex =@(ii) (header.ifds(ii).SampleFormat>4);
    
    % get the size of each image from the IFDs
    nBands = numel(header.ifds);
    outputSize=zeros(nBands,2);
    typeSpec = cell(nBands);
    for iBand=1:nBands
        tIfd = header.ifds(iBand);
        
        isCropped = ~isempty(limits.bands)  ...
            || ~isempty(limits.rows)        ...
            || ~isempty(limits.columns); 
                
        if (~isCropped)
            outputSize(iBand,1) = tIfd.ImageLength;
            outputSize(iBand,2) = tIfd.ImageWidth;
        else
            %fprintf(1,"wifth %i\n",tIfd.ImageWidth);
            %limits.rows(1)
            skipVals = int64(tIfd.ImageWidth).*(limits.rows(1)-1);
            skipVals = skipVals + limits.columns(1);
            outputSize(iBand,2) = limits.rows(2)-limits.rows(1)+1;
            outputSize(iBand,1) = limits.columns(2)-limits.columns(1)+1;
        end
        outputSize;
        
        tType = char(read_tiff.formatSpec( tIfd.SampleFormat ));
        bits = int64(tIfd.BitsPerSample)/int64(1+isComplex(iBand));
        typeSpec{iBand}= ...
            [tType, num2str(bits,'%i')];
    end
    
    % if they're all equal we can speed things up...
    nUnique = @(x) numel(unique(x));
    rSizes = outputSize(:,2);
    cSizes = outputSize(:,1);
    isEqualSizedBands = nUnique(rSizes).*nUnique(cSizes) == 1;
    isEqualType = all((cellfun(@(x) strcmp(x,typeSpec{1}),typeSpec)));
    % ...by making an X * Y * Z matrix instead of VLAs for output
    % Just need the spec first
    if ( isEqualSizedBands && isEqualType )
        isUniformBands = true;
        imageData = ...
            zeros(outputSize(1,1),outputSize(1,2),nBands, typeSpec{iBand});
    else
        isUniformBands = false;
        imageData = cell(nBands);
        for iBand=1:nBands
            imageData{iBand}=zeros(outputSize(iBand,1:2),typeSpec{iBand});
        end
    end
    
    % open file
    fid = fopen(header.filename);
    
    % read each image in each IFD
    for iBand=1:nBands
        tIfd = header.ifds(iBand);
        columnSize = outputSize(iBand,1);
        rowSize = outputSize(iBand,2);
        tIfd(iBand).StripByteCounts(1);
        
        
        % for performance have a lot of different read scenarios to choose
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
        
        fseek(fid,header.ifds(iBand).StripOffsets(1),'bof');
        bytePerSample = int64(tIfd.BitsPerSample)/int64(8);
        fseek(fid,skipVals.*bytePerSample,0);
        
        %{
        while skipVals>0
            skipHere = min( skipVals );
            
        end
        %}
        
        switch (flagValue)
            % cropped section of uniform uncompressed data:
            case 1 + 2 + 4

            % uncompressed data with uniform output :
            case 1 + 2 + 8
                bandData=fread( fid, ...
                                multiplicity*rowSize*columnSize, ...
                                freadFormat                              );
                imageData(:,:,iBand)=reshape(bandData,rowSize,columnSize);
            case 1 + 2 + 8 + 16
                bandData=fread( fid, ...
                                multiplicity*rowSize*columnSize, ...
                                freadFormat                              );
                bandData =  single(bandData(1:2:end)) ...
                            + 1i.*single(bandData(2:2:end));
                imageData(:,:,iBand)= reshape(bandData,rowSize,columnSize);
            case 1 + 2 + 4 + 8 + 16
                bandData=zeros(rowSize.*columnSize.*multiplicity,1);
                sofar=1;
                %1507 * (9-1) + 
                rowOff = limits.rows(1);% * tIfd.ImageWidth;
                firstColumnsSkipBytes = ...
                    uint32( limits.columns(1) * bytePerSample );
                fseek(fid, ...
                      tIfd.StripOffsets(rowOff) + firstColumnsSkipBytes,...
                      'bof');
                  
                for jj=1:rowSize
                    
                nVals = multiplicity*columnSize*1;
                nSkips = multiplicity*double(tIfd.ImageWidth-columnSize);
                %nSkips = multiplicity*rowSize*columnSize - nVals+1;
                r=fread( fid, ...
                                nVals, ...
                                freadFormat, 0 ...
                                );
                bandData(sofar:sofar+nVals-1)=r;
                            sofar=sofar+nVals;
                            %rowOff=(1507 * (9-1) + jj - 1);% * tIfd.ImageWidth;
                rowOff = limits.rows(1) + jj - 1; % 1507 * (9-1) + 
                fseek(fid,tIfd.StripOffsets(rowOff) + firstColumnsSkipBytes ,'bof');
                end
                 

                bandData =  single(bandData(1:2:end)) ...
                            + 1i.*single(bandData(2:2:end));
                imageData(:,:,iBand)= reshape(bandData,outputSize(iBand,1),outputSize(iBand,2));
        end
    end % for iBand=1:nBands
    fclose(fid);
end % function read_tiff

function save_tiff( filename, data )
    % determine the type of data, write the header, and write the data
    % data can be a 2D or 3D matrix
    % if 3D, the first dimension is the band
    % if 2D, the data is assumed to be a single band
    % if the data is complex, the real and imaginary parts are written
    % as separate bands

    % determine the type of data
    if ( isreal(data) )
        isComplex = false;
    else
        isComplex = true;
    end
    
    % open the file
    fid = fopen( filename, 'w' );

    % write the header
    write_tiff_header( fid, data, isComplex );

    % write the data
    write_tiff_data( filename, data, isComplex );

    % close the file
    fclose(fid);
    

end % function save_tiff

function write_tiff_header( fid, data, isComplex )
    % The info required to write the header is:
    %   - the number of bands
    %   - the number of rows
    %   - the number of columns
    %   - the type of data
    %   - whether the data is complex
    %   - the number of bytes per sample
    %   - the number of samples per pixel
    %   - the number of rows per strip
    %   - the number of bytes per strip
    %   - the number of strips
    %   - the offset to the first strip
    %   - the offset to the next IFD
    %   - the number of entries in the IFD
    
    % determine the number of bands
    



end % function save_tiff

end % methods (Static)

end % classdef read_tiff

