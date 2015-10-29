function country_risk_waterfall(country_name,annual_eco_growth)
% country_risk_waterfall(country_name,annual_eco_growth)
% MODULE:
%   country risk
% NAME:
%   country_risk_waterfall
% PURPOSE:
%   Produce waterfall graph for a specific country, using the precalculated
%   hazards (TC, TS, TC_cc_2050, TS_cc_2050) and entity (entity today)
% CALLING SEQUENCE:
%   country_risk_waterfall(country_name,annual_eco_growth)
% EXAMPLE:
%   country_risk_waterfall('Mexico',0.04)
%   country_risk_waterfall({'Mexico'; 'Aruba'},0.04)
%   country_risk_waterfall('ALL',0.04)
% INPUTS:
%   country_name: name of the country, like 'Switzerland', or a list of
%       countries, like {'Switzerland','Germany','France'}. See
%       climada_check_country_name for the list of valid country names
%       If set to 'ALL', the code runs recursively through ALL countries
%       (mind the time this will take...)
%       > prompted for via dropdown list if empty (allows for single or
%       multiple country selection)
% OPTIONAL INPUT PARAMETERS:
%   annual_eco_growth: annual economic growth, e.g. 0.04 for 4% growth for 
%       a developing country, and 0.01 for a developed country 
% OUTPUTS:
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20151029, initial
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name', 'var'), country_name = ''; end
if ~exist('annual_eco_growth', 'var'), annual_eco_growth = ''; end
if ~exist('peril_ID', 'var'), peril_ID = ''; end

% PARAMETERS
if isempty(annual_eco_growth), annual_eco_growth = 0.04; end
if isempty(peril_ID), peril_ID = {'TC' 'TS'}; end

% set parameters
return_period = 250;
climada_global.Value_unit = 'USD';
% climada_global.future_reference_year = 2050;
% timespan = 35;
timespan = climada_global.future_reference_year - climada_global.present_reference_year;

% set country_name
if isempty(country_name) % prompt for country (one or many) as list dialog
    country_name = climada_country_name('Multiple');
elseif strcmp(country_name,'ALL')
    country_name = climada_country_name('all');
end

if isempty(country_name), return; end % Cancel pressed

if ~iscell(country_name),country_name={country_name};end % check that country_name is a cell

if length(country_name)>1 % more than one country, process recursively
    n_countries=length(country_name);
    for country_i = 1:n_countries
        single_country_name = country_name(country_i);
        %fprintf('\nprocessing %s (%i of %i) ************************ \n',...
        %    char(single_country_name),country_i,n_countries);
        cr_waterfall(single_country_name, annual_eco_growth)
    end % country_i
    return
end

% from here on, only one country
country_name_char = char(country_name); % as to create filenames etc., needs to be char
[country_name_char_chk,country_ISO3] = climada_country_name(country_name_char); % check name and ISO3
if isempty(country_name_char_chk)
    country_ISO3='XXX';
    fprintf('Warning: Unorthodox country name, check results\n');
else
    country_name_char = country_name_char_chk;
end

if isempty(country_name_char),return;end % invalid country name


% find appropriate basin
basin = {'atl' 'epa' 'wpa' 'she' 'nio'};

