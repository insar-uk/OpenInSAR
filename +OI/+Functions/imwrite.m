function imwrite( dataArray, path, doNormalise )

    if nargin == 3 && doNormalise
        % for each channel
        for i = size( dataArray, 3 ) : -1 : 1
            % get max and min values
            maxVal = max( dataArray(:) );
            minVal = min( dataArray(:) );
            % normalize data
            dataArray(:,:,i) = ( dataArray(:,:,i) - minVal ) / ( maxVal - minVal );
            % convert to 8 bit
            dataArrayOut(:,:,i) = uint8( dataArray(:,:,i) * 255 );
        end
    else
        dataArrayOut = dataArray;
    end
    
    imwrite( dataArrayOut, path );
end