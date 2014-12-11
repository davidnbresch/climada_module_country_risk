function centroids_hazard_info=centroids_generate_hazard_sets(centroids,probabilistic,force_recalc,check_plots)
% climada
% NAME:
%   centroids_generate_hazard_sets
% PURPOSE:
%   run all (available) perils for a given set of centroids. Generate earthquake (EQ),
%   tropical cyclone (TC), torrential rain (TR) and storm surge (TS) hazard event sets
%   1) figure which hazards affect the centroids
%   2) create the hazard event sets, uses
%      - climada_tc_hazard_set (wind)
%      - climada_tr_hazard_set (rain)
%      - climada_ts_hazard_set (surge)
%      - eq_global_hazard_set (earthquake)
%      - European winter storm module (existing hazard)
%
%   Note that the code supports both TC tracks from unisys database files
%   and (NCAR) netCDF TC track files. Should both exist in the active
%   ..\data\tc_tracks folder, the user NEEDS to 'hide' the ones not needed
%   (e.g. by moving them into a temporary subfolder). Otherwise, the code
%   produces two hazard event sets (which might be intended).
%
%   Please not further that the WS_Europe hazard event set is defined in
%   PARAMETERS, as this is not freshly generated, but the country hazard
%   event set is just a subset (see also climada module ws_europe)
%
%   previous step: country_risk_calc or climada_create_GDP_entity
%   next step: see country_risk_calc (if you start with your own centroids,
%   you might rather calculate the risk yourself, e.g. using
%   climada_EDS_calc...)
% CALLING SEQUENCE:
%   centroids_hazard_info=centroids_generate_hazard_sets(centroids,probabilistic,force_recalc,check_plots)
% EXAMPLE:
%   centroids_generate_hazard_sets; % interactive, prompt for centroids
% INPUTS:
%   centroids: a centroid structure, see e.g. climada_centroids_load
%       or an entity (in which case it takes the entity.assets.Latitude and
%       entity.assets.Longitude)
%       > prompted for if empty (centroids need to exist als .mat file
%       already - otherwise run e.g. climada_centroids_read first). 
%       In case you select an entity, it takes entity.assets.Latitude and
%       entity.assets.Longitude.   
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
% OUTPUTS:
%   writes hazard event set files
%   centroids_hazard_info(centroids_i): a structure with hazard information for
%       each set of centroids. See centroids_hazard_info.res.hazard with
%       peril_ID: 'TC' or ...
%       raw_data_file: for TC only: the file sused to generste the event set
%       hazard_set_file: the full filename of the hazard set generated
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141025, moved out of country_risk_calc
% David N. Bresch, david.bresch@gmail.com, 20141026, probabilistic as input
% David N. Bresch, david.bresch@gmail.com, 20141029, WSEU added
% David N. Bresch, david.bresch@gmail.com, 20141208, possibility to pass entity as centroids
%-

centroids_hazard_info = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('centroids','var'),     centroids = '';   end
if ~exist('probabilistic','var'), probabilistic = 0;end
if ~exist('force_recalc','var'),  force_recalc = 0; end
if ~exist('check_plots' ,'var'),  check_plots  = 0; end

module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% TEST_location to mark and lable one spot
%TEST_location.name      = '  San Salvador'; % first two spaces for nicer labeling
%TEST_location.longitude = -89+11/60+24/3600;
%TEST_location.latitude  =  13+41/60+24/3600;
TEST_location=''; % set TEST_location='' to omit labeling
%
% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' creates so many
% files, one might divert to e.g. a data folder structure within the
% module (see climada_init_folders to create the required folders automatically)
local_data_dir = climada_global.data_dir;
%local_data_dir = module_data_dir;
%
% define the WS Europe hazard event set we test for (see module ws_europe)
WS_Europe_hazard_set_file='WS_Europe.mat'; % with .mat
%WS_Europe_hazard_set_file='WS_ERA40.mat'; % until 20141201
%WS_Europe_hazard_set_file='WS_ECHAM_CTL.mat'; % until 20141126
%
% whether we create a single WS Europe country hazard event set for each WS
% Europe exposed country (speedup in risk calc, since centroids ordered the
% exact same way as hazard intensities, if =1). If =0, use the same
% Europe-wide hazard event set for all exposed countries, which requires
% re-encoding in risk calc each time (see country_risk calc and set
% force_re_encoding=1 in the Parameter section in the code).
WS_Europe_country_hazard_set=1; % default=1 (mainly for speedup)