% loop over perils
counter = 1;
for p_i = 1:numel(peril_ID)
    % loop over basins
    for b_i = 1:numel(basin)
        hazard_filename = [climada_global.data_dir filesep 'hazards' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_' basin{b_i} '_' peril_ID{p_i} '.mat'];
        hazard_filename_future = [climada_global.data_dir filesep 'hazards' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_' basin{b_i} '_' peril_ID{p_i} '_cc_2050.mat'];
        
        if exist(hazard_filename,'file')
            hazard_files{counter,1} = hazard_filename;
            if exist(hazard_filename_future,'file')
                hazard_files_future{counter,1} = hazard_filename_future;
            else
                fprintf('Climate change hazard does not exist, however today''s hazard exists.\n')
            end
            counter = counter+1;
        end
        
    end
end

% load entity file
entity_file = [climada_global.data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
entity = climada_entity_load(entity_file);

%create future entity 
entity_future = entity;
entity_future.assets.Value = entity.assets.Value*(1+annual_eco_growth)^timespan;

% calculate damage today and damage with economic development
% loop over hazard files, normally one for TC and one for TS
for h_i = 1:numel(hazard_files)
    clear hazard
    hazard = climada_hazard_load(hazard_files{h_i});
    EDS_temp = climada_EDS_calc(entity,hazard);
    EDS_temp_eco = climada_EDS_calc(entity_future,hazard);
    
    % combine the new EDS with the existing EDS
    if h_i >1
        EDS = climada_EDS_combine(EDS,EDS_temp);
        EDS_eco = climada_EDS_combine(EDS_eco,EDS_temp_eco);
    else
        EDS = EDS_temp;
        EDS_eco = EDS_temp_eco;
    end
end
% adjust EDS
EDS = cr_EDS_adjust(EDS);
EDS_eco = cr_EDS_adjust(EDS_eco);


% calculate damage based on eco. development and climate change
% loop over hazard files, normally one for TC and one for TS
for h_i = 1:numel(hazard_files_future)
    clear hazard
    hazard_cc = climada_hazard_load(hazard_files_future{h_i});
    EDS_temp_cc = climada_EDS_calc(entity_future,hazard_cc);
    
    % combine the new EDS with the existing EDS
    if h_i >1
        EDS_cc = climada_EDS_combine(EDS_cc,EDS_temp_cc);
    else
        EDS_cc = EDS_temp_cc;
    end
end
% adjust EDS
EDS_cc = cr_EDS_adjust(EDS_cc);


% create figures

% DFC, today, eco, cc
fig = climada_figuresize(0.4,0.6);
climada_EDS_DFC(EDS,EDS_eco); hold on
climada_EDS_DFC(EDS_cc)

% DFC, today split between perils
fig = climada_figuresize(0.4,0.6);
climada_EDS_DFC(EDS,EDS_temp); hold on
% climada_EDS_DFC(EDS_cc,EDS_temp_cc)


% waterfall graph
% climada_global.font_scale = 1;
fig2 = climada_waterfall_graph(EDS,EDS_eco,EDS_cc,return_period);
legend('off'); %legend(get(fig),'');
title(country_name_char,'fontsize',14)
figure_name = [climada_global.data_dir filesep 'results' filesep 'waterfall_' country_ISO3 '_' strrep(country_name_char,' ','') '_' int2str(return_period) 'year.pdf'];
print(fig2,figure_name,'-dpdf')


return



% countryname = 'MEX_Mexico';
% basin = 'epa';
% % countryname = 'AUS_Australia';
% % basin = 'she';
% factor_eco =.01;

%set directories and files
% hazard_file_TC = [climada_global.data_dir filesep 'hazards' filesep country_ISO3 '_' country_name_char '_' basin '_TC.mat'];
% hazard_file_TS = [climada_global.data_dir filesep 'hazards' filesep country_ISO3 '_' country_name_char '_' basin '_TS.mat'];
% hazard_file_TC_cc = [climada_global.data_dir filesep 'hazards' filesep country_ISO3 '_' country_name_char '_' basin '_TC_cc_2050.mat'];
% hazard_file_TS_cc = [climada_global.data_dir filesep 'hazards' filesep country_ISO3 '_' country_name_char '_' basin '_TS_cc_2050.mat'];


% DFC_1 = climada_EDS2DFC(EDS1,250)
% DFC = climada_EDS2DFC(EDS4,250)
% 
% cr_hazard_clim_scen('Mexico','',1)
% hazard = climada_hazard_load;
% 
% 
% % graph
% climada_global.font_scale=1;
% fig1 = climada_waterfall_graph(EDS1,EDS2,EDS3,return_period,-1);
% print(fig1,ISO_shortcut,'-dpng')


% EDS1 = climada_EDS_combine(EDS_TC,EDS_TS);
% hazard_TS = climada_hazard_load(hazard_file_TS);
% EDS_TC = climada_EDS_calc(entity,hazard_TC);
% EDS_TS = climada_EDS_calc(entity,hazard_TS);
% EDS1 = climada_EDS_combine(EDS_TC,EDS_TS);
% EDS1 = cr_EDS_adjust(EDS1);

% %EDS2 entity future no climate change hazard
% EDS_TC = climada_EDS_calc(entity_future,hazard_TC);
% EDS_TS = climada_EDS_calc(entity_future,hazard_TS);
% EDS2 = climada_EDS_combine(EDS_TC,EDS_TS);
% EDS2 = cr_EDS_adjust(EDS2);
% 
% %EDS3 entity future climate change
% hazard_TC = climada_hazard_load(hazard_file_TC_cc);
% hazard_TS = climada_hazard_load(hazard_file_TS_cc);
% 
% EDS_TC = climada_EDS_calc(entity_future,hazard_file_TC_cc);
% EDS_TS = climada_EDS_calc(entity_future,hazard_file_TC_cc);
% EDS3 = climada_EDS_combine(EDS_TC,EDS_TS);
% EDS3 = cr_EDS_adjust(EDS3);

% EDS_TC = climada_EDS_calc(entity,hazard_file_TC_cc);
% EDS_TS = climada_EDS_calc(entity,hazard_file_TC_cc);
% EDS4 = climada_EDS_combine(EDS_TC,EDS_TS);
% EDS4 = cr_EDS_adjust(EDS4);
% 
% figure;climada_EDS_DFC(EDS1,EDS4)
% 
% DFC_1 = climada_EDS2DFC(EDS1,250)
% DFC = climada_EDS2DFC(EDS4,250)
% 
% return
% cr_hazard_clim_scen('Mexico','',1)
% hazard = climada_hazard_load;
% 
% 
% % graph
% climada_global.font_scale=1;
% fig1 = climada_waterfall_graph(EDS1,EDS2,EDS3,return_period,-1);
% print(fig1,ISO_shortcut,'-dpng')
% 
% 
% %Hongkong
% ISO_shortcut='HKG';
% basin = 'wpa';
% factor_HKG=.01;
% 
% %EDS1
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\entities\HKG_HongKong_entity.mat')
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\HKG_HongKong_wpa_TC.mat')
% hazard_TC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\HKG_HongKong_wpa_TS.mat')
% hazard_TS=hazard;
% EDS_TC=climada_EDS_calc(entity,hazard_TC);
% EDS_TS=climada_EDS_calc(entity,hazard_TS);
% EDS1=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS1.ED=EDS1.ED*0.35;               %cr_EDS_adjust
% 
% %create future entities 
% entity_future=entity;
% entity_future.assets.Value=entity.assets.Value*(1+factor_HKG)^timespan;
% 
% %EDS2 entity future no climate change hazard
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS);
% EDS2=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS2.ED=EDS2.ED*0.35;               %cr_EDS_adjust
% 
% %EDS3 entity future climate change
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\HKG_HongKong_wpa_TC_cc_2050.mat')
% hazard_TC_CC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\HKG_HongKong_wpa_TS_cc_2050.mat')
% hazard_TS_CC=hazard;
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC_CC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS_CC);
% EDS3=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS3.ED=EDS3.ED*0.35;               %cr_EDS_adjust
% 
% %graph
% climada_global.font_scale=1;
% fig1 = climada_waterfall_graph(EDS1,EDS2,EDS3,return_period,-1);
% print(fig1,ISO_shortcut,'-dpng')
% 
% %% Dom Rep
% ISO_shortcut='DOM';
% factor_DOM=.05;
% 
% %EDS1
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\entities\DOM_DominicanRepublic_entity.mat')
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\DOM_DominicanRepublic_atl_TC.mat')
% hazard_TC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\DOM_DominicanRepublic_atl_TS.mat')
% hazard_TS=hazard;
% EDS_TC=climada_EDS_calc(entity,hazard_TC);
% EDS_TS=climada_EDS_calc(entity,hazard_TS);
% EDS1=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS1.ED=EDS1.ED*1;               %cr_EDS_adjust
% 
% %create future entities 
% entity_future=entity;
% entity_future.assets.Value=entity.assets.Value*(1+factor_DOM)^timespan;
% 
% %EDS entity future no climate change hazard
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS);
% EDS2=climada_EDS_combine(EDS_TC,EDS_TS);
% 
% %EDS entity future climate change
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\DOM_DominicanRepublic_atl_TC_cc_2050.mat')
% hazard_TC_CC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\DOM_DominicanRepublic_atl_TS_cc_2050.mat')
% hazard_TS_CC=hazard;
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC_CC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS_CC);
% EDS3=climada_EDS_combine(EDS_TC,EDS_TS);
% 
% %graph
% climada_global.font_scale=1;
% fig2 = climada_waterfall_graph(EDS1,EDS2,EDS3,return_period,-1);
% print(fig2,ISO_shortcut,'-dpng')
% 
% %% New Zealand
% ISO_shortcut='NZL';
% factor_DOM=.02;
% 
% %EDS1
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\entities\NZL_NewZealand_entity.mat')
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\NZL_NewZealand_she_TC.mat')
% hazard_TC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\NZL_NewZealand_she_TS.mat')
% hazard_TS=hazard;
% EDS_TC=climada_EDS_calc(entity,hazard_TC);
% EDS_TS=climada_EDS_calc(entity,hazard_TS);
% EDS1=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS1.ED=EDS1.ED*1;               %cr_EDS_adjust
% 
% %create future entities 
% entity_future=entity;
% entity_future.assets.Value=entity.assets.Value*(1+factor_DOM)^timespan;
% 
% %EDS entity future no climate change hazard
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS);
% EDS2=climada_EDS_combine(EDS_TC,EDS_TS);
% 
% %EDS entity future climate change
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\NZL_NewZealand_she_TC_cc_2050.mat')
% hazard_TC_CC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\NZL_NewZealand_she_TS_cc_2050.mat')
% hazard_TS_CC=hazard;
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC_CC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS_CC);
% EDS3=climada_EDS_combine(EDS_TC,EDS_TS);
% 
% %graph
% climada_global.font_scale=1;
% fig3 = climada_waterfall_graph(EDS1,EDS2,EDS3,return_period,-1);
% print(fig3,ISO_shortcut,'-dpng') %,[climada_global.data_dir results])
% 
% %% USA
% %Hongkong
% ISO_shortcut='USA';
% factor_HKG=.01;
% 
% %EDS1
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\entities\USA_UnitedStates_entity.mat')
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\USA_UnitedStates_atl_TC.mat')
% hazard_TC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\USA_UnitedStates_atl_TS.mat')
% hazard_TS=hazard;
% EDS_TC=climada_EDS_calc(entity,hazard_TC);
% EDS_TS=climada_EDS_calc(entity,hazard_TS);
% EDS1=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS1.ED=EDS1.ED*0.92561179483609;               %cr_EDS_adjust
% %create future entities 
% entity_future=entity;
% entity_future.assets.Value=entity.assets.Value*(1+factor_HKG)^timespan;
% 
% %EDS2 entity future no climate change hazard
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS);
% EDS2=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS2.ED=EDS2.ED*0.92561179483609;               %cr_EDS_adjust
% 
% %EDS3 entity future climate change
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\USA_UnitedStates_atl_TC_cc_2050.mat')
% hazard_TC_CC=hazard;
% load('N:\RM\sustainability\SandPcountry_risk\climada_data_SP\hazards\USA_UnitedStates_atl_TS_cc_2050.mat')
% hazard_TS_CC=hazard;
% EDS_TC=climada_EDS_calc(entity_future,hazard_TC_CC);
% EDS_TS=climada_EDS_calc(entity_future,hazard_TS_CC);
% EDS3=climada_EDS_combine(EDS_TC,EDS_TS);
% EDS3.ED=EDS3.ED*0.92561179483609;               %cr_EDS_adjust
% 
% %graph
% climada_global.font_scale=1;
% fig4 = climada_waterfall_graph(EDS1,EDS2,EDS3,return_period,-1);
% print(fig4,ISO_shortcut,'-dpng')