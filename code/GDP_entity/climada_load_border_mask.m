function border_mask = climada_load_border_mask(border_mask_DUMMY, asset_resolution_km)
% load border mask
% NAME:
%   climada_load_border_mask
% PURPOSE:
%   load border mask
% CALLING SEQUENCE:
%   border_mask = climada_load_border_mask(border_mask, asset_resolution_km)
% EXAMPLE:
%   border_mask = climada_load_border_mask
% INPUTS:
%   none
% OPTIONAL INPUT PARAMETERS:
%   border_mask_DUMMY: a dummy parameter for backward compatibility, not used
%   asset_resolution_km: resolution in km, default=10
% OUTPUTS:
%   border_mask
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20141016
% David N. Bresch, david.bresch@gmail.com, 20141229, full revision
% David N. Bresch, david.bresch@gmail.com, 20160222, module_data_dir updated
%-

border_mask    = []; %init

%global climada_global
if ~climada_init_vars,return;end % init/import global variables
%if ~exist('border_mask_DUMMY'   , 'var'),return; end
if ~exist('asset_resolution_km' , 'var'), asset_resolution_km = 10; end

% set modul data directory
module_data_dir = [fileparts(fileparts(fileparts(mfilename('fullpath')))) filesep 'data'];

% PARAMETERS
%
% the file with the border mask (after first call)
border_mask_file=[module_data_dir filesep 'border_mask_' int2str(asset_resolution_km) 'km.mat'];

try
    load(border_mask_file) % load if exists
catch
    fprintf('Warning: border_mask not available, trying to create it (climada_polygon2raster)\n')
    %input_resolution_km = climada_geo_distance(0,0,night_light.resolution_x,0)/1000;
    %input_resolution_km = ceil(input_resolution_km/10)*10;
    %factor              = round(asset_resolution_km/input_resolution_km);
    %raster_size         = round(size(night_light.values)/factor);
    borders             = [];
    switch asset_resolution_km
        case 10
            raster_size         = [1680 4320]; %10km
        case 50
            raster_size         = [336 864]; %50km
        case 100
            raster_size         = [168 432]; %100km
        otherwise
            fprintf('ERROR: asset resolution of %i km not implemented, aborted\n',asset_resolution_km)
            return
    end
    save_on     = 1;
    border_mask = climada_polygon2raster(borders,raster_size,save_on);
end

end