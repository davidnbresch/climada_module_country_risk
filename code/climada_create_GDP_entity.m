function [centroids,entity,entity_future]=climada_create_GDP_entity(country_name,polygon,check_figure,no_wbar)
% GDP entity assets
% MODULE:
%   GDP_entity
% NAME:
%   climada_create_GDP_entity
% PURPOSE:
%   create centroids and entity for a specific country, distribute assets
%   and value according to night light intensities and scale up to match 
%   GDP today (see climada_global.present_reference_year) and a future (see
%   climada_global.future_reference_year) scenario 
% CALLING SEQUENCE:
%   [centroids entity entity_future] = climada_create_GDP_entity(country_name,polygon,check_figure,no_wbar)
% EXAMPLE:
%   [centroids entity entity_future] = climada_create_GDP_entity
%   [centroids entity entity_future] = climada_create_GDP_entity('Mexico')
% INPUTS:
%   country_name: the name of the country or an ISO3 country code (like
%       'CHE'), see climada_country_name
%   polygon: do restrict to centroids in polygon, calls
%       climada_cut_out_GDP_entity, see parameters there.
%   check_figure: set to 1 to visualize figures, default 1
%   no_wbar: 1 to suppress waitbars
%   OBSOLETE (not supported any more): GDP: GDP data within a structure, 
%       prompted for if not given, loaded automatically from economic_indicators_mastertable.mat file if existing
%       --> all automatic now
% OUTPUTS:
%   centroids: a structure with fields centroid_ID, Latitude, Longitude,
%       onLand, country_name, comment for each centroid
%   entity         : a structure with fields assets, damagefunctions, measures,
%                    discount. Assets values are based on night light 
%                    intensity and scaled up to todays GDP (e.g. 2014)
%   entity_future  : entity strucure with values scaled to a future GDP
%                    scenario
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20140206
% David N. Bresch, david.bresch@gmail.com, 20141209, country ISO3 enabled
% David N. Bresch, david.bresch@gmail.com, 20141212, migrated to world_50m.gen being local to GDP_entity, as climada moved to admin0.mat
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150125, incorporated climada_entity_value_GDP_adjust to scale up the entity, ... 
%                                                    climada_entity_GDP not used anymore
% David N. Bresch, david.bresch@gmail.com, 20150204, cleanup
% David N. Bresch, david.bresch@gmail.com, 20150804, cleanup
%-

% init output
centroids=[];entity=[];entity_future=[];

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

if ~exist('country_name', 'var'), country_name = []  ; end
if ~exist('polygon', 'var'),      polygon = []  ; end
if ~exist('check_figure', 'var'), check_figure = 1; end
if ~exist('no_wbar'     , 'var'), no_wbar      = 1; end

% PARAMETERS
%
% set the parameters according to your needs
asset_resolution_km      = 10;
year_start               = climada_global.present_reference_year;
year_future              = climada_global.future_reference_year;
%
check_printplot          = 0;
check_for_groups         = 0;

% create entity_base (all values add up to 100 within the specified country) and create the centroids on the required resolution
[centroids,entity]=climada_create_centroids_entity_base(country_name,...
    asset_resolution_km,0,check_for_groups,'','','','',...
    check_figure,0,no_wbar); 
                                                    
if isempty(entity), return, end % something went wrong, error already thrown in climada_create_centroids_entity_base
  
% fill in reference year
entity.assets.reference_year = climada_global.present_reference_year;

% adjust Values to sum up to country GDP
entity=climada_entity_value_GDP_adjust_one(entity,2);

% generate future entity by scaling up the adjusted entity
[~, scale_up_factor]= climada_entity_scaleup_GDP(entity,[],year_future,year_start,centroids,'',check_figure,check_printplot);

% scale up entity with that factor to generate entity_future 
entity_future=climada_entity_scaleup_factor(entity,scale_up_factor);   
entity_future.assets.reference_year = climada_global.future_reference_year;

if ~isempty(polygon)
    if numel(polygon) == 1, polygon = []; end
    [centroids,entity]        = climada_cut_out_GDP_entity(entity       ,centroids,polygon);
    [centroids,entity_future] = climada_cut_out_GDP_entity(entity_future,centroids,polygon);
end

end % climada_create_GDP_entity