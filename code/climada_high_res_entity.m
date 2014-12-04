function entity=climada_high_res_entity(img_filename,check_plot,select_admin0,admin0_name,admin1_name)
% world border map country political
% NAME:
%	climada_high_res_entity
% PURPOSE:
%   Construct an entity file baed on high-res night light data. Reads an
%   image file with nightlight density and matches it to the local geography
%
%   Prompts for country (admin0) and state/province (admin1), fetches the
%   tile of night light density from www, constrains the active centroids
%   (with values>0) to the selected country or admin1 (see
%   restrict_Values_to_admin in PARAMETERS in code) and saves the entity.
%
%   Since we're dealing with admin1, no automatic scaling or allocation of
%   GDP to centroids is performed (see climada_create_GDP_entity)
%
%   See also climada_create_GDP_entity
% CALLING SEQUENCE:
%   entity=climada_high_res_entity(img_filename,check_plot,select_admin0,admin0_name,admin1_name)
% EXAMPLE:
%   entity=climada_high_res_entity('ASK',0,0,'Austria','Steiermark') % prompts for image file, then restricts entity to Steiermark
%   entity=climada_high_res_entity;
%   climada_entity_plot(entity)
% INPUTS:
%   img_filename: the filename of an image with night light density, as
%       created using the GUI at http://maps.ngdc.noaa.gov/viewers/dmsp_gcv4/
%       and select Satellite F18, 2010, avg_lights_x_pct, then 'Download
%       data' and enter the coordinates
%       The filename has to be of form A_B_C_D_*..lzw.tiff with A,B,C and D
%       the min lon, min lat, max lon and max lat (integer), like
%       87_20_94_27_F182010.v4c.avg_lights_x_pct.lzw.tiff
%       You find the four edge coordinates also in the html code to get the
%       tile of the nightlight data, as the bbox parameters, e.g.
%       http://mapserver.ngdc.noaa.gov/cgi-bin/public/gcv4/
%       F182010.v4c.avg_lights_x_pct.lzw.tif?request=GetCoverage&service=WCS
%       &version=1.0.0&COVERAGE=F182010.v4c.avg_lights_x_pct.lzw.tif
%       &crs=EPSG:4326&format=geotiff&resx=0.0083333333&resy=0.0083333333
%       &bbox=87,20,94,27
%       If empty, we ask for a country and state/province (see
%       select_admin0) and fetch the image with night light density from
%       www.
%       ='ASK' prompt for an image file, rather than fetching it (again)
%       from www.
% OPTIONAL INPUT PARAMETERS:
%   check_plot: if =1: plot nightlight data with admin0 (countries)
%       superimposed, if=2 also admin1 (country states/provinces)
%       =0: no plot (default)
%   select_admin0: =1: select admin0 (full country), not admin1 (country
%       state/province). Note that select_admin0=1 might lead to memory issues
%       for large(r) countries. Default=0
%   admin0_name: if passed on, do not prompt for country name
%       Also useful if a img_filename is passed and thus if admin0_name is
%       defined, the respective country is cut out
%   admin1_name: if passed on, do not prompt for admin1 name
%       Most useful for subsequent calls, i.e. once one knows the exact
%       admin1 name. Also useful if a img_filename is passed and thus if
%       admin1_name is defined, the respective admin1 is cut out.
%       NOTE: Still an issue with ?..., i.e. Zrich does not work if entered
%       as admin1_name, but works if selected from list-dialog
% OUTPUTS:
%   entity: a full climada entity, see climada_entity_read
%       and see e.g. climada_entity_plot to check
% RESTRICTIONS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141202
% David N. Bresch, david.bresch@gmail.com, 20141203, country and admin1 selection
% David N. Bresch, david.bresch@gmail.com, 20141204, 'ASK' debugged
%-

entity=[]; % init

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% check for arguments
if ~exist('img_filename','var'),img_filename=''; end
if ~exist('check_plot','var'),check_plot=0; end
if ~exist('select_admin0','var'),select_admin0=[]; end
if ~exist('admin0_name','var'),admin0_name=''; end
if ~exist('admin1_name','var'),admin1_name=''; end

% locate the moduel's data
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% check for other modules which are needed:
if isempty(which('country_admin1_risk_calc'))
    fprintf('install climada module country_risk first, see https://github.com/davidnbresch/climada_module_country_risk\n');
    return
