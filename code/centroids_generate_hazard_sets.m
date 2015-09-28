function centroids_hazard_info=centroids_generate_hazard_sets(centroids,probabilistic,force_recalc,check_plots,peril_ID)
% climada
% MODULE:
%   country_risk
% NAME:
%   centroids_generate_hazard_sets
% PURPOSE:
%   run all (available) perils for a given set of centroids. Generate
%   earthquake (EQ), volcano (VQ), tropical cyclone (TC), torrential rain
%   (TR) and storm surge (TS) hazard event sets 
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
%   centroids_hazard_info=centroids_generate_hazard_sets(centroids,probabilistic,force_recalc,check_plots,peril_ID)
% EXAMPLE:
%   centroids_generate_hazard_sets; % interactive, prompt for centroids
% INPUTS:
%   centroids: a centroid structure, see e.g. climada_centroids_load
%       or an entity (in which case it takes the entity.assets.lat and
%       entity.assets.lon)
%       > prompted for if empty (centroids need to exist als .mat file
%       already - otherwise run e.g. climada_centroids_read first).
%       In case you select an entity, it takes entity.assets.lat and
%       entity.assets.lon.
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
%   peril_ID: if passed on, run all calculations only for specified peril
%       peril_ID can be 'TC','TS','TR','EQ','WS'..., default='' for all
% OUTPUTS:
%   writes hazard event set files: III_name_rrr_PP{|_hist}.mat with III
%       ISO2 country (admin0) code, country name, rrr peril region and PP
%       peril_ID. Appends _hist if non-probabilistic. Note that for admin1
%       hazard event sets, name does alos contain the admin1 name.
%   centroids_hazard_info(centroids_i): a structure with hazard information for
%       each set of centroids. See centroids_hazard_info.res.hazard with
%       peril_ID: 'TC' or ...
%       data_file: for TC only: the file sused to generste the event set
%       hazard_set_file: the full filename of the hazard set generated
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141025, moved out of country_risk_calc
% David N. Bresch, david.bresch@gmail.com, 20141026, probabilistic as input
% David N. Bresch, david.bresch@gmail.com, 20141029, WSEU added
% David N. Bresch, david.bresch@gmail.com, 20141208, possibility to pass entity as centroids
% David N. Bresch, david.bresch@gmail.com, 20150110, save with -v7.3 (needed for large hazard sets)
% David N. Bresch, david.bresch@gmail.com, 20150112, hazard extension '_hist' for historic, '' for probabilistic
% David N. Bresch, david.bresch@gmail.com, 20150112, III_name_rrr_PP{|_hist}.mat
% David N. Bresch, david.bresch@gmail.com, 20150118, tc_track nodes file with track number
% David N. Bresch, david.bresch@gmail.com, 20150123, distance2coast_km in TC added
% David N. Bresch, david.bresch@gmail.com, 20150128, tc_track handling simplified, climada_tc_track_nodes
% David N. Bresch, david.bresch@gmail.com, 20150309, VQ (volcano) added
% David N. Bresch, david.bresch@gmail.com, 20150819, climada_global.centroids_dir introduced
%-

centroids_hazard_info = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('centroids','var'),     centroids = '';   end
if ~exist('probabilistic','var'), probabilistic = 0;end
if ~exist('force_recalc','var'),  force_recalc = 0; end
if ~exist('check_plots','var'),   check_plots  = 0; end
if ~exist('peril_ID','var'),      peril_ID  = ''; end

%module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% switches to select which hazards to calculate, default is all =1
calculate_TC=1; % whether we calculate TC
calculate_TS=1; % whether we calculate TS (needs TC)
calculate_TR=0; % whether we calculate TR (needs TC)
calculate_EQ=1; % whether we calculate EQ
calculate_VQ=0; % whether we calculate VQ
calculate_WS=1; % whether we calculate WS
%
% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' in country_risk_calc
% creates so many files, one might divert to e.g. a data folder structure within the
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
if ~exist([local_data_dir filesep 'centroids'],'dir'),mkdir(local_data_dir,'centroids');end
if ~exist([local_data_dir filesep 'entities'],'dir'),mkdir(local_data_dir,'entities');end
if ~exist([local_data_dir filesep 'hazards'],'dir'),mkdir(local_data_dir,'hazards');end

