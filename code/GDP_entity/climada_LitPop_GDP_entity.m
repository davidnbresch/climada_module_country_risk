function entity = climada_LitPop_GDP_entity(admin0_name, parameters)
% MODULE:
%   country_risk
% NAME:
%   climada_LitPop_GDP_entity
% PURPOSE:
%   Create gridded entity for a country based on "Lit Population" (LitPop).
%   GDP on admin1 or admin0 level is distributed spatially in proportion to LitPop.
%   (LitPop is computed by multiplying nightlight intensity with population
%   density).
%   Additionally, an agriculture entity can be computed seperately from all
%   other GDP. 
% DATA REQUIREMENTS:
%   LITPOP:
%   Requires "Lit Population" data files inside the country risk module in /data and
%   /data/GSDP. LitPop is computed for each country if it is not yet available as a MAT-File.
%   This requires gridded nightlight (Blackmarble, NASA, 2016) and population data (SEDAC, 2015).
%   Please refer to climada_LitPop_country.m and climada_LitPop_import.m for more info on LitPop
%   and data requirements.
%   Please set alternative file paths and names for input below.
%   GDP: 
%   For admin1 options, an additional xls-file with district-level GDP
%   (i.e. GSDP) and a mapping of admin1 names to the identifiers used in the shape1 file need to be provided.
%   For agriculture, a table with the agriculture share of GDP by country
%   AGRICULTURE:
%   (source: worldbank, 'GDP_share_agrar_per_country_Worldbank_1960-2016')
%   and a global agriculture entity
%   ('GLB_agriculture_XXX.mat') i.e. http://dx.doi.org/10.7910/DVN/DHXBJX,
%   as used in the CLIMADA MRIO project needs to be provided
% CALLING SEQUENCE:
%   climada_gpw_read;
%   climada_blackmarble_read;
%   climada_LitPop_import;
%   climada_LitPop_country;
%   entity = climada_LitPop_GDP_entity(admin0_name, parameters)
% EXAMPLES:
%   parameters.admin1_calc=0;
%   climada_LitPop_GDP_entity('India', parameters)
%
%   parameters.make_plot = 1;
%   entity = climada_LitPop_GDP_entity('CHE', parameters)
% INPUTS:
%   admin0_name: String with name or ISO3 code of country, e.g. 'USA' or 'Taiwan'
% OPTIONAL INPUT PARAMETERS:
%   parameters: struct with the following fields:
%      target_res: Integer, with target resolution in arc-seconds (Default: 30)
%           possible values: 30 60 120 300 600 3600
%      admin0_calc (Default= 1); % Distribute national GDP (admin0) to grid (requires GDP per country)
%      admin1_calc (Default= 1); % Distribute sub-national GDP (admin1) to grid (requires G(S)DP per admin0)
%      admin1_calc_inherit_admin0 (Default = 0); % Use distribution from admin0_calc
%          for grid points for which no admin1 data has been found (relevant
%          e.g. in India for island and city union territories) (requires
%          admin0_calc and admin1_calc)
%      do_agrar (Default = 0); % include split of GDP in agriculture and
%          non-agriculture (slow!)
%      save_as_entity_file (Default = 1); % save resulting grid as CLIMADA entity file  
%      save_admin0 (Default = 0); % save all grids for country to MAT file
%      save_admin1 (Default = 0); % save results and comparison on admin1 level to MAT file
%      output_entity_file: string of file name to export entity to (normally to entity folder)
%      output_admin0_file: string of file name to export admin0 data to (specify with full path)
%      output_admin1_file: string of file name to export admin1 data to (specify with full path)
%      mainLand (Default = 0): If = 1, only mainland is evaluated (so far
%           for USA only, ignores Hawaii and Alaska)
%      debug_mode (Default = 0); If = 1, only one admin1 is evaluated to
%               speed up debugging
%      hazard_file (string): name of a hazard set (.mat). If this is
%               provided, the entities are encoded to the centroids of this hazard set.
%      max_encoding_distance_m: max_encoding distance in meters (see climada_asset_encode.m)
%      make_plot (Default = 0); % make plots, map of entity and scatter to compare distribution of national GDP to given GSDP (requires admin0_calc and admin1_calc)
% OUTPUTS:
%       entity: CLIMADA entity struct with asset value based on GDP distributed to
%           grid points according to LitPop + additional fields depending on
%           parameters.
%
% MODIFICATION HISTORY:
% Samuel Eberenz, eberenz@posteo.eu, 20180306, initial.
% Samuel Eberenz, eberenz@posteo.eu, 20180306, Removed parameters.check_admin1
% Samuel Eberenz, eberenz@posteo.eu, 20180321, include bounding boxes to make inpolygon faster, add option mainland for USA
% Samuel Eberenz, eberenz@posteo.eu, 20180403, litpop no longer written to entity file to reduce size and speed up
% Dario Stocker, dario.stocker@gmail.com, 20180405, Bugs fixed, adaptations for usage from climada_LitPop_country.m
% Dario Stocker, dario.stocker@gmail.com, 20180418, adaptations for usage with climada_shape_mask
% Samuel Eberenz, eberenz@posteo.eu, 20180425, clean up & debug in case no admin1 spreadsheet is provided, improve encoding option
%-

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% clear a A admin* b i* GDP* para* shap* entit* IN* Output* n_shap* litpop* GSDP*

