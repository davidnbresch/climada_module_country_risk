function em_data=emdat_read(emdat_file,country_ISO3,peril_ID,exposure_growth,verbose_mode,CAGR)
% climada template
% MODULE:
%   country_rsk
% NAME:
%   emdat_read
% PURPOSE:
%   Read EM-DAT database (www.emdat.be and www.emdat.be/explanatory-notes)
%   from the file {country_risk_module}/data/emdat/emdat.xls
%
%   The code primarily reads disaster_syubtype (more precise), which also
%   allows a better mapping to climada perils (see paramter peril_ID). But
%   since some (past) events are not properly classified by type and/or
%   subtype, one can also base the selection on disaster_type (see
%   parameter peril_ID). Since we joined disaster type to subtype in Exel,
%   disaster type is always there.
%
%   Please note that the EM-DAT database does NOT contain its reference
%   date (i.e. the last year it contains data for, see EMDAT_last_year
%   in PARAMETERS)
%
%   If requested, index past damages according to GDP (see
%   exposure_growth). This feature needs t GDP_entity module to exist
%
%   Please note that the code stores a .mat copy of the Excel upon first
%   import (checkes for .mat file being younger then Excel). Use this .mat
%   file in case you'd like to get all records, also those with no damage
%   or affeced people.
%
%   Also produce a damage frequency curve (DFC) in order to ease comparison with
%   climada results, especially if EM-DAT data is filtered by country (see
%   input country_ISO3) and peril (see input peril_ID).
%   Use e.g. plot(em_data.DFC.return_period,em_data.DFC.damage) to plot the
%   damage excess frequency curve based on EM-DAT.
%   
%   see also: emdat_barplot 
%
% CALLING SEQUENCE:
%   em_data=emdat_read(emdat_file,country_ISO3,peril_ID,exposure_growth,verbose_mode,CAGR)
% EXAMPLE:
%   em_data=emdat_read('','USA','TC',1,1); % with exposure growth
%   em_data=emdat_read('','USA','TC',2005,1); % with exposure growth relative to year 2005
%   em_data=emdat_read('','USA','TC',0,1); % without exposure growth
% INPUTS:
%   emdat_file: filename of the emdat database
%       Default (='' or no input at all) is full global EM-DAT database, 
%       see PARAMETERS for its default location
%       if ='ASK', prompt for
% OPTIONAL INPUT PARAMETERS:
%   country_ISO3: if provided, only return records for specific country - or
%       for the list of countries, if provided as cell, i.e. {'USA','CAN'}
%       default: all countries (use climada_country_name to obtaib the ISO3 code)
%   peril_ID: if provided, only return records for specific peril, based on
%       disaster_subtype (since more precise). If peril_ID starts with '-',
%       such as '-TC' or '-Storm', disaster_type is used instead of subtype.
%       currently implemented are (see PARAMETERS section)
%       - 'TC': tropical cyclone, returns records with disaster subtype='Tropical cyclone' or type 'Storm'
%       - 'TS': tropical cyclone surge, returns records with disaster subtype='Coastal flood'
%       - 'FL': flood, returns records with disaster subtype='Riverine flood'
%       - 'WS': winter storm, returns records with disaster subtype='Extra-tropical storm' or type 'Storm'
%       - 'EQ': earthquake, returns records with disaster subtype='Ground movement' or type 'Earthquake'
%       - or just any of the disaster subtypes or types in EM-DAT, e.g.
%       'Tsunami' (a subtype) or '-Storm' (a type, thus the traling '-'.
%       You might use em_data=emdat_read('','USA','',0,1); to get a list of
%       all available disaster types or subtypes in the United States (or
%       any other country), or emdat_read('','','',0,1) to get all
%       Default: all perils (i.e. all disaster subtypes)
%   exposure_growth: =1: correct damage numbers to account for exposure
%       growth (the field em_data.damage_orig contains the uncorrected numbers
%       Only works if a single country is requested, i.e. if country_ISO3
%       is specified. In essence, we calculate the correction factor for
%       year i as GDP(today)/GDP(year i)
%       =0: no correction (default)
%       =yyyy (e.g. 2005): use this as reference year, see growth_reference_year
%   verbose_mode: if =1, print list of countries and disaster subtypes that
%       are returned in em_data. Default=0 (silent)
%   CAGR: the compound annual growht rate (decimal). If not specified, the
%       GDP development of thw past is used to index damages, and a CAGR
%       default is used where no GDP exists (see PARAMETERS section, CAGR set
%       to 0.02).
% OUTPUTS:
%   em_data, a structure with (for each row/event i, field names converted to lowercase)
%       filename: the original filename with EM-DAT fata
%       year(i): the year (e.g. use hist(em_data.year) to get a feel...)
%       disaster_type{i}: disaster type i, see www.emdat.be/explanatory-notes
%       disaster_subtype{i}: disaster subtype i, see www.emdat.be/explanatory-notes
%       occurrence(i): see www.emdat.be/explanatory-notes
%       total_deaths(i): see www.emdat.be/explanatory-notes
%       total_affected(i): see www.emdat.be/explanatory-notes
%       injured(i): see www.emdat.be/explanatory-notes
%       homeless(i): see www.emdat.be/explanatory-notes
%       damage(i): the damage in USD (in units of 1 USD)
%           Note that EM-DAT estimated damage in the database are given in
%           US$ (?000), hence we multiply by 1000. And note further that we
%           rename Total_damage to damage for climada compatibility.
%       damage_orig(i): the uncorrected damage in case exposure_growth=1
%       disaster_combitype(i): both type and subtype, as 'type .. subtype' (for checks)
%       frequency(i): the frequency of eaxch event (once in the years the
%           database exists for)
%       DFC: the damage frequency curve, a structure, see e.g.
%           climada_EDS2DFC for this structures's fields, e.g.
%           DFC.return_period and DFC.damage
%       DFC_orig: the DFC of the original damages in case exposure_growth=1
%       YDS: the year damage set, just plain summation of all damages in
%           one year, use climada_EDS2DFC(em_data.YDS) to plot...
%       last_year: the last year there is data in the whole EM-DAT
%       first_year: the first year there is data for selected country(s)
%       first_year_overall: the first year there is any data in the whole
%           EM-DAT
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150126, initial, Sils Maria
% David N. Bresch, david.bresch@gmail.com, 20150207, list of countries accepted
% David N. Bresch, david.bresch@gmail.com, 20150208, YDS added
% David N. Bresch, david.bresch@gmail.com, 20170715, new emdat until mid 2017
% David N. Bresch, david.bresch@gmail.com, 20170725, FULL overhaul
% David N. Bresch, david.bresch@gmail.com, 20170727, Value_unit added
% David N. Bresch, david.bresch@gmail.com, 20170730, on output em_data.emdat_file_mat added
% David N. Bresch, david.bresch@gmail.com, 20180319, growth_reference_year added
%-

em_data=[]; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('emdat_file','var'),emdat_file='';end
if ~exist('country_ISO3','var'),country_ISO3='';end
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
if isempty(emdat_file),emdat_file=[module_data_dir filesep 'emdat' filesep 'emdat.xlsx'];end % 20170715 .xslx
%
% the EM-DAT reference year, i.e. the last year EM-DAT is valid for
% see also www.emdat.be/explanatory-notes
EMDAT_last_year=2017;
%
EMDAT_Value_unit='USD'; % hard-wired, since EM-DAT is all in USD
%
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
% the table to match climada peril_ID with EM-data disaster subtype or type
peril_subtype_match_table={
    'TC' 'Tropical cyclone'
    'TS' 'Coastal flood'
    'EQ' 'Ground movement'
    'FL' 'Riverine flood'
    'WS' 'Extra-tropical storm'
    };
%
peril_type_match_table={
    'DR' 'Drought'
    'TC' 'Storm'
    'EQ' 'Earthquake'
    'FL' 'Flood'
    'LS' 'Landslide'
    'WS' 'Storm'
    'VQ' 'Volcanic activity'
    'BF' 'Wildfire'
    'HW' 'Extreme temperature'
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

% figure whether we base the selection on disaster subtype (default) or
% disaster type (on request)
disaster_type_switch='disaster_subtype'; % default
if ~isempty(peril_ID)
    if strcmp(peril_ID(1),'-')
        peril_ID=peril_ID(2:end);
        disaster_type_switch='disaster_type'; % default
    end
end

if strcmp(disaster_type_switch,'disaster_subtype')
    peril_match_table=peril_subtype_match_table;
else
    peril_match_table=peril_type_match_table;
end
if verbose_mode,fprintf('selection based on %s\n',disaster_type_switch);end

[fP,fN]=fileparts(emdat_file);
emdat_file_mat=[fP filesep fN '_' disaster_type_switch '.mat']; % special

if climada_check_matfile(emdat_file,emdat_file_mat)
    load(emdat_file_mat);
else
    em_data=climada_spreadsheet_read('no',emdat_file,disaster_type_switch,1); % allow for .xls and .ods
    
    % remove helper columns (only used in Excel to join type)
    if isfield(em_data,'unique'),em_data=rmfield(em_data,'unique');end
    if isfield(em_data,'disaster_type_LOOKUP'),em_data=rmfield(em_data,'disaster_type_LOOKUP');end
    if isfield(em_data,'disaster_type_MAPPING'),em_data=rmfield(em_data,'disaster_type_MAPPING');end
    if isfield(em_data,'ISNA_on_LOOKUP'),em_data=rmfield(em_data,'ISNA_on_LOOKUP');end
    if isfield(em_data,'unique'),em_data=rmfield(em_data,'unique');end
    if isfield(em_data,'subtype_lookup'),em_data=rmfield(em_data,'subtype_lookup');end
    
    % set field names to lower case
    if isfield(em_data,'Total_deaths'),em_data.total_deaths=em_data.Total_deaths;em_data=rmfield(em_data,'Total_deaths');end
    if isfield(em_data,'Injured'),em_data.injured=em_data.Injured;em_data=rmfield(em_data,'Injured');end
    if isfield(em_data,'Affected'),em_data.affected=em_data.Affected;em_data=rmfield(em_data,'Affected');end
    if isfield(em_data,'Homeless'),em_data.homeless=em_data.Homeless;em_data=rmfield(em_data,'Homeless');end
    if isfield(em_data,'Total_affected'),em_data.total_affected=em_data.Total_affected;em_data=rmfield(em_data,'Total_affected');end
    if isfield(em_data,'Occurrence'),em_data.occurrence=em_data.Occurrence;em_data=rmfield(em_data,'Occurrence');end % unclear, whether needed
    
    % special treatment for Total_damage, rename to damage, EM-DAT estimated damage are given in US$ (?000)
    if isfield(em_data,'Total_damage'),em_data.damage=em_data.Total_damage*1000;em_data=rmfield(em_data,'Total_damage');end
    
    save(emdat_file_mat,'em_data','-v7'); % -v7, not yet -v7.3 to ensure Octave compatibility
end

% get rid of all rows with no entries for either deaths, affected or damage
% do NOT get rid of all rows with no entries for either deaths, affected or
% damage, but at least replace NaN with zeros (for better math)
em_data.total_deaths(isnan(em_data.total_deaths))=0;
em_data.injured(isnan(em_data.injured))=0;
em_data.affected(isnan(em_data.affected))=0;
em_data.homeless(isnan(em_data.homeless))=0;
em_data.total_affected(isnan(em_data.total_affected))=0;
em_data.damage(isnan(em_data.damage))=0;

% % OLD, where we removed entries with no damage
% orig_datacount=length(em_data.damage);
% non_zero_entries=em_data.damage>0;
% em_data.damage=em_data.damage(non_zero_entries);
% em_data.iso=em_data.iso(non_zero_entries);
% em_data.country_name=em_data.country_name(non_zero_entries);
% if isfield(em_data,'disaster_type'),em_data.disaster_type(non_zero_entries);end;
% if isfield(em_data,'disaster_subtype'),em_data.disaster_subtype(non_zero_entries);end;
% em_data.year=em_data.year(non_zero_entries);
% em_data.occurrence=em_data.occurrence(non_zero_entries);
% em_data.total_deaths=em_data.total_deaths(non_zero_entries);
% em_data.affected=em_data.affected(non_zero_entries);
% em_data.injured=em_data.injured(non_zero_entries);
% em_data.homeless=em_data.homeless(non_zero_entries);
% em_data.total_affected=em_data.total_affected(non_zero_entries);
% nonzero_datacount=length(em_data.damage);
% if verbose_mode,fprintf('full EM-DAT: %i entries damage>0 (%i raw entries)\n',nonzero_datacount,orig_datacount);end

EMDAT_first_year=min(em_data.year);
EMDAT_last_year=max(max(em_data.year),EMDAT_last_year);

%fields: (country), year, disaster type, disaster subtype, occurrence, deaths, affected, injured, homeless, total_affected, total_damage

if ~isempty(country_ISO3) && isfield(em_data,'iso') % formely matched to country_name, but a mess
        
    % if only one country (char), convert to cell
    if ischar(country_ISO3),country_ISO3=cellstr(country_ISO3);end

    if iscell(country_ISO3)
        country_pos=[]; % init
        for country_i=1:length(country_ISO3)
            country_ISO3_char=char(country_ISO3{country_i});
            country_ISO3{country_i}=country_ISO3_char;            
            country_pos=[country_pos strmatch(country_ISO3_char,em_data.iso)']; 
        end % country_i
    else
        country_pos=strmatch(country_ISO3,em_data.iso);
    end
        
    if ~isempty(country_pos)
               
        em_data.year=em_data.year(country_pos);
        em_data.iso=em_data.iso(country_pos);
        em_data.country_name=em_data.country_name(country_pos);
        if isfield(em_data,'disaster_type'),em_data.disaster_type=em_data.disaster_type(country_pos);end;
        if isfield(em_data,'disaster_subtype'),em_data.disaster_subtype=em_data.disaster_subtype(country_pos);end;
        em_data.occurrence=em_data.occurrence(country_pos);
        em_data.total_deaths=em_data.total_deaths(country_pos);
        em_data.affected=em_data.affected(country_pos);
        em_data.injured=em_data.injured(country_pos);
        em_data.homeless=em_data.homeless(country_pos);
        em_data.total_affected=em_data.total_affected(country_pos);
        em_data.damage=em_data.damage(country_pos);
        
        em_data.first_year_overall=EMDAT_first_year; % store the first year of all data
        EMDAT_first_year=min(em_data.year); % adjust, as not all countries have date since same year
        
        nonzero_datacount=sum(em_data.damage>0);
        if verbose_mode,fprintf('country selection: %i entries damage>0 (%i raw entries)\n',nonzero_datacount,length(em_data.damage));end

    else
        fprintf('EM-DAT, error: country %s not found, aborted\n',char(country_ISO3));
        em_data=[];
        return
    end
    
elseif ~isempty(country_ISO3) && ~isfield(em_data,'country')
    
    fprintf('Warning: no field em_data.iso, check whether data is only for country %s\n',char(country_ISO3)');
    
end % country_ISO3

if ~isempty(peril_ID)
     % note that we decided above whether subtype or type will be used,
     % hence peril_match_table is already the required one
    peril_pos=[]; % init
    for peril_i=1:size(peril_ID,1) % we allow for more than one peril here
        one_peril_ID=peril_ID(peril_i,:);
        match_pos=strcmp(peril_match_table(:,1),one_peril_ID);
        
        if sum(match_pos)>0
            disaster_sub_type=peril_match_table{match_pos,2};
        else
            disaster_sub_type=one_peril_ID;
        end
        
        if strcmp(disaster_type_switch,'disaster_subtype') % here we need to switch
            peril_pos=[peril_pos;strmatch(disaster_sub_type,em_data.disaster_subtype)];
        else
            peril_pos=[peril_pos;strmatch(disaster_sub_type,em_data.disaster_type)];
        end
        
    end % peril_i
    
    if ~isempty(peril_pos)
  
        em_data.year=em_data.year(peril_pos);
        em_data.iso=em_data.iso(peril_pos);
        em_data.country_name=em_data.country_name(peril_pos);
        if isfield(em_data,'disaster_type'),em_data.disaster_type=em_data.disaster_type(peril_pos);end;
        if isfield(em_data,'disaster_subtype'),em_data.disaster_subtype=em_data.disaster_subtype(peril_pos);end;
        em_data.occurrence=em_data.occurrence(peril_pos);
        em_data.total_deaths=em_data.total_deaths(peril_pos);
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
        fprintf('EM-DAT, error: peril %s not found\n',char(peril_ID));
        em_data=[];
        return
    end
        
end % peril_ID

if exposure_growth
    
    if exposure_growth>1900
        growth_reference_year=exposure_growth;
    else
        growth_reference_year=EMDAT_last_year;
    end
    
    GDP_factor=ones(2200-year0,1); % allocate, such that GDP_factor(year-year0) is the factor for year

    % Check if economic data file is available
    if ~exist(GDP_data_file,'file')
        fprintf('EM-DAT, warning: %s is missing, no exposure growth correction\n',GDP_data_file)
        fprintf('Please download it from the <a href="https://github.com/davidnbresch/climada_module_country_risk">climada_module_country_risk</a> repository on Github\n');
    else
        
        [fP,fN]=fileparts(GDP_data_file);
        GDP_data_file_mat=[fP filesep fN '.mat'];
                
        if climada_check_matfile(GDP_data_file,GDP_data_file_mat)
            load(GDP_data_file_mat); % contains GDP
        else
            GDP=climada_GDP_read(GDP_data_file, 1, 1, 1);
            save(GDP_data_file_mat,'GDP'); % save for subsequent calls
        end
        
        country_pos=strmatch(country_ISO3,GDP.iso); % more tolerant a matching
        
        if length(country_pos)>1,country_pos=[];end % more than one country, resort to CAGR below
        
        if ~isempty(country_pos)
            
            % we have a country entry in the GDP table
            %country_pos = strcmp(country_ISO3,GDP.country_ISO3s)==1;
            %if sum(country_pos)==1
            
            GDP_value=GDP.value(country_pos,:);
            
            if verbose_mode,fprintf('GDP values %g .. %g\n',min(GDP_value),max(GDP_value));end

            % get rid of occasional NaN (missing GDP years)
            % BUT: this might lead to shifts +/- 1 year in GDP (better than
            % nothing, but really a fix)
            GDP_value(isnan(GDP_value))=0;
            valid_GDP_pos=find(GDP_value>0);
        else
            valid_GDP_pos=[];
        end
          
        if isempty(valid_GDP_pos) || force_CAGR % either no GDP or CAGR specified
            
            fprintf('Warning: no GDP for country %s, %2.1f%% CAGR correction for exposure growth\n',char(country_ISO3)',CAGR*100);
            
            GDP_factor(1:EMDAT_last_year-year0)=(1+CAGR).^(EMDAT_last_year-year0-1:-1:0);
            annotation_name=[annotation_name ' indexed*']; % '*' indicates the CAGR appraoch
            
        else
            % we have non-zero (or non-NaN GDPs)
            
            GDP.year = GDP.year(valid_GDP_pos);
            GDP_value=GDP_value(valid_GDP_pos);
            
            reference_year_pos=find(GDP.year==growth_reference_year);
            if isempty(reference_year_pos),reference_year_pos=length(GDP_value);end
            em_data.growth_reference_year=growth_reference_year;
            
            GDP_factor(GDP.year-year0)=GDP_value(reference_year_pos)./GDP_value;
            
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
        em_data.GDP_factor=GDP_factor(em_data.year-year0);
        
        % check growth correction:
        % plot(em_data.year,em_data.GDP_factor);hold on;plot(em_data.year,em_data.year*0+1,'-k')
        % set(gcf,'Color',[1 1 1]);title('growth correction');axis tight

    end % table missing
    
end % exposure_growth

% not necessarily min/max of em_data.year
em_data.first_year=EMDAT_first_year;
em_data.last_year=EMDAT_last_year;
em_data.emdat_file_mat=emdat_file_mat;

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
em_data.YDS.Value_unit=EMDAT_Value_unit;
em_data.YDS.currency_unit=1;
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
    list_items=unique(em_data.country_name);
    n_list_items=length(list_items);
    fprintf('\n%i countrie(s): (name as in file, ISO3 used for matching)\n',n_list_items);
    for item_i=1:n_list_items
        fprintf('  %s\n',list_items{item_i});
    end % item_i
    
    if isfield(em_data,'disaster_subtype')
        for elem_i=1:length(em_data.disaster_type)
            em_data.disaster_combitype{elem_i}=[em_data.disaster_type{elem_i} ' .. ' em_data.disaster_subtype{elem_i}];
        end
    else
        em_data.disaster_combitype=em_data.disaster_type;
    end
    
    list_items=unique(em_data.disaster_combitype);
    n_list_items=length(list_items);
    fprintf('\n%i disaster type(s) .. subtype(s):\n',n_list_items);
    for item_i=1:n_list_items
        fprintf('  %s\n',list_items{item_i});
    end % item_i
    
end
    
end % emdat_read