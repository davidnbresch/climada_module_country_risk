function entity=climada_centroids_generate_blackmarble_entity(centroids, country_names, parameters, regulargrid_flag)
% country admin0 admin1 entity high resolution
% NAME:
%	climada_centroids_generate_blackmarble_entity
% PURPOSE:
%   Construct an entity file based on high-resolution (1km!) or
%   mid-resolution (10km) night light data for a predefined set of centroids. Use scaling
%   etc. as in climada_nightlight_entity, but for all countries.
%
%   SPECIAL: run climada_nightlight_entity at least for one country at the
%   desried resolution once before calling
%   climada_nightlight_gloabl_entity, since climada_nightlight_entity does
%   prepare and init some (nightlight) datasets.
%
%   Reads an image file with nightlight density and matches it to the local
%   geography, then scales to proxy for asset values. See
%   climada_nightlight_entity for detailed description of the scaling etc.
%
%   climada_nightlight_entity also for sources, data files etc.
%
%   This code is a bit a bare-bone version, just to create a globally
%   consistent asset base (usually in 10km resolution).
%
%   Note: the code uses climada_inpolygon instead of inpolygon.
%
%   See also: climada_blackmarble_entity
% CALLING SEQUENCE:
%   entity=climada_centroids_generate_blackmarble_entity(centroids, country_names, parameters, regulargrid_flag)
% EXAMPLE:
%   hazard_TCNA = climada_hazard_load('TCNA_today_small.mat');
%   entity_USA = climada_centroids_generate_blackmarble_entity(hazard_TCNA, {'USA'});
%   climada_entity_plot(entity_USA,[],1); % visual check
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   centroids: a structure, with (at least)
%       lon  (1,:): the longitudes   
%       lat   (1,:): the latitudes   
%       centroid_ID(1,:): a unique ID for each centroid, simplest: 1:length(Longitude)
%   country_names: a list of countries for which the entity should be
%       calculated
%   parameters: a structure to pass on parameters, with fields as
%       (run parameters=climada_nightlight_global_entity('parameters') to obtain
%       all default values)
%       restrict_Values_to_country: whether we scale country assets to GDP
%           * factor, see climada_nightlight_entity and assign the country
%           ISO3 code to each centroid  (=1, default) or not (=0,faster,
%           but less useful).
%           NOTE: this parameter has the same name, but a different meaning
%           in climada_nightlight_entity (but convenient to use same set of
%           parameters oin both codes).
%       grid_spacing_multiplier: the spacing of regular grid outside of the
%           area requested. Default=5, hence approx every 5th point as outer
%           grid.
%       nightlight_transform_poly: the polynomial coefficients to transform
%           the nightlight intensity (usually in the range 0..60) to proxy
%           asset values. Evaluated using polyval, i.e.
%           value=polyval(parameters.nightlight_transform_poly,nightlight_intensity)
%           Default=[1 0 0 0], which means Value=nightlight_intensity^3
%           After this Values are normalized to sum up to 1.
%           Note that if a whole country is requested, Values are then
%           scaled to sum up to GDP*(income_group+1).
%       value_threshold: if empty or =0, all centroids (also those with zero
%           value) are kept in the entity (default). If set to a value,
%           only centroids with entity.Value>value_threshold are kept (note
%           that this way, one can specify an asset value threshold, reduce
%           the number of points to be dealt with).
%           One might often want to avoid all truly tero points, i.e.
%       add_distance2coast_km: if =1, add distance to coast, default=0
%       add_elevation_m: if =1, add elevation, default=0
%       img_filename: the filename of an image with night light density, as
%           created using the GUI at http://maps.ngdc.noaa.gov/viewers/dmsp_gcv4/
%           and select Satellite F18, 2010, avg_lights_x_pct, then 'Download
%           data' and enter the coordinates
%           The filename has to be of form A_B_C_D_{|E_F}*..lzw.tiff with A,B,C and D
%           the min lon, min lat, max lon and max lat (integer), like
%           87_20_94_27_F182010.v4c.avg_lights_x_pct.lzw.tiff and E and F the
%           country (admin0) and state/province (admin1) name, like
%           -88_24_-79_32_United States of America_Florida_high_res.avg_lights.lzw.tiff
%
%           If empty (eg run the code without any argument), it prompts for country
%           and admin1 name and constructs the URL to get the corresponding
%           tile from the nightlight data, e.g. a string such as:
%           http://mapserver.ngdc.noaa.gov/cgi-bin/public/gcv4/F182010.v4c.
%               avg_lights_x_pct.lzw.tif?request=GetCoverage&service=WCS&
%               version=1.0.0&COVERAGE=F182010.v4c.avg_lights_x_pct.lzw.tif&
%               crs=EPSG:4326&format=geotiff&resx=0.0083333333&resy=0.0083333333&
%               bbox=-88,24,-79,32
%       save_entity: whether we save the entity (=1, default) or nor (=0).
%           ='ASK' prompt for an image file (without first asking for country
%           where one has to press 'Cancel') to get the to filename prompt
%       entity_filename: the filename to save the entity to, default is a
%           long one with ISO3, country name, admin1 name, geo coord and
%           resolution. Not used if save_entity=0
%       check_plot: if =1: plot nightlight data with admin0 (countries)
%           superimposed. If=3, plot the resulting asset Values
%       verbose: whether we printf progress to stdout (=1, default) or not (=0)
%   regulargrid_flag: select which algorithm to use for translating the
%       grid of the satellite image onto the centroids (1=regular grid
%
% OUTPUTS:
%   entity: a full climada entity, see climada_entity_read, plus the fields
%       entity.assets.distance2coast_km(i): distance to coast in km (both on-
%           and offshore) for each centroid
%       entity.assets.elevation_m(i): elevation in m for each centroid,
%           negatove for ocean depth (needs climada module etopo, just skips
%           this if module not installed)
%       entity.assets.centroid_admin0_ISO3{i}: country ISO3 code for each
%           centroid i, WWW for water (oceans). Not added, if
%           restrict_Values_to_country=0)
%       entity.assets.nightlight_transform_poly: the polynomial
%           coefficients that have been used to transform the nightlight
%           intensity.
%       entity.assets.isgridpoint: =1 for the regular grid added 'around'
%           the assets, =0 for the 'true' asset centroids (not added, if
%           restrict_Values_to_country=0)
%       see e.g. climada_entity_plot to check
% RESTRICTIONS:
% MODIFICATION HISTORY:
% thomas.roeoesli@usys.ethz.ch, 20171114, initial


