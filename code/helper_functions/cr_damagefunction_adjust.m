function entity_adjusted = cr_damagefunction_adjust(entity)
% adjust the data points describing the damage function 
% MODULE:
%   country_risk
% NAME:
%   cr_damagefunction_adjust
% PURPOSE:
%   Adjust the data points describing the damage function by multiplying
%   them with country-specific factors that are based on expert judgment. 
%   The resulting damage function provides the basis for the final climada 
%   model results of a country's expected losses over the return period(s) 
%   one is interested in.
% CALLING SEQUENCE:
%   entity_adjusted = cr_damagefunction_adjust(entity)
% EXAMPLE:
%   entity_Australia_adjusted = cr_damagefunction_adjust(entity_Australia)
% INPUTS:
%   entity: a climada entity with the fields 
%       - assets
%       - damagefunctions
%       - measures
%       - discount
%   to generate an entity, see climada_nightlight_entity (in the module 
%   country_risk) or climada_create_GDP_entity (in the module GDP_entity)
% OPTIONAL INPUT PARAMETERS:
%
% OUTPUTS:
%   entity_adjusted: entity with adjusted damagefunction; contains the
%   fields
%       - assets
%       - damagefunctions
%       - measures
%       - discount
%       - damagefunctions_adjusted (=1; flag to show that the
%       damagefunctions of that entity have been adjusted)
%       - damagefunctions_orig (original/unadjusted damage functions for
%       reference)
%   Also, damagefunctions_adjusted contains a further field 
%   'adjustment_factor_table', which contains the information on the 
%   adjustment factors for that country and all perils.
%   
%   The field 'MDR' is removed in entity_adjusted (if it existed in the 
%   input entity)
%
% MODIFICATION HISTORY:
% Melanie Bieli, melanie.bieli@bluewin.ch, 20150202, initial
%-

% initialize output
entity_adjusted = [];

% import/setup global variables
global climada_global
if ~climada_init_vars,return;end;

% check arguments
if ~exist('entity','var')
    fprintf('error: missing input argument ''entity'', can''t proceed.\n');
    return;
end


