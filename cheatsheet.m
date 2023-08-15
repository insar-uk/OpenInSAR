%% Common patterns and use cases

%% Loading the engine
engine=OpenInSAR().engine;

%% Find the identifying paramaters for a data object
blockGeocoding = OI.Data.BlockGeocodedCoordinates();
blockGeocoding.identifying_paramaters

%% Find a block
closestBlock = blockMap.find_closest(50.92,0.96);

%% Specify and load block data
blockObj = OI.Data.Block().configure( ...
'POLARISATION', 'VV', ...
'STACK',num2str( 1 ), ...
'BLOCK', num2str( 35 ) ...
).identify( engine );
blockData = engine.load( blockObj );

%% Get coregistration information
coregOffsets = OI.Data.CoregOffsets();
coregOffsets.STACK = '1';
coregOffsets.REFERENCE_SEGMENT_INDEX = '2';
azRgOffsets = engine.load( coregOffsets );

%% Get geocoded coordinates for a block
blockGeocoding = OI.Data.BlockGeocodedCoordinates();
blockGeocoding.STACK='1';
blockGeocoding.BLOCK='35';