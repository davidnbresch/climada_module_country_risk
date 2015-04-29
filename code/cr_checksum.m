function cr_checksum(country_name,peril_ID,report_fid)
% climada template
% MODULE:
%   country_risk
% NAME:
%   cr_checksum
% PURPOSE:
%   Calculate a checksum for entity, damage functions (the ones with ID 1)
%   and hazard sets
%
%   See also country_risk_calc
% CALLING SEQUENCE:
%   cr_checksum(country_name,peril_ID)
% EXAMPLE:
%   cr_checksum('Australia','TC')
%   cr_checksum({'Australia','China'},'TC')
%   country_list={'Japan','New Zealand','Belgium','Taiwan','Mexico','Italy','Philippines'};
%   cr_checksum(country_list)
% INPUTS:
%   country_name: a single country name (output to stdout) or a list of
%       countries (output to file ../results/cr_checksum.csv). If ='ALL',
%       run for all countries.
%       > promted for if not given
% OPTIONAL INPUT PARAMETERS:
%   peril_ID: the peril_ID we check for
%       currently aborts if no ID provided, future implementations will
%       loop over perils
%   report_fid: INTERNAL, to pass on the fid of the report file
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150429, initial
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('country_name','var'),country_name = '';end
if ~exist('peril_ID','var'),peril_ID = '';end
if ~exist('report_fid','var'),report_fid = -1;end % 1 for stdout, neg to write header

