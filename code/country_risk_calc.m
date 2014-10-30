function country_risk=country_risk_calc(country_name,probabilistic,force_recalc,check_plots)
% climada
% NAME:
%   country_risk_calc
% PURPOSE:
%   run all (available) perils for one country. I.e. generate earthquake (EQ),
%   tropical cyclone (TC), torrential rain (TR) and storm surge (TS) hazard 
%   event sets and run risk calculation for a given country
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
%   NOTE that centroids_generate_hazard_sets is called for steps 2 and 3
%
%   next step: country_risk_report
% CALLING SEQUENCE:
%   country_risk=country_risk_calc(country_name,probabilistic,force_recalc,check_plots)
% EXAMPLE:
%   country_risk=country_risk_calc; % interactive, select country from dropdown
%   country_risk=country_risk_calc('ALL',0,0,0) % whole world, no figures
% INPUTS:
%   country_name: name of the country, see climada_create_GDP_entity
%       if set to 'ALL', the code runs recursively through ALL countries
%       (mind the time this will take...)
%       > prompted for via dropdown list if empty
% OPTIONAL INPUT PARAMETERS:
%   probabilistic: if =1, generate probabilistic hazard event sets,
%       =0 generate 'historic' hazard event sets (default)
%       While one need fully probabilistic sets for really meaningful
%       results, the default is 'historic' as this is the first thing to
%       check.
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
% David N. Bresch, david.bresch@gmail.com, 20141025, major cleanup and EQ added
% David N. Bresch, david.bresch@gmail.com, 20141026, probabilistic as input
% David N. Bresch, david.bresch@gmail.com, 20141029, force_re_encoding
%-

country_risk = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'), country_name = '';end
if ~exist('probabilistic','var'), probabilistic = 0;end
if ~exist('force_recalc','var'), force_recalc = 0;end
if ~exist('check_plots' ,'var'), check_plots  = 0;end

module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% TEST_location to mark and lable one spot
% only makes sense if run for one country (not rot 'ALL')
%TEST_location.name      = '  San Salvador'; % first two spaces for nicer labeling
%TEST_location.longitude = -89+11/60+24/3600;
%TEST_location.latitude  =  13+41/60+24/3600;
TEST_location=''; % set TEST_location='' to omit labeling
%
% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' creates so many
% files, one might divert to e.g. a data folder structure within the
% module (see climada_init_folders to create the required folders automatically)
country_data_dir = climada_global.data_dir;
%country_data_dir = module_data_dir;
%
% Note that one would need to re-encode assets to each hazard prior to
% calling the damage calculation (as climada_EDS_calc assumes matching
% order for speedup), unless one knows that all hazard event sets are valid
% on the exact same centroids (the first n elements in the hazard are
% matching the n locations of the assets, while the n+1:end elements in
% hazard are the ones for the buffer around the country). The call to
% centroids_generate_hazard_sets ensures that, and hence no need for
% re-encoding (force_re_encoding=0)
force_re_encoding=0; % default=0

% some folder checks (to be on the safe side)
if ~exist(country_data_dir,'dir'),mkdir(fileparts(country_data_dir),'data');end
if ~exist([country_data_dir filesep 'system'],'dir'),mkdir(country_data_dir,'system');end
if ~exist([country_data_dir filesep 'entities'],'dir'),mkdir(country_data_dir,'entities');end
if ~exist([country_data_dir filesep 'hazards'],'dir'),mkdir(country_data_dir,'hazards');end


% prepare country list
borders = climada_load_world_borders;
if isempty(borders), fprintf('no map found\n'), return, end

% valid country names
valid_countries_indx = ~strcmp(borders.ISO3,'-');
valid_countries      = borders.name(valid_countries_indx);

