function entity = climada_LitPop_GDP_entity(admin0_name, parameters)
% MODULE:
%   country_risk
% NAME:
%   climada_LitPop_GDP_entity
% PURPOSE:
%   Create gridded entity for a country based on "Lit Population" (LitPop) 
% DATA REQUIREMENTS:
%   Needs a file of "Lit Population" (litpop) for the country or global and
%   further data files inside the country risk module in /data and
%   /data/GSDP.   Please set alternative file paths and names for input below.
% CALLING SEQUENCE:
%   entity = climada_LitPop_GDP_entity(admin0_name, parameters)
% EXAMPLE:
%   parameters.make_plot = 1;
%   entity = climada_LitPop_GDP_entity('CHE', parameters)
% INPUTS:
%   admin0_name: String with name or ISO3 code of country, e.g. 'USA' or 'India'
% OPTIONAL INPUT PARAMETERS:
%   parameters: struct with the following fields:
%      admin0_calc (Default= 1); % Distribute national GDP (admin0) to grid (requires GDP per country)
%      admin1_calc (Default= 1); % Distribute sub-national GDP (admin1) to grid (requires G(S)DP per admin0)
%      admin1_calc_inherit_admin0 (Default = 1); % Use distribution from admin0_calc
%          for grid points for which no admin1 data has been found (relevant
%          e.g. in India for island and city union territories) (requires
%          admin0_calc and admin1_calc)
%      do_agrar (Default = 0); % include split of GDP in agriculture and non-agriculture
%      make_plot (Default = 0); % make plots, map of entity and scatter to compare distribution of national GDP to given GSDP (requires admin0_calc and admin1_calc)
%      save_as_entity_file (Default = 1); % save resulting grid as CLIMADA entity file  
%      save_admin0 (Default = 0); % save all grids for country to MAT file
%      save_admin1 (Default = 1); % save results and comparison on admin1 level to MAT file
%      output_entity_file: string of file name to export entity to (normally to entity folder)
%      output_admin0_file: string of file name to export admin0 data to (specify with full path)
%      output_admin1_file: string of file name to export admin1 data to (specify with full path)
%      mainLand (Default = 0): If = 1, only mainland is evaluated (so far
%           for USA only, ignores Hawaii and Alaska)
%      debug_mode (Default = 0); If = 1, only one admin1 is evaluated to
%               speed up debugging
%      hazard_file (string): name of a hazard set (.mat). If this is
%               provided, the entities are encoded to the centroids of this hazard set.
% OUTPUTS:
%       entity: CLIMADA entity struct with asset value based on GDP distributed to
%           grid points according to LitPop + additional fields depending on
%           parameters.
%
% MODIFICATION HISTORY:
% Samuel Eberenz, eberenz@posteo.eu, 20180306, initial.
% Samuel Eberenz, eberenz@posteo.eu, 20180306, Removed parameters.check_admin1
% Samuel Eberenz, eberenz@posteo.eu, 20180321, include bounding boxes to make inpolygon faster, add option mainland for USA
%-

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% clear a A admin* b i* GDP* para* shap* entit* IN* Output* n_shap* litpop* GSDP*

% check for arguments
if ~exist('admin0_name','var'),error('Missing input. Please provide country name or ISO3-code as string!'); end
if ~exist('parameters','var'), parameters=struct; end
% parameters
if ~isfield(parameters,'admin0_calc'), parameters.admin0_calc = 1;end
if ~isfield(parameters,'admin1_calc'), parameters.admin1_calc = 1;end
if ~isfield(parameters,'admin1_calc_inherit_admin0'), parameters.admin1_calc_inherit_admin0 = 1;end
if ~isfield(parameters,'do_agrar'), parameters.do_agrar = 0;end
if ~isfield(parameters,'make_plot'), parameters.make_plot = 0;end
if ~isfield(parameters,'save_as_entity_file'), parameters.save_as_entity_file = 1;end
if ~isfield(parameters,'save_admin0'), parameters.save_admin0 = 0;end
if ~isfield(parameters,'save_admin1'), parameters.save_admin1 = 1;end
if ~isfield(parameters,'mainLand'), parameters.mainLand = 0;end
if ~isfield(parameters,'debug_mode'), parameters.debug_mode = 0;end; 

