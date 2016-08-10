function params=country_risk_prep(country_name,check_plot)
% climada
% MODULE:
%   country_risk
% NAME:
%   country_risk_prep
% PURPOSE:
%   prepare all parameters for a given country, sucb that one can run
%   country_risk_calc afterwards
%
%   next step: country_risk_calc, see also country_admin1_risk_calc and
% CALLING SEQUENCE:
%   params=country_risk_prep(country_name,check_plot)
% EXAMPLE:
%   params=country_risk_prep('Barbados')
% INPUTS:
%   country_name: name of the country, like 'Switzerland', or a list of
%       countries, like {'Switzerland','Germany','France'}. See
%       climada_check_country_name for the list of valid country names
%       > prompted for via dropdown list if empty (allows for single or
%       multiple country selection)
% OPTIONAL INPUT PARAMETERS:
%   check_plot: =1, show check plots, =0 not (default)
% OUTPUTS:
%   params: the parameter structure to run country_risk_calc
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20160615, initial
%-

params = []; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'),country_name=[];end
if ~exist('check_plot','var'),check_plot=[];end
if isempty(check_plot),check_plot=0;end

% PARAMETERS
%
% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' creates so many
% files, one might divert to e.g. a data folder structure within the
% module
country_data_dir = climada_global.data_dir; % default
%country_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data']; % to store within module
%
% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' in country_risk_calc
% creates so many files, one might divert to e.g. a data folder structure within the
% module (see climada_init_folders to create the required folders automatically)
local_data_dir = climada_global.data_dir; % default
%
map_shape_file = climada_global.map_border_file; % the default shape file
dX=1;dY=1; % the 'border' around the country shape to define the region of ineterest
%
% define the WS Europe hazard event set we test for (see module ws_europe)
WS_Europe_hazard_set_file='WS_Europe.mat'; % with .mat
%WS_Europe_hazard_set_file='WS_ERA40.mat'; % until 20141201
%WS_Europe_hazard_set_file='WS_ECHAM_CTL.mat'; % until 20141126

if isempty(country_name) % prompt for country (one or many) as list dialog
    country_name = climada_country_name('Multiple');
elseif strcmp(country_name,'ALL')
    country_name = climada_country_name('all');
end

if isempty(country_name),return; end % Cancel pressed

if ~iscell(country_name),country_name={country_name};end % check that country_name is a cell

if length(country_name)>1 % more than one country, process recursively
    n_countries=length(country_name);
    params_out={}; % init
    for country_i = 1:n_countries
        single_country_name = country_name(country_i);
        fprintf('\nprocessing %s (%i of %i) ************************ \n',...
            char(single_country_name),country_i,n_countries);
        params_out{country_i}=country_risk_prep(single_country_name);
    end % country_i
    params=params_out;
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
if isempty(country_name_char),return;end % still invalid country name

params.country_name = country_name_char;
params.country_ISO3 = country_ISO3;

