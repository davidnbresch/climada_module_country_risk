function [centroids, entity] = climada_create_centroids_entity_base(country_name, asset_resolution_km, hollowout,...
    check_for_groups, night_light, pp, borders, border_mask, ...
    check_figure, save_on_entity_centroids, no_wbar)
% NAME:
%   climada_create_centroids_entity_base
% PURPOSE:
%   create centroids and entity for a specific country, distribute assets
%   and value according to night light intensities
% CALLING SEQUENCE:
%   [centroids entity] =
%   climada_create_centroids_entity_base(country_name,asset_resolution_km,...
%       hollowout,check_for_groups,night_light,pp,borders,border_mask,...
%       check_figure,save_on_entity_centroids,no_wbar)
% EXAMPLE:
%   [centroids entity] = climada_create_centroids_entity_base;
%   [centroids entity] = climada_create_centroids_entity_base('Bangladesh', 10);
% INPUTS:
%   country_name: the name of the country or an ISO3 country code (like
%       'CHE'), see climada_check_country_name
%   asset_resolution_km:resolution for centroids and assets within entity,
%       default 10km
%   check_for_groups: if country is within a group (e.g. China with
%       Taiwan), to combine the two or more regions, default do not check
%       DISABLED, run the code multiple times (see also climada module
%       country risk)
%   hollowout: hollwout country, so to take only points close to the coast
%       line, default do not hollowout
%   night_light: structure with night light intensities, automatically load
%       from mat or read from default file
%   pp: nonlinear transformation function of night lights to values (e.g.
%       pp = [0 1 0]; y = 0*x^2 + 1*x + 0
%   borders: border structure (with name, polygon for every country)
%   border_mask: structure with all country masks (zeros and ones)
%   check_figure: set to 1 to visualize figures, default 1
%   save_on_entity_centroids: to save entity and centroids automatically,
%       default 1
%   no_wbar: 1 to suppress waitbars
% OUTPUTS:
%   centroids: a structure with fields centroid_ID, Latitude, Longitude,
%       onLand, country_name, comment for each centroid
%   entity: an entity structure with fields assets, damagefunctions,
%       measures, discount. Asset values from an entire country
%       sum up to 100. If only coastal areas are selected,
%       values sum up to less than 100.
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140205
% david.bresch@gmail.com, 20140216, replaced variable entity_base with entity for compatibility
% david.bresch@gmail.com, 20141209, country or ISO3 enabled
% david.bresch@gmail.com, 20141229, tolerant iro country names
% david.bresch@gmail.com, 20150804, return empty if Cancel pressed
% David N. Bresch, david.bresch@gmail.com, 20150819, climada_global.centroids_dir introduced
% David N. Bresch, david.bresch@gmail.com, 20150819, module_data_dir updated
%-

centroids=[];entity=[]; % init

global climada_global
if ~climada_init_vars, return; end

% poor man's version to check arguments
if ~exist('country_name'            , 'var'), country_name             = ''; end
if ~exist('asset_resolution_km'     , 'var'), asset_resolution_km      = []; end
if ~exist('check_for_groups'        , 'var'), check_for_groups         = []; end
if ~exist('hollowout'               , 'var'), hollowout                = 0 ; end
if ~exist('night_light'             , 'var'), night_light              = []; end
if ~exist('pp'                      , 'var'), pp                       = []; end
if ~exist('borders'                 , 'var'), borders                  = []; end
if ~exist('border_mask'             , 'var'), border_mask              = []; end
if ~exist('check_figure'            , 'var'), check_figure             = 1 ; end
if ~exist('save_on_entity_centroids', 'var'), save_on_entity_centroids = 1 ; end
if ~exist('no_wbar'                 , 'var'), no_wbar                  = 1 ; end

centroids = [];
entity    = [];
% asset_resolution_km      = 200;
% check_figure             = 1;
% save_on_entity_centroids = 0;

% set modul data directory
%%module_data_dir = [fileparts(fileparts(fileparts(mfilename('fullpath')))) filesep 'data'];

% set default parameters
if isempty(asset_resolution_km), asset_resolution_km = 10   ; end
check_printplot = 0;

% parameter of second order polynomial function to transform night lights
% nonlinearly into distribution of asset values
if isempty(pp), pp = []  ; end


% 0a) load world borders
% fprintf('0) \t a) Load world borders including regions\n')
% borders = climada_load_world_borders(borders);
% if isempty(borders), return, end