% check for arguments
if ~exist('admin0_name','var'),error('Missing input. Please provide country name or ISO3-code as string!'); end
if ~exist('parameters','var'), parameters=struct; end
% parameters
if ~isfield(parameters,'target_res'), parameters.target_res = 30;end
if ~isfield(parameters,'admin0_calc'), parameters.admin0_calc = 1;end
if ~isfield(parameters,'admin1_calc'), parameters.admin1_calc = 1;end
if ~isfield(parameters,'admin1_calc_inherit_admin0'), parameters.admin1_calc_inherit_admin0 = 0;end
if ~isfield(parameters,'do_agrar'), parameters.do_agrar = 0;end
if ~isfield(parameters,'make_plot'), parameters.make_plot = 0;end
if ~isfield(parameters,'save_as_entity_file'), parameters.save_as_entity_file = 1;end
if ~isfield(parameters,'save_admin0'), parameters.save_admin0 = 0;end
if ~isfield(parameters,'save_admin1'), parameters.save_admin1 = 0;end
if ~isfield(parameters,'mainLand'), parameters.mainLand = 0;end
if ~isfield(parameters,'debug_mode'), parameters.debug_mode = 0;end;
if ~isfield(parameters,'hazard_file'), parameters.hazard_file = [];end;
if ~isfield(parameters,'max_encoding_distance_m'), parameters.max_encoding_distance_m = climada_global.max_encoding_distance_m;end;

if parameters.admin1_calc_inherit_admin0 == 1 && (parameters.admin0_calc + parameters.admin1_calc) <2
    parameters.admin0_calc=1;
    parameters.admin1_calc=1;
    fprintf('Parameter admin1_calc_inherit is set to one. Automatically adjusted some other neccessary paramters.\n');
end
if parameters.admin1_calc~=1
    parameters.save_admin1=0;
    fprintf('Parameter save_admin1 is set =0.\n');
end

% set target resolution = parameters.target_res
if ~isscalar(parameters.target_res)
    parameters.target_res=30;
    fprintf(['None or invalid target resolution. Resorting to default resolution (30 arc-sec).\n']);
else
    possible_res=[30 60 120 300 600 3600];
    if interp1(possible_res,possible_res,parameters.target_res,'nearest','extrap') ~= parameters.target_res
        parameters.target_res = interp1(possible_res,possible_res,parameters.target_res,'nearest','extrap');
    fprintf(['Target resolution adjusted. It was set to ', num2str(parameters.target_res), ' arc-sec\n']);
    end
    clearvars possible_res;
