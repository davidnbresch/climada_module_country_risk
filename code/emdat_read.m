function em_data=emdat_read(emdat_file,country_name,peril_ID,exposure_growth,verbose_mode,CAGR)
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
%   country_name: if provided, only return records for specific country - r
%   for the list of countries, if provided as cell, i.e. {'Vanuata','Aruba'}
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
%   CAGR: the compound annual growht rate (decimal). If not specified, the
%       GDP development of thw past is used to index damages, and a CAGR
%       default is used where no GDP exists (see PARAMETERS section, CAGR set
%       to 0.02).
% OUTPUTS:
%   em_data, a structure with (for each event i)
%       filename: the original filename with EM-DAT fata
%       year(i): the year (e.g. use hist(em_data.year) to get a feel...)
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
%       YDS: the year damage set, just plain summation of all damages in
%           one year, use climada_EDS2DFC(em_data.YDS) to plot...
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150126, initial, Sils Maria
% David N. Bresch, david.bresch@gmail.com, 20150207, list of countries accepted
% David N. Bresch, david.bresch@gmail.com, 20150208, YDS added
%-

em_data=[]; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('emdat_file','var'),emdat_file='';end
if ~exist('country_name','var'),country_name='';end
if ~exist('peril_ID','var'),peril_ID='';end
if ~exist('exposure_growth','var'),exposure_growth=0;end
if ~exist('verbose_mode','var'),verbose_mode=0;end
if ~exist('CAGR','var'),CAGR=[];end

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
if isempty(CAGR)
    CAGR=climada_global.global_CAGR; % compound annual growth rate, decimal, e.g. 0.02 for 2%
    force_CAGR=0; % since default set
else
    force_CAGR=1; % since CAGR specified on input
end
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

% get rid of all zero values
orig_datacount=length(em_data.damage);
non_zero_damage=em_data.damage>0;
em_data.damage=em_data.damage(non_zero_damage);
em_data.country=em_data.country(non_zero_damage);
em_data.disaster_subtype=em_data.disaster_subtype(non_zero_damage);
em_data.year=em_data.year(non_zero_damage);
em_data.occurrence=em_data.occurrence(non_zero_damage);
em_data.deaths=em_data.deaths(non_zero_damage);
em_data.affected=em_data.affected(non_zero_damage);
em_data.injured=em_data.injured(non_zero_damage);
em_data.homeless=em_data.homeless(non_zero_damage);
em_data.disaster_type=em_data.disaster_type(non_zero_damage);
em_data.total_affected=em_data.total_affected(non_zero_damage);
nonzero_datacount=length(em_data.damage);
if verbose_mode,fprintf('full EM-DAT: %i entries damage>0 (%i raw entries)\n',nonzero_datacount,orig_datacount);end

EMDAT_first_year=min(em_data.year);

%fields: (country), year, disaster type, disaster subtype, occurrence, deaths, affected, injured, homeless, total_affected, total_damage

