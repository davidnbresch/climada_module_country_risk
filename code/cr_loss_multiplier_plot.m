function country_ec_damage = cr_loss_multiplier_plot(country_names,economic_data_file)
% plot the loss multiplier
% MODULE:
% country_risk
% climada template
% NAME:
%   cr_loss_multiplier_plot
% PURPOSE:
%   Plot the loss multiplier which is defined by:
%   loss_multiplier = 1+cr_get_damage_weight(damage/GDP) * country_damage_factor; 
%   see documentation climada_module_country_risk.docx for details on the 
%   calculation of the loss multiplier)
% CALLING SEQUENCE:
%   country_ec_damage = cr_loss_multiplier_plot(country_names,economic_data_file)
% EXAMPLE:
%   country_ec_damage = cr_loss_multiplier_plot({'El Salvador','Austria'})
% INPUT:
%   country_names: name of the country, like 'Switzerland', or a list of
%       countries, like {'Switzerland','Germany','France'}. See
%       climada_check_country_name for the list of valid country names
% OPTIONAL INPUT PARAMETERS:
%   economic_data_file: the filename of the excel file with the raw data
%   (country-specific economic and resilience data used to calculate the
%   economic loss)
%   if empty, the code tries a default name, if it does not exist, it
%   prompts the user to locate the file
% OUTPUTS
%   a plot showing how the loss multiplier depends on damage per GDP
%   country_damage_factors: A struct wih the following fields:
%       country_ec_damage.Country           country name
%       country_ec_damage.ISO3              ISO3 code 
%       country_ec_damage.damage_factor     country damage factor
%       country_ec_damage.financial_strength financial strength
%       country_ec_damage.BI_risk           BI_and_supply_chain_risk
%       country_ec_damage.ec_exposure       natural_hazard_economic_exposure
%       country_ec_damage.resilience        disaster_resilience
% MODIFICATION HISTORY:
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150109, initial
%-

% initialize output
country_ec_damage = []; 

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%% check arguments 
if ~exist('country_names','var'), country_names = '';end
if ~exist('economic_data_file','var'),economic_data_file='';end

