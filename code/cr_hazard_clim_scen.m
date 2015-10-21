function ok = cr_hazard_clim_scen(country_name,peril_ID,force_recalc)
% climada
% MODULE:
%   country_risk
% NAME:
%   cr_hazard_clim_scen
% PURPOSE:
%   create climate change hazards for 2050
%   load existing hazards and modify based on TC, TS and basin
%
%   to be called in selected_countries_all_in_one
% CALLING SEQUENCE:
%   country_risk =country_risk_calc(country_name,method,force_recalc,check_plots,peril_ID)
% EXAMPLE:
%   country_risk0=country_risk_calc('CHE',1,0); % 10x10km resolution for
% INPUTS:
%   country_name: name of the country, like 'Switzerland', or a list of
%       countries, like {'Switzerland','Germany','France'}. See
%       climada_check_country_name for the list of valid country names
%       If set to 'ALL', the code runs recursively through ALL countries
%       (mind the time this will take...)
%       > prompted for via dropdown list if empty (allows for single or
%       multiple country selection)
% OPTIONAL INPUT PARAMETERS:
%   peril_ID: 'TS' or 'TC', or both. If empty, all perils (TC and TS) will 
%       be modified
%   force_recalc: if set to 1 recalcs hazards even if they already exist,
%       default 0
% OUTPUTS:
%   creates climate change hazard files and saves them in the hazard
%   directory. Additionally creates a diary file to save output from
%   command window in the hazard directoy.
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20151020, initial
%-

country_risk = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'), country_name = '';end
if ~exist('peril_ID','var'), peril_ID = '';end
if ~exist('force_recalc','var'), force_recalc = 0;end

% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' creates so many
% files, one might divert to e.g. a data folder structure within the
% module
country_data_dir = climada_global.data_dir; % default

% some folder checks (to be on the safe side)
if ~exist(country_data_dir,'dir'),mkdir(fileparts(country_data_dir),'data');end
if ~exist([country_data_dir filesep 'hazards'],'dir'),mkdir(country_data_dir,'hazards');end

% set hazard directoy
hazard_dir = [country_data_dir filesep 'hazards'];
ok = 0; %init

diary_file = [hazard_dir filesep sprintf('Diary_create_climate_change_hazards_%s.csv',datestr(now,'YYYYmmdd'))];
diary(diary_file)

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
        ok = cr_hazard_clim_scen(single_country_name,peril_ID,force_recalc);
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

% create climate change hazards for 2050 for TC and TS
% load existing hazards and save as ..._cc_2050.mat
climate_change_str = '_cc_2050';
hazard_files = dir([hazard_dir filesep '*.mat']);

% set peril_ID
if isempty(peril_ID)
    peril_ID = {'TC' 'TS'};
end

% find ISO3 code
is_valid = ~cellfun('isempty', strfind({hazard_files.name},[country_ISO3 '_' strrep(country_name_char,' ','')]));
hazard_files = hazard_files(is_valid);

% filter out historical hazards
is_valid = cellfun('isempty', strfind({hazard_files.name},'_hist'));
hazard_files = hazard_files(is_valid);

% filter out hazards that are already climate change modified
is_valid = cellfun('isempty', strfind({hazard_files.name},climate_change_str));
hazard_files_all = hazard_files(is_valid);
    
if isempty(hazard_files)
    fprintf('No hazard for %s exist.\n',country_name_char)
    return
end

% ------
% - climate change scenario numbers for RCP8.5, 2050
% ------
basin = {'atl' 'wpa' 'she' 'nio'};

TC_frequency_screw = [5 4 1 1]/100 +1.;
TC_intensity_screw = [0 0 0 0 0]/100 +1.;

TS_frequency_screw = [0 0 0 0]/100 +1.;
TS_intensity_screw = [0 0 0 0]/100 +1.;
TS_intensity_shift = [0.4 0.35 0.3 0.25]; % sea level rise in m until 2050, RCP 8.5


% loop over perils
for p_i = 1:numel(peril_ID)
    is_valid = ~cellfun('isempty', strfind({hazard_files_all.name},peril_ID{p_i}));
    hazard_files_peril = hazard_files_all(is_valid);
    
    % loop over basins
    for b_i = 1:numel(basin)
        is_valid = ~cellfun('isempty', strfind({hazard_files_peril.name},basin{b_i}));
        hazard_files = hazard_files_peril(is_valid);
        
        if ~isempty(hazard_files)
            if ischar(hazard_files.name)

                % set climate change filename
                hazard_save_file = strrep(hazard_files.name,peril_ID{p_i},[peril_ID{p_i} climate_change_str]);

                % only create and save modified hazard if it not does not yet
                % exist
                if ~exist([hazard_dir filesep hazard_save_file],'file') | force_recalc
                    switch peril_ID{p_i}
                        case 'TC'
                            frequency_screw = TC_frequency_screw(b_i);
                            intensity_screw = TC_intensity_screw(b_i);
                            intensity_shift = 0;
                        case 'TS'
                            frequency_screw = TS_frequency_screw(b_i);
                            intensity_screw = TS_intensity_screw(b_i);
                            intensity_shift = TS_intensity_shift(b_i);
                    end
                    clear hazard
                    load([hazard_dir filesep hazard_files.name])
                    fprintf('Hazard %s created.\n',hazard_save_file);
                    hazard = climada_hazard_clim_scen(hazard,hazard_save_file,frequency_screw,intensity_screw,intensity_shift);
                    ok = 1;
                else
                    fprintf('Hazard %s exists already.\n',hazard_save_file)
                end
            end %ischar
        end %~isempty
    end
  
end

diary off
