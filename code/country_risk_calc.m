function country_risk=country_risk_calc(country_name,method,force_recalc,check_plots,peril_ID,damagefunctions)
% climada
% MODULE:
%   country_risk
% NAME:
%   country_risk_calc
% PURPOSE:
%   run all (available) perils for one country. I.e. generate earthquake (EQ),
%   tropical cyclone (TC), torrential rain (TR), storm surge (TS) and
%   European winter storm (WS) hazard event sets and run risk calculation
%   for a given country:
%   1) generate centroids for the country (uses climada_create_GDP_entity)
%   2) figure which hazards affect the country
%   3) create the hazard event sets, uses
%      - climada_tc_hazard_set (wind)
%      - climada_tr_hazard_set (rain)
%      - climada_ts_hazard_set (surge)
%      - eq_global_hazard_set (earthquake)
%      - European winter storms (existing European hazard set)
%   4) run the risk calculation for all hazards
%
%   NOTE that centroids_generate_hazard_sets is called for steps 2 and 3.
%   Note further that should there be more than one source for TC tracks,
%   more than one TC hazard set is generated (see centroids_generate_hazard_sets)
%
%   next step: country_risk_report, see also country_admin1_risk_calc and
%   esepcially country_risk_calibrate, plus cr_DFC_plot and cr_DFC_plot_aggregate
% CALLING SEQUENCE:
%   country_risk=country_risk_calc(country_name,method,force_recalc,check_plots,peril_ID)
% EXAMPLE:
%   country_risk0=country_risk_calc('CHE',1,0); % 10x10km resolution for
%       % Switzerland, using climada_nightlight_entity (not GDP_entity)
%   country_risk0=country_risk_calc('CHE',2,0); % 1x1km resolution for
%       % Switzerland, using climada_nightlight_entity
%   country_risk0=country_risk_calc('CHE',3,0); % 10x10km resolution for
%       % Switzerland, using GDP_entity
%   country_risk=country_risk_calc; % interactive, select country from dropdown
%   country_risk=country_risk_calc('ALL',1,0,0) % whole world, no figures
%   country_risk=country_risk_calc(country_name,-7,0,0,['atl_TC';'atl_TS']) % both TC and TS for atl
% INPUTS:
%   country_name: name of the country, like 'Switzerland', or a list of
%       countries, like {'Switzerland','Germany','France'}. See
%       climada_check_country_name for the list of valid country names
%       If set to 'ALL', the code runs recursively through ALL countries
%       (mind the time this will take...)
%       > prompted for via dropdown list if empty (allows for single or
%       multiple country selection)
% OPTIONAL INPUT PARAMETERS:
%   method: =1: use 10km nightlight (climada_nightlight_entity, default)
%       =2: use 1km nightlight (climada_nightlight_entity)
%       =3: use 10km nightlight (GDP_entity). In this case, USA is
%           restricted to contiguous US excl. Alaska and NZL only West of dateline.
%
%       Since the code uses the entity (III_Name, with III Iso3 code and
%       Name the country name) if it exists already, the resolution only
%       matters on the first call, that's why we can use force_recalc to
%       direct resolution. For another entity resolution, delete or rename
%       the entity.
%
%       <0: all above options *(-1) trigger the generation of the full
%       probabilistic hazard sets (otherwise _hist is added to the hazard
%       event sets) 
%       =7 (for historic, or -7 to use probabilistic sets): skip entity and
%       hazard set generation, straight to damage calculations (this allows
%       to avoid any re-generation of - missing - hazard event sets, the
%       code just takes what's there). In this case, peril_ID can contain
%       the peril region, too, i.e. 'atl_TC' or 'glb_EQ' and peril_ID can
%       be a list of IDs, such as peril_ID=['atl_TC';'atl_TS'].
%
%       Internally: if method<0, probabilistic=1, =0 else (default)
%       =sign(.)*(abs(.)+100): use future entities, e.g. -107 uses
%       future entity, and probabilistic hazards, but skips entity and
%       hazard calculation.
%       If method has two elements, the second one triggers
%       EDS_emdat_adjust, i.e. if method(2)=1, we adjust the EDS by
%       comparison with EM-DAT, see cr_EDS_emdat_adjust
%   force_recalc: if =1, recalculate the hazard sets, even if they exist
%       (good for TEST while editing the code, default=0)
%   check_plots: if =1, show figures to check hazards etc.
%       If =0, skip figures (default)
%       If country_name is set to 'ALL', be careful to set check_plots=1
%   peril_ID: if passed on, run all calculations only for specified peril
%       peril_ID can be 'TC','TS','TR','EQ','WS'..., default='' for all
%       Once generated, one can also specify the peril region within
%       peril_ID, such as 'atl_TC'. If method=+/-7, peril_ID can also
%       contain a list, e.g. peril_ID=['atl_TC';'atl_TS';'EQ']
%   damagefunctions: if passed, use damagefunctions instead of the one that
%       comes with the entity (or entities). Replaces entity.damagefunctiuons 
%       without any further tests. The user is responsible for not messing
%       up, i.e. for entity.assets.DamageFunID to point to the right damage
%       function, damagefunctions.peril_ID to be consistent with e.g. input
%       parameter peril_ID etc.
% OUTPUTS:
%   writes a couple files, such as entities and hazard event sets (the
%       output to stdout lists all names)
%   country_risk(country_i): a structure with some risk information for
%       each country (if run eg with 'ALL'), see hazard(hazard_i).EDS
%       e.g. plot damage for one hazard in one country at each centroid with
%         climada_circle_plot(...
%          country_risk(country_i).res.hazard(hazard_i).EDS.ED_at_centroid,...
%          country_risk(country_i).res.hazard(hazard_i).EDS.assets.lon,...
%          country_risk(country_i).res.hazard(hazard_i).EDS.assets.lat)
%       see country_risk_report to create a readable report to stdout
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20140831, initial
% David N. Bresch, david.bresch@gmail.com, 20140922, three hazards: TC,TS,TR
% David N. Bresch, david.bresch@gmail.com, 20141020, ready for checkin
% David N. Bresch, david.bresch@gmail.com, 20141025, major cleanup, WS and EQ added
% David N. Bresch, david.bresch@gmail.com, 20141026, probabilistic as input
% David N. Bresch, david.bresch@gmail.com, 20141029, force_re_encoding
% David N. Bresch, david.bresch@gmail.com, 20141103, matching peril_ID for damagefunction added
% David N. Bresch, david.bresch@gmail.com, 20141107, add ncetCFD tc_track file treatment (NCAR) (on flight to Dubai)
% David N. Bresch, david.bresch@gmail.com, 20141126, country list enabled and multiple selection added
% David N. Bresch, david.bresch@gmail.com, 20141222, method parameter simplified (replaces and includes probabilistic)
% David N. Bresch, david.bresch@gmail.com, 20150112, climada_hazard2octave
% David N. Bresch, david.bresch@gmail.com, 20150121, method=7 added
% David N. Bresch, david.bresch@gmail.com, 20150123, distance2coast_km added
% David N. Bresch, david.bresch@gmail.com, 20150213, peril_ID to contain region and multiple perils enabled (if method=+/-7)
%-

country_risk = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'),    country_name =    '';end
if ~exist('method','var'),          method       =     1;end % default=1
if ~exist('force_recalc','var'),    force_recalc =     0;end
if ~exist('check_plots' ,'var'),    check_plots  =     0;end
if ~exist('peril_ID' ,'var'),       peril_ID     =    '';end
if ~exist('damagefunctions' ,'var'),damagefunctions = [];end

% check for module GDP_entity, as it otherwise fails anyway
if length(which('climada_create_GDP_entity'))<2 && method==3
    fprintf('ERROR: GDP_entity module not found. Pleaseforce_recalc download from github and install. \nhttps://github.com/davidnbresch/climada_module_GDP_entity\n');
    fprintf('> consider option force_recalc<0, e.g. country_risk=country_risk_calc(...,1,...)\n');
    return
end

% PARAMETERS
%
% whether we automatically adjust to EM-DAT (where available)
EDS_emdat_adjust=0; % default=0, see method(2)
%
% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' creates so many
% files, one might divert to e.g. a data folder structure within the
% module
country_data_dir = climada_global.data_dir; % default
%country_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data']; % to store within module
%
% Note that one would need to re-encode assets to each hazard prior to
% calling the damage calculation (as climada_EDS_calc assumes matching
% order for speedup), unless one knows that all hazard event sets are valid
% on the exact same centroids (the first n elements in the hazard are
% matching the n locations of the assets, while the n+1:end elements in
% hazard are the ones for the buffer around the country). The call to
% centroids_generate_hazard_sets ensures that, and hence no need for
% re-encoding (force_re_encoding=0). But in case you're in doubt, set
% force_re_encoding=1 and check whether you get the same results (if yes,
% very likely no need for force_re_encoding=1, otherwise keep =1).
force_re_encoding=0; % default=0
%
probabilistic=0; % default

% process method (it has complex meaning ;-)
orig_method=method;
%
if size(method)>1,EDS_emdat_adjust=method(2);method=method(1);end
if method<0,probabilistic=1;method=abs(method);end
use_future_entity=0; % we use entity today by default
if method>100,method=method-100;use_future_entity=1;end % indicates to use entity_future


% some folder checks (to be on the safe side)
if ~exist(country_data_dir,'dir'),mkdir(fileparts(country_data_dir),'data');end
if ~exist([country_data_dir filesep 'system'],'dir'),mkdir(country_data_dir,'system');end
if ~exist([country_data_dir filesep 'entities'],'dir'),mkdir(country_data_dir,'entities');end
if ~exist([country_data_dir filesep 'hazards'],'dir'),mkdir(country_data_dir,'hazards');end

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
        fprintf('\nprocessing %s (%i of %i) ************************ \n',...
            char(single_country_name),country_i,n_countries);
        country_risk_out(country_i)=country_risk_calc(single_country_name,orig_method,force_recalc,check_plots,peril_ID,damagefunctions);
    end % country_i
    close all
    country_risk=country_risk_out;
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
country_risk.res.country_name = country_name_char;
country_risk.res.country_ISO3 = country_ISO3;

% to test countries, uncomment following few lines
% country_name_char
% country_ISO3
% return

if isempty(country_name_char),return;end % invalid country name

% define easy to read filenames
centroids_file     = [country_data_dir filesep 'system'   filesep country_ISO3 '_' strrep(country_name_char,' ','') '_centroids.mat'];
entity_file        = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
entity_future_file = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity_future.mat'];

if method<7 % if method>=6, skip entity and hazard generation alltogether
    
    % 1) read the centroids
    % =====================
    
    if ( ~exist(centroids_file,'file') || ~exist(entity_file,'file') ) || force_recalc
        
        if method==1
            entity=climada_nightlight_entity(country_name_char,'',[-1 1],0,[],'',0); % no save
        elseif method==2
            entity=climada_nightlight_entity(country_name_char,'',[ 1 1],0,[],'',0); % no save
        elseif method==3
            % invoke the GDP_entity module to generate centroids and entity
            [centroids,entity,entity_future] = climada_create_GDP_entity(country_name_char,[],0,1);
            if isempty(centroids), return, end
            centroids.distance2coast_km=climada_distance2coast_km(centroids.lon,centroids.lat);
            save(centroids_file,'centroids');
            save(entity_file,'entity');
            climada_entity_value_GDP_adjust(entity_file); % adjust GDP
            entity = entity_future; %replace with entity future
            save(entity_future_file,'entity');
            climada_entity_value_GDP_adjust(entity_future_file); % adjust GDP
            if strcmp(country_ISO3,'USA'),LOCAL_USA_UnitedStates_entity_treatment;end
            if strcmp(country_ISO3,'NZL'),LOCAL_NZL_NewZealand_entity_treatment;end
        else
            fprintf('%s: method=%i not implemented, aborted\n',mfilename,method);
            return
        end % method
        
        if ~exist('centroids','var')
            if isempty(entity),return,end
            % since climada_nightlight_entity only created the entity,
            % create centroids, too
            entity.assets.centroid_index=1:length(entity.assets.lon); % as we later construct the hazard accordingly
            save(entity_file,'entity');
            
            % get centroids from entity
            centroids.lat=entity.assets.lat;
            centroids.lon=entity.assets.lon;
            centroids.centroid_ID=1:length(centroids.lon);
            if isfield(entity.assets,'country_name'),centroids.country_name=entity.assets.country_name;end
            if isfield(entity.assets,'admin0_name'),centroids.admin0_name=entity.assets.admin0_name;end
            if isfield(entity.assets,'admin0_ISO3'),centroids.admin0_ISO3=entity.assets.admin0_ISO3;end
            if isfield(entity.assets,'admin1_name'),centroids.admin1_name=entity.assets.admin1_name;end
            if isfield(entity.assets,'admin1_code'),centroids.admin1_code=entity.assets.admin1_code;end
            if isfield(entity.assets,'distance2coast_km'),centroids.distance2coast_km=entity.assets.distance2coast_km;end
            if isfield(entity.assets,'elevation_m'),centroids.elevation_m=entity.assets.elevation_m;end
            save(centroids_file,'centroids');
        end
    else
        load(centroids_file)
    end % entity or centroids not exist
    
    if isempty(centroids)
        fprintf('ERROR: %s no centroids\n',country_name_char);
        return
    end
    
    if ~isfield(centroids,'distance2coast_km')
        % it takes a bit of time to calculate
        % climada_distance2coast_km, but the windfield calcuklation is
        % much faster that way (see climada_tc_windfield)
        centroids.distance2coast_km=climada_distance2coast_km(centroids.lon,centroids.lat);
        save(centroids_file,'centroids'); % save centrois with field distance2coast_km
    end
    
    if check_plots
        % visualize assets on map
        climada_plot_entity_assets(entity,centroids,country_name_char);
    end % check_plots
    
    if size(peril_ID,1)>1 % we allow one peril here
        fprintf('Error: more than one peril_ID only allowed for method=+/-7, aborted\n');
        return
    end

    % 2) figure which hazards affect the country
    % 3) and generate the hazard event sets
    % =================================
    % centroids are the ones for the country, not visible in code sinde loaded
    % above with load(centroids_file)
    fprintf('--> calling centroids_generate_hazard_sets...\n');
    country_risk=centroids_generate_hazard_sets(centroids,probabilistic,force_recalc,check_plots,peril_ID);
    fprintf('<-- back from calling centroids_generate_hazard_sets\n');
    