% 0b) load country masks
% load border_mask for all countries (original resolution ~10km)
% fprintf('0)\t b) Load border masks...')
% fprintf(' done\n')
border_mask = climada_load_border_mask(border_mask, asset_resolution_km);
if isempty(border_mask), return, end


% 0c) ask for country or region

if isempty(country_name)
    [country_name,country_ISO3] = climada_country_name('Single');
    if isempty(country_name),return;end
end

% check country name (and obtain ISO3)
[country_name_chckd,country_ISO3] = climada_country_name(country_name);
if isempty(country_name_chckd)
    country_ISO3='XXX'; % be tolerant...
    fprintf('Warning: Might be an unorthodox country name as input - check results\n')
else
    country_name=country_name_chckd;
end
country_name_str = strrep(country_name,' ',''); % remove spaces

if hollowout
    hollow_name = 'hollow';
else
    hollow_name = '';
end
fprintf('*** %s on roughly %d km %s ***\n', ...
    country_name_str, asset_resolution_km, hollow_name);


% 1) Cut out night lights for the specific country and transform nonlinearly
silent_mode = 0;
save_on     = 0;
% pp is the parameter of second order polynomial function to transform night lights
% nonlinearly into distribution of asset values

[values_distributed, pp] = climada_night_light_to_country(country_name, pp, night_light,...
    borders, border_mask, 0, check_printplot, save_on, silent_mode);
if isempty(values_distributed); return; end
if ~any(values_distributed.values)
    fprintf('Warning: No light data available for %s, aborted\n', country_name_str)
    return
end

% create string from parameters from nonlinear transformation
pp_str = climada_parameter_string(pp);


% 1b) Downscale resolution
asset_resolution_km_ori = asset_resolution_km;
fprintf('1) Downscale distributed values to ~%dkm ...  ', asset_resolution_km)
[values_distributed,X,Y,asset_resolution_km]=climada_resolution_downscale(values_distributed, asset_resolution_km, 'sum');
values_distributed.values(values_distributed.values<0) = 0;
if asset_resolution_km_ori ~= asset_resolution_km
    fprintf('(roughly ~%dkm)', asset_resolution_km)
end
fprintf(' done\n')


% 2) Create centroids
% country_index = ismember(border_mask.name,country_name);
fprintf('2) Create centroids for %s on a ~%d km resolution\n', country_name_str, asset_resolution_km)

% Create mask and buffer mask for selected region based on distributed values
% buffer_km       = 150;
buffer_km       = 50;
if asset_resolution_km>buffer_km
    buffer_km = 2*asset_resolution_km;
end

fprintf(' a) Create buffer of ~%dkm\n',buffer_km)
no_pixel_buffer = ceil(buffer_km/asset_resolution_km);
printname       = sprintf('%s_%dkm',country_name_str, asset_resolution_km);
printname_pp    = [printname ', ' pp_str];
if hollowout
    printname        = [printname '_' hollow_name];
    hollowout_km     = 500;
    no_pixel_hollow  = ceil(hollowout_km/asset_resolution_km);
    fprintf(' b) Select only coastal areas, hollowout matrix of ~%dkm\n',hollowout_km)
else
    fprintf(' b) Select entire country (hollowout is set to 0) \n')
    no_pixel_hollow = 0;
end