end

% load shape file (admin0):
Input_path = [climada_global.modules_dir filesep 'country_risk' filesep 'data'];
admin0_shape_file = [Input_path filesep 'ne_10m_admin_0_countries' filesep 'ne_10m_admin_0_countries.shp'];
module_data_dir=[fileparts(fileparts(which('centroids_generate_hazard_sets'))) filesep 'data'];
% get the admin0 boundaries (countries)
if exist(admin0_shape_file,'file')
    admin0_shapes=climada_shaperead(admin0_shape_file); % read the admin1 shapes
    n_shapes_admin0=length(admin0_shapes);
else
    fprintf('ERROR: admin0 shape file %s not found, aborted\n',admin1_shape_file);
    fprintf('download from www.naturalearthdata.com\n');
    fprintf('and store in %s\n',module_data_dir);
    return
end

% fetch and present list, if admin0 empty or couldn't be matched
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
        admin0_ISO3 = admin0_code_list{sort_index(selection)};
    else
        error('No country selected. Operation aborted');
    end
else
    [admin0_name,admin0_ISO3] = climada_country_name(admin0_name); % get full name & ISO3 code
end


% INPUT: Set input file paths and file names here:

GSDP_folder_path = [Input_path filesep 'GSDP']; % 

admin1_GSDP_file = [GSDP_folder_path filesep admin0_ISO3 '_GSDP.xls']; % Spreadsheet needs 1 column named 'State_Province' and 1 named 'GSDP_ref'
admin1_mapping_file = [GSDP_folder_path filesep admin0_ISO3 '_GSDP_admin1_mapping.xls']; % mapping of admin1 names
GDP_admin0_file = [GSDP_folder_path filesep 'World_GDP_current_WDI_2015-2016'];
% litpop_file = [climada_global.entities_dir filesep 'GPW_BM_' admin0_ISO3 '_LitPopulation']; % gridded LitPop
admin1_shape_file = [Input_path filesep 'ne_10m_admin_1_states_provinces' filesep 'ne_10m_admin_1_states_provinces.mat'];

if parameters.do_agrar
    GDP_agrar_admin0_file = [Input_path filesep 'GDP_share_agrar_per_country_Worldbank_1960-2016'];
    agrar_entity_file='GLB_agriculture_XXX.mat'; % global or country specific entity file
end

% OUTPUT: Set defaults for Output filenames
if ~isfield(parameters,'output_entity_file')
    if parameters.save_as_entity_file
        parameters.output_entity_file = [admin0_ISO3 '_GDP_LitPop_BM2016.mat']; % saved to entity folder
        if parameters.mainLand
            parameters.output_entity_file = [admin0_ISO3 'mainLand_GDP_LitPop_BM2016.mat'];
        end  
    end
    if parameters.save_as_entity_file && parameters.debug_mode
        parameters.output_entity_file = [admin0_ISO3 '_GDP_LitPop_BM2016_DEBUG.mat']; % saved to entity folder
    end
end
if parameters.save_admin0 && ~exist('parameters.output_admin0_file','var')
    parameters.output_admin0_file = [GSDP_folder_path filesep admin0_ISO3 '_GDP_LitPop_grid.mat'];
end
if parameters.save_admin1 && ~exist('parameters.output_admin1_file','var')
    parameters.output_admin1_file = [GSDP_folder_path filesep admin0_ISO3 '_GSDP_LitPop_admin1.mat'];
end

%% Loading data
% get the admin1 boundaries (states/ provinces)
if exist(admin1_shape_file,'file')
    load(admin1_shape_file)
    % shapes=climada_shaperead(admin1_shape_file); % read the admin1 shapes
    n_shapes_admin1=length(shapes);