% some folder checks (to be on the safe side)
if ~exist(local_data_dir,'dir'),mkdir(fileparts(local_data_dir),'data');end
if ~exist([local_data_dir filesep 'system'],'dir'),mkdir(local_data_dir,'system');end
if ~exist([local_data_dir filesep 'entities'],'dir'),mkdir(local_data_dir,'entities');end
if ~exist([local_data_dir filesep 'hazards'],'dir'),mkdir(local_data_dir,'hazards');end

% prompt for centroids if not given

if isempty(centroids) % local GUI
    centroids_file=[climada_global.data_dir filesep 'system' filesep '*.mat'];
    [filename, pathname] = uigetfile(centroids_file, 'Select centroids (or an entity):');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        centroids_file=fullfile(pathname,filename);
    end
    load(centroids_file); % loads either centroids or entity
    if exist('entity','var'),centroids=entity;end % centroids_file contains an entity, see below
    if isempty(centroids),return;end % neither centroids nor entity loaded
end

if isfield(centroids,'assets') % centroids contains in fact an entity
    entity=centroids; centroids=[]; % silly switch, but fastest
    centroids.Latitude =entity.assets.Latitude;
    centroids.Longitude=entity.assets.Longitude;
    if isfield(entity.assets,'country_name'),centroids.country_name{1}=entity.assets.country_name;end
    if isfield(entity.assets,'admin0_name'),centroids.admin0_name{1}=entity.assets.admin0_name;end
    if isfield(entity.assets,'admin1_name'),centroids.admin1_name{1}=entity.assets.admin1_name;end
    clear entity
end

if isfield(centroids,'country_name') % usually the case
    country_name_char=char(centroids.country_name{1});
elseif isfield(centroids,'admin0_name') % another name for the field
    country_name_char=char(centroids.admin0_name{1});
else
    country_name_char='centroids'; % just to keep going
end
if isfield(centroids,'admin1_name') % append, if it exists
    country_name_char=[country_name_char char(centroids.admin1{1})];
end
country_name_char=strrep(strrep(country_name_char,' ',''),' ',''); % remove inner blanks
country_name_char=strrep(country_name_char,'(','');
country_name_char=strrep(country_name_char,')','');
country_name_char=strrep(country_name_char,'-','');
country_name_char=strrep(country_name_char,'_','');

% 1) figure which hazards affect the country
% ==========================================

% prep the region we need
centroids_rect = [min(centroids.Longitude) max(centroids.Longitude) min(centroids.Latitude) max(centroids.Latitude)];
centroids_edges_x = [centroids_rect(1),centroids_rect(1),centroids_rect(2),centroids_rect(2),centroids_rect(1)];
centroids_edges_y = [centroids_rect(3),centroids_rect(4),centroids_rect(4),centroids_rect(3),centroids_rect(3)];

% TC, TS, TR: figure which ocean basin(s) to use for the particular country
% -------------------------------------------------------------------------

tc_tracks_folder=[local_data_dir filesep 'tc_tracks'];
if ~exist(tc_tracks_folder,'dir'),mkdir(local_data_dir,'tc_tracks');end
if ~exist([tc_tracks_folder filesep 'tracks.atl.txt'],'file') % check for first
    % get all TC tracks from www
    climada_tc_get_unisys_databases(tc_tracks_folder);
end

hazard_count = 0; % init

fprintf('*** hazard detection (%s)\n',country_name_char);