if strcmp(country_name,'ALL')
    % call recursively
    [~, sort_index] = sort(valid_countries);
    %sort_index=sort_index([2 6 9 14 19 21 22 127 183 208]); % TEST subset
    for country_i = 1:length(sort_index)
        country_name = valid_countries(sort_index(country_i));
        fprintf('\nprocessing %s (%i of %i) ************************ \n',...
            char(country_name),country_i,length(sort_index));
        country_risk_out(country_i)=country_risk_calc(country_name,probabilistic,force_recalc,check_plots);
    end % country_i
    close all
    country_risk=country_risk_out;
    return
end

% ask for country or region
if isempty(country_name)
    country_name = climada_ask_country_name;
end
if isempty(country_name),return, end

%check that country_name is a cell
if ~iscell(country_name),country_name = {country_name};end

country_name_char         = char(country_name); % as to create filenames etc., needs to be char
country_risk.res.country_name = country_name_char;

% define easy to read filenames
centroids_file     = [country_data_dir filesep 'system'   filesep country_name_char '_centroids.mat'];
entity_file        = [country_data_dir filesep 'entities' filesep country_name_char '_entity.mat'];
entity_future_file = [country_data_dir filesep 'entities' filesep country_name_char '_entity_future.mat'];


% 1) read the centroids
% =====================

if ~exist(centroids_file,'file') || force_recalc
    % invoke the GDP_entity moduke to generate centroids and entity
    country_name_char_tmp=country_name_char;
    if strcmp(country_name_char,'Vietnam')   , country_name_char_tmp='Viet Nam';end
    if strcmp(country_name_char,'ElSalvador'), country_name_char_tmp='El Salvador';end
    [centroids, entity, entity_future] = climada_create_GDP_entity(country_name_char_tmp,[],0,1);
    save(centroids_file,'centroids');
    save(entity_file,'entity');
    entity = entity_future; %replace with entity future
    save(entity_future_file,'entity');
    if isempty(centroids), return, end
    
    if check_plots
        % visualize assets on map
        climada_plot_entity_assets(entity,centroids,country_name_char);
    end
else
    load(centroids_file) % load centroids
end

if isempty(centroids)
    fprintf('ERROR: %s no centroids\n',country_name_char);
    return
end

% 2) figure which hazards affect the country
% 3) Generate the hazard event sets
% =================================
% centroids are the ones for the country, not visible in code sinde loaded
% above with load(centroids_file)
fprintf('--> calling centroids_generate_hazard_sets...\n');
country_risk=centroids_generate_hazard_sets(centroids,probabilistic,force_recalc,check_plots);
fprintf('<-- back from calling centroids_generate_hazard_sets\n');

% 4) risk calculation
% ===================

if isfield(country_risk.res,'hazard')
    
    fprintf('*** risk calculations for %s\n',country_name_char);

    hazard_count=length(country_risk.res.hazard);
    
    for hazard_i=1:hazard_count
        
        load(entity_file) % load entity
        load(country_risk.res.hazard(hazard_i).hazard_set_file)
        [~,hazard_name]=fileparts(country_risk.res.hazard(hazard_i).hazard_set_file);
        
        fprintf('* hazard %s %s\n',hazard.peril_ID,hazard_name);
        
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
        
        if ~isempty(hazard)
            
            % DUMMY DAMAGE FUNCTIONS FOR TESTS (HERE WE ARE)
            % just match max scale of hazard.intensity to max
            % damagefunction.intensity
            max_damagefunction_intensity=max(entity.damagefunctions.Intensity);
            max_hazard_intensity=full(max(max(hazard.intensity)));
            damagefunction_scale=max_hazard_intensity/max_damagefunction_intensity;
            
            %         % a suggestion for hard-wired for comparison would be
            %         if strcmp(country_risk.res.hazard(3).peril_ID,'TS')
            %             damagefunction_scale=5;
            %         elseif strcmp(country_risk.res.hazard(3).peril_ID,'TR')
            %             damagefunction_scale=500;
            %         elseif strcmp(country_risk.res.hazard(3).peril_ID,'EQ')
            %             damagefunction_scale=100;
            %         end
            
            entity.damagefunctions.Intensity = entity.damagefunctions.Intensity * damagefunction_scale;
            
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