else
    fprintf('ERROR: admin1 shape file %s not found, aborted\n',admin1_shape_file);
    fprintf('download www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_admin_1_states_provinces.zip\n');
    fprintf('and store in %s\n',module_data_dir);
    return
end

%% load input data

% Generate variable name from country
country_litpop_varname = [admin0_ISO3, '_LitPopulation'];
country_index_varname = [admin0_ISO3, '_ind'];

if ~exist([module_data_dir filesep 'GPW_BM_' admin0_ISO3 '_LitPopulation_', num2str(parameters.target_res), 'arcsec.mat'],'file')
    [litpop.(country_litpop_varname), litpop.(country_index_varname), litpop.gpw_index, litpop.gpw_lon, litpop.gpw_lat] = climada_LitPop_country(admin0_ISO3,parameters.target_res,1,0);
%climada_LitPop_country(admin0_ISO3,parameters.target_res,1,0);
else
    try
        litpop_file = [module_data_dir filesep 'GPW_BM_' admin0_ISO3 '_LitPopulation_', num2str(parameters.target_res), 'arcsec.mat']; % gridded LitPop
        litpop = load(litpop_file);
        fprintf('LitPop successfully loaded.\n');
    catch
        error('Error while trying to load the LitPopulation file. Operation aborted.')
    end
end

GDP_admin0 = climada_xlsread(0,GDP_admin0_file,'world_GDP_current');
if parameters.do_agrar
    try
        load(GDP_agrar_admin0_file); % GDP_share_agrar (variable)
    catch
        error('Error while loading agricultural GDP share file. Operation aborted.');
    end

    % load global agriculture output entity
    try
        GLB_agriculture = climada_entity_load(agrar_entity_file);
    catch
        error('Error while loading agriculutral gloabl entity. Operation aborted.');
    end
end

% load country specific files:
% Lit Population from GWP and Black Marble is loaded previously in script.
if ~isfield(litpop,country_index_varname)
    country_index_varname = [admin0_ISO3, '_index'];
    if ~isfield(litpop,country_index_varname)
        error('Index variable not found. Please regenerate the country mat file using climada_LitPop_country');
    end
end
if parameters.mainLand
    country_index_varname = 'mainLand_ind';
    if ~isfield(litpop,country_index_varname)
        country_index_varname = 'mainLand_index';
        if ~isfield(litpop,country_index_varname)
            error('Index variable not found. Please regenerate the country mat file using climada_LitPop_country');
        end
    end
    country_litpop_varname = 'mainLand_LitPopulation';
end
if ~isfield(litpop,'lon')
    litpop.lon = litpop.gpw_lon(litpop.(country_index_varname));
end
if ~isfield(litpop,'lat')
    litpop.lat = litpop.gpw_lat(litpop.(country_index_varname));
end
% list of admin1 with GSPD:
idx = ~cellfun('isempty',strfind({shapes.adm0_a3},admin0_ISO3));
i1 = find(idx==1); 
if parameters.debug_mode, i1=i1(min(5,length(i1)));end % only process one single admin1
% find index of country (admin0 )
%idx = ~cellfun('isempty',strfind({admin0_shapes.ISO_A3},admin0_ISO3)); %
%Throws error if empty countries are included. Hence new version:
i0=0;

for admin0_i=1:length(shapes)
    if strcmp(admin0_ISO3,admin0_shapes(admin0_i).ISO_A3)==1
        i0=admin0_i;
        break;
    end
end

clearvars admin0_i idx;

%i0 = find(idx==1); 


admin1_names = {shapes.name}; 
admin1_adm1_cod_1 = {shapes.adm1_cod_1}; 

