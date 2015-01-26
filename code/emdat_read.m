function em_data=emdat_read(emdat_file,country_name,peril_ID,verbose_mode)
% climada template
% MODULE:
%   country_rsk
% NAME:
%   emdat_read
% PURPOSE:
%   read EM-DAT database (www.emdat.be and www.emdat.be/explanatory-notes)
%   from the file {country_risk_module}/data/emdat/emdat.xls
%
%   Also produce a damage frequency curve (DFC) in order to ease comparison with
%   climada results, especially if EM-DAT data is filtered by country (see
%   input country_name) and peril (see input peril_ID).
%   Use e.g. plot(em_data.DFC.return_period,em_data.DFC.damage) to plot the
%   damage excess frequency curve based on EM-DAT.
%
% CALLING SEQUENCE:
%   em_data=emdat_read(emdat_file,country_name,peril_ID)
% EXAMPLE:
%   em_data=emdat_read('','United States','TC');
% INPUTS:
%   emdat_file: filename of the emdat database
%       Default (='' or no input at all) is full global EM-DAT database, 
%       see PARAMETERS for its default location
%       if ='ASK', prompt for
% OPTIONAL INPUT PARAMETERS:
%   country_name: if provided, only return records for specific country
%       default: all countries
%   peril_ID: if provided, only return records for specific peril,
%       currently implemented are
%       - 'TC': tropical cyclone, returns records with disaster subtype='Tropical cyclone'
%       - 'TS': tropical cyclone surge, returns records with disaster subtype='Coastal flood'
%       - 'FL': flood, returns records with disaster subtype='Riverine flood'
%       - 'WS': winter storm, returns records with disaster subtype='Extra-tropical s'
%       - 'EQ': earthquake, returns records with disaster subtype='Ground movement'
%       - or just any of the disaster subtypes in EM-DAT, e.g. 'Tsunami'. You
%         might use em_data=emdat_read('','China','',1); to get a list of all
%         available disaster subtypes in China
%       Default: all perils (i.e. all disaster subtypes)
%   verbose_mode: if =1, print list of countries and disaster subtypes that
%       are returned in em_data. Default=0 (silent)
% OUTPUTS:
%   em_data, a structure with (for each event i)
%       filename: the original filename with EM-DAT fata
%       year(i): the year
%       disaster_type{i}: disaster type i, see www.emdat.be/explanatory-notes
%       disaster_subtype{i}: disaster subtype i, see www.emdat.be/explanatory-notes
%       occurrence(i): see www.emdat.be/explanatory-notes
%       deaths(i): see www.emdat.be/explanatory-notes
%       affected(i): see www.emdat.be/explanatory-notes
%       injured(i): see www.emdat.be/explanatory-notes
%       homeless(i): see www.emdat.be/explanatory-notes
%       damage(i): the damage in USD (in units of 1 USD)
%           Note that EM-DAT estimated damage in the database are given in
%           US$ (?000), hence we multiply by 1000.
%       frequency(i): the frequency of eaxch event (once in the years the
%           database exists for)
%       DFC: the damage frequency curve, a structure, see e.g.
%           climada_EDS2DFC for this structures's fields, e.g.
%           DFC.return_period and DFC.damage
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150126, initial, Sils Maria
%-

em_data=[]; % init output

%global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('emdat_file','var'),emdat_file='';end
if ~exist('country_name','var'),country_name='';end
if ~exist('peril_ID','var'),peril_ID='';end
if ~exist('verbose_mode','var'),verbose_mode=0;end

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% define the the default database file
if isempty(emdat_file),emdat_file=[module_data_dir filesep 'emdat' filesep 'emdat.xls'];end
%
% the table to match climada peril_ID with EM-data disaster subtype
peril_match_table={
    'TC' 'Tropical cyclone'
    'TS' 'Coastal flood'
    'EQ' 'Ground movement'
    'FL' 'Riverine flood'
    'WS' 'Extra-tropical s'
    };
% TEST (only to speed up testing)
%emdat_file=[module_data_dir filesep 'emdat' filesep 'emdat_USA_UnitedStates.xls'] % no ';' to show TEST

if strcmp(emdat_file,'ASK'),emdat_file='';end

