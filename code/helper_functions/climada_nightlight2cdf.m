function ok=climada_nightlight2cdf(parameters)
% country admin0 admin1 entity high resolution
% NAME:
%	climada_nightlight2cdf
% PURPOSE:
%   save high-resolution (1km!) or mid-resolution (10km) night light data
%   as netCDF file (using ncwrite), use ncdisp to check the file
%
%   Reads an image file with nightlight density and scales to proxy for asset values.
%
%   The original nightlight intensities are first scaled to the range
%   [0..1], then transformed using a polynomial (see
%   parameters.nightlight_transform_poly).
%
%   If the high-resolution night light image is stored locally (about 700MB
%   as tiff, after first call about 24MB as .mat), the code works from
%   there.
%   See http://ngdc.noaa.gov/eog/dmsp/downloadV4composites.html#AVSLCFC3
%   to obtain the file
%   http://ngdc.noaa.gov/eog/data/web_data/v4composites/F182012.v4.tar
%   and unzip the file F182012.v4c_web.stable_lights.avg_vis.tif in there
%   to the /data folder of country_risk module. As the .tif is so much
%   larger, the climada module country_risk comes with the .mat file, but
%   does not contain the original (.tif).
%
%   next step: ncdisp % to check the file
% CALLING SEQUENCE:
%   ok=climada_nightlight2cdf(parameters)
% EXAMPLE:
%   ok=climada_nightlight2cdf;
%   parameters=climada_nightlight2cdf('parameters') % return all default parameters
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   parameters: a structure to pass on parameters, with fields as
%       (run parameters=climada_nightlight2cdf('parameters') to obtain
%       all default values)
%       resolution_km: the resuting resolution, either =1 (default) or =10
%       nightlight_transform_poly: the polynomial coefficients to transform
%           the nightlight intensity (usually in the range 0..62) to proxy
%           asset values. Evaluated using polyval, i.e.
%           value=polyval(parameters.nightlight_transform_poly,nightlight_intensity)
%           Default=[0 1 0 0], which means Value=nightlight_intensity^2
%           After this Values are normalized to sum up to 1.
%           Note that if a whole country is requested, Values are then
%           scaled to sum up to GDP*(income_group+1).
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
%       netcdf_filename: the filename to save the netCDF file to, default
%           is same folder as original image, just with extension .cdf
%       verbose: whether we printf progress to stdout (=1, default) or not (=0)
% OUTPUTS:
%   ok: =1, if successful
% RESTRICTIONS:
% MODIFICATION HISTORY:
% david.bresch@gmail.com, 20170119, initial, based on climada_nightlight_entity

ok=0; % init

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% check for arguments
if ~exist('parameters','var'),parameters=struct;end

% locate the moduel's data
module_data_dir=[fileparts(fileparts(fileparts(mfilename('fullpath')))) filesep 'data'];

if strcmpi(parameters,'parameters'),
    return_parameters=1;clear parameters
    parameters=struct;
else
    return_parameters=0;
end

% check for some parameter fields we need
if ~isfield(parameters,'resolution_km'),parameters.resolution_km=[];end
if ~isfield(parameters,'nightlight_transform_poly'),parameters.nightlight_transform_poly=[];end
if ~isfield(parameters,'img_filename'),parameters.img_filename='';end
if ~isfield(parameters,'netcdf_filename'),parameters.netcdf_filename='';end
if ~isfield(parameters,'verbose'),parameters.verbose=[];end

% set default values (see header for details)
if isempty(parameters.resolution_km),parameters.resolution_km=1;end
%
% test using:
%   x=0:0.001:1;plot(x,x),hold on;
%   plot(x,polyval(parameters.nightlight_transform_poly,x),'-r')
%   plot(x,0.0000*x.^0 + -0.0817*x.^1 + 0.0172*x.^2),'-r')
% title('x^3');
%if isempty(parameters.nightlight_transform_poly),parameters.nightlight_transform_poly=[1 0 0 0];end
if isempty(parameters.nightlight_transform_poly),parameters.nightlight_transform_poly=[0 1 0 0];end

if isempty(parameters.verbose),parameters.verbose=1;end

% PARAMETERS
%
% the file with the full (whole earth) 1x1km nightlights
% see http://ngdc.noaa.gov/eog/dmsp/downloadV4composites.html#AVSLCFC3
% and the detailed instructions where to obtain in the file
% F182012.v4c_web.stable_lights.avg_vis.txt in the module's data dir.
full_img_filename=[module_data_dir filesep 'F182012.v4c_web.stable_lights.avg_vis.tif'];
min_South=-65; % degree, defined on the webpage above
max_North= 75; % defined on the webpage above
%
% low resolution file (approx. 10x10km):
low_img_filename=[module_data_dir filesep 'night_light_2010_10km.png'];
% Note: you might check whether the same min_South and max_Nort happly
%
% a TEST region to show if verbose=1
TEST_region=[-5 5 45 55]; % [minlon maxlon minlat maxlat]


