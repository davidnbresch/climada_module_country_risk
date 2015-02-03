% selected_countries_CAM
% climada template
% MODULE:
%   country_risk
% NAME:
%   selected_countries_CAM, run all CAM project countries, all calculations
%
%   run this code (see PARAMETERS)
%   - first with  check_country_names=1;
%     > checks for country list being ok
%   - second with check_country_names=0;generate_entities=1;
%     > generates the entities, adjusts them to GDP
%   - third with  check_country_names=0;generate_entities=0;
%     > generates all hazard event sets and calculates damages
%
%   If you then repeat the third step, since all hazard sets are stored, it
%   will be fast and easy to play with parameters (e.g. damage functions).
%
%   SPECIAL: in order to process CAM files only, the global variable
%   climada_global.tc.default_raw_data_ext is set to '.nc' to avoid
%   processing the UNISYS ('.txt') files in tc_track, see code
%   centroids_generate_hazard_sets
%
%   run as a batch code, such that all is available on command line
% PURPOSE:
%   Run all climada for project
%
%   In order to synchronize all entities with GDP etc, country_risk_calc
%   uses climada_entity_value_GDP_adjust
%
% CALLING SEQUENCE:
%   selected_countries_CAM
% EXAMPLE:
%   selected_countries_CAM
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150203, initial (on ICE to Paris)
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
%module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];