% PARAMETERS
% Table containing ISO3 country codes and the adjustment factors for all
% perils. For the time being, all factors are set to 1 (except for a few
% 'testfactors' to check if the function works)
% 1st column: country reference name
% 2nd column: country ISO3 code
% 3rd column: peril ID
% 4th column: adjustment factor
%
adjustment_factor_table  = {
    'Algeria'               'DZA'	'TC'    1;
    'Algeria'               'DZA'	'TS'    1;
    'Algeria'               'DZA'	'WS'    1;
    'Algeria'               'DZA'	'EQ'    1;
    'Australia'             'AUS'   'TC'    1;
    'Australia'             'AUS'   'TS'    1;
    'Australia'             'AUS'   'WS'    1;
    'Australia'             'AUS'   'EQ'    1;
    'Austria'               'AUT'	'TC'    1;
    'Austria'               'AUT'	'TS'    1;
    'Austria'               'AUT'	'WS'    1;
    'Austria'               'AUT'	'EQ'    1;
    'Belgium'               'BEL'	'TC'    1;
    'Belgium'               'BEL'	'TS'    1;
    'Belgium'               'BEL'	'WS'    1;   
    'Belgium'               'BEL'	'EQ'    1;
    'Bangladesh'            'BGD'	'TC'    1;  
    'Bangladesh'            'BGD'	'TS'    1;
    'Bangladesh'            'BGD'	'WS'    1;
    'Bangladesh'            'BGD'	'EQ'    1;
    'Brazil'                'BRA'	'TC'    1;
    'Brazil'                'BRA'	'TS'    1;
    'Brazil'                'BRA'	'WS'    1;  
    'Brazil'                'BRA'	'EQ'    1;
    'Canada'                'CAN'	'TC'    1;
    'Canada'                'CAN'	'TS'    1;  
    'Canada'                'CAN'	'WS'    1;
    'Canada'                'CAN'	'EQ'    1;
    'Cambodia'              'KHM'	'TC'    1;
    'Cambodia'              'KHM'	'TS'    1;
    'Cambodia'              'KHM'	'WS'    1;
    'Cambodia'              'KHM'	'EQ'    1;
    'Chile'                 'CHL'   'TC'    1;
    'Chile'                 'CHL'   'TS'    1;
    'Chile'                 'CHL'   'WS'    1;   
    'Chile'                 'CHL'   'EQ'    1;
    'China'                 'CHN'   'TC'    2;  
    'China'                 'CHN'   'TS'    3;
    'China'                 'CHN'   'WS'    4;
    'China'                 'CHN'   'EQ'    10;
    'Colombia'              'COL'	'TC'    1;
    'Colombia'              'COL'	'TS'    1;
    'Colombia'              'COL'	'WS'    1;
    'Colombia'              'COL'	'EQ'    1;
    'Costa Rica'            'CRI'	'TC'    1;
    'Costa Rica'            'CRI'	'TS'    1;
    'Costa Rica'            'CRI'	'WS'    1;
    'Costa Rica'            'CRI'	'EQ'    1;
    'Czech Republic'        'CZE'	'TC'    1;
    'Czech Republic'        'CZE'	'TS'    1;
    'Czech Republic'        'CZE'	'WS'    1;
    'Czech Republic'        'CZE'	'EQ'    1;
    'Denmark'               'DNK'	'TC'    1;
    'Denmark'               'DNK'	'TS'    1;
    'Denmark'               'DNK'	'WS'    1;
    'Denmark'               'DNK'	'EQ'    1;
    'Dominican Republic'    'DOM'	'TC'    1;
    'Dominican Republic'    'DOM'	'TS'    1;
    'Dominican Republic'    'DOM'	'WS'    1;
    'Dominican Republic'    'DOM'	'EQ'    1;
    'Ecuador'               'ECU'	'TC'    1;
    'Ecuador'               'ECU'	'TS'    1;
    'Ecuador'               'ECU'	'WS'    1;
    'Ecuador'               'ECU'	'EQ'    1;
    'Finland'               'FIN'	'TC'    1;
    'Finland'               'FIN'	'TS'    1;
    'Finland'               'FIN'	'WS'    1;
    'Finland'               'FIN'	'EQ'    1;
    'France'                'FRA'	'TC'    1;
    'France'                'FRA'	'TS'    1;
    'France'                'FRA'	'WS'    1;
    'France'                'FRA'	'EQ'    1;
    'Germany'               'DEU'	'TC'    1;
    'Germany'               'DEU'	'TS'    1;
    'Germany'               'DEU'	'WS'    1;
    'Germany'               'DEU'	'EQ'    1;
    'Greece'                'GRC'	'TC'    1;
    'Greece'                'GRC'	'TS'    1;
    'Greece'                'GRC'	'WS'    1;
    'Greece'                'GRC'	'EQ'    1;
    'Hungary'               'HUN'	'TC'    1;
    'Hungary'               'HUN'	'TS'    1;
    'Hungary'               'HUN'	'WS'    1;
    'Hungary'               'HUN'	'EQ'    1;
    'India'                 'IND'	'TC'    1;
    'India'                 'IND'	'TS'    1;
    'India'                 'IND'	'WS'    1;
    'India'                 'IND'	'EQ'    1;
    'Indonesia'             'IDN'	'TC'    1;
    'Indonesia'             'IDN'	'TS'    1;
    'Indonesia'             'IDN'	'WS'    1;
    'Indonesia'             'IDN'	'EQ'    1;
    'Ireland'               'IRL'	'TC'    1;
    'Ireland'               'IRL'	'TS'    1;
    'Ireland'               'IRL'	'WS'    1;
    'Ireland'               'IRL'	'EQ'    1;
    'Israel'                'ISR'	'TC'    1;
    'Israel'                'ISR'	'TS'    1;
    'Israel'                'ISR'	'WS'    1;
    'Israel'                'ISR'	'EQ'    1;
    'Italy'                 'ITA'	'TC'    5;
    'Italy'                 'ITA'	'TS'    2;
    'Italy'                 'ITA'	'WS'    10;
    'Italy'                 'ITA'	'EQ'    11;
    'Japan'                 'JPN'	'TC'    1;
    'Japan'                 'JPN'	'TS'    1;
    'Japan'                 'JPN'	'WS'    1;
    'Japan'                 'JPN'	'EQ'    1;
    'Kenya'                 'KEN'   'TC'    1;
    'Kenya'                 'KEN'   'TS'    1;
    'Kenya'                 'KEN'   'WS'    1;
    'Kenya'                 'KEN'   'EQ'    1;
    'Laos'                  'LAO'	'TC'    1;
    'Laos'                  'LAO'	'TS'    1;
    'Laos'                  'LAO'	'WS'    1;
    'Laos'                  'LAO'	'EQ'    1;
    'Mexico'                'MEX'	'TC'    1;
    'Mexico'                'MEX'	'TS'    1;
    'Mexico'                'MEX'	'WS'    1;
    'Mexico'                'MEX'	'EQ'    1;
    'Morocco'               'MAR'   'TC'    1;
    'Morocco'               'MAR'   'TS'    1;
    'Morocco'               'MAR'   'WS'    1;
    'Morocco'               'MAR'   'EQ'    1;
    'Myanmar'               'MMR'	'TC'    1;
    'Myanmar'               'MMR'	'TS'    1;
    'Myanmar'               'MMR'	'WS'    1;
    'Myanmar'               'MMR'	'EQ'    1;
    'Netherlands'           'NLD'	'TC'    1;
    'Netherlands'           'NLD'	'TS'    1;
    'Netherlands'           'NLD'	'WS'    1;
    'Netherlands'           'NLD'	'EQ'    1;
    'New Zealand'           'NZL'	'TC'    1;
    'New Zealand'           'NZL'	'TS'    1;
    'New Zealand'           'NZL'	'WS'    1;
    'New Zealand'           'NZL'	'EQ'    1;
    'Nigeria'               'NGA'   'TC'    1;
    'Nigeria'               'NGA'   'TS'    1;
    'Nigeria'               'NGA'   'WS'    1;
    'Nigeria'               'NGA'   'EQ'    1;
    'Norway'                'NOR'	'TC'    1;
    'Norway'                'NOR'	'TS'    1;
    'Norway'                'NOR'	'WS'    1;
    'Norway'                'NOR'	'EQ'    1;
    'Pakistan'              'PAK'	'TC'    1;
    'Pakistan'              'PAK'	'TS'    1;
    'Pakistan'              'PAK'	'WS'    1;
    'Pakistan'              'PAK'	'EQ'    1;
    'Panama'                'PAN'	'TC'    1;
    'Panama'                'PAN'	'TS'    1;
    'Panama'                'PAN'	'WS'    1;
    'Panama'                'PAN'	'EQ'    1;
    'Peru'                  'PER'	'TC'    1;
    'Peru'                  'PER'	'TS'    1;
    'Peru'                  'PER'	'WS'    1;
    'Peru'                  'PER'	'EQ'    1;
    'Philippines'           'PHL'	'TC'    1;
    'Philippines'           'PHL'	'TS'    1;
    'Philippines'           'PHL'	'WS'    1;
    'Philippines'           'PHL'	'EQ'    1;
    'Poland'                'POL'	'TC'    1;
    'Poland'                'POL'	'TS'    1;
    'Poland'                'POL'	'WS'    1;
    'Poland'                'POL'	'EQ'    1;
    'Portugal'              'PRT'	'TC'    1;
    'Portugal'              'PRT'	'TS'    1;
    'Portugal'              'PRT'	'WS'    1;
    'Portugal'              'PRT'	'EQ'    1;
    'Singapore'             'SGP'	'TC'    1;
    'Singapore'             'SGP'	'TS'    1;
    'Singapore'             'SGP'	'WS'    1;
    'Singapore'             'SGP'	'EQ'    1;
    'Slovakia'              'SVK'	'TC'    1;
    'Slovakia'              'SVK'	'TS'    1;
    'Slovakia'              'SVK'	'WS'    1;
    'Slovakia'              'SVK'	'EQ'    1;
    'Slovenia'              'SVN'	'TC'    1;
    'Slovenia'              'SVN'	'TS'    1;
    'Slovenia'              'SVN'	'WS'    1;
    'Slovenia'              'SVN'	'EQ'    1;
    'South Africa'          'ZAF'	'TC'    1;
    'South Africa'          'ZAF'	'TS'    1;
    'South Africa'          'ZAF'	'WS'    1;
    'South Africa'          'ZAF'	'EQ'    1;    
    'Korea'                 'KOR'	'TC'    1;
    'Korea'                 'KOR'	'TS'    1;
    'Korea'                 'KOR'	'WS'    1;
    'Korea'                 'KOR'	'EQ'    1;
    'Spain'                 'ESP'	'TC'    1;
    'Spain'                 'ESP'	'TS'    1;
    'Spain'                 'ESP'	'WS'    1;
    'Spain'                 'ESP'	'EQ'    1;
    'Sri Lanka'             'LKA'	'TC'    1;
    'Sri Lanka'             'LKA'	'TS'    1;
    'Sri Lanka'             'LKA'	'WS'    1;
    'Sri Lanka'             'LKA'	'EQ'    1;
    'Sweden'                'SWE'   'TC'    1;
    'Sweden'                'SWE'   'TS'    1;
    'Sweden'                'SWE'   'WS'    1;
    'Sweden'                'SWE'   'EQ'    1;
    'Switzerland'           'CHE'   'TC'    1;
    'Switzerland'           'CHE'   'TS'    1;
    'Switzerland'           'CHE'   'WS'    1;
    'Switzerland'           'CHE'   'EQ'    1;
    'Taiwan'                'TWN'   'TC'    1;
    'Taiwan'                'TWN'   'TS'    1;
    'Taiwan'                'TWN'   'WS'    1;
    'Taiwan'                'TWN'   'EQ'    1;
    'Thailand'              'THA'	'TC'    1;
    'Thailand'              'THA'	'TS'    1;
    'Thailand'              'THA'	'WS'    1;
    'Thailand'              'THA'	'EQ'    1;
    'Tunisia'               'TUN'	'TC'    1;
    'Tunisia'               'TUN'	'TS'    1;
    'Tunisia'               'TUN'	'WS'    1;
    'Tunisia'               'TUN'	'EQ'    1;
    'Turkey'                'TUR'	'TC'    1;
    'Turkey'                'TUR'	'TS'    1;
    'Turkey'                'TUR'	'WS'    1;
    'Turkey'                'TUR'	'EQ'    1;
    'United Kingdom'        'GBR'   'TC'    1;
    'United Kingdom'        'GBR'   'TS'    1;
    'United Kingdom'        'GBR'   'WS'    1;
    'United Kingdom'        'GBR'   'EQ'    1;
    'United States'         'USA'	'TC'    1;
    'United States'         'USA'	'TS'    1;
    'United States'         'USA'	'WS'    1;
    'United States'         'USA'	'EQ'    1;
    'Uruguay'               'URY'	'TC'    1;
    'Uruguay'               'URY'	'TS'    1;
    'Uruguay'               'URY'	'WS'    1;
    'Uruguay'               'URY'	'EQ'    1;
    'Vietnam'               'VNM'   'TC'    1;
    'Vietnam'               'VNM'   'TS'    1;
    'Vietnam'               'VNM'   'WS'    1;
    'Vietnam'               'VNM'   'EQ'    1;
};

