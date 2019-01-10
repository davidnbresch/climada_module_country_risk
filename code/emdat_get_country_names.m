function [iso3_emdat,iso3_climada,changes_list]=emdat_get_country_names(country_ISO3,peril_ID,years_range,verbose_mode,emdat_file)
% climada country_risk get all countries that fall under that country in EM-DAT
% MODULE:
%   country_risk
% NAME:
%   emdat_get_country_names
% PURPOSE:
%   Identify all countries that either belonged or now belong to the
%   input country, in order to avoid missing damage data from EM-DAT.
%   Also identifies if the ISO3 country names from climada_country_name and
%   in EM-DAT differ. Note that entries have been typed in manually and
%   hence the code might not be complete (currently includes countries
%   related to USSR, Ex-Yugoslavia, Germany, Czechoslovakia, Sudan, Yemen,
%   and Palestine.
%
%   next call: emdat_read
% CALLING SEQUENCE:
%   [iso3_emdat,iso3_climada,changes_list]=emdat_get_country_names(country_ISO3, peril_ID, years_range)
% EXAMPLE:
%   iso3_emdat=emdat_get_country_names('SCG',['FL';'F1';'F2']);
% INPUTS:
%   country_ISO3: country name (ISO3); does not need to be recognized by
%   climada
% OPTIONAL INPUT PARAMETERS:
%   peril_ID: peril considered to check if the issue is relevant in EM-DAT.
%       If not given, all perils are included. See documentation of
%       emdat_read for the list of perils.
%   years_range: a vector such as [year_min year_max] to know which years
%       should be included (beta only; please check carefully for your own
%       purpose).
%   verbose_mode: if =1 (default), print status and potential issues.
%       0=silent.
%   emdat_file: filename of the emdat database, see emdat_read (default='')
% OUTPUTS:
%   iso3_emdat,iso3_climada: cell arrays contaning a list of all countries
%   (according to emdat and to climada_country_name, respectively) that belonged 
%       to the country given as an input at any time (e.g., for Serbia and
%       Montenegro SCG, since 2006 it is formed of two countries, SRB and
%       MNE). Empty if this is not possible (i.e., changes_list==99).
%   changes_list: indicates which changes occurred as follows:
%       0 = no change was detected (country remained stable). The ISO3
%           names in EM-DAT and climada_country_name might differ.
%       1 = the country was or is split into several countries, or the
%           country is listed under various abbreviations in EM-DAT, hence 
%           the names of all countries (past or present) composing that
%           country (and with non-zero damage recorded over the time period
%           defined by years_range) is returned in iso3_emdat (iso3_climada
%           is as country_ISO3).
%       2 = the country was or is part of a larger country, but emdat does
%           not contain any non-zero damage data for the corresponding
%           peril_ID and time period in that larger country. This is fine.
%       99 = the country was or is part of a larger country AND emdat
%            contains damage data for the corresponding peril_ID and time
%            period in that larger country. In this case it is suggested to
%            either consider that larger country instead of its
%            sub-countries, or to choose a time period to avoid this issue.
%       -1 = the country was not found in both EM-DAT and
%            climada_country_name. iso3_all will return country_ISO3.
%       -2 = the country exists in climada but not in EM-DAT, likely simply
%            no damage data for that country.
%       -3 = the country exists in EM-DAT but not in climada. Needs
%            checking.
% MODIFICATION HISTORY:
% Benoit P. Guillod, benoit.guillod@env.ethz.ch, 20190104, initial
% Benoit P. Guillod, benoit.guillod@env.ethz.ch, 20190110, fix in the indentification of existing country in emdat and for country SCG
%-

global climada_global

if ~exist('country_ISO3','var'),error('input argument country_ISO3 is missing');end
if ~exist('peril_ID','var'),peril_ID='';end
if ~exist('years_range','var'),years_range=[1800 2300];end
if ~exist('verbose_mode','var'),verbose_mode=1;end
if ~exist('emdat_file','var'),emdat_file='';end

% init output
iso3_emdat = {};
iso3_climada = {};
changes_list = -1;

% % if multiple countries provided as input, assume they are part of a region
% % and their damages will be summed up.
% if (iscell(country_ISO3) && length(country_ISO3)>1)
%     ratio_emdat = zeros([length(country_ISO3 1]);
%     for i=1:length(country_ISO3)
%         [iso3_emdat_i,iso3_climada_i,changes_list_i]=emdat_get_country_names(country_ISO3{i}, peril_ID, years_range, verbose_mode,emdat_file)
%         
%     end
% end

if isfield(climada_global,'emdat_file')
    emdat_file_global = climada_global.emdat_file;
else
    emdat_file_global = [];
end
climada_global.emdat_file = emdat_file;

% check if the country is found in climada or EM-DAT
country_climada =  climada_country_name(country_ISO3);
if isempty(country_climada)
    % check if any data for that country in EM-DAT
    emdat_i=emdat_read(climada_global.emdat_file,country_ISO3);
    if isempty(emdat_i)
        if verbose_mode,fprintf('Country %s not found in climada_country_name or emdat_read\n',country_ISO3);end
        % reset climada_global if changed
        if ~isempty(emdat_file_global)
            climada_global.emdat_file=emdat_file_global;
        else
            climada_global = rmfield(climada_global,'emdat_file');
        end
        return
    end
end

% manual attribution of countries
switch country_ISO3
    case 'IND'
        % India - is also as 'Ind' in EM-DAT
        if any_em_data('Ind',peril_ID,years_range)
            iso3_emdat = {'IND','Ind'};
            changes_list = 1;
        else
            iso3_emdat = {'IND'};
        end
    case 'ANT'
        % TO DO
        fprintf('** warning in emdat_get_country_names: country ANT not found in climada but is in EM-DAT **')
        iso3_emdat = {'BES','CUW','SXM'};
        iso3_climada = {};
    case 'SCG'
        % Serbia and Montenegro: 1 country until 2006
        sub_countries_ISO3 = {'SCG','SRB','MNE'};
        iso3_climada = {'SRB','MNE'};
        [iso3_emdat_a,changes_list_a]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range);
        [iso3_emdat_b,changes_list_b] = check_larger_country(country_ISO3,'YUG',peril_ID,years_range);
        iso3_emdat = union(iso3_emdat_a,iso3_emdat_b);
        changes_list = max(changes_list_a,changes_list_b);
    case {'MNE','SRB'}
        [iso3_emdat_a,changes_list_a] = check_larger_country(country_ISO3,'SCG',peril_ID,years_range);
        iso3_climada = {country_ISO3};
        [iso3_emdat_b,changes_list_b] = check_larger_country(country_ISO3,'YUG',peril_ID,years_range);
        iso3_emdat = union(iso3_emdat_a,iso3_emdat_b);
        changes_list = max(changes_list_a,changes_list_b);
    case {'PSE','PSX'}
        % Palestine: somehow different ISO3 codes
        iso3_emdat = {'PSE'};
        iso3_climada = {'PSX'};
        changes_list = 1;
    case 'CSK'
        % Czechoslovakia
        sub_countries_ISO3 = {'CSK','SVK','CZE'};
        [iso3_emdat,changes_list]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range);
        iso3_climada = {'SVK','CZE'};
    case {'SVK','CZE'}
        % Slovakia or Czech Republic
        [iso3_emdat,changes_list] = check_larger_country(country_ISO3,'CSK',peril_ID,years_range);
        iso3_climada = {country_ISO3};
    case 'DEU'
        % Germany (do not forget it used to be split in two countries)
        sub_countries_ISO3 = {'DEU','DDR','DFR'};
        [iso3_emdat,changes_list]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range);
        iso3_climada = {'DEU'};
    case {'DDR','DFR'}
        % Eastern/Western Germany
        [iso3_emdat,changes_list] = check_larger_country(country_ISO3,'DEU',peril_ID,years_range);
        iso3_climada = {country_ISO3};
    case 'SDN'
        % Sudan (now Sudan and South Sudan)
        sub_countries_ISO3 = {'SDN','SSD'};
        [iso3_emdat,changes_list]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range);
        iso3_climada = {'SDN'};
    case 'SUN'
        % USSR
        sub_countries_ISO3 = {'SUN','RUS','UKR','BLR','ARM','AZE','EST','GEO','KAZ','KGZ','LVA','LTU','MDA','TJK','TKM','UZB'};
        [iso3_emdat,changes_list]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range);
        iso3_climada = {};
    case {'RUS','UKR','BLR','ARM','AZE','EST','GEO','KAZ','KGZ','LVA','LTU','MDA','TJK','TKM','UZB'}
        % Ex-USSR countries
        [iso3_emdat,changes_list] = check_larger_country(country_ISO3,'SUN',peril_ID,years_range);
        iso3_climada = {country_ISO3};
    case 'YEM'
        % Yemen
        sub_countries_ISO3 = {'YEM','YMD','YMN'};
        [iso3_emdat,changes_list]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range);
        iso3_climada = {'YEM'};
    case {'YMD','YMN'}
        [iso3_emdat,changes_list] = check_larger_country(country_ISO3,'YEM',peril_ID,years_range);
        iso3_climada = {country_ISO3};
    case 'YUG'
        % Yugoslavia
        sub_countries_ISO3 = {'YUG','HRV','SVN','MKD','BIH','SCG','SRB','MNE'};
        [iso3_emdat,changes_list]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range);
        iso3_climada = {};
    case {'HRV','SVN','MKD','BIH'}
        % Ex-yugoslavian countries besides SRB/MNE/SCG (considered in an
        %   earlier case)
        [iso3_emdat,changes_list] = check_larger_country(country_ISO3,'YUG',peril_ID,years_range);
        iso3_climada = {country_ISO3};
    otherwise
        % determine emdat_country_name
        emdat_exists=any_em_data(country_ISO3,'');
        if ~emdat_exists
            % country in climada but nothing in EM-DAT
            if verbose_mode,fprintf('Country %s not found in emdat_read, but exists in climada\n',country_ISO3);end
            iso3_emdat = {};
            iso3_climada = {country_ISO3};
            changes_list = -2;
        else
            iso3_emdat = country_ISO3;
            % determine climada country name
            if isempty(country_climada)
                % country in EM-DAT but not in climada
                if verbose_mode,fprintf('Country %s not found in climada, but exists in emdat_read\n',country_ISO3);end
                iso3_climada = {};
                changes_list = -3;
            else
                % country in both EM-DAT and climada
                iso3_climada = country_ISO3;
                changes_list = 0;
            end
        end