%% distribute national GDP to grid points
if parameters.admin0_calc
    tic
    % find grid points inside country's polygon
    % shapes.BoundingBox = [Lon_min, Lat_min; Lon_max, Lat_max];
    if parameters.do_agrar
        %%
        in_box_agrar = find(GLB_agriculture.assets.lon>=admin0_shapes(i0).BoundingBox(1,1) &...
                           GLB_agriculture.assets.lon<=admin0_shapes(i0).BoundingBox(2,1) &...
                           GLB_agriculture.assets.lat>=admin0_shapes(i0).BoundingBox(1,2) &...
                           GLB_agriculture.assets.lat<=admin0_shapes(i0).BoundingBox(2,2));

        IN0_agrar = climada_inpolygon(GLB_agriculture.assets.lon(in_box_agrar),GLB_agriculture.assets.lat(in_box_agrar),admin0_shapes(i0).X,admin0_shapes(i0).Y,0);
       
        %%
    end
    % IN0_litpop = climada_inpolygon(litpop.lon,litpop.lat,admin0_shapes(i0).X,admin0_shapes(i0).Y,0); % only if not cut out already
    IN0_litpop = ones(size(litpop.lon));
    toc
    %% isolate gridpoints inside polygon
    if parameters.do_agrar
    % admin0_agriculture = GLB_agriculture;
        admin0.agriculture.assets.lon = GLB_agriculture.assets.lon(in_box_agrar(IN0_agrar==1));
        admin0.agriculture.assets.lat = GLB_agriculture.assets.lat(in_box_agrar(IN0_agrar==1));
        admin0.agriculture.assets.Value = GLB_agriculture.assets.Value(in_box_agrar(IN0_agrar==1));
        clear GLB_agriculture
        admin0.agriculture.assets.Norm = admin0.agriculture.assets.Value./sum(admin0.agriculture.assets.Value(:));
    end
    admin0.litpop.lon = litpop.lon(IN0_litpop==1);
    admin0.litpop.lat = litpop.lat(IN0_litpop==1);
    admin0.litpop.Value = litpop.([admin0_ISO3 '_LitPopulation'])(IN0_litpop==1);
    litpop = rmfield(litpop,{[admin0_ISO3 '_LitPopulation'],[admin0_ISO3 '_ind'],'lat','lon'});
    admin0.litpop.Norm = admin0.litpop.Value./sum(admin0.litpop.Value(:));
    
    %% find country in GDP structs:
    i0_GDP = ~cellfun('isempty',strfind(GDP_admin0.iso,admin0_ISO3))==1;   
    if parameters.do_agrar
        i0_agrar_share = find(~cellfun('isempty',strfind(GDP_share_agrar.Country_Code,admin0_ISO3))==1);
        if isequal(GDP_share_agrar.Att_2016{i0_agrar_share},'NaN') || isnan(GDP_share_agrar.Att_2016{i0_agrar_share})
            GDP_share_agrar.Att_2016{i0_agrar_share} = GDP_share_agrar.Att_2015{i0_agrar_share};
        end
    end
    %% Distribute GDP to gridpoints
    GDP_admin0_ref = GDP_admin0.year2016(i0_GDP); % from worldbank
    GDP_admin0_ref =     GDP_admin0_ref(1);    
    if GDP_admin0_ref==0, GDP_admin0_ref = 1;warning('No GDP value found; GDP is set to 1');end
    % 100% GDP distributed linearly to LitPopulation:
    admin0.GDP.FromLitPop = admin0.litpop.Norm .* GDP_admin0_ref ;
    
    % GDP without agriculture distributed linearly to LitPopulation:
    if parameters.do_agrar
        admin0.GDP.FromLitPop_minus_agrar = admin0.litpop.Norm .* ...
            (GDP_admin0_ref * (1-GDP_share_agrar.Att_2016{i0_agrar_share}));

        % GDP of agriculture only distributed linearly to agricultural output:
        admin0.GDP.FromAgrar = admin0.agriculture.assets.Norm .* ...
            (GDP_admin0_ref * GDP_share_agrar.Att_2016{i0_agrar_share});
    end
    %%
end


%% compare sum per state/ province to given values of GSDP