else
    
    % no hazard set generation, just detecting existing hazard event sets
    % and then running damage calculations
    
    % figure the existing hazard set files (same procedure as in
    % country_admin1_risk_calc)
    probabilistic_str='_hist';if probabilistic,probabilistic_str='';end
    hazard_dir=[country_data_dir filesep 'hazards'];
    hazard_files=dir([hazard_dir filesep country_ISO3 '_' ...
        strrep(country_name_char,' ','') '*' probabilistic_str '.mat']);
        
    % first, filter probabilistic/historic
    valid_hazard=1:length(hazard_files); % assume all valid, the restrict
    for hazard_i=1:length(hazard_files)
        if probabilistic && ~isempty(strfind(hazard_files(hazard_i).name,'_hist.mat'))
            % filter, depending on probabilistic
            valid_hazard(hazard_i)=0;
        end
    end % hazard_i
    valid_hazard=valid_hazard(valid_hazard>0);
    hazard_files=hazard_files(valid_hazard);
    
    
    if ~isempty(peril_ID)
        % second, filter requested hazards (and possibly regions)
        valid_hazard=[]; % only pick the needed ones
        % filter for peril
        for peril_i=1:size(peril_ID,1) % we allow for more than one peril here
            one_peril_ID=peril_ID(peril_i,:);
            for hazard_i=1:length(hazard_files)
                if ~isempty(strfind(hazard_files(hazard_i).name,['_' one_peril_ID]))
                    % filter, depending on peril_ID
                    valid_hazard(end+1)=hazard_i;
                end
            end % hazard_i
        end % peril_i
        
        if isempty(valid_hazard)
            fprintf('Error: no hazards found, run with another method than +/-7\n')
            return
        else
            hazard_files=hazard_files(valid_hazard);
        end
        
    end % ~isempty(peril_ID)
    
    
    % store explicit hazard event set files with path (to use load)
    for hazard_i=1:length(hazard_files)
        country_risk.res.hazard(hazard_i).hazard_set_file=[hazard_dir filesep hazard_files(hazard_i).name];
    end % hazard_i
    
