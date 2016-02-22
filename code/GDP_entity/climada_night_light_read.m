function night_light = climada_night_light_read(png_filename, check_figure, check_printplot, save_on)
%
% NAME:
%   climada_night_light_read
% PURPOSE:
%   read stable night lights (2010) from NOAA
%
%   read stable night lights, 2010 (resolution ~10km)
%   http://www.ngdc.noaa.gov/dmsp/downloadV4composites.html
%   http://www.ngdc.noaa.gov/dmsp/data/web_data/v4composites/F182010.v4.tar
%   Version 4 DMSP-OLS Nighttime Lights Time Series
%
%   previous: diverse
%   next: climada_GDP_distribute
%   see also: module country_risk, climada_nightlight_entity
% CALLING SEQUENCE:
%   night_light = climada_night_light_read(png_filename, check_figure, check_printplot, save_on)
% EXAMPLE:
%   night_light = climada_night_light_read
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   png_filename: the filename (location) of the png-file with night lights
%       (global coverage)
%       > prompted for if empty (default night_light_2010_10km.png, but not
%       automatically chosen)
%   check_figure: =1: show figure of night light, default=0
%   check_printplot: =1 to 1 to save figure (default=0)
%   save_on: =1 to save .mat file (default)
% OUTPUTS:
%   night_light: a struct, with following fields
%         .value        : GDP value in USD per country
%         .lon_range    : range of Longitude
%         .lat_range    : range of Latitude
%         .resolution_x : resolution in x-direction
%         .resolution_y : resolution in y-direction
%         .comment      : information about night light data
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20120730
% David N. Bresch, david.bresch@gmail.com, 20141205, cleanup
% David N. Bresch, david.bresch@gmail.com, 20160222, module_data_dir updated
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables
if ~exist('png_filename'   , 'var'), png_filename    = []; end
if ~exist('check_figure'   , 'var'), check_figure    = 0; end
if ~exist('check_printplot', 'var'), check_printplot = 0; end
if ~exist('save_on'        , 'var'), save_on         = 1; end

% set modul data directory
module_data_dir = [fileparts(fileparts(fileparts(mfilename('fullpath')))) filesep 'data'];

% prompt for png_filename if not given
if isempty(png_filename) % local GUI
    png_filename         = [module_data_dir filesep '*.png'];
    png_filename_default = [module_data_dir filesep 'night_light_2010_10km.png'];
    [filename, pathname] = uigetfile(png_filename, 'Select night lights:',png_filename_default);
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        png_filename = fullfile(pathname,filename);
    end
end

[~,fN]=fileparts(png_filename);
save_filename = [module_data_dir filesep fN '.mat'];
print_filename = [climada_global.data_dir filesep 'results' filesep fN '.pdf'];

values                   = flipud(double(imread(png_filename)));
values(isnan(values))    = 0;
x_range                  = [-180 180];
y_range                  = [ -65  75];
resolution_x             = sum(abs(x_range))/size(values,2);
resolution_y             = sum(abs(y_range))/size(values,1);

night_light.values       = sparse(values);
night_light.lon_range    = x_range;
night_light.lat_range    = y_range;
night_light.resolution_x = resolution_x;
night_light.resolution_y = resolution_y;
night_light.comment      = 'Night time lights, 2010';


% plot image
if check_figure
    % colormap from green to red
    %colormap_green_red = [summer(20);flipud(autumn(80))];
    
    fig_width       = 162+180;
    fig_height      = 60+77;
    fig_relation    = fig_height/fig_width;
    fig_height_     = 1.2;
    fig             = climada_figuresize(fig_height_*fig_relation,fig_height_);
    
    im = imagesc(x_range-resolution_x/2, y_range-resolution_y/2, night_light.values);
    % set(im,'alphadata',~isnan(values))
    set(gca,'ydir','normal')
    hold on
    colormap(flipud(hot))
    % caxis([1 max(night_light(:))])
    t = colorbar;
    colorbar_label = night_light.comment;
    set(get(t,'ylabel'),'String', colorbar_label,'fontsize',14);
    
    climada_plot_world_borders(0.5)
    axis equal
    % axis([-162 180 -60 77])
    % set(gca,'xlim',[-162 180],'ylim',[-60 77])
    % set(gca,'xlim',[-162 180],'ylim',[-60 77],'ytick',[],'xtick',[])
    
    if check_printplot %(>=1)
        print(fig,'-dpdf',print_filename)
        %close
        fprintf('\t\t saved figure as %s\n', print_filename);
    end
end

if save_on
    save(save_filename,'night_light')
    fprintf('\t\t saved night lights as %s \n',save_filename)
end

end
