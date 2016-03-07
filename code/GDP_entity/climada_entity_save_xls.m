function climada_entity_save_xls(entity, entity_xls_file,dam_funct_overwrite,measures_overwrite,discount_overwrite)
% climada assets read import without assets
% MODULE:
%   GDP_entity
% NAME:
%   climada_entity_save_xls
% PURPOSE:
%   Save entiy as xls file
% CALLING SEQUENCE:
%   climada_entity_save_xls(entity, entity_xls_file)
% EXAMPLE:
%   climada_entity_save_xls(entity)
% INPUTS:
%   entity: entity strucure to write out in excel file
%   entity_xls_file: the filename of the Excel file to be written
% OUTPUTS:
%   excel file
% MODIFICATION HISTORY:
% Lea Mueller, 20130412
% Gilles Stassen 20141210 - change condition from
%                  multiple strcmp() statements to ismember(); add relevant
%                  'wrong' fields to cell array to be checked in line 64;
%                  change to dynamic field referencing instead of getfield;
%                  add isnumeric condition to damagefunction section to
%                  include peril_ID field.
% Gilles Stassen 20141211 - add overwrite options for non-asset sheets
% Gilles Stassen 20150106 - generalise condition on entity.assets.(fields)
% David N. Bresch, david.bresch@gmail.com, 20150804, old assets.Longitude replaced by assets.lon
% Lea Mueller, muellele@gmail.com, 20160212, set dam_funct_overwrite, measures_overwrite, discount_overwrite to 1 (default)
% Lea Mueller, muellele@gmail.com, 20160212, check excel limit only for .xls version
% Lea Mueller, muellele@gmail.com, 20160307, add other fields in tab "others" so that this function can be used for any kind of structure, not just an entity
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% poor man's version to check arguments
if ~exist('entity'         , 'var'), return;end
if ~exist('entity_xls_file', 'var'), entity_xls_file = [];end
if ~exist('dam_funct_overwrite', 'var'), dam_funct_overwrite = 1;end % default to overwrite entire file
if ~exist('measures_overwrite', 'var'), measures_overwrite = 1;end % default to overwrite entire file
if ~exist('discount_overwrite', 'var'), discount_overwrite = 1;end % default to overwrite entire file
warning off MATLAB:xlswrite:AddSheet

% prompt for entity_file if not given
entity = climada_entity_load(entity);

% prompt for entity_file if not given
if isempty(entity_xls_file) % local GUI
    entity_xls_file = [climada_global.data_dir filesep 'entities' filesep 'entity_out.xls'];
    [filename, pathname] = uiputfile(entity_xls_file, 'Save entity as:');
    if isequal(filename,0) || isequal(pathname,0)
        return; % cancel
    else
        entity_xls_file = fullfile(pathname,filename);
    end
end

% check if number of assets smaller than excel limit
[pathstr,name,ext] = fileparts(entity_xls_file);
if strcmp(ext,'.xls')
    xls_row_limit = 65536;
    if isfield(entity,'assets')
        if length(entity.assets.lon)>xls_row_limit 
            fprintf('\t\t ERROR: The number of assets in the entity structure (%d) exceed the number of rows in excel (.xls). (%d)\n \t\t Try .xlsx format.\n',length(entity.assets.lon),xls_row_limit)
            return
        end
    end
end

fprintf('Save entity as excel-file\n')

