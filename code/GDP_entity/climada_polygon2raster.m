function border_mask = climada_polygon2raster(borders, raster_size, save_on)
% create raster (mask with 1 for inside and on polygon, and zeros for
% outside polygon) based on polygon-input for a specific raster size
% NAME:
%   climada_polygon2raster
% PURPOSE:
%   create raster (mask with 1 for inside and on polygon, and zeros for
%   outside polygon) based on polygon-input for a specific raster size
%   previous: diverse
%   next: diverse
% CALLING SEQUENCE:
%   border_mask = climada_polygon2raster(borders, raster_size)
% EXAMPLE:
%   border_mask = climada_polygon2raster(borders, raster_size)
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   borders     : structure (fields with polygons and names) from climada plot
%                 world map
%   raster_size : size of requested matrix (e.g. [336 864], 50km
%   resolution); [1680 4320], 10km; [168 432], 100km
% OUTPUTS:
%  border_mask  : structure with following fields
%  .mask        : 243 matrices (for each country) masking 1 for
%                 within country and zero for out of country
%  .name        : name of all countries
%  .world_mask  : world mask (all countries), 1 for land, 0 for sea
%  .lon_range   : longitudinal range of masks
%  .lat_range   : latitudinal range of masks
%  .resolution_x: resolution in x direction in degree
%  .resolution_y: resolution in y direction in degree
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20120730
% David N. Bresch, david.bresch@gmail.com, 20141229, revision
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables
if ~exist('borders'    , 'var'), borders     = []; end
if ~exist('raster_size', 'var'), raster_size = []; end
if ~exist('save_on'    , 'var'), save_on     = []; end

% set modul data directory
modul_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];


% load the borders file, if not given
if isempty(borders)
    borders = climada_load_world_borders;
end
if isempty(borders), return, end


if isempty(raster_size)
    fprintf('Please indicate size of requested raster\n\n')
    border_mask = [];
    return
end

% size or requested raster, limits of world map, and meshgrid creation
raster_x     = raster_size(1);
raster_y     = raster_size(2);
x_range      = [-180 180];
y_range      = [ -65  75];
resolution_x = sum(abs(x_range))/raster_y;
resolution_y = sum(abs(y_range))/raster_x;
[X, Y ]      = meshgrid(x_range(1)+resolution_x/2: resolution_x: x_range(2)-resolution_x/2, ...
                        y_range(1)+resolution_y/2: resolution_y: y_range(2)-resolution_y/2);

% waitbar
if climada_global.waitbar,h = waitbar(0);end

% go through each country and their polygons
for country_i = 1:length(borders.poly)
    % create empty sparse matrix for country masks
    mask{country_i} = sparse(raster_x, raster_y);
        
    n_islands = length(borders.poly{country_i}.lon);
    msgstr    = sprintf('Creating 1 mask for %d islands within %s...',n_islands, borders.name{country_i});
    
    for island_i = 1:n_islands
        
        if climada_global.waitbar,waitbar(island_i/n_islands, h, msgstr);end
        %waitbar(island_i/n_islands, h, msgstr); % update waitbar)
        
        lon_range = [min(borders.poly{country_i}.lon{island_i})...
                     max(borders.poly{country_i}.lon{island_i})];
                 
        for ii = 1:1:raster_y
            if X(1,ii)>= lon_range(1) && X(1,ii) <= lon_range(2)
                a  = inpoly([X(:,ii) Y(:,1)],...
                        [borders.poly{country_i}.lon{island_i}'...
                         borders.poly{country_i}.lat{island_i}']);
                mask{country_i}(a,ii) = 1;    
                %fprintf('%d: %d pixels found\n',ii, sum(a))
            end  
        end
    end %island_i
    if ~any(mask{country_i}) %island or entire country too small 
        lon = mean(borders.poly{country_i}.lon{island_i});
        lat = mean(borders.poly{country_i}.lat{island_i});
        [~,indx] = min(abs(X(1,:)-lon));
        [~,indy] = min(abs(Y(:,1)-lat));
        mask{country_i}(indy,indx) = 1;    
    end
end %country_i

if climada_global.waitbar,close(h);end % close waitbar


% creating world mask, 1 for on land, 0 for sea
world_mask = zeros(size(mask{1}));
for country_i = 1:length(mask)
    world_mask = world_mask + mask{country_i};
end
world_mask(world_mask>1) = 1;
        
% put all in one structure
border_mask.mask         = mask;
border_mask.name         = borders.name;
border_mask.world_mask   = world_mask;
border_mask.lon_range    = x_range;
border_mask.lat_range    = y_range;
border_mask.resolution_x = resolution_x;
border_mask.resolution_y = resolution_y;

resolution_km = round(climada_geo_distance(0,0,resolution_x,0)/1000);
resolution_km = ceil(resolution_km/5)*5;

if save_on
    filename = [modul_data_dir filesep 'border_mask_' int2str(resolution_km) 'km.mat'];
    save(filename,'border_mask')
    fprintf('border_mask structure saved in %s\n',filename)
end