if parameters.admin1_calc
    try
        admin1.mapping = climada_xlsread(0,admin1_mapping_file);
        admin1.GSDP = climada_xlsread(0,admin1_GSDP_file);
        admin1.GSDP.Norm = admin1.GSDP.GSDP_ref / nansum(admin1.GSDP.GSDP_ref(end));


        %% Prepare result vectors
        admin1.GSDP_FromLitPop = zeros(size(i1))';
        if parameters.do_agrar
            admin1.GSDP_FromLitPop_minus_agrar = admin1.GSDP_FromLitPop;
            admin1.GSDP_FromAgrar = admin1.GSDP_FromLitPop;
        end
        admin1.GSDP_Reference = admin1.GSDP_FromLitPop;
        admin1.name = cell(size(i1))';
        if parameters.admin1_calc
            admin1.GSDP_FromLitPop_admin1 = admin1.GSDP_FromLitPop;
            if parameters.admin1_calc_inherit_admin0
                admin0.GDP.FromLitPop_admin1 = admin0.GDP.FromLitPop;
            else
                admin0.GDP.FromLitPop_admin1 = zeros(size(admin0.GDP.FromLitPop)); % admin0 GDP-grid for redistribution according to admin1-GSDP
            end
        end

        %% Loop through admin1

        for i = 1:length(i1)
            display(admin1_names{i1(i)});
            admin1.name{i} = admin1_names{i1(i)};
            if ~isempty(admin1_names{i1(i)})
                % Sum inside polygon of state/ province and sum grid point data
                % to get GSDP:
                tic;
                if parameters.do_agrar
                    in_box_agrar = find(admin0.agriculture.assets.lon>=shapes(i1(i)).BoundingBox(1,1) &...
                               admin0.agriculture.assets.lon<=shapes(i1(i)).BoundingBox(2,1) &...
                               admin0.agriculture.assets.lat>=shapes(i1(i)).BoundingBox(1,2) &...
                               admin0.agriculture.assets.lat<=shapes(i1(i)).BoundingBox(2,2));

                    IN_agrar  = climada_inpolygon(admin0.agriculture.assets.lon(in_box_agrar),admin0.agriculture.assets.lat(in_box_agrar),shapes(i1(i)).X,shapes(i1(i)).Y,0);
                end
                in_box = find(admin0.litpop.lon>=shapes(i1(i)).BoundingBox(1,1) &...
                               admin0.litpop.lon<=shapes(i1(i)).BoundingBox(2,1) &...
                               admin0.litpop.lat>=shapes(i1(i)).BoundingBox(1,2) &...
                               admin0.litpop.lat<=shapes(i1(i)).BoundingBox(2,2));
                if parameters.admin1_calc
                    % IN_litpop = climada_inpolygon(admin0.litpop.lon(in_box),admin0.litpop.lat(in_box),shapes(i1(i)).X,shapes(i1(i)).Y,0);
                    [IDX_LitPop, IN_litpop] = climada_shape_mask(shapes(i1(i)),[],parameters.target_res,litpop.gpw_index,litpop.gpw_lon,litpop.gpw_lat,0);
                end

                % Find admin1 in mapping of GSDP data:
                switch admin0_ISO3
                    case 'CHE'
                        i1_GSDP = find(~cellfun('isempty',strfind(admin1.mapping.adm1_cod_1,admin1_adm1_cod_1{i1(i)}))==1); 
                    otherwise
                        i1_GSDP = find(~cellfun('isempty',strfind(admin1.mapping.admin1,admin1_names{i1(i)}))==1);  
                end
                admin1_name_GSDP = admin1.mapping.gov{i1_GSDP};
                if ~isnan(admin1_name_GSDP)

                    i1_GSDP = strcmp(admin1.GSDP.State_Province,admin1_name_GSDP);                   
                    admin1.GSDP_Reference(i) = admin1.GSDP.Norm(i1_GSDP).*GDP_admin0_ref; % multiply normalized GSDP with reference admin0 GDP
                else
                    admin1.GSDP_Reference(i) = NaN;
                end
                if parameters.admin1_calc
                    litpop_tmp = admin0.litpop.Value;
                    litpop_tmp(IDX_LitPop) = litpop_tmp(IDX_LitPop)/nansum(litpop_tmp(IDX_LitPop)); % normalized by admin1 level
                    if round(full(nansum(litpop_tmp(IDX_LitPop))).*1e9)~=1e9      
                        warning('nansum(litpop_tmp(in_box(IN_litpop==1))) is not equal to 1. Normalization failed.')
                    else % distribute GSDP to gridpoints in state/ province (admin1): 
                        admin0.GDP.FromLitPop_admin1(IDX_LitPop) = litpop_tmp(IDX_LitPop).*admin1.GSDP_Reference(i); % multiply by reference GSDP
                    end
                    clear litpop_tmp
                    admin1.GSDP_FromLitPop_admin1(i) = sum(admin0.GDP.FromLitPop_admin1(IDX_LitPop));
                    admin1.GSDP_FromLitPop(i) = sum(admin0.GDP.FromLitPop(IDX_LitPop));
                end
                % Test sum: summing up gridpoints over one admin1 (=GSDP):

                if parameters.do_agrar && parameters.admin1_calc
                    admin1.GSDP_FromLitPop_minus_agrar(i) = sum(admin0.GDP.FromLitPop_minus_agrar(IDX_LitPop));
                    admin1.GSDP_FromAgrar(i) = sum(admin0.GDP.FromAgrar(in_box_agrar(IN_agrar==1)));   
                end

                clear IN_* IDX_LitPop
                toc
            else
                admin1.GSDP_FromLitPop(i) = NaN;
                admin1.GSDP_FromLitPop_admin1(i) = NaN;
                if parameters.do_agrar
                    admin1.GSDP_FromLitPop_minus_agrar(i) = NaN;
                    admin1.GSDP_FromAgrar(i) = NaN;
                end


            end

        end
    catch ME
        warning('climada_xlsread failed. Either for technical reasons (java?) or missing file(s): admin1_GSDP_file, admin1_mapping_file');
        %       warning([admin0_name ': Import of state/ province level GDP (GSDP) not yet implemented for this country! Please implement if required.']);
        display(ME.identifier)
        display(ME.message)
        warning('admin1 was not calculated.')
        parameters.admin1_calc=0;
        parameters.save_admin1=0;
    end
    if parameters.admin1_calc
        admin1.GSDP_Reference_RestOfNation = GDP_admin0_ref - nansum(admin1.GSDP_Reference);
        if parameters.do_agrar
            admin1.GSDP_FromGDPandAgrarCombined = admin1.GSDP_FromLitPop_minus_agrar + admin1.GSDP_FromAgrar;
        end
        % correlation:
        idx_isnan = isnan(admin1.GSDP_Reference) + isnan(admin1.GSDP_FromLitPop);

        [admin1.corr_coeff_Ref_LitPop, admin1.corr_pval_Ref_LitPop] = corrcoef(admin1.GSDP_Reference(~idx_isnan),admin1.GSDP_FromLitPop(~idx_isnan));
        if parameters.do_agrar
            [admin1.corr_coeff_Ref_LitPop_w_agrar, admin1.corr_pval_Ref_LitPop_w_agrar] = corrcoef(admin1.GSDP_Reference(~idx_isnan),admin1.GSDP_FromLitPop(~idx_isnan)+admin1.GSDP_FromAgrar(~idx_isnan));
        end
        if parameters.save_admin1
            save(parameters.output_admin1_file,'admin1','-v7.3');
        end
    end
