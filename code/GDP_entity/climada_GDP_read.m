function GDP = climada_GDP_read(xlsfilename, special_cases_on, check_names, silent_mode)
% read GDP data from worldbank (1960 - 2010, in USD)
% http://data.worldbank.org/indicator/NY.GDP.MKTP.CD/countries
% read GDP data and forecast from IMF (2000 - 2017, in national currency)
% http://www.imf.org/external/ns/cs.aspx?id=28
% NAME:
%   climada_GDP_read
% PURPOSE:
%   read GDP data excel-file to mat-file
%   previous: diverse
%   next: climada_night_light_read
% CALLING SEQUENCE:
%   GDP = climada_GDP_read(xlsfilename, special_cases_on, check_names,
%   save_on)
% EXAMPLE:
%   GDP = climada_GDP_read(xlsfilename)
% INPUTS:
% OPTIONAL INPUT PARAMETERS:
%   xlsfilename     :  the filename (location) of the GDP data
%                      (default World_GDP_1960_2010.xls)
%   special_cases_on:  set to 1 for summing up GDP of e.g. Sudan and South
%                      Sudan, not applicable for GDP per capita (set to 0)
%   check_names     :  if set to 1, check GDP names with borders.name
%                      (climada world map)
%   save_on         :  if set to 1, GDP-mat file to be saved
%   silent_mode     :  if set to 1, no print out messages
% OUTPUTS:
%   GDP: a struct, with following fields
%         .country_names: sorted countrynames (207 countries)
%         .year         : vector of all the years that GDP is available for
%         .value        : GDP value in USD per country
%         .comment      : information about GDP data
%         .description  : use for plot as colorbarlabel
%         .country_borders_index: index to relate to climada worldmap
%                                  borders.name

% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20120730
% david.bresch@gmail.com, 20170725, iso code read (and added to file ;-)
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables
if ~exist('xlsfilename'     , 'var'), xlsfilename      = []; end
if ~exist('special_cases_on', 'var'), special_cases_on = []; end
if ~exist('check_names'     , 'var'), check_names      = 1 ; end
if ~exist('silent_mode'     , 'var'), silent_mode      = 0 ; end

% set modul data directory
modul_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];


% prompt for file if not given
if isempty(xlsfilename) % local GUI
    xlsfilename          = [modul_data_dir filesep '*.xls'];
    [filename, pathname] = uigetfile({'*.xlsx';'*.xls'}, 'Select GDP file:',xlsfilename);
    if isequal(filename,0) || isequal(pathname,0)
        GDP = [];
        return; % cancel
    else
        xlsfilename = fullfile(pathname,filename);
    end
end


% new, using the standard climada reading routine
xls_data          = climada_xlsread('no',xlsfilename,'',silent_mode);
GDP.iso           = xls_data.iso; % 20170725
GDP.country_names = xls_data.countryname;
xls_fieldnames    = fieldnames(xls_data);
next_year         = 1;
for field_i = 1:length(xls_fieldnames);
    xls_fieldname = xls_fieldnames{field_i};
    if strfind(xls_fieldname,'year')
        GDP.year(next_year)    = str2num(xls_fieldname(5:end));
        GDP.value(:,next_year) = xls_data.(xls_fieldname); % GDP.value(c_index,year_index))
        next_year              = next_year+1;
    end
end % field_i
GDP.description  = 'GDP in USD'; % hard-wired, since always in USD
special_cases_on = 0; % no treatment of special cases

GDP.comment      = sprintf('Worldbank/IMF GDP data, from year %d to %d',min(GDP.year), max(GDP.year));
empty            = find(strcmp(GDP.country_names, ''));
if ~isempty(empty)
    GDP.country_names(empty)  = [];
    GDP.value(empty(1):end,:) = [];
end


if ~silent_mode
    fprintf('***\n');
    fprintf('%s\n',GDP.description);
    fprintf('%s\n',GDP.comment);
end

