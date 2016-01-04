function [centroids,entity,polygon] = climada_cut_out_GDP_entity(entity,centroids,polygon)
% NAME:
%   climada_cut_out_GDP_entity
% PURPOSE:
%   Select a specific region within a country (entity and centroids).
%   specify region either with a polygon or define interactively with mouse
% CALLING SEQUENCE:
%   [centroids entity polygon] = climada_cut_out_GDP_entity(entity, centroids, polygon)
% EXAMPLE:
%   [centroids entity polygon] = climada_cut_out_GDP_entity
% INPUTS:
% none
% OUTPUTS:
%   centroids: a structure with fields centroid_ID, Latitude, Longitude,
%       onLand, country_name, comment for each centroid
%   entity: a structure with fields assets, damagefunctions, measures,
%       discount. Assets values are based on night light
%       intensity and scaled up to todays GDP (e.g. 2014)
%   polygon: the polygon that specifies the region that was
%       defined through mouse clicks, or self-defined input. The vertices 
%       of the polygon as an Mx2 array [X1 Y1; X2 Y2; etc].
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140206
% david.bresch@gmail.com, 20140216, _2012 replaced by _today
% david.bresch@gmail.com, 20141209, tried to fix, does not work properly
% David N. Bresch, david.bresch@gmail.com, 20150819, climada_global.centroids_dir introduced
%-

global climada_global
if ~climada_init_vars, return; end

% poor man's version to check arguments

if ~exist('entity'         , 'var'), entity          = ''; end
if ~exist('centroids'      , 'var'), centroids       = []; end
if ~exist('polygon'        , 'var'), polygon         = []; end

country_name  = {''};
year          = climada_global.present_reference_year;
check_figure  = 1;

% set modul data directory
module_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

%% load entity
if isempty(entity)
    entity = climada_entity_load;
end

%% prompt for centroids not given
if isempty(centroids) % local GUI
    centroids = [climada_global.centroids_dir filesep '*.mat'];
    [filename, pathname] = uigetfile(centroids, 'Select centroids:');
    if isequal(filename,0) || isequal(pathname,0)
        centroids=[];
        entity=[];
        polygon=[];
        return; % cancel
    else
        centroids=fullfile(pathname,filename);
    end
end
if ~isstruct(centroids)
    load(centroids)
end

% save_entity_xls = 1;
% % save entity as mat-file
% if save_on_entity_centroids
%     entity_filename   = ['entity_' strrep(country_name_str,', ','') '_' int2str(year) '_' pp_str_ '_' int2str(asset_resolution_km) 'km_' hollow_name];
%     entity_foldername = [climada_global.data_dir filesep 'entities' filesep entity_filename];
%     save(entity_foldername, 'entity')
%     fprintf('\t d) entity saved in\n')
%     cprintf([113 198 113]/255,'\t\t %s\n',entity_foldername)
%
%     if save_entity_xls
%         fprintf('\t e)')
%         entity_xls_file = [entity_foldername '.xls'];
%         warning off MATLAB:xlswrite:AddSheet
%         climada_entity_save_xls(entity, entity_xls_file)
%     end
% end

