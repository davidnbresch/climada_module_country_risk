function country_risk=country_admin1_risk_calc(country_name,probabilistic,check_plots,admin1_save_entity)
% climada country admin1 risk calc
% MODULE:
%   country_risk
% NAME:
%   country_admin1_risk_calc
% PURPOSE:
%   Run the all (available) perils for one country's admin1 level
%
%   Obtain the admin1 boundaries (from www.naturalearthdata.com, see
%   PARAMETERS in code) and carve out the respective centroids (set Value
%   at all others to zero). Run the risk calculation for each admin1 for
%   all hazards. In case one would like to skip hazards, just (temporarily)
%   remove the respective {country_name}_*.mat hazard event sets.
%
%   ONLY makes sense if country_risk_calc has been run for the respective
%   country (we keep it like this, as automatic mode might trigger lots of
%   un-wanted calculations). If not, the code terminates with the
%   respective messages (no entity found, no hazard set(s) found...)
%   But one can run country_admin1_risk_calc for more than one
%   country (see country_name), if the respective countries have been run
%   as country_risk_calc.
%
%   NOTE: Before using this code, make yourself familiar with 
%   country_risk_calc
%
%   next step: country_risk_report (same format as country_risk_calc)
% CALLING SEQUENCE:
%   country_risk=country_admin1_risk_calc(country_name,probabilistic,check_plots)
% EXAMPLE:
%   country_risk=country_admin1_risk_calc; % interactive, select country from dropdown
%   country_risk=country_admin1_risk_calc('ALL',0,0,0) % whole world, no figures
%   country_risk=country_admin1_risk_calc({'Germany','Switzerland'}) % just two countries
% INPUTS:
%   country_name: name of the country, like 'Switzerland', or a list of
%       countries, like {'Switzerland','Germany','France'}, see
%       climada_create_GDP_entity.
%       If set to 'ALL', the code runs recursively through ALL countries
%       (mind the time this will take...)
%       > prompted for via dropdown list if empty (allows for single or
%       multiple country selection)
% OPTIONAL INPUT PARAMETERS:
%   probabilistic: Just to keep the same parameters as in country_risk_calc.
%       Has no effect, since hazard event sets are generated in
%       country_risk_calc, not in country_admin1_risk_calc
%   check_plots: if =1, show figures to check hazards etc.
%       If =0, skip figures (default)
%       If =100, plot only, skip calculations
%       If country_name is set to 'ALL', be careful to set check_plots=1
%   admin1_save_entity: =1 to save all the admin1 entities as single entity
%       files, =0 to omit this (default)
% OUTPUTS:
%   country_risk(1): a structure with some risk information
%       see country_risk_report to create a readable report to stdout
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141126, initial
% David N. Bresch, david.bresch@gmail.com, 20141212, compatible with new admin0.mat instead of world_50m.gen
% David N. Bresch, david.bresch@gmail.com, 20150110, country naming as in country_risk_calc
% David N. Bresch, david.bresch@gmail.com, 20150112, hazard extensnio '_hist' for historic, '' for probabilistic
%-