if special_cases_on
    if ~silent_mode
        fprintf('Special cases \n\t\t - Serbia, Montenegro, Kosovo \n\t\t - Sudan, South Sudan \n\t\t - China, Macao \n\t\t - France, Monaco\n\t\t - Netherlands, Sint Maarten \n\t\t - UK, Gibraltar, Channels Islands, Isle of Man \n ')
    end
    
    %% special cases
    %Montenegro and Kosovo added up to Serbia
    GDP_index  = strcmp('Serbia'    , GDP.country_names);
    GDP_index2 = strcmp('Montenegro', GDP.country_names);
    GDP_index3 = strcmp('Kosovo'    , GDP.country_names);
    GDP.value(GDP_index,:)                           = nansum([GDP.value(GDP_index ,:);
        GDP.value(GDP_index2,:);
        GDP.value(GDP_index3,:)] );
    GDP.value(find([GDP_index2+GDP_index3]),:)       = [];
    GDP.country_names(find([GDP_index2+GDP_index3])) = [];
    
    %South Sudan
    GDP_index  = strcmp('Sudan'      , GDP.country_names);
    GDP_index2 = strcmp('South Sudan', GDP.country_names);
    GDP.value(GDP_index,:)        = nansum([GDP.value(GDP_index ,:);
        GDP.value(GDP_index2,:)] );
    GDP.value(GDP_index2,:)       = [];
    GDP.country_names(GDP_index2) = [];
    
    %Macao SAR, China
    GDP_index   = strcmp('China'           , GDP.country_names);
    GDP_index2  = strcmp('Macao SAR, China', GDP.country_names);
    GDP.value(GDP_index,:)        = nansum([GDP.value(GDP_index ,:);
        GDP.value(GDP_index2,:)] );
    GDP.value(GDP_index2,:)       = [];
    GDP.country_names(GDP_index2) = [];
    
    %Monaco
    GDP_index   = strcmp('France', GDP.country_names);
    GDP_index2  = strcmp('Monaco', GDP.country_names);
    GDP.value(GDP_index,:)        = nansum([GDP.value(GDP_index ,:);
        GDP.value(GDP_index2,:)] );
    GDP.value(GDP_index2,:)       = [];
    GDP.country_names(GDP_index2) = [];
    
    %Netherlands Antilles
    GDP_index   = strcmp('Netherlands Antilles'     , GDP.country_names);
    GDP_index2  = strcmp('Sint Maarten (Dutch part)', GDP.country_names);
    GDP.value(GDP_index,:)        = nansum([GDP.value(GDP_index ,:);
        GDP.value(GDP_index2,:)] );
    GDP.value(GDP_index2,:)       = [];
    GDP.country_names(GDP_index2) = [];
    
    %Gibraltar
    GDP_index   = strcmp('United Kingdom' , GDP.country_names);
    GDP_index2  = strcmp('Gibraltar'      , GDP.country_names);
    GDP_index3  = strcmp('Channel Islands', GDP.country_names);
    GDP_index4  = strcmp('Isle of Man'    , GDP.country_names);
    GDP.value(GDP_index,:)  = nansum([GDP.value(GDP_index ,:);
        GDP.value(GDP_index2,:);
        GDP.value(GDP_index3,:);
        GDP.value(GDP_index4,:)] );
    GDP.value(find([GDP_index2 + GDP_index3 + GDP_index4]),:)        = [];
    GDP.country_names(find([GDP_index2 + GDP_index3 + +GDP_index4])) = [];
end

if ~silent_mode
    fprintf('read successfully and loaded into workspace\n')
    fprintf('GDP available for %d countries\n', length(GDP.country_names))
    fprintf('***\n\n')
end

if check_names
    if ~silent_mode
        fprintf('***\n')
        fprintf('Check country names...\n')
    end
    GDP = climada_GDP_check_countrynames(GDP,[],silent_mode);
end


% climada_plot_world_borders(1, 'Serbia')
% climada_plot_world_borders(1, 'United Kingdom')
% climada_plot_world_borders(1, 'France')
% climada_plot_world_borders(1, 'Netherlands')
% climada_plot_world_borders(1, 'Netherlands Antilles')
% climada_plot_world_borders(1, 'Guadeloupe')
% climada_plot_world_borders(1, 'Martinique')

end % climada_GDP_read


function res=nansum(values)
% local implementation of nansum, since not exsiting in new MATLAB any more
res=sum(values(not(isnan(values)))); % nansum(values)
end



