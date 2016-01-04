function [entity,scale_up_factor]=climada_entity_scaleup_GDP(entity,GDP_future,year_future,year_start,centroids,borders,check_figure,check_printplot)
% upscale a given entity based on GDP growth between two periods
% NAME:
%   climada_entity_scaleup_GDP
% PURPOSE:
%   upscale a given entity based on GDP growth between two periods
% CALLING SEQUENCE:
%   entity = climada_entity_scaleup_GDP(entity, GDP_future,
%   year_future, year_start, centroids, borders, check_figure, check_printplot)
% EXAMPLE:
%   entity = climada_entity_scaleup_GDP(entity, '', 2030, 2012)
% INPUTS:
%   none
% OPTIONAL INPUTS:
%   entity       : entity with entity.assets, prompted for it not given
%   GDP_future   : GDP data structure based on IMF data, automatically
%                  loaded from mat-file or newly read from xls if available
%   year_future  : e.g. 2030, default 2030
%   year_start   : e.g. 2012, default 2012
%   centroids    : centroids structure, with centroids.country_name to link
%                  GDP data with entity.assets, prompted for if not given
%   borders      : border structure (with name, polygon for every country)
%   check_figure : set to 1 to visualize figures, default 1
%   check_printplot : set to 1 to save figure, default 0
% OUTPUTS:
%   entity: assets upscaled based on GDP growth
%   a structure, with
%       assets: a structure, with
%           Latitude: the latitude of the values
%           Longitude: the longitude of the values
%           Value: the total insurable value
%           Deductible: the deductible
%           Cover: the cover
%           DamageFunID: the damagefunction curve ID
%       damagefunctions: a structure, with
%           DamageFunID: the damagefunction curve ID
%           Intensity: the hazard intensity
%           MDD: the mean damage degree
% MODIFICATION HISTORY:
% Lea Mueller, 20130412
% Melanie Bieli, 20150125, added scale_up_factor as an additional output parameter 
% David N. Bresch, david.bresch@gmail.com, 20150819, climada_global.centroids_dir
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('entity'         , 'var'), entity          = [];end
if ~exist('GDP_future'     , 'var'), GDP_future      = [];end
if ~exist('year_future'    , 'var'), year_future     = 2030; end
if ~exist('year_start'     , 'var'), year_start      = 2012;end
if ~exist('centroids'      , 'var'), centroids       = [];end
if ~exist('borders'        , 'var'), borders         = [];end
if ~exist('check_figure'   , 'var'), check_figure    = 1 ;end
if ~exist('check_printplot', 'var'), check_printplot = [];end

% set module data directory
modul_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

xlsfilename = [modul_data_dir filesep 'World_GDP_constant_2000_2017.xlsx'];

if isempty(entity)
    entity = climada_entity_load;
end


% economic development (asset upscaling)
if isempty(GDP_future)
    silent_mode = 1;
    if exist(xlsfilename,'file')
        GDP_future = climada_GDP_read(xlsfilename, 1, 1, silent_mode);
        %save(strrep(xlsfilename,'.xls','.mat'), 'GDP_future')
    else
        xlsfilename = [];
        GDP_future = climada_GDP_read(xlsfilename, 1, 1, silent_mode);
        if isempty(GDP_future)
            entity = []; fprintf('GDP forecast data not available.\n');
            return
        end
    end
end

