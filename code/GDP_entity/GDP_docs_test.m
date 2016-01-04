% batch TEST code, see code
%-

country_name     = 'Mexico';
load('\\CHRB1065.CORP.GWPNET.COM\homes\X\S3BXXW\Documents\lea\climada_test_environment\climada_additional\GDP_entity\data\border_mask_10km.mat')


%% values
[values_distributed, pp] = climada_night_light_to_country(country_name, '', '', '', border_mask, 1, 0, 0, 0);
[values_distributed, X, Y, resolution_km] = climada_resolution_downscale (values_distributed, 10);


%% centroids
c_idx            = strcmp(border_mask.name, country_name);
% 80 km buffer, no hollowout
matrix_nohollowout = climada_mask_buffer_hollow(border_mask.mask{c_idx}, 8,0);
% 80 km buffer, 150 km coastal area
matrix_hollowout = climada_mask_buffer_hollow(border_mask.mask{c_idx}, 8,15);                               
fig              = climada_plot_centroids(centroids, country_name, 1);                                      
                       



%% entity_base                                    
entity_base = climada_entity_assets_add(values_distributed, centroids, country_name, matrix_hollowout,  X, Y);      
fig         = climada_plot_entity_assets(entity_base, centroids, country_name, 0);



%% coastal, 80 km buffer, 150 km coastal area
matrix_hollowout       = climada_mask_buffer_hollow(border_mask.mask{c_idx}, 8,15); 
centroids_coastal      = climada_matrix2centroid(matrix_hollowout  , border_mask.lon_range, border_mask.lat_range, ...
                                                 country_name);  
fig                    = climada_plot_centroids(centroids_coastal, country_name, 1);   
entity_100_costal      = climada_entity_assets_add(values_distributed, centroids_coastal    , country_name, matrix_hollowout  ,  X, Y); 
fig                    = climada_plot_entity_assets(entity_100_coastal, centroids_coastal, country_name, 1);
entity_coastal         = climada_entity_GDP(entity_100_coastal, '', 2014, centroids_coastal, borders, 1, 1);


%% no hollowout, 80 km buffer
matrix_nohollowout     = climada_mask_buffer_hollow(border_mask.mask{c_idx}, 8,0);
centroids_nohollowout  = climada_matrix2centroid(matrix_nohollowout, border_mask.lon_range, border_mask.lat_range, ...
                                                 country_name);      
fig                    = climada_plot_centroids(centroids_nohollowout, country_name, 1);
entity_100_nohollowout = climada_entity_assets_add(values_distributed, centroids_nohollowout, country_name, matrix_nohollowout,  X, Y);    
fig                    = climada_plot_entity_assets(entity_100_nohollowout, centroids_nohollowout, country_name, 1);
entity_nohollowout     = climada_entity_GDP(entity_100_nohollowout, '', 2014, centroids_nohollowout, borders, 1, 1);



country_name_str    = country_name;
pp_str_             = '';
asset_resolution_km = 10;
hollow_name         = '';
borders             = '';

climada_entity_save_xls(entity_100, 'text.xls');

% [status, message] = xlwrite(filename,A,sheet, range)


entity      = climada_entity_GDP(entity_100_coastal, '', 2014, centroids, borders, 1, 0);
entity_2050 = climada_entity_GDP(entity_100_coastal, '', 2050, centroids, borders, 1, 0);


polygon = [];
[centroids_cut, entity_cut, polygon_used] = climada_cut_out_GDP_entity(entity_nohollowout, centroids_nohollowout, polygon);


%% all in all
climada_create_GDP_entity('Mexico', 1);