entity=[]; % init

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% check for arguments
if ~exist('centroids','var'),return;end
if ~exist('country_names','var'),country_names='';end
if ~exist('parameters','var'),parameters=struct;end
if ~exist('regulargrid_flag','var'),regulargrid_flag=1;end


return_parameters=0;
if strcmpi(centroids,'parameters'),return_parameters=1;parameters=struct;end
if strcmpi(parameters,'parameters'),return_parameters=1;parameters=struct;end

% locate the moduel's data
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% check for some parameter fields we need
if ~isfield(parameters,'nightlight_transform_poly'),parameters.nightlight_transform_poly=[];end
if ~isfield(parameters,'restrict_Values_to_country'),parameters.restrict_Values_to_country=[];end
if ~isfield(parameters,'grid_spacing_multiplier'),parameters.grid_spacing_multiplier=[];end
if ~isfield(parameters,'img_filename'),parameters.img_filename='';end
if ~isfield(parameters,'save_entity'),parameters.save_entity=[];end
if ~isfield(parameters,'entity_filename'),parameters.entity_filename='';end
if ~isfield(parameters,'value_threshold'),parameters.value_threshold=[];end
if ~isfield(parameters,'add_distance2coast_km'),parameters.add_distance2coast_km=[];end
if ~isfield(parameters,'add_elevation_m'),parameters.add_elevation_m=[];end
if ~isfield(parameters,'check_plot'),parameters.check_plot=[];end
if ~isfield(parameters,'verbose'),parameters.verbose=[];end
if ~isfield(parameters,'max_encoding_distance_m'),parameters.max_encoding_distance_m=[];end

% set default values (see header for details)
if isempty(parameters.nightlight_transform_poly),parameters.nightlight_transform_poly=[1 0 0 0];end
if isempty(parameters.restrict_Values_to_country),parameters.restrict_Values_to_country=1;end
if isempty(parameters.grid_spacing_multiplier),parameters.grid_spacing_multiplier=5;end
if isempty(parameters.save_entity),parameters.save_entity=1;end
if isempty(parameters.value_threshold),parameters.value_threshold=0;end
if isempty(parameters.add_distance2coast_km),parameters.add_distance2coast_km=0;end
if isempty(parameters.add_elevation_m),parameters.add_elevation_m=0;end
if isempty(parameters.check_plot),parameters.check_plot=0;end
if isempty(parameters.verbose),parameters.verbose=1;end
if isempty(parameters.max_encoding_distance_m),parameters.max_encoding_distance_m=100000;end

% check if country_names is cell
if ~iscell(country_names), country_names = {country_names}; end

% PARAMETERS

% base entity file, such that we do not need to construct the entity from scratch
entity_file=[climada_global.entities_dir filesep 'entity_template.xls'];
%

if return_parameters,entity=parameters;return;end


if isempty(parameters.entity_filename) % define default entity filename
    parameters.entity_filename=[parameters.entity_filename 'blackmarble_GLOBAL_01x01'];
end