% define easy to read filenames
params.centroids_file     = [country_data_dir filesep 'centroids' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_centroids.mat'];
params.entity_file        = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
params.entity_future_file = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity_future.mat'];

% set some parameters to default values
params.add_elevation_m=0;
params.add_distance2coast_km=0;
params.probabilistic=0;

% figure which hazards affect the country
% ---------------------------------------
params.hazard=[];hazard_count= 0; % init

climada_plot_world_borders(-999); % check for country shape file

% read the .shp border file and find the country shape
shapes=climada_shaperead(map_shape_file,1,1); % reads .mat subsequent times
for shape_i = 1:length(shapes)
    if any(strcmpi(shapes(shape_i).NAME,params.country_name))
        params.country_shape=shapes(shape_i);
    end
end % shape_i

% the rectangle around the country (for faster checks)
params.country_rect = [min(params.country_shape.X)-dX max(params.country_shape.X)+dX ...
    min(params.country_shape.Y)-dY max(params.country_shape.Y)+dY];
country_edges_x = [params.country_rect(1),params.country_rect(1),params.country_rect(2),params.country_rect(2),params.country_rect(1)];
country_edges_y = [params.country_rect(3),params.country_rect(4),params.country_rect(4),params.country_rect(3),params.country_rect(3)];

fprintf('*** hazard detection (%s)\n',params.country_name);

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
% check for all basisn's track files
tc_tracks_ok=exist([tc_tracks_folder filesep 'tracks.atl.txt'],'file');
tc_tracks_ok=exist([tc_tracks_folder filesep 'tracks.epa.txt'],'file')*tc_tracks_ok;
tc_tracks_ok=exist([tc_tracks_folder filesep 'tracks.nio.txt'],'file')*tc_tracks_ok;
tc_tracks_ok=exist([tc_tracks_folder filesep 'tracks.she.txt'],'file')*tc_tracks_ok;
tc_tracks_ok=exist([tc_tracks_folder filesep 'tracks.wpa.txt'],'file')*tc_tracks_ok;
if strcmp(climada_global.tc.default_raw_data_ext,'.txt') && tc_tracks_ok==0 % check for .epa., as .atl. comes with core climada
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
            in_track_poly = inpolygon(tc_track_nodes.lon,tc_track_nodes.lat,country_edges_x,country_edges_y);
            
            if check_plot
                if check_plot<2,climada_plot_world_borders(-1,params.country_name);hold on;end
                plot(tc_track_nodes.lon,tc_track_nodes.lat,'.b','MarkerSize',3);
                plot(tc_track_nodes.lon(in_track_poly),tc_track_nodes.lat(in_track_poly),'xg','MarkerSize',4);
                plot(country_edges_x,country_edges_y,'-g')
                check_plot=2; % to indicate we already did plot once
            end
            
            if sum(in_track_poly)>0
                hazard_count = hazard_count+1;
                params.hazard(hazard_count).peril_ID = 'TC';
                params.hazard(hazard_count).data_file = tc_track_hist_file;
                hazard_count = hazard_count+1;
                params.hazard(hazard_count).peril_ID = 'TS';
                params.hazard(hazard_count).data_file = tc_track_hist_file;
                hazard_count = hazard_count+1;
                params.hazard(hazard_count).peril_ID = 'TR';
                params.hazard(hazard_count).data_file = tc_track_hist_file;
                fprintf('* hazard TC %s detected\n',strrep(raw_data_file_temp,'.txt',''));
            end
            
        end % only *.txt files
        
    end
end


% EQ: figure whether the particular country is exposed
% ----------------------------------------------------

if length(which('eq_isc_gem_read'))<2
    fprintf(['Earthquake (EQ) module not found. Please download ' ...
        '<a href="https://github.com/davidnbresch/climada_module_earthquake_volcano">'...
        'climada_module_earthquake_volcano</a> from Github.\n'])
else
    % test EQ exposure
    %eq_data=eq_centennial_read; % until 20141203
    [eq_data,isc_gem_file_mat]=eq_isc_gem_read;
    
    % check for track nodes within centroids_rect
    in_seismic_poly = inpolygon(eq_data.glon,eq_data.glat,country_edges_x,country_edges_y);
    
    if check_plot
        if check_plot<2,climada_plot_world_borders(-1,params.country_name);hold on;end
        plot(eq_data.glon,eq_data.glat,'.r','MarkerSize',3);
        plot(eq_data.glon(in_seismic_poly),eq_data.glat(in_seismic_poly),'xg','MarkerSize',4);
        plot(country_edges_x,country_edges_y,'-g')
    end
    
    if sum(in_seismic_poly)>0
        hazard_count = hazard_count+1;
        params.hazard(hazard_count).peril_ID = 'EQ';
        params.hazard(hazard_count).data_file = isc_gem_file_mat; % for information, not needed
        fprintf('* hazard EQ detected\n');
    end
end


% VQ: figure whether the particular country is exposed
% ----------------------------------------------------

if length(which('vq_volcano_list_read'))<2
    fprintf(['Volcano/Earthquake (EQ/VQ) module not found. Please download ' ...
        '<a href="https://github.com/davidnbresch/climada_module_earthquake_volcano">'...
        'climada_module_earthquake_volcano</a> from Github.\n'])
else
    % test VQ exposure
    [vq_data,volcano_list_file_mat]=vq_volcano_list_read;
    
    % check for track nodes within centroids_rect
    in_seismic_poly = inpolygon(vq_data.lon,vq_data.lat,country_edges_x,country_edges_y);
    
    if check_plot
        if check_plot<2,climada_plot_world_borders(-1,params.country_name);hold on;end
        plot(vq_data.lon,vq_data.lat,'.r','MarkerSize',3);
        plot(vq_data.lon(in_seismic_poly),vq_data.lat(in_seismic_poly),'xg','MarkerSize',4);
        plot(country_edges_x,country_edges_y,'-g')
    end
    
    if sum(in_seismic_poly)>0
        hazard_count = hazard_count+1;
        params.hazard(hazard_count).peril_ID = 'VQ';
        params.hazard(hazard_count).data_file = volcano_list_file_mat; % for information, not needed
        fprintf('* hazard VQ detected\n');
    end
end


% WS: figure whether the particular country is exposed to European winter storms
% ------------------------------------------------------------------------------

if length(which('winterstorm_TEST'))<2
    fprintf(['European winterstorm (WS) module not found. Please download ' ...
        '<a href="https://github.com/davidnbresch/climada_module_storm_europe">'...
        'climada_module_storm_europe</a> from Github.\n'])
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
    in_ws_poly = inpolygon(hazard.lon,hazard.lat,country_edges_x,country_edges_y);
    
    if check_plot
        if check_plot<2,climada_plot_world_borders(-1,params.country_name);hold on;end
        plot(hazard.lon,hazard.lat,'.m','MarkerSize',3);
        plot(hazard.lon(in_ws_poly),hazard.lat(in_ws_poly),'xg','MarkerSize',4);
        plot(country_edges_x,country_edges_y,'-g')
    end
    
    if sum(in_ws_poly)>0
        hazard_count = hazard_count+1;
        params.hazard(hazard_count).peril_ID = 'WS';
        params.hazard(hazard_count).data_file = full_WS_Europe_hazard_set_file;
        fprintf('* hazard WS Europe detected\n');
    end
end

if hazard_count < 1
    fprintf('WARNING: %s not exposed\n',params.country_name)
end

end % country_risk_prep