D = dir(tc_tracks_folder); % get content
for file_i=1:length(D)
    if ~D(file_i).isdir
        raw_data_file_temp=D(file_i).name;
        [~,~,fE]=fileparts(raw_data_file_temp);
        if (strcmp(fE,'.txt') || strcmp(fE,'.nc')) && isempty(strfind(raw_data_file_temp,'TEST'))
            
            tc_track_nodes_file=strrep([tc_tracks_folder filesep raw_data_file_temp],fE,'_nodes.mat');
                        
            if ~climada_check_matfile([tc_tracks_folder filesep raw_data_file_temp],tc_track_nodes_file)
                if  (strcmp(fE,'.txt'))
                    % read tracks from unisys database file
                    tc_track = climada_tc_read_unisys_database([tc_tracks_folder filesep raw_data_file_temp]);
                elseif  (strcmp(fE,'.nc'))
                    % read tracks from (NCAR) netCDF file
                    tc_track=climada_tc_read_cam_ibtrac_v02([tc_tracks_folder filesep raw_data_file_temp]);                
                else
                    fprintf('*** ERROR generating tc_track nodes file: %s\n',tc_track_nodes_file);
                end
                tc_track_nodes.lon=[];
                tc_track_nodes.lat=[];
                fprintf('collecting all nodes for %i TC tracks\n',length(tc_track));
                for track_i=1:length(tc_track)
                    tc_track_nodes.lon=[tc_track_nodes.lon tc_track(track_i).lon];
                    tc_track_nodes.lat=[tc_track_nodes.lat tc_track(track_i).lat];
                end % track_i
                
                fprintf('saving TC track nodes as %s\n',tc_track_nodes_file);
                save(tc_track_nodes_file,'tc_track_nodes');
            else
                load(tc_track_nodes_file);
            end
            
            % check for track nodes within centroids_rect
            in_track_poly = inpolygon(tc_track_nodes.lon,tc_track_nodes.lat,centroids_edges_x,centroids_edges_y);
            
            if check_plots
                climada_plot_world_borders; hold on;
                plot(tc_track_nodes.lon,tc_track_nodes.lat,'.b','MarkerSize',3);
                plot(tc_track_nodes.lon(in_track_poly),tc_track_nodes.lat(in_track_poly),'xg','MarkerSize',4);
                plot(centroids_edges_x,centroids_edges_y,'-g')
            else
                close all
            end
            
            if sum(in_track_poly)>0
                hazard_count = hazard_count+1;
                centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'TC';
                centroids_hazard_info.res.hazard(hazard_count).raw_data_file = [tc_tracks_folder filesep raw_data_file_temp];
                hazard_count = hazard_count+1;
                centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'TS';
                centroids_hazard_info.res.hazard(hazard_count).raw_data_file = [tc_tracks_folder filesep raw_data_file_temp];
                hazard_count = hazard_count+1;
                centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'TR';
                centroids_hazard_info.res.hazard(hazard_count).raw_data_file = [tc_tracks_folder filesep raw_data_file_temp];
                fprintf('* hazard TC %s detected\n',strrep(raw_data_file_temp,'.txt',''));
            end
            
        end % only *.txt files
        
    end
end %


% EQ: figure whether the particular country is exposed
% ----------------------------------------------------

if length(which('eq_isc_gem_read'))<2
    cprintf([1,0.5,0],'Earthquake (EQ) module not found. Please download from github and install. \nhttps://github.com/davidnbresch/climada_module_eq_global\n\n');
else
    % test EQ exposure
    %eq_data=eq_centennial_read; % until 20141203
    eq_data=eq_isc_gem_read;
    
    % check for track nodes within centroids_rect
    in_seismic_poly = inpolygon(eq_data.glon,eq_data.glat,centroids_edges_x,centroids_edges_y);
    
    if check_plots
        climada_plot_world_borders; hold on;
        plot(eq_data.glon,eq_data.glat,'.r','MarkerSize',3);
        plot(eq_data.glon(in_seismic_poly),eq_data.glat(in_seismic_poly),'xg','MarkerSize',4);
        plot(centroids_edges_x,centroids_edges_y,'-g')
    else
        close all
    end
    
    if sum(in_seismic_poly)>0
        hazard_count = hazard_count+1;
        centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'EQ';
        centroids_hazard_info.res.hazard(hazard_count).raw_data_file = []; % for safety, not needed
        fprintf('* hazard EQ detected\n');
    end
end

% WS: figure whether the particular country is exposed to European winter storms
% ------------------------------------------------------------------------------

if length(which('winterstorm_TEST'))<2
    cprintf([1,0.5,0],'European winterstorm (WS) module not found. Please download from github and install. \nhttps://github.com/davidnbresch/climada_module_ws_europe\n\n');