if ~isempty(peril_ID)
    % first, reset all
    calculate_TC=0;
    calculate_TS=0;
    calculate_TR=0;
    calculate_EQ=0;
    calculate_VQ=0;
    calculate_WS=0;
    switch peril_ID
        case 'TC'
            calculate_TC=1;
        case 'TS'
            calculate_TS=1;
            calculate_TC=1;% needs TC
        case 'TR'
            calculate_TR=1;
            calculate_TC=1;% needs TC
        case 'EQ'
            calculate_EQ=1;
        case 'VQ'
            calculate_VQ=1;
        case 'WS'
            calculate_WS=1;
        otherwise
            fprintf('%s: peril_ID %s not implemented, aborted\n',mfilename,peril_ID)
            return
    end
end % ~isempty(peril_ID)


% prompt for centroids if not given

if isempty(centroids) % local GUI
    centroids_file=[climada_global.centroids_dir filesep '*.mat'];
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
    centroids.lat=entity.assets.lat;
    centroids.lon=entity.assets.lon;
    centroids.centroid_ID=1:length(entity.assets.lon);
    if isfield(entity.assets,'distance2coast_km'),centroids.distance2coast_km=entity.assets.distance2coast_km;end
    if isfield(entity.assets,'elevation_m'),centroids.elevation_m=entity.assets.elevation_m;end
    if isfield(entity.assets,'country_name'),centroids.country_name=entity.assets.country_name;end
    if isfield(entity.assets,'admin0_name'),centroids.admin0_name=entity.assets.admin0_name;end
    if isfield(entity.assets,'admin0_ISO3'),centroids.admin0_ISO3=entity.assets.admin0_ISO3;end
    if isfield(entity.assets,'admin1_name'),centroids.admin1_name=entity.assets.admin1_name;end
    if isfield(entity.assets,'admin1_code'),centroids.admin1_code=entity.assets.admin1_code;end
    clear entity
end

country_name_char=''; % init, start appending:

if isfield(centroids,'country_name'),[~,country_ISO3]=climada_country_name(centroids.country_name);end
% first ISO3 code
if isfield(centroids,'admin0_ISO3'),country_name_char=char(centroids.admin0_ISO3);
elseif ~isempty(country_ISO3),country_name_char=country_ISO3;end
% second country name
if isfield(centroids,'admin0_name')country_name_char=[country_name_char '_' char(centroids.admin0_name)];
elseif isfield(centroids,'country_name')
    if iscell(centroids.country_name),country_name_char=[country_name_char '_' centroids.country_name{1}];end
end % another name for the field
% third admin1 name
if isfield(centroids,'admin1_name'),country_name_char=[country_name_char '_' char(centroids.admin1_name)];end % append, if it exists
% fourth admin1 code
if isfield(centroids,'admin1_code'),country_name_char=[country_name_char '_' char(centroids.admin1_code)];end % append, if it exists
if isempty(country_name_char),country_name_char='centroids';end % just to keep going

country_name_char=strrep(strrep(country_name_char,' ',''),' ',''); % remove inner blanks
country_name_char=strrep(country_name_char,'(','');
country_name_char=strrep(country_name_char,')','');
%country_name_char=strrep(country_name_char,'-','');

% 1) figure which hazards affect the country
% ==========================================

% prep the region we need
centroids_rect = [min(centroids.lon) max(centroids.lon) min(centroids.lat) max(centroids.lat)];
centroids_edges_x = [centroids_rect(1),centroids_rect(1),centroids_rect(2),centroids_rect(2),centroids_rect(1)];
centroids_edges_y = [centroids_rect(3),centroids_rect(4),centroids_rect(4),centroids_rect(3),centroids_rect(3)];

hazard_count = 0; % init