% locate the module's (or this code's) data folder (usually  afolder
% 'parallel' to the code folder, i.e. in the same level as code folder)
%module_data_dir=[fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

% PARAMETERS
%
% the folder with the country data, usually the standard one
country_data_dir = climada_global.data_dir; % default
%
% name of the file the checksum results are written (only created if >1
% country_name is passed)
report_filename=[country_data_dir filesep 'results' filesep 'cr_checksum.csv'];
%
% whether we check for probabilistic (=1, default) or historic (=0) hazard sets
probabilistic=1; % default=1

header_str='admin0(country),ISO3,centroids_checksum,entity_checksum,entity_future_checksum,hazard_name,hazard_checksum,dmf_name,dmf_checksum\n';
format_str='%s,%s,%f,%f,%f,%s,%f,%s,%f\n';
header_str=strrep(header_str,',',climada_global.csv_delimiter);
format_str=strrep(format_str,',',climada_global.csv_delimiter);

if isempty(country_name) % prompt for country (one or many) as list dialog
    country_name = climada_country_name('Multiple');
elseif strcmp(country_name,'ALL')
    country_name = climada_country_name('all');
end

if isempty(country_name),return; end % Cancel pressed

if ~iscell(country_name),country_name={country_name};end % check that country_name is a cell

if length(country_name)>1 % more than one country, process recursively
    n_countries=length(country_name);
    
    report_fid=fopen(report_filename,'w');
    fprintf(report_fid,header_str);

    for country_i = 1:n_countries
        single_country_name = country_name(country_i);
        cr_checksum(single_country_name,peril_ID,report_fid);
    end % country_i
    
    fclose(report_fid);
    fprintf('results written to %s\n',report_filename);
    return
elseif report_fid<0
    report_fid=abs(report_fid);
    fprintf(report_fid,header_str);
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

centroids_file     = [country_data_dir filesep 'system'   filesep country_ISO3 '_' strrep(country_name_char,' ','') '_centroids.mat'];
entity_file        = [climada_global.data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity.mat'];
entity_future_file = [climada_global.data_dir filesep 'entities' filesep country_ISO3 '_' strrep(country_name_char,' ','') '_entity_future.mat'];

if exist(centroids_file,'file')
    load(centroids_file); % contains entity
    centroids_checksum=sum(centroids.lon)+sum(centroids.lat);
else
    fprintf('%s: centroids not found (%s)\n',country_name_char,centroids_file);
    centroids_checksum=NaN;
end

if exist(entity_file,'file')
    load(entity_file); % contains entity
    entity_checksum=sum(entity.assets.Value);
else
    fprintf('%s: entity not found (%s)\n',country_name_char,entity_file);
    entity_checksum=NaN;
end

if exist(entity_future_file,'file')
    load(entity_future_file); % contains entity
    entity_future_checksum=sum(entity.assets.Value);
else
    fprintf('%s: entity future not found (%s)\n',country_name_char,entity_future_file);
    entity_future_checksum=NaN;
end

% figure the existing hazard set files (same procedure as in
% country_admin1_risk_calc)
probabilistic_str='_hist';if probabilistic,probabilistic_str='';end
hazard_dir=[country_data_dir filesep 'hazards'];
hazard_files=dir([hazard_dir filesep country_ISO3 '_' ...
    strrep(country_name_char,' ','') '*' probabilistic_str '.mat']);

% first, filter probabilistic/historic
valid_hazard=1:length(hazard_files); % assume all valid, the restrict
for hazard_i=1:length(hazard_files)
    if probabilistic && ~isempty(strfind(hazard_files(hazard_i).name,'_hist.mat'))
        % filter, depending on probabilistic
        valid_hazard(hazard_i)=0;
    end
end % hazard_i
valid_hazard=valid_hazard(valid_hazard>0);
hazard_files=hazard_files(valid_hazard);

if ~isempty(peril_ID)
    % second, filter requested hazards (and possibly regions)
    valid_hazard=[]; % only pick the needed ones
    % filter for peril
    for peril_i=1:size(peril_ID,1) % we allow for more than one peril here
        one_peril_ID=peril_ID(peril_i,:);
        for hazard_i=1:length(hazard_files)
            if ~isempty(strfind(hazard_files(hazard_i).name,['_' one_peril_ID]))
                % filter, depending on peril_ID
                valid_hazard(end+1)=hazard_i;
            end
        end % hazard_i
    end % peril_i
    
    if isempty(valid_hazard)
        fprintf(report_fid,format_str,country_name_char,country_ISO3,...
            centroids_checksum,entity_checksum,entity_future_checksum,'',NaN,'',NaN);
        return
    else
        hazard_files=hazard_files(valid_hazard);
    end
    
end % ~isempty(peril_ID)

% store explicit hazard event set files with path (to use load)
for hazard_i=1:length(hazard_files)
    hazard_set_file=[hazard_dir filesep hazard_files(hazard_i).name];
    hazard_name=strrep(hazard_files(hazard_i).name,'.mat','');
    hazard_checksum=NaN;
    if exist(hazard_set_file,'file')
        load(hazard_set_file); % contains entity
        hazard_checksum=full(sum(sum(hazard.intensity)));
    else
        fprintf('%s: hazard not found (%s)\n',country_name_char,hazard_name);
    end
    
    % re-load entity to check for damage function
    damagefun_checksum=NaN;unique_ID='';
    if exist(entity_file,'file')
        load(entity_file); % contains entity
        
        % create the unique_IDs, i.e. for all damage functions
        unique_IDs={}; % init
        if isfield(entity.damagefunctions,'peril_ID')
            for i=1:length(entity.damagefunctions.DamageFunID)
                unique_IDs{i}=sprintf('%s_%3.3i',entity.damagefunctions.peril_ID{i},entity.damagefunctions.DamageFunID(i));
            end % i
        else
            for i=1:length(entity.damagefunctions.DamageFunID)
                unique_IDs{i}=sprintf('%3.3i',entity.damagefunctions.DamageFunID(i));
            end % i
        end
        
        % create the unique_ID, i.e. the damage function we need
        DamageFunID=unique(entity.assets.DamageFunID);
        if length(DamageFunID)>1,DamageFunID=DamageFunID(1);end
        if isempty(peril_ID)
            dmf_peril_ID=hazard_name(end-1:end);
        else
            dmf_peril_ID=peril_ID;
        end
        unique_ID=sprintf('%s_%3.3i',dmf_peril_ID,DamageFunID);
        
        % locate relevant damage function
        dmf_pos=strmatch(unique_ID,unique_IDs);
        
        damagefun_checksum=sum(entity.damagefunctions.MDD(dmf_pos))+sum(entity.damagefunctions.PAA(dmf_pos));
        
    end
    
    fprintf(report_fid,format_str,country_name_char,country_ISO3,...
        centroids_checksum,entity_checksum,entity_future_checksum,...
        hazard_name,hazard_checksum,unique_ID,damagefun_checksum);
    
end % hazard_i

end % country_risk_calibrate