end

% reset climada_global if changed
if ~isempty(emdat_file_global)
    climada_global.emdat_file=emdat_file_global;
else
    climada_global = rmfield(climada_global,'emdat_file');
end

end

function [data_in]=any_em_data(country_ISO3,peril_ID,years_range)
% function finding out whether EM-DAT contains any data for a given country
% over a time period defined by first and last year, for the perils given
% as peril_ID
global climada_global
if ~exist('years_range','var'),years_range=[1800 2300];end
if ~exist('peril_ID','var'),peril_ID='';end
data_in = false;
em_data_i=emdat_read(climada_global.emdat_file,country_ISO3,peril_ID);
if ~isempty(em_data_i)
    yi = (em_data_i.year >= years_range(1)) & (em_data_i.year <= years_range(2));
    data_in = any(em_data_i.damage(yi)>0);
end
end

function [iso3_emdat,changes_list]=check_larger_country(country_ISO3,larger_country_ISO3,peril_ID,years_range)
if any_em_data(larger_country_ISO3,peril_ID,years_range)
    iso3_emdat = {country_ISO3 larger_country_ISO3};
    changes_list = 99;
else
    iso3_emdat = {country_ISO3};
    changes_list = 2;
end
end

function [iso3_emdat,changes_list]=check_sub_countries(sub_countries_ISO3,peril_ID,years_range)
% here sub_countries_ISO3 MUST INCLUDE the original country
i_in = zeros([1 length(sub_countries_ISO3)]);
for i=1:length(sub_countries_ISO3)
    i_in(i) = any_em_data(sub_countries_ISO3{i},peril_ID,years_range);
end
iso3_emdat = sub_countries_ISO3(find(i_in));
changes_list = 1;
end