fprintf('*** hazard detection (%s)\n',country_name_char);

if calculate_TC
    
    % TC, TS, TR: figure which ocean basin(s) to use for the particular country
    % -------------------------------------------------------------------------
    
    % note on process: here, we read the TC tracks a first time and make
    % sure the .mat file with tc_track is generated (in case it does not
    % exists to start with). The core functions which read the TC tracks do
    % not only return the tracks in strcuture tc_track, but also the .mat
    % file where they got saved (usually *_hist.mat, to indicate it's the
    % processed - means cleaned - tracks).
    % We also save just the track nodes (in _nodes.mat, for speedup in later use)
    % Futher down, the file *_prob.mat is generated, which contains the
    % probabilistic tracks to make sure we use the exact same
    % probabilistic set for subsequent calls (as the generation of
    % probabilistic tracks involves a random number, we avoid troubles this
    % way).
    %
    % in summary:
    % *_hist.mat contains the cleaned original (historic) TC tracks structure tc_track(i)
    % *_nodes.mat contains the TC track nodes (tc_track_nodes.lon(j) and .lat(j), all in one, not by track)
    % *_prob.mat contains the tc_track(i) structure with the full probabilistic set
    %
    % It is highly recommended to use above .mat files in subsequent calls,
    % in order to ensure full consistency with hazard sets etc.
    
    tc_tracks_folder=[local_data_dir filesep 'tc_tracks'];
    if ~exist(tc_tracks_folder,'dir'),mkdir(local_data_dir,'tc_tracks');end
    if strcmp(climada_global.tc.default_raw_data_ext,'.txt') && ...
            ~exist([tc_tracks_folder filesep 'tracks.epa.txt'],'file') % check for .epa., as .atl. comes with core climada
        % if we expect UNISYS (.txt) tc track raw data files and do not
        % find them, get them all from www
        climada_tc_get_unisys_databases(tc_tracks_folder);
    end
    
    D = dir(tc_tracks_folder); % get content
    for file_i=1:length(D)
        if ~D(file_i).isdir
            raw_data_file_temp=D(file_i).name;
            [~,~,fE]=fileparts(raw_data_file_temp);
            if (strcmp(fE,climada_global.tc.default_raw_data_ext) || strcmp(fE,'.nc')) && isempty(strfind(raw_data_file_temp,'TEST'))
                
                tc_track_raw_file=[tc_tracks_folder filesep raw_data_file_temp]; % original raw data file
                tc_track_hist_file=strrep(tc_track_raw_file,fE,'_hist.mat'); % the *_hist.mat file where tc_track is stored
                
                if ~climada_check_matfile(tc_track_raw_file,tc_track_hist_file)
                    % get the tc_tracks (or re-read in case the .mat file is older then the raw data file)
                    if (strcmp(fE,'.txt'))
                        % read tracks from unisys database file
                        [tc_track,tc_track_hist_file] = climada_tc_read_unisys_database(tc_track_raw_file);
                    elseif (strcmp(fE,'.nc'))
                        % read tracks from (NCAR) netCDF file
                        [tc_track,tc_track_hist_file] = climada_tc_read_cam_ibtrac_v02(tc_track_raw_file);
                    else
                        fprintf('*** ERROR reading original tc_track data file: %s\n',tc_track_raw_file);
                    end
                end
                
                % obtain all TC track nodes:
                tc_track_nodes=climada_tc_track_nodes(tc_track_hist_file);
                
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
                    centroids_hazard_info.res.hazard(hazard_count).data_file = tc_track_hist_file;
                    if calculate_TS
                        hazard_count = hazard_count+1;
                        centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'TS';
                        centroids_hazard_info.res.hazard(hazard_count).data_file = tc_track_hist_file;
                    end
                    if calculate_TR
                        hazard_count = hazard_count+1;
                        centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'TR';
                        centroids_hazard_info.res.hazard(hazard_count).data_file = tc_track_hist_file;
                    end
                    fprintf('* hazard TC %s detected\n',strrep(raw_data_file_temp,'.txt',''));
                end
                
            end % only *.txt files
            
        end
    end %
    