%% assets sheet
if isfield(entity,'assets')
    fprintf('\t\t - Assets sheet\n')
    if isstruct(entity.assets)
        fields_2 =  fieldnames(entity.assets);
        counter  = 0;
        matr     = cell(length(entity.assets.lon)+1,5);
        for row_i = 1:length(fields_2)
            if isnumeric(entity.assets.(fields_2{row_i})) && numel(entity.assets.(fields_2{row_i})) > 1
                counter         = counter+1;
                matr{1,counter} = fields_2{row_i};
                matr(2:end,counter) = num2cell(entity.assets.(fields_2{row_i})');
            end
        end
        xlswrite(entity_xls_file, matr, 'assets')
    end
end

%% damagefunctions sheet
if dam_funct_overwrite == 1;
    if isfield(entity,'damagefunctions')
        if isstruct(entity.damagefunctions)
            fprintf('\t\t - Damagefunctions sheet\n')
            fields_2 =  fieldnames(entity.damagefunctions);
            counter  = 0;
            matr     = cell(length(entity.damagefunctions.DamageFunID)+1,1);
            for row_i = 1:length(fields_2)
                if ~strcmp(fields_2{row_i},'filename')
                    counter         = counter+1;
                    matr{1,counter} = fields_2{row_i};
                    if ~isnumeric(entity.damagefunctions.(fields_2{row_i}))
                        matr(2:end,counter) = entity.damagefunctions.(fields_2{row_i});
                    else
                        matr(2:end,counter) = num2cell(entity.damagefunctions.(fields_2{row_i}));
                    end
                end
            end
            xlswrite(entity_xls_file, matr, 'damagefunctions')
        end
    end
end
%% measures sheet
if measures_overwrite == 1;
    if isfield(entity,'measures')
        if isstruct(entity.measures)
            fprintf('\t\t - Measures sheet\n')
            fields_2 =  fieldnames(entity.measures);
            counter  = 0;
            matr     = cell(length(entity.measures.name)+1,1);
            for row_i = 1:length(fields_2)
                if ~strcmp(fields_2{row_i},'filename') & ~strcmp(fields_2{row_i},'color_RGB') & ~strcmp(fields_2{row_i},'damagefunctions_mapping')
                    counter         = counter+1;
                    matr{1,counter} = fields_2{row_i};
                    if ~isnumeric(entity.measures.(fields_2{row_i})) %is not numeric
                        matr(2:end,counter) = entity.measures.(fields_2{row_i});
                    else
                        matr(2:end,counter) = num2cell(entity.measures.(fields_2{row_i}));
                    end
                end
            end
            xlswrite(entity_xls_file, matr, 'measures')
         end
    end
end

%% discount sheet
if discount_overwrite ==1;
    if isfield(entity,'discount')
        if isstruct(entity.discount)
            fprintf('\t\t - Discount sheet\n')
            fields_2 =  fieldnames(entity.discount);
            counter  = 0;
            matr     = cell(length(entity.discount.yield_ID)+1,1);
            for row_i = 1:length(fields_2)
                if ~strcmp(fields_2{row_i},'filename')
                    counter         = counter+1;
                    matr{1,counter} = fields_2{row_i};
                    if ~isnumeric(entity.discount.(fields_2{row_i})) %is not numeric
                        matr(2:end,counter) = entity.discount.(fields_2{row_i});
                    else
                        matr(2:end,counter) = num2cell(entity.discount.(fields_2{row_i}));
                    end
                end
            end
            xlswrite(entity_xls_file, matr, 'discount')
        end
    end
end


% all other fields directly in entity
fprintf('\t\t - All other fields sheet\n')
fields_2 =  fieldnames(entity);
counter  = 0;
matr     = cell(100,5); % a wild guess
for row_i = 1:length(fields_2)
    if ~strcmp(fields_2{row_i},'assets') && ~strcmp(fields_2{row_i},'damagefunctions') && ~strcmp(fields_2{row_i},'measures') && ~strcmp(fields_2{row_i},'discount')
        if isnumeric(entity.(fields_2{row_i})) && numel(entity.(fields_2{row_i})) > 0
            counter         = counter+1;
            matr{1,counter} = fields_2{row_i};
            values = full(entity.(fields_2{row_i}))'; [a,b] = size(values); 
            if a>1 && b>1, values = values(:,1); end
            matr(2:numel(values)+1,counter) = num2cell(values);
        end
    end
end
xlswrite(entity_xls_file, matr, 'others')

fprintf('\t\t Save entity as xls file\n')
cprintf([113 198 113]/255,'\t\t %s\n',entity_xls_file);


end

