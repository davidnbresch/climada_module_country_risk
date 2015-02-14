function ok=country_risk_calibrate(country_name)
% climada template
% MODULE:
%   module name
% NAME:
%   country_risk_calibrate
% PURPOSE:
%   Calibrate a given country (or a list of countries)
%   Call country_risk_calc before
%
%   Standard procedure is that the switch statement below has entries for
%   countries (and lists of countries) and hence performs the specific
%   actions. Be careful to check for repetitious application. We set the
%   field entity.calibrated=1 the first time it is treated here, but since
%   one might need to re-calibrate, one should rather assign absolute
%   values to e.g. damagefunctions.MDD, since a mere multiplication of
%   existing values might lead to troubles on subseqent calls. the code
%   climada_damagefunctions_replace does indeed not replace on repetitious
%   calls if the result would be exactly the same.
%
%   See also cr_country_hazard_test in order to test country calibration
%
% CALLING SEQUENCE:
%   ok=country_risk_calibrate(country_name)
% EXAMPLE:
%   ok=country_risk_calibrate('USA')
% INPUTS:
%   country_name: a single country name or a list of countries
%       > promted for if not given
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150214, initial
%-

ok=[]; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'),country_name = '';end

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
%module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%


if isempty(country_name) % prompt for country (one or many) as list dialog
    country_name = climada_country_name('Multiple');
elseif strcmp(country_name,'ALL')
    country_name = climada_country_name('all');
end

if isempty(country_name),return; end % Cancel pressed

if ~iscell(country_name),country_name={country_name};end % check that country_name is a cell

if length(country_name)>1 % more than one country, process recursively
    n_countries=length(country_name);
    ok=1;
    for country_i = 1:n_countries
        single_country_name = country_name(country_i);
        fprintf('\nprocessing %s (%i of %i) ************************ \n',...
            char(single_country_name),country_i,n_countries);
        ok_out=country_risk_calibrate(single_country_name);
        ok=ok*ok_out;
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
    country_name_char=country_name_char_chk;
end

entity_file        = [climada_global.data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
entity_future_file = [climada_global.data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity_future.mat'];

if exist(entity_future_file,'file')
    load(entity_future_file);entity_future=entity;
else
    entity_future=[];
end
if exist(entity_file,'file')
    load(entity_file); % contains entity
else
    fprintf('%s: entity not found, aborted (%s)\n',country_name_char,entity_file);
    return
end

switch country_name_char
    case {'Anguilla'
            'Antigua and Barbuda'
            'Aruba'
            'Bahamas'
            'Barbados'
            'Belize'
            'Bermuda'
            'British Virgin Islands'
            'Cayman Islands'
            'Colombia'
            'Costa Rica'
            'Cuba'
            'Dominica'
            'Dominican Republic'
            'El Salvador'
            'Grenada'
            'Guatemala'
            'Guyana'
            'Haiti'
            'Honduras'
            'Jamaica'
            'Mexico'
            'Nicaragua'
            'Panama'
            'Puerto Rico'
            'Saint Kitts and Nevis'
            'Saint Lucia'
            'Saint Martin' % NOT supported in climada_create_GDP_entity
            'Saint Pierre and Miquelon'
            'Saint Vincent and the Grenadines'
            'Sao Tome and Principe'
            'Trinidad and Tobago'
            'Turks and Caicos Islands'
            'US Virgin Islands'
            'United States'
            'Venezuela'
            }
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(1:5:120,20,1,0.9,'s-shape','TC',0);
        fprintf('%s TC: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Cambodia'
            'China'
            'Hong Kong'
            'Indonesia'
            'Japan'
            'Korea'
            'Laos'
            'Malaysia'
            'Micronesia'
            'Myanmar'
            'Philippines'
            'Singapore'
            'Taiwan'
            'Thailand'
            'Vietnam'
            };
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(1:5:120,15,1,1.0,'s-shape','TC',0);
        fprintf('%s TC: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    otherwise
        fprintf('No calibration available for %s, ignored\n',country_name_char);
        return
end

entity.calibrated=1; % indicate calibration has happened
fprintf('- saving %s\n',entity_file)
save(entity_file,'entity')
if ~isempty(entity_future)
    entity_future.calibrated=1; % indicate calibration has happened
    entity=entity_future;
    fprintf('- saving %s\n',entity_future_file)
    save(entity_future_file,'entity');
end
ok=1;

end % country_risk_calibrate