end

if isempty(which('climada_create_GDP_entity'))
    fprintf('install climada module GDP_entity first, see https://github.com/davidnbresch/climada_module_GDP_entity\n');
    return
end

% PARAMETERS
%
% crate the entity for the rectangular are, but store the values only for
% the (center/selected) country
restrict_Values_to_coutry=1;
%
% admin0 and admin1 shap files, borrowed from climada module country_risk:
country_risk_data_folder=[fileparts(fileparts(which('country_admin1_risk_calc'))) filesep 'data'];
admin0_shape_file=[country_risk_data_folder filesep 'ne_10m_admin_0_countries' filesep 'ne_10m_admin_0_countries.shp'];
admin1_shape_file=[country_risk_data_folder filesep 'ne_10m_admin_1_states_provinces' filesep 'ne_10m_admin_1_states_provinces.shp'];
%
% base entity file, borrowed from climada module GDP_entity:
GDP_entity_data_folder=[fileparts(fileparts(which('climada_create_GDP_entity'))) filesep 'data'];
entity_file=[GDP_entity_data_folder filesep 'entity_global_without_assets.xls'];
% TEST
% a tile of nightlights downloaded from http://maps.ngdc.noaa.gov/viewers/dmsp_gcv4/
% e.g. http://mapserver.ngdc.noaa.gov/cgi-bin/public/gcv4/F182010.v4c.avg_lights_x_pct.lzw.tif?request=GetCoverage&service=WCS&version=1.0.0&COVERAGE=F182010.v4c.avg_lights_x_pct.lzw.tif&crs=EPSG:4326&format=geotiff&resx=0.0083333333&resy=0.0083333333&bbox=87,20,94,27
%img_filename=[module_data_dir filesep 'system' filesep '87_20_94_27_F182010.v4c.avg_lights_x_pct.lzw.tiff'];
close all % for TEST

% read admin0 (country) shape file (we need this in any case)
admin0_shapes=shaperead(admin0_shape_file);
admin1_shapes=[]; % init

selection_admin0_shape_i=[]; % init
selection_admin1_shape_i=[]; % init

