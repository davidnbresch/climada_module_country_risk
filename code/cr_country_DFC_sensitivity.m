function cr_country_DFC_sensitivity(country_ISO3,show_plot,probabilistic,damagefunctions,peril_ID,peril_region)
% generate damagefunction sensitivity plots of all hazards affecting a 
% given country
% MODULE:
%   country_risk
% NAME:
%   cr_country_DFC_sensitivity
% PURPOSE:
%   For a given country (defined by its ISO3 code), generate 
%   "damagefunction sensitivity plots" (i.e., DFCs resulting from modifying 
%   an entity's original damagefunctions in different ways) of all 
%   available hazards and store them in a folder 
%   "damagefun_sensitivity_plots" in climada-master/data/results
%
%   see cr_damagefunction_sensitivity for more information on how the
%   damagefunctions are modified. The present code
%   cr_country_DFC_sensitivity is a mere caller to cr_damagefunction_sensitivity
%
%   For the generation of entities and hazards in one single function, see 
%   country_risk_calc (in the module country_risk), which creates hazard 
%   sets and an entity for a given country before it runs the risk 
%   calculations. For automatic comparison of a series of countries in one
%   hazard region, see selected_countries_region_peril
%   
% CALLING SEQUENCE:
%   cr_country_DFC_sensitivity(country_ISO3,show_plot,probabilistic,damagefunctions,peril_ID,peril_region)
% EXAMPLE:
%   cr_country_DFC_sensitivity('CHN', 1) % country: China, don't show plots
% INPUTS:
%   country_ISO3: ISO3 code of a country (see climada_country_name for
%   valid ISO3 codes)
% OPTIONAL INPUT PARAMETERS:
%   show_plot: only save the plots (=0; default), or show and save the 
%       plots (=1)
%   probabilistic: whether to use the probabilistic hazard sets (=1, default) 
%       or the historic ones (=0)
%   damagefunctions: a struct containing the damagefunctions (for one
%       single peril) to overwrite the entity's damagefunctions with. See
%       e.g. climada_damagefunctions_read. Replaces entity.damagefunctiuons 
%       without any further tests. The user is responsible for not messing
%       up, i.e. for entity.assets.DamageFunID to point to the right damage
%       function, damagefunctions.peril_ID to be consistent with e.g. input
%       parameter peril_ID etc.
%   peril_ID: 2-digit peril ID, like 'TC','TS','TR','WS','EQ',... 
%       If not provided, the peril for which the first damagefunction with
%       DamageFunID =1 exists is used.
%   peril_region: e.g. 'wpa' or 'atl', allows for selection of a
%       specific region. If not provided, no selection of peril region,
%       i.e. a country affected by tropical cyclones from two basins (such
%       as El Salvador with atl and epa) is treated twice.
% OUTPUTS:
%   plots of a set of DFCs (generated using different damagefunctions) for
%   all perils affecting the given country (or for one specific peril, if a
%   peril-specific damagefunctions struct is passed as input)
% NOTE 1:
%   TR hazard sets are currently not considered since there is no
%   damagefunctions implemented for that peril yet.
% NOTE 2:
%   In the current implementation, a peril_ID can only be selected
%   implicitly, i.e. by giving the function a peril-specific
%   damagefunctions struct. One might consider adding peril_ID also as a
%   separate input argument, such that a specific peril can be chosen
%   without having to pass a damagefunctions struct to the function
% NOTE 3:
%   This is a preliminary version that might need some clean-up /
%   optimization
%
% MODIFICATION HISTORY:
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150206, initial
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150209, added damagefunctions and peril_region
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150209, simplified to one peril (and one region)
%-


% initialize global variables
global climada_global
if ~climada_init_vars,return;end % init/import global variables

% check arguments and set default variables if necessary
if ~exist('country_ISO3','var')
    fprintf('error: missing input argument ''country_ISO3'',aborted\n');
    return;
end 
if ~exist('show_plot','var'), show_plot = 0;end
if ~exist('probabilistic','var'), probabilistic = 1;end
if ~exist('peril_region','var'), peril_region = '';end
if ~exist('damagefunctions','var'),damagefunctions = [];end
if ~exist('peril_ID','var'),peril_ID = '';end
if ~exist('peril_region','var'),peril_region = '';end


% PARAMETERS
%
% default data directory
data_dir = climada_global.data_dir; % default
%
% default directory containing the entities
entity_data_dir = [climada_global.data_dir filesep 'entities'];


% some preparations
probabilistic_str='_hist';if probabilistic,probabilistic_str='';end


% check whether data folder to store the resulting plots exists, and if not,
% create it
if ~exist([data_dir filesep 'results' filesep 'damagefun_plots'],...
        'dir'),mkdir([data_dir filesep 'results'],'damagefun_plots');
end

% find country name corresponding to ISO3 code
[country_name_char,~] = climada_country_name(country_ISO3); 
if isempty(country_name_char)
    fprintf('Error: Invalid ISO3 code, check climada_country_name.\n');
end

% figure the entity file and load it
entity_file = [entity_data_dir filesep country_ISO3 '_' ...
    strrep(country_name_char,' ','') '_entity.mat'];
if ~exist(entity_file,'file')
    fprintf('Error: Entity for %s not found.\n',country_name_char);
    return;
end
load(entity_file); % contains entity

% if damagefunctions have been given as an input, use them to replace the 
% entity's damagefunction 
if ~isempty(damagefunctions)
    entity = rmfield(entity,'damagefunctions');
    entity.damagefunctions = damagefunctions;
    if isempty(peril_ID),peril_ID=damagefunctions.peril_ID{1};end % set peril ID
end

if isempty(peril_ID),fprintf('peril_ID not defined, aborted\n'),return;end

%save('entity','entity') % NEVER, could be harmful

% figure the existing hazard set files for the given country
hazard_files=dir([data_dir filesep 'hazards' filesep ...
    country_ISO3 '_' strrep(country_name_char,' ','') '*' peril_region '_' peril_ID probabilistic_str '.mat']);

% if probabilistic == 1, hazard_files at this point contains the 
% probabilistic as well as the historic hazard file names, so we need to
% get rid of the latter ones
valid_hazard = 1:length(hazard_files);
for hazard_i = 1:length(hazard_files)
    if probabilistic && ~isempty(strfind(hazard_files(hazard_i).name,'_hist.mat'))
        valid_hazard(hazard_i)=0;
    end
end % hazard_i

valid_hazard = valid_hazard(valid_hazard>0);
hazard_files = hazard_files(valid_hazard);

% loop over all hazards (there are unlikely more than one, but we allow for)
for hazard_i = 1:length(hazard_files)
    full_hazard_file_i = [data_dir filesep 'hazards' filesep ...
        hazard_files(hazard_i).name];
    load(full_hazard_file_i);
    cr_damagefunction_sensitivity(entity,hazard,'',show_plot,peril_region);
end % hazard_i

end







