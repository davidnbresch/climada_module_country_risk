function [country_LitPop,country_idx,gpw_index,gpw_lon,gpw_lat]=climada_LitPop_country(admin0_name,target_res,save_flag,plot_flag)
% MODULE:
%   core
% NAME:
%	climada_LitPop_country
% PURPOSE:
%   This function calculates the "Lit Population" of a country based on the product of
%   nighlight intensity (Black Marble 2016) and population density (GPW).
% CALLING SEQUENCE:
%   climada_gpw_read;
%   climada_blackmarble_read;
%   climada_LitPop_import;
%   climada_LitPop_country;
% Example:
%   [country_LitPop,country_idx]=climada_LitPop_country('JPN',[],30,1,1)
% INPUTS:
%   admin0_name: ISO3 code or name of country (string)
% OPTIONAL INPUT PARAMETERS:
%   target_res: target resolution in arcsec, possible_res=[30 60 120 300 600 3600];
%   save_flag: if set =1 (default), the BM data is saved to the country risk module
%       data folder.
%   plot_flag: if set=1, a map of the result is plotted
% OUTPUTS:
%   LitPopulation: The LitPopulation value for each grid point in country in
%       a column vector. Resultion: [((3600/target_res)*180*360) 1]
%   country_idx: Index of grid points that are in country. Vector of same size as LitPopulation.
%   gpw_index: A function which calculates the indices for a given bounding
%       box, matching the chosen resolution.
%   gpw_lat: A function which calculates the latitude from given indices.
%       In a way the inversion operation of gpw_index.
%   gpw_lon: The same as gpw_lat, but for longitudes.
% MODIFICATION HISTORY:
% Dario Stocker, dario.stocker@gmail.ch, 2018, init
% Dario Stocker, dario.stocker@gmail.ch, 20180406, add flexible target_res
%%%
% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% check for arguments
if ~exist('admin0_name','var'),admin0_name=''; end
%if ~exist('admin1_name','var'),admin1_name=''; end
if ~exist('target_res','var'),target_res=[];end
if ~exist('save_flag','var'),save_flag=1;end
if ~exist('plot_flag','var'),plot_flag=1;end


% locate data folder of country risk module
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

LitPop_Filename = ['GPW_BM_LitPopulation_' num2str(target_res) 'arcsec.mat'];
LitPop_data_path=[module_data_dir filesep LitPop_Filename];

% Check if file exists
if ~exist(LitPop_data_path,'file')
    disp(['The LitPopulation data with the filename ' LitPop_Filename ' was not found (a dialog should open now)']);
    nextStep = questdlg(['The LitPopulation data with the filename ' LitPop_Filename ' was not found.' newline 'What would you like to do next? Please note that you need to download the raw data first if you choose to generate the Nighlight population data.'] , ...
	'Missing LitPopulation data', ...
	'Locate missing file','Generate LitPopulatoin Data','Abort Operation','Locate missing file');
    % Handle response
    switch nextStep
        case 'Locate missing file'
            ui_path=uigetdir([],['Locate folder where file ' LitPop_Filename ' is placed.']);
            if ui_path(end:end)==filesep % remove filesep if neccessary, it is added later
                ui_path=ui_path(1:(end-1));
            end
            LitPop_data_path=[ui_path filesep LitPop_Filename];
            if ~exist(LitPop_data_path,'file')
                error('Global LitPopulation data could not be found. Operation aborted.');
            end
        case 'Generate LitPopulatoin Data'
            fprintf('LitPopulation is created. This may take a while.\n');
            [LitPopulation,gpw_index,gpw_lon,gpw_lat]=climada_LitPop_import([],target_res);    
        otherwise
            fprintf('Operation aborted by user.\n')
            return;
    end
    %error('LitPopulation file does not exist, plese import it first using the function climada_LitPopulation_import');
else
    try
        load(LitPop_data_path);
    catch
        error('An error occured while loading LitPopulation. Operation aborted.');
    end
end


% admin0 and admin1 shape files (in climada module country_risk):
admin0_shape_file=climada_global.map_border_file; 


% import country shape file
admin0_shapes=climada_shaperead(admin0_shape_file);

if ~isempty(admin0_name) % check for valid name, othwerwise set to empty
    [~,admin0_code]=climada_country_name(admin0_name);
end
    

if isempty(admin0_name)
    
    % generate the list of countries
    admin0_name_list={};admin0_code_list={};
    for shape_i=1:length(admin0_shapes)
        admin0_name_list{shape_i}=admin0_shapes(shape_i).NAME;
        admin0_code_list{shape_i}=admin0_shapes(shape_i).ADM0_A3;
    end % shape_i

    [liststr,sort_index] = sort(admin0_name_list);

    % prompt for a country name
    [selection] = listdlg('PromptString','Select a country:',...
        'ListString',liststr,'SelectionMode','Single');
    pause(0.1)
    if ~isempty(selection)
        admin0_name = admin0_name_list{sort_index(selection)};
        admin0_code = admin0_code_list{sort_index(selection)};
    else
        error('No country selected. Operation aborted');
    end

end

admin0_idx=0;

for admin0_i=1:length(admin0_shapes)
    if strcmp(admin0_code,admin0_shapes(admin0_i).ADM0_A3)==1
        admin0_idx=admin0_i;
        break;
    end
end

% Select appropriate country shape, dump the rest
country_shape=admin0_shapes(admin0_idx);
clearvars admin0_shapes;


% Double check if neccessary functions exist
if ~exist('gpw_index','var')
    error('Function gpw_index missing (should load with global LitPopulation data). Operation aborted')
end
if ~exist('gpw_lat','var')
    error('Function gpw_lat missing (should load with global LitPopulation data). Operation aborted')
end
if ~exist('gpw_lon','var')
    error('Function gpw_lon missing (should load with global LitPopulation data). Operation aborted')
end

% Set initial index, lat, lon
country_bb_ind = gpw_index(min(min(country_shape.Y)),max(max(country_shape.Y)),min(min(country_shape.X)),max(max(country_shape.X)));
country_bb_lat = gpw_lat(country_bb_ind);
country_bb_lon = gpw_lon(country_bb_ind);

% Now do the acutal operation
fprintf(['Locating coordinates within ' admin0_name '. This may take a while\n']);
in_country=climada_inshape(country_bb_lat, country_bb_lon, country_shape, 0);

% Data cleaning
country_ind_temp = (in_country.*double(country_bb_ind));
country_ind = country_ind_temp(find(country_ind_temp~=0));
clearvars country_ind_temp;
country_LitPopulation = LitPopulation(country_ind);


if plot_flag~=0
    figure; plotclr(gpw_lon(country_ind),gpw_lat(country_ind),double(country_LitPopulation));
end

% Generate dynamic variable names
country_LitPop_varname = [admin0_code, '_LitPopulation'];
country_idx_varname = [admin0_code, '_ind'];

country_LitPop=country_LitPopulation;
country_idx=country_ind;



% Save variables under new names
eval([country_LitPop_varname, ' = country_LitPopulation;']);
clearvars country_LitPopulation;
eval([country_idx_varname, ' = country_ind;']);
clearvars country_ind;


if save_flag~=0
    module_data_dir=[fileparts(fileparts(which('centroids_generate_hazard_sets'))) filesep 'data'];
    save([module_data_dir filesep 'GPW_BM_', admin0_code, '_LitPopulation_', num2str(target_res), 'arcsec.mat'],country_LitPop_varname,country_idx_varname,'gpw_lat','gpw_lon','gpw_index','-v7.3');
end

end
