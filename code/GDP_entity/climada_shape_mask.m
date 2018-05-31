function [in, idx]=climada_shape_mask(shape,precision,target_res,gpw_index,gpw_lon,gpw_lat,plot_flag)
% !!!BETA!!!
% MODULE:
%   country_risk
% NAME:
%   climada_inshape_new
% PURPOSE:
%   create a mask of all coordinates contained within a shape file. Returns
%   a vector sized according to the shapes bounding box and the chosen
%   resolution. The smallest possible bounding box is automatically
%   chosen.
%   Requires the functions gpw_index, gpw_lon, gpw_lat which are contained in
%   the files which contain the LitPopulation raw data. Supports enclaves
%   and is significantly faster compared to the functions inpolygon / inshape.
% CALLING SEQUENCE:
% EXAMPLE:
%   climada_shape_mask(shape,[],30,gpw_index,gpw_lon,gpw_lat,0)
% INPUTS:
%   shape: The shape which is to be evaluated
%   precision: edit the precision with which the border areas are
%       evaluated. The value set here is the number of pixels added to each
%       direction of the border. DEFAULT =3 (3 is recommended as offering great
%       precision at very reasonable speeds.
%   target_res: desired target resolution in arc-seconds
%   gpw_index: function which creates indizes from lat/lon values. is
%       loaded from the LitPopulation files. Note that it must be
%       compatible with the chosen target_res resolution, otherwise result will be
%       faulty.
%   gpw_lat/gpw_lon: The "inverse" function of gpw_index.
%   plot_flag: whether or not to plot the result. DEFAULT =1
% OUTPUTS:
%   in: Boolean value whether or not a pixel is located in (or on) the
%       shape.
%   idx: The indizes of the pixels located within the shape within the
%       global grid (0 being at 90 N and 180 E and than counting along the
%       columns)
% MODIFICATION HISTORY:
%  Dario Stocker, dario.stocker@gmail.com, 20180412, initial
%  Samuel Eberenz, eberenz@posteo.eu, 20180531, improved error handling
%
% Additional commment: 
% For conversion to python regarding poly2mask: see https://github.com/scikit-image/scikit-image/issues/1103
%-

in=[]; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
% and to set default values where appropriate
%if ~exist('lat','var'),return;end
%if ~exist('lon','var'),return;end
if ~exist('shape','var'),return;end
if ~exist('precision','var'),precision=3;end
if ~exist('target_res','var'),return;end
if ~exist('gpw_index','var'),return;end
if ~exist('plot_flag','var'),plot_flag=0;end
if ~exist('check_enclave','var'),check_enclave=1;end


if ~isscalar(precision),precision=3;end;




try

    lon_shape = [shape.X]';
    lat_shape = [shape.Y]';
    
    % extract all shapes
    subshapes=struct('lon',[],'lat',[]);
    if ~(isempty(isnan(lon_shape))) % only check one of them
        isnan_vector = isnan(lon_shape);
        number_shapes = sum(sum(isnan_vector));
        if number_shapes>1
            nan_indices = find(isnan(lon_shape));

            subshapes(1).lon = lon_shape(1:(nan_indices(1)-1)); % First entry added manually
            subshapes(1).lat = lat_shape(1:(nan_indices(1)-1)); 
            for i = 2:(numel(nan_indices))
                subshapes(i).lon = lon_shape((nan_indices(i-1)+1):(nan_indices(i)-1));
                subshapes(i).lat = lat_shape((nan_indices(i-1)+1):(nan_indices(i)-1));
            end
            clearvars i nan_indices;
            
        else    % only one shape. Just remove the trailing nans
            number_shapes = 1;
            subshapes(1).lon = lon_shape(find(~isnan(lon_shape)));
            subshapes(1).lat = lat_shape(find(~isnan(lat_shape)));
        end
    else        % No trailing Nan
        number_shapes = 1;
        subshapes(1).lon = (lon_shape);
        subshapes(1).lat = (lat_shape);
    end

    clearvars lon_shape lat_shape;
    
    % cleanup empty subshapes. Some countries (e.g. FRA) have multiple NaNs in a row
    i_del=1;
    for i = 1:number_shapes
        if isempty(subshapes(i_del).lon)
            subshapes(i_del) = [];
        else
            i_del=i_del+1;
        end
    end
    clearvars i i_del;
    number_shapes = length(subshapes);
    
    % for all shapes create a rough mask
    country_mask_idx = [];
    
    regular_shape = [];
    enclaves = []; % these need to be removed later
    for k = 1:number_shapes
        flip_lat = -(subshapes(k).lat - 90); % Mirror everything for usage with polymask
        min_lon = min(min(subshapes(k).lon));
        min_lat = min(min(flip_lat));
        max_lon = max(max(subshapes(k).lon));
        max_lat = max(max(flip_lat));

        % convert coordinates to "cartesian" with point of origin in NW corner
        % of geograhpical coordinate system and one step per pixel (for poly2mask)
        lon_shape_conv = ((subshapes(k).lon-min_lon)*(3600/target_res));
        lat_shape_conv = ((flip_lat-min_lat)*(3600/target_res));
        temp_bbox=gpw_index(min(min(subshapes(k).lat)),max(max(subshapes(k).lat)),min_lon,max_lon);

        % Create a first cut out of the country, a little rough around the
        % edges, but very quick
        temp_mask = poly2mask(lon_shape_conv,lat_shape_conv,size(temp_bbox,1),size(temp_bbox,2));
        temp_mask_idx=temp_bbox(find((double(temp_bbox).*temp_mask)~=0));
        
        country_mask_idx = [country_mask_idx; temp_mask_idx];
        %clearvars temp_mask;
        
        if k > 1 % Check for enclaves
            is_enclave = 0;
            
            for m = 1:(k-1)
                if (isscalar(subshapes(m).lon(1)))
                    [tmp_in, tmp_on] = inpolygon(subshapes(k).lon(1),subshapes(k).lat(1),subshapes(m).lon,subshapes(m).lat);
                    if tmp_in ==1 && tmp_on ==0
                        is_enclave = 1;
                                                
                    end
                    clearvars tmp_in tmp_on;
                end
                
                
            end
             
            if is_enclave == 1
                    enclaves = [enclaves; k];
                else
                   regular_shape = [regular_shape; k];
            end
            clearvars is_enclave;
        else
            regular_shape = [regular_shape; k];
        end
    end  

    
    clearvars k global_idx temp_country_idx country_mask min_lat min_lon max_lat max_lon;
    
    
    %%% Now define "border region"
    fprintf('Specific treatment for border regions...\n');

    % First we "extend" the coordinates from the shape file (we add coordinates
    % where the are lacking for some distance (at straight lines normally))
    
    
    % first do it for regular shapes
    i_added=1;
    
    for k = 1:numel(regular_shape)
        lon_shape = subshapes(regular_shape(k)).lon;
        lat_shape = subshapes(regular_shape(k)).lat;
        
        for i = 1:numel(lon_shape)
            if ~(isnan(lon_shape(i)) || isnan(lat_shape(i))) %skip if is nan
                if (i<numel(lon_shape)-1)
                    if (~(isnan(lat_shape(i+1)) || isnan(lat_shape(i+1)))) && (abs(lon_shape(i+1)-lon_shape(i))>(3*(1/(3600/target_res))) || abs(lat_shape(i+1)-lat_shape(i))>(3*(1/(3600/target_res))))  % Distance must be greater than a threshold of 3 "resolution steps"
                        curr_eucl_dist=sqrt((lat_shape(i+1)-lat_shape(i))^2+(lon_shape(i+1)-lon_shape(i))^2);
                        no_of_extra_points=ceil(curr_eucl_dist/(1/120)); % ceil because also the "current" coordinate is added
                        lon_steigung = (lon_shape(i+1)-lon_shape(i))/(no_of_extra_points-1);
                        lat_steigung = (lat_shape(i+1)-lat_shape(i))/(no_of_extra_points-1);
                        coords_extended_lon(i_added) = lon_shape(i);
                        coords_extended_lat(i_added) = lat_shape(i);
                        for j=1:(no_of_extra_points-1) %start at 2 because first was for "current" coord
                            coords_extended_lon(i_added+j) = lon_shape(i)+lon_steigung*j;
                            coords_extended_lat(i_added+j) = lat_shape(i)+lat_steigung*j;
                        end
                        i_added=i_added+no_of_extra_points;
                    else
                        coords_extended_lon(i_added) = lon_shape(i);
                        coords_extended_lat(i_added) = lat_shape(i);
                        i_added=i_added+1;
                    end
                else   % special treatment for the last point: compare to the first point
                    if (~(isnan(lat_shape(1)) || isnan(lat_shape(1)))) && (abs(lon_shape(1)-lon_shape(i))>(3*(1/(3600/target_res))) || abs(lat_shape(1)-lat_shape(i))>(3*(1/(3600/target_res))))  % Distance must be greater than a threshold of 3 "resolution steps"
                        curr_eucl_dist=sqrt((lat_shape(1)-lat_shape(i))^2+(lon_shape(1)-lon_shape(i))^2);
                        no_of_extra_points=ceil(curr_eucl_dist/(1/120)); % ceil because also the "current" coordinate is added
                        lon_steigung = (lon_shape(1)-lon_shape(i))/(no_of_extra_points-1);
                        lat_steigung = (lat_shape(1)-lat_shape(i))/(no_of_extra_points-1);
                        coords_extended_lon(i_added) = lon_shape(i);
                        coords_extended_lat(i_added) = lat_shape(i);
                        for j=1:(no_of_extra_points-1) %start at 2 because first was for "current" coord
                            coords_extended_lon(i_added+j) = lon_shape(i)+lon_steigung*j;
                            coords_extended_lat(i_added+j) = lat_shape(i)+lat_steigung*j;
                        end
                        i_added=i_added+no_of_extra_points;
                    else
                        coords_extended_lon(i_added) = lon_shape(i);
                        coords_extended_lat(i_added) = lat_shape(i);
                        i_added=i_added+1;
                    end
                end
            else
                fprintf('.');
            end
        end
    end
    
    clearvars i j i_added lon_steigung lat_steigung no_of_extra_points curr_eucl_dist;
    clearvars lon_shape_conv lat_shape_conv;

    lon_extended_conv=((coords_extended_lon+180)*(3600/target_res));
    lat_extended_conv=(-(coords_extended_lat-90)*(3600/target_res));

    clearvars coords_extended_* lon_shape lat_shape;



    % Pixels to be searched by "inpolygon", pixels along the border
    %precision = 3;  % precision can be adjusted here, higher number means higher precision and longer CPU time
    precision_pixels = precision*2+1;
    precision_pixels_sq = (((precision*2)+1)^2);
    border_region_idx_all=zeros(numel(lon_extended_conv)*(precision_pixels_sq),1);

    for i = 1:numel(lon_extended_conv)
    
        temp_idx=floor(lon_extended_conv(i))*((3600/target_res)*180)+ceil(lat_extended_conv(i));  % the id of the center pixel
        
        for j=1:((precision*2)+1)
            border_region_idx_all(((i-1)*precision_pixels_sq+(j-1)*precision_pixels+1):((i-1)*precision_pixels_sq+(j-1)*precision_pixels+precision_pixels)) = max((temp_idx-(((3600/target_res)*180)*precision)+(((3600/target_res)*180)*(j-1))-(precision)):(temp_idx-(((3600/target_res)*180)*precision)+(((3600/target_res)*180)*(j-1))+(precision)),0);
                
            % explicit function for 5x5 square
%             border_region_idx(((i-1)*25+1):((i-1)*25+5)) = (temp_idx-2):(temp_idx+2);
%             border_region_idx(((i-1)*25+6):((i-1)*25+10)) = (temp_idx-(21600)-2):(temp_idx-(21600)+2);
%             border_region_idx(((i-1)*25+11):((i-1)*25+15)) = (temp_idx+(21600)-2):(temp_idx+(21600)+2);
%             border_region_idx(((i-1)*25+16):((i-1)*25+20)) = (temp_idx-(21600)*2-2):(temp_idx-(21600)*2+2);
%             border_region_idx(((i-1)*25+21):((i-1)*25+25)) = (temp_idx+(21600)*2-2):(temp_idx+(21600)*2+2);
        end
        
    end
    
    border_region_idx = unique(border_region_idx_all(find(border_region_idx_all~=0)),'stable');

    clearvars lat_extended_conv lon_extended_conv border_region_idx_all;

    border_region_lon=gpw_lon(border_region_idx);
    border_region_lat=gpw_lat(border_region_idx);
    
    % use climada_inshape for the border region only
    border_region_in=climada_inshape(border_region_lat,border_region_lon,shape);
    
    
    % extract border coordinates which were determined to be inside and
    % outside the shape
    border_region_idx_in_zeros=(border_region_idx.*border_region_in);
    border_region_idx_in=border_region_idx_in_zeros(find(border_region_idx_in_zeros~=0));
    clearvars border_region_idx_in_zeros;
    border_region_idx_out_zeros=((~border_region_in).*border_region_idx);
    border_region_idx_out=border_region_idx_out_zeros(find(border_region_idx_out_zeros~=0));
    clearvars border_region_idx_out_zeros;
    %border_region_out=~border_region_in;
    clearvars border_region_idx border_region_in border_region_out;
    
    
    
    
if ~check_enclave==0    
    in_enclave_idx = [];
    if numel(enclaves)>0   % Now do it separately for every single enclave
       country_mask_idx_enclave = [];
 

        for k = 1:numel(enclaves)

            flip_lat_enclave = -(subshapes(enclaves(k)).lat - 90); % Mirror everything for usage with polymask
            min_lon_enclave = min(min(subshapes(enclaves(k)).lon));
            min_lat_enclave = min(min(flip_lat_enclave));
            max_lon_enclave = max(max(subshapes(enclaves(k)).lon));
            %max_lat = max(max(flip_lat));

            % convert coordinates to "cartesian" with point of origin in NW corner
            % of geograhpical coordinate system and one step per pixel (for poly2mask)
            lon_shape_conv_enclave = ((subshapes(enclaves(k)).lon-min_lon_enclave)*(3600/target_res));
            lat_shape_conv_enclave = ((flip_lat_enclave-min_lat_enclave)*(3600/target_res));
            temp_bbox_enclave=gpw_index(min(min(subshapes(enclaves(k)).lat)),max(max(subshapes(enclaves(k)).lat)),min_lon_enclave,max_lon_enclave);

            % Create a first cut out of the country, a little rough around the
            % edges, but very quick
            temp_mask_enclave = poly2mask(lon_shape_conv_enclave,lat_shape_conv_enclave,size(temp_bbox_enclave,1),size(temp_bbox_enclave,2));
            temp_mask_idx_enclave=(double(temp_bbox_enclave).*temp_mask_enclave);
            country_mask_idx_enclave=temp_mask_idx_enclave(find(temp_mask_idx_enclave~=0));
           % country_mask_idx_enclave = [country_mask_idx_enclave; temp_mask_idx_enclave];
            %clearvars temp_mask;





        clearvars global_idx temp_country_idx country_mask min_lat min_lon max_lat max_lon;    





        % Now also precise treatment for the border of the enclave

            lon_enclave = subshapes(enclaves(k)).lon;
            lat_enclave = subshapes(enclaves(k)).lat;

            i_added_enclave = 1;

            for i = 1:numel(lon_enclave)
                if ~(isnan(lon_enclave(i)) || isnan(lat_enclave(i))) %skip if is nan
                    if (i<numel(lon_enclave)-1)
                        if (~(isnan(lat_enclave(i+1)) || isnan(lat_enclave(i+1)))) && (abs(lon_enclave(i+1)-lon_enclave(i))>(3*(1/(3600/target_res))) || abs(lat_enclave(i+1)-lat_enclave(i))>(3*(1/(3600/target_res))))  % Distance must be greater than a threshold of 3 "resolution steps"
                            curr_eucl_dist=sqrt((lat_enclave(i+1)-lat_enclave(i))^2+(lon_enclave(i+1)-lon_enclave(i))^2);
                            no_of_extra_points=ceil(curr_eucl_dist/(1/120)); % ceil because also the "current" coordinate is added
                            lon_steigung = (lon_enclave(i+1)-lon_enclave(i))/(no_of_extra_points-1);
                            lat_steigung = (lat_enclave(i+1)-lat_enclave(i))/(no_of_extra_points-1);
                            coords_extended_lon_enclave(i_added_enclave) = lon_enclave(i);
                            coords_extended_lat_enclave(i_added_enclave) = lat_enclave(i);
                            for j=1:(no_of_extra_points-1) %start at 2 because first was for "current" coord
                                coords_extended_lon_enclave(i_added_enclave+j) = lon_enclave(i)+lon_steigung*j;
                                coords_extended_lat_enclave(i_added_enclave+j) = lat_enclave(i)+lat_steigung*j;
                            end
                            i_added_enclave=i_added_enclave+no_of_extra_points;
                        else
                            coords_extended_lon_enclave(i_added_enclave) = lon_enclave(i);
                            coords_extended_lat_enclave(i_added_enclave) = lat_enclave(i);
                            i_added_enclave=i_added_enclave+1;
                        end
                    else   % special treatment for the last point: compare to the first point
                        if (~(isnan(lat_enclave(1)) || isnan(lat_enclave(1)))) && (abs(lon_enclave(1)-lon_enclave(i))>(3*(1/(3600/target_res))) || abs(lat_enclave(1)-lat_enclave(i))>(3*(1/(3600/target_res))))  % Distance must be greater than a threshold of 3 "resolution steps"
                            curr_eucl_dist=sqrt((lat_enclave(1)-lat_enclave(i))^2+(lon_enclave(1)-lon_enclave(i))^2);
                            no_of_extra_points=ceil(curr_eucl_dist/(1/120)); % ceil because also the "current" coordinate is added
                            lon_steigung = (lon_enclave(1)-lon_enclave(i))/(no_of_extra_points-1);
                            lat_steigung = (lat_enclave(1)-lat_enclave(i))/(no_of_extra_points-1);
                            coords_extended_lon_enclave(i_added_enclave) = lon_enclave(i);
                            coords_extended_lat_enclave(i_added_enclave) = lat_enclave(i);
                            for j=1:(no_of_extra_points-1) %start at 2 because first was for "current" coord
                                coords_extended_lon_enclave(i_added_enclave+j) = lon_enclave(i)+lon_steigung*j;
                                coords_extended_lat_enclave(i_added_enclave+j) = lat_enclave(i)+lat_steigung*j;
                            end
                            i_added_enclave=i_added_enclave+no_of_extra_points;
                        else
                            coords_extended_lon_enclave(i_added_enclave) = lon_enclave(i);
                            coords_extended_lat_enclave(i_added_enclave) = lat_enclave(i);
                            i_added_enclave=i_added_enclave+1;
                        end
                    end
                else
                    fprintf('.');
                end

            end


              % Determine the pixels that are _in_ the enclave and have to be
                % removed from the previous shape so not to be double counted.
                clearvars i j i_added_enclave lon_steigung lat_steigung no_of_extra_points curr_eucl_dist;

                lon_extended_conv_enclave=((coords_extended_lon_enclave+180)*(3600/target_res));
                lat_extended_conv_enclave=(-(coords_extended_lat_enclave-90)*(3600/target_res));

                clearvars coords_extended_* lon_enclave lat_enclave;


                %Pixels to be searched by "inpolygon", pixels along the border
                precision_pixels = precision*2+1;
                precision_pixels_sq = (((precision*2)+1)^2);
                border_region_idx_enclave=zeros(numel(lon_extended_conv_enclave)*(precision_pixels_sq),1);

                for i = 1:numel(lon_extended_conv_enclave)

                    temp_idx_enclave=floor(lon_extended_conv_enclave(i))*((3600/target_res)*180)+ceil(lat_extended_conv_enclave(i));  % the id of the center pixel

                    for j=1:((precision*2)+1)
                        border_region_idx_enclave(((i-1)*precision_pixels_sq+(j-1)*precision_pixels+1):((i-1)*precision_pixels_sq+(j-1)*precision_pixels+precision_pixels)) = max((temp_idx_enclave-(((3600/target_res)*180)*precision)+(((3600/target_res)*180)*(j-1))-(precision)):(temp_idx_enclave-(((3600/target_res)*180)*precision)+(((3600/target_res)*180)*(j-1))+(precision)),0);
                    end

                end

            border_region_idx_in_enclave = unique(border_region_idx_enclave(find(border_region_idx_enclave~=0)),'stable');

            clearvars lat_extended_conv_enclave lon_extended_conv_enclave border_region_idx_enclave temp_idx;

            border_region_lon_enclave=gpw_lon(border_region_idx_in_enclave);
            border_region_lat_enclave=gpw_lat(border_region_idx_in_enclave);

            %figure; plotclr(border_region_lon,border_region_lat,border_region_lon);

            % use climada_inshape for the border region only
            border_region_enclave_tmp=inpolygon(border_region_lon_enclave,border_region_lat_enclave,subshapes(enclaves(k)).lon,subshapes(enclaves(k)).lat);
            in_enclave_border = (double(border_region_idx_in_enclave).*border_region_enclave_tmp);
            in_enclave = union(country_mask_idx_enclave,in_enclave_border);
            not_in_enclave = (double(border_region_idx_in_enclave).*~border_region_enclave_tmp);
            in_enclave_rm = setdiff(in_enclave,not_in_enclave);
            in_enclave_add = in_enclave_rm(find(in_enclave_rm~=0));

            in_enclave_idx = [in_enclave_idx; in_enclave_add];

            clearvars border_region_enclave_temp in_enclave not_in_enclave_in_enclave_rm in_enclave_add border_region_lon_enclave border_region_lat_enclave border_region_idx_in_enclave  border_region_idx_enclave temp_idx_enclave


        end
    end
end % enclave special treatment
    
    
    
    


    % now add and remove coordinates to "original" set
    in_both=union(country_mask_idx, border_region_idx_in);
    in_notout=setdiff(in_both, border_region_idx_out);
    if ~check_enclave==0
        idx=setdiff(in_notout,in_enclave_idx);
        idx=idx(find(idx~=0));
    else
        idx=in_notout(find(in_notout~=0));
    end
    in=reshape(ismember(temp_bbox,idx),[numel(temp_bbox) 1]);
    
    clearvars in_both in_notout border_region_* country_mask_idx temp_bbox;
    
    %country_LitPopulation=LitPopulation(country_ind);
    try
        toc;
    end
catch ME
    %lasterr
    display(ME.identifier)
    display(ME.message)
    disp(ME.stack(end).line)
    error('Error while trying to extract coordinates. Operation aborted.');
end

if plot_flag~=0
    % all red color set
    red_c=[zeros(125,1); linspace(0,0,125)'];
    green_c=[linspace(0,0,125)'; linspace(0,0,125)'];
    blue_c=[linspace(255/255,255/255,125)'; ones(125,1)];
    blue_only=[red_c green_c blue_c];
    figure; plotclr(gpw_lon(idx),gpw_lat(idx),double(idx),[],[],[],[],[],blue_only);
    climada_shapeplotter(shape);
    clearvars red_c green_c blue_c blue_only;
end        


end % climada_inshape