else
    % test WS exposure
    WS_module_data_dir=[fileparts(fileparts(which('winterstorm_TEST'))) filesep 'data'];
    
    full_WS_Europe_hazard_set_file=[WS_module_data_dir filesep 'hazards' filesep WS_Europe_hazard_set_file];
    if exist(full_WS_Europe_hazard_set_file,'file')
        load([WS_module_data_dir filesep 'hazards' filesep WS_Europe_hazard_set_file]);
    else
        % generate the blended WS_Europe hazard set first
        hazard=winterstorm_blend_hazard_event_sets;
    end
    
    % check for WS centroids within centroids_rect
    in_ws_poly = inpolygon(hazard.lon,hazard.lat,centroids_edges_x,centroids_edges_y);
    
    if check_plots
        climada_plot_world_borders; hold on;
        plot(hazard.lon,hazard.lat,'.m','MarkerSize',3);
        plot(hazard.lon(in_ws_poly),hazard.lat(in_ws_poly),'xg','MarkerSize',4);
        plot(centroids_edges_x,centroids_edges_y,'-g')
    else
        close all
    end
    
    if sum(in_ws_poly)>0
        hazard_count = hazard_count+1;
        centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'WS';
        centroids_hazard_info.res.hazard(hazard_count).raw_data_file = []; % for safety, not needed
        fprintf('* hazard WS Europe detected\n');
    end
end

if hazard_count < 1
    fprintf('NOTE: %s not exposed, skipped\n',country_name_char)
    return
end

% 2) Generate the hazard event sets
% =================================

