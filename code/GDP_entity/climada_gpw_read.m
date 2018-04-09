function gpw_popNum=climada_gpw_read(source_path,save_flag)
% MODULE:
%   
% NAME:
%	climada_gpw_read
% PURPOSE:
%   Imports the GPW data from the according TIFF file and prepares the data
%   accordingly. This function is called by climada_LitPop_import.
%   The data set is GPW v4 rev10 "Population count" and the data year 2015.
%   The data can be downloaded from: 
%   http://sedac.ciesin.columbia.edu/data/set/gpw-v4-population-count-rev10
% CALLING SEQUENCE:
%   gpw_popNum=climada_gpw_read(source_path,save_flag)
%   [LitPopulation, gpw_index, gpw_lat, gpw_lon] = climada_LitPop_import
% EXAMPLE:
%   gpw_popNum=climada_gpw_read
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   source_path: path were the GPW Tiff file is saved. Prompted if invalid
%       or empty.
%   save_flag: if set =1, the GPW data is saved to the country risk module
%       data folder.
% OUTPUTS:
%   gpw_popNum: The global population number per pixel in a column vector.
%   (30 arc-sec resolution ~ 1km)
%
% RESTRICTIONS:
% MODIFICATION HISTORY:
% Dario Stocker, dario.stocker@gmail.com, 201803, init



%%
% Check if files are in path
if ~exist('source_path','var'),source_path=[];end
gpw_folder = source_path;
gpw_filename = 'gpw_v4_population_count_rev10_2015_30_sec.tif';
 
if ~exist([gpw_folder filesep gpw_filename],'file')
[gpw_folder] = uigetdir([], 'Please select the folder cointaining the GPW raw data');
    if isequal(gpw_folder,0)
        error('No folder chosen. Operation aborted.');        
    end
end

if strcmp(gpw_folder(length(gpw_folder):length(gpw_folder)),filesep)==1
    gpw_folder=gpw_folder(1:(length(gpw_folder)-1));
end

% Reading file
fprintf('Attempting to read GPW data from source image\n');
try
    [gpw_raw,~,~]=geotiffread([gpw_folder filesep gpw_filename]);

    if size(gpw_raw)~= [17400,43200]
        disp(['Warning: GPW dataset has different dimensions than expected. Actual dimensions: ', num2str(size(a,1)), 'x',num2str(size(a,2)),'. Expected dimsions: 17400x43200.']);
    end

    % NaNs are denoted with a high negative number in the data set. These values are set to zero instead
    buffer_val=gpw_raw(1,1);
    gpw_raw(gpw_raw==buffer_val)=0;
    gpw_raw=sparse(double(gpw_raw));

    % Add (empty) top and bottom, to obtain a world wide grid
    a_top=sparse(600,43200);
    a_bottom=sparse(3600,43200);

    gpw_glb=sparse([a_top; gpw_raw; a_bottom]);

    clearvars gpw_raw a_top a_bottom;

    % Switch to one dimension
    gpw_popNum_wholegrid = reshape(gpw_glb,[43200*21600,1]);
    clearvars gpw_glb buffer_val;
    gpw_popNum=gpw_popNum_wholegrid;
    clearvars gpw_popNum_wholegrid;

    fprintf('GPW images imported\n');
catch
    error('An error occured while importing GPW data');
end

%% Save data to a mat file in climada risk module data folder
if ~save_flag==0
    module_data_dir=[fileparts(fileparts(which('centroids_generate_hazard_sets'))) filesep 'data'];
    save([module_data_dir filesep 'GPW_Population_2015_30arcsec.mat'],'gpw_popNum','-v7.3');
end

return;
end