% selected_countries_all_in_one
% climada template
% MODULE:
%   module name
% NAME:
%   selected_countries_all_in_one, run all project countries, all calculations
%
%   run as a batch code, such that all is available on command line
% PURPOSE:
%   Run all climada for project
%
%   In order to synchronize all entities with GDP etc, country_risk_calc
%   uses climada_entity_value_GDP_adjust
%
% CALLING SEQUENCE:
%   selected_countries_all_in_one
% EXAMPLE:
%   selected_countries_all_in_one
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150105
% David N. Bresch, david.bresch@gmail.com, 20150116, almost complete
% David N. Bresch, david.bresch@gmail.com, 20150121, GDP adjust added
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('param1','var'),param1=[];end

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];


% PARAMETERS
%
% swithes to run only parts of the code:
% --------------------------------------
%
% to check for climada-conformity of country names
check_country_names=1; % default=0, if=1, stops after check
%
% to generate entities
generate_entities=0; % default=0, if=1, stops after
add_distance2coast=0; % default=0, if=1, stops after
%
% whether we calculate admin1 level
calculate_admin1=0; % default=1, but set to =0 for TEST
%
generate_property_damage_report=1; % default=0, we need the economic loss report
generate_economic_loss_report=1; % default=1, the final economic loss report
%
property_damage_report_filename=[climada_global.data_dir filesep 'results' filesep 'property_damage_report.xls'];
economic_loss_report_filename  =[climada_global.data_dir filesep 'results' filesep 'economic_loss_report.xls'];
%
country_data_dir=climada_global.data_dir;
%
% parameters for country_risk_calc
% method=-3: default, using GDP_entity and probabilistic sets, see country_risk_calc
% method=3: using GDP_entity and historic sets, see country_risk_calc
% method=-7: skip entity and hazard generation, probabilistic sets, see country_risk_calc
country_risk_calc_method=-7; % default=-3, using GDP_entity and probabilistic sets, see country_risk_calc
country_risk_calc_force_recalc=0; % default=0, see country_risk_calc
%
country_list={
    'Algeria'
    'Australia'
    'Austria'
    'Belgium'
    'Bangladesh'
    'Brazil'
    'Canada'
    'Cambodia'
    'Chile'
    'China'
    'Colombia'
    'Costa Rica'
    'Czech Republic'
    'Denmark'
    'Dominican Republic'
    'Ecuador'
    'Finland'
    'France'
    'Germany'
    'Greece'
    'Hungary'
    'India'
    'Indonesia'
    'Ireland'
    'Israel'
    'Italy'
    'Japan'
    'Kenya'
    'Laos'
    'Mexico'
    'Morocco'
    'Myanmar'
    'Netherlands'
    'New Zealand'
    'Nigeria'
    'Norway'
    'Pakistan'
    'Panama'
    'Peru'
    'Philippines'
    'Poland'
    'Portugal'
    'Singapore'
    'Slovakia'
    'Slovenia'
    'South Africa'
    'Korea'
    'Spain'
    'Sri Lanka'
    'Sweden'
    'Switzerland'
    'Taiwan'
    'Thailand'
    'Tunisia'
    'Turkey'
    'United Kingdom'
    'United States'
    'Uruguay'
    'Vietnam'
    };
%
% TEST list (only a few)
% ----
% country_list={
%     'Philippines'
%     'Mexico'
%     'Italy'
%     };
%
% LOCAL TEST
% country_list={
%     'Aruba'
%     'Australia'
%     'Bangladesh'
%     'Bermuda'
%     'Switzerland'
%     'Chile'
%     'China'
%     'Cuba'
%     'Germany'
%     'Dominican Republic'
%     'Algeria'
%     'Greece'
%     'Indonesia'
%     'India'
%     'Israel'
%     'Italy'
%     'Japan'
%     'Mexico'
%     'Philippines'
%     'Singapore'
%     'El Salvador'
%     'Taiwan'
%     'Vietnam'
%     };
% LOCAL TEST
% country_list={
%     'Greece'
%     'Taiwan'
%     'Vietnam'
%     };
%
% more technical parameters
climada_global.waitbar=0; % switch waitbar off


