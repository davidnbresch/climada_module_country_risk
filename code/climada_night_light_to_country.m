function [values_distributed,pp] = climada_night_light_to_country(country_name,pp,night_light,...
    borders,border_mask,check_figure,check_printplot,save_on,silent_mode)
% NAME:
%   climada_night_light_to_country
% PURPOSE:
%   distributed values within one country according to night light density
%
%   geographically distribute values within one country according to
%   nonlinearly tranformed night light density values (values between 1 and 63)
%   based on nonlinear relationship between night light intensity and
%   distribution of GDP assets, use a second order polynomial function
%   without y-indent: y = pp(1) x^2 + pp(2) x;
%
%   previous: climada_night_light_read
%   next: climada_resolution_downscale
% CALLING SEQUENCE:
%   [values_distributed pp] = climada_night_light_to_country(country_name, pp, night_light,...
%             borders, border_mask, check_figure, check_printplot, save_on, silent_mode)
% EXAMPLE:
% values_distributed = climada_night_light_to_country('Bangladesh')
% INPUTS:
%   country_name     : name of country (string)
% OPTIONAL INPUT PARAMETERS:
%   pp               : parameter of second order polynomial function to transform night lights
%                      nonlinearly into distribution of GDP assets
%                      y = pp(1)*x^2 + pp(2)*x;
%   night_light      : night light mat file (structure with values,
%                      lon_range, lat_range, resolution_x, resolution_y and comment)
%   borders          : climada world map country borders (structure with
%                      polygon and names)
%   border_mask      : structure with all country masks (zeros and ones)
%   check_figure     : set to 1 to visualize figures, default 1
%   check_printplot  : set to 1 to save figure, default 0
%   save_on          : set to 1 to save Gvalues_distributed.mat
%   silent_mode      : if set to 1, no print out messages, default 0
% OUTPUTS:
%   values_distributed: a struct, with following fields
%         .values       : distributed GDP per pixel
%         .lon_range    : range of Longitude
%         .lat_range    : range of Latitude
%         .resolution_x : resolution in x-direction
%         .resolution_y : resolution in y-direction
%         .comment      : information about distributed GDP data, year and pp
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20130412
% David N. Bresch, david.bresch@gmail.com, 20141205, cleanup and 1km try (see parameters below)
% David N. Bresch, david.bresch@gmail.com, 20160222, module_data_dir updated
%-

values_distributed = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables
if ~exist('country_name'       , 'var'), country_name        = []; end
if ~exist('pp'                 , 'var'), pp                  = []; end
if ~exist('night_light'        , 'var'), night_light         = []; end
if ~exist('borders'            , 'var'), borders             = []; end
if ~exist('border_mask'        , 'var'), border_mask         = []; end
if ~exist('check_figure'       , 'var'), check_figure        = 1 ; end
if ~exist('check_printplot'    , 'var'), check_printplot     = []; end
if ~exist('save_on'            , 'var'), save_on             = []; end
if ~exist('silent_mode'        , 'var'), silent_mode         = 0 ; end

% set modul data directory
module_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% the file with the night lights
png_filename = [module_data_dir filesep 'night_light_2010_10km.png'];
% the following high-res night light dataset can be produced by running
% climada_night_light_read and selecting the high-resolution night light
% image from the climada module country risk, namely the file
% ..country_risk/data/F182012.v4c_web.stable_lights.avg_vis.tif and then
% rename the resulting
% ..GDP_entity/data/F182012.v4c_web.stable_lights.avg_vis.mat file to
% ..GDP_entity/data/night_light_2012_1km.mat 
% BUT: currently leads to an error, since night light resolution (~1km)
% does in this case not match border mask resolution (~10km)
%png_filename = [module_data_dir filesep 'night_light_2012_1km.png'];

if isempty(country_name)
    fprintf('No country chosen, aborted\n')
    return
end

% read stable night lights, 2010 (resolution ~10km)
if isempty(night_light)
    [fP,fN]=fileparts(png_filename);
    png_filename_mat=[fP filesep fN '.mat'];
    if exist(png_filename_mat,'file')
        load(png_filename_mat) % contains night_light
    else
        if exist(png_filename,'file')
            night_light = climada_night_light_read(png_filename,0,0,1);
        else
            fprintf('Night light %s not found, aborted\n', png_filename)
            values_distributed = []; pp = [];
            return
        end
    end
