function entity_base = climada_entity_base_assets_add(values_distributed, centroids, country_name_str, matrix_hollowout,  X, Y, hollow_name, no_wbar)
% climada add assets to entity base structure, from values_distributed
% NAME:
%   climada_entity_base_assets_add
% PURPOSE:
%   add assets to entity structure from values_distributed and find the
%   closest calculation centroids (encode assets to centroids)
%   normally called from: climada_create_centroids_entity_base
% CALLING SEQUENCE:
%   entity_base = climada_entity_base_assets_add(values_distributed, centroids, country_name_str, matrix_hollowout,  X, Y)
% EXAMPLE:
%   entity_base = climada_entity_base_assets_add(values_distributed, centroids, country_name_str, matrix_hollowout,  X, Y)
% INPUTS:
%   values_distributed    : structure mat-file with the following fields
%         .values         : distributed values per pixel
%         .lon_range      : range of Longitude
%         .lat_range      : range of Latitude
%         .resolution_x   : resolution in x-direction
%         .resolution_y   : resolution in y-direction
%   centroids             : a centroid mat-file (struct)
%   country_name_str      : country name as string format
%   matrix_hollowout      : coastal area, bufferzone and hollowed out matrix,
%                           masking 1 for on land, and zero for sea, 2 (max value) for buffer
%   X                     : helper matrix containing Longitude information for plotting matrix
%   Y                     : helper matrix containing Latitude information for plotting matrix
% OPTIONAL INPUT PARAMETERS:
%   no_wbar               : set to 1 to suppress waitbar
% OUTPUTS:
%   entity_base           : entity with assets from values_distributed.
%                           Values sum up to 100, or if only coastal areas
%                           are selected, to less than 100.
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140205
% david.bresch@gmail.com, 20140216, _2012 replaced by _today
% david.bresch@gmail.com, 20140216, assets.comment introduced
% david.bresch@gmail.com, 20141104, climada_check_matfile used
% david.bresch@gmail.com, 20141215, switch to entity_template.xls
% Lea Mueller, muellele@gmail.com, 20150123, omit assets.Value_today, not needed
% Lea Mueller, muellele@gmail.com, 20150904, add assets.Value_unit field
% Lea Mueller, muellele@gmail.com, 20151125, invoke climada_entity_read instead of climada_entity_read_wo_assets
% Lea Mueller, muellele@gmail.com, 20160331, use entity_template.xlsx from from climad/data/entities, omit encoding
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

entity = [];
% poor man's version to check arguments
if ~exist('values_distributed', 'var'), fprintf('No values given. Unable to proceed.\n')   , return ;end
if ~exist('centroids'         , 'var'), fprintf('No centroids given. Unable to proceed.\n'), return ;end
if ~exist('hollow_name'       , 'var'), hollow_name = [];end
if ~exist('no_wbar'           , 'var'), no_wbar     = 0 ;end

% PARAMETERS
%
% define the file with an empty entity (used as 'template')
entity_global_without_assets_file = [climada_global.root_dir filesep 'data' filesep 'entities' filesep 'entity_template.xlsx'];
% entity_global_without_assets_file = [climada_global.data_dir filesep 'entities' filesep 'entity_template.xls'];


if ~climada_check_matfile(entity_global_without_assets_file)
    fprintf(' a) Read from excel, entity without assets (damagefunctions, measures, discount) ...\n\t    ')
    entity = climada_entity_read(entity_global_without_assets_file);
    %entity = climada_entity_read_wo_assets(entity_global_without_assets_file);
else
    [fP,fN] = fileparts(entity_global_without_assets_file);
    mat_filename = [fP filesep fN '.mat'];
    fprintf(' a) Load wildcard entity without assets (damagefunctions, measures, discount)\n')
    load(mat_filename);
end


% rename to entity_base
entity_base = entity; clear entity;


% take assets from distributed values matrix
fprintf(' b) Take assets from distributed values matrix\n')
assets                  = [];
assets.comment          = [country_name_str ', ' values_distributed.comment hollow_name];
assets.filename         = country_name_str; % since we did not read from Excel

% mask_index = logical(country_mask_resolution.values);
% check for buffer value
matrix_hollowout        = double(matrix_hollowout);
buffer_value            = full(max(matrix_hollowout(:)));
if buffer_value == 1;  buffer_value = 2; end
mask_index              = matrix_hollowout >= 1 & matrix_hollowout < buffer_value;
assets.lon              = X(mask_index)';
assets.lat              = Y(mask_index)';
assets.Value            = full(values_distributed.values(mask_index))';
assets.Deductible       = zeros(1,length(assets.lon));
assets.Cover            = full(values_distributed.values(mask_index))';
assets.DamageFunID      = ones(1,length(assets.lon));
assets.Value_unit       = repmat({climada_global.Value_unit},size(ones(1,length(assets.lon))));
%assets.Value_today      = full(values_distributed.values(mask_index))'; % _2012 replaced by _today
assets.reference_year   = [];
if sum(assets.Value)<100.5 && sum(assets.Value)>99.5, assets.reference_year = 100; end

if ~any(assets.Value)%all zeros
    fprintf('Error: No values within assets for %s\n', country_name_str)
    %centroids = []; entity = []; entity_forecast = [];
    return
end

% % encode assets
% fprintf(' c) Encode assets to centroids\n')
% entity_base.assets = climada_assets_encode(assets,centroids);

% do not encode assets
fprintf(' c) Assets not yet encoded to centroids \n')
entity_base.assets = assets;


return
