function country_risk=cr_country_hazard_test(country_risk,country_i,hazard_i,CAGR,show_plot)
% climada country risk calibrate test damage function
% MODULE:
%   module name
% NAME:
%   cr_country_hazard_test
% PURPOSE:
%   Given a country_risk results structure, experiment with one country and
%   hazard to test different damage function settings etc.
%
%   This code is MOST LIKELY to be edited by the user, i.e. to set
%   damagefunction parameters etc. It provides merely a TESTBED for
%   efficient calibration of country results.
%
%   Process:
%   - Run country_risk_calc for either one or a set of countries. A set makes
%     particularly sense for e.g. a peril region, such as TC atl, in order to
%     ensure (neighbouring) countries in that region have similar
%     damagefunction settings. Hence you might e.g. run
%     >> country_list={'Colombia','Costa Rica','Dominican Republic','United States'};
%     >> country_risk=country_risk_calc(country_list,-7,0,0,['atl_TC';'atl_TS']);
%   - call cr_DFC_plot to get a first overview by country, e.g.
%     >> cr_DFC_plot(country_risk)
%   - call cr_DFC_plot_aggregate to get a first overview or the combined
%     results of all countries, e.g.
%     >> cr_DFC_plot_aggregate(country_risk) % does combine EDSs himself
%     Note that especially the comparison with EM-DAT makes only sense for
%     either larger countries or a group of smaller ones - otherwise it
%     might be too much due to chance whether a country got hit in the past
%     years or not.
%   - Now, call cr_country_hazard_test to test different damagefunction
%     settings (or modifications) for one country and peril, e.g.
%     country_risk=cr_country_hazard_test(country_risk,2,1) % 'Costa Rica','TC'
%     and occasionally call cr_DFC_plot_aggregate(country_risk) to show the
%     aggregate result. Note that cr_DFC_plot_aggregate does the
%     aggregation itself.
%     In case you'd like to experiment only with TC, but want to compare TC
%     and TS combined, proceed as follows (say hazard 1 is TC, hazard 2 TS)
%     >> country_risk=cr_country_hazard_test(country_risk,2,1)
%     >> [country_risk_agg,EDC]=country_risk_EDS_combine(country_risk);
%     >> cr_DFC_plot(country_risk_agg,1,1)
%
%   How to use: make your copy of the present code (name it e.g.
%   cr_country_hazard_mytest) and experiment with different damage function
%   settings for a given country and region (group of countries). In
%   special cases, you might also consider adjusting hazard event sets.
%
%   Next step: put your final adjustments in country_risk_calibrate
% CALLING SEQUENCE:
%   country_risk=cr_country_hazard_test(country_risk,country_i,hazard_i,CAGR,show_plot)
% EXAMPLE:
%   country_risk=cr_country_hazard_test(country_risk,2,1) % 2nd country, 1st haazrd
% INPUTS:
%   country_risk: the output of country_risk_calc (NOT of
%       country_risk_EDS_combine, as this would result in empty EDSs for
%       e.g. TS).
%   country_i: the country index (as shown when first run) to only show one
%       country (usefule in the country damagefunction calibration process)
%       Default=1 (hence the user will usually specify)
%   hazard_i: the hazard index (as shown when first run) to only show one
%       hazard (usefule in the country damagefunction calibration process)
%       Default=1 (hence the user will usually specify)
% OPTIONAL INPUT PARAMETERS:
%   CAGR: the compound annual growth rate to inflate historic EM-DAT
%       damages with, if empty, the default value is used (climada_global.global_CAGR)
%   show_plot: =1 (default) show the plot, 0= just create and save the plot
%       =2: show not only the single DFC plot for the country, but also
%       call cr_DFC_plot_aggregate
%       If show_plot is negative, first delete all existing figures.
% OUTPUTS:
%   country_risk: the country_risk structure with the results for country_i
%       and hazard_i updated
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150213, initial
% David N. Bresch, david.bresch@gmail.com, 20150906, no change, as the user anyway needs to edit lines....
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_risk','var'),return;end
if ~exist('country_i','var'),country_i=1;end
if ~exist('hazard_i','var'),hazard_i=1;end
if ~exist('CAGR','var'),CAGR=[];end
if ~exist('show_plot','var'),show_plot=1;end

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

if show_plot<0,close all;show_plot=abs(show_plot);end

% PARAMETERS
%
if isempty(CAGR),CAGR=climada_global.global_CAGR;end % default CAGR

entity_future=[]; % not used, just to allow code clocks to be copied from country_risk_calibrate
dmf_info_str='';

% load entity and hazard
load(country_risk(country_i).res.hazard(hazard_i).entity_file); % entity
load(country_risk(country_i).res.hazard(hazard_i).hazard_set_file); % hazard

country_name_char=country_risk(country_i).res.country_name;

% *********************************************************
% ****** edit the damage function below *******************

% you can usually copy/paste such a code block once ok to country_risk_calibrate

%if strcmp(country_risk(country_i).res.hazard(hazard_i).peril_ID,'TS')

% New Zealand
% [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,15,1,1,'s-shape','TC',0);
% fprintf('%s TC she: %s\n',country_name_char,dmf_info_str);
% entity=climada_damagefunctions_replace(entity,damagefunctions);
% if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
% [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,1,'s-shape','TS',0);
% fprintf('%s TS wpa: %s\n',country_name_char,dmf_info_str);
% entity=climada_damagefunctions_replace(entity,damagefunctions);
% if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end

% New Zealand not much TC/TS exposed, no EM-DAT, just a generic curve
% [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,15,1,1,'s-shape','TC',0);
% fprintf('%s TC she: %s\n',country_name_char,dmf_info_str);
% entity=climada_damagefunctions_replace(entity,damagefunctions);
% if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
% [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,1,'s-shape','TS',0);
% fprintf('%s TS wpa: %s\n',country_name_char,dmf_info_str);
% entity=climada_damagefunctions_replace(entity,damagefunctions);
% if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end

% EQ USA
%[damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,0.75,'s-shape','EQ',1);
[damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:13,3,1,1,'s-shape','EQ',1);
fprintf('%s EQ glb: %s\n',country_name_char,dmf_info_str);
entity=climada_damagefunctions_replace(entity,damagefunctions);
if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end

%climada_damagefunctions_plot(entity) % plot damagefunctions

%end

% ****** end edit the damage function  ********************
% *********************************************************

% re-calculate the damages
country_risk(country_i).res.hazard(hazard_i).EDS=climada_EDS_calc(entity,hazard);
%country_risk(country_i).res.hazard(hazard_i).EDS.ED

% plot the result
if show_plot,cr_DFC_plot(country_risk,country_i,hazard_i,CAGR,1);end
if show_plot==2,cr_DFC_plot_aggregate(country_risk,[],CAGR);end

end % cr_country_hazard_test