country_risk = []; % init output (call it still country_risk, for easy use in country_risk_report

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'), country_name = '';end
if ~exist('probabilistic','var'), probabilistic = 0;end
if ~exist('check_plots' ,'var'), check_plots  = 0;end
if ~exist('admin1_save_entity' ,'var'), admin1_save_entity  = 0;end

module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% whether we show subplots for admin1 centroid selection (for checks)
admin1_check_subplots=check_plots; % default same as check_plots
%
% the folder all data will be stored to, usually the standard climada
% data tree. But since the option country_name='ALL' creates so many
% files, one might divert to e.g. a data folder structure within the
% module
country_data_dir = climada_global.data_dir; % default
%country_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data']; % to store within module
%
% the file with the admin1 boundaries
% (downloaded from www.naturalearthdata.com/downloads/10m-cultural-vectors
% specifically the file: www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_admin_1_states_provinces.zip)
admin1_shape_file=[module_data_dir filesep 'ne_10m_admin_1_states_provinces'...
    filesep 'ne_10m_admin_1_states_provinces.shp'];
%
% Note that, as in country_risk_calc, one would need to re-encode assets to
% each hazard prior to calling the damage calculation (as climada_EDS_calc
% assumes matching order for speedup), unless one knows that all hazard
% event sets are valid on the exact same centroids (the first n elements in
% the hazard are matching the n locations of the assets, while the n+1:end
% elements in hazard are the ones for the buffer around the country). Since
% country_risk_cacl already generated a country hazard event set which
% ensures that and we only set asset values to zero (except the ones within
% the repsective admin1), no need for re-encoding (force_re_encoding=0).
% But in case you're in doubt, set force_re_encoding=1 and check whether
% you get the same results (if yes, very likely no need for
% force_re_encoding=1, otherwise keep =1).
force_re_encoding=0; % default=0

% some folder checks (to be on the safe side)
if ~exist(country_data_dir,'dir'),mkdir(fileparts(country_data_dir),'data');end
if ~exist([country_data_dir filesep 'system'],'dir'),mkdir(country_data_dir,'system');end
if ~exist([country_data_dir filesep 'entities'],'dir'),mkdir(country_data_dir,'entities');end
if ~exist([country_data_dir filesep 'hazards'],'dir'),mkdir(country_data_dir,'hazards');end

if isempty(country_name) % prompt for country or region
    country_name = climada_country_name('Multiple');
    if isempty(country_name),return,end % Cancel selected
end

if strcmp(country_name,'ALL')
    % compile list of all countries, then call recursively below
    country_name = climada_country_name('all');
end

if ~iscell(country_name),country_name = {country_name};end % check that country_name is a cell

if length(country_name)>1 % more than one country, process recursively
    n_countries=length(country_name);
    for country_i = 1:n_countries
        single_country_name = country_name(country_i);
        fprintf('\nprocessing %s (%i of %i) ************************ \n',...
            char(single_country_name),country_i,n_countries);
        country_risk_out(country_i)=country_admin1_risk_calc(single_country_name,probabilistic,check_plots);
    end % country_i
    close all
    country_risk=country_risk_out;
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
country_risk.res.country_name = country_name_char;
country_risk.res.country_ISO3 = country_ISO3;

% define easy to read filenames
entity_file        = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
%entity_future_file = [country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity_future.mat'];

if ~exist(entity_file,'file')
    fprintf('please run country_risk_calc(''%s'') first, skipped\n',country_name_char);
    return
    % one could run it all fully automatic, but the risk is too high that
    % this is not intended (e.g. somebody unadvertently calling...)
    % run the country calculation first to make sure all files exist
    %country_risk_calc(country_name_char,method,force_recalc,check_plots);
end

% get the admin1 boundaries
if exist(admin1_shape_file,'file')
    shapes=climada_shaperead(admin1_shape_file); % read the admin1 shapes
    n_shapes=length(shapes);
else
    fprintf('ERROR: admin1 shape file %s not found, aborted\n',admin1_shape_file);
    fprintf('download www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_admin_1_states_provinces.zip\n');
    fprintf('and store in %s\n',module_data_dir);
    return
end

% find the countries' admin1s
admin1_pos=[];
for shape_i=1:n_shapes
    if strcmp(country_name_char,shapes(shape_i).admin)
        admin1_pos=[admin1_pos shape_i]; % we do not know the number of admin1s a-priori
    end
end % shape_i

next_EDS=1;
Value_checksum=0;
n_admin1=length(admin1_pos);
fprintf('%s (%s): %i admin1\n',shapes(admin1_pos(1)).admin,country_ISO3,n_admin1);

if n_admin1>0
    
    if admin1_check_subplots
        % prepare subplot, figure number of sub-plots and their arrangement
        n_plots=n_admin1;
        N_n_plots=ceil(sqrt(n_plots));n_N_plots=N_n_plots-1;
        if ~((N_n_plots*n_N_plots)>n_plots),n_N_plots=N_n_plots;end
    end
    
    % figure the existing hazard set files
    probabilistic_str='_hist';if probabilistic,probabilistic_str='';end
    hazard_files=dir([country_data_dir filesep 'hazards' filesep ...
        country_ISO3 '_' strrep(country_name_char,' ','') '*' probabilistic_str '.mat']);
    
    % filter, depending on probabilistic
    valid_hazard=1:length(hazard_files);
    for hazard_i=1:length(hazard_files)
        if probabilistic && ~isempty(strfind(hazard_files(hazard_i).name,'_hist.mat'))
            valid_hazard(hazard_i)=0;
        end
    end % hazard_i
    valid_hazard=valid_hazard(valid_hazard>0);
    hazard_files=hazard_files(valid_hazard);
                        
    for admin1_i=1:n_admin1 % loop over all admin1
        shape_i=admin1_pos(admin1_i);
        
        fprintf(' %s (%i of %i): ',shapes(shape_i).name,admin1_i,n_admin1);
        
        admin1_name=shapes(shape_i).name;
        admin1_code=shapes(shape_i).adm1_code;
        
        % reduce entity to admin1
        entity_filename=[country_data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];

        if exist(entity_filename,'file')
            load(entity_filename)% load entity
            entity_assets_Value=entity.assets.Value;
            entity.assets.Value=entity.assets.Value*0;
            admin1_centroids=inpolygon(entity.assets.Longitude,entity.assets.Latitude,shapes(shape_i).X,shapes(shape_i).Y);
            if sum(admin1_centroids)>0 % at least 1 centroid in admin1
                entity.assets.Value(admin1_centroids)=entity_assets_Value(admin1_centroids);
                fprintf('%i centroids (%2.1f%%), val %1.0f (%2.1f%%)\n',...
                    sum(admin1_centroids),100*sum(admin1_centroids)/length(admin1_centroids),...
                    sum(entity.assets.Value),100*sum(entity.assets.Value)/sum(entity_assets_Value));
                
                Value_checksum=Value_checksum+sum(entity.assets.Value);
                
                if admin1_check_subplots>0
                    subplot(N_n_plots,n_N_plots,admin1_i);
                    climada_plot_world_borders,hold on;
                    climada_plot_entity_assets(entity,[],shapes(shape_i).name);
                    %plot(entity.assets.Longitude,entity.assets.Latitude,'xr')
                    %plot(entity.assets.Longitude(admin1_centroids),entity.assets.Latitude(admin1_centroids),'og')
                    plot(shapes(shape_i).X,shapes(shape_i).Y,'LineWidth',2)
                    dbb=1; % degrees around BoundingBox
                    axis([shapes(shape_i).BoundingBox(1)-dbb shapes(shape_i).BoundingBox(2)+dbb ...
                        shapes(shape_i).BoundingBox(3)-dbb shapes(shape_i).BoundingBox(4)+dbb])
                    set(gcf,'Color',[1 1 1]);
                    hold off
                end
                
                if admin1_save_entity
                    admin1_entity_filename=[entity_filename '_' strrep(shapes(shape_i).name,' ','')];
                    fprintf('saving %s\n',admin1_entity_filename);
                    save(admin1_entity_filename,'entity');
                end
                
                if admin1_check_subplots==100
                    
                    fprintf('calculations skipped (plotting only)\n');
                    
                else
                    
                    damagefunctions=entity.damagefunctions; % store
                    
                    for hazard_i=1:length(hazard_files)
                        
                        % run the EDS calculation
                        hazard_set_file=[country_data_dir filesep 'hazards' filesep hazard_files(hazard_i).name];
                        hazard_short_name=strrep(strrep(hazard_files(hazard_i).name,'.mat',''),[country_name_char '_'],'');
                        fprintf('  %s: ',hazard_short_name);
                        if exist(hazard_set_file,'file')
                            load(hazard_set_file); % load hazard set
                            
                            % Note that one would need to re-encode assets to each hazard,
                            % unless one knows that all hazard event sets are valid on the
                            % exact same centroids (the first n elements in the hazard
                            % are matching the n locations of the assets, while the n+1:end
                            % elements in hazard are the ones for the buffer around the
                            % country. The call to centroids_generate_hazard_sets ensures that,
                            % and hence the following code bit is usually not necessary:
                            if force_re_encoding
                                fprintf('re-encoding... \n');
                                assets = climada_assets_encode(entity.assets,hazard);
                                entity=rmfield(entity,'assets');
                                entity.assets=assets; % assign re-encoded assets
                            end
                            
                            if ~isempty(hazard)
                                
                                entity.damagefunctions=damagefunctions; % reset
                                
                                % find the damagefunctions for the peril under consideration
                                if isfield(entity.damagefunctions,'peril_ID') % refine for peril
                                    if sum(strcmp(entity.damagefunctions.peril_ID,hazard.peril_ID(1:2)))>0
                                        % peril_ID found, reasonable damage calculation
                                    else
                                        
                                        % find the TC damagefunction (to start from)
                                        asset_damfun_pos = find(entity.damagefunctions.DamageFunID == entity.assets.DamageFunID(1)); % keep it simple (1)
                                        asset_damfun_pos = asset_damfun_pos(strcmp(entity.damagefunctions.peril_ID(asset_damfun_pos),'TC')); % use TC
                                        
                                        entity.damagefunctions.DamageFunID=entity.damagefunctions.DamageFunID(asset_damfun_pos);
                                        entity.damagefunctions.Intensity=entity.damagefunctions.Intensity(asset_damfun_pos);
                                        entity.damagefunctions.MDD=entity.damagefunctions.MDD(asset_damfun_pos);
                                        entity.damagefunctions.PAA=entity.damagefunctions.PAA(asset_damfun_pos);
                                        
                                        entity.damagefunctions=rmfield(entity.damagefunctions,'peril_ID'); % get rid of the peril_ID
                                        
                                        % DUMMY DAMAGE FUNCTIONS FOR TESTS
                                        % just match max scale of hazard.intensity to max
                                        % damagefunction.intensity
                                        max_damagefunction_intensity=max(entity.damagefunctions.Intensity);
                                        max_hazard_intensity=full(max(max(hazard.intensity)));
                                        damagefunction_scale=max_hazard_intensity/max_damagefunction_intensity;
                                        
                                        entity.damagefunctions.Intensity = entity.damagefunctions.Intensity * damagefunction_scale;
                                        fprintf('(dummy damage) ');
                                        
                                    end
                                end % isfield 'peril_ID'
                                
                                country_risk.res.hazard(next_EDS).EDS=climada_EDS_calc(entity,hazard);
                                country_risk.res.hazard(next_EDS).EDS.annotation_name=...
                                    [shapes(shape_i).admin ' ' shapes(shape_i).name ' ' hazard_short_name];
                                
                                country_risk.res.hazard(next_EDS).admin1_name = admin1_name;
                                country_risk.res.hazard(next_EDS).admin1_code = admin1_code;
                                
                                ED=country_risk.res.hazard(next_EDS).EDS.ED;
                                fprintf('   ED %1.0f (%1.1f%%o)\n',ED,ED/sum(entity.assets.Value)*1000);
                                next_EDS=next_EDS+1; % point to next free EDS
                                
                            else
                                fprintf('   WARNING: %s hazard is empty, skipped\n',hazard_name)
                            end
                            
                        else
                            fprintf('hazard not found, skipped\n');
                        end
                    end % hazard_i
                    
                end % admin1_check_subplots=100
                
            else
                fprintf(' no centroids within, skipped\n');
            end % at least 1 centroid in admin1
            
        else
            fprintf('ERROR: %s not found, skipped\n',entity_filename);
        end % exist(entity_filename)
        
    end % admin1_i
    
    fprintf('%s, sum of admin1 values: %1.0f (%1.0f%% of country value), country value %1.0f\n',...
        country_name_char,Value_checksum,Value_checksum/sum(entity_assets_Value)*100,sum(entity_assets_Value));
else
    fprintf('WARNING: no admin1 for %s, skipped\n',country_name_char);
end % n_admin1>0

return