if isempty(img_filename) % local GUI
    
    % no filename passed, we ask for admin0 and admin1...
    
    if isempty(admin0_name)
        
        % generate the list of countries
        for shape_i=1:length(admin0_shapes)
            admin0_name_list{shape_i}=admin0_shapes(shape_i).ADMIN;
        end % shape_i
        
        [liststr,sort_index] = sort(admin0_name_list);
        
        % prompt for a country name
        [selection,ok] = listdlg('PromptString','Select one country (Cncl -> img):',...
            'ListString',liststr,'SelectionMode','single');
        pause(0.1)
        if ~isempty(selection)
            admin0_name = admin0_name_list{sort_index(selection)};
        else
            img_filename='ASK'; % Cancel pressed, later prompt for filename
        end
        
    end % isempty(admin0_name)
    
    % find the country in the shape file
    admin0_shape_i=0;
    for shape_i=1:length(admin0_shapes)
        if strcmp(admin0_shapes(shape_i).ADMIN,admin0_name)
            admin0_shape_i=shape_i;
        end
    end % shape_i
    
    selection_admin0_shape_i=admin0_shape_i;
    
    if ~strcmp(img_filename,'ASK')
        
        if select_admin0
            
            % prepare parameters for www call to fetch the tile of the global map
            bbox(1)=floor(admin0_shapes(selection_admin0_shape_i).BoundingBox(1));
            bbox(3)=ceil(admin0_shapes(selection_admin0_shape_i).BoundingBox(2));
            bbox(2)=floor(admin0_shapes(selection_admin0_shape_i).BoundingBox(3));
            bbox(4)=ceil(admin0_shapes(selection_admin0_shape_i).BoundingBox(4));
            admin1_name='';
            
        else
            
            % add (country states/provinces)
            fprintf('processing admin1 shapes ...\n'); % prompt, since takes a bit of time...
            if isempty(admin1_shapes),admin1_shapes=shaperead(admin1_shape_file);end % read admin1 shape file
            % figure which shapes within the country we need
            admin1_shape_i=0;next_admin1=1; % init
            for shape_i=1:length(admin1_shapes)
                for country_i=1:length(admin0_shape_i)
                    if strcmp(admin0_shapes(admin0_shape_i(country_i)).ADMIN,admin1_shapes(shape_i).admin)
                        admin1_shape_i(next_admin1)=shape_i;
                        next_admin1=next_admin1+1;
                    end
                end % country_i
            end % shape_i
            
            if isempty(admin1_name)
                
                % plot admin0 (country) shape(s)
                for admin0_i=1:length(admin0_shape_i)
                    shape_i=admin0_shape_i(admin0_i);
                    plot(admin0_shapes(shape_i).X,admin0_shapes(shape_i).Y,'-r','LineWidth',2);
                    hold on; axis equal
                end % country_i
                set(gcf,'Color',[1 1 1]) % whithe figure background
                
                % plot admin1 (country states/provinces) shapes
                liststr=[]; % reset
                for admin1_i=1:length(admin1_shape_i)
                    shape_i=admin1_shape_i(admin1_i);
                    plot(admin1_shapes(shape_i).X,admin1_shapes(shape_i).Y,'-r','LineWidth',1);
                    text(admin1_shapes(shape_i).longitude,admin1_shapes(shape_i).latitude,admin1_shapes(shape_i).name);
                    liststr{admin1_i}=admin1_shapes(shape_i).name; % compile list of admin1 names
                end % admin1_i
                
                % show list dialog to select admin1 (now easy as names shown on plot)
                [selection,ok] = listdlg('PromptString','Select admin1:',...
                    'ListString',liststr,'SelectionMode','single');
                if ~ok,return;end
                pause(0.1)
                if ~isempty(selection)
                    admin1_name=['_' deblank(liststr{selection})]; % _ for filename, see below
                    selection_admin1_shape_i=admin1_shape_i(selection);                    
                else
                    return
                end % ~isempty(selection)
                
            else
                
                for shape_i=1:length(admin1_shapes)
                    if strcmp(admin1_shapes(shape_i).name,admin1_name)
                        selection_admin1_shape_i=shape_i;
                    end
                end % shape_i
                
            end % isempty(admin1_name)
            
            % prepare parameters for www call to fetch the tile of the global map
            bbox(1)=floor(admin1_shapes(selection_admin1_shape_i).BoundingBox(1));
            bbox(3)=ceil(admin1_shapes(selection_admin1_shape_i).BoundingBox(2));
            bbox(2)=floor(admin1_shapes(selection_admin1_shape_i).BoundingBox(3));
            bbox(4)=ceil(admin1_shapes(selection_admin1_shape_i).BoundingBox(4));
            
        end % select_admin0
        
        % make sure at least 2 deg in each direction
        if abs(bbox(3)-bbox(1))<2,bbox(1)=bbox(1)-1;bbox(3)=bbox(3)+1;end
        if abs(bbox(4)-bbox(2))<2,bbox(2)=bbox(2)-1;bbox(4)=bbox(4)+1;end
        % prepare parameters for www call to fetch the tile of the global map
        bbox_file_pref=sprintf('%i_%i_%i_%i_',bbox);
        
        if isempty(img_filename)
            
            % construct the filename and fetch the image tile from www
            
            img_filename=[climada_global.data_dir filesep 'results' filesep bbox_file_pref admin0_name admin1_name '_high_res.avg_lights.lzw.tiff'];
            fprintf('%s\n',img_filename);
            
            if ~fetch_mapserver_ngdc_noaa_gov_gcv4(bbox,img_filename),return;end
        end
        
    end % ~strcmp(img_filename,'ASK')
    
end % isempty(img_filename)

if strcmp(img_filename,'ASK')
    % Prompt for image file
    img_filename=[climada_global.data_dir filesep '*.tiff'];
    [filename, pathname] = uigetfile(img_filename, 'Select night light image:');
    if isequal(filename,0) || isequal(pathname,0) % Cancel pressed
        return
    else
        img_filename=fullfile(pathname,filename);
    end
end

% some double-checks (for the special case where an img_filename and
% admin0_name and admin1_name are passed)
if isempty(selection_admin0_shape_i) && ~isempty(admin0_name)
    admin0_name=admin0_name;
    for shape_i=1:length(admin0_shapes)
        if strcmp(admin0_shapes(shape_i).ADMIN,admin0_name)
            selection_admin0_shape_i=shape_i;
        end
    end % shape_i
