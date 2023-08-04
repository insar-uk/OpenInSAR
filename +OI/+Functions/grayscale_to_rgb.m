
    function I = grayscale_to_rgb( grayImage, cmap, crange )
        if nargin == 2
            crange = [min(grayImage(:)), max(grayImage(:))];
        end
        minValue = double(crange(1));
        maxValue = double(crange(2));
        normalized_array = (grayImage - minValue) / (maxValue - minValue);
        
        % Get the colormap and rescale it to match the grayscale image limits
        cmapIndex = round(1 + (size(cmap, 1) - 1) * normalized_array);
        cmapIndex = max(cmapIndex, 1);
        cmapIndex = min(cmapIndex, size(cmap, 1));
        
        % Convert the grayscale image to an RGB image using the colormap
        I = ind2rgb(cmapIndex, cmap);
    end