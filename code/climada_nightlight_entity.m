function entity=climada_nightlight_entity(admin0_name,admin1_name,selections,check_plot,scale_Value,img_filename,save_entity)
% country admin0 admin1 entity high resolution
% NAME:
%	climada_nightlight_entity
% PURPOSE:
%   Construct an entity file based on high-res (1km!) or mif -res (10km)
%   night light data. 
%
%   Reads an image file with nightlight density and matches it to the local
%   geography.
%
%   Prompts for country (admin0) and state/province (admin1), obtains the
%   high-resolution night lights for this area and constrains the active
%   centroids (with values>0) to the selected country or admin1 (see input
%   parameter selections) and saves the entity.
%
%   Since we're dealing with admin1, no automatic scaling or allocation of
%   GDP to centroids is performed (for this, see
%   climada_create_GDP_entity), unless selection is set for full country
%   (=1), in which case assets are scaled to 6 times GDP, as a proxy for
%   insurable values.
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
%   does not contain the original (.tif). Please note that the GDP_entity
%   could also deal with such a high-res dataset (see respective
%   documentation) - that's why the present code does also check for the
%   night light data to be stored there (see GDP_entity_CHECK in code)
%
%   If the high-resolution night light image is stored locally, it fetches
%   the tile of night light density from www (i.e. asks the user to enter a
%   specific URL, to locally store the respective file) and works from
%   there. (See also http://maps.ngdc.noaa.gov/viewers/dmsp_gcv4/ to obtain
%   a specific 'tile' of the global high res via a web-GUI (but method with
%   the coe suggesting the URL is strongly recommended).
%
%   Programmer's remark: see fetch_mapserver_ngdc_noaa_gov_gcv4 at the
%   bottom of the code, which could in theory fetch the tile from www
%
%   See also climada_create_GDP_entity
% CALLING SEQUENCE:
%   entity=climada_nightlight_entity(admin0_name,admin1_name,selections,check_plot,scale_Value,img_filename,save_entity)
% EXAMPLE:
%   entity=climada_nightlight_entity('Italy','',2); % good for test, as shape of Italy is well-known
%   entity=climada_nightlight_entity('United States of America','Florida',2,2);
%   entity=climada_nightlight_entity('Sswitzerland','',1,0,[0 1 0 -1]); % scale by GDP (the -1)
%   entity=climada_nightlight_entity('CHE','',1); % full country, scale by 6 times GDP as a proxy for insurable values
%   entity=climada_nightlight_entity % all interacrtive
%   climada_entity_plot(entity) % to check the content of the final entity
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   admin0_name: the country name, either full or ISO3
%       > If empty, a list dialog lets the user select (default)
%       Also useful if a img_filename is passed and thus if admin0_name is
%       defined, the respective country is cut out.
%       Instead of explicit country names, one can also use ISO3 country
%       codes (like DEU, CHE). Note that the entity filename will use the
%       full country name, but ISO3 is stored in entity.assets.admin0_ISO3
%       See parameter selections, especially if you want to select a whole
%       country.
%   admin1_name: if passed on, do not prompt for admin1 name
%       > If empty, a list dialog lets the user select (default)
%       Most useful for subsequent calls, i.e. once one knows the exact
%       admin1 name. Also useful if a img_filename is passed and thus if
%       admin1_name is defined, the respective admin1 is cut out.
%       NOTE: Still an issue with some characters, i.e. Zrich does not work
%       if entered as admin1_name, please use the admin1_code, also shown
%       behind the | in the list dialog, e.g. for Zurich, the call hence is
%       entity=climada_nightlight_entity('CHE','CHE-176'). Note that the
%       admin1_name is kept as on input, i.e. 'CHE-176' in the example, not
%       'Zrich'.
%   selections: =0 (default): select admin0 (country) and constrain the active
%       centroids (with values>0) to the selected admin1 (state/province)
%       =10: use 10km instead of 1km night light image
%       resolution. See also remark about using -(selections) below.
%       =1: select admin0 (full country), not admin1 (country
%       state/province). The assets are scaled by country GDP and further
%       multiplied by 6 (as a proxy to scale up for insurable values). 
%       Note that select_admin0=1 might lead to memory issues for large(r)
%       countries, see option =2, too. This usage gets close to
%       climada_create_GDP_entity.
%       =2: select admin0 (like =1) and do not constrain the active
%       centroids (with values>0) to the selected country (good for initial
%       test and speedup, but less useful as an entity for damage
%       calculation later).
%       =3: select admin1 and do not constrain the active
%       centroids (with values>0) to the selected state/province, see 2.
%       <0: If selections is negative, use mid-resolution nightlights (see
%       PARAMETER low_img_filename below). Default is high-res (1km).
%   check_plot: if =1: plot nightlight data with admin0 (countries)
%       superimposed, if=2 also admin1 (country states/provinces)
%       =0: no plot (default)
%   scale_Value: =[a b c], scale entity.assets.Value to account for high
%       nightlihgt intensity to represent larger share of values, as
%       entity.assets.Value =  a + b*entity.assets.Value + c*entity.assets.Value.^2
%       If = [a b c d], normalize after scaling and multziply by d. If d is
%       negative, scale with country GDP (only makes sense if selections=1
%       or =2), but works in other cases, too (as the user might find it
%       useful).
%       Default= [0 1 0 1e9], except for selections=1, in which case the
%       assets are scaled by country GDP and further multiplied by 6 (as a
%       proxy to scale up for insurable values)
%   img_filename: the filename of an image with night light density, as
%       created using the GUI at http://maps.ngdc.noaa.gov/viewers/dmsp_gcv4/
%       and select Satellite F18, 2010, avg_lights_x_pct, then 'Download
%       data' and enter the coordinates
%       The filename has to be of form A_B_C_D_{|E_F}*..lzw.tiff with A,B,C and D
%       the min lon, min lat, max lon and max lat (integer), like
%       87_20_94_27_F182010.v4c.avg_lights_x_pct.lzw.tiff and E and F the
%       country (admin0) and state/province (admin1) name, like
%       -88_24_-79_32_United States of America_Florida_high_res.avg_lights.lzw.tiff
%
%       If empty (eg run the code without any argument), it prompts for country
%       and admin1 name and constructs the URL to get the corresponding
%       tile from the nightlight data, e.g. a string such as:
%       http://mapserver.ngdc.noaa.gov/cgi-bin/public/gcv4/F182010.v4c.
%           avg_lights_x_pct.lzw.tif?request=GetCoverage&service=WCS&
%           version=1.0.0&COVERAGE=F182010.v4c.avg_lights_x_pct.lzw.tif&
%           crs=EPSG:4326&format=geotiff&resx=0.0083333333&resy=0.0083333333&
%           bbox=-88,24,-79,32
%
%       ='ASK' prompt for an image file (without first asking for country
%       where one has to press 'Cancel') to get the to filename prompt
%   save_entity: whether we save the entity (=1, default) or nor (=0).
% OUTPUTS:
%   entity: a full climada entity, see climada_entity_read
%       and see e.g. climada_entity_plot to check
%       entity does contain entity.assets.admin0_name and
%       entity.assets.admin0_ISO3, also for admin1 if restricted to.
% RESTRICTIONS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141202
% David N. Bresch, david.bresch@gmail.com, 20141203, country and admin1 selection
% David N. Bresch, david.bresch@gmail.com, 20141204, 'ASK' debugged, cleaned up
% David N. Bresch, david.bresch@gmail.com, 20141205, high-res locally stored
% David N. Bresch, david.bresch@gmail.com, 20141206, GDP scaling added
% David N. Bresch, david.bresch@gmail.com, 20141209, admin1 name issue resolved
% David N. Bresch, david.bresch@gmail.com, 20141212, compatible with new admin0.mat instead of world_50m.gen
% David N. Bresch, david.bresch@gmail.com, 20141212, renamed to climada_nightlight_entity (formerly climada_high_res_entity)
%-

entity=[]; % init

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% check for arguments
if ~exist('img_filename','var'),img_filename=''; end
if ~exist('check_plot','var'),check_plot=0; end
if ~exist('selections','var'),selections=0; end
if ~exist('admin0_name','var'),admin0_name=''; end
if ~exist('admin1_name','var'),admin1_name=''; end
if ~exist('scale_Value','var'),scale_Value=[0 1 0 1e9]; end
if ~exist('save_entity','var'),save_entity=1; end

% locate the moduel's data
module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

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
% low resolution file (approx. 10x10km). Note that this moderate-size
% (440kB) file is also used in GDP_entity and locally stored there (to
% avoid cross-dependency between the modules country_risk and GDP_entity).
low_img_filename=[module_data_dir filesep 'night_light_2010_10km.png'];
min_South=-65; % degree, defined as for full_img_filename
max_North= 75; % degree, defined as for full_img_filename
%
% admin0 and admin1 shap files (in climada module country_risk):
admin0_shape_file=climada_global.map_border_file; % as we use the admin0 as in next line as default anyway
%admin0_shape_file=[module_data_dir filesep 'ne_10m_admin_0_countries' filesep 'ne_10m_admin_0_countries.shp'];
admin1_shape_file=[module_data_dir filesep 'ne_10m_admin_1_states_provinces' filesep 'ne_10m_admin_1_states_provinces.shp'];
%
% base entity file, borrowed from climada module GDP_entity:
GDP_entity_data_folder=[fileparts(fileparts(which('climada_create_GDP_entity'))) filesep 'data'];
entity_file=[GDP_entity_data_folder filesep 'entity_global_without_assets.xls'];
%
% the Excel file with latest GDP for admin0 (country)
%GDP_data_file=[GDP_entity_data_folder filesep 'World_GDP_current_1960_2010.xls']; % GDP_entity
GDP_data_file=[module_data_dir filesep 'WorldBank_GDP_admin0.xls'];
%
% the annual growht rate we use to correct should latest GDP data in table
% GDP_data_file not be the same as climada_global.present_reference_year:
GDP_AGR=0.02; % global average annual GDP growth rate in decimal (0.02 is 2%)
%
% multiplier to scale GDP to a proxy of insurable values
GDP2TIV_multiplier=6; % default =6
%
% Parameters below very unlikely to change, see input parameter selections
% crate the entity for the rectangular are, but store the values only for
% the (center/selected) country or admin1 (see parameter selections)
restrict_Values_to_coutry=1; % default=1
%
% whether we select admin0 or admin1 (see parameter selections)
select_admin0=0; % default=0, to select admin1

if selections<0 || selections==10
    if selections<0,selections=-selections;end % reverse sign
    if selections<0.2,selections=0;end % to avoid troubles
    full_img_filename=low_img_filename;
    fprintf('%s: switched to moderate resolution (10x10km) nightlight image\n',mfilename)
    moderate_resolution=1;
else
    moderate_resolution=0;
end

% switch the different selections for admin0/1 selection and restriction of values
if selections==1
    % admin0
    select_admin0=1;
    restrict_Values_to_coutry=1;
elseif selections==2
    % admin0, but no restriction of values
    select_admin0=1;
    restrict_Values_to_coutry=0; % fast
elseif selections==3
    % admin1, but no restriction of values
    select_admin0=0;
    restrict_Values_to_coutry=0; % fast
end


% read admin0 (country) shape file (we need this in any case)
admin0_shapes=climada_shaperead(admin0_shape_file);
admin1_shapes=[]; % init

selection_admin0_shape_i=[]; % init
selection_admin1_shape_i=[]; % init

% check for full global night light image being locally available
for i=1:2
    if i==2 % check for alterantive location of the file, GDP_entity_CHECK
        if ~isempty(which('climada_create_GDP_entity')) % check for module to be present
            GDP_entity_data_folder=[fileparts(fileparts(which('climada_create_GDP_entity'))) filesep 'data'];
            full_img_filename=[GDP_entity_data_folder filesep fN fE];
        end
    end
    [fP,fN,fE]=fileparts(full_img_filename);
    full_img_filename_mat=[fP filesep fN '.mat'];
    if ~exist(full_img_filename_mat,'file')
        full_img_filename_mat=''; % not .mat file
        if ~exist(full_img_filename,'file')
            full_img_filename='';
            full_img_exists=0;
        else
            full_img_exists=1; % .mat of full image exists
            break
        end % not full file
    else
        full_img_filename=''; % no need for original, since .mat exists
        full_img_exists=1;
        break
    end
end % i

bbox=[]; % init

if isempty(img_filename) % local GUI
    
    % no filename passed, we ask for admin0 and admin1...
    
    if isempty(admin0_name)
        
        % generate the list of countries
        admin0_name_list={};admin0_code_list={};
        for shape_i=1:length(admin0_shapes)
            admin0_name_list{shape_i}=admin0_shapes(shape_i).NAME;
            admin0_code_list{shape_i}=admin0_shapes(shape_i).ADM0_A3;
        end % shape_i
        
        [liststr,sort_index] = sort(admin0_name_list);
        
        % prompt for a country name
        [selection,ok] = listdlg('PromptString','Select one country (Cncl -> img):',...
            'ListString',liststr,'SelectionMode','single');
        pause(0.1)
        if ~isempty(selection)
            admin0_name = admin0_name_list{sort_index(selection)};
            admin0_code = admin0_code_list{sort_index(selection)};
        else
            img_filename='ASK'; % Cancel pressed, later prompt for filename
        end
        
    end % isempty(admin0_name)
    
    if ~strcmp(img_filename,'ASK')
        
        [admin0_name,admin0_code]=climada_country_name(admin0_name);
        % find the country in the shape file
        admin0_shape_i=0;
        for shape_i=1:length(admin0_shapes)
            if strcmp(admin0_shapes(shape_i).ADMIN,admin0_name)
                admin0_shape_i=shape_i;
            elseif strcmp(admin0_shapes(shape_i).ADM0_A3,admin0_code) % country code (2nd, since safer)
                admin0_shape_i=shape_i;
            end
        end % shape_i
        selection_admin0_shape_i=admin0_shape_i;
        
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
            if isempty(admin1_shapes),admin1_shapes=climada_shaperead(admin1_shape_file);end % read admin1 shape file
            % figure which shapes within the country we need
            admin1_shape_i=0;next_admin1=1; % init
            for shape_i=1:length(admin1_shapes)
                for country_i=1:length(admin0_shape_i)
                    %if strcmp(admin0_shapes(admin0_shape_i(country_i)).ADMIN,admin1_shapes(shape_i).admin)
                    if strcmp(admin0_shapes(admin0_shape_i(country_i)).ADM0_A3,admin1_shapes(shape_i).adm0_a3) % safer
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
                admin1_name_list={};
                admin1_name_code_list={};
                for admin1_i=1:length(admin1_shape_i)
                    shape_i=admin1_shape_i(admin1_i);
                    plot(admin1_shapes(shape_i).X,admin1_shapes(shape_i).Y,'-r','LineWidth',1);
                    text(admin1_shapes(shape_i).longitude,admin1_shapes(shape_i).latitude,admin1_shapes(shape_i).name);
                    admin1_name_list{admin1_i}=admin1_shapes(shape_i).name; % compile list of admin1 names
                    admin1_name_code_list{admin1_i}=[admin1_shapes(shape_i).name ...
                        ' | ' admin1_shapes(shape_i).adm1_code]; % with code
                end % admin1_i
                
                [liststr,sort_index] = sort(admin1_name_code_list);
                
                % show list dialog to select admin1 (now easy as names shown on plot)
                [selection,ok] = listdlg('PromptString','Select admin1:',...
                    'ListString',liststr,'SelectionMode','single');
                if ~ok,return;end
                pause(0.1)
                if ~isempty(selection)
                    admin1_name = admin1_name_list{sort_index(selection)};
                    selection_admin1_shape_i=admin1_shape_i(sort_index(selection));
                else
                    return
                end % ~isempty(selection)
                
            else
                
                for shape_i=1:length(admin1_shapes)
                    if strcmp(admin1_shapes(shape_i).name,admin1_name)
                        selection_admin1_shape_i=shape_i;
                    elseif strcmp(admin1_shapes(shape_i).adm1_code,admin1_name) % also allow for code
                        selection_admin1_shape_i=shape_i;
                     end
                end % shape_i
                
            end % isempty(admin1_name)
            
            if isempty(selection_admin1_shape_i)
                fprintf('%s not found, consider using admin1_code, run once without specifying admin1 to see list of codes\n',admin1_name);
                return
            end
            
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
        
        if isempty(img_filename) && ~full_img_exists
            % we need a tile, since the full file does not exist
            
            % construct the filename
            img_filename=[climada_global.data_dir filesep 'results' filesep bbox_file_pref admin0_name '_' admin1_name '_high_res.avg_lights.lzw.tiff'];
            %fprintf('%s\n',img_filename);
            
            % fetch the image tile from www
            if ~fetch_mapserver_ngdc_noaa_gov_gcv4(bbox,img_filename)
                fprintf('re-start %s(''ASK'') and select the filename you saved\n',mfilename);
                return
            end
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

if isempty(img_filename)
    % we get there if filename is empty on input and full_img_exists
    % hence will use the full img
    if ~isempty(full_img_filename_mat)
        % there is a previously saved .mat version of the full image
        load(full_img_filename_mat) % loads img        
    elseif ~isempty(full_img_filename)
        % there is a full image
        fprintf('reading full global high-res image, takes ~20 sec (%s)\n',full_img_filename);
        if exist(full_img_filename,'file')
        img=imread(full_img_filename);
        img=img(end:-1:1,:); % switch for correct order in lattude (images are saved 'upside down')
        else
            fprintf('full-resolution global night light density image not found, aborted\n')
            fprintf('> Please follow instructions in:\n\t%s\n',...
                [module_data_dir filesep 'F182012.v4c_web.stable_lights.avg_vis.txt'])
            return
        end
        
        xx=360*(1:size(img,2))/size(img,2)+(-180); % -180..180
        yy=(max_North-min_South)*(1:size(img,1))/size(img,1)+min_South;
        
        [fP,fN]=fileparts(full_img_filename);
        full_img_filename_mat=[fP filesep fN '.mat'];
        save(full_img_filename_mat,'img','xx','yy'); % for fast access next time
    else
        fprintf('STUCK, aborted\n')
        return
    end
    
    % img holds the full global image, crop to what we need (for speedup)
    fprintf('cropping lon=%i..%i, lat=%i..%i --> ',bbox(1),bbox(3),bbox(2),bbox(4));
    
    pos_x=find(xx>=bbox(1) & xx<=bbox(3));
    pos_y=find(yy>=bbox(2) & yy<=bbox(4));
    
    fprintf('x=%i..%i, y=%i..%i\n',min(pos_x),max(pos_x),min(pos_y),max(pos_y));
    
    % crop to the area we need
    img=img(pos_y,pos_x);
    xx=xx(pos_x);
    yy=yy(pos_y);
    
else
    
    % read the image (a tile, not the full global one, see just above)
    img=imread(img_filename);
    img=img(end:-1:1,:); % switch for correct order in lattude (images are saved 'upside down')
    
end

% instead of bbox, the plotting further down needs another order
img_area=[bbox(1) bbox(3) bbox(2) bbox(4)]; % [minlon maxlon minlat maxlat]

if isempty(xx) && isempty(yy)
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
        [admin_name_tmp,remaining_str]=strtok(remaining_str,'_');
        if ~strncmp(admin_name_tmp,'F182010',7) && isempty(admin0_name),admin0_name=admin_name_tmp;end
        [admin_name_tmp,remaining_str]=strtok(remaining_str,'_');
        if ~strncmp(admin_name_tmp,'F182010',7) && isempty(admin1_name),admin1_name=admin_name_tmp;end
        
        % define the corresponding x and y axes:
        xx=(img_area(2)-img_area(1))*(1:size(img,2))/size(img,2)+img_area(1);
        yy=(img_area(4)-img_area(3))*(1:size(img,1))/size(img,1)+img_area(3);
    catch
        fprintf('ERROR: filename does not contain boundig box coordinates, please\n');
        fprintf('make sure it is of form A_B_C_D_*.lzw.tiff with A,B,C and D the min lon, min lat, max lon and max lat (integer)\n');
        return
    end
end % isempty(xx) && isempty(yy)

% consistency check, returns both, interprets both name and ISO3
[admin0_name,admin0_ISO3] = climada_country_name(admin0_name); % get full name

% some double-checks (for the special case where an img_filename and
% admin0_name and admin1_name are passed)
if isempty(selection_admin0_shape_i) && ~isempty(admin0_name)
    for shape_i=1:length(admin0_shapes)
        %fprintf('|%s|%s|\n',admin0_shapes(shape_i).ADMIN,admin0_name)
        if strcmp(admin0_shapes(shape_i).ADMIN,admin0_name)
            selection_admin0_shape_i=shape_i;
        elseif strcmp(admin0_shapes(shape_i).ADM0_A3,admin0_ISO3) % ISO3 country code
            selection_admin0_shape_i=shape_i;
        end
    end % shape_i
end
if isempty(selection_admin1_shape_i) && ~isempty(admin1_name)
    if isempty(admin1_shapes),admin1_shapes=climada_shaperead(admin1_shape_file);end % read admin1 shape file
    for shape_i=1:length(admin1_shapes)
        %fprintf('|%s|%s|\n',admin1_shapes(shape_i).name,admin1_name)
        if strcmp(admin1_shapes(shape_i).name,admin1_name)
            selection_admin1_shape_i=shape_i;
        elseif strcmp(admin1_shapes(shape_i).adm1_code,admin1_name) % code
            selection_admin1_shape_i=shape_i;
        end
    end % shape_i
end

if isempty(admin1_name) % country
    entity_save_file=sprintf('%s_%s_%i_%i_%i_%i',admin0_ISO3,admin0_name,bbox);
else % state/province
    entity_save_file=sprintf('%s_%s_%s_%s_%i_%i_%i_%i',admin0_ISO3,admin0_name,...
        admin1_shapes(selection_admin1_shape_i).name,admin1_shapes(selection_admin1_shape_i).adm1_code,bbox);
end
if moderate_resolution
    entity_save_file=[entity_save_file '_10x10'];
else
    entity_save_file=[entity_save_file '_01x01'];
end
entity_save_file=[climada_global.data_dir filesep 'entities' ...
    filesep strrep(entity_save_file,'.','') '.mat'];

[X,Y]=meshgrid(xx,yy); % construct regular grid

% convert to daouble (from uint8)
VALUES=double(img);

% figure which admin0 (country) shapes we need
% done before check_plot, as used below again
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
if ~isempty(selection_admin0_shape_i),...
        admin0_shape_i(next_admin0)=selection_admin0_shape_i;end % to be safe

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
        fprintf('adding admin1 shapes to plot ...\n');
        % figure which admin1 (country states/provinces) shapes we need
        if isempty(admin1_shapes),admin1_shapes=climada_shaperead(admin1_shape_file);end % read admin1 shape file
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

if isempty(which('climada_create_GDP_entity'))
    fprintf('WARNING: install climada module GDP_entity first, see https://github.com/davidnbresch/climada_module_GDP_entity\n');
    fprintf('code continues, but does not return a full enity, just entity.assets\n');
else
    if exist(entity_file,'file')
        entity=climada_entity_read(entity_file,'SKIP'); % read the empty entity
        entity=rmfield(entity,'assets');
    else
        fprintf('WARNING: base entity %s not found, entity just entity.assets\n',entity_file);
    end
    
end

entity.assets.comment=sprintf('generated by %s at %s',mfilename,datestr(now));
entity.assets.filename=img_filename;
if ~isempty(selection_admin1_shape_i),
    entity.assets.ADM0_A3=admin0_shapes(selection_admin0_shape_i).ADM0_A3;end
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
        fprintf('restricting %i assets to country %s (can take some time) ...\n',length(VALUES_1D),admin0_shapes(selection_admin0_shape_i).ADMIN);
        admin_hit=inpolygon(entity.assets.Longitude,entity.assets.Latitude,...
            admin0_shapes(selection_admin0_shape_i).X,admin0_shapes(selection_admin0_shape_i).Y);
    else
        fprintf('restricting %i assets to admin1 %s (%s) (can take some time) ...\n',...
            length(VALUES_1D),admin1_shapes(selection_admin1_shape_i).name,...
            admin1_shapes(selection_admin1_shape_i).adm1_code);
        admin_hit=inpolygon(entity.assets.Longitude,entity.assets.Latitude,...
            admin1_shapes(selection_admin1_shape_i).X,admin1_shapes(selection_admin1_shape_i).Y);
    end
    if sum(admin_hit)>0
        entity.assets.Value(admin_hit)=VALUES_1D(admin_hit)';
    end
else
    entity.assets.Value=VALUES_1D';
end % restrict_Values_to_coutry
entity.assets.DamageFunID=entity.assets.Value*0+1;
entity.assets.reference_year=climada_global.present_reference_year;
if sum(scale_Value)>0
    entity.assets.Value = scale_Value(1) + scale_Value(2)*entity.assets.Value + scale_Value(3)*entity.assets.Value.^2;
    entity.assets.comment=sprintf('%s: y = %2.2f + %2.2f*x^1 + %2.2f*x^2',mfilename,scale_Value(1:3));
    if length(scale_Value)==4
        entity.assets.Value = entity.assets.Value/sum(entity.assets.Value)*scale_Value(4); % normalize, multiply
        entity.assets.comment=[entity.assets.comment sprintf(', normalized, then *%2.2f',scale_Value(4))];
    end
end

entity.assets.admin0_name=admin0_name;
entity.assets.admin0_ISO3=admin0_shapes(selection_admin0_shape_i).ADM0_A3;
entity.assets.admin1_name=admin1_name;
if ~isempty(selection_admin1_shape_i)
    entity.assets.admin0_code=admin1_shapes(selection_admin1_shape_i).adm1_code;
end

if select_admin0
    
    % find GDP data
    [fP,fN] = fileparts(GDP_data_file);
    GDP_save_file=[fP filesep fN '.mat'];
        
    % two options, GDP from GDP_entity or from the GDP file in country_risk
    if strfind(GDP_data_file,'GDP_entity') % the file in module GDP_entity
        if climada_check_matfile(GDP_data_file)
            load(GDP_save_file) % loads GDP_data
        else
            GDP=climada_GDP_read(GDP_data_file,1,1,1);
        end
        admin0_pos=strmatch(admin0_name,GDP.country_names); % locate admin0 GDP
        % one issue is that not all country names in GDP database and
        % shapes match.
        if ~isempty(admin0_pos)
            GDP_value=GDP.value(admin0_pos,end)*(1+GDP_AGR)^(max(0,climada_global.present_reference_year-GDP.year(end)));
        else
            GDP_value=1; % norm
        end
    else
        if climada_check_matfile(GDP_data_file,GDP_save_file)
            fprintf('GDP data from %s\n',GDP_save_file);
            load(GDP_save_file) % loads GDP_data
        else
            fprintf('GDP data from %s\n',GDP_data_file);
            GDP=climada_xlsread('no',GDP_data_file,'Data CLEAN',1);
            if sum(isnan(GDP.ISO3{1}))>0
                fprintf('WARNING: %s, GDP might not be correctly read from %s\n',mfilename,GDP_data_file);
                fprintf(' > make sure the Excel''s tab ''Data CLEAN'' does contain values for ISO3, not links\n');
            else
                save(GDP_save_file,'GDP'); % only save if it looks correct
            end
        end
        admin0_pos=strmatch(admin0_shapes(selection_admin0_shape_i).ADM0_A3,GDP.ISO3); % match via ISO3, safer
        % since we use the 3-digit country code, it always matches
        if ~isempty(admin0_pos)
            GDP_value=GDP.GDP(admin0_pos,end)*(1+GDP_AGR)^(max(0,climada_global.present_reference_year-GDP.Year(admin0_pos)));
        else
            GDP_value=1; % norm
        end
    end % GDP_entity
    
    entity.assets.GDP=GDP_value; % does not hurt to store it
    if GDP_value>1 && restrict_Values_to_coutry % valid GDP and only one country
        entity.assets.Value=entity.assets.Value/sum(entity.assets.Value)*...
            GDP_value*GDP2TIV_multiplier; % *6: GDP->TIV
        fprintf('sum of Values scaled to %g (%1.1f times GDP)\n',sum(entity.assets.Value),GDP2TIV_multiplier);
    elseif GDP_value==1
        fprintf('WARNING: no valid GDP found\n');
    elseif ~restrict_Values_to_coutry
        fprintf('GDP not applied, since assets not restricted to country\n');
    end
    
end % select_admin0

% for consistency, update Deductible and Cover
entity.assets.Deductible=entity.assets.Value*0;
entity.assets.Cover=entity.assets.Value;

if save_entity
    fprintf('saving entity as %s\n',entity_save_file);
    save(entity_save_file,'entity');
    fprintf('consider encoding entity to a particular hazard, see climada_assets_encode\n');
end

return % climada_nightlight_entity




function ok=fetch_mapserver_ngdc_noaa_gov_gcv4(bbox,img_filename)
% fetch a tile of the global night light high-res image

http_str='http://mapserver.ngdc.noaa.gov/cgi-bin/public/gcv4/F182010.v4c.avg_lights_x_pct.lzw.tif?request=GetCoverage&service=WCS&version=1.0.0&COVERAGE=F182010.v4c.avg_lights_x_pct.lzw.tif&crs=EPSG:4326&format=geotiff&resx=0.0083333333&resy=0.0083333333';
bbox_str=sprintf('&bbox=%i,%i,%i,%i',bbox);
bbox_file_pref=sprintf('%i_%i_%i_%i_',bbox);
www_filename=[http_str bbox_str];

fprintf('please enter the following URL in a browser:\n\n');
fprintf('%s\n\n',www_filename);
fprintf('please save the .tiff file as:\n\n');
fprintf('%s\n\n',img_filename);
ok=0;

% the following does not work, since urlread returns garbage for non-text
% [S,STATUS] = urlread(www_filename);
% if STATUS==1
%     fid=fopen(img_filename,'w');
%     fprintf(fid,'%s',S);
%     fclose(fid);
%     fprintf('%s (fetch_mapserver_ngdc_noaa_gov_gcv4) done\n',mfilename)
%     ok=1;
% else
%     fprintf('%s (fetch_mapserver_ngdc_noaa_gov_gcv4) FAILED\n',mfilename)
%     ok=0;
% end

return % fetch_mapserver_ngdc_noaa_gov_gcv4