end
if isempty(selection_admin1_shape_i) && ~isempty(admin1_name)
    if isempty(admin1_shapes),admin1_shapes=shaperead(admin1_shape_file);end % read admin1 shape file
    for shape_i=1:length(admin1_shapes)
        if strcmp(admin1_shapes(shape_i).name,admin1_name)
            selection_admin1_shape_i=shape_i;
        end
    end % shape_i
end

% read the image
img=imread(img_filename);
img=img(end:-1:1,:); % switch for correct order in lattude (images are saved 'upside down')

% infer the edge coordiantes from the filename
try
    [~,fN]=fileparts(img_filename);
    [single_token,remaining_str]=strtok(fN,'_');
    bbox=str2num(single_token);
    [single_token,remaining_str]=strtok(remaining_str,'_');
    bbox(2)=str2num(single_token);
    [single_token,remaining_str]=strtok(remaining_str,'_');
    bbox(3)=str2num(single_token);
    [single_token,remaining_str]=strtok(remaining_str,'_');
    bbox(4)=str2num(single_token);
    % entity_save_file=strrep(remaining_str,'.tiff',''); % start from filename withoput bbox
    entity_save_file=strrep(fN,'.tiff',''); % name with bbox
    entity_save_file=strrep(entity_save_file,'.lzw','');
    entity_save_file=[climada_global.data_dir filesep 'entities' ...
        filesep strrep(entity_save_file,'.','') '.mat'];
catch
    fprintf('ERROR: filename does not contain boundig box coordinates, please\n');
    fprintf('make sure it is of form A_B_C_D_*.lzw.tiff with A,B,C and D the min lon, min lat, max lon and max lat (integer)\n');
    return
end

% define the corresponding x and y axes:
img_area=[bbox(1) bbox(3) bbox(2) bbox(4)]; % [minlon maxlon minlat maxlat]
xx=(img_area(2)-img_area(1))*(1:size(img,2))/size(img,2)+img_area(1);
yy=(img_area(4)-img_area(3))*(1:size(img,1))/size(img,1)+img_area(3);
[X,Y]=meshgrid(xx,yy); % construct regular grid

% patch zeros
VALUES=double(img);

% figure which admin0 (country) shapes we need
% done before check_plot, as used below again
fprintf('processing admin0 shapes ...\n');
admin0_shapes=shaperead(admin0_shape_file); % read admin0 (country) shape file
x=[bbox(1) bbox(1) bbox(3) bbox(3) (bbox(1)+bbox(3))/2];
y=[bbox(2) bbox(4) bbox(2) bbox(4) (bbox(2)+bbox(4))/2];
admin0_shape_i=0;next_admin0=1; % init
for shape_i=1:length(admin0_shapes)
    country_hit=inpolygon(x,y,admin0_shapes(shape_i).X,admin0_shapes(shape_i).Y);
    if sum(country_hit)>0
        admin0_shape_i(next_admin0)=shape_i;
        next_admin0=next_admin0+1;
    end
end % shape_i

if check_plot
    % plot the image (kind of 'georeferenced')
    pcolor(X,Y,VALUES);
    shading flat
    axis(img_area)
    hold on
    set(gcf,'Color',[1 1 1]) % whithe figure background
    
    % plot admin0 (country) shapes
    for admin0_i=1:length(admin0_shape_i)
        shape_i=admin0_shape_i(admin0_i);
        plot(admin0_shapes(shape_i).X,admin0_shapes(shape_i).Y,'-r','LineWidth',2);
    end % country_i
    
    if check_plot>1
        fprintf('processing admin1 shapes ...\n');
        % figure which admin1 (country states/provinces) shapes we need
        if isempty(admin1_shapes),admin1_shapes=shaperead(admin1_shape_file);end % read admin1 shape file
        admin1_shape_i=0;next_admin1=1; % init
        for shape_i=1:length(admin1_shapes)
            for country_i=1:length(admin0_shape_i)
                if strcmp(admin0_shapes(admin0_shape_i(country_i)).ADMIN,admin1_shapes(shape_i).admin)
                    admin1_shape_i(next_admin1)=shape_i;
                    next_admin1=next_admin1+1;
                end
            end % country_i
        end % shape_i
        
        % plot admin1 (country states/provinces) shapes
        for admin1_i=1:length(admin1_shape_i)
            shape_i=admin1_shape_i(admin1_i);
            plot(admin1_shapes(shape_i).X,admin1_shapes(shape_i).Y,'-r','LineWidth',1);
        end % country_i
    end % check_plot>1