for hazard_i=1:hazard_count
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'TC')
        
        [~,hazard_name]=fileparts(centroids_hazard_info.res.hazard(hazard_i).raw_data_file);
        hazard_name=strrep(strrep(hazard_name,'.',''),'tracks','');
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_TC_' deblank(hazard_name) '.mat'];
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            fprintf('*** hazard generation for TC %s in %s\n',hazard_name,country_name_char);
            
            [~,~,fE]=fileparts(centroids_hazard_info.res.hazard(hazard_i).raw_data_file);

            % read tracks from database file (.txt or .nc)
            if (strcmp(fE,'.txt'))
                % read tracks from unisys database file (txt)
                [tc_track,tc_track_mat] = climada_tc_read_unisys_database(centroids_hazard_info.res.hazard(hazard_i).raw_data_file);
            elseif  (strcmp(fE,'.nc'))
                % read tracks from (NCAR) netCDF files
                [tc_track,tc_track_mat] = climada_tc_read_cam_ibtrac_v02(centroids_hazard_info.res.hazard(hazard_i).raw_data_file);
            else
                fprintf('*** ERROR generating tc_track nodes file: %s\n',tc_track_nodes_file);
            end
                        
            if probabilistic
                
                if exist('climada_tc_track_wind_decay_calculate','file')
                    % wind speed decay at track nodes after landfall
                    [~,p_rel]  = climada_tc_track_wind_decay_calculate(tc_track,check_plots);
                else
                    fprintf('WARNING: no inland decay for probabilistic tracks, consider module tc_hazard_advanced\n');
                end
                
                tc_track = climada_tc_random_walk(tc_track); % overwrites tc_track to save memory
                
                if exist('climada_tc_track_wind_decay_calculate','file')
                    % add the inland decay correction to all probabilistic nodes
                    tc_track   = climada_tc_track_wind_decay(tc_track, p_rel,check_plots);
                end
                
                if check_plots
                    % plot the tracks
                    figure('Name','TC tracks','Color',[1 1 1]); hold on
                    for event_i=1:length(tc_track) % plot all tracks
                        plot(tc_track(event_i).lon,tc_track(event_i).lat,'-b');
                    end % event_i
                    % overlay historic (to make them visible, too)
                    for event_i=1:length(tc_track)
                        if tc_track(event_i).orig_event_flag
                            plot(tc_track(event_i).lon,tc_track(event_i).lat,'-r');
                        end
                    end % event_i
                    climada_plot_world_borders(2)
                    box on; axis equal; axis(centroids_rect);
                    xlabel('blue: probabilistic, red: historic');
                end
                
                % save probabilistic track set
                tc_track_prob_mat = strrep(tc_track_mat,'_proc.mat','_prob.mat');
                save(tc_track_prob_mat,'tc_track');
                
            end % probabilistic
            
            hazard = climada_tc_hazard_set(tc_track,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,centroids);
            fprintf('TC: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
            
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end % exists already
        
    end % peril_ID,'TC'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'TR')
        
        % NOTE: TC has to have run before (usually the case)
        
        [~,hazard_name]=fileparts(centroids_hazard_info.res.hazard(hazard_i).raw_data_file);
        hazard_name=strrep(strrep(hazard_name,'.',''),'tracks','');
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_TR_' deblank(hazard_name) '.mat'];
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            fprintf('*** hazard generation for TR %s in %s\n',hazard_name,country_name_char);
            
            if exist('climada_tr_hazard_set', 'file') % the function exists
                
                % we need the TC track set to start with
                [fP,fN]=fileparts(centroids_hazard_info.res.hazard(hazard_i).raw_data_file);
                tc_track_mat=[fP filesep fN '_proc.mat'];
                tc_track_prob_mat = strrep(tc_track_mat,'_proc.mat','_prob.mat');
                if probabilistic
                    raw_data_file_mat = tc_track_prob_mat;
                else
                    raw_data_file_mat = tc_track_mat;
                end
                fprintf('loading tc tracks from %s\n',raw_data_file_mat);
                load(raw_data_file_mat)
                
                hazard = climada_tr_hazard_set(tc_track,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,centroids);
                fprintf('TR: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
            else
                cprintf([1,0.5,0],'Torrential rain module not found. Please download from github. \nhttps://github.com/davidnbresch/climada_module_tc_rain \n\n'); % a kind of easy check
                centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=[];
            end
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end
    end % peril_ID,'TR'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'TS')
        
        % NOTE: TC has to have run before (usually the case)
        
        [~,hazard_name]=fileparts(centroids_hazard_info.res.hazard(hazard_i).raw_data_file);
        hazard_name=strrep(strrep(hazard_name,'.',''),'tracks','');
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_TS_' deblank(hazard_name) '.mat'];
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            % we need the TC hazard set to start with
            TC_hazard_set_file=strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'TS','TC');
            if exist(TC_hazard_set_file,'file')
                load(TC_hazard_set_file);hazard_TC=hazard;hazard=[];
                
                fprintf('*** hazard generation for TS %s in %s\n',hazard_name,country_name_char);
                
                if exist('climada_ts_hazard_set', 'file') % the function exists
                    hazard = climada_ts_hazard_set(hazard_TC,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file);
                    if ~isempty(hazard)
                        fprintf('TS: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
                    end
                else
                    cprintf([1,0.5,0],'Coastal surge module not found. Please download from github and install. \nhttps://github.com/davidnbresch/climada_module_tc_surge\n\n');
                    centroids_hazard_info.res.hazard(hazard_i).hazard_set_file = [];
                end
                
            else
                fprintf('*** ERROR generating TS: TC hazard set not found: %s\n',TC_hazard_set_file);
            end
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end
    end % peril_ID,'TS'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'EQ')
        
        hazard_name='global'; % once could in theory run more than one 'region', as we do with TC
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_EQ_' deblank(hazard_name) '.mat'];
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            fprintf('*** hazard generation for EQ in %s\n',country_name_char);
            
            if exist('eq_global_hazard_set','file') % the function exists
                %eq_data=eq_centennial_read; % to be on the safe side, until 20141203
                eq_data=eq_isc_gem_read; % to be on the safe side
    
                if probabilistic,eq_data=eq_global_probabilistic(eq_data,9);end
                hazard=eq_global_hazard_set(eq_data,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,centroids);
                if ~isempty(hazard)
                    fprintf('EQ: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
                end
            else
                cprintf([1,0.5,0],'Earthquake module not found. Please download from github and install. \nhttps://github.com/davidnbresch/climada_module_eq_global\n\n');
                centroids_hazard_info.res.hazard(hazard_i).hazard_set_file = [];
            end
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end
    end % peril_ID,'EQ'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'WS')
        hazard_name='Europe'; % once could in theory run more than one 'region', as we do with TC
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [WS_module_data_dir filesep 'hazards' filesep WS_Europe_hazard_set_file];
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file')
            fprintf('WARNING WS Europe hazard set file not found for %s\n',country_name_char);
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
            
            if WS_Europe_country_hazard_set
                % we create a single WS Europe country hazard event set for
                % each WS Europe exposed country (speedup in risk calc,
                % since centroids ordered the exact same way as hazard
                % intensities)
                
                 centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
                        [local_data_dir filesep 'hazards' filesep country_name_char '_WS_' deblank(hazard_name) '.mat'];
                
                if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
                    
                    fprintf('*** hazard generation for WS in %s\n',country_name_char);
                    
                    % re-arrange hazard to match centroids and create a hazard
                    % sub-set specific to the country (saves time later in risk
                    % calculation, since centroids and hazard.intensity match)
                    n_centroids=length(centroids.Longitude);
                    centroid_index=zeros(1,n_centroids);
                    hazard.event_count=size(hazard.intensity,1);
                    hazard_intensity = spalloc(hazard.event_count,n_centroids,...
                        ceil(hazard.event_count*n_centroids*hazard.matrix_density));
                    
                    if climada_global.waitbar,h = waitbar(0,sprintf('WSEU: Encoding %i records...',n_centroids));end
                    for centroid_i=1:n_centroids
                        if climada_global.waitbar,waitbar(centroid_i/n_centroids,h);end
                        dist_m=climada_geo_distance(centroids.Longitude(centroid_i),centroids.Latitude(centroid_i),hazard.lon,hazard.lat);
                        [~,min_dist_index] = min(dist_m);
                        centroid_index(centroid_i)=min_dist_index;
                        hazard_intensity(:,centroid_i)=sparse(hazard.intensity(:,min_dist_index));
                    end % centroid_i
                    if climada_global.waitbar,close(h);end % close waitbar
                    
                    hazard=rmfield(hazard,'intensity');
                    hazard.intensity=hazard_intensity;hazard_intensity=[];
                    hazard.lat=centroids.Latitude;
                    hazard.lon=centroids.Longitude;
                    hazard.centroid_ID=1:n_centroids;
                    
                    hazard.filename=centroids_hazard_info.res.hazard(hazard_i).hazard_set_file;
                    save(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'hazard');
                end
            end
        end
    end % peril_ID,'WS'
    
    
    if check_plots && ~isempty(hazard)
        [~,max_intensity_pos] = max(sum(hazard.intensity,2)); % the maximum hazard intensity
        
        if ~exist('main_fig_h','var'),main_fig_h = climada_figuresize(0.75,0.8);end
        figure(main_fig_h); subplot(3,3,hazard_i);
        values   = full(hazard.intensity(max_intensity_pos,:)); % get one footprint
        centroids.Longitude   = hazard.lon; % as the gridding routine needs centroids
        centroids.Latitude    = hazard.lat;
        [X, Y, gridded_VALUE] = climada_gridded_VALUE(values,centroids);
        contourf(X, Y, gridded_VALUE,200,'edgecolor','none')
        hold on
        plot(centroids.Longitude,centroids.Latitude,'.r','MarkerSize',1);
        if isfield(centroids,'onLand')
            water_points=find(centroids.onLand==0);
            plot(centroids.Longitude(water_points),centroids.Latitude(water_points),'.b','MarkerSize',1);
        end
        box on; climada_plot_world_borders
        axis equal; axis(centroids_rect);
        title(sprintf('max %s %s event (%i)',hazard.peril_ID,hazard_name,max_intensity_pos));
        colorbar;
        cmap = climada_colormap(hazard.peril_ID);
        if ~isempty(cmap)
            colormap(cmap)
            freezeColors % freeze this plot's colormap
            cbfreeze(colorbar)
        end
        
        if ~isempty(TEST_location)
            text(TEST_location.longitude,TEST_location.latitude,TEST_location.name)
            plot(TEST_location.longitude,TEST_location.latitude,'xk');
        end
    else
        close all % to be on the safe side
    end % check_plots
    
end % hazard_i

return