end % method<7, if method>=6, skip entity and hazard generation alltogether

country_risk.res.country_name = country_name_char;
country_risk.res.country_ISO3 = country_ISO3;

% 4) risk calculation
% ===================

if use_future_entity
    entity_file=entity_future_file;
    fprintf('FUTURE calculations instead of today\n');
end

if isfield(country_risk.res,'hazard')
    
    fprintf('*** risk calculations for %s\n',country_name_char);
    
    hazard_count=length(country_risk.res.hazard);
    
    for hazard_i=1:hazard_count
        
        country_risk.res.hazard(hazard_i).entity_file=entity_file; % store each time
        load(entity_file) % load entity
        
        hazard=[]; % init
        [~,hazard_name]=fileparts(country_risk.res.hazard(hazard_i).hazard_set_file);
        
        if exist(country_risk.res.hazard(hazard_i).hazard_set_file,'file')
                        
            load(country_risk.res.hazard(hazard_i).hazard_set_file)              
            
            % Note that one would need to re-encode assets to each hazard,
            % unless one knows that all hazard event sets are valid on the
            % exact same centroids (the first n elements in the hazard
            % are matching the n locations of the assets, while the n+1:end
            % elements in hazard are the ones for the buffer around the
            % country. The call to centroids_generate_hazard_sets ensures that,
            % and hence the following code bit is usually not necessary:
            if force_re_encoding
                fprintf('re-encoding hazard to the respective centroids\n');
                assets = climada_assets_encode(entity.assets,hazard);
                entity=rmfield(entity,'assets');
                entity.assets=assets; % assign re-encoded assets
            end
        end
        
        if ~isempty(hazard)
                        
            fprintf('* hazard %s %s',hazard.peril_ID,hazard_name);
            
            country_risk.res.hazard(hazard_i).peril_ID=hazard.peril_ID;
            
            if ~isempty(damagefunctions)
                fprintf(' damagefunctions replaced ');
                entity.damagefunctions=damagefunctions;
            end
            
            % find the damagefunctions for the peril under consideration
            if isfield(entity.damagefunctions,'peril_ID') % refine for peril
                if sum(strcmp(entity.damagefunctions.peril_ID,hazard.peril_ID(1:2)))>0
                    % peril_ID found, reasonable damage calculation
                    fprintf('\n');
                else
                    
                    % find the TC damagefunction (to start from)
                    asset_damfun_pos = find(entity.damagefunctions.DamageFunID == entity.assets.DamageFunID(1)); % keep it simple (1)
                    asset_damfun_pos = asset_damfun_pos(strcmp(entity.damagefunctions.peril_ID(asset_damfun_pos),'TC')); % use TC
                    
                    entity.damagefunctions.DamageFunID=entity.damagefunctions.DamageFunID(asset_damfun_pos);
                    entity.damagefunctions.Intensity=entity.damagefunctions.Intensity(asset_damfun_pos);
                    entity.damagefunctions.MDD=entity.damagefunctions.MDD(asset_damfun_pos);
                    entity.damagefunctions.PAA=entity.damagefunctions.PAA(asset_damfun_pos);
                    
                    entity.damagefunctions=rmfield(entity.damagefunctions,'peril_ID'); % get rid of the peril_ID
                    
                    % DUMMY DAMAGE FUNCTIONS FOR TESTS
                    % just match max scale of hazard.intensity to max
                    % damagefunction.intensity
                    max_damagefunction_intensity=max(entity.damagefunctions.Intensity);
                    
                    hazard=climada_hazard2octave(hazard); % Octave compatibility for -v7.3 mat-files
                    max_hazard_intensity=full(max(max(hazard.intensity)));
                    
                    damagefunction_scale=max_hazard_intensity/max_damagefunction_intensity;
                    entity.damagefunctions.Intensity = entity.damagefunctions.Intensity * damagefunction_scale;
                    fprintf(' (dummy damage)\n');
                    
                end
            else
                fprintf(' (default damage)\n');
            end % isfield 'peril_ID'
            
            country_risk.res.hazard(hazard_i).EDS=climada_EDS_calc(entity,hazard);
            
            if EDS_emdat_adjust
                country_risk.res.hazard(hazard_i).EDS=...
                    cr_EDS_emdat_adjust(country_risk.res.hazard(hazard_i).EDS,1);
            end
            
        else
            fprintf('WARNING: %s hazard is empty, skipped\n',hazard_name)
        end
        
    end % hazard_i
    
    % show all damage frequency curves
    
    if check_plots
        for hazard_i=1:length(country_risk.res.hazard) % convert into one EDS
            EDS(hazard_i)=country_risk.res.hazard(hazard_i).EDS;
        end
        climada_EDS_DFC(EDS);
    end
    
end % isfield(country_risk.res,'hazard')

end % country_risk_calc


% local HELPER functions

function LOCAL_USA_UnitedStates_entity_treatment
% special treatent for USA (restrict to contiguous US excl. Alaska)
global climada_global
fprintf('USA UnitedStates, restricting to contiguous US\n');
centroids_file    =[climada_global.data_dir filesep 'system'   filesep 'USA_UnitedStates_centroids.mat'];
entity_file       =[climada_global.data_dir filesep 'entities' filesep 'USA_UnitedStates_entity.mat'];
entity_future_file=[climada_global.data_dir filesep 'entities' filesep 'USA_UnitedStates_entity_future.mat'];

for entity_i=1:2
    if entity_i==2,entity_file=entity_future_file;end % ugly but pragmatic
    load(entity_file) % contains entity
    pos=find(entity.assets.lon>-130 & entity.assets.lat<50);
    entity.assets.centroid_index=entity.assets.centroid_index(pos);
    entity.assets.lon=entity.assets.lon(pos);
    entity.assets.lat=entity.assets.lat(pos);
    entity.assets.Value=entity.assets.Value(pos);
    if isfield(entity.assets,'Value_today'),entity.assets.Value_today=entity.assets.Value_today(pos);end
    if isfield(entity.assets,'distance2coast_km'),entity.assets.distance2coast_km=entity.assets.distance2coast_km(pos);end
    entity.assets.Deductible=entity.assets.Deductible(pos);
    entity.assets.Cover=entity.assets.Cover(pos);
    entity.assets.DamageFunID=entity.assets.DamageFunID(pos);
    save(entity_file,'entity') % write back
    climada_entity_value_GDP_adjust(entity_file); % assets based on GDP
end % entity_i

load(centroids_file) % contains centroids
pos=find(centroids.lon>-130 & centroids.lat<50);
centroids.lon=centroids.lon(pos);
centroids.lat=centroids.lat(pos);
centroids.centroid_ID=centroids.centroid_ID(pos);
if isfield(centroids,'onLand'),centroids.onLand=centroids.onLand(pos);end
if isfield(centroids,'distance2coast_km'),centroids.distance2coast_km=centroids.distance2coast_km(pos);end
centroids=rmfield(centroids,'country_name');
save(centroids_file,'centroids');
end % LOCAL_USA_UnitedStates_entity_treatment


function LOCAL_NZL_NewZealand_entity_treatment
% special treatent for NZL (date line issue, restrict to West of dateline)
global climada_global

fprintf('NZL_ NewZealand, resolving date line issue\n');
centroids_file    =[climada_global.data_dir filesep 'system'   filesep 'NZL_NewZealand_centroids.mat'];
entity_file       =[climada_global.data_dir filesep 'entities' filesep 'NZL_NewZealand_entity.mat'];
entity_future_file=[climada_global.data_dir filesep 'entities' filesep 'NZL_NewZealand_entity_future.mat'];

for entity_i=1:2
    if entity_i==2,entity_file=entity_future_file;end % ugly but pragmatic
    load(entity_file) % contains entity
    pos=find(entity.assets.lon>150);
    entity.assets.centroid_index=entity.assets.centroid_index(pos);
    entity.assets.lon=entity.assets.lon(pos);
    entity.assets.lat=entity.assets.lat(pos);
    entity.assets.Value=entity.assets.Value(pos);
    if isfield(entity.assets,'Value_today'),entity.assets.Value_today=entity.assets.Value_today(pos);end
    if isfield(entity.assets,'distance2coast_km'),entity.assets.distance2coast_km=entity.assets.distance2coast_km(pos);end
    entity.assets.Deductible=entity.assets.Deductible(pos);
    entity.assets.Cover=entity.assets.Cover(pos);
    entity.assets.DamageFunID=entity.assets.DamageFunID(pos);
    save(entity_file,'entity') % write back
    climada_entity_value_GDP_adjust(entity_file); % assets based on GDP
end % entity_i

load(centroids_file) % contains centroids
pos=find(centroids.lon>150);
centroids.lon=centroids.lon(pos);
centroids.lat=centroids.lat(pos);
centroids.centroid_ID=centroids.centroid_ID(pos);
if isfield(centroids,'onLand'),centroids.onLand=centroids.onLand(pos);end
if isfield(centroids,'distance2coast_km'),centroids.distance2coast_km=centroids.distance2coast_km(pos);end
centroids=rmfield(centroids,'country_name');
save(centroids_file,'centroids');
end % LOCAL_NZL_NewZealand_entity_treatment