end % check_plot

% read the empty entity
if exist(entity_file,'file')
    entity=climada_entity_read(entity_file,'SKIP');
    entity=rmfield(entity,'assets');
    entity.assets.comment=sprintf('generated by %s at %s',mfilename,datestr(now));
    entity.assets.filename=img_filename;
    entity.assets.Longitude=X(:)';
    entity.assets.Latitude=Y(:)';
    VALUES_1D=VALUES(:); % one dimension
    if restrict_Values_to_coutry % reduce to assets within the country or admin1
        entity.assets.Value=entity.assets.Longitude*0; % init
        if isempty(selection_admin0_shape_i) % find center country
            
            % find center of centroids
            center_lon=mean(entity.assets.Longitude);
            center_lat=mean(entity.assets.Latitude);
            
            % find the country in the shape file
            admin0_shape_i=0;
            for shape_i=1:length(admin0_shapes)
                admin_hit=inpolygon(center_lon,center_lat,...
                    admin0_shapes(shape_i).X,admin0_shapes(shape_i).Y);
                if sum(admin_hit)>0,admin0_shape_i=shape_i;end
            end % shape_i
            selection_admin0_shape_i=admin0_shape_i(1);
            
        end
        if isempty(selection_admin1_shape_i)
            fprintf('restricting %i assets to country %s...\n',length(VALUES_1D),admin0_shapes(selection_admin0_shape_i).ADMIN);
            admin_hit=inpolygon(entity.assets.Longitude,entity.assets.Latitude,...
                admin0_shapes(selection_admin0_shape_i).X,admin0_shapes(selection_admin0_shape_i).Y);
        else
            fprintf('restricting %i assets to admin1 %s...\n',length(VALUES_1D),admin1_shapes(selection_admin1_shape_i).name);
            admin_hit=inpolygon(entity.assets.Longitude,entity.assets.Latitude,...
                admin1_shapes(selection_admin1_shape_i).X,admin1_shapes(selection_admin1_shape_i).Y);
        end
        if sum(admin_hit)>0
            entity.assets.Value(admin_hit)=VALUES_1D(admin_hit)';
        end
    else
        entity.assets.Value=VALUES_1D';
    end % restrict_Values_to_coutry
    entity.assets.Deductible=entity.assets.Value*0;
    entity.assets.Cover=entity.assets.Value;
    entity.assets.DamageFunID=entity.assets.Value*0+1;
    entity.assets.reference_year=climada_global.present_reference_year;
    fprintf('saving entity as %s\n',entity_save_file);
    save(entity_save_file,'entity');
    fprintf('consider encoding entity to a particular hazard, see climada_assets_encode\n');
else
    fprintf('base entity %s not found, entity creation skipped\n',entity_file);
end

return % climada_high_res_entity




function ok=fetch_mapserver_ngdc_noaa_gov_gcv4(bbox,img_filename)
% fetch a tile of the global night light high-res image

http_str='http://mapserver.ngdc.noaa.gov/cgi-bin/public/gcv4/F182010.v4c.avg_lights_x_pct.lzw.tif?request=GetCoverage&service=WCS&version=1.0.0&COVERAGE=F182010.v4c.avg_lights_x_pct.lzw.tif&crs=EPSG:4326&format=geotiff&resx=0.0083333333&resy=0.0083333333';
bbox_str=sprintf('&bbox=%i,%i,%i,%i',bbox);
bbox_file_pref=sprintf('%i_%i_%i_%i_',bbox);
www_filename=[http_str bbox_str];

fprintf('issueing %s\n',www_filename);
fprintf('should it fails, please enter in a browser, it often works better, start the filename with %s\n',bbox_file_pref);

[S,STATUS] = urlread(www_filename);
if STATUS==1
    fid=fopen(img_filename,'w');
    fprintf(fid,'%s',S);
    fclose(fid);
    fprintf('%s (fetch_mapserver_ngdc_noaa_gov_gcv4) done\n',mfilename)
    ok=1;
else
    fprintf('%s (fetch_mapserver_ngdc_noaa_gov_gcv4) FAILED\n',mfilename)
    ok=0;
end

return % fetch_mapserver_ngdc_noaa_gov_gcv4