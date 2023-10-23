classdef TiffHeader

properties

endian = 'l'; % 'l' for little endian, 'b' for big endian
isBigTiff = false; % true for big tiff, false for tiff
ifdCount = 0; % number of ifds in file
ifdOffsets = []; % offset of each ifd in file
ifds = []; % array of ifds

end

methods
    function obj = TiffHeader()
    end


function bytes = write_header(this, fid)
    % write_header - write a tiff header to a file
    %   bytes = write_header(this)
    %   bytes is the number of bytes written to the file
    %   this is the tiff_header object
    %   this.filename is the file to write to
    %   this.ifds is the array of tiff_ifd objects to write
    %   this.ifdOffsets is the array of offsets to the ifds
    %   this.ifdCount is the number of ifds to write
    %   this.endian is the endian code to write
    %   this.isBigTiff is the tiff version code to write

    % open the file
    if (fid == -1)
        error("FILE NO GOOD");
    end

    % write the endian code
    fwrite(fid,this.endian,'uchar');
    % write the tiff version code
    if (this.isBigTiff)
        fwrite(fid,43,'uint8');
    else
        fwrite(fid,42,'uint8');
    end
    fwrite(fid,0,'uint8'); % skip a byte

    % write the ifds
    bytes = 8; % 8 bytes for the header


end % write_header
end

methods ( Static = true )

function this = from_stream( fId )
    % read tiff header from stream
    % fId: file id of open stream

    this = OI.Data.TiffHeader(); % create object

    % first two chars: little endian or big endian byte structure
    endianCode = fread(fId,2,'char=>char')';
    switch (endianCode)
        case 'II'
            this.endian = 'l';
        case 'MM'
            this.endian = 'b';
        otherwise
            error("bad tiff file format")
    end
    % next char: tiff version number 
    tiffTypeCode = fread(fId,1,'uint8');
    switch (tiffTypeCode)
        case 42
            this.isBigTiff = false;
        case 43
            this.isBigTiff = true;
        otherwise 
            error("bad tiff file format")
    end
    fread(fId,1,'uint8'); %skip a byte
        
    % each ifd points to next ifd until one points to 0.
    nextOffset = fread(fId,1,'*uint32');
    this.ifdOffsets(1) = nextOffset;
    
    % while we have ifd locations
    while ( nextOffset )
        fseek(fId,nextOffset,'bof'); % move to ifd offset
        this.ifdCount=this.ifdCount+1; % increment ifd count
        % add the IFD to an array, some ugliness is needed for obj arrays
        % to work in mat/oct
        if this.ifdCount == 1
            this.ifds = OI.Data.TiffIfd( fId, nextOffset);
        else
            this.ifds( this.ifdCount ) = ...
                OI.Data.TiffIfd( fId, nextOffset); % read
        end
        nextOffset = this.ifds( this.ifdCount ).NextIfd; %get next
        this.ifdOffsets( this.ifdCount + 1 ) = nextOffset; % save next 
    end
end % from_stream



end % methods

end % classdef