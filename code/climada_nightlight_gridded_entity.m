function entity=climada_centroids_generate_nightlight_entity(centroids, parameters, regulargrid_flag)
% country admin0 admin1 entity high resolution
% NAME:
%	climada_centroids_generate_nightlight_entity
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
%   See also: climada_nightlight_entity
% CALLING SEQUENCE:
%   entity=climada_nightlight_global_entity(parameters)
% EXAMPLE:
%   entity=climada_nightlight_global_entity; % global 10km
%   climada_entity_plot(entity,[],1); % visual check
%   parameters=climada_nightlight_global_entity('parameters') % return all default parameters
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   centroids: a structure, with (at least)
%       lon  (1,:): the longitudes   
%       lat   (1,:): the latitudes   
%       centroid_ID(1,:): a unique ID for each centroid, simplest: 1:length(Longitude)
%   parameters: a structure to pass on parameters, with fields as
%       (run parameters=climada_nightlight_global_entity('parameters') to obtain
%       all default values)
%       resolution_km: the resuting resolution, either =1 or =10
%           It is often advisable to first TEST with resolution=10 for
%           speed reasons. If a fully country is selected, default=10, else
%           =1 for admin1
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
%
%           ='ASK' prompt for an image file (without first asking for country
%           where one has to press 'Cancel') to get the to filename prompt
%       regulargrid_flag: select which algorithm to use for translating the
%           grid of the satellite image onto the centroids (1=regular grid
%       save_entity: whether we save the entity (=1, default) or nor (=0).
%       entity_filename: the filename to save the entity to, default is a
%           long one with ISO3, country name, admin1 name, geo coord and
%           resolution. Not used if save_entity=0
%       check_plot: if =1: plot nightlight data with admin0 (countries)
%           superimposed. If=3, plot the resulting asset Values
%       verbose: whether we printf progress to stdout (=1, default) or not (=0)
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
% david.bresch@gmail.com, 20161022, initial
% david.bresch@gmail.com, 20161023, save using -v7.3 if troubles

entity=[]; % init

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% check for arguments
if ~exist('centroids','var'),return;end
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

% PARAMETERS
%
% the file with the full (whole earth) 1x1km nightlights
% -> see climada_nightlight_entity for source and details
%    if this file does not exist, run climada_nightlight_entity first
full_img_filename=[module_data_dir filesep 'F182012.v4c_web.stable_lights.avg_vis.mat'];
%
% admin0 and admin1 shap files (in climada module country_risk):
admin0_shape_file=climada_global.map_border_file; % as we use the admin0 as in next line as default anyway
%
% base entity file, such that we do not need to construct the entity from scratch
entity_file=[climada_global.entities_dir filesep 'entity_template.xls'];
%

if return_parameters,entity=parameters;return;end

% if parameters.resolution_km==10,full_img_filename=low_img_filename;end

if parameters.verbose,fprintf('resolution %ix%i km\n',parameters.resolution_km,parameters.resolution_km);end

% read admin0 (country) shape file (we need this in any case)
admin0_shapes=climada_shaperead(admin0_shape_file);

if ~exist(full_img_filename,'file')
    fprintf('ERROR: run climada_nightlight_entity for at leats one country first\n');
    fprintf('       Note: at same resolution as you will need the global entity\n');
    return
end

% there is a previously saved .mat version of the full image
load(full_img_filename) % loads img
% if exist('night_light','var')
%     % special case, if mid resolution data is in fact stored on full_img_filename_mat
%     img=night_light.values;
%     xx=(night_light.lon_range(2)-night_light.lon_range(1))*(1:size(img,2))/size(img,2)+night_light.lon_range(1);
%     yy=(night_light.lat_range(2)-night_light.lat_range(1))*(1:size(img,1))/size(img,1)+night_light.lat_range(1);
% end % exist('night_light','var')

if isempty(parameters.entity_filename) % define default entity filename
    if parameters.resolution_km==10
        parameters.entity_filename=[parameters.entity_filename 'GLOBAL_10x10'];
    else
        parameters.entity_filename=[parameters.entity_filename 'GLOBAL_01x01'];
    end
end

% parameters.entity_filename: complete path, if missing
[fP,fN,fE]=fileparts(parameters.entity_filename);
if isempty(fP),fP=climada_global.entities_dir;end
if isempty(fE),fE='.mat';end
parameters.entity_filename=[fP filesep fN fE];

fprintf('creating regulat grid ...');
[X_sat,Y_sat]=meshgrid(xx,yy); % construct regular grid
fprintf(' done\n');

% convert to daouble (from uint8)
VALUES_sat=double(img);

%% do projection onto new grid here now with nightlight, but in future it makes more sence to do it below with $-amount
% % get grid from centroids
% X = centroids.lat;
% Y = centroids.lon;
% % project nightlight onto new grid
% VALUES = griddata(X_sat,Y_sat,VALUES_sat,X,Y);

%% continue as usual

X = X_sat;
Y = Y_sat;

VALUES = VALUES_sat;

if parameters.check_plot
    
    %     % plot land and ocean in light blue
    %     climada_plot_world_borders(-1);
    %     hold on
    
    % plot the image (kind of 'georeferenced')
    pcolor(X,Y,VALUES);
    hold on
    shading flat
    axis equal
    xlim([-180 180]);
    ylim([-90 90]);
    axis off
    set(gcf,'Color',[1 1 1]) % whithe figure background
    % plot admin0 (country) shapes
    for shape_i=1:length(admin0_shapes)
        plot(admin0_shapes(shape_i).X,admin0_shapes(shape_i).Y,'-w','LineWidth',1);
    end % country_i
    
end % check_plot

if exist(entity_file,'file')
    entity=climada_entity_read(entity_file,'SKIP'); % read the empty entity
    if isfield(entity,'assets'),entity=rmfield(entity,'assets');end
else
    fprintf('WARNING: base entity %s not found, entity just entity.assets\n',entity_file);
end

entity.assets.comment=sprintf('generated by %s at %s',mfilename,datestr(now));
entity.assets.filename=parameters.img_filename;
entity.assets.lon=X(:)';
entity.assets.lat=Y(:)';
entity.assets.Value=VALUES(:)'; % one dimension
entity.assets.Value_unit=repmat({climada_global.Value_unit},size(entity.assets.Value));

if sum(parameters.nightlight_transform_poly)>0 && max(entity.assets.Value)>0
    entity.assets.Value=entity.assets.Value/max(entity.assets.Value); % normalize to range [0..1]
    entity.assets.Value = polyval(parameters.nightlight_transform_poly,entity.assets.Value); % ***********
    entity.assets.Value=entity.assets.Value/max(entity.assets.Value); % normalize to range 0..1
    entity.assets.nightlight_transform_poly=parameters.nightlight_transform_poly;
    entity.assets.comment='nightlights transformed using polynomial, then normalized to 1';
    if parameters.verbose,fprintf('%s\n',entity.assets.comment);end
end % parameters.nightlight_transform_poly

if parameters.restrict_Values_to_country
    
    entity.assets.isgridpoint=logical(entity.assets.lon*0+1); % init
    entity.assets.centroid_admin0_ISO3=repmat({'WWW'},size(entity.assets.Value));
    
    if parameters.add_distance2coast_km,...
            entity.assets.distance2coast_km=entity.assets.lon*0-999;end % init
    
    if parameters.add_elevation_m,...
            entity.assets.elevation_m=entity.assets.lon*0;end % init
    
    
    for shape_i=1:length(admin0_shapes)
        
        centroids_in_shape=climada_inpolygon(centroids.lon,centroids.lat,admin0_shapes(shape_i).X,admin0_shapes(shape_i).Y);
        if sum(centroids_in_shape) <= 0
            next
        end
        fprintf('processing %s (%s) ...',admin0_shapes(shape_i).ADM0_A3,admin0_shapes(shape_i).NAME);
        
        % in order to speed up inpolygon, only run for points within a box
        % around the country
        
        min_X=min(admin0_shapes(shape_i).X)-1;
        max_X=max(admin0_shapes(shape_i).X)+1;
        min_Y=min(admin0_shapes(shape_i).Y)-1;
        max_Y=max(admin0_shapes(shape_i).Y)+1;
        country_index=logical(entity.assets.lon*0); % init
        
        box_pos=find(entity.assets.lon > min_X & entity.assets.lon < max_X & ...
            entity.assets.lat > min_Y & entity.assets.lat < max_Y);
        
        country_hit=climada_inpolygon(entity.assets.lon(box_pos),entity.assets.lat(box_pos),admin0_shapes(shape_i).X,admin0_shapes(shape_i).Y);
        country_index(box_pos)=country_hit;
        
        % for TEST
        %plot(entity.assets.lon(box_pos),entity.assets.lat(box_pos),'.r');
        %hold on
        %plot(entity.assets.lon(country_index),entity.assets.lat(country_index),'.g');
        
        if sum(country_index)>0
            
            fprintf(' %i centroids ...',sum(country_index));
            
            entity.assets.isgridpoint(country_index)=false; % is not a grid point
            
            % we use a dummy entity to get the scaling factors back from climada_entity_value_GDP_adjust_one
            dummy_entity.assets.admin0_ISO3=admin0_shapes(shape_i).ADM0_A3; % pass the ISO3 code
            dummy_entity.assets.Value=1;dummy_entity.assets.GDP_value=1;dummy_entity.assets.scale_up_factor=1; % init
            dummy_entity=climada_entity_value_GDP_adjust_one(dummy_entity); % obtain scaling
            
            entity.assets.Value(country_index)=entity.assets.Value(country_index)/sum(entity.assets.Value(country_index)); % normalize to 1
            entity.assets.Value(country_index)=entity.assets.Value(country_index)*dummy_entity.assets.Value; % scale
            
            entity.assets.centroid_admin0_ISO3(country_index)=repmat({dummy_entity.assets.admin0_ISO3},1,sum(country_index));
            
            if parameters.add_distance2coast_km % add distance to coast
                if parameters.verbose,fprintf(' d2coast ...');end
                entity.assets.distance2coast_km(country_index)=...
                    climada_distance2coast_km(entity.assets.lon(country_index),entity.assets.lat(country_index));
            end
            
            if parameters.add_elevation_m % add elevation
                if exist('etopo_get','file')
                    if parameters.verbose,fprintf(' elev ...');end
                    entity.assets.elevation_m(country_index)=...
                        etopo_elevation_m(entity.assets.lon(country_index),entity.assets.lat(country_index));
                end
            end
            
        end % sum(country_hit)>0
        
        fprintf(' done\n');
        
    end % shape_i
    
end % params.restrict_Values_to_country

entity.assets.DamageFunID=entity.assets.Value*0+1;
entity.assets.reference_year=climada_global.present_reference_year;

% for consistency, update Deductible and Cover
entity.assets.Deductible=entity.assets.Value*0;
entity.assets.Cover=entity.assets.Value;

if parameters.value_threshold>0
    valid_pos=find(entity.assets.Value>parameters.value_threshold);
    fprintf('keeping only %i (%2.2f%%) centroids with Value > %f\n',...
        length(valid_pos),length(valid_pos)/length(entity.assets.Value)*100,parameters.value_threshold);
    entity.assets.lon=entity.assets.lon(valid_pos);
    entity.assets.lat=entity.assets.lat(valid_pos);
    entity.assets.Value=entity.assets.Value(valid_pos);
    entity.assets.DamageFunID=entity.assets.DamageFunID(valid_pos);
    entity.assets.Deductible=entity.assets.Deductible(valid_pos);
    entity.assets.Cover=entity.assets.Cover(valid_pos);
end % parameters.value_threshold>=0

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