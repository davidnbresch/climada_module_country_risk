function country_hazard_comparison(cmp_folder,cmp_file_regexp)
% country_hazard_comparison
% MODULE:
%   module name
% NAME:
%   country_hazard_comparison
% PURPOSE:
%   run the model comparison for countries and hazards. Loops over damage
%   frequency curve (DFC) files (see climada_DFC_read), indentifies the
%   matching climada entity and hazard event set and shows the DFCs for
%   comparison (and any other further use).
%   
%   See e.g. climada_DFC_comparison for further scrutiny
% CALLING SEQUENCE:
%   country_hazard_comparison(cmp_folder)
% EXAMPLE:
%   country_hazard_comparison
% INPUTS:
%   cmp_folder: folder with model comparison files, i.e. DFC files with
%       names III_name_rrr_PP_cmp_results with III ISO3, name country name,
%       rrr the peril PP region (e.g. CHE_Switzerland_glb_EQ_cmp_results)
%       > prompted for folder if not given
% OPTIONAL INPUT PARAMETERS:
%   cmp_file_regexp: the regexp to find the comparison files in cmp_folder
%       Default=['*' climada_global.spreadsheet_ext] (hence e.g. '*.xls')
%       This way, one can also restrict files such as '*_latest.xlsx'
% OUTPUTS:
%   Just DFC plots
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150120, initial
%-

res=[]; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('cmp_folder','var'),cmp_folder=[];end
if ~exist('cmp_file_regexp','var'),cmp_file_regexp=['*' climada_global.spreadsheet_ext];end

% PARAMETERS
%
close all % since we may produce many figures...
%
climada_global.waitbar=0; % no progress bar

% prompt for cmp_folder if not given
if isempty(cmp_folder) % local GUI
    cmp_folder=[climada_global.data_dir filesep 'results'];
    cmp_folder=uigetdir(cmp_folder, 'Select folder with comparison files:');
    if length(cmp_folder)<2,return;end
end

D=dir([cmp_folder filesep cmp_file_regexp]);

for file_i=1:length(D)
    if ~D(file_i).isdir
        
        [~,fN]=fileparts([cmp_folder filesep D(file_i).name]);
        
        file_name=strrep(fN,'_cmp_results',''); %e.g. fN=CHE_Switzerland_glb_EQ_MSP_results
        fprintf('%s:\n',file_name);
        
        % get the damage frequency curve (DFC)
        DFC_cmp=climada_DFC_read([cmp_folder filesep D(file_i).name]);
        
        
        % get the corresponding climada result
        hazard_file=file_name; %e.g. CHE_Switzerland_glb_EQ_cmp_results
        entity_file=[hazard_file(1:end-7) '_entity'];
        hazard_file=[climada_global.data_dir filesep 'hazards' filesep hazard_file '.mat'];
        entity_file=[climada_global.data_dir filesep 'entities' filesep entity_file '.mat'];
        
        if exist(entity_file,'file') && exist(hazard_file,'file')
            load(entity_file)
            load(hazard_file)
            DFC=climada_EDS2DFC(climada_EDS_calc(entity,hazard),DFC_cmp.return_period); % same return periods
            
            % multiply climada to match cmp value
            cmp_factor=DFC_cmp.value/DFC.value;
            DFC.value=DFC.value*cmp_factor;
            DFC.damage=DFC.damage*cmp_factor;
            
            % show comparison
            figure('Color',[1 1 1]) % new figure for each
            plot(DFC.return_period,DFC.damage,'-b'); hold on
            plot(DFC_cmp.return_period,DFC_cmp.damage,'-g'); hold on
            legend('climada','cmp');title(strrep(file_name,'_',' '));
            % zoom to 0..500 years return period
            pos500=find(DFC.return_period==500);
            y_max=max(DFC.damage(pos500),DFC_cmp.damage(pos500));
            axis([0 500 0 y_max]);
            hold off
            drawnow
            
            pos100=find(DFC.return_period==100);
            fprintf('  100 yr climada %f, cmp %f (value factor %f)\n',DFC.damage(pos100),DFC_cmp.damage(pos100),cmp_factor);
        else
            inset_str='';
            if ~exist(entity_file,'file'),fprintf('  Not found: entity %s\n',entity_file);inset_str='  ';end
            if ~exist(hazard_file,'file'),fprintf('  %sNot found: hazard %s\n',inset_str,hazard_file);end
        end
        
    end;
end % file_i