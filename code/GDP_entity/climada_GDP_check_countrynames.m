function GDP = climada_GDP_check_countrynames(GDP, borders, silent_mode)

% compare countrynames of GDP with climada worldmap (borders.mat)
% NAME:
%   climada_GDP_read
% PURPOSE:
%   check county names of GDP (worldbank) with climada worldmap country names
%   and add index within GDP structure to refer to the index of the relevant
%   country within climada world map structure (borders structure)
%   previous: climada_GDP_read
%   next: diverse
% CALLING SEQUENCE:
%   GDP = climada_GDP_check_countrynames(GDP, borders, silent_mode)
% EXAMPLE:
%   GDP = climada_GDP_check_countrynames
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   GDP: a struct, if not given, prompted for, with following fields
%         .country_names: sorted countrynames (207 countries)
%         .year         : vector of all the years that GDP is available for
%         .value        : GDP value in USD per country
%         .comment      : information about GDP data
%         .description  : use for plot as colorbarlabel
%   borders             : the borders-strucuture-mat-file in systems folder
%                         (created in function climada_world_border)
%   silent_mode         :  if set to 1, no print out messages
% OUTPUTS:
%  GDP: including field
%        .country_borders_index: index to relate to climada worldmap
%                                borders.name (can have more than one index
%                                if within a group (e.g. china for china
%                                and taiwan in climada worldmap))
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20120730
%-


global climada_global
if ~climada_init_vars,return;end % init/import global variables
if ~exist('GDP'        , 'var'), GDP         = []; end
if ~exist('borders'    , 'var'), borders     = []; end
if ~exist('silent_mode', 'var'), silent_mode = 0 ; end

% set modul data directory
modul_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% prompt for GDP if not given
if isempty(GDP) % local GUI
    GDP          = [modul_data_dir filesep '*.mat'];
    GDP_default  = [modul_data_dir filesep 'Select GDP .mat'];
    [filename, pathname] = uigetfile(GDP, 'Select GDP mat file:',GDP_default);
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        GDP = fullfile(pathname,filename);
    end
end

% load the GDP structure, if a filename has been passed
if ~isstruct(GDP)
    GDP_file    = GDP;
    GDP         = [];
    load(GDP_file);
end

% load the borders file, if not given
if isempty(borders),borders = climada_load_world_borders;end


%% GDP.no_countries
not_found_names = {};
for GDP_country_i = 1:length(GDP.country_names)
    tf = strcmp(GDP.country_names(GDP_country_i), borders.name);
    if tf == 0
        if ~silent_mode
            cprintf([255 193 37]/255,'\t%d: no match found for GDP country name %s\n',GDP_country_i, GDP.country_names{GDP_country_i});
        end
        GDP.country_borders_index{GDP_country_i,1} = nan;
        not_found_names{end+1,1} = GDP.country_names{GDP_country_i};
    else
        if ~silent_mode
            %fprintf('\t%d: GDP country name %s matches borders.name{%d}: %s\n',...
            %    GDP_country_i, GDP.country_names{GDP_country_i}, find(tf),borders.name{tf})
        end
        
        % check if that country name belongs to a group, check groupID
        if borders.groupID(tf)>0
            group_index = borders.groupID == borders.groupID(tf);
            GDP.country_borders_index{GDP_country_i,1} = find(group_index);
            c_names = sprintf('%s, ',borders.name{group_index}); c_names(end-1:end) = [];
            if ~silent_mode
                fprintf('\t - GDP %s is applied to \n\t\t\t %s\n',GDP.country_names{GDP_country_i}, c_names)
            end
        else
            GDP.country_borders_index{GDP_country_i,1} = find(tf);
        end
    end
end
nr_found_names = sum(~isnan( [GDP.country_borders_index{:}] ));
if ~silent_mode,fprintf('GDP country name matched for %d countries within climada world map. \n',nr_found_names);end


index_borders_name        = 1:length(borders.name);
index_country_without_GDP = ~ismember(index_borders_name, [GDP.country_borders_index{:}]);
country_without_GDP       = sort(borders.name(index_country_without_GDP))';

if ~silent_mode
    fprintf('No GDP information available for following %d countries (within climada worldmap):\n', length(country_without_GDP))
    for c_i = 1:length(country_without_GDP)
        fprintf('\t - %s\n',country_without_GDP{c_i})
    end
end