end
values = night_light.values;
% Set night lights nan values to zero and create sparse matrix
% values(isnan(values)) = 0;


% nonlinearly transform night lights,
% based on relationship between night lights and asset distribution),
% use a second order polynomial function without y-indent
% y = pp(3)*x^2 + pp(2)*x + + pp(1)
if pp == 1; pp = [0 1 0]; end
[values,pp] = climada_nightlight_nonlinear_transformation(values, pp, 0, 0);
pp_str = 'y = ';
for i = length(pp):-1:1; pp_str = sprintf('%s %0.4f*x^%d +',pp_str,pp(i), length(pp) - (i)); end
pp_str(end-1:end) = [];
% pp_str     = num2str(pp,', %2.1e');

if ~silent_mode; fprintf('Night lights to values: %s\n',pp_str); end
pp_str_ = strrep(strrep(strrep(strrep(strrep(strrep(pp_str,' ',''),'^',''),'0.',''),'+','_'),'*',''),'.','');
pp_str_(1:2) = [];
% values       = sparse(values);


% range of worldmap
x_range             = night_light.lon_range;
y_range             = night_light.lat_range;
resolution_x        = night_light.resolution_x;
resolution_y        = night_light.resolution_y;
input_resolution_km = climada_geo_distance(0,0,night_light.resolution_x,0)/1000;
input_resolution_km = ceil(input_resolution_km/10)*10;

% load border_mask file

if isempty(border_mask)
    border_mask = climada_load_border_mask;
end
if isempty(border_mask), return, end


%check resolution of border_mask file matches night light values
if any(size(border_mask.mask{1}) ~= size(night_light.values))
    asset_resolution_km = climada_geo_distance(0,0,border_mask.resolution_x,0)/1000;
    asset_resolution_km = ceil(asset_resolution_km/10)*10;
    fprintf('Error: Night light resolution (~%dkm) does not match border mask resolution (~%dkm)\n',input_resolution_km, asset_resolution_km)
    return
else
    asset_resolution_km = input_resolution_km;
end


% load the borders file, if not given
if isempty(borders)
    borders = climada_load_world_borders;
end
if isempty(borders), return, end


% create distributed matrix
%country_name = climada_country_name(country_name);
%if isempty(country_name), return, end

% create country mask for selected country
c_indx       = strcmp(country_name, borders.name);
if sum(c_indx)==0
    fprintf('ERROR %s: country name does not match any border information\n',mfilename)
    return
end
country_mask = border_mask.mask{c_indx};
if ~any(country_mask)
    fprintf('%s is too small and does not exist as a mask, aborted\n',country_name)
end
values_dist  = values .* country_mask;
if ~any(values_dist)
    fprintf('No light data available for %s - assuming uniform distribution\n',country_name)
    values_dist  = country_mask;
    any(country_mask)
end
values_dist  = values_dist / sum(values_dist(:)) * 100;

% values_dist  = zeros(size(country_mask));
% values_dist(logical(country_mask)) =  values(logical(country_mask));
% values_dist =  values_dist / sum(values_dist(:)) * 100;


% % check for groups
% c_borders_index = strcmp(country_name, borders.name);
% if borders.groupID(c_borders_index)>0
%     group_index = find(borders.groupID == borders.groupID(c_borders_index));
% else
%     group_index = find(c_borders_index);
% end
% if ~isempty(group_index)
%
%     country_name_str = sprintf('%s, ',borders.name{group_index});
%     country_name_str(end-1:end) = [];
%     fprintf('\t\t Distribute values according to night lights within %s on a %d km resolution\n',country_name_str, asset_resolution_km)
%
%     % if more than one country, put all countries together in
%     % one country_mask
%     country_mask = zeros(size(border_mask.mask{1}));
%     for group_index_i = 1:length(group_index)
%         country_mask = country_mask + border_mask.mask{group_index(group_index_i)};
%     end
%     country_mask(country_mask>1) = 1;
%
%     values_dist = zeros(size(country_mask));
%     values_dist(logical(country_mask)) =  values(logical(country_mask));
%     values_dist =  values_dist / sum(values_dist(:)) * 100;
% else
%     fprintf('\t\t No country mask for %s. Unable to proceed.\n', country_name)
%     return
% end


