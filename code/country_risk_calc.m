function country_risk=country_risk_calc(country_name,method,force_recalc,check_plots)
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
%   next step: country_risk_report, see also country_admin1_risk_calc
% CALLING SEQUENCE:
%   country_risk=country_risk_calc(country_name,method,force_recalc,check_plots)
% EXAMPLE:
%   country_risk0=country_risk_calc('CHE',1,0); % 10x10km resolution for 
%       % Switzerland, using climada_nightlight_entity (not GDP_entity)
%   country_risk0=country_risk_calc('CHE',2,0); % 1x1km resolution for 
%       % Switzerland, using climada_nightlight_entity
%   country_risk0=country_risk_calc('CHE',3,0); % 10x10km resolution for 
%       % Switzerland, using GDP_entity
%   country_risk=country_risk_calc; % interactive, select country from dropdown
%   country_risk=country_risk_calc('ALL',1,0,0) % whole world, no figures
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
%       =3: use 10km nightlight (GDP_entity)
%       Since the code uses the entity (III_Name, with III Iso3 code and
%       Name the country name) if it exists already, the resolution only
%       matters on the first call, that's why we can use force_recalc to
%       direct resolution. For another entity resolution, delete or rename
%       the entity.
%       <0: all above options *(-1) trigger the generation of the full
%       probabilistic hazard sets (adding extension _p to the hazard
%       event sets)
%       internally: if method<0, probabilistic=1, =0 else (default)
%   force_recalc: if =1, recalculate the hazard sets, even if they exist
%       (good for TEST while editing the code, default=0)
%   check_plots: if =1, show figures to check hazards etc.
%       If =0, skip figures (default)
%       If country_name is set to 'ALL', be careful to set check_plots=1
% OUTPUTS:
%   writes a couple files, such as entities and hazard event sets (the
%       output to stdout lists all names)
%   country_risk(country_i): a structure with some risk information for
%       each country (if run eg with 'ALL'), see hazard(hazard_i).EDS
%       e.g. plot damage for one hazard in one country at each centroid with
%         climada_circle_plot(...
%          country_risk(country_i).res.hazard(hazard_i).EDS.ED_at_centroid,...
%          country_risk(country_i).res.hazard(hazard_i).EDS.assets.Longitude,...
%          country_risk(country_i).res.hazard(hazard_i).EDS.assets.Latitude)
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
%-

country_risk = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'), country_name = '';end
if ~exist('method','var'),       method       =  1;end % default=1
if ~exist('force_recalc','var'), force_recalc =  0;end
if ~exist('check_plots' ,'var'), check_plots  =  0;end

% check for module GDP_entity, as it otherwise fails anyway
if length(which('climada_create_GDP_entity'))<2 && method==3
    fprintf('ERROR: GDP_entity module not found. Pleaseforce_recalc download from github and install. \nhttps://github.com/davidnbresch/climada_module_GDP_entity\n');
    fprintf('> consider option force_recalc<0, e.g. country_risk=country_risk_calc(...,1,...)\n');
    return
end

% PARAMETERS
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
if method<0,probabilistic=1;method=abs(method);end


% some folder checks (to be on the safe side)
if ~exist(country_data_dir,'dir'),mkdir(fileparts(country_data_dir),'data');end
if ~exist([country_data_dir filesep 'system'],'dir'),mkdir(country_data_dir,'system');end
if ~exist([country_data_dir filesep 'entities'],'dir'),mkdir(country_data_dir,'entities');end
if ~exist([country_data_dir filesep 'hazards'],'dir'),mkdir(country_data_dir,'hazards');end

if isempty(country_name) % prompt for country (one or many) as list dialog
    country_name = climada_country_name('MULTIPLE');
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
        country_risk_out(country_i)=country_risk_calc(single_country_name,method,force_recalc,check_plots);
    end % country_i
    close all
    country_risk=country_risk_out;
    return
end

% from here on, only one country
country_name_char = char(country_name); % as to create filenames etc., needs to be char
[country_name_char,country_ISO3] = climada_country_name(country_name_char); % check name and ISO3

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

% 1) read the centroids
% =====================

if ( ~exist(centroids_file,'file') || ~exist(entity_file,'file') ) || force_recalc
    
    if method==1
        entity=climada_nightlight_entity(country_name_char,'',-1,0,[],'',0); % no save
    elseif method==2
        entity=climada_nightlight_entity(country_name_char,'', 1,0,[],'',0); % no save
    elseif method==3
        % invoke the GDP_entity module to generate centroids and entity
        [centroids,entity,entity_future] = climada_create_GDP_entity(country_name_char,[],0,1);
        if isempty(centroids), return, end
        save(centroids_file,'centroids');
        save(entity_file,'entity');
        entity = entity_future; %replace with entity future
        save(entity_future_file,'entity');
    else
        fprintf('%s: method=%i not implemented, aborted\n',mfilename,method);
        return
    end % method
    
    if ~exist('centroids','var')
        if isempty(entity),return,end
        % since climada_nightlight_entity only created the entity,
        % create centroids, too
        entity.assets.centroid_index=1:length(entity.assets.Longitude); % as we later construct the hazard accordingly
        save(entity_file,'entity');
        
        % get centroids from entity
        centroids.Latitude =entity.assets.Latitude;
        centroids.Longitude=entity.assets.Longitude;
        centroids.centroid_ID=1:length(centroids.Longitude);
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

if check_plots
    % visualize assets on map
    climada_plot_entity_assets(entity,centroids,country_name_char);
end % check_plots

% 2) figure which hazards affect the country
% 3) and generate the hazard event sets
% =================================
% centroids are the ones for the country, not visible in code sinde loaded
% above with load(centroids_file)
fprintf('--> calling centroids_generate_hazard_sets...\n');
country_risk=centroids_generate_hazard_sets(centroids,probabilistic,force_recalc,check_plots);
fprintf('<-- back from calling centroids_generate_hazard_sets\n');

country_risk.res.country_name = country_name_char;
country_risk.res.country_ISO3 = country_ISO3;

% 4) risk calculation
% ===================

if isfield(country_risk.res,'hazard')
    
    fprintf('*** risk calculations for %s\n',country_name_char);
    
    hazard_count=length(country_risk.res.hazard);
    
    for hazard_i=1:hazard_count
        
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
                    max_hazard_intensity=full(max(max(hazard.intensity)));
                    damagefunction_scale=max_hazard_intensity/max_damagefunction_intensity;
                    
                    entity.damagefunctions.Intensity = entity.damagefunctions.Intensity * damagefunction_scale;
                    fprintf(' (dummy damage)\n');
                    
                end
            else
                fprintf(' (default damage)\n');
            end % isfield 'peril_ID'
            
            country_risk.res.hazard(hazard_i).EDS=climada_EDS_calc(entity,hazard);
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

return