if check_figure
    scale  = max(centroids.lon) - min(centroids.lon);
    scale2 =(max(centroids.lon) - min(centroids.lon))/...
        (min(max(centroids.lat),80)-max(min(centroids.lat),-60));
    height = 0.5;
    if height*scale2 > 1.2; height = 1.2/scale2; end
    
    ax_lim = [min(centroids.lon)-scale/30          max(centroids.lon)+scale/30 ...
        max(min(centroids.lat),-60)-scale/30  min(max(centroids.lat),80)+scale/30];
    markersizepp = polyfit([15 62],[5 3],1);
    markersize   = polyval(markersizepp,ax_lim(2) - ax_lim(1));
    markersize(markersize<2) = 2;
    
    fig = climada_figuresize(height,height*scale2+0.15);
    name_str = sprintf('Entity %s %d', country_name{1}, year);
    set(fig,'Name',name_str)
    % colormap(flipud(hot))
    cbar = plotclr(entity.assets.lon, entity.assets.lat, entity.assets.Value,'s',markersize,1,...
        [],[],[],[],1);
    set(get(cbar,'ylabel'),'String', 'USD (exponential)' ,'fontsize',12);
    hold on
    box on
    climada_plot_world_borders(0.5)
    axis(ax_lim)
    axis equal
    axis(ax_lim)
    title(entity.assets.hazard.comment)
    %title(entity.assets.excel_file_name)
    
    %     if check_printplot
    %         foldername = [filesep 'results' filesep 'Entity_' int2str(year) '_' printname '.pdf'];
    %         print(fig,'-dpdf',[climada_global.data_dir foldername])
    %         cprintf([255 127 36 ]/255,'\t\t saved 1 FIGURE in folder ..%s \n', foldername);
    %     end
    
    if isempty(polygon); interactive_mode = 1; else interactive_mode = 0; end
    cut_out_region = 1;
    if cut_out_region
        
        redo = 1;
        while redo == 1
            if interactive_mode
                zoom_str = 'Zoom first and then define your region\n - Press r if you are ready to define your region:\n - Press q if you want to quit:\n';
                reply = 'y';
                polygon = [];
                while ~strcmp(reply,'r')
                    reply = input(zoom_str, 's');
                    if strcmp(reply,'r')
                        polygon = climada_define_polygon;
                    elseif strcmp(reply,'q')
                        reply = 'r';
                    end
                end
            end
            if ~isempty(polygon)
                cn = inpoly([entity.assets.lon' entity.assets.lat'],polygon);
                if ~any(cn)
                    fprintf('No assets within this polygon. Unable to proceed.\n')
                    return
                end
                entity_ori = entity;
                entity.assets.lon           = entity.assets.lon(cn);
                entity.assets.lat           = entity.assets.lat(cn);
                entity.assets.Value         = entity.assets.Value(cn);
                entity.assets.Deductible    = entity.assets.Deductible(cn);
                entity.assets.Cover         = entity.assets.Cover(cn);
                entity.assets.DamageFunID   = entity.assets.DamageFunID(cn);
                entity.assets.Value_today   = entity.assets.Value_today(cn);
                entity.assets.centroid_index= entity.assets.centroid_index(cn);
                
                clf
                cbar = plotclr(entity.assets.lon, entity.assets.lat, entity.assets.Value,'s',markersize,1,...
                    [],[],[],[],1);
                set(get(cbar,'ylabel'),'String', 'USD (exponential)' ,'fontsize',12);
                hold on
                box on
                climada_plot_world_borders(0.5)
                title(entity.assets.hazard.comment)
                plot(entity_ori.assets.lon(~cn),entity_ori.assets.lat(~cn),'s','markersize',markersize,'color',[199 199 199]/255);
                axis(ax_lim)
                axis equal
                axis(ax_lim)
                
                if interactive_mode
                    rep = input('Redo polyon? Type y/n: ', 's');
                    if ~strcmp(rep,'y')
                        redo = 0;
                    else
                        redo = 1;
                        entity = entity_ori;
                        clf
                        cbar = plotclr(entity.assets.lon, entity.assets.lat, entity.assets.Value,'s',markersize,1,...
                            [],[],[],[],1);
                        set(get(cbar,'ylabel'),'String', 'USD (exponential)' ,'fontsize',12);
                        climada_plot_world_borders(0.5)
                        title(entity.assets.hazard.comment)
                        axis(ax_lim)
                        axis equal
                        axis(ax_lim)
                    end
                else
                    redo = 0;
                end
            end %isempty polygon
        end %redo
    end %cut_out_region
end

% cut out the centroids
cn = inpoly([centroids.lon' centroids.lat'],polygon);
centroids.lon     = centroids.lon(cn);
centroids.lat      = centroids.lat(cn);
% centroids.centroid_ID = centroids.centroid_ID(cn);
centroids.centroid_ID   = 1:sum(cn);
centroids.onLand        = centroids.onLand(cn);
centroids.country_name  = centroids.country_name(cn);
if isfield(centroids,'dist_to_coast')
    centroids.dist_to_coast  = centroids.dist_to_coast(cn);
end

% plot(centroids.lon, centroids.lat, 'xr')

% encode assets to new centroids
entity.assets = climada_assets_encode(entity.assets,centroids);

% climada_plot_world_borders
% plot(centroids.lon(1:1341), centroids.lat(1:1341), 'xr')
% plot(centroids.lon(1342:end), centroids.lat(1342:end), '.b')

end