end
if parameters.save_admin0
    save(parameters.output_admin0_file,'admin0','-v7.3');
end
%% Creating entity file

entity = climada_entity_load('entity_template_ADVANCED.mat');

entity.assets.reference_year = 2016;


entity.assets.lon = admin0.litpop.lon';
entity.assets.lat = admin0.litpop.lat';
% entity.assets.litpop = (full(admin0.litpop.Value))';
if parameters.save_admin1
    entity.assets.Value = (full(admin0.GDP.FromLitPop_admin1))';
    entity.assets.comment='asset.Value: admin1-level GDP distributed proportionally to Lit Population';
else
    entity.assets.Value = (full(admin0.GDP.FromLitPop))';
    entity.assets.comment='asset.Value: admin0-level GDP distributed proportionally to Lit Population';
end
entity.assets.Cover = entity.assets.Value;
entity.assets.Deductible = 0*entity.assets.Value;
entity.assets.Category_ID = ones(size(entity.assets.Value));
entity.assets.DamageFunID = entity.assets.Category_ID;
entity.assets.Region_ID = entity.assets.Category_ID;
entity.assets.Value_unit = repmat({'USD'},size(entity.assets.Category_ID));    % Necessary while entity requires an equal number of fields for the value unit
%entity.assets.Value_unit = {'USD'};
try
    entity.assets = rmfield(entity.assets,'centroid_index');
    entity.assets = rmfield(entity.assets,'hazard');