% prompt for centroids if not given
if isempty(centroids) % local GUI
    centroids         = [climada_global.centroids_dir filesep '*.mat'];
    [filename, pathname] = uigetfile(centroids, 'Select centroids to encode to:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        centroids = fullfile(pathname,filename);
    end
end
% load the centroids, if a filename has been passed
if ~isstruct(centroids)
    centroids_file = centroids;
    centroids      = [];
    load(centroids_file);
end

% prompt for borders if not given
if isempty(borders)
    if isfield(climada_global,'map_border_file')
        %map_border_file = strrep(climada_global.map_border_file,'.gen','.mat');
        map_border_file = [modul_data_dir filesep 'world_50m.mat'];
    else
        fprintf('Error: no map found, aborted\n')
        return
    end
    try
        load(map_border_file)
    catch err
        fprintf('create and save world borders as mat-file...')
        climada_plot_world_borders
        close
        fprintf('done\n')
        load(map_border_file)
    end
end
if ~isfield(borders,'region')
    borders = climada_borders_region(borders,[],0);
end


% basic check if entity matches with centroids
uni_index = unique(entity.assets.centroid_index);
if all(ismember(uni_index,centroids.centroid_ID))
    fprintf('Assets are all encoded to valid centroids\n')
else
    fprintf('Error: Not all assets within entities match with given centroids, aborted\n')
    entity = [];
    return
end


% check if centroids have ISO3 country codes (for each centroid)
country_index = ismember(centroids.centroid_ID, uni_index);
country_uni   = unique(centroids.country_name(country_index));
iscountry     = ~ismember(country_uni,{'buffer' 'grid'});
country_uni   = country_uni(iscountry);
if length(country_uni) == 1 && isempty(country_uni{1})
    fprintf('Error: No country names for centroids, aborted\n')
    entity = [];
    return
end

% initialize GDP extrapolation figure
if check_figure
    %fig = climada_figuresize(0.4,0.8);
    fig = climada_figuresize(0.4,0.8);
    set(fig,'Name','Entity scale up')
    subaxis(1,3,1,'SpacingHoriz',0.08,'MarginLeft',0.08,'MarginRight',0.0,'MarginTop',0.1,'MarginBottom',0.4 )
    hold on
    %ylabel('GDP (USD)')
    ylabel(GDP_future.description)
    titlestr = sprintf('Forecasted GDP from %d to %d', year_start, year_future);
    title({titlestr ; 'current prices'})
    xlim([GDP_future.year(1) year_future+5])
    plot([year_start year_start])
    %xlim([year_start-1 year_future+5])
    subaxis(2)
    hold on
    xlim([year_start-1 year_future+5])
    ylabel_ = sprintf('GDP (scaled to %d)',year_start);
    ylabel(ylabel_)
    titlestr = sprintf('GDP %d is set to 1', year_start);
    title(titlestr)
    legendstr = {'IMF forecast';'Extrapolation'};
    if length(country_uni)== 1
        color_ = [0 0 205]/255; %blue
    else
        color_    = jet(length(country_uni));
    end
    %color_    = lines(length(ISO3_uni));
    counter   = 0;
    h         = [];
end


% calculate scale up factors for each country
scale_up_factor = zeros(1,length(country_uni));

for c_i = 1:length(country_uni)
    % find centroids and assets within specific country
    c_name  = strcmp(country_uni(c_i), borders.name);
    if any(c_name)
        %fprintf('%s\n',borders.name{c_name})
        if sum(c_name)>1
            c_name = find(c_name,1);
        end
        %fprintf('%s\n',borders.name{c_name})
        c_index = strcmp(borders.name(c_name), GDP_future.country_names);
    else
        c_index = '';
        fprintf('No country found for "%s"\n', country_uni{c_i})
    end
    if ~any(c_index) %&& ~strcmp(ISO3_uni(c_i),'sea')
        if borders.groupID(c_name)>0
            groupIndex = borders.groupID == borders.groupID(c_name);
        else
            groupIndex = [];
        end
        %group_str = sprintf('%s, ', borders.name{groupIndex}); group_str(end-1:end) = [];
        %is_nan = cellfun(@isnan,GDP_future.country_names, 'UniformOutput', false);
        %GDP_future.country_names{219}
        
        %isnan(GDP_future.country_names)
        [a,ia] = ismember(borders.name(groupIndex), GDP_future.country_names);
        c_index = ia(ia>0);
        if length(c_index)>1
            names_str = sprintf('%s, ',GDP_future.country_names{c_index}); names_str(end-1:end) = [];
            fprintf('More than one country within group has GDP information (%s)\n',names_str);
            c_index = c_index(1);
            fprintf('Take GDP information  from %s\n',GDP_future.country_names{c_index});
            fprintf('%s is not in GDP database, but in group with %s\n',borders.name{c_name}, GDP_future.country_names{c_index})
        else
            fprintf('%s is not in GDP database\n',borders.name{c_name})
        end
    end
    if any(c_index) && any(~isnan(GDP_future.value(c_index,:))) && any(nonzeros(GDP_future.value(c_index,:)))
        % check if requested year is within the forecasted values
        year_f_index = find(GDP_future.year == year_future);
        year_s_index = find(GDP_future.year == year_start, 1);
        if isempty(year_s_index); year_s_index = 1; end
        if ~isempty(year_f_index)
            GDP_fit = GDP_future.value(c_index,year_s_index:year_f_index);
            scale_up_factor(c_i) = GDP_fit(end)/GDP_fit(1);
        else
            %extrapolate with first order polynom
            %p_GDP   = polyfit(GDP_future.year(year_s_index:end), GDP_future.value(c_index,year_s_index:end),1);
            GDP_future_country = GDP_future.value(c_index,:);
            valid_indx         = ~isnan(GDP_future_country);
            p_GDP   = polyfit(GDP_future.year(valid_indx), GDP_future_country(valid_indx), 1);
            GDP_fit = [GDP_future.value(c_index,year_s_index:end)...
                polyval(p_GDP, GDP_future.year(end)+1:year_future)];
            % calculate scale up factor for specific forecast year
            scale_up_factor(c_i) = GDP_fit(end)/GDP_fit(1);
        end
        
        if check_figure
            counter = counter+1;
            hold on
            %h(end+1)= plot(subaxis(1),GDP_future.year(year_s_index:end), GDP_future.value(c_index,year_s_index:end),'.-','color',color_(counter,:));
            h(end+1) = plot(subaxis(1),GDP_future.year, GDP_future.value(c_index,:),'.-','color',color_(counter,:));
            g        = plot(subaxis(1),GDP_future.year(year_s_index):year_future, GDP_fit,':','color',color_(counter,:));
            plot(subaxis(1),year_future, GDP_fit(end),'o','color',color_(counter,:))
            
            % plot in percentage, base 2010 or indicated year_start
            %plot(subaxis(2),GDP_future.year(year_s_index:end), GDP_future.value(c_index,year_s_index:end)/GDP_future.value(c_index,year_s_index), '.-','color',color_(counter,:));
            plot(subaxis(2),GDP_future.year, GDP_future.value(c_index,:)/GDP_future.value(c_index,year_s_index), '.-','color',color_(counter,:));
            plot(subaxis(2),GDP_future.year(year_s_index):year_future, GDP_fit/GDP_fit(1), ':','color',color_(counter,:));
            plot(subaxis(2),year_future, GDP_fit(end)/GDP_fit(1),'o','color',color_(counter,:))
            plot(subaxis(2),year_start, GDP_fit(1)/GDP_fit(1),'x','color',color_(counter,:))
            
            text(year_future+1.5, GDP_fit(end)/GDP_fit(1), [num2str(scale_up_factor(c_i),'%2.2f')],'VerticalAlignment','cap','HorizontalAlignment','left',...
                'color',color_(counter,:),'fontsize',7,'Parent', subaxis(2))
            %legendstr{end+1} = borders.name{c_name};
            legendstr{end+1} = [num2str(scale_up_factor(c_i),'%2.2f') ': ' borders.name{c_name}];
        end
    else
        fprintf('WARNING: %s: no GDP data available\n',borders.name{c_name});
        return
    end
end
if check_figure;
    legend([h(1) g h],legendstr,'location',[0.73 0.4 0.2 0.4],'fontsize',7)
    if isempty(year_f_index); ylim([0.9 max(scale_up_factor)*1.1]); end
    if check_printplot
        token      = strrep(strtok(entity.assets.filename,','),' ','');
        printname  = sprintf('Scale_up_%s_%d_%d.pdf', token, year_start, year_future);
        foldername = [filesep 'results' filesep printname];
        print(fig,'-dpdf',[climada_global.data_dir foldername])
        cprintf([255 127 36 ]/255,'\t\t saved 1 FIGURE in folder ..%s \n', foldername);
    end
end


% take scale up factors for requested year
scale_mean = mean(scale_up_factor(scale_up_factor>0));
scale_up_factor(scale_up_factor == 0) = scale_mean;
% scale_up_factor(scale_up_factor == 0) = default_scale_up_factor;


% scale up assets for forecast year with calculated scale up factors
for c_i = 1:length(country_uni)
    % find centroids and assets within specific country
    cen_index = strcmp(country_uni{c_i}, centroids.country_name);
    en_index  = ismember(entity.assets.centroid_index, centroids.centroid_ID(cen_index));
    if any(en_index)
        entity.assets.Value(en_index)      = scale_up_factor(c_i) * entity.assets.Value(en_index);
        entity.assets.Deductible(en_index) = scale_up_factor(c_i) * entity.assets.Deductible(en_index);
        entity.assets.Cover(en_index)      = scale_up_factor(c_i) * entity.assets.Cover(en_index);
        fprintf('%d centroids are within %s\n', sum(en_index), country_uni{c_i})
    else
        fprintf('No centroids within %s\n',country_uni{c_i})
    end
end
entity.assets.hazard.comment = [entity.assets.hazard.comment ', scaled up for ' int2str(year_future)];
entity.assets.reference_year = year_future;
token = strtok(entity.assets.filename,',');
fprintf('Entity assets "%s" scaled from %d to %d with average scale up factor %2.2f\n', token, year_start, year_future, mean(scale_up_factor))
fprintf('Entity assets sum is %2.4g USD \n', sum(entity.assets.Value))

end
