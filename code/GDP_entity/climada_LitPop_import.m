function [LitPopulation, gpw_index, gpw_lon, gpw_lat] = climada_LitPop_import(source_folder,target_res,force_reread,save_flag,save_intermediate_flag,plot_flag)
% MODULE:
%   core / country risk (?)
% NAME:
%   climada_inpolygon
% PURPOSE:
%     This script imports the data from the files of the blackmarble nightlight
%     and the Gridded Population of the World (GPW) products and creates a global "Litpouplation" product.
%     The Litpopulation method is derived from: Zhao, N., Liu, Y., Cao, G., Samson, E. L., & Zhang, J. (2017).
%     "Forecasting China?s GDP at the pixel level using nighttime lights time series and population images". GIScience & Remote Sensing, 54(3), 407-425.
% 
%     Please download the following datasets first:
%     - Blackmarble: Full Resolution (500m / 15 arc-sec) By Region - 2016 Grayscale"
%     (https://earthobservatory.nasa.gov/Features/NightLights/page3.php).
%     - GPW, Population Count, v4.10, for year 2015, GeoTiff, 30 arc-sec resoultion
%     http://sedac.ciesin.columbia.edu/data/collection/gpw-v4/sets/browse
% 
%     Note that the datasets have to be forced to the same resolution first (downscaling of BlackMarble).
%     This can automatically by this script.
%     GPW data are only avaiable for latitude -60 to +85 degree, hence the
%     blackmarble file is also cropped accordingly. 
%     If external procedure for the downscaling is preferred: using the GDAL library is recommended.
%     With the tool gdalwarp from that library, the resolution of BM can be changed to 30 arc-sec with the
%     following command:
%     gdalwarp -tr 0.008333333333 0.00833333333 -r average BlackMarble_2016_A1_geo_gray.tif BlackMarble_2016_A2_geo_gray.tif BlackMarble_2016_B1_geo_gray.tif BlackMarble_2016_B2_geo_gray.tif BlackMarble_2016_C1_geo_gray.tif BlackMarble_2016_C2_geo_gray.tif BlackMarble_2016_D1_geo_gray.tif BlackMarble_2016_D2_geo_gray.tif Output_gdalwarp.tif
%     Then gdaltranslate can be used for compression, otherwise the 
%     filesize is very large (larger than the orignal file):
%     gdal_translate -co compress=LZW output_gdalwarp.tif output_gdaltranslate.tif
%     Note that gdal_translate can also be used for cropping.
%     E.g. adding -srcwin 0 600 43200 17400 would crop the file to match
%     GPWs range.
% 
% CALLING SEQUENCE:
%   [LitPopulation, gpw_index, gpw_lat, gpw_lon] = climada_LitPopulation_import(source_folder,target_res,force_reread,save_flag,save_intermediate_flag,plot_flag)
% EXAMPLE:
%   [LitPopulation, gpw_index, gpw_lat, gpw_lon] = climada_LitPopulation_import
% INPUTS:
%   xq,yq,xv,yv: see help inpolygo
% OPTIONAL INPUT PARAMETERS:
%   source_folder: Folder, where gpw and BM raw data are stored. adfj dfj
%       Prompted if empty.
%   target_res: Target resolution in arc-sec:
%       available options are (other values will be automatically rounded to the next available option):
%       - 30 arc-sec (~1 km), DEFAULT
%       - 60 arc-sec (~2 km)
%       - 120 arc-sec (~4 km)
%       - 300 arc-sec (5 arc-min, ~10 km)
%       - 600 arc-sec (10 arc-min, ~20 km)
%       - 3600 arc-sec (1 degree, ~110 km)
%       More target_resolution can easily be implemented in the code
%   force_reread: If =1, existing *.mat files are ignored and
%       raw data(i.e. base GPW and BM) is imported again (DEFAULT=0).
%   save_flag: If =0, data is not saved to disk (DEFAULT=1).
%   save_intermediate_flag, If =1, also intermediate data (population and
%       nightlight intensity) is stored to disk (DEFAULT=0).
%   plot_flag: If =0, no plot of data is produced (DEFAULT=1).
%       check_plot: =1 to shown the result (DEFAULT=0)
% OUTPUTS:
%   LitPopulation: The LitPopulation value for each grid point globally in
%       a column vector. Resultion: [((3600/target_res)*180*360) 1]
%   gpw_index: A function which calculates the indices for a given bounding
%       box, matching the chosen resolution.
%   gpw_lat: A function which calculates the latitude from given indices.
%       In a way the inversion operation of gpw_index.
%   gpw_lon: The same as gpw_lat, but for longitudes.

% Thomas Roosli, thomas.roeoesli@usys.ethz.ch, initial Blackmarble script
% Dario Stocker, dario.stocker@gmail.com, 201803, adapted from Blackmarble to "LitPopulation"
% Samuel Eberenz, eberenz@posteo.eu, 20180430, changed filename for save from GPW_BM_LitPopulation30arcsec.mat to GPW_BM_LitPopulation_300arcsec.mat




%% Adjust folder and file names accordingly, assumes Both files (black marble and GPW are in the same folder

% Check arguments
if ~exist('source_folder','var'),source_folder=[];end
if ~exist('target_res','var'),target_res=[];end
if ~exist('force_reread','var'),force_reread=0;end
if ~exist('save_flag','var'),save_flag=1;end
if ~exist('save_intermediate_flag','var'),save_intermediate_flag=0;end
if ~exist('plot_flag','var'),plot_flag=1;end


module_data_dir=[fileparts(fileparts(which('centroids_generate_hazard_sets'))) filesep 'data'];


% set target resolution
if ~isscalar(target_res)
    target_res=30;
    fprintf(['None or invalid target resolution. Resorting to default resolution (30 arc-sec).\n']);
else
    possible_res=[30 60 120 300 600 3600];
    if interp1(possible_res,possible_res,target_res,'nearest','extrap') ~= target_res
        target_res = interp1(possible_res,possible_res,target_res,'nearest','extrap');
        fprintf(['Target resolution adjusted. It was set to ', num2str(target_res), ' arc-sec\n']);
    end
    clearvars possible_res;
end


gpw_loaded=0;
bm_loaded=0;

% Conversion Factor for Resolution Change. The "base" resultion is 30 arc-sec.
conv_factor=target_res/30;

gpw_folder = source_folder;

if ~save_intermediate_flag==1
    save_intermediate_flag=0;
end


if ~force_reread==1
        try
        load([module_data_dir filesep 'BlackMarble_2016_geo_gray_30arcsec.mat'],'nightlight_intensity');
   
        fprintf('BM data loaded from mat file.\n');
        
        if numel(nightlight_intensity)==43200*86400 % ensure source data has the correct dimensions
            bm_regridded=bm_regrid(nightlight_intensity,conv_factor*2); %factor needs to be multiplied by 2
            nightlight_intensity=bm_regridded;
            clearvars bm_regridded;
        end
        
        if target_res~=30
            fprintf('Attempting converting resolution for BM\n');
            bm_regridded=bm_regrid(nightlight_intensity,conv_factor);
            nightlight_intensity=bm_regridded;
            clearvars bm_regridded;
            fprintf('BM resolution conversion successful\n');
        end
        bm_loaded=1;
    catch
        bm_loaded=0;
        clearvars nightlight_intensity;
    end
    try
        load([module_data_dir filesep 'GPW_Population_2015_30arcsec.mat']);

        fprintf('GPW data loaded from mat file.\n');
        
        if target_res~=30
            if numel(gpw_popNum)==21600*43200 % ensure source data has the correct dimensions
                fprintf('Attempting converting resolution for GPW\n');
                gpw_regridded=gpw_regrid(gpw_popNum,conv_factor);
                gpw_popNum=gpw_regridded;
                clearvars gpw_regridded;
                fprintf('GPW resolution conversion successful\n');
            end
        end
        gpw_loaded=1;
    catch
        gpw_loaded=0;
    end
end



if bm_loaded==0
    try
        nightlight_intensity=climada_blackmarble_read(gpw_folder,save_intermediate_flag);
        if target_res ~= 30
            fprintf('Attempting converting resolution for BM\n');
            bm_regridded=bm_regrid(nightlight_intensity,conv_factor);
            nightlight_intensity=bm_regridded;
            clearvars bm_regridded;
            fprintf('BM resolution conversion successful\n');
        end
        
        
        bm_loaded=1;
        fprintf('BM data successfully initialised.\n');
    catch
        %lasterr
        error('Error: could not read BM data. Operation aborted.');
    end
end

if gpw_loaded==0
    try
        gpw_popNum=climada_gpw_read(gpw_folder,save_intermediate_flag);
        if target_res ~= 30
            fprintf('Attempting to convert resolution of GPW data.\n');
            gpw_regridded=gpw_regrid(gpw_popNum,conv_factor);
            gpw_popNum=gpw_regridded;
            clearvars gpw_target_res;
        end
        gpw_loaded=1;
        fprintf('GPW data successfully initialised.\n');
    catch
        %lasterr
        error('Error: could not read GPW data. Operation aborted.');
    end
end


if gpw_loaded==1 && bm_loaded==1
    if size(gpw_popNum) == size(nightlight_intensity)
        try      
            % LitPopulation calculation. Matrices are divided to multiple piceses to
            % prevent memory errors for high resolutions. All allowed
            % resoultions are divisible by four, hence no further check is neccessary
            
            fprintf('Calculating LitPopulation');
            d=length(nightlight_intensity)/4;
            
            bm_shift_1 = sparse(nightlight_intensity(d*0+1:d*1));
            fprintf('.');
            
            bm_shift_2 = sparse(nightlight_intensity(d*1+1:d*2));
            fprintf('.');
            
            bm_shift_3 = sparse(nightlight_intensity(d*2+1:d*3));
            fprintf('.');
            
            bm_shift_4 = sparse(nightlight_intensity(d*3+1:d*4));
            fprintf('.');
            clearvars nightlight_intensity;

            % The same for GPW data
            gpw_popNum_wholeGrid1 = sparse(gpw_popNum(d*0+1:d*1));
            fprintf('.');
            gpw_popNum_wholeGrid2 = sparse(gpw_popNum(d*1+1:d*2));
            fprintf('.');
            gpw_popNum_wholeGrid3 = sparse(gpw_popNum(d*2+1:d*3));
            fprintf('.');
            gpw_popNum_wholeGrid4 = sparse(gpw_popNum(d*3+1:d*4));
            fprintf('.');

            clearvars gpw_popNum;

            % Now create the "lit-population" (multiplication of raw NL value and population per pixel)
            % Shift all Nightlight values by +1 to retain unlit but populated areas
            combined_NLpopNum1 = sparse(gpw_popNum_wholeGrid1.*(bm_shift_1+1));
            clearvars gpw_popNum_wholeGrid1 bm_shift_1;
            fprintf('.');
            combined_NLpopNum2 = sparse(gpw_popNum_wholeGrid2.*(bm_shift_2+1));
            clearvars gpw_popNum_wholeGrid2 bm_shift_2;
            fprintf('.');
            combined_NLpopNum3 = sparse(gpw_popNum_wholeGrid3.*(bm_shift_3+1));
            clearvars gpw_popNum_wholeGrid3 bm_shift_3;
            fprintf('.\n');
            combined_NLpopNum4 = sparse(gpw_popNum_wholeGrid4.*(bm_shift_4+1));
            clearvars gpw_popNum_wholeGrid4 bm_shift_4;

            % combine the four submatrices to one entire
            LitPopulation = [combined_NLpopNum1; combined_NLpopNum2; combined_NLpopNum3; combined_NLpopNum4];

            clearvars combined_NLpopNum*;
            fprintf('LitPopulation calculation successful.\n');


        catch
            %lasterr;
            error('Could not calculate LitPopulation. Operation aborted.')
        end
    else
        %lasterr
        error('Error: Dimension mismatch. Operation aborted');
    end
else
    %lasterr
    error('Data could not be initialised. Operation aborted');
end

% Create indexing fucntions to be stored along with the data. Expressed as a function to avoid running out of memory. Note that lats/lons
% are defined for the entire global grid, not just for available data (-180 to 180 and 85 to -60) to easily accomodate potential changes in the
% data basis.

% These are the orignal functions, used for the 30 arc-sec resolution
% gpw_lon = @(x)(-180+((1/120)/2)+((1/120)*floor((double(x)-1)/21600)));
% gpw_lat = @(x)(90-((1/120)/2)-(1/120)*(mod(double(x)-1,21600)));
% gpw_index = @(lat_min,lat_max,lon_min,lon_max)(uint32(interp1([1 2], [linspace((((min([(floor(((max([lon_min-(((1/120)/2)) -180]))-(-180))/(1/120))+1) 43200]))-1)*(180/(1/120))+(max([(ceil((90-(min([lat_max+(((1/120)/2)) 90])))/(1/120))) 1]))), (((max([(ceil(((min([lon_max+(((1/120)/2)) 180]))-(-180))/(1/120))) 1]))-1)*(180/(1/120))+(max([(ceil((90-(min([lat_max+(((1/120)/2)) 90])))/(1/120))) 1]))), ((max([(ceil(((min([lon_max+(((1/120)/2)) 180]))-(-180))/(1/120))) 1]))-(min([(floor(((max([lon_min-(((1/120)/2)) -180]))-(-180))/(1/120))+1) 43200]))+1)); linspace((((min([(floor(((max([lon_min-(((1/120)/2)) -180]))-(-180))/(1/120))+1) 43200]))-1)*(180/(1/120))+(min([(ceil((90-(max([lat_min-(((1/120)/2)) -90])))/(1/120))) 21600]))), (((max([(ceil(((min([lon_max+(((1/120)/2)) 180]))-(-180))/(1/120))) 1]))-1)*(180/(1/120))+(min([(ceil((90-(max([lat_min-(((1/120)/2)) -90])))/(1/120))) 21600]))), ((max([(ceil(((min([lon_max+(((1/120)/2)) 180]))-(-180))/(1/120))) 1]))-(min([(floor(((max([lon_min-(((1/120)/2)) -180]))-(-180))/(1/120))+1) 43200]))+1))], linspace(1, 2, ((min([(ceil((90-(max([lat_min-(((1/120)/2)) -90])))/(1/120))) 21600]))-(max([(ceil((90-(min([lat_max+(((1/120)/2)) 90])))/(1/120))) 1]))+1)))));

% Dynamically craete the functions to match the chosen resolution. The use of eval shall be forgiven :)
eval(['gpw_lon = @(x)(-180+((1/', num2str(3600/target_res), ')/2)+((1/', num2str(3600/target_res), ')*floor((double(x)-1)/', num2str(180*(3600/target_res)), ')));']);
eval(['gpw_lat = @(x)(90-((1/', num2str(3600/target_res), ')/2)-(1/', num2str(3600/target_res), ')*(mod(double(x)-1,', num2str(180*(3600/target_res)), ')));']);
eval(['gpw_index = @(lat_min,lat_max,lon_min,lon_max)(uint32(interp1([1 2], [linspace((((min([(floor(((max([lon_min-(((1/', num2str(3600/target_res), ')/2)) -180]))-(-180))/(1/', num2str(3600/target_res), '))+1) ', num2str(360*(3600/target_res)), ']))-1)*(180/(1/', num2str(3600/target_res), '))+(max([(ceil((90-(min([lat_max+(((1/', num2str(3600/target_res), ')/2)) 90])))/(1/', num2str(3600/target_res), '))) 1]))), (((max([(ceil(((min([lon_max+(((1/', num2str(3600/target_res), ')/2)) 180]))-(-180))/(1/', num2str(3600/target_res), '))) 1]))-1)*(180/(1/', num2str(3600/target_res), '))+(max([(ceil((90-(min([lat_max+(((1/', num2str(3600/target_res), ')/2)) 90])))/(1/', num2str(3600/target_res), '))) 1]))), ((max([(ceil(((min([lon_max+(((1/', num2str(3600/target_res), ')/2)) 180]))-(-180))/(1/', num2str(3600/target_res), '))) 1]))-(min([(floor(((max([lon_min-(((1/', num2str(3600/target_res), ')/2)) -180]))-(-180))/(1/', num2str(3600/target_res), '))+1) ', num2str(360*(3600/target_res)), ']))+1)); linspace((((min([(floor(((max([lon_min-(((1/', num2str(3600/target_res), ')/2)) -180]))-(-180))/(1/', num2str(3600/target_res), '))+1) ', num2str(360*(3600/target_res)), ']))-1)*(180/(1/', num2str(3600/target_res), '))+(min([(ceil((90-(max([lat_min-(((1/', num2str(3600/target_res), ')/2)) -90])))/(1/', num2str(3600/target_res), '))) ', num2str(180*(3600/target_res)), ']))), (((max([(ceil(((min([lon_max+(((1/', num2str(3600/target_res), ')/2)) 180]))-(-180))/(1/', num2str(3600/target_res), '))) 1]))-1)*(180/(1/', num2str(3600/target_res), '))+(min([(ceil((90-(max([lat_min-(((1/', num2str(3600/target_res), ')/2)) -90])))/(1/', num2str(3600/target_res), '))) ', num2str(180*(3600/target_res)), ']))), ((max([(ceil(((min([lon_max+(((1/', num2str(3600/target_res), ')/2)) 180]))-(-180))/(1/', num2str(3600/target_res), '))) 1]))-(min([(floor(((max([lon_min-(((1/', num2str(3600/target_res), ')/2)) -180]))-(-180))/(1/', num2str(3600/target_res), '))+1) ', num2str(360*(3600/target_res)), ']))+1))], linspace(1, 2, ((min([(ceil((90-(max([lat_min-(((1/', num2str(3600/target_res), ')/2)) -90])))/(1/', num2str(3600/target_res), '))) ', num2str(180*(3600/target_res)), ']))-(max([(ceil((90-(min([lat_max+(((1/', num2str(3600/target_res), ')/2)) 90])))/(1/', num2str(3600/target_res), '))) 1]))+1)))));']);

%% Save data to a mat file in climada data

if ~save_flag==0
    module_data_dir=[fileparts(fileparts(which('centroids_generate_hazard_sets'))) filesep 'data'];
    save([module_data_dir filesep 'GPW_BM_LitPopulation_', num2str(target_res), 'arcsec.mat'],'LitPopulation','gpw_lat','gpw_lon','gpw_index','-v7.3');
end

% plot a sample of the map (every 50th point)
if ~plot_flag==0
    if target_res < 300
        img_res=50;
    else
        img_res=1;
    end
    figure; plotclr(gpw_lon(1:img_res:(length(LitPopulation))),gpw_lat(1:img_res:(length(LitPopulation))),double(LitPopulation(1:img_res:(length(LitPopulation)))));
end

%return;

end

%% Local functions: Changing the resolution of raw data
% 
% Local function to change the resolution of the GPW data.
% Here, the concerning data points are ADDED (to retain the same total population)
function gpw_target_res = gpw_regrid(gpw_orig,conv_factor)

gpw_orig=reshape(gpw_orig,[21600 43200]);
temp_grid=zeros(21600/conv_factor,43200/conv_factor);
for i = 1:size(temp_grid,1)
    for j= 1:size(temp_grid,2)
        temp_grid(i,j)=sum(sum(gpw_orig(((i-1)*conv_factor+1):((i-1)*conv_factor+conv_factor),((j-1)*conv_factor+1):((j-1)*conv_factor+conv_factor))));
    end
end

% See if converted data is far off
if ~(sum(sum(temp_grid))==sum(sum(gpw_orig)))
    fprintf(['Warning: The converted GPW data deviates by ', num2str(((sum(sum(temp_grid))/sum(sum(gpw_orig)))-1)*100), '%% from the original\n']);
end
clearvars gpw_orig;
gpw_target_res=sparse(reshape(temp_grid,[21600*43200/(conv_factor^2) 1]));
clearvars temp_grid;

end


% Local function to change the resolution of the BM data.
% Here, the concerning data points are averaged
function bm_target_res = bm_regrid(bm_orig,conv_factor)
orig_mean=(mean(mean(bm_orig)));

fprintf('Converting resolution');
bm_orig=reshape(bm_orig,[21600 43200]);

d=21600;
            
bm_part_1 = full(bm_orig(d*0+1:d*1,d*0+1:d*1));
bm_target_res_1=imresize(bm_part_1,1/conv_factor,'bilinear');
clearvars bm_part_1;
fprintf('.');
bm_part_2 = full(bm_orig(d*0+1:d*1,d*1+1:d*2));
bm_target_res_2=imresize(bm_part_2,1/conv_factor,'bilinear');
clearvars bm_part_2;
fprintf('.');

clearvars bm_orig;
bm_target_res = reshape([bm_target_res_1 bm_target_res_2],[21600*43200/(conv_factor^2) 1]);% bm_target_res_1
fprintf('.\n');

% See if converted data is far off
if ~(mean(mean(bm_target_res))==orig_mean)
    fprintf(['Warning: The converted BM data deviates by ', num2str(((mean(mean(bm_target_res))/orig_mean)-1)*100), '%% from the original\n']);
end

end