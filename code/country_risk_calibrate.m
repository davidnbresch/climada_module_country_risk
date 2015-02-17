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
%   existing values might lead to troubles on subsequent calls. the code
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
% David N. Bresch, david.bresch@gmail.com, 20150217, Philippines and Taiwan re-adjusted
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
    
    case {'Anguilla' % TC atl
            'Antigua and Barbuda'
            'Aruba'
            'Bahamas'
            'Barbados'
            'Belize'
            'Bermuda'
            'British Virgin Islands'
            'Cayman Islands'
            %'Colombia' - see special case below
            'Costa Rica'
            'Cuba'
            'Dominica'
            %'Dominican Republic' - see special case below
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
            %'United States' - see special case below
            'Venezuela'
            }
        
        % Panama ok, EM-DAT would indicate higher (but return period with 2 damages?)
        % Mexico also very good (at high RP good match with EM-DAT), steep
        %   increase >200yr, hence 250yr climada damage too high, but 100 yr fine
        % Costa Rica: unchanged, looks pretty steep, but range of EM-DAT indicates
        %   that we're too cheap for say 20yr, but might be about ok for 100+ years)
        % annual aggregate full TC atl looks really good, almost too good a match with EM-DAT ;-)

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,15,1,1.0,'s-shape','TC',0);
        fprintf('%s TC atl: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'United States'} % TC/TS atl
        
        % USA looks good, good match EM-DAT

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,0.75,'s-shape','TS',0);
        fprintf('%s TS atl: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,25,1,0.4,'s-shape','TC',0);
        fprintf('%s TC atl: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Dominican Republic','Colombia'} % TC/TS atl
        
        % Dominican Republic: climada TC originally too high, adjusted to get close to
        %   EM-DAT, climada TS far too high adjusted down to get close to EM-DAT
        % Colombia looked like Dominican Republic, hence same adjustment, now good fit with EM-DAT

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,20,1,0.45,'s-shape','TC',0);
        fprintf('%s TC atl: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,1,'s-shape','TS',0);
        fprintf('%s TS atl: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Cambodia' % TC wpa
            %'China' - see special case below
            'Hong Kong'
            %'Indonesia' - moved to she, since it stretches further South than North
            %'Japan' - see special case below
            %'Korea' - see special case below
            'Laos'
            'Malaysia'
            'Micronesia'
            %'Philippines' - see special case below
            'Singapore'
            %'Taiwan' - see special case below
            'Thailand'
            'Vietnam'
            }
        
        % Vietnam looks ok, good match with EM-DAT
        % Thailand ok, might be too low, good match with EM-DAT unindexed, kept for the time being
        % Singapore not adjusted (no EM-DAT)
        % Laos no further adjustment, only 2 EM-DAT points, range of >200yr
        %   damge to be in the range of max(EM-DAT)
        % Indonesia no adjustment, no EM-DAT

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,15,1,1.0,'s-shape','TC',0);
        fprintf('%s TC wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'China'} % TC/TS
        
        % China: TC tuned to upper bound of EM-DAT (12% CAGR, in China, the asset base grew more than GDP)

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,30,3,0.6,'exp','TC',0);
        fprintf('%s TC wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,0.6,'s-shape','TS',0);
        fprintf('%s TS wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Japan'} % TC/TS
        
         % Japan TS adjusted to be in EM-DAT range (upper bound at 5% CAGR, only one point)
         %  TC also adjusted, but shape not really nice. 
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,45,4,0.5,'exp','TC',0);
        fprintf('%s TC wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0.5,1,0.6,'s-shape','TS',0);
        fprintf('%s TS wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Philippines'} % TC/TS
        
        % Philippines adjusted to match EM-DAT

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,33,3,0.75,'exp','TC',0);
        fprintf('%s TC wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,0.75,'s-shape','TS',0);
        fprintf('%s TS wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Taiwan'} % TC/TS
        
        % Taiwan was completly off. EM-DAT looks very low, except for
        %   largest damage - in the far past, hence inflation might
        %   overcompensate. Thus adjusted to match EM-DAT in between

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,35,3,0.6,'exp','TC',0);
        fprintf('%s TC wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,0.75,'s-shape','TS',0);
        fprintf('%s TS wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Korea'} % TC
        
        % Korea adjusted to be close to EM-DAT

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,35,2,0.5,'s-shape','TC',0);
        fprintf('%s TC wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Bangladesh' % TC nio
            'India'
            'Pakistan'
            'Myanmar' % moved from wpa
            }
        
        % Pakistan: climada very low, but left as is (TC not a big threat there)
        % India: climada for high RP much lower than EM-DAT, but loos like reasonable an extrap for <100yr, thus left as is
        % Bangladesh: climada much lower than EM-DAT, left as is for the time being
        %   annual aggregate combined looks reasonable, a bit ower than EM-DAT
        % Myanmar hard to compare, not adjusted either
        % TC nio basin aggregate low for high RP, but looks reasonable an extrap for <100yr
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,15,2,1.0,'s-shape','TC',0); % 15 to 20
        fprintf('%s TC nio: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Australia'} % TS she
        
        % Australia TS matches well, TS massively adjusted (was far too high)
        %   combined ow matchinf EM-DAT (upper end)

        % TS, an example of an explicit function
        damagefunctions.Intensity=[0 0.5 1 1.5 2 2.5 3 3.5 4 4.5 5 5.5 6 6.5 7 7.5 8 10 16]';
        damagefunctions.MDD=[0 0.002 0.004 0.01 0.02 0.04 0.06 0.08 0.1 0.12 0.13 0.135 0.14 0.142 0.144 0.145 0.145 0.145 0.145]';
        damagefunctions.PAA=[0 0.3935 0.6321 0.7769 0.8647 0.9179 0.9502 0.9698 0.9817 0.9889 0.9933 0.9959 0.9975 0.9985 0.9991 0.9994 0.9997 1 1]';
        damagefunctions.DamageFunID=damagefunctions.Intensity*0+1;
        damagefunctions.peril_ID=cellstr(repmat('TS',length(damagefunctions.Intensity),1));
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'New Zealand'} % TS she
        
        % New Zealand not much TC/TS exposed, no EM-DAT, just a generic curve
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,15,1,1,'s-shape','TC',0);
        fprintf('%s TC she: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,1,'s-shape','TS',0);
        fprintf('%s TS wpa: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
    case {'Indonesia'} % TC/TS she
        
        % Indonesia TC and TS manually adjusted (no EM-DAT) to be correct order of magnitude

        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:16,0,1,1,'s-shape','TS',0);
        fprintf('%s TS she: %s\n',country_name_char,dmf_info_str);
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        if ~isempty(entity_future),entity_future=climada_damagefunctions_replace(entity_future,damagefunctions);end
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(0:5:120,30,1,1,'s-shape','TC',0);
        fprintf('%s TC she: %s\n',country_name_char,dmf_info_str);
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