function entity = climada_entity_GDP(entity_base, GDP, year_requested, centroids, borders, check_figure, check_printplot)
% upscale given base entity (sum of assets is 100, or less if only coastal
% areas) to match the GDP of a specific country for a given year
% NAME:
%   climada_entity_GDP
% PURPOSE:
%   Upscale entity to a GDP of a given country and year, read GDP data from
%   worldbank/IMF, find country for given entity/centroids
% CALLING SEQUENCE:
%   entity = climada_entity_GDP(entity_100, GDP, year_start, centroids,
%   borders, check_figure, check_printplot)
% EXAMPLE:
%   entity = climada_entity_GDP(entity_100, GDP, 2014, centroids)
% INPUTS:
%   entity_base: entity with entity.assets.Value sum up to 100 for the
%   entire country (if only coastal areas, sum is less than 100)
% OPTIONAL INPUTS:
%   GDP       : GDP data within a structure, prompted for if not given, loaded
%               automatically from GDP.mat file if existing
%   year_requested: year for GDP for a given country, default
%               climada_global.present_reference_year
%   centroids : prompted if not given, centroids with field .country_name
%               for each centroid indicating the country matching with GDP data
%   borders   : border structure (with name, polygon for every country)
%   check_figure   : 1 to visualize figure
%   check_printplot: 1 to print/save figure
% OUTPUTS:
%   entity             : assets upscaled to a GDP of a country and a given year
%   a structure, with
%       assets         : a structure, with
%           Latitude   : the latitude of the values
%           Longitude  : the longitude of the values
%           Value      : the total insurable value
%           Deductible : the deductible
%           Cover      : the cover
%           DamageFunID: the damagefunction curve ID
%       damagefunctions: a structure, with
%           DamageFunID: the damagefunction curve ID
%           Intensity  : the hazard intensity
%           MDD        : the mean damage degree
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140206
% David N. Bresch, david.bresch@gmail.com, 20141105,
% David N. Bresch, david.bresch@gmail.com, 20150819, climada_global.centroids_dir
%-

entity = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('entity_base'    , 'var'), entity_base     = [];end
if ~exist('GDP'            , 'var'), GDP             = [];end
if ~exist('year_requested' , 'var'), year_requested  = climada_global.present_reference_year;end
if ~exist('centroids'      , 'var'), centroids       = [];end
if ~exist('borders'        , 'var'), borders         = [];end
if ~exist('check_figure'   , 'var'), check_figure    = 1 ;end
if ~exist('check_printplot', 'var'), check_printplot = [];end

modul_data_dir      = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% excel file with GDP information
GDP_xls_filename = [modul_data_dir filesep 'World_GDP_current.xls'];


if isempty(entity_base)
    entity_base = climada_entity_load;
end

[~,fN]=fileparts(GDP_xls_filename);
fprintf('Step 1: Base entity to GDP current (from %s)\n',fN)


% read/load GDP data per country from 1960 to 2013
if isempty(GDP)
    [fP,fN]=fileparts(GDP_xls_filename);
    GDP_mat_filename   = [fP filesep fN '.mat'];
    
    if climada_check_matfile(GDP_xls_filename,GDP_mat_filename)
        load(GDP_mat_filename);
    else
        if exist(GDP_xls_filename,'file')
            GDP = climada_GDP_read(GDP_xls_filename, 1, 1, 1);
            if isempty(GDP),fprintf('\t\t GDP data not available.\n'),return;end
            fprintf('saving GDP as %s\n',GDP_mat_filename)
            save(GDP_mat_filename,'GDP');
        else
            fprintf('\t\t GDP data %s not found. Unable to proceed. \n', GDP_xls_filename)
            return
        end
    end
end

GDP_latest_year     = max(GDP.year);
fprintf('\t\t GDP data cover year %d to %d. \n', min(GDP.year), GDP_latest_year)

if year_requested < min(GDP.year)
    fprintf('\t\t Requested year (%d) lies to far back. Unable to proceed.\n', year_requested)
    return
end


% economic development (asset upscaling)
if year_requested > GDP_latest_year
    year_requested_step_2 = year_requested;
    year_requested        = GDP_latest_year;
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
    borders = climada_load_world_borders;
end
if isempty(borders), fprintf('Error: no map found, aborted\n'), return, end


% basic check if entity matches with centroids
uni_index = unique(entity_base.assets.centroid_index);
if all(ismember(uni_index,centroids.centroid_ID))
    fprintf('Assets are all encoded to valid centroids.\n')
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