%% PARAMETERS
% Data directories
climada_global_data_dir = climada_global.data_dir; % default
country_risk_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data']; 
% create folders if they do not exist yet
if ~exist(climada_global_data_dir,'dir'),mkdir(fileparts(climada_global_data_dir),'data');end
if ~exist(country_risk_data_dir,'dir'),mkdir(fileparts(country_risk_data_dir),'data');end
%
% For the income group, we assume that the relationship between loss and
% GNI per capita (based on which a country's income group is defined) is an
% inverted U shape (highest losses for middle income countries, smaller
% losses for low and high income countries)
% see e.g. Okuyama, Yasuhide. Economic Impacts of Natural Disasters:
% Development Issues and Applications
% http://nexus-idrim.net/idrim09/Kyoto/Okuyama.pdf
% income group factors for income groups 1-4, as well as missing data (5)
income_group_factor(1) = 0.9;
income_group_factor(2) = 0.4;
income_group_factor(3) = 0.5;
income_group_factor(4) = 1;
income_group_factor(5) = 0.4;   % default value for NaN entries
%
% insurance penetration factors
insurance_penetration_factor(1) = 0;    % insurance penetration <5%
insurance_penetration_factor(2) = 0.5;  % insurance penetration between 5% and 10%
insurance_penetration_factor(3) = 1;    % insurance penetration >10%
insurance_penetration_factor(4) = 0;    % default value for NaN entries
%
misdat_value = -999; %indicates missing data 

%% prompt for country (one or multiple) as list dialog
if isempty(country_names) 
    country_names = climada_country_name('Multiple');
end
if isempty(country_names)
    fprintf('Error: No country selected.\n')
    return; 
end % Cancel pressed

if ~iscell(country_names),country_names={country_names};end % check that country_name is a cell

%% set default value for economic_data_file if not given and prompt for it
% if the default file does not exist
economic_data_file_default=[country_risk_data_dir filesep 'economic_indicators_mastertable.xls'];
if isempty(economic_data_file),economic_data_file=economic_data_file_default;end

if ~exist(economic_data_file,'file')
    [filename, pathname] = uigetfile(economic_data_file_default,...
        'Choose the database containing the economic indicators:');
    if isequal(filename,0) || isequal(pathname,0)
        fprintf('No database selected, consider downloading the country_risk module again\n');
        fprintf('See <a href="https://github.com/davidnbresch/climada_module_country_risk">climada_module_country_risk</a>\n')
        return; % cancel
    else
        economic_data_file=fullfile(pathname,filename);
    end
end

if ~exist(economic_data_file,'file'),fprintf('ERROR: file %s not found\n',economic_data_file);return;end

[~,economic_datafile_name,ext] = fileparts(economic_data_file);

%% read excel sheet with the (socio-)economic data needed in the calculation
master_data = climada_xlsread('no',economic_data_file,[],1,misdat_value);

% some parameters need to be converted into another unit
master_data.income_group(master_data.income_group==1)       = income_group_factor(1);
master_data.income_group(master_data.income_group==2)       = income_group_factor(2);
master_data.income_group(master_data.income_group==3)       = income_group_factor(3);
master_data.income_group(master_data.income_group==4)       = income_group_factor(4);
master_data.income_group(isnan(master_data.income_group))   = income_group_factor(5);

master_data.insurance_penetration(master_data.insurance_penetration <=5) = ...
    insurance_penetration_factor(1); 
master_data.insurance_penetration(master_data.insurance_penetration >5 & master_data.insurance_penetration <=10) = ...
    insurance_penetration_factor(2); 
master_data.insurance_penetration(master_data.insurance_penetration >10) = ...
    insurance_penetration_factor(3); 
master_data.insurance_penetration(isnan(master_data.insurance_penetration)) = ...
    insurance_penetration_factor(4); 


%% Calculate and plot
% Calculate country_damage_factor for each country, given that the country
% name is valid (i.e., that it matches an entry in the Climada reference 
% country list) and its economic data are available
% Plot loss_multiplier vs. damage_per_GDP
% 
n_countries=length(country_names);
colors = colormap(hsv(n_countries+3));
damage_per_GDP = 0:0.001:1;
nan_indices = [];
nan_counter = 1;
max_multiplier = [];
for country_i=1:n_countries
    country_name_char = char(country_names(country_i));
    [country_name_char_checked,country_ISO3] = climada_country_name(country_name_char); % check name and ISO3
    if isempty(country_name_char_checked)
        % Invalid country name - print warning message, but continue 
        % (there might be other 
        fprintf(['Warning: Cannot plot the loss multiplier of %s since %s',...
            'is an invalid country name.\n Please make sure that all',...
            'country names match the Climada reference names.\n', ...
            'Type \"climada_country_name\" to see a list of ', ...
            'all valid country names and their ISO3 codes. \n'], ...
            country_name_char,country_name_char,economic_datafile_name,ext);
        % fill output with NaN for that country
        country_ec_damage.Country(country_i)            = country_name_char;      
        country_ec_damage.ISO3(country_i)               = NaN;
        country_ec_damage.damage_factor(country_i)      = NaN;
        country_ec_damage.financial_strength(country_i) = NaN;
        country_ec_damage.BI_risk(country_i)            = NaN;
        country_ec_damage.ec_exposure(country_i)        = NaN;     
        country_ec_damage.resilience(country_i)         = NaN;
        
        % keep track of NaN indices
        nan_indices(nan_counter) = country_i;
        nan_counter = nan_counter + 1;
    else
        % Valid country name
        fprintf('\nCountry name check successful.\n\tCountry: %s\n\tISO3 Code: %s\n', ...
            country_name_char_checked, country_ISO3);
        country_index = find(strcmp(master_data.Country,country_name_char));
        % Compute economic_damage_factor: calculate financial_strength, 
        % BI_and_supply_chain_risk, natural_hazard_economic_exposure, and 
        % disaster_resilience based on the data in master_data
        financial_strength = ...
            min(master_data.total_reserves(country_index)/master_data.GDP_today(country_index),1) ...% setting an upper bound of 1
            + master_data.insurance_penetration(country_index) ...
            + master_data.income_group(country_index) ...
            - master_data.central_government_debt(country_index);
        % make sure 1/financial_strength (i.e. the term that goes into the
        % calculation of the country damage factor) does not exceed 2
        if financial_strength < 0.5, financial_strength =0.5;end
        if isnan(financial_strength)
            fprintf(['Error: Missing data - could not calculate financial_strength ',...
                'of %s.\n',country_name_char]);
            fprintf(['Please make sure %s.%s contains data on GDP, total reserves, ',...
                'insurance penetration, income group and central government ',...
                'of %s.\n'],economic_datafile_name,ext,country_name_char);
        else
            fprintf('Financial strength: %6.3f\n',financial_strength);
        end
        BI_and_supply_chain_risk = ...
            master_data.GDP_industry(country_index) ...
            + (1-master_data.FM_resilience_index_supply_chain(country_index)/100);
        if isnan(BI_and_supply_chain_risk)
            fprintf(['Error: Missing data - could not calculate BI_and_supply_chain_risk ',...
                'of %s.\n'],country_name_char);
            fprintf(['Please make sure %s.%s contains data on the share ',...  
                'of GDP generated by the industrial sector, as well as the supply ' ,...
                'chain factor of the FM Global Resilience Index of %s.\n'],...
                economic_datafile_name,ext,country_name_char);
        else
            fprintf('Business interruption and supply chain risk: %6.3f\n',...
                BI_and_supply_chain_risk);
        end
        natural_hazard_economic_exposure = ...
            1-master_data.Natural_Hazards_Economic_Exposure(country_index)/10;
        if isnan(natural_hazard_economic_exposure)
            fprintf(['Error: Missing data - could not calculate ',...
                'natural_hazard_economic_exposure of %s.\n'],country_name_char);
            fprintf(['Please make sure %s.%s contains data on the Natural ',...
                'Hazards Economic Exposure Index of %s.\n'],...
                economic_datafile_name,ext,country_name_char);
        else
            fprintf('Natural hazard economic exposure: %6.3f\n',natural_hazard_economic_exposure);
        end
        
        disaster_resilience = ...
            master_data.FM_resilience_index_risk_quality(country_index)/100 ...
            + (master_data.global_competitiveness_index(country_index)-1)/6;
        if isnan(disaster_resilience)
            fprintf(['Error: Missing data - could not calculate ',...
                'disaster_resilience of %s.\n'],country_name_char);
            fprintf(['Please make sure %s.%s contains data on the risk quality',...
                ' factor of the FM Global Resilience Index and the Global ',...
                ' Competitiveness Index of %s.\n'],...
                economic_datafile_name,ext,country_name_char);
        else
            fprintf('Disaster resilience: %6.3f\n',disaster_resilience);
        end
        
        country_damage_factor = 1/financial_strength ...
            + BI_and_supply_chain_risk ...
            + natural_hazard_economic_exposure ...
            - disaster_resilience;
        if country_damage_factor < 0, country_damage_factor = 0; end
        if isnan(country_damage_factor)
            fprintf(['Error: Could not calculate country_damage_factor ',...
                'of %s. due to missing data in %s.%s\n'],...
                country_name_char,economic_data_file,ext);
        end
        fprintf('Country damage factor: %6.3f\n',country_damage_factor);
        country_ec_damage.Country(country_i)            = {country_name_char_checked};      
        country_ec_damage.ISO3(country_i)               = {country_ISO3};
        country_ec_damage.damage_factor(country_i)      = country_damage_factor;
        country_ec_damage.financial_strength(country_i) = financial_strength;
        country_ec_damage.BI_risk(country_i)            = BI_and_supply_chain_risk;
        country_ec_damage.ec_exposure(country_i)        = natural_hazard_economic_exposure;     
        country_ec_damage.resilience(country_i)         = disaster_resilience;

        % Plot loss_multiplier
        counter=1;
        loss_multiplier = NaN(1,length(damage_per_GDP));
        for damage_ratio_i = 0:0.001:1
            loss_multiplier(counter) = ...
                1+cr_get_damage_weight(damage_ratio_i)*country_damage_factor;
            counter = counter+1;
        end
        plot(damage_per_GDP,loss_multiplier,'Color',colors(country_i,:),...
            'Linewidth',1.5);
        % determine maximum value for axis settings
        max_multiplier(country_i) = loss_multiplier(end);
        if country_i < n_countries
            hold on;
        else
            hold off;
        end
    end
end
title('Loss multiplier')
xlabel('damage per GDP');
ylabel('loss multiplier');
axis([0,1,0,ceil(max(max_multiplier))]);
countries_legend = country_ec_damage.Country;
if ~isempty(nan_indices),countries_legend{nan_indices}=[]; end
legend(countries_legend);

