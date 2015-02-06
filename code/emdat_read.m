function em_data=emdat_read(emdat_file,country_name,peril_ID,exposure_growth,verbose_mode)
% climada template
% MODULE:
%   country_rsk
% NAME:
%   emdat_read
% PURPOSE:
%   Read EM-DAT database (www.emdat.be and www.emdat.be/explanatory-notes)
%   from the file {country_risk_module}/data/emdat/emdat.xls
%
%   Please note that the EM-DAT database does NOT contain its reference
%   date (i.e. the last year it contains data for, see EMDAT_last_year
%   in PARAMETERS)
%
%   If requested, index past damages according to GDP (see
%   exposure_growth). This feature needs t GDP_entity module to exist
%
%   Also produce a damage frequency curve (DFC) in order to ease comparison with
%   climada results, especially if EM-DAT data is filtered by country (see
%   input country_name) and peril (see input peril_ID).
%   Use e.g. plot(em_data.DFC.return_period,em_data.DFC.damage) to plot the
%   damage excess frequency curve based on EM-DAT.
%
% CALLING SEQUENCE:
%   em_data=emdat_read(emdat_file,country_name,peril_ID,exposure_growth,verbose_mode)
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
%         might use em_data=emdat_read('','China','',0,1); to get a list of all
%         available disaster subtypes in China
%       Default: all perils (i.e. all disaster subtypes)
%   exposure_growth: =1: correct damage numbers to account for exposure
%       growth (the field em_data.damage_orig contains the uncorrected numbers
%       Only works if a single country is requested, i.e. if country_name
%       is specified. In essence, we calculate the correction factor for
%       year i as GDP(today)/GDP(year i)
%       =0: no correction (default)
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
%       damage_orig(i): the uncorrected damage in case exposure_growth=1
%       frequency(i): the frequency of eaxch event (once in the years the
%           database exists for)
%       DFC: the damage frequency curve, a structure, see e.g.
%           climada_EDS2DFC for this structures's fields, e.g.
%           DFC.return_period and DFC.damage
%       DFC_orig: the DFC of the original damages in case exposure_growth=1
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
if ~exist('exposure_growth','var'),exposure_growth=0;end
if ~exist('verbose_mode','var'),verbose_mode=0;end

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% define the the default database file
if isempty(emdat_file),emdat_file=[module_data_dir filesep 'emdat' filesep 'emdat.xls'];end
%
% the EM-DAT reference year, i.e. the last year EM-DAT is valid for
% see also www.emdat.be/explanatory-notes
EMDAT_last_year=2013; 
% Note that EMDAT_first_year is not the same for all countries, hence
% determined in code
year0=1800; % earlier than min(GDP.year), not the smallest EM-DAT year, but a year really in the past
% in case there is no GDP for a given country, use simple discounting
CAGR=0.02; % compound annual growth rate, decimal, e.g. 0.02 for 2%
%
% the table to match climada peril_ID with EM-data disaster subtype
peril_match_table={
    'TC' 'Tropical cyclone'
    'TS' 'Coastal flood'
    'EQ' 'Ground movement'
    'FL' 'Riverine flood'
    'WS' 'Extra-tropical s'
    };
%
% the table with GDP of past years (only used if exposure_growth=1):
GDP_module_data_dir=[fileparts(fileparts(which('climada_create_GDP_entity'))) filesep 'data'];
GDP_data_file=[GDP_module_data_dir filesep 'World_GDP_current.xls'];
%
% the annotation name in DFC (see below)
annotation_name='EM-DAT';
%
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

EMDAT_first_year=min(em_data.year);

%fields: (country), year, disaster type, disaster subtype, occurrence, deaths, affected, injured, homeless, total_affected, total_damage

if ~isempty(country_name) && isfield(em_data,'country')
    
    % explicitely deal with non-standard country names
    if strcmp(country_name,'Vietnam'),country_name='Viet Nam';end
    if strcmp(country_name,'US Virgin Islands'),country_name='Virgin Is (US)';end
    if strcmp(country_name,'Turks and Caicos Islands'),country_name='Turks and Caicos';end
    if strcmp(country_name,'Taiwan'),country_name='Taiwan (China)';end
    if strcmp(country_name,'Syria'),country_name='Syrian Arab Rep';end
    if strcmp(country_name,'Saint Vincent and the Grenadines'),country_name='St Vincent and t';end
    if strcmp(country_name,'Saint Lucia'),country_name='St Lucia';end
    if strcmp(country_name,'St. Kitts and Nevis'),country_name='St Kitts and Nev';end
    if strcmp(country_name,'Saint Helena'),country_name='St Helena';end
    if strcmp(country_name,'Russia'),country_name='Soviet Union';end
    if strcmp(country_name,'Sao Tome and Principe'),country_name='Sao Tome et Prin';end
    if strcmp(country_name,'Solomon Is.'),country_name='Solomon Is';end
    if strcmp(country_name,'Moldova'),country_name='Moldova Rep';end
    if strcmp(country_name,'Solomon Islands'),country_name='Marshall Is';end
    if strcmp(country_name,'Marshall Islands'),country_name='Solomon Is';end
    if strcmp(country_name,'Congo'),country_name='Zaire/Congo Dem';end
    if strcmp(country_name,'Laos'),country_name='Lao P Dem Rep';end
    if strcmp(country_name,'Korea'),country_name='Korea Rep';end
    if strcmp(country_name,'Iran'),country_name='Iran Islam Rep';end
    if strcmp(country_name,'Hong Kong'),country_name='Hong Kong (China';end
    if strcmp(country_name,'Dominican Republic'),country_name='Dominican Rep';end
    if strcmp(country_name,'Czech Republic'),country_name='Czech Rep';end
    if strcmp(country_name,'Gambia'),country_name='Gambia The';end
    if strcmp(country_name,'Antigua and Barbuda'),country_name='Antigua and Barb';end
    
    country_pos=strmatch(country_name,em_data.country);
    if ~isempty(country_pos)
    %country_pos = strcmp(country_name,em_data.country)==1;
    %if sum(country_pos)>0
        
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
        
        EMDAT_first_year=min(em_data.year); % adjust, as not all countries have date since same year
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
    end
    
    peril_pos=strmatch(disaster_subtype,em_data.disaster_subtype);
    if ~isempty(peril_pos)
    %peril_pos = strcmp(disaster_subtype,em_data.disaster_subtype)==1;
    %if sum(peril_pos)>0
        
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
        
        % we do NOT adjust EMDAT_first_year, as we assume all perils being
        % reported the first year the country is reported

    else
        fprintf('Error: peril %s not found\n',char(peril_ID));
        em_data=[];
        return
    end
        
end % peril_ID

if exposure_growth
    
    GDP_factor=ones(2200-year0,1); % allocate, such that GDP_factor(year-year0) is the factor for year

    % Check if economic data file is available
    if ~exist(GDP_data_file,'file')
        fprintf('Error: %s is missing, no exposure growth correction\n',GDP_data_file)
        fprintf('Please download it from the <a href="https://github.com/davidnbresch/climada_module_GDP_entity">climada GDP_entity repository on Github\n</a>');
    else
        
        [fP,fN]=fileparts(GDP_data_file);
        GDP_data_file_mat=[fP filesep fN '.mat'];
                
        if climada_check_matfile(GDP_data_file,GDP_data_file_mat)
            load(GDP_data_file_mat); % contains GDP
        else
            GDP=climada_GDP_read(GDP_data_file, 1, 1, 1);
            save(GDP_data_file_mat,'GDP'); % save for subsequent calls
        end
        
        country_pos=strmatch(country_name,GDP.country_names); % more tolerant a matching
        
        if length(country_pos)>1,country_pos=[];end % more than one country, resort to CAGR below
        
        if ~isempty(country_pos)
            
            % we have a country entry in the GDP table
            %country_pos = strcmp(country_name,GDP.country_names)==1;
            %if sum(country_pos)==1
            
            GDP_value=GDP.value(country_pos,:);
            
            % get rid of occasional NaN (missing GDP years)
            % BUT: this might lead to shifts +/- 1 year in GDP (better than
            % nothing, but really a fix)
            GDP_value(isnan(GDP_value))=0;
            valid_GDP_pos=find(GDP_value>0);
        else
            valid_GDP_pos=[];
        end
          
        if ~isempty(valid_GDP_pos)
            
            % we have non-zero (or non-NaN GDPs)
            
            GDP.year = GDP.year(valid_GDP_pos);
            GDP_value=GDP_value(valid_GDP_pos);
            
            GDP_factor(GDP.year-year0)=GDP_value(end)./GDP_value;
            
            % fill earlier years with earliest correction factor
            GDP_factor(1:GDP.year(1)-year0-1)=max(GDP_factor);
            
            % fill later years with latest correction factor
            GDP_factor(GDP.year(end)-year0+1:end)=min(GDP_factor);
            
            %plot(GDP.year,GDP.value(country_pos,:)) % GDP checkplot
            %figure,year=(1:length(GDP_factor))+year0;plot(year,GDP_factor) % GDP factor checkplot
            
            annotation_name=[annotation_name ' indexed'];
        else
            fprintf('Warning: no GDP for country %s, %2.1f%% CAGR correction for exposure growth\n',char(country_name),CAGR*100);
            
            GDP_factor(1:EMDAT_last_year-year0)=(1+CAGR).^(EMDAT_last_year-year0-1:-1:0);
            annotation_name=[annotation_name ' indexed*']; % '*' indicates the CAGR appraoch
        end
             
        em_data.damage_orig=em_data.damage; % store uncorrected
        em_data.damage=em_data.damage.*GDP_factor(em_data.year-year0);

    end % table missing
    
end % exposure_growth

% not necessarily min/max of em_data.year
em_data.first_year=EMDAT_first_year;
em_data.last_year=EMDAT_last_year;

% add DFC
em_data.DFC.value=NaN;
em_data.DFC.peril_ID=peril_ID;
em_data.DFC.annotation_name=annotation_name;

em_data.frequency=ones(length(em_data.damage),1)/(EMDAT_last_year-EMDAT_first_year+1);
em_data.DFC.ED=em_data.damage'*em_data.frequency; % just assume...

[sorted_damage,exceedence_freq]=climada_damage_exceedence(em_data.damage',em_data.frequency');
nonzero_pos               = find(exceedence_freq);
em_data.DFC.damage        = sorted_damage(nonzero_pos);
exceedence_freq           = exceedence_freq(nonzero_pos);
em_data.DFC.return_period = 1./exceedence_freq;
em_data.DFC.damage_of_value=em_data.DFC.damage./em_data.DFC.value;

if isfield(em_data,'damage_orig')
    % add DFC for original damage
    em_data.DFC_orig=em_data.DFC;
    em_data.DFC_orig.annotation_name='EM-DAT orig';
    em_data.DFC_orig.ED=em_data.damage_orig'*em_data.frequency; % just assume...
    
    [sorted_damage,exceedence_freq]=climada_damage_exceedence(em_data.damage_orig',em_data.frequency');
    nonzero_pos               = find(exceedence_freq);
    em_data.DFC_orig.damage   = sorted_damage(nonzero_pos);
    exceedence_freq           = exceedence_freq(nonzero_pos);
    em_data.DFC_orig.return_period = 1./exceedence_freq;
    em_data.DFC_orig.damage_of_value=em_data.DFC_orig.damage./em_data.DFC_orig.value;
end

if verbose_mode
    country_list=unique(em_data.country);
    country_list % verbose, hence no ';'
    disaster_subtype_list=unique(em_data.disaster_subtype);
    disaster_subtype_list % verbose, hence no ';'
end
    
end % emdat_read