% check names
if check_country_names
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        fprintf('%s: %s %s\n',country_list{country_i},country_name,country_ISO3);
        
        entity_file=[country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name,' ','') '_entity.mat'];
        if ~exist(entity_file,'file'),fprintf('WARNING: entity missing %s\n',entity_file);end
        
        hazard_TC_file=[country_data_dir filesep 'hazards' filesep country_ISO3 '_' strrep(country_name,' ','') '_*TC.mat'];
        D=dir([country_data_dir filesep 'hazards' filesep country_ISO3 '_' strrep(country_name,' ','') '_*.mat']);
        for D_i=1:length(D)
            if ~D(D_i).isdir
                fprintf(' - %s\n',D(D_i).name);
            end
        end % D_i
    end % country_i
    fprintf('STOP after check_country_names\n')
    return
end

% generate entites only
if generate_entities
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        country_name_char = char(country_name); % as to create filenames etc., needs to be char
        
        % define easy to read filenames
        centroids_file     = [country_data_dir filesep 'system'   filesep country_ISO3 '_' strrep(country_name_char,' ','') '_centroids.mat'];
        entity_file        = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
        entity_future_file = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity_future.mat'];
        
        if ~exist(entity_file,'file')
            % invoke the GDP_entity module to generate centroids and entity
            [centroids,entity,entity_future] = climada_create_GDP_entity(country_name_char,[],0,1);
            if isempty(centroids), return, end
            save(centroids_file,'centroids');
            save(entity_file,'entity');
            climada_entity_value_GDP_adjust(entity_file); % assets based on GDP
            entity = entity_future; %replace with entity future
            save(entity_future_file,'entity');
            climada_entity_value_GDP_adjust(entity_future_file); % assets based on GDP
        end
    end % country_i
    return
end % generate_entities

if add_distance2coast
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        country_name_char = char(country_name); % as to create filenames etc., needs to be char
        
        % define easy to read filenames
        centroids_file    = [country_data_dir filesep 'system'   filesep country_ISO3 '_' strrep(country_name_char,' ','') '_centroids.mat'];
        load(centroids_file)
        if ~isfield(centroids,'distance2coast_km')
            fprintf('%s %s: adding distance2coast_km\n',country_ISO3,country_name_char);
            centroids.distance2coast_km=climada_distance2coast_km(centroids.lon,centroids.lat);
            save(centroids_file,'centroids')
        end
    end % country_i
    return
end % add_distance2coast

% calculate damage on admin0 (country) level
country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0);
country_risk=country_risk_EDS_combine(country_risk); % combine TC and TS

% adjust country Value
%cr_entity_value_adjust % Melanie's code

if calculate_admin1
    % calculate damage on admin1 (state/province) level
    probabilistic=0;if country_risk_calc_method<0,probabilistic=1;end
    country_risk1=country_admin1_risk_calc(country_list,probabilistic,0);
    country_risk1=country_risk_EDS_combine(country_risk1); % combine TC and TS
end

% annual aggregate where appropriate - NOT IMPLEMENTED YET
country_risk=country_risk_EDS2YDS(country_risk);

% calibrate property damage - NOT IMPLEMENTED YET
% see climada_DFC_compare (and call it for country_risk structure)

if generate_property_damage_report
    if calculate_admin1
        country_risk_report([country_risk country_risk1],1,property_damage_report_filename);
    else
        country_risk_report(country_risk,1,property_damage_report_filename);
    end
end

% calculate economic loss (first on country basis)
country_risk_economic_loss=cr_economic_loss_calc(country_risk);

if generate_economic_loss_report
    country_risk_report(country_risk_economic_loss,1,economic_loss_report_filename);
end