values_distributed.values       = sparse(values_dist);
values_distributed.lon_range    = x_range;
values_distributed.lat_range    = y_range;
values_distributed.resolution_x = resolution_x;
values_distributed.resolution_y = resolution_y;
values_distributed.comment      = sprintf('nonlinear function, %s', pp_str);


if check_figure
    % find minimum and maximum of longitude, latitude for axis limits
    res_x           = values_distributed.resolution_x;
    [X, Y ]         = meshgrid(values_distributed.lon_range(1)+res_x/2: res_x: values_distributed.lon_range(2)-res_x/2, ...
        values_distributed.lat_range(1)+res_x/2: res_x: values_distributed.lat_range(2)-res_x/2);
    nonzero_index   = values_distributed.values>0;
    delta           = 2;
    axislim         = [min(X(nonzero_index))-delta  max(X(nonzero_index))+delta ...
        min(Y(nonzero_index))-delta  max(Y(nonzero_index))+delta];
    
    fig_width       = abs(axislim(2) - axislim(1));
    fig_height      = abs(axislim(4) - axislim(3));
    fig_relation    = fig_height/fig_width;
    fig_height_     =  0.7;
    fig             = climada_figuresize(fig_height_*fig_relation,fig_height_);
    
    imagesc(x_range-resolution_x/2, y_range-resolution_y/2, log10(full(values_distributed.values)))
    
    a = full(values_distributed.values);
    a = a(:); a(a==0) = [];
    %figure
    %hist(a)
    
    %figure;hist(values_distributed.values(values_distributed.values>0));
    hold on
    set(gca,'ydir','normal')
    climada_plot_world_borders(0.08)
    %set colormap
    cmap = jet(300);
    cmap = [1 1 1; cmap(50:300,:)];
    colormap(cmap)
    %caxis([0 0.1e10])
    %caxis([0 full(max(values_distributed.values(:)))*0.5])
    %caxis(log10([0.00032 0.33])) for Switzerland
    caxis(sort([log10(min(a))*0.99 log10(max(a))*1.01])) % for logarithmic color scale
    
    t = colorbar;
    ytick_ = get(t,'ytick');
    set(t,'YTick',ytick_,'YTickLabel',sprintf('%1.2g|',10.^ytick_))
    
    %colorbar_label = sprintf('%s\n GDP %d',GDP.comment, year);
    colorbar_label = sprintf('values (sum 100), exponential scale');
    set(get(t,'ylabel'),'String', colorbar_label,'fontsize',14);
    axis equal
    axis(axislim)
    titlestr = sprintf('\t %s, %d km\nValues based on nonlinear transformed night lights\n(%s) \n%d km ', country_name, asset_resolution_km, pp_str);
    title(titlestr)
    
    if check_printplot %(>=1)
        foldername = [filesep 'results' filesep 'Values_distributed_' country_name '_' int2str(input_resolution_km) 'km_' pp_str_ '.pdf'];
        print(fig,'-dpdf',[climada_global.data_dir foldername])
        %close
        fprintf('saved 1 FIGURE in folder ..%s\n', foldername);
        
    end
end

if save_on
    foldername = [module_data_dir filesep 'Values_distributed_' country_name '_' int2str(input_resolution_km) 'km_' pp_str_ '.mat'];
    save(foldername,'values_distributed')
    if ~silent_mode
        cfprintf('saved 1 mat-file in folder %s\n',foldername)
    end
end



% put all countries in one matrix all_borders
% all_borders = zeros(size(values,1), size(values,2));
% for country_i = 1:length(borders.name)
%     [a b] = find(all_borders(logical(border_mask{country_i})));
%     if ~isempty(a)
%         fprintf('attention: data will be overwritten through %s!\n',borders.name{country_i})
%         fprintf('%d values at position %d\n',length(a),b(1))
%     end
%     all_borders(logical(border_mask{country_i})) = country_i;
% end
%
% figure
% climada_plot_world_borders
% set(gca,'ydir','normal')
% hold on
% colormap(lines)
% imagesc(x_range-resolution_x/2,y_range-resolution_y/2,all_borders)
% colorbar