end % calculate_TC

if calculate_EQ
    
    % EQ: figure whether the particular country is exposed
    % ----------------------------------------------------
    
    if length(which('eq_isc_gem_read'))<2
        cprintf([1,0.5,0],'Earthquake (EQ) module not found. Please download from github and install. \nhttps://github.com/davidnbresch/climada_module_eq_global\n\n');
    else
        % test EQ exposure
        %eq_data=eq_centennial_read; % until 20141203
        [eq_data,isc_gem_file_mat]=eq_isc_gem_read;
        
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
            centroids_hazard_info.res.hazard(hazard_count).data_file = isc_gem_file_mat; % for information, not needed
            fprintf('* hazard EQ detected\n');
        end
    end
    
end % calculate_EQ

if calculate_VQ
    
    % VQ: figure whether the particular country is exposed
    % ----------------------------------------------------
    
    if length(which('vq_volcano_list_read'))<2
        fprintf('Volcano/Earthquake (EQ) module not found. Please download from github and install. \nhttps://github.com/davidnbresch/climada_module_eq_global\n');
    else
        % test VQ exposure
        [vq_data,volcano_list_file_mat]=vq_volcano_list_read;
        
        % check for track nodes within centroids_rect
        in_seismic_poly = inpolygon(vq_data.lon,vq_data.lat,centroids_edges_x,centroids_edges_y);
        
        if check_plots
            climada_plot_world_borders; hold on;
            plot(vq_data.lon,vq_data.lat,'.r','MarkerSize',3);
            plot(vq_data.lon(in_seismic_poly),vq_data.lat(in_seismic_poly),'xg','MarkerSize',4);
            plot(centroids_edges_x,centroids_edges_y,'-g')
        else
            close all
        end
        
        if sum(in_seismic_poly)>0
            hazard_count = hazard_count+1;
            centroids_hazard_info.res.hazard(hazard_count).peril_ID = 'VQ';
            centroids_hazard_info.res.hazard(hazard_count).data_file = volcano_list_file_mat; % for information, not needed
            fprintf('* hazard VQ detected\n');
        end
    end
    
end % calculate_VQ

if calculate_WS
    
    % WS: figure whether the particular country is exposed to European winter storms
    % ------------------------------------------------------------------------------
    
    if length(which('winterstorm_TEST'))<2
        cprintf([1,0.5,0],'European winterstorm (WS) module not found. Please download from github and install. \nhttps://github.com/davidnbresch/climada_module_ws_europe\n\n');
    else
        % test WS exposure
        WS_module_data_dir=[fileparts(fileparts(which('winterstorm_TEST'))) filesep 'data'];
        
        full_WS_Europe_hazard_set_file=[WS_module_data_dir filesep 'hazards' filesep WS_Europe_hazard_set_file];
        if exist(full_WS_Europe_hazard_set_file,'file')
            load(full_WS_Europe_hazard_set_file);
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
            centroids_hazard_info.res.hazard(hazard_count).data_file = full_WS_Europe_hazard_set_file;
            fprintf('* hazard WS Europe detected\n');
        end
    end
    
    if hazard_count < 1
        fprintf('NOTE: %s not exposed, skipped\n',country_name_char)
        return
    end
    
end % calculate_WS

probabilistic_str='_hist';if probabilistic,probabilistic_str='';end

% 2) Generate the hazard event sets
% =================================