% for big countries this can take some time
if asset_resolution_km_ori >= asset_resolution_km-4 && asset_resolution_km_ori <= asset_resolution_km+4;
    c_idx            = strcmp(border_mask.name, country_name);
    
    % downscale resolution
    country_matrix_high_res        = border_mask;
    country_matrix_high_res.values = logical(border_mask.mask{c_idx});
    country_matrix_low_res         = climada_resolution_downscale(country_matrix_high_res, asset_resolution_km, 'sum');
    country_matrix_low_res.values(country_matrix_low_res.values>1) = 1;
    
    % create coastal buffer
    matrix_hollowout = climada_mask_buffer_hollow(logical(country_matrix_low_res.values), no_pixel_buffer, no_pixel_hollow, border_mask, ...
        0, 0, printname, country_name, no_wbar);
else
    matrix_hollowout = climada_mask_buffer_hollow(logical(values_distributed.values), no_pixel_buffer, no_pixel_hollow, border_mask, ...
        0, 0, printname, country_name, no_wbar);
    % otherwise skip buffer and hollowout
    %matrix_hollowout = logical(values_distributed.values);
end

% c_borders_index  = strcmp(country_name{1}, borders.name);
% matrix_structure = values_distributed;
% matrix_structure.values = border_mask.mask{c_borders_index};
% matrix_structure = climada_resolution_downscale(matrix_structure, asset_resolution_km, 'sum');
% matrix_hollowout = logical(matrix_hollowout + matrix_structure.values);

if ~any(find(matrix_hollowout))
    fprintf(' No pixels within %s after hollowout (not at coast)\n',country_name_str)
    return
end

%% create centroids from matrix and save if needed
centroids         = climada_matrix2centroid(matrix_hollowout, border_mask.lon_range, border_mask.lat_range, ...
    country_name);
centroids.comment = sprintf('%s, %s %s',country_name_str, values_distributed.comment, hollow_name);
if min(centroids.onLand) > 0
    indx = find(centroids.onLand, 1, 'last');
    centroids.onLand(indx) = 0;
end

% visualize centroids on map
if check_figure
    climada_plot_centroids(centroids, country_name, check_printplot, printname);
end

% add country info
centroids.admin0_name=country_name;
centroids.admin0_ISO3=country_ISO3;

if save_on_entity_centroids
    centroids_filename = [climada_global.centroids_dir filesep 'centroids_' strrep(country_name_str,', ','') '_' int2str(asset_resolution_km) 'km_' hollow_name];
    save(centroids_filename,'centroids')
    fprintf(' d) Save centroids in %s\n',centroids_filename)
end


% 3a) Create base entity file and save in xls

fprintf('3) Create base entity\n')

% create entity, read wildcard entity, add assets from values_distributed,
% and encode to centroids
entity=climada_entity_base_assets_add(values_distributed, centroids, country_name_str, matrix_hollowout,  X, Y, hollow_name, no_wbar);

% add country info
entity.assets.admin0_name=country_name;
entity.assets.admin0_ISO3=country_ISO3;

save_entity_xls = 1;
% save entity as mat-file
if save_on_entity_centroids
    %entity_filename   = ['entity_' strrep(country_name_str,', ','') '_base_' pp_str '_' int2str(asset_resolution_km) 'km_' hollow_name];
    entity_filename   = ['entity_' strrep(country_name_str,', ','') '_base_' int2str(asset_resolution_km) 'km_' hollow_name];
    entity_foldername = [climada_global.data_dir filesep 'entities' filesep entity_filename];
    save(entity_foldername, 'entity')
    fprintf(' d) Save entity in %s\n',entity_foldername)
    
    if save_entity_xls
        fprintf(' e)')
        entity_xls_file = [entity_foldername '.xls'];
        try
            climada_entity_save_xls(entity, entity_xls_file)
        catch err
            fprintf('WARNING: Entity base cannot be saved as xls file.\n');
        end
    end
end

% visualize assets on map
if check_figure
    climada_plot_entity_assets(entity, centroids, country_name, check_printplot);
end