% parameters.entity_filename: complete path, if missing
[fP,fN,fE]=fileparts(parameters.entity_filename);
if isempty(fP),fP=climada_global.entities_dir;end
if isempty(fE),fE='.mat';end
parameters.entity_filename=[fP filesep fN fE];


% load or create all entities for the needed countries
for country_i = 1:length(country_names)
    [country_name_i, country_ISO3_i] = climada_country_name(country_names(country_i));
    country_name_i = strrep(country_name_i,' ','');
    filename_i = [climada_global.entities_dir filesep country_ISO3_i '_' country_name_i '_blackmarble.mat'];
    if ~exist(filename_i,'file')
        % generate the asset data
        entity_i = climada_blackmarble_entity(country_names(country_i));
    else
        % load previously generated assets
        entity_i=climada_entity_load(filename_i,1);
    end
    entity_i.assets.centroid_admin0_ISO3 = repmat({country_ISO3_i},size(entity_i.assets.Value));
    if country_i == 1
        entity = entity_i;
    else
        entity = climada_entity_combine(entity, entity_i);
    end
end % country_i
% entity now contains all the assets of all countries specified in
% country_names



%% project assets on new grid
resolution_centroid_sat = ...
    mean( [mean(diff(centroids.lon)) mean(diff(centroids.lat))] ) /...
    mean( [mean(diff(entity.assets.lon)) mean(diff(entity.assets.lat))] );
if resolution_centroid_sat < 0.8333
    error('projection from one grid to another not implemented yet')
    