% get rid of MDR (not needed)
if isfield(entity.damagefunctions,'MDR')
    entity.damagefunctions = rmfield(entity.damagefunctions,'MDR');
end

% make sure damagefunctions only get adjusted once
if ~isfield(entity,'damagefunctions_adjusted'),entity.damagefunctions_adjusted=0;end

if ~entity.damagefunctions_adjusted
    entity.damagefunctions_orig=entity.damagefunctions;  % backup 
    
    % find the row indices for the required country in the table 
    % (each country has 4 entries, one for each peril)
    country_positions = find(strcmp(adjustment_factor_table(:,2),entity.assets.admin0_ISO3));
    
    % loop over all damage function data points (for all perils)
    for damage_datapoint_i = 1:length(entity.damagefunctions.DamageFunID)
        % in the adjustment_factor_table, find the index of the row that 
        % contains the required country as well as the required peril ID
        peril_positions = find(strcmp(adjustment_factor_table(:,3),...
            entity.damagefunctions.peril_ID(damage_datapoint_i)));
        row_index = intersect(country_positions, peril_positions);
        if isempty(row_index)
            % no entry found
            fprintf('Error: There is no entry for ISO3 code %s and peril ID %s.\n',...
                entity.assets.admin0_ISO3,entity.damagefunctions.peril_ID(damage_datapoint_i))
            return;
        end
        % now we can extract the adjustment factor from the table
        adjustment_factor = cell2mat(adjustment_factor_table(row_index,4));
        % adjust the mean damage degree (MDD) accordingly 
        entity.damagefunctions.MDD(damage_datapoint_i) = ...
            entity.damagefunctions.MDD(damage_datapoint_i)*adjustment_factor;     
    end % end damage_datapoint_i
    
    % set flag to 1 to make sure the damage function does not get 
    % adjusted another time
    entity.damagefunctions_adjusted = 1;
        
    % we also add to the entity the part of the table that contains the
    % relevant information for the respective country
    entity.damagefunctions.adjustment_factor_table = ...
        adjustment_factor_table(country_positions,:);
    
end % end if
        
entity_adjusted=entity;