end
if parameters.do_agrar
    entity.assets.Value_Agrar = (full(admin0.GDP.FromAgrar))';
    entity.assets.Value_LitPop_minus_Agrar = (full(admin0.GDP.FromLitPop_minus_agrar))'; 
end
if isfield(parameters,'hazard_file') && ~isempty(parameters.hazard_file)
    try
        entity = climada_assets_encode(entity,parameters.hazard_file,parameters.max_encoding_distance_m);
        display(['entity was encoded to hazard ' parameters.hazard_file]);
    catch ME
        warning('Encoding failed, either due to error while loading hazard or while encoding.');
        display(ME.identifier)
        display(ME.message)
    end
end
if parameters.save_as_entity_file
    disp(['Writing to entity file: ' parameters.output_entity_file]);
    entity.assets.filename = parameters.output_entity_file; 
    tic
    save([climada_global.entities_dir filesep parameters.output_entity_file],'entity','-v7.3')
    toc
end

if parameters.make_plot
    figure(1); climada_entity_plot(entity,2); title('GDP from LitPopulation')
end


if parameters.make_plot && parameters.do_agrar
    
    figure(4); hold on;
    scatter(admin1.GSDP_FromLitPop,admin1.GSDP_FromGDPandAgrarCombined,'xm');
    plot([0 max(admin1.GSDP_Reference)],[0 max(admin1.GSDP_Reference)],'k--')
    hold off
    title(['GSDP (USD), ' admin0_name]);
    xlabel('LitPop only')
    ylabel('LitPop + Agrar')
end

%%

if parameters.make_plot && parameters.admin1_calc
    
    figure(5); hold on;
    scatter(admin1.GSDP_Reference,admin1.GSDP_FromLitPop,'xb');
    if parameters.do_agrar
        scatter(admin1.GSDP_Reference,admin1.GSDP_FromGDPandAgrarCombined,'xr');
    end
    plot([0 max(admin1.GSDP_Reference)],[0 max(admin1.GSDP_Reference)],'k--')
    hold off
    title(['GSDP (USD), ' admin0_name]);
    xlabel('Reference (official)')
    if parameters.do_agrar
        ylabel('LitPop (blue) & LitPop + Agrar (red)')
    else
        ylabel('from LitPop')
    end
    
    figure(6); hold on;
    scatter(admin1.GSDP_Reference,admin1.GSDP_FromLitPop_admin1,'xb');
    plot([0 max(admin1.GSDP_Reference)],[0 max(admin1.GSDP_Reference)],'k--')
    hold off
    title(['GSDP (USD), ' admin0_name]);
    xlabel('Reference (official)')
    ylabel('LitPop from admin1')
   
end
