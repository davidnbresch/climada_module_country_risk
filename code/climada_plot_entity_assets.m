function fig = climada_plot_entity_assets(entity,centroids,country_name,check_printplot,printname,keep_boundary)
% climada plot assets from entity file and save if needed
% NAME:
%   climada_plot_entity_assets
% PURPOSE:
%   plot assets from entity file on a map with different colors to show the
%   distribution of assets, print if needed
%   normally called from: climada_create_GDP_entity
% CALLING SEQUENCE:
%   fig = climada_plot_entity_assets(entity, centroids, country_name, check_printplot)
% EXAMPLE:
%   climada_plot_entity_assets(entity, centroids, country_name)
% INPUTS:
%   entity          : entity structure, with entity.assets field
%   centroids       : centroids mat-file (struct)
%       if passed empty, the information is taken from entity.assets
% OPTIONAL INPUT PARAMETERS:
%   country_name_str: country name as string format
%   check_printplot : 1 for printing (save as pdf), set to 0 by default
%   printname       : name for pdf-file, to be saved in .../climada/data/results/Entity_printname.pdf
% OUTPUTS:
%   fig             : figure handle
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140205
% David N. Bresch, david.bresch@gmail.com, 20141127, figure creating suppressed
% David N. Bresch, david.bresch@gmail.com, 20141208, country_name='' as default
% David N. Bresch, david.bresch@gmail.com, 20141209, abort if sum(Values)=0
% Lea Mueller, muellele@gmail.com, 20140205, add keep_boundary option
% Lea Mueller, muellele@gmail.com, 20160318, use climada_colormap('assets')
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

fig = [];
% poor man's version to check arguments
if ~exist('entity'          ,'var'), return              ; end
if ~exist('centroids'       ,'var'), centroids       = []; end
if ~exist('country_name'    ,'var'), country_name    = ''; end
if ~exist('check_printplot' ,'var'), check_printplot = []; end
if ~exist('printname'       ,'var'), printname       = []; end
if ~exist('keep_boundary'   ,'var'), keep_boundary   = []; end

if isempty(keep_boundary), keep_boundary = 0;end

name_str = ''; % init
if ~iscell(country_name), country_name = {country_name}; end

if isempty(centroids)
    % take lat/lon from entity.assets
    centroids.lon=entity.assets.lon;
    centroids.lat=entity.assets.lat;
end

% calculate figure scaling parameters
scale  = max(centroids.lon) - min(centroids.lon);
scale2 =(max(centroids.lon) - min(centroids.lon))/...
    (min(max(centroids.lat),80)-max(min(centroids.lat),-60));
height = 0.5;
if height*scale2 > 1.2; height = 1.2/scale2; end

% calculate figure characteristics
ax_lim = [min(centroids.lon)-scale/30          max(centroids.lon)+scale/30 ...
          max(min(centroids.lat),-60)-scale/30  min(max(centroids.lat),80)+scale/30];
markersizepp = polyfit([15 62],[5 3],1);
markersize   = polyval(markersizepp,ax_lim(2) - ax_lim(1));
markersize(markersize<2) = 2;


% create figure
% fig = climada_figuresize(height,height*scale2+0.15);
% if ~isfield(entity.assets,'reference_year')
%     entity.assets.reference_year = '';
% end
% name_str = sprintf('Entity %s, Reference year %d', country_name{1}, entity.assets.reference_year);
% set(fig,'Name',name_str)

plot(entity.assets.lon, entity.assets.lat,'.', 'color', [238 224 229]/255, 'MarkerSize', 0.05);
hold on

if sum(entity.assets.Value)==0
    return
else
    % colormap(flipud(hot))
    cmap = climada_colormap('assets');
    cbar = plotclr(entity.assets.lon, entity.assets.lat, entity.assets.Value,'s',markersize,1,[],[],cmap,[],1);
    set(get(cbar,'ylabel'),'String', 'value per pixel (exponential scale)' ,'fontsize',12);
    hold on
    box on
    climada_plot_world_borders(0.5,'','',keep_boundary)
    if ~keep_boundary
        axis(ax_lim)
        axis equal
        axis(ax_lim)
    end
    
    if sum(entity.assets.Value)<=100.5
        %title_str = sprintf('Entity %s (sum of all assets: %10.1f)', entity.assets.hazard.comment, sum(entity.assets.Value));
        title_str = sprintf('%s: sum of all assets: %10.1f, Base entity',name_str,...
            sum(entity.assets.Value));
    else %if sum(entity.assets.Value) > 10000
        %title_str = sprintf('Entity %s (sum of all assets: %2.4g USD)', entity.assets.hazard.comment, sum(entity.assets.Value));
        title_str = sprintf('%s %2.4g USD (%d)',char(country_name),...
            sum(entity.assets.Value), entity.assets.reference_year);
    end
    title(title_str)
    
    
    if check_printplot
        if isempty(printname) %local GUI
            printname_         = [climada_global.data_dir filesep 'results' filesep '*.pdf'];
            printname_default  = [climada_global.data_dir filesep 'results' filesep 'Entity_' country_name{1} '_resolution_km.pdf'];
            [filename, pathname] = uiputfile(printname_,  'Save asset map as figure:',printname_default);
            foldername = [pathname filename];
            if pathname <= 0; return;end
        else
            foldername = [climada_global.data_dir filesep 'results' filesep 'Entity_' printname '_sum100.pdf'];
        end
        print(fig,'-dpdf',foldername)
        cprintf([255 127 36 ]/255,'\t\t saved 1 FIGURE in folder ..%s \n', foldername);
    end
    
end

fig=gcf; % backward compatibility

return


