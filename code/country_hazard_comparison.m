function res=country_hazard_comparison(cmp_folder,cmp_file_regexp,scale_value_flag,reference_RP)
% country_hazard_comparison
% MODULE:
%   module name
% NAME:
%   country_hazard_comparison
% PURPOSE:
%   Model comparison (cmp) for countries and hazards
%
%   Loops over damage frequency curve (DFC) files (see climada_DFC_read),
%   indentifies the matching climada entity and hazard event set and shows
%   the DFCs for comparison (and any other further use).
%
%   See e.g. climada_DFC_comparison for further scrutiny
% CALLING SEQUENCE:
%   country_hazard_comparison(cmp_folder)
% EXAMPLE:
%   country_hazard_comparison
%   country_hazard_comparison('','*.xlsx',0); % no scaling
% INPUTS:
%   cmp_folder: folder with model comparison files, i.e. DFC files with
%       names III_name_rrr_PP_cmp_results with III ISO3, name country name,
%       rrr the peril PP region (e.g. CHE_Switzerland_glb_EQ_cmp_results)
%       > prompted for folder if not given
% OPTIONAL INPUT PARAMETERS:
%   cmp_file_regexp: the regexp to find the comparison files in cmp_folder
%       Default=['*' climada_global.spreadsheet_ext] (hence e.g. '*.xls')
%       This way, one can also restrict files such as '*_latest.xlsx'
%   scale_value_flag: =1: scale value of climada (and damages) to cmp value
%       (default), =0 keep values and do not scale damages.
%   reference_RP: the (few) reference return periods we report values in
%       res (the output). Default: reference_RP=[100 200]. Values have to
%       be return period the cmp results exist for (no interpolation).
% OUTPUTS:
%   res: a struct with
%       file_name: the comparison filename
%       admin0_ISO3: the country ISO3 (if in entity)
%       admin0_name: the country name (if in entity)
%       DFC.value: the value 'underlying' the climada DFC
%       DFC_cmp.value: the value 'underlying' the comparison DFC
%       return_period(i): the return periods (as in reference_RP)
%       DFC.damage(i): the climada damage for return_period(i)
%       DFC_cmp.damage(i): the comparison damage for return_period(i)
%   Plus the DFC plots and writes a small report to
%       'country_hazard_comparison.csv'
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150120, initial
% David N. Bresch, david.bresch@gmail.com, 20150122, scale_value_flag
%-

res=[];next_res_i=1; % init output

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
% and to set default value where  appropriate
if ~exist('cmp_folder','var'),cmp_folder=[];end
if ~exist('cmp_file_regexp','var'),cmp_file_regexp=['*' climada_global.spreadsheet_ext];end
if ~exist('scale_value_flag','var'),scale_value_flag=1;end
if ~exist('reference_RP','var'),reference_RP=[100 200];end % reference return period to report in res (see code)

% PARAMETERS
%
show_plot=0;
if show_plot,close all;end % since we may produce many figures...
%
report_filename=[climada_global.data_dir filesep 'results' filesep mfilename '.csv'];
%
climada_global.waitbar=0; % no progress bar

% prompt for cmp_folder if not given
if isempty(cmp_folder) % local GUI
    cmp_folder=[climada_global.data_dir filesep 'results'];
    cmp_folder=uigetdir(cmp_folder, 'Select folder with comparison files:');
    if length(cmp_folder)<2,return;end
end

D=dir([cmp_folder filesep cmp_file_regexp]);

fid=fopen(report_filename,'w');
out_hdr='admin0_name;admin0_ISO3;climada value;cmp value;peril;return period;climada damage;cmp damage';
out_hdr=strrep(out_hdr,';',climada_global.csv_delimiter);
fprintf(fid,'%s\n',out_hdr);
out_fmt='%s;%s;%f;%f;%s;%i;%f;%f\n';
out_fmt=strrep(out_fmt,';',climada_global.csv_delimiter);


for file_i=1:length(D)
    if ~D(file_i).isdir
        
        [~,fN]=fileparts([cmp_folder filesep D(file_i).name]);
        
        file_name=strrep(fN,'_cmp_results',''); %e.g. fN=CHE_Switzerland_glb_EQ_cmp_results
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
            
            if scale_value_flag
                % multiply climada to match cmp value
                scale_value_factor=DFC_cmp.value/DFC.value;
                DFC.value=DFC.value*scale_value_factor;
                DFC.damage=DFC.damage*scale_value_factor;
            else
                scale_value_factor=1;
            end % scale_value_flag
            
            if show_plot
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
            end
            
            res(next_res_i).file_name=file_name;
            res(next_res_i).admin0_ISO3='';
            res(next_res_i).admin0_name='';
            if isfield(entity.assets,'admin0_ISO3'),...
                    res(next_res_i).admin0_ISO3=entity.assets.admin0_ISO3;end
            if isfield(entity.assets,'admin0_name'),...
                    res(next_res_i).admin0_name=entity.assets.admin0_name;end
            res(next_res_i).DFC.value=DFC.value;
            res(next_res_i).DFC_cmp.value=DFC_cmp.value;
            res(next_res_i).return_period=[];
            res(next_res_i).DFC.damage=[];
            res(next_res_i).DFC_cmp.damage=[];
            
            for reference_RP_i=1:length(reference_RP)
                ref_pos=find(DFC.return_period==reference_RP(reference_RP_i));
                if ~isempty(ref_pos)
                    res(next_res_i).return_period(end+1) =reference_RP(reference_RP_i);
                    res(next_res_i).DFC.damage(end+1)    =DFC.damage(ref_pos);
                    res(next_res_i).DFC_cmp.damage(end+1)=DFC_cmp.damage(ref_pos);
                    fprintf('  %i yr climada %f, cmp %f (value factor %f)\n',reference_RP(reference_RP_i),DFC.damage(ref_pos),DFC_cmp.damage(ref_pos),scale_value_factor);
                    
                    % admin0_name;admin0_ISO3;climada value;cmp value;return period;climada damage;cmp damage';
                    fprintf(fid,out_fmt,res(next_res_i).admin0_ISO3,res(next_res_i).admin0_name,...
                        res(next_res_i).DFC.value,res(next_res_i).DFC_cmp.value,char(hazard.peril_ID),...
                        reference_RP(reference_RP_i),DFC.damage(ref_pos),DFC_cmp.damage(ref_pos));
                end
            end % reference_RP_i
            next_res_i=next_res_i+1;
            
        else
            inset_str='';
            if ~exist(entity_file,'file'),fprintf('  Not found: entity %s\n',entity_file);inset_str='  ';end
            if ~exist(hazard_file,'file'),fprintf('  %sNot found: hazard %s\n',inset_str,hazard_file);end
        end
        
    end
    
end % file_i

fclose(fid);
fprintf('results written to %s\n',report_filename);

end % country_hazard_comparison