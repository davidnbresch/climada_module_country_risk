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
% David N. Bresch, david.bresch@gmail.com, 20150126, ED also reported
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
show_plot=1;
if show_plot,close all;end % since we may produce many figures...
%
% whether we only want to check entity
check_entity_only=0; % default=0
%
% plot layout, define how many subplots horizontally and vertically
% (n_plots_horz*n_plots_vert+1 plot opens new figure)
n_plots_horz=4;n_plots_vert=2;
%
% the maximum return period (RP) to show in plots - has to be one of the
% return periods the comparison DFC exists for
plot_max_RP=200; % default=200
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

out_fmt2='%s;%s;%f;%f;%s;SCALING FACTOR:;%f\n';
out_fmt2=strrep(out_fmt2,';',climada_global.csv_delimiter);


for file_i=1:length(D)
%for file_i=2:2 % 2 for TC CHN
    if ~D(file_i).isdir
        
        [~,fN]=fileparts([cmp_folder filesep D(file_i).name]);
        
        file_name=strrep(fN,'_cmp_results',''); %e.g. fN=CHE_Switzerland_glb_EQ_cmp_results
        fprintf('%s: (file_i=%i)\n',file_name,file_i);
        
        % get the damage frequency curve (DFC)
        [cmp_folder filesep D(file_i).name]
        return
        DFC_cmp=climada_DFC_read([cmp_folder filesep D(file_i).name]);
        
        % get the corresponding climada result
        hazard_file=file_name; %e.g. CHE_Switzerland_glb_EQ_cmp_results
        entity_file=[hazard_file(1:end-7) '_entity'];
        hazard_file=[climada_global.data_dir filesep 'hazards' filesep hazard_file '.mat'];
        entity_file=[climada_global.data_dir filesep 'entities' filesep entity_file '.mat'];
           
        % make sure we have latest GDP
        entity_adjusted=climada_entity_value_GDP_adjust(entity_file,2);
        
        if exist(entity_file,'file') && exist(hazard_file,'file')
            load(entity_file)
            
            entity.assets.Cover=entity.assets.Value;
            %             Cover_pct=entity.assets.Cover./entity.assets.Value;
            %             if max(Cover_pct)<0.01
            %                 fprintf('Warning: max Cover less than 1%% of Value -> set to Value\n');
            %                 entity.assets.Cover=entity.assets.Value;
            %             end
            %             fprintf('min/max Cover: %f%%..%f%%\n',min(Cover_pct)*100,max(Cover_pct)*100);
            
            if ~check_entity_only
                
                load(hazard_file)
                
                % hazard-dependent switches to adjust (later implement at
                % proper place in DBs)
                switch char(hazard.peril_ID(1:2))
                    case 'WS'
                        %                     entity.damagefunctions.MDD=entity.damagefunctions.MDD*1;
                        %                     entity.damagefunctions.PAA=entity.damagefunctions.PAA*1;
                        %                     fprintf('NOTE: WS damagefunctions adjusted\n');
                    case 'TC'
                        %                     entity.damagefunctions.MDD=entity.damagefunctions.MDD*1;
                        %                     entity.damagefunctions.PAA=entity.damagefunctions.PAA*1;
                        %                     fprintf('NOTE: WS damagefunctions adjusted\n');
                        if strfind(hazard.filename,'_wpa_')
                            fprintf(' >> wpa detected, adjusted <<\n')
                            %entity.damagefunctions.Intensity=entity.damagefunctions.Intensity+30;
                            %hazard.intensity=hazard.intensity/1.15;
                            
%                             entity.damagefunctions.Intensity=[0 20 30 40 50 60 70 80 100];
%                             entity.damagefunctions.MDR=[0 0 0.0000 0.0000 0.0004 0.0054 0.0584 0.1694 0.1694];
%                             entity.damagefunctions.MDD=entity.damagefunctions.MDR;
%                             entity.damagefunctions.PAA=entity.damagefunctions.MDR*0+1;
%                             entity.damagefunctions.DamageFunID=entity.damagefunctions.MDR*0+1;
%                             entity.damagefunctions.peril_ID=entity.damagefunctions.peril_ID(1:length(entity.damagefunctions.MDR));
                            
                        end
                end
                
                % calculate climada EDS and DFC
                EDS=climada_EDS_calc(entity,hazard);
                DFC=climada_EDS2DFC(EDS,DFC_cmp.return_period); % same return periods as comparison
               
                % use EM-DAT information to calibrate, if available
                em_data=emdat_read('',entity.assets.admin0_name,char(hazard.peril_ID(1:2)),1,0);
                if ~isempty(em_data)
                    
                    % calculate climada DFC on EM-DAT return periods
                    DFC_0=climada_EDS2DFC(EDS,em_data.DFC.return_period);
                    
                    % figure adjustment factor for climada to match EM-DAT
                    climada2emdat_factor=em_data.DFC.damage./DFC_0.damage;
                    
                    DFC_weight_pos=em_data.DFC.return_period>20 & DFC_0.damage>0; % we look into >20 years
                    if ~isempty(DFC_weight_pos)
                        % weight the factor, in order to only have one global
                        climada2emdat_factor_weighted=climada2emdat_factor(DFC_weight_pos)*...
                            em_data.DFC.return_period(DFC_weight_pos)'/sum(em_data.DFC.return_period(DFC_weight_pos));
                        fprintf('EM-DAT: climada scaling factor %f\n',climada2emdat_factor_weighted);
                    else
                        climada2emdat_factor_weighted=1.0;
                        fprintf('EM-DAT: no adjustment (not enough EM-DAT data)\n');
                    end
                    