if parameters.resolution_km==10,full_img_filename=low_img_filename;end
parameters.img_filename=full_img_filename;
if isempty(parameters.netcdf_filename)
    parameters.netcdf_filename=strrep(parameters.img_filename,'.tif','.nc');
    parameters.netcdf_filename=strrep(parameters.netcdf_filename,'.png','.nc');
end
if return_parameters,ok=parameters;return;end % special case, return the full parameters strcture

if parameters.verbose,fprintf('resolution %ix%i km\n',parameters.resolution_km,parameters.resolution_km);end

if strcmp(parameters.img_filename,'ASK')
    % Prompt for image file
    parameters.img_filename=[climada_global.data_dir filesep '*.tiff'];
    [filename, pathname] = uigetfile(parameters.img_filename, 'Select night light image:');
    if isequal(filename,0) || isequal(pathname,0) % Cancel pressed
        return
    else
        parameters.img_filename=fullfile(pathname,filename);
    end
end

full_img_filename_mat=strrep(parameters.img_filename,'.tif','.mat');
full_img_filename_mat=strrep(full_img_filename_mat,'.png','.mat');

if climada_check_matfile(parameters.img_filename,full_img_filename_mat)
    fprintf('loading %s ...',full_img_filename_mat)
    load(full_img_filename_mat)
    fprintf(' done\n')
    %   img                      16801x43201            725820001  uint8
    %   xx                           1x43201               345608  double
    %   yy                           1x16801               134408  double
else
    % there is a full image
    if parameters.verbose,fprintf('reading full global high-res image, takes ~20 sec (%s)\n',parameters.img_filename);end
    if exist(parameters.img_filename,'file')
        img=imread(parameters.img_filename);
        img=img(end:-1:1,:); % switch for correct order in lattude (images are saved 'upside down')
    else
        fprintf('Error: full-resolution global night light density image not found, aborted\n')
        fprintf('> Please follow instructions in:\n\t%s\n',...
            [module_data_dir filesep 'F182012.v4c_web.stable_lights.avg_vis.txt'])
        return
    end
    
    xx=360*(1:size(img,2))/size(img,2)+(-180); % -180..180
    yy=(max_North-min_South)*(1:size(img,1))/size(img,1)+min_South;
    save(full_img_filename_mat,'img','xx','yy'); % for fast access next time
    
    fprintf('saved in %s\n',full_img_filename_mat);
end

% rename
nightlight=double(img);clear img
nightlight_lon=xx;
nightlight_lat=yy;
fprintf('lon %2.2f .. %2.2f, lat %2.2f .. %2.2f\n',min(nightlight_lon),max(nightlight_lon),min(nightlight_lat),max(nightlight_lat));

if parameters.verbose
    pos_x=find(nightlight_lon>TEST_region(1) & nightlight_lon<TEST_region(2));
    pos_y=find(nightlight_lat>TEST_region(3) & nightlight_lat<TEST_region(4));
    x1=min(pos_x);x2=max(pos_x);
    y1=min(pos_y);y2=max(pos_y);
    TEST_val=nightlight(y2:-1:y1,x1:x2);
    max_TEST_val=max(max(TEST_val));
    subplot(2,2,1)
    image(nightlight_lon(x1:x2),nightlight_lat(y2:-1:y1),TEST_val(end:-1:1,:));title('original');
    subplot(2,2,3)
    hist(TEST_val)
end
if sum(abs(parameters.nightlight_transform_poly))>0 % scale the values
    fprintf('applying transformation ...');
    max_value=max(max(nightlight));
    nightlight=nightlight/max_value; % normalize to 0..1
    nightlight=polyval(parameters.nightlight_transform_poly,nightlight);
    fprintf(' done\n');
else
    fprintf('no transformation applied');
end
if parameters.verbose
    new_TEST_val=nightlight(y2:-1:y1,x1:x2);
    new_max_TEST_val=max(max(new_TEST_val));
    new_TEST_val=new_TEST_val/new_max_TEST_val*max_TEST_val;
    subplot(2,2,2)
    image(nightlight_lon(x1:x2),nightlight_lat(y2:-1:y1),new_TEST_val(end:-1:1,:))
    title('transformed ( )^3')
    subplot(2,2,4)
    hist(new_TEST_val)
end

% save as netCDF
nightlight_size=size(nightlight);
nccreate(parameters.netcdf_filename,'nightlight',...
    'Dimensions', {'lat',nightlight_size(1),'lon',nightlight_size(2)});
ncwrite(parameters.netcdf_filename,'nightlight', nightlight);
nccreate(parameters.netcdf_filename,'lat','Dimensions',{'la1',1,'la2', nightlight_size(1)});
nccreate(parameters.netcdf_filename,'lon','Dimensions',{'lo1',1,'lo2', nightlight_size(2)});
ncwrite(parameters.netcdf_filename,'lat', nightlight_lat);
ncwrite(parameters.netcdf_filename,'lon', nightlight_lon);
fprintf('saved as %s\n',parameters.netcdf_filename);

if parameters.verbose
    ncdisp(parameters.netcdf_filename)
end

end % climada_nightlight2cdf