% PARAMETERS
%
% switches to run only parts of the code:
% ---------------------------------------
%
climada_global.tc.default_raw_data_ext='.nc'; % to restrict to netCDF TC track files
%
% to check for climada-conformity of country names
check_country_names=1; % default=0, if=1, stops after check
%
% to generate entities
generate_entities=0; % default=0, if=1, stops after
USA_UnitedStates_entity_treatment=1; % =1, treat USA entity, see code below
NZL_NewZealand_entity_treatment=1; % =1, treat NZL entity, see code below
%
% parameters for country_risk_calc
% method=-3: default, using GDP_entity and probabilistic sets, see country_risk_calc
% method=3: FAST for checks, using GDP_entity and historic sets, see country_risk_calc
% method=-7: skip entity and hazard generation, probabilistic sets, see country_risk_calc
country_risk_calc_method=3; % default=-3, using GDP_entity and probabilistic sets, see country_risk_calc
country_risk_calc_force_recalc=0; % default=0, see country_risk_calc
%
% whether we calculate admin1 level (you might not set this =1 for the full
% country list, i.e. first run all requested countries with
% calculate_admin1=0, then restrict the list and only run with
% calculate_admin1=1 for these (e.g. USA, CHN...)
calculate_admin1=0; % default=1, but set to =0 for TEST
%
generate_damage_report=1; % default=0, we need the economic loss report
damage_report_filename=[climada_global.data_dir filesep 'results' filesep 'CAM_damage_report.xls'];
%
% the explicit list of countires we'd like to process
% see climada_country_name('ALL'); to obtain it
country_list={
    %'Afghanistan'
    %'Akrotiri'
    %'Aland'
    %'Albania'
    %'Algeria'
    %'American Samoa'
    %'Andorra'
    %'Angola'
    'Anguilla'
    %'Antarctica'
    'Antigua and Barbuda'
    %'Argentina'
    %'Armenia'
    'Aruba'
    %'Ashmore and Cartier Islands'
    'Australia'
    %'Austria'
    %'Azerbaijan'
    'Bahamas'
    %'Bahrain'
    %'Baikonur'
    %'Bajo Nuevo Bank (Petrel Islands)'
    'Bangladesh'
    'Barbados'
    %'Belarus'
    %'Belgium'
    'Belize'
    %'Benin'
    'Bermuda'
    %'Bhutan'
    'Bolivia'
    %'Bosnia and Herzegovina'
    %'Botswana'
    %'Brazil'
    %'British Indian Ocean Territory'
    'British Virgin Islands'
    %'Brunei'
    %'Bulgaria'
    %'Burkina Faso'
    %'Burundi'
    'Cambodia'
    %'Cameroon'
    %'Canada'
    %'Cape Verde'
    'Cayman Islands'
    %'Central African Republic'
    %'Chad'
    'Chile'
    'China'
    %'Clipperton Island'
    'Colombia'
    'Comoros'
    %'Congo'
    %'Cook Islands'
    %'Coral Sea Islands'
    'Costa Rica'
    %'Cote dIvoire'
    %'Croatia'
    'Cuba'
    'Curacao'
    %'Cyprus'
    %'Cyprus UN Buffer Zone'
    %'Czech Republic'
    %'Democratic Republic of the Congo'
    %'Denmark'
    %'Dhekelia'
    %'Djibouti'
    'Dominica'
    'Dominican Republic'
    'Ecuador'
    %'Egypt'
    'El Salvador'
    %'Equatorial Guinea'
    %'Eritrea'
    %'Estonia'
    %'Ethiopia'
    %'Faeroe Islands'
    %'Falkland Islands'
    'Fiji'
    %'Finland'
    %'France'
    %'French Polynesia'
    %'French Southern and Antarctic Lands '
    %'Gabon'
    %'Gambia'
    %'Georgia'
    %'Germany'
    %'Ghana'
    %'Gibraltar'
    %'Greece'
    %'Greenland'
    'Grenada'
    'Guam'
    'Guatemala'
    %'Guernsey'
    %'Guinea'
    %'Guinea-Bissau'
    'Guyana'
    'Haiti'
    %'Heard Island and McDonald Islands '
    'Honduras'
    'Hong Kong'
    %'Hungary'
    %'Iceland'
    'India'
    'Indian Ocean Territory'
    'Indonesia'
    %'Iran'
    %'Iraq'
    %'Ireland'
    %'Isle of Man'
    %'Israel'
    %'Italy'
    'Jamaica'
    'Japan'
    %'Jersey'
    %'Jordan'
    %'Kazakhstan'
    %'Kenya'
    'Kiribati'
    'Korea'
    %'Kosovo'
    %'Kuwait'
    %'Kyrgyzstan'
    'Laos'
    %'Latvia'
    %'Lebanon'
    %'Lesotho'
    %'Liberia'
    %'Libya'
    %'Liechtenstein'
    %'Lithuania'
    %'Luxembourg'
    'Macao'
    %'Macedonia'
    'Madagascar'
    %'Malawi'
    'Malaysia'
    'Maldives'
    %'Mali'
    %'Malta'
    'Marshall Islands'
    'Mauritania'
    'Mauritius'
    'Mexico'
    'Micronesia'
    %'Moldova'
    %'Monaco'
    %'Mongolia'
    'Montenegro'
    'Montserrat'
    %'Morocco'
    'Mozambique'
    'Myanmar'
    %'Namibia'
    'Nauru'
    %'Nepal'
    %'Netherlands'
    'New Caledonia'
    'New Zealand'
    'Nicaragua'
    %'Niger'
    %'Nigeria'
    %'Niue'
    %'Norfolk Island'
    %'North Cyprus'
    %'North Korea'
    'Northern Mariana Islands'
    %'Norway'
    %'Oman'
    %'Pakistan'
    'Palau'
    %'Palestine'
    'Panama'
    'Papua New Guinea'
    'Paraguay'
    'Peru'
    'Philippines'
    'Pitcairn Islands'
    %'Poland'
    %'Portugal'
    'Puerto Rico'
    %'Qatar'
    %'Romania'
    %'Russia'
    %'Rwanda'
    'Saint Helena'
    'Saint Kitts and Nevis'
    'Saint Lucia'
    'Saint Martin'
    'Saint Pierre and Miquelon'
    'Saint Vincent and the Grenadines'
    'Samoa'
    %'San Marino'
    'Sao Tome and Principe'
    %'Saudi Arabia'
    %'Scarborough Reef'
    %'Senegal'
    %'Serbia'
    %'Serranilla Bank'
    'Seychelles'
    %'Siachen Glacier'
    %'Sierra Leone'
    'Singapore'
    'Sint Maarten'
    %'Slovakia'
    %'Slovenia'
    'Solomon Islands'
    %'Somalia'
    %'Somaliland'
    %'South Africa'
    'South Georgia and South Sandwich Islands'
    %'South Sudan'
    %'Spain'
    'Spratly Islands'
    'Sri Lanka'
    'St-Barthelemy'
    %'Sudan'
    'Suriname'
    %'Swaziland'
    %'Sweden'
    %'Switzerland'
    %'Syria'
    'Taiwan'
    %'Tajikistan'
    %'Tanzania'
    'Thailand'
    %'Timor-Leste'
    %'Togo'
    'Tonga'
    'Trinidad and Tobago'
    %'Tunisia'
    %'Turkey'
    %'Turkmenistan'
    'Turks and Caicos Islands'
    'Tuvalu'
    'US Minor Outlying Islands'
    'US Virgin Islands'
    %'USNB Guantanamo Bay'
    %'Uganda'
    %'Ukraine'
    'United Arab Emirates'
    'United Kingdom'
    'United States'
    'Uruguay'
    %'Uzbekistan'
    'Vanuatu'
    %'Vatican'
    'Venezuela'
    'Vietnam'
    %'Wallis and Futuna Islands'
    %'Western Sahara'
    %'Yemen'
    %'Zambia'
    %'Zimbabwe'
    };
%
% TEST list (only a few)
% ----
country_list={
    'Barbados'
    'Puerto Rico'
    };
%
% more technical parameters
climada_global.waitbar=0; % switch waitbar off


% check names
if check_country_names
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        fprintf('%s: %s %s\n',country_list{country_i},country_name,country_ISO3);
    end % country_i
    climada_plot_world_borders(1,country_list) % plot and show selected in yellow
    fprintf('STOP after check country names, now set check_country_names=0\n')
    return
end

% generate entites only
% this allows to re-check entities (e.g for proper GDP before next steps)
if generate_entities
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        country_name_char = char(country_name); % as to create filenames etc., needs to be char
        
        % define easy to read filenames
        centroids_file     = [climada_global.data_dir filesep 'system'   filesep country_ISO3 '_' strrep(country_name_char,' ','') '_centroids.mat'];
        entity_file        = [climada_global.data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
        entity_future_file = [climada_global.data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity_future.mat'];
        
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
    
    if USA_UnitedStates_entity_treatment
        % special treatent for USA (restrict to contiguous US)
        fprintf('USA UnitedStates, restricting to contiguous US\n');
        centroids_file    =[climada_global.data_dir filesep 'system'   filesep 'USA_UnitedStates_centroids.mat'];
        entity_file       =[climada_global.data_dir filesep 'entities' filesep 'USA_UnitedStates_entity.mat'];
        entity_future_file=[climada_global.data_dir filesep 'entities' filesep 'USA_UnitedStates_entity_future.mat'];
        
        for entity_i=1:2
            if entity_i==2,entity_file=entity_future_file;end % ugly but pragmatic
            load(entity_file) % contains entity
            pos=find(entity.assets.lon>-130 & entity.assets.lat<50);
            entity.assets.centroid_index=entity.assets.centroid_index(pos);
            entity.assets.lon=entity.assets.lon(pos);
            entity.assets.lat=entity.assets.lat(pos);
            entity.assets.Value=entity.assets.Value(pos);
            if isfield(entity.assets,'Value_today'),entity.assets.Value_today=entity.assets.Value_today(pos);end
            if isfield(entity.assets,'distance2coast_km'),entity.assets.distance2coast_km=entity.assets.distance2coast_km(pos);end
            entity.assets.Deductible=entity.assets.Deductible(pos);
            entity.assets.Cover=entity.assets.Cover(pos);
            entity.assets.DamageFunID=entity.assets.DamageFunID(pos);
            save(entity_file,'entity') % write back
            climada_entity_value_GDP_adjust(entity_file); % assets based on GDP
        end % entity_i
        
        load(centroids_file) % contains centroids
        pos=find(centroids.lon>-130 & centroids.lat<50);
        centroids.lon=centroids.lon(pos);
        centroids.lat=centroids.lat(pos);
        centroids.centroid_ID=centroids.centroid_ID(pos);
        if isfield(centroids,'onLand'),centroids.onLand=centroids.onLand(pos);end
        if isfield(centroids,'distance2coast_km'),centroids.distance2coast_km=centroids.distance2coast_km(pos);end
        centroids=rmfield(centroids,'country_name');
        save(centroids_file,'centroids');
    end % USA_UnitedStates_entity_treatment
    
    if NZL_NewZealand_entity_treatment
        % special treatent for NZL (date line issue)
        fprintf('NZL_ NewZealand, resolving date line issue\n');
        centroids_file    =[climada_global.data_dir filesep 'system'   filesep 'NZL_NewZealand_centroids.mat'];
        entity_file       =[climada_global.data_dir filesep 'entities' filesep 'NZL_NewZealand_entity.mat'];
        entity_future_file=[climada_global.data_dir filesep 'entities' filesep 'NZL_NewZealand_entity_future.mat'];
        
        for entity_i=1:2
            if entity_i==2,entity_file=entity_future_file;end % ugly but pragmatic
            load(entity_file) % contains entity
            pos=find(entity.assets.lon>150);
            entity.assets.centroid_index=entity.assets.centroid_index(pos);
            entity.assets.lon=entity.assets.lon(pos);
            entity.assets.lat=entity.assets.lat(pos);
            entity.assets.Value=entity.assets.Value(pos);
            if isfield(entity.assets,'Value_today'),entity.assets.Value_today=entity.assets.Value_today(pos);end
            if isfield(entity.assets,'distance2coast_km'),entity.assets.distance2coast_km=entity.assets.distance2coast_km(pos);end
            entity.assets.Deductible=entity.assets.Deductible(pos);
            entity.assets.Cover=entity.assets.Cover(pos);
            entity.assets.DamageFunID=entity.assets.DamageFunID(pos);
            save(entity_file,'entity') % write back
            climada_entity_value_GDP_adjust(entity_file); % assets based on GDP
        end % entity_i
        
        load(centroids_file) % contains centroids
        pos=find(centroids.lon>150);
        centroids.lon=centroids.lon(pos);
        centroids.lat=centroids.lat(pos);
        centroids.centroid_ID=centroids.centroid_ID(pos);
        if isfield(centroids,'onLand'),centroids.onLand=centroids.onLand(pos);end
        if isfield(centroids,'distance2coast_km'),centroids.distance2coast_km=centroids.distance2coast_km(pos);end
        centroids=rmfield(centroids,'country_name');
        save(centroids_file,'centroids');
    end % NZL_NewZealand_entity_treatment
    fprintf('STOP after generate entities, now set generate_entities=0\n')
    return
end % generate_entities

% calculate damage on admin0 (country) level
country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0);

% next line allows to combine sub-perils, such as wind (TC) and surge (TS)
% EDC is the maximally combined EDS, i.e. only one fully combined EDS per
% hazard and region, i.e. one EDS for all TC Atlantic damages summed up
% (per event), one for TC Pacific etc.
[country_risk,EDC]=country_risk_EDS_combine(country_risk); % combine TC and TS and calculate EDC

% next few lines would allow results by state/province (e.g. for US states)
if calculate_admin1
    % calculate damage on admin1 (state/province) level
    probabilistic=0;if country_risk_calc_method<0,probabilistic=1;end
    country_risk1=country_admin1_risk_calc(country_list,probabilistic,0);
    country_risk1=country_risk_EDS_combine(country_risk1); % combine TC and TS
end

% next line allows to calculate annual aggregate where appropriate
%country_risk=country_risk_EDS2YDS(country_risk);

% next line to compare with EM-DAT, needs still a bit of work to compare
% country_risk structure with EM-DAT data
%climada_EDS_emdat_adjust

if generate_damage_report
    if calculate_admin1
        country_risk_report([country_risk country_risk1],1,damage_report_filename);
    else
        country_risk_report(country_risk,1,damage_report_filename);
    end
end