if ~isempty(country_name) && isfield(em_data,'country')
        
    % if only one country (char), convert to cell
    if ischar(country_name),country_name=cellstr(country_name);end

    if iscell(country_name)
        country_pos=[]; % init
        for country_i=1:length(country_name)
            country_name_char=char(country_name{country_i});
            % explicitely deal with non-standard country names
            if strcmp(country_name_char,'Vietnam'),country_name_char='Viet Nam';end
            if strcmp(country_name_char,'US Virgin Islands'),country_name_char='Virgin Is (US)';end
            if strcmp(country_name_char,'Turks and Caicos Islands'),country_name_char='Turks and Caicos';end
            if strcmp(country_name_char,'Taiwan'),country_name_char='Taiwan (China)';end
            if strcmp(country_name_char,'Syria'),country_name_char='Syrian Arab Rep';end
            if strcmp(country_name_char,'Saint Vincent and the Grenadines'),country_name_char='St Vincent and t';end
            if strcmp(country_name_char,'Saint Lucia'),country_name_char='St Lucia';end
            if strcmp(country_name_char,'St. Kitts and Nevis'),country_name_char='St Kitts and Nev';end
            if strcmp(country_name_char,'Saint Helena'),country_name_char='St Helena';end
            if strcmp(country_name_char,'Russia'),country_name_char='Soviet Union';end
            if strcmp(country_name_char,'Sao Tome and Principe'),country_name_char='Sao Tome et Prin';end
            if strcmp(country_name_char,'Solomon Is.'),country_name_char='Solomon Is';end
            if strcmp(country_name_char,'Moldova'),country_name_char='Moldova Rep';end
            if strcmp(country_name_char,'Solomon Islands'),country_name_char='Marshall Is';end
            if strcmp(country_name_char,'Marshall Islands'),country_name_char='Solomon Is';end
            if strcmp(country_name_char,'Congo'),country_name_char='Zaire/Congo Dem';end
            if strcmp(country_name_char,'Laos'),country_name_char='Lao P Dem Rep';end
            if strcmp(country_name_char,'Korea'),country_name_char='Korea Rep';end
            if strcmp(country_name_char,'Iran'),country_name_char='Iran Islam Rep';end
            if strcmp(country_name_char,'Hong Kong'),country_name_char='Hong Kong (China';end
            if strcmp(country_name_char,'Dominican Republic'),country_name_char='Dominican Rep';end
            if strcmp(country_name_char,'Czech Republic'),country_name_char='Czech Rep';end
            if strcmp(country_name_char,'Gambia'),country_name_char='Gambia The';end
            if strcmp(country_name_char,'Antigua and Barbuda'),country_name_char='Antigua and Barb';end
            country_name{country_i}=country_name_char;            
            country_pos=[country_pos strmatch(country_name_char,em_data.country)']; 
        end % country_i
    else
        country_pos=strmatch(country_name,em_data.country);
    end
    
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
        
        nonzero_datacount=sum(em_data.damage>0);
        if verbose_mode,fprintf('country selection: %i entries damage>0 (%i raw entries)\n',nonzero_datacount,length(em_data.damage));end

    else
        fprintf('Error: country %s not found, aborted\n',char(country_name));
        em_data=[];
        return
    end
    
elseif ~isempty(country_name) && ~isfield(em_data,'country')
    
    fprintf('Warning: no field em_data.country, check whether data is only for country %s\n',char(country_name)');
    
end % country_name

if ~isempty(peril_ID) && isfield(em_data,'disaster_subtype')
    
    peril_pos=[]; % init
    for peril_i=1:size(peril_ID,1) % we allow for more than one peril here
        one_peril_ID=peril_ID(peril_i,:);
        match_pos=strcmp(peril_match_table(:,1),one_peril_ID);
        
        if sum(match_pos)>0
            disaster_subtype=peril_match_table{match_pos,2};
        else
            disaster_subtype=one_peril_ID;
        end
        peril_pos=[peril_pos;strmatch(disaster_subtype,em_data.disaster_subtype)];
        
    end % peril_i
    
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
        
        nonzero_datacount=sum(em_data.damage>0);
        if verbose_mode,fprintf('peril selection: %i entries damage>0 (%i raw entries)\n',nonzero_datacount,length(em_data.damage));end

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
          
        if isempty(valid_GDP_pos) || force_CAGR % either no GDP or CAGR specified
            
            fprintf('Warning: no GDP for country %s, %2.1f%% CAGR correction for exposure growth\n',char(country_name)',CAGR*100);
            
            GDP_factor(1:EMDAT_last_year-year0)=(1+CAGR).^(EMDAT_last_year-year0-1:-1:0);
            annotation_name=[annotation_name ' indexed*']; % '*' indicates the CAGR appraoch
            
        else
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

% also create the annual aggregate (not based on a yearset, just summing up
% over all events in one year
unique_years=unique(em_data.year);

% init YDS (year damage set)
em_data.YDS.damage=zeros(1,length(unique_years));
em_data.YDS.yyyy=unique_years;
em_data.YDS.orig_year_flag=ones(1,length(unique_years));
em_data.YDS.event_ID=[];
em_data.YDS.orig_event_flag=[];
em_data.YDS.reference_year=EMDAT_last_year;
em_data.YDS.Value=[];
em_data.YDS.orig_event_flag=[];
em_data.YDS.peril_ID=peril_ID;
em_data.YDS.frequency=ones(1,length(em_data.YDS.damage))/(EMDAT_last_year-EMDAT_first_year+1);
em_data.YDS.hazard=[];
em_data.YDS.assets=[];
em_data.YDS.ED=em_data.DFC.ED;
em_data.YDS.damagefunctions=[];
em_data.YDS.annotation_name='EM-DAT annual aggregate';
em_data.YDS.comment=sprintf('generated by %s',mfilename);

for year_i=1:length(unique_years)
    em_data.YDS.damage(year_i)=sum(em_data.damage(em_data.year==unique_years(year_i)));
end

if verbose_mode
    country_list=unique(em_data.country);
    country_list % verbose, hence no ';'
    disaster_subtype_list=unique(em_data.disaster_subtype);
    disaster_subtype_list % verbose, hence no ';'
end
    
end % emdat_read