elseif resolution_centroid_sat > 1.2 %% review everything
    
    
%     % omit flagged centroids (those with centroid_ID<0)
%     if isfield(centroids,'centroid_ID')
%         centroids.lon=centroids.lon(centroids.centroid_ID>0);
%         centroids.lat=centroids.lat(centroids.centroid_ID>0);
%     end

    % making entity.assets smaller focusing only on the square that has
    % values
    min_lat = min(entity.assets.lat(entity.assets.Value>0))-1;
    max_lat = max(entity.assets.lat(entity.assets.Value>0))+1;
    min_lon = min(entity.assets.lon(entity.assets.Value>0))-1;
    max_lon = max(entity.assets.lon(entity.assets.Value>0))+1;
    
    box_pos2=(entity.assets.lon > min_lon & entity.assets.lon < max_lon & ...
        entity.assets.lat > min_lat & entity.assets.lat < max_lat);
    
    entity.assets.lat = entity.assets.lat(box_pos2);
    entity.assets.lon = entity.assets.lon(box_pos2);
    entity.assets.Value = entity.assets.Value(box_pos2);
    clear box_pos2
    

    % check lat lon dimension (1xn or nx1), now the concatenations works for both dimensions
    [lon_i,lon_j] = size(entity.assets.lon);
    % find unique lat lons
    if lon_j == 1 % was lon_i
        [~,indx, indx2] = unique([entity.assets.lon entity.assets.lat],'rows');
    elseif lon_i == 1 % was lon_j
        [~,indx, indx2] = unique([entity.assets.lon;entity.assets.lat]','rows');
    else
        fprintf('Please check the dimensions of assets.lon and assets.lat.\n')
        return
    end

    
    % start encoding
    n_assets              = length(indx);
    entity_assets_centroid_index = entity.assets.Value*0; % init

    fprintf('encoding %i assets (max distance %d m) ...\n',n_assets,parameters.max_encoding_distance_m);

    % actual projection
    [entity_assets_centroid_index, min_dist] = knnsearch([centroids.lat;centroids.lon]',...
        [entity.assets.lat;entity.assets.lon]','k',1);
    min_dist=sqrt(min_dist)*111.12*1000;
    % project all values from old to new grid
    if any(min_dist > parameters.max_encoding_distance_m) % values to dismiss because of max_encoding_distance_m
        entity_assets_centroid_index(min_dist > parameters.max_encoding_distance_m) = length(centroids.lat) + 1;
        value_centroids = accumarray(entity_assets_centroid_index,entity.assets.Value);
        isgridpoint_centroids = accumarray(entity_assets_centroid_index,entity.assets.isgridpoint,[],@mode);
        %project admin0_ISO3 - more complicated because of char
        [unique_admin0_ISO3,~,index_admin0_ISO3] = unique(entity.assets.centroid_admin0_ISO3);
        index_admin0_ISO3_centroids = accumarray(entity_assets_centroid_index,index_admin0_ISO3,[],@mode);
        unique_admin0_ISO3(end+1) = {'WWW'};
        index_admin0_ISO3_centroids(index_admin0_ISO3_centroids==0) = find(strcmp(unique_admin0_ISO3,'WWW'),1);
        centroid_admin0_ISO3_centroids = unique_admin0_ISO3(index_admin0_ISO3_centroids);
        if parameters.add_distance2coast_km
            distance2coast_km_centroids = accumarray(entity_assets_centroid_index,entity.assets.distance2coast_km,[],@mean);
            distance2coast_km_centroids = distance2coast_km_centroids(1:(end-1));
        end
        if parameters.add_elevation_m
            elevation_m_centroids = accumarray(entity_assets_centroid_index,entity.assets.elevation_m,[],@mean);
            elevation_m_centroids = elevation_m_centroids(1:(end-1));
        end
        value_centroids = value_centroids(1:(end-1));
        isgridpoint_centroids = isgridpoint_centroids(1:(end-1));
        centroid_admin0_ISO3_centroids = centroid_admin0_ISO3_centroids(1:(end-1));
    else
        value_centroids = accumarray(entity_assets_centroid_index,entity.assets.Value);
        isgridpoint_centroids = accumarray(entity_assets_centroid_index,entity.assets.isgridpoint,[],@mode);
        %project admin0_ISO3 - more complicated because of char
        [unique_admin0_ISO3,~,index_admin0_ISO3] = unique(entity.assets.centroid_admin0_ISO3);
        index_admin0_ISO3_centroids = accumarray(entity_assets_centroid_index,index_admin0_ISO3,[],@mode);
        centroid_admin0_ISO3_centroids = unique_admin0_ISO3(index_admin0_ISO3_centroids);
        if parameters.add_distance2coast_km
            distance2coast_km_centroids = accumarray(entity_assets_centroid_index,entity.assets.distance2coast_km,[],@mean);
        end
        if parameters.add_elevation_m
            elevation_m_centroids = accumarray(entity_assets_centroid_index,entity.assets.elevation_m,[],@mean);
        end
    end
    if all(size(value_centroids) ~= size(centroids.lat)) % size is not the same
        value_centroids((end+1):length(centroids.lat)) = 0;
        isgridpoint_centroids((end+1):length(centroids.lat)) = true;
        centroid_admin0_ISO3_centroids((end+1):length(centroids.lat)) = {'WWW'};
        if parameters.add_distance2coast_km
            distance2coast_km_centroids((end+1):length(centroids.lat)) = NaN;
        end
        if parameters.add_elevation_m
            elevation_m_centroids((end+1):length(centroids.lat)) = NaN;
        end
    end

    selection_is_positive = value_centroids > 0;
    value_centroids = value_centroids(selection_is_positive);
    centroids.lon = centroids.lon(selection_is_positive);
    centroids.lat = centroids.lat(selection_is_positive);
    isgridpoint_centroids = isgridpoint_centroids(selection_is_positive);
    centroid_admin0_ISO3_centroids = centroid_admin0_ISO3_centroids(selection_is_positive);
    if parameters.add_distance2coast_km
        distance2coast_km_centroids = distance2coast_km_centroids(selection_is_positive);
    end
    if parameters.add_elevation_m
        elevation_m_centroids = elevation_m_centroids(selection_is_positive);
    end
    clear selection_is_positive
    
else % resolution of satellite grid and centroids grid is similar
    value_centroids = griddata(entity.assets.lat,entity.assets.lon,entity.assets.Value,centroids.lat,centroids.lon);
    % re-normalize to the same sum of assets
    % 
    error('projection from one grid to another not implemented yet')
end


entity.assets.Value = value_centroids;
entity.assets.lon = centroids.lon;
entity.assets.lat = centroids.lat;
entity.assets.isgridpoint = isgridpoint_centroids;
entity.assets.DamageFunID=entity.assets.Value*0+1;
entity.assets.isgridpoint = isgridpoint_centroids;
entity.assets.centroid_admin0_ISO3 = centroid_admin0_ISO3_centroids;
if parameters.add_distance2coast_km
    entity.assets.distance2coast_km = distance2coast_km_centroids;
end
if parameters.add_elevation_m
    entity.assets.elevation_m = elevation_m_centroids;
end

% for consistency, update Deductible and Cover
entity.assets.Deductible=entity.assets.Value*0;
entity.assets.Cover=entity.assets.Value;
entity.assets.Value_unit=repmat({climada_global.Value_unit},size(entity.assets.Value));

if parameters.save_entity
    if parameters.verbose,fprintf('saving entity as %s\n',parameters.entity_filename);end
    entity.assets.filename=parameters.entity_filename;
    try
        save(parameters.entity_filename,'entity');
    catch
        fprintf('saving with -v7.3, might take quite some time ...')
        save(parameters.entity_filename,'entity','-v7.3');
        fprintf(' done\n')
    end
    if parameters.verbose,fprintf('consider encoding entity to a particular hazard, see climada_assets_encode\n');end
end

if parameters.check_plot>2
    hold on
    climada_entity_plot(entity);
    hold off;drawnow
end

end % climada_nightlight_global_entity