% admin0: consistency check, returns both, interprets both name and ISO3
[admin0_name,admin0_ISO3] = climada_country_name(admin0_name); % get full name

% INPUT: Set input file paths and file names here:
Input_path = [climada_global.modules_dir filesep 'country_risk' filesep 'data'];
GSDP_folder_path = [Input_path filesep 'GSDP']; % 

admin1_GSDP_file = [GSDP_folder_path filesep admin0_ISO3 '_GSDP.xls']; % Spreadsheet needs 1 column named 'State_Province' and 1 named 'GSDP_ref'
admin1_mapping_file = [GSDP_folder_path filesep admin0_ISO3 '_GSDP_admin1_mapping.xls']; % mapping of admin1 names
GDP_admin0_file = [GSDP_folder_path filesep 'World_GDP_current_WDI_2015-2016'];
litpop_file = [climada_global.entities_dir filesep 'GPW_BM_' admin0_ISO3 '_LitPopulation']; % gridded LitPop 
admin1_shape_file = [Input_path filesep 'ne_10m_admin_1_states_provinces' filesep 'ne_10m_admin_1_states_provinces.mat'];
admin0_shape_file = [Input_path filesep 'ne_10m_admin_0_countries' filesep 'ne_10m_admin_0_countries.shp'];

if parameters.do_agrar
    GDP_agrar_admin0_file = [Input_path filesep 'GDP_share_agrar_per_country_Worldbank_1960-2016'];
    agrar_entity_file='GLB_agriculture_XXX.mat'; % global or country specific entity file
end

% OUTPUT: Set defaults for Output filenames
if parameters.save_as_entity_file
    parameters.output_entity_file = [admin0_ISO3 '_GDP_LitPop_BM2016.mat']; % saved to entity folder
    if parameters.mainLand
        parameters.output_entity_file = [admin0_ISO3 'mainLand_GDP_LitPop_BM2016.mat'];
    end
end
if parameters.save_as_entity_file && parameters.debug_mode
    parameters.output_entity_file = [admin0_ISO3 '_GDP_LitPop_BM2016_DEBUG.mat']; % saved to entity folder
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
% get the admin0 boundaries (countries)
if exist(admin0_shape_file,'file')
    shapes0=climada_shaperead(admin0_shape_file); % read the admin1 shapes
    n_shapes_admin0=length(shapes0);
else
    fprintf('ERROR: admin0 shape file %s not found, aborted\n',admin1_shape_file);
    fprintf('download from www.naturalearthdata.com\n');
    fprintf('and store in %s\n',module_data_dir);
    return
end
%%
% load input data
GDP_admin0 = climada_xlsread(0,GDP_admin0_file,'world_GDP_current');
if parameters.do_agrar
    load(GDP_agrar_admin0_file); % GDP_share_agrar (variable)
    % load global agriculture output entity
    GLB_agriculture = climada_entity_load(agrar_entity_file);
end
% load country specific files: 
% Lit Population from GWP and Black Marble
litpop=load(litpop_file); % litpop.([admin0_ISO3 '_LitPopulation'])
if parameters.mainLand
    litpop.([admin0_ISO3 '_ind']) = litpop.mainLand_ind;
    litpop.([admin0_ISO3 '_LitPopulation']) = litpop.mainLand_LitPopulation;
end
if ~isfield(litpop,'lon')
    litpop.lon = litpop.gpw_lon(litpop.([admin0_ISO3 '_ind']));
end
if ~isfield(litpop,'lat')
    litpop.lat = litpop.gpw_lat(litpop.([admin0_ISO3 '_ind']));
end