for hazard_i=1:hazard_count
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'TC')
        
        [~,hazard_name]=fileparts(centroids_hazard_info.res.hazard(hazard_i).data_file);
        hazard_name=strrep(hazard_name,'.','');
        hazard_name=strrep(hazard_name,'tracks','');
        hazard_name=strrep(hazard_name,'_hist','');
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_' deblank(hazard_name) '_TC' probabilistic_str '.mat'];
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'__','_');
        
        if exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') && force_recalc
            % we need to delete the hazard set file, as
            % climada_tc_hazard_set picks up from last file if it exists
            % already
            delete(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file);
        end
        
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            fprintf('*** hazard generation for TC %s%s in %s (can take some time)\n',hazard_name,probabilistic_str,country_name_char);
            
            tc_track_hist_file=centroids_hazard_info.res.hazard(hazard_i).data_file;
            load(tc_track_hist_file) % contains tc_track
            
            if probabilistic
                
                tc_track_prob_mat  = strrep(tc_track_hist_file,'_hist.mat','_prob.mat');
                if exist(tc_track_prob_mat,'file')
                    load(tc_track_prob_mat)
                else
                    
                    if exist('climada_tc_track_wind_decay_calculate','file')
                        % wind speed decay at track nodes after landfall
                        [~,p_rel]  = climada_tc_track_wind_decay_calculate(tc_track,check_plots);
                    else
                        fprintf('WARNING: no inland decay for probabilistic tracks, consider module tc_hazard_advanced\n');
                    end
                    
                    tc_track = climada_tc_random_walk(tc_track); % overwrites tc_track to save memory
                    
                    if exist('climada_tc_track_wind_decay','file')
                        % add the inland decay correction to all probabilistic nodes
                        tc_track   = climada_tc_track_wind_decay(tc_track, p_rel,check_plots);
                    else
                        fprintf('WARNING: no inland decay for probabilistic tracks, consider module tc_hazard_advanced\n');
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
                    save(tc_track_prob_mat,'tc_track');
                end % exist(tc_track_prob_mat)
                
            end % probabilistic
            
            if ~isfield(centroids,'distance2coast_km')
                fprintf('calculating distance2coast_km (speeds up windfield calculation)\n')
                % it takes a bit of time to calculate
                % climada_distance2coast_km, but the windfield calcuklation is
                % much faster that way (see climada_tc_windfield)
                centroids.distance2coast_km=climada_distance2coast_km(centroids.lon,centroids.lat);
            end
            
            hazard = climada_tc_hazard_set(tc_track,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,centroids);
            fprintf('TC: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
            
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end % exists already
        
    end % peril_ID,'TC'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'TS')
        
        % NOTE: TC has to have run before (usually the case)
        
        [~,hazard_name]=fileparts(centroids_hazard_info.res.hazard(hazard_i).data_file);
        hazard_name=strrep(hazard_name,'.','');
        hazard_name=strrep(hazard_name,'tracks','');
        hazard_name=strrep(hazard_name,'_hist','');
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_' deblank(hazard_name) '_TS' probabilistic_str '.mat'];
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'__','_');
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            % we need the TC hazard set to start with
            TC_hazard_set_file=strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'TS','TC');
            if exist(TC_hazard_set_file,'file')
                load(TC_hazard_set_file);hazard_TC=hazard;hazard=[];
                
                fprintf('*** hazard generation for TS %s%s in %s (can take some time, faster than TC)\n',hazard_name,probabilistic_str,country_name_char);
                
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
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'TR')
        
        % NOTE: TC has to have run before (usually the case)
        
        [~,hazard_name]=fileparts(centroids_hazard_info.res.hazard(hazard_i).data_file);
        hazard_name=strrep(hazard_name,'.','');
        hazard_name=strrep(hazard_name,'tracks','');
        hazard_name=strrep(hazard_name,'_hist','');
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_' deblank(hazard_name) '_TR'  probabilistic_str '.mat'];
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'__','_');
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            fprintf('*** hazard generation for TR %s%s in %s (can take some time, longer than TC)\n',hazard_name,probabilistic_str,country_name_char);
            
            if exist('climada_tr_hazard_set', 'file') % the function exists
                
                % we need the TC track set to start with
                tc_track_file=centroids_hazard_info.res.hazard(hazard_i).data_file;
                if probabilistic
                    tc_track_file = strrep(tc_track_file,'_hist.mat','_prob.mat');
                end
                fprintf('loading tc tracks from %s\n',tc_track_file);
                load(tc_track_file) % contains tc_track
                
                hazard = climada_tr_hazard_set(tc_track,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,centroids);
                fprintf('TR: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
            else
                fprintf('Torrential rain module not found. Please download from github:\nhttps://github.com/davidnbresch/climada_module_tc_rain\n'); % a kind of easy check
                centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=[];
            end
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end
    end % peril_ID,'TR'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'EQ')
        
        hazard_name='glb'; % one could in theory run more than one 'region', as we do with TC
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_' deblank(hazard_name) '_EQ' probabilistic_str '.mat'];
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'__','_');
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            fprintf('*** hazard generation for EQ%s in %s\n',probabilistic_str,country_name_char);
            
            if exist('eq_global_hazard_set','file') % the function exists
                
                if exist(centroids_hazard_info.res.hazard(hazard_i).data_file,'file')
                    load(centroids_hazard_info.res.hazard(hazard_i).data_file); % contains eq_data
                else
                    %eq_data=eq_centennial_read; % to be on the safe side, until 20141203
                    [eq_data,eq_data_file]=eq_isc_gem_read; % to be on the safe side
                    centroids_hazard_info.res.hazard(hazard_i).data_file=eq_data_file;
                end
                
                if probabilistic
                    [fP,fN,fE]=fileparts(centroids_hazard_info.res.hazard(hazard_i).data_file);
                    eq_data_prob_file=[fP filesep fN '_prob' fE];
                    if exist(eq_data_prob_file,'file')
                        load(eq_data_prob_file); % contains eq_data
                    else
                        eq_data=eq_global_probabilistic(eq_data,9);
                        save(eq_data_prob_file,'eq_data');
                    end
                    centroids_hazard_info.res.hazard(hazard_i).data_file=eq_data_prob_file;
                end
                hazard=eq_global_hazard_set(eq_data,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,centroids);
                if ~isempty(hazard)
                    fprintf('EQ: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
                end
            else
                fprintf('Earthquake module not found. Please download from github and install.\nhttps://github.com/davidnbresch/climada_module_eq_global\n');
                centroids_hazard_info.res.hazard(hazard_i).hazard_set_file = [];
            end
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end
    end % peril_ID,'EQ'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'VQ')
        
        hazard_name='glb'; % one could in theory run more than one 'region', as we do with TC
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            [local_data_dir filesep 'hazards' filesep country_name_char '_' deblank(hazard_name) '_VQ' probabilistic_str '.mat'];
        
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'__','_');
        
        if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
            
            fprintf('*** hazard generation for VQ%s in %s\n',probabilistic_str,country_name_char);
            
            if exist('vq_global_hazard_set','file') % the function exists
                
                if exist(centroids_hazard_info.res.hazard(hazard_i).data_file,'file')
                    load(centroids_hazard_info.res.hazard(hazard_i).data_file); % contains vq_data
                else
                    [vq_data,volcano_list_file_mat]=vq_volcano_list_read;
                    centroids_hazard_info.res.hazard(hazard_i).data_file=volcano_list_file_mat;
                end
                
                if probabilistic
                    [fP,fN,fE]=fileparts(centroids_hazard_info.res.hazard(hazard_i).data_file);
                    vq_data_prob_file=[fP filesep fN '_prob' fE];
                    if exist(vq_data_prob_file,'file')
                        load(vq_data_prob_file); % contains eq_data
                    else
                        vq_data=vq_global_probabilistic(vq_data,9);
                        save(vq_data_prob_file,'vq_data');
                    end
                    centroids_hazard_info.res.hazard(hazard_i).data_file=vq_data_prob_file;
                end
                hazard=vq_global_hazard_set(vq_data,centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,centroids);
                if ~isempty(hazard)
                    fprintf('VQ: max(max(hazard.intensity))=%f\n',full(max(max(hazard.intensity)))); % a kind of easy check
                end
            else
                fprintf('Volcano/Earthquake module not found. Please download from github and install.\nhttps://github.com/davidnbresch/climada_module_eq_global\n');
                centroids_hazard_info.res.hazard(hazard_i).hazard_set_file = [];
            end
        else
            load(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file); % load hazard (to check)
        end
    end % peril_ID,'VQ'
    
    
    if strcmp(centroids_hazard_info.res.hazard(hazard_i).peril_ID,'WS')
        hazard_name='eur'; % once could in theory run more than one 'region', as we do with TC
        centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
            centroids_hazard_info.res.hazard(hazard_i).data_file;
        
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
                    [local_data_dir filesep 'hazards' filesep country_name_char '_' deblank(hazard_name) '_WS.mat'];
                
                centroids_hazard_info.res.hazard(hazard_i).hazard_set_file=...
                    strrep(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'__','_');
                
                if ~exist(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'file') || force_recalc
                    
                    fprintf('*** hazard generation for WS in %s (can take some time)\n',country_name_char);
                    
                    % re-arrange hazard to match centroids and create a hazard
                    % sub-set specific to the country (saves time later in risk
                    % calculation, since centroids and hazard.intensity match)
                    n_centroids=length(centroids.lon);
                    centroid_index=zeros(1,n_centroids);
                    hazard.event_count=size(hazard.intensity,1);
                    hazard_intensity = spalloc(hazard.event_count,n_centroids,...
                        ceil(hazard.event_count*n_centroids*hazard.matrix_density));
                    
                    if climada_global.waitbar,h = waitbar(0,sprintf('WSEU: Encoding %i records...',n_centroids));end
                    for centroid_i=1:n_centroids
                        if climada_global.waitbar,waitbar(centroid_i/n_centroids,h);end
                        dist_m=climada_geo_distance(centroids.lon(centroid_i),centroids.lat(centroid_i),hazard.lon,hazard.lat);
                        [~,min_dist_index] = min(dist_m);
                        centroid_index(centroid_i)=min_dist_index;
                        hazard_intensity(:,centroid_i)=sparse(hazard.intensity(:,min_dist_index));
                    end % centroid_i
                    if climada_global.waitbar,close(h);end % close waitbar
                    
                    hazard=rmfield(hazard,'intensity');
                    hazard.intensity=hazard_intensity;hazard_intensity=[];
                    hazard.lat=centroids.lat;
                    hazard.lon=centroids.lon;
                    hazard.centroid_ID=1:n_centroids;
                    
                    hazard.filename=centroids_hazard_info.res.hazard(hazard_i).hazard_set_file;
                    save(centroids_hazard_info.res.hazard(hazard_i).hazard_set_file,'hazard','-v7.3');
                    % Warning: Variable 'hazard' cannot be saved to a MAT-file whose version is
                    % older than 7.3. To save this variable, use the -v7.3 switch. to avoid
                    % this warning, the switch is used. david's comment: only shows for large
                    % hazard sets, seems to be due to huge size of hazard.
                    % Octave does not like -v7.3, but solved in climada_EDS_calc, see there
                end
            end
        end
    end % peril_ID,'WS'
    
    
    if check_plots && ~isempty(hazard)
        [~,max_intensity_pos] = max(sum(hazard.intensity,2)); % the maximum hazard intensity
        
        if ~exist('main_fig_h','var'),main_fig_h = climada_figuresize(0.75,0.8);end
        figure(main_fig_h); subplot(3,3,hazard_i);
        values   = full(hazard.intensity(max_intensity_pos,:)); % get one footprint
        centroids.lon   = hazard.lon; % as the gridding routine needs centroids
        centroids.lat    = hazard.lat;
        [X, Y, gridded_VALUE] = climada_gridded_VALUE(values,centroids);
        contourf(X, Y, gridded_VALUE,200,'edgecolor','none')
        hold on
        plot(centroids.lon,centroids.lat,'.r','MarkerSize',1);
        if isfield(centroids,'onLand')
            water_points=find(centroids.onLand==0);
            plot(centroids.lon(water_points),centroids.lat(water_points),'.b','MarkerSize',1);
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
        
    else
        close all % to be on the safe side
    end % check_plots
    
end % hazard_i

return