% calculate GDP entity_base scale up factors for each country
% loop over countries, mostly just one country within one entity
for c_i = 1:length(country_uni)
    
    % find centroids and assets within specific country
    c_name  = strcmp(country_uni(c_i), borders.name);
    if any(c_name)
        %fprintf('%s\n',borders.name{c_name})
        if sum(c_name)>1
            c_name = find(c_name,1);
        end
        %fprintf('%s\n',borders.name{c_name})
        c_index = strcmp(borders.name(c_name), GDP.country_names);
    else
        c_index = '';
        fprintf('Warning: No country found for "%s"\n', country_uni{c_i})
    end
    
    
    if ~any(c_index) %&& ~strcmp(ISO3_uni(c_i),'sea')
        if borders.groupID(c_name)>0
            groupIndex = borders.groupID == borders.groupID(c_name);
        else
            groupIndex = [];
        end
        %group_str = sprintf('%s, ', borders.name{groupIndex}); group_str(end-1:end) = [];
        [a ia] = ismember(borders.name(groupIndex), GDP.country_names);
        c_index = ia(ia>0);
        if length(c_index)>1
            names_str = sprintf('%s, ',GDP.country_names{c_index}); names_str(end-1:end) = [];
            fprintf('More than one country within group has GDP information (%s)\n',names_str);
            c_index = c_index(1);
            fprintf('Take GDP information  from %s\n',GDP.country_names{c_index});
            fprintf('%s is not in GDP database, but in group with %s\n',borders.name{c_name}, GDP.country_names{c_index})
        else
            fprintf('%s is not in GDP database\n',borders.name{c_name})
        end
    end
    
    % country identified and GDP data for that country is available
    if any(c_index) && any(~isnan(GDP.value(c_index,:))) && any(nonzeros(GDP.value(c_index,:)))
        
        % check if requested year is within the forecasted values
        year_s_index = find(GDP.year == year_requested, 1);
        if isempty(year_s_index); year_s_index = 1; end
        
        % calculate scaleup_factor as
        % factor = "GDP for a given country and year" / "sum(assets)", whereas sum(assets) is 100 as defined by entity_base
        % factor = "GDP for a given country and year" / 100
        GDP_val        = GDP.value(c_index, year_s_index);
        if isnan(GDP_val)
            fprintf('No GDP value for year %d available. Stick with base entity where all assets sum up to 100.\n', year_requested)
            entity = entity_base;
            entity.assets.reference_year = 100;
            return
        end
        scaleup_factor = GDP_val / 100;
        entity         = climada_entity_scaleup_factor(entity_base, scaleup_factor);
        fprintf('GDP for %s in %d is %2.4g USD (current) \n',GDP.country_names{c_index}, year_requested, GDP_val);
        entity.assets.reference_year = year_requested;
        
        if sum(entity_base.assets.Value) >= 99.5 &&  sum(entity_base.assets.Value) <= 100.5
            fprintf('Entity assets covers %2.1f%% of %s, i.e. GDP for entire %s in %d is %2.4g USD\n',...
                sum(entity_base.assets.Value), GDP.country_names{c_index}, GDP.country_names{c_index}, year_requested, sum(entity.assets.Value));
        elseif sum(entity_base.assets.Value) <100
            fprintf('Entity assets covers %2.1f%% of %s, i.e. GDP for that region in %d is %2.4g USD\n',...
                sum(entity_base.assets.Value), GDP.country_names{c_index}, year_requested, sum(entity.assets.Value));
        end
    else
        fprintf('%s: no GDP data available. Stick with base entity where all assets sum up to 100.\n',borders.name{c_name})
        entity = entity_base;
        entity.assets.reference_year = 100;
        %return
    end
end

if exist('year_requested_step_2', 'var') % if year_requested > GDP_latest_year
    fprintf('Step 2: Entity based on GDP %d to entity based on GDP %d\n', GDP_latest_year, year_requested_step_2)
    if entity.assets.reference_year ~= 100
        GDP_future = [];
        entity = climada_entity_scaleup_GDP(entity, GDP_future, year_requested_step_2, GDP_latest_year, centroids, borders, check_figure, check_printplot);
    else
        fprintf('Stick with base entity where all assets sum up to 100.\n')
    end
end

if check_figure,climada_plot_entity_assets(entity, centroids, country_uni{1}, check_printplot);end

end