%                     fprintf('RP EM-DAT     climada\n');
%                     for i=1:length(DFC_0.damage)
%                         fprintf('%i %f %f\n',ceil(em_data.DFC.return_period(i)),em_data.DFC.damage(i),DFC_0.damage(i));
%                     end
                    
                    % adjust damagefunctions (the crude way)
                    entity.damagefunctions.MDD=entity.damagefunctions.MDD*climada2emdat_factor_weighted;
                    
                    % admin0_name;admin0_ISO3;climada value;cmp value;SCALING FACTOR:;factor';
                    fprintf(fid,out_fmt2,entity.assets.admin0_ISO3,entity.assets.admin0_name,...
                        0,0,char(hazard.peril_ID),...
                        climada2emdat_factor_weighted);
                    
                    % and, since a linear scale, we omit fgu recaculation
                    EDS.damage=EDS.damage*climada2emdat_factor_weighted;
                    DFC=climada_EDS2DFC(EDS,DFC_cmp.return_period); % same return periods as comparison
 
                else
                    
                    % admin0_name;admin0_ISO3;climada value;cmp value;SCALING FACTOR:;factor';
                    fprintf(fid,out_fmt2,entity.assets.admin0_ISO3,entity.assets.admin0_name,...
                        0,0,char(hazard.peril_ID)); % no scaling factor
                    
                end % em_data
                
                if scale_value_flag
                    % multiply climada to match cmp value
                    scale_value_factor=DFC_cmp.value/DFC.value;
                    DFC.value=DFC.value*scale_value_factor;
                    DFC.damage=DFC.damage*scale_value_factor;
                else
                    scale_value_factor=1;
                end % scale_value_flag
                
                if show_plot
                    subplot_no=mod(next_res_i-1,n_plots_horz*n_plots_vert)+1;
                    if subplot_no==1
                        figure('Color',[1 1 1]) % new figure for each
                    end
                    subplot(n_plots_vert,n_plots_horz,subplot_no); % 4 plots
                    
                    % show comparison
                    plot(DFC.return_period,DFC.damage,'-b','LineWidth',2); hold on
                    plot(DFC_cmp.return_period,DFC_cmp.damage,'-k','LineWidth',1); hold on
                    
                    % add EM-DAT information if available
                    if ~isempty(em_data)
                        if isfield(em_data,'DFC_orig')
                            plot(em_data.DFC.return_period,em_data.DFC.damage,'xg'); hold on
                            plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og'); hold on
                            legend('climada','cmp',em_data.DFC.annotation_name,em_data.DFC_orig.annotation_name);
                            title(strrep(file_name,'_',' '));
                        else
                            plot(em_data.DFC.return_period,em_data.DFC.damage,'og'); hold on
                            legend('climada','cmp',em_data.DFC.annotation_name);title(strrep(file_name,'_',' '));
                        end
                    else
                        legend('climada','cmp');title(strrep(file_name,'_',' '));
                    end
                    
                    if ~isempty(DFC_0) % show unadjusted climada
                        plot(DFC_0.return_period,DFC_0.damage,':b','LineWidth',2); hold on
                        DFC_0=[];
                    end
                    
                    % zoom to 0..plot_max_RP years return period
                    posRP= DFC.return_period==plot_max_RP;
                    posRP_cmp= DFC_cmp.return_period==plot_max_RP;
                    DFC_val=DFC.damage(posRP);if isnan(DFC_val),DFC_val=max(DFC.damage);end
                    DFC_cmp_val=DFC_cmp.damage(posRP_cmp);if isnan(DFC_cmp_val),DFC_cmp_val=max(DFC_cmp.damage);end
                    y_max=max(DFC_val,DFC_cmp_val);
                    axis([0 plot_max_RP 0 y_max]);
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
                
                v1=DFC.ED;v2=DFC_cmp.ED;vq=v1/v2*100;
                fprintf('  ED     climada %2.2g, cmp %2.2g, %3.0f%% (value factor %3.0f)\n',v1,v2,vq,scale_value_factor);
                
                % admin0_name;admin0_ISO3;climada value;cmp value;return period;climada damage;cmp damage';
                fprintf(fid,out_fmt,res(next_res_i).admin0_ISO3,res(next_res_i).admin0_name,...
                    res(next_res_i).DFC.value,res(next_res_i).DFC_cmp.value,char(hazard.peril_ID),1,DFC.ED,DFC_cmp.ED);
                
                for reference_RP_i=1:length(reference_RP)
                    ref_pos=find(DFC.return_period==reference_RP(reference_RP_i));
                    if ~isempty(ref_pos)
                        res(next_res_i).return_period(end+1) =reference_RP(reference_RP_i);
                        res(next_res_i).DFC.damage(end+1)    =DFC.damage(ref_pos);
                        res(next_res_i).DFC_cmp.damage(end+1)=DFC_cmp.damage(ref_pos);
                        
                        v1=DFC.damage(ref_pos);v2=DFC_cmp.damage(ref_pos);vq=v1/v2*100;
                        fprintf('  %i yr climada %2.2g, cmp %2.2g, %3.0f%% (value factor %3.0f)\n',reference_RP(reference_RP_i),...
                            v1,v2,vq,scale_value_factor);
                        
                        % admin0_name;admin0_ISO3;climada value;cmp value;return period;climada damage;cmp damage';
                        fprintf(fid,out_fmt,res(next_res_i).admin0_ISO3,res(next_res_i).admin0_name,...
                            res(next_res_i).DFC.value,res(next_res_i).DFC_cmp.value,char(hazard.peril_ID),...
                            reference_RP(reference_RP_i),DFC.damage(ref_pos),DFC_cmp.damage(ref_pos));
                    end
                end % reference_RP_i
                next_res_i=next_res_i+1;
                
            end % ~check_entity_only
            
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