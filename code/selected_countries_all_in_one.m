% selected_countries_all_in_one
% climada template
% MODULE:
%   module name
% NAME:
%   selected_countries_all_in_one, run all project countries, all calculations
% PURPOSE:
%   Run all climada for project
% CALLING SEQUENCE:
%   selected_countries_all_in_one
% EXAMPLE:
%   selected_countries_all_in_one
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150105
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
report_filename=[climada_global.data_dir filesep 'results' filesep 'selected_countries_all_in_one_report.xls'];
%
% swithes to run only parts of the code:
% --------------------------------------
%
% to check for climada-conformity of country names
check_country_names=0; % default=0
%
% parameters for country_risk_calc
country_risk_calc_method=-3; % default=-3, using GDP_entity and probabilistic sets, see country_risk_calc
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
country_list={
    'Dominican Republic'
    'Singapore'
    'Taiwan'
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
    return
end

% all on admin0 (country) level
country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0);

% all on admin1 (state/province) level
probabilistic=0;if country_risk_calc_method<0,probabilistic=1;end
country_risk1=country_admin1_risk_calc(country_list,probabilistic,0);

% generate report
country_risk_report([country_risk country_risk1],1,report_filename);
