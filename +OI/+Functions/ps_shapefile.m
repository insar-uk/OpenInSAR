function ps_shapefile(filename,latArray,lonArray,dataArray,imageDates,h,v,c)

OI.Functions.mkdirs(filename);
% add '.shp' to filename if it doesn't already have it
if numel(filename)>4 && ~strcmp(filename(end-3:end),'.shp')
    filename=[filename '.shp'];
end

% if ~isempty(dataArray)
%     % Make a template structure to speed things up
% end

nP=numel(latArray);
nT=size(dataArray,2);
for ii=nP:-1:1
    DataStructure(ii).Geometry='Point';
    DataStructure(ii).Lat=latArray(ii);
    DataStructure(ii).Lon=lonArray(ii);
    DataStructure(ii).CODE=['p' num2str(ii)];
    DataStructure(ii).HEIGHT=h(ii);
    DataStructure(ii).H_STDEV=0;
    DataStructure(ii).VEL=v(ii);
    DataStructure(ii).V_STDEV=0;
    DataStructure(ii).COHERENCE=c(ii);
    DataStructure(ii).EFF_AREA=0;

    if ~isempty(dataArray)
        for jj=1:nT
           DataStructure(ii).(['D' imageDates{jj}])=dataArray(ii,jj);
        end
    end
end

OI.Functions.buffer_shpwrite(DataStructure,filename);