% list of admin1 with GSPD:
idx = ~cellfun('isempty',strfind({shapes.adm0_a3},admin0_ISO3));
i1 = find(idx==1); 
if parameters.debug_mode, i1=i1(min(5,length(i1)));end % only process one single admin1
% find index of country (admin0 )
idx = ~cellfun('isempty',strfind({shapes0.ISO_A3},admin0_ISO3));
i0 = find(idx==1); 
clear idx
admin1_names = {shapes.name}; 
admin1_adm1_cod_1 = {shapes.adm1_cod_1}; 

%% distribute national GDP to grid points
if parameters.admin0_calc
    tic
    % find grid points inside country's polygon
    % shapes.BoundingBox = [Lon_min, Lat_min; Lon_max, Lat_max];
    if parameters.do_agrar
        %%
        in_box_agrar = find(GLB_agriculture.assets.lon>=shapes0(i0).BoundingBox(1,1) &...
                           GLB_agriculture.assets.lon<=shapes0(i0).BoundingBox(2,1) &...
                           GLB_agriculture.assets.lat>=shapes0(i0).BoundingBox(1,2) &...
                           GLB_agriculture.assets.lat<=shapes0(i0).BoundingBox(2,2));

        IN0_agrar = climada_inpolygon(GLB_agriculture.assets.lon(in_box_agrar),GLB_agriculture.assets.lat(in_box_agrar),shapes0(i0).X,shapes0(i0).Y,0);
       
        %%
    end
    % IN0_litpop = climada_inpolygon(litpop.lon,litpop.lat,shapes0(i0).X,shapes0(i0).Y,0); % only if not cut out already
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
    clear litpop
    admin0.litpop.Norm = admin0.litpop.Value./sum(admin0.litpop.Value(:));
    
    %% find country in GDP structs:
    i0_GDP = find(~cellfun('isempty',strfind(GDP_admin0.iso,admin0_ISO3))==1);   
    if parameters.do_agrar
        i0_agrar_share = find(~cellfun('isempty',strfind(GDP_share_agrar.Country_Code,admin0_ISO3))==1);
        if isequal(GDP_share_agrar.Att_2016{i0_agrar_share},'NaN') || isnan(GDP_share_agrar.Att_2016{i0_agrar_share})
            GDP_share_agrar.Att_2016{i0_agrar_share} = GDP_share_agrar.Att_2015{i0_agrar_share};
        end
    end
    %% Distribute GDP to gridpoints
    GDP_admin0_ref = GDP_admin0.year2016(i0_GDP); % from worldbank
    GDP_admin0_ref =     GDP_admin0_ref(1);    
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
    catch ME
        warning('climada_xlsread failed. Either for technical reasons (java?) or missing file(s): admin1_GSDP_file, admin1_mapping_file');
 %       warning([admin0_name ': Import of state/ province level GDP (GSDP) not yet implemented for this country! Please implement if required.']);
        display(ME.identifier)
        display(ME.message)
    end   
    % GSDP normalization:
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
            in_box_agrar = find(admin0.agriculture.assets.lon>=shapes(i1(i)).BoundingBox(1,1) &...
                           admin0.agriculture.assets.lon<=shapes(i1(i)).BoundingBox(2,1) &...
                           admin0.agriculture.assets.lat>=shapes(i1(i)).BoundingBox(1,2) &...
                           admin0.agriculture.assets.lat<=shapes(i1(i)).BoundingBox(2,2));
            if parameters.do_agrar
                IN_agrar  = climada_inpolygon(admin0.agriculture.assets.lon(in_box_agrar),admin0.agriculture.assets.lat(in_box_agrar),shapes(i1(i)).X,shapes(i1(i)).Y,0);
            end
            in_box = find(admin0.litpop.lon>=shapes(i1(i)).BoundingBox(1,1) &...
                           admin0.litpop.lon<=shapes(i1(i)).BoundingBox(2,1) &...
                           admin0.litpop.lat>=shapes(i1(i)).BoundingBox(1,2) &...
                           admin0.litpop.lat<=shapes(i1(i)).BoundingBox(2,2));
            if parameters.admin1_calc
                IN_litpop = climada_inpolygon(admin0.litpop.lon(in_box),admin0.litpop.lat(in_box),shapes(i1(i)).X,shapes(i1(i)).Y,0);
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
                litpop_tmp(in_box(IN_litpop==1)) = litpop_tmp(in_box(IN_litpop==1))/nansum(litpop_tmp(in_box(IN_litpop==1))); % normalized by admin1 level
                if round(full(nansum(litpop_tmp(in_box(IN_litpop==1)))).*1e9)~=1e9      
                    warning('nansum(litpop_tmp(in_box(IN_litpop==1))) is not equal to 1. Normalization failed.')
                else % distribute GSDP to gridpoints in state/ province (admin1): 
                    admin0.GDP.FromLitPop_admin1(in_box(IN_litpop==1)) = litpop_tmp(in_box(IN_litpop==1)).*admin1.GSDP_Reference(i); % multiply by reference GSDP
                end
                clear litpop_tmp
                admin1.GSDP_FromLitPop_admin1(i) = sum(admin0.GDP.FromLitPop_admin1(in_box(IN_litpop==1)));
                admin1.GSDP_FromLitPop(i) = sum(admin0.GDP.FromLitPop(in_box(IN_litpop==1)));
            end
            % Test sum: summing up gridpoints over one admin1 (=GSDP):
            
            if parameters.do_agrar && parameters.admin1_calc
                admin1.GSDP_FromLitPop_minus_agrar(i) = sum(admin0.GDP.FromLitPop_minus_agrar(in_box(IN_litpop==1)));
                admin1.GSDP_FromAgrar(i) = sum(admin0.GDP.FromAgrar(in_box_agrar(IN_agrar==1)));   
            end
            
            clear IN_*
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
if parameters.save_admin0
    save(parameters.output_admin0_file,'admin0','-v7.3');
end
%% Creating entity file

entity = climada_entity_load('entity_template_ADVANCED.mat');

entity.assets.reference_year = 2016;


entity.assets.lon = admin0.litpop.lon';
entity.assets.lat = admin0.litpop.lat';
entity.assets.litpop = (full(admin0.litpop.Value))';
if parameters.save_admin1
    entity.assets.Value = (full(admin0.GDP.FromLitPop_admin1))';
else
    entity.assets.Value = (full(admin0.GDP.FromLitPop))';
end
entity.assets.Cover = entity.assets.Value;
entity.assets.Deductible = 0*entity.assets.Value;
entity.assets.Category_ID = ones(size(entity.assets.Value));
entity.assets.DamageFunID = entity.assets.Category_ID;
entity.assets.Region_ID = entity.assets.Category_ID;
entity.assets.Value_unit = repmat({'USD'},size(entity.assets.Category_ID));
try
    entity.assets = rmfield(entity.assets,'centroid_index');
    entity.assets = rmfield(entity.assets,'hazard');
end
if parameters.do_agrar
    entity.assets.Value_Agrar = (full(admin0.GDP.FromAgrar))';
    entity.assets.Value_LitPop_minus_Agrar = (full(admin0.GDP.FromLitPop_minus_agrar))'; 
end
if isfield(parameters,'hazard_file') && (ischar(parameters.hazard_file) || isstring(parameters.hazard_file))
    hazard = climada_hazard_load(parameters.hazard_file);
    entity = climada_assets_encode(entity,hazard);%,40000);
end
if parameters.save_as_entity_file
    entity.assets.filename = parameters.output_entity_file;
    tic
    disp('Writing to entity file...');
    save([climada_global.entities_dir filesep entity.assets.filename],'entity','-v7.3')
    toc
end

if parameters.make_plot
    figure(1); climada_entity_plot(entity,2); title('admin1')
    entity.assets.Value = (full(admin0.GDP.FromLitPop))';
    figure(2); climada_entity_plot(entity,2); title('admin0')
    entity.assets.Value = (full(admin0.GDP.FromLitPop_admin1))';
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

if parameters.make_plot
    
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