% prompt for emdat_file
if isempty(emdat_file) % local GUI
    emdat_file=[module_data_dir filesep 'emdat' filesep '*.xls'];
    [filename, pathname] = uigetfile(emdat_file, 'Open:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        emdat_file=fullfile(pathname,filename);
    end
end

[fP,fN]=fileparts(emdat_file);
emdat_file_mat=[fP filesep fN '.mat'];
if climada_check_matfile(emdat_file,emdat_file_mat)
    load(emdat_file_mat);
else
    em_data=climada_spreadsheet_read('no',emdat_file,'emdat',1); % allow for .xls and .ods
    
    % rename for consistency with climada
    em_data.damage=em_data.total_damage*1000; % EM-DAT estimated damage are given in US$ (?000)
    em_data=rmfield(em_data,'total_damage');
    
    if isfield(em_data,'unique'),em_data=rmfield(em_data,'unique');end % only used in Excel
    
    save(emdat_file_mat,'em_data');
end

%fields: (country), year, disaster type, disaster subtype, occurrence, deaths, affected, injured, homeless, total_affected, total_damage

if ~isempty(country_name) && isfield(em_data,'country')
    
    country_pos=strmatch(country_name,em_data.country);
    if ~isempty(country_pos)
        
        em_data.country=em_data.country(country_pos);
        if isfield(em_data,'disaster_type'),em_data.disaster_type=em_data.disaster_type(country_pos);end;
        if isfield(em_data,'disaster_subtype'),em_data.disaster_subtype=em_data.disaster_subtype(country_pos);end;
        em_data.year=em_data.year(country_pos);
        em_data.occurrence=em_data.occurrence(country_pos);
        em_data.deaths=em_data.deaths(country_pos);
        em_data.affected=em_data.affected(country_pos);
        em_data.injured=em_data.injured(country_pos);
        em_data.homeless=em_data.homeless(country_pos);
        em_data.total_affected=em_data.total_affected(country_pos);
        em_data.damage=em_data.damage(country_pos);
    else
        fprintf('Error: country %s not found, aborted\n',char(country_name));
        em_data=[];
        return
    end
    
elseif ~isempty(country_name) && ~isfield(em_data,'country')
    
    fprintf('Warning: no field em_data.country, check whether data is only for country %s\n',char(country_name));
    
end % country_name

if ~isempty(peril_ID) && isfield(em_data,'disaster_subtype')
    
    match_pos=strcmp(peril_match_table(:,1),peril_ID);
    
    if sum(match_pos)>0
        disaster_subtype=peril_match_table{match_pos,2};
    else
        disaster_subtype=peril_ID;
%         fprintf('peril_ID %s not matched,aborted\n',char(peril_ID));
%         em_data=[];
%         return
    end
    
    peril_pos=strmatch(disaster_subtype,em_data.disaster_subtype);
    if ~isempty(peril_pos)
        if isfield(em_data,'country'),em_data.country=em_data.country(peril_pos);end;
        if isfield(em_data,'disaster_type'),em_data.disaster_type=em_data.disaster_type(peril_pos);end;
        if isfield(em_data,'disaster_subtype'),em_data.disaster_subtype=em_data.disaster_subtype(peril_pos);end;
        em_data.year=em_data.year(peril_pos);
        em_data.occurrence=em_data.occurrence(peril_pos);
        em_data.deaths=em_data.deaths(peril_pos);
        em_data.affected=em_data.affected(peril_pos);
        em_data.injured=em_data.injured(peril_pos);
        em_data.homeless=em_data.homeless(peril_pos);
        em_data.total_affected=em_data.total_affected(peril_pos);
        em_data.damage=em_data.damage(peril_pos);
    else
        fprintf('Error: peril %s not found\n',char(peril_ID));
        em_data=[];
        return
    end
        
end % peril_ID

% add DFC
em_data.DFC.value=NaN;
em_data.DFC.peril_ID=peril_ID;
em_data.DFC.annotation_name=fN;

em_data.frequency=(em_data.damage*0+1)*1/(max(em_data.year)-min(em_data.year)+1);
em_data.DFC.ED=em_data.damage'*em_data.frequency; % just assume...

[sorted_damage,exceedence_freq]=climada_damage_exceedence(em_data.damage',em_data.frequency');
nonzero_pos               = find(exceedence_freq);
em_data.DFC.damage        = sorted_damage(nonzero_pos);
exceedence_freq           = exceedence_freq(nonzero_pos);
em_data.DFC.return_period = 1./exceedence_freq;
em_data.DFC.damage_of_value=em_data.DFC.damage./em_data.DFC.value;

if verbose_mode
    country_list=unique(em_data.country);
    country_list % verbose, hence no ';'
    disaster_subtype_list=unique(em_data.disaster_subtype);
    disaster_subtype_list % verbose, hence no ';'
end
    
end % emdat_read