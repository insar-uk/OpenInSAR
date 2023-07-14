function osvStruct = parse_s1_orbit_file( T )
% where T is the text content of the POE file.

%Find the relevant entries for our ~90min? Absolute Orbit Number
%Pick out the relevant section of the POE file.
% The relevant section of the file containing orbital state vectors is extracted using string manipulation functions such as OI.Functions.strfind1, strfind, and size.
% The location of the tags in the text string is identified using strfind.
% Delimiters such as <, >, and / are marked with zeros using a logical array called Delimeters.
% The type of delimiter is identified as either an opening tag, closing tag, or value using an array called Comp.
% The name and value of each tag is extracted from the text string using string manipulation functions and stored in a temporary structure called tempStruct.
% The resulting structure tempStruct contains the relevant orbital state vectors.
%Pick out the relevant orbital state vectors
startline=OI.Functions.strfind1(T,'<OSV>',1);
endline=OI.Functions.strfind1(T,'<OSV>',-1);
T=T(startline:endline);
            
%Find the location of the tags
tagclose=strfind(T,'</');
tagleft=strfind(T,'<');
tagright=strfind(T,'>');

%init
Delimeters=zeros(size(T),'logical');
Comp=zeros(size(T),'int8');
%Mark location of delimeters
Delimeters(tagclose)=1;
Delimeters(tagleft)=1;
Delimeters(tagright)=1;
%Mark location and meaning of delimeters
Comp(tagleft)=1;
Comp(tagright)=2;
Comp(tagclose)=3;
%Indices of delimeters
tagindices=find(Delimeters);

%init
Parents={'';''};
repeatssofar=0;

%loop through delimeters
for i=1:size(tagindices,2)-1  
    
    %Some logic to find values and names based on the delimiters
    if Comp(tagindices(i))==1
        if Comp(tagindices(i+1))==2
            tagtoadd=T(tagindices(i)+1:tagindices(i+1)-1);
            piv=strfind(tagtoadd,' ')-1;
            if ~isempty(piv)
                tagtoadd=tagtoadd(1:piv);
            end

            if strcmp(tagtoadd,'OSV')
            repeatssofar=repeatssofar+1;
            end

            Parents{2}=tagtoadd;

        end

        if Comp(tagindices(i+2))==3
            value=T(tagindices(i+1)+1:tagindices(i+2)-1);
            osvStruct.OSV(repeatssofar).(Parents{2})=value;
        end
    end

    %If it closed the tag, get rid of the last parent.
    if Comp(tagindices(i))==3
        Parents(end)=[];
    end
end% for loop

osvStruct = osvStruct.OSV;

end%parse_s1_orbit_file