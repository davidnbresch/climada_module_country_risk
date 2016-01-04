function centroids = climada_matrix2centroid(matrix_buffer, lon_range, lat_range, country_name)
% create centroids (structure) out of matrix_buffer and according range of
% longitude and latitude
% NAME:
%   climada_matrix2centroid
% PURPOSE:
%   create centroids based on matrix_hollowout or matrix_buffer
%   previous: climada_mask_buffer_hollow
%   next    : create entity, diverse
% CALLING SEQUENCE:
%   centroids = climada_matrix2centroid(matrix_buffer, lon_range, lat_range, 
%   country_name)
% EXAMPLE:
%   centroids = climada_matrix2centroid(matrix_buffer, lon_range, lat_range)
% INPUTS:
%   matrix_buffer   : matrix masking 1 for on land (or higher values if more 
%                     than one country), zero for on sea, and max value for bufferzone
%   lon_range       : range of Longitude of matrix_buffer
%   lat_range       : range of Latitude of matrix_buffer
% OPTIONAL INPUT PARAMETERS:
%   country_name    : country name for countries in matrix_buffer
% OUTPUTS:
%   centroids structure with following fields
%      .centroid_ID : unambiguous ID number for each centroid
%      .lon   : Longitude of centroid
%      .lat    : Latitude of centroid
%      .onLand      : 1 for on land (or higher if more than one country, 
%                     zero for on sea, and max value for bufferzone
%      .country_name: country_name for each centroid, enhanced with 
%                     'buffer' and 'sea'
%      .comment     : information about centroids
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140205
%-


global climada_global
if ~climada_init_vars,return;end % init/import global variables

if ~exist('matrix_buffer'      , 'var'), centroids           = []; return; end
if ~exist('lon_range'          , 'var'), centroids           = []; return; end
if ~exist('lat_range'          , 'var'), centroids           = []; return; end
if ~exist('country_name'       , 'var'), country_name        = []; end

if ~iscell(country_name)
    country_name = {country_name};
end

resolution_x   = sum(abs(lon_range))/size(matrix_buffer,2);
resolution_y   = sum(abs(lat_range))/size(matrix_buffer,1);
[X, Y ]        = meshgrid(lon_range(1)+resolution_x/2: resolution_x: lon_range(2)-resolution_x/2, ...
                          lat_range(1)+resolution_y/2: resolution_y: lat_range(2)-resolution_y/2);

% centroids on land and within buffer zone
% on land        : value 1 until length of countries
% within buffer  : max(uni_val)
% out of interest: 0
uni_val     = full(unique(matrix_buffer));
uni_val(uni_val == 0) = [];
Longitude   = [];
Latitude    = [];
onLand      = [];
country_n   = [];
   
for i = 1:length(uni_val)  
    buffer_index = matrix_buffer == uni_val(i);
    Longitude   = [Longitude X(buffer_index)'];
    Latitude    = [Latitude  Y(buffer_index)'];
    onLand      = [onLand  zeros(1,length(Y(buffer_index)'))+uni_val(i)];
    
    if ~isempty(country_name)
        if i == length(uni_val) && length(uni_val)>1
            country_n    = [country_n repmat({'buffer'},1,length(Y(buffer_index)')) ];
        else
            country_n    = [country_n repmat(country_name(uni_val(i)),1,length(Y(buffer_index)')) ];
        end
    end
end
if isempty(country_name)
    country_n = repmat({''}, 1, length(Longitude)); 
end
if ~iscell(country_name)
    country_name = {country_name};
end

% downscale to requested resolution and take centroids from sea within
% 1000 km of region
matrix_buffer(matrix_buffer>1)= 1;
matrix_structure.values       = matrix_buffer;
matrix_structure.lon_range    = lon_range;
matrix_structure.lat_range    = lat_range;
% 5 x input resolution for regular grid (e.g. 50 km for input resolution 10 km)
resolution_km_addon_centroids = climada_geo_distance(0,0,resolution_x,0)/1000*5;
[low_resolution_matrix, X, Y] = climada_resolution_downscale(matrix_structure, resolution_km_addon_centroids, 'unique');
% [low_resolution_matrix, X, Y] = climada_resolution_downscale(matrix_structure, 500, 'unique');
sea_index = ~low_resolution_matrix.values >0 ;

%within 1000 km of land, 10? ~1000km
% distance = climada_geo_distance(0,0,10,0)/1000;
dist     = 1; %~100 km
landpoly = [min(Longitude)-dist  min(Latitude)-dist;
            min(Longitude)-dist  max(Latitude)+dist;
            max(Longitude)+dist  max(Latitude)+dist;
            max(Longitude)+dist  min(Latitude)-dist];
Longitude_s   = X(sea_index)';
Latitude_s    = Y(sea_index)';
cn            = inpoly([Longitude_s' Latitude_s'],landpoly);
Longitude     = [Longitude Longitude_s(cn)];
Latitude      = [Latitude  Latitude_s(cn)];
onLand        = [onLand    zeros(1,length(Longitude_s(cn)))];
country_n     = [country_n repmat({'grid'},1,length(Longitude_s(cn))) ];  

% put all in centroids structure
centroids.centroid_ID = 1:length(Longitude);     
centroids.lon    = Longitude;
centroids.lat     = Latitude;
centroids.onLand       = onLand;
centroids.country_name = country_n;

no_onLand = sum(centroids.onLand <  max(centroids.onLand) & centroids.onLand>0 );
no_buffer = sum(centroids.onLand == max(centroids.onLand));
no_sea    = sum(centroids.onLand == 0);
fprintf('\t\t --> %d centroids (%d on land and within buffer, %d outside)\n', length(centroids.lon), no_buffer, no_sea)

centroids.comment = sprintf('%s',country_name{1});


return
                          
               


    

