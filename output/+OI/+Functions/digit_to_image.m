% function img = digit_to_image( digit )
%
% if digit==0
%     digit=10;
% end
%
% % Create bars
% [TL, TR, T, M, BL, BR, B, blankImg] = deal(zeros(7,5));
% TL(2:3,1)=1;
% TR(2:3,5)=1;
% T(1,2:4)=1;
% M(4,2:4)=1;
% BL(5:6,1)=1;
% BR(5:6,5)=1;
% B(7,2:4)=1;
%
% % Create digits
% digits{1} = TR + BR;
% digits{2} = T + M + B + TR + Bl;
% digits{3} = digits{1} + T + M + B;
% digits{4} = TL + TR + M + B;
% digits{5} = digits{3} + TL + B;
% digits{6} = digits{3} + TL;
% digits{7} = digits{1} + TR + BR;
% digits{8} = T + M + B + TL + TR + BL + BR;
% digits{9} = digits{3} + TL + TR;
%
% img = imresize(digits{digit},[100,100]);

function img = digit_to_image(digit, padding)

% Convert the input digit to a string
digit_str = num2str(digit);

% Create bars
[TL, TR, T, M, BL, BR, B, VM, blankImg] = deal(zeros(9, 7));
TL(2:4, 2) = 1;
TR(2:4, 6) = 1;
T(2, 2:6) = 1;
M(5, 2:6) = 1;
BL(5:7, 2) = 1;
BR(5:7, 6) = 1;
B(8, 2:6) = 1;

VM(2:8,4)=1;

% Create digits
digits{1} = VM;
digits{2} = T + M + B + TR + BL;
digits{3} = TR + BR + T + M + B;
digits{4} = TL + TR + M + BR;
digits{5} = T + M + B + TL + BR;
digits{6} = T + TL + BL + M + B + BR;
digits{7} = TR + BR + T;
digits{8} = T + M + B + TL + TR + BL + BR;
digits{9} = digits{3} + TL;
digits{10} = digits{8} - M;
digits{11} = M;
digits{12} = blankImg;

% Initialize the final image
img = zeros(9,7 * length(digit_str) );
% Process each character in the input digit string
for i = 1:length(digit_str)

    if digit_str(i) == '-'
        char_digit = 11;
    else
        char_digit = str2double(digit_str(i));
    end

    if char_digit==0
        char_digit = 10;
    end

    % Handle digits outside the range of 0-9
    if isnan(char_digit)
        error('Invalid digit. Please enter a digit between 0 and 9.');
    end

    % Concatenate the binary images horizontally
    if i == 1 || isempty(img)
        img = digits{char_digit};
    else
        img(:,(1:7) + (i-1) * 7) = digits{char_digit};
    end
end

if nargin>1
    img = [ blankImg img blankImg ];
end
% Resize the final image to 100 pixels in height and preserve the aspect ratio
img = imresize(img, [100, NaN],'nearest');

% Show the binary image
%figure;
%imshow(img);
%title(['Binary Image of Digit ', num2str(digit)]);
end
