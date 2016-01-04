function fig = climada_plot_centroids(centroids, country_name, check_printplot, printname)
% plot centroids on a map, differentiate for coastal land areas,
% bufferzone, and further away (more inland and on sea)
% NAME:
%   climada_plot_centroids
% PURPOSE:
%   plot centroids on a map, differentiate for coastal land areas,
%   bufferzone, and further away (more inland and on sea)
%   next: diverse
% CALLING SEQUENCE:
%   fig = climada_plot_centroids(centroids, country_name, check_printplot, printname)
% EXAMPLE:
%   climada_plot_centroids(centroids, country_name)
% INPUTS:
%   centroids       : centroids structure
%   country_name    : name of the country (cell or string)
%   check_printplot : set to 1 to save figure, default 0
%   printname       : string for title and for filename if saved
% OUTPUTS:
%   fig             : figure handle
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140205
%-


global climada_global
if ~climada_init_vars,return;end % init/import global variables

fig = [];
if ~exist('centroids'          , 'var'), return; end
if ~exist('country_name'       , 'var'), country_name        = []; end
if ~exist('check_printplot'    , 'var'), check_printplot     = []; end
if ~exist('printname'          , 'var'), printname           = ''; end
if isempty(printname)                  , printname = country_name; end

if ~iscell(country_name)
    country_name = {country_name};
end


%% calculate figure parameters
markersize = 1.5;  
scale      = max(centroids.lon) - min(centroids.lon);
scale2     =(max(centroids.lon) - min(centroids.lon))/...
            (min(max(centroids.lat),80)-max(min(centroids.lat),-60));
height     = 0.5;
if height*scale2 > 1.2; height = 1.2/scale2; end
ax_lim = [min(centroids.lon)-scale/30          max(centroids.lon)+scale/30 ...
          max(min(centroids.lat),-60)-scale/30  min(max(centroids.lat),80)+scale/30];

      
%% create figure      
fig      = climada_figuresize(height,height*scale2+0.15);
name_str = sprintf('Centroids in %s', country_name{1});
set(fig,'Name',name_str, 'NumberTitle','on')
climada_plot_world_borders(0.5);
xlabel('Longitude'); ylabel('Latitude')
axis(ax_lim)   
axis equal
axis(ax_lim)   
if max(centroids.onLand)== 1 %no buffer
    cmap = ([[255 153  18]/255;...
          jet(max(centroids.onLand))]);
else
    if ~isempty(country_name)
        no_colors = length(country_name);
    else
        no_colors = max(centroids.onLand)-1;
    end   
    cmap = ([[255 153  18]/255;...
          jet(no_colors);...
          [205 193 197 ]/255]);
end

if min(centroids.onLand) > 0
    indx = find(centroids.onLand, 1, 'last');
    centroids.onLand(indx) = 0;
end

cbar = plotclr(centroids.lon, centroids.lat, centroids.onLand, '+',markersize, 1, [],[],cmap);
colormap(cmap)
caxis([0 size(cmap,1)])

if ~isempty(country_name)
    cbar_label_ = {};
    for i = 1:length(country_name)
        cbar_label_{i} = sprintf('%d: %s', i, country_name{i});
    end
    cbar_label = ['0: Grid' cbar_label_ [int2str(i+1) ': Buffer']];
else
    cbar_label = num2cell(0:size(cmap,1)-1);
    cbar_label{1} = '0: Grid';
    cbar_label{end} = sprintf('%d: Buffer',cbar_label{end});
end 
set(cbar,'YTick',0.5:1:size(cmap,1)-0.5,'yticklabel',cbar_label,'fontsize',12)   
title([strrep(printname,'_',' ') ': centroids on land, within buffer and grid']) 

if check_printplot
    if strcmp(printname,country_name) %local GUI
        printname_         = [climada_global.data_dir filesep 'results' filesep '*.pdf'];
        printname_default  = [climada_global.data_dir filesep 'results' filesep 'Centroids_' country_name{1} '_resolution_km.pdf'];
        [filename, pathname] = uiputfile(printname_,  'Save centroids as figure:',printname_default);
        foldername = [pathname filename];
        if pathname <= 0; return;end
    else
        foldername = [climada_global.data_dir filesep 'results' filesep 'Centroids_' printname '.pdf'];
    end
    print(fig,'-dpdf',foldername)       
    cprintf([255 127 36 ]/255,'\t\t saved 1 FIGURE in folder ..%s \n', foldername);
end


return
               


    

