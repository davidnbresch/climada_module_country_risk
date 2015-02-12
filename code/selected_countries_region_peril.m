% selected_countries_region_peril
% climada batch code
% MODULE:
%   country_risk
% NAME:
%   selected_countries_region_peril
% PURPOSE:
%   Run all countries for a given peril (e.g. TC) and region (e.g. atl)
%   in order to e.g. adjust damage functions for this peril and region.
%   On first call, you might have to set peril_region='' in order to
%   generate all hazard event sets.
%
%   It generates all entities (the assets) and hazard event sets and
%   calculates damages. In essence, a clever caller to country_risk_calc
%
%   Subsequent calls just repeat the damage calculations (unless you set
%   country_risk_calc_force_recalc=1).
%   Thus if you repeat the second step, since all hazard sets are stored, it will
%   be fast and easy to play with parameters (e.g. damage functions).
%
%   run as a batch code, such that all is available on command line, all
%   PARAMETERS are set in this file, see section below
%
% CALLING SEQUENCE:
%   peril_region='nio';selected_countries_region_peril % batch code
% EXAMPLE:
%   selected_countries_region_peril % a batch code
% INPUTS:
%   see PARAMETERS in this batch code
% OPTIONAL INPUT PARAMETERS:
% OUTPUTS:
%   produce a report (.csv, see PARAMETER damage_report_filename) and a
%   graph with regional (and annual) aggregate damage frequency curve, plus
%       comparison with (indexed) EM-DAT damages
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20150207, initial
%-

close all % as this one produces (too) many plots

global climada_global
if ~climada_init_vars,return;end % init/import global variables

dmf_info_str=''; % init

% PARAMETERS
%
% switches to run only parts of the code:
% ---------------------------------------
%
% whether we show the figures (=0 to produce and save figure without showing it)
show_plot=1; % default=1
%
% whether we are actually REPLACEing damagefunctions in entities, rather
% than just temporarily using them (code Stops after this)
REPLACE_damagefunctions=0; % default=0
damagefunctions=[]; % init, see below
%
% set parameters to get started (if called without setting any parameters)
if ~exist('peril_ID','var'),peril_ID='';end
if ~exist('peril_region','var'),peril_region='';end
if isempty(peril_ID),peril_ID='TC';end
if isempty(peril_region),peril_region='atl';end
% define the peril to treat. If ='', run TC, TS and TR (and also EQ and WS,
% but this does not take much time, see PARAMETERS section in
% centroids_generate_hazard_sets)
peril_ID='TC';peril_region='atl'; % default='TC' and 'wpa'
%peril_ID='TC';peril_region='wpa'; % default='TC' and 'wpa'
%peril_ID='TC';peril_region='she'; % default='TC' and 'wpa'
%peril_ID='TC';peril_region='nio'; % default='TC' and 'wpa'
%peril_ID='EQ';peril_region='glb'; % EQ global
%peril_ID='WS';peril_region='eur'; % WS europe
%
%climada_global.tc.default_raw_data_ext='.nc'; % to restrict to netCDF TC track files
climada_global.tc.default_raw_data_ext='.txt'; % to restrict to UNISYS TC track files
%
% parameters for country_risk_calc
% method=-3: default, using GDP_entity and probabilistic sets, see country_risk_calc
% method=3: FAST for checks, using GDP_entity and historic sets, see country_risk_calc
% method=-7: skip entity and hazard generation, probabilistic sets, see country_risk_calc
% method=-999: to force combination of TC and TS into TC (not calling country_risk_calc, all done in code below)
country_risk_calc_method=-7; % default=-3, using GDP_entity and probabilistic sets, see country_risk_calc
country_risk_calc_force_recalc=0; % default=0, see country_risk_calc
%
% whether we plot the DFC each country
country_DFC_plot=1; % default=1
country_DFC_plot_dir=[climada_global.data_dir filesep 'results' filesep 'damagefun_plots'];
%
% whether we run a damage function sensitivity check for each country
% if country_DFC_plot=1, it makes only limited sense to set this=1
country_DFC_sensitivity=0; % default=0
%
% whether we calculate admin1 level (you might not set this =1 for the full
% country list, i.e. first run all requested countries with
% calculate_admin1=0, then restrict the list and only run with
% calculate_admin1=1 for these (e.g. USA, CHN...)
calculate_admin1=0; % default=0
%
% where we store the .mat file with key results, set='' to omit
country_risk_results_mat_file=[climada_global.data_dir filesep 'results' filesep 'region_peril.mat'];
%
% where we store the results table, set='' to omit writing the report
damage_report_filename=[climada_global.data_dir filesep 'results' filesep 'region_peril_report.xls'];
%
% whether we plot all the global damage frequency curves
plot_global_DFC=1;
plot_max_RP=250; % the maxium RP we show (to zoom in a bit)
%
% the explicit list of countries we'd like to process
% see climada_country_name('ALL'); to obtain it.
switch [peril_region '_' peril_ID]
    
    case 'atl_TC'
        country_risk_calc_method=-999; % to force combination of TC and TS into TC (not calling country_risk_calc, all done in code below)
        %         country_list={ % the list of reasonable countries to calibrate atl TC
        %             'Anguilla'
        %             'Antigua and Barbuda'
        %             'Aruba'
        %             'Bahamas'
        %             'Barbados'
        %             'Belize'
        %             'Bermuda'
        %             'British Virgin Islands'
        %             'Cayman Islands'
        %%             'Colombia'
        %%             'Costa Rica'
        %             'Cuba'
        %             'Dominica'
        %%             'Dominican Republic'
        %             'El Salvador'
        %             'Grenada'
        %             'Guatemala'
        %             'Guyana'
        %             'Haiti'
        %             'Honduras'
        %             'Jamaica'
        %%             'Mexico'
        %             'Nicaragua'
        %%             'Panama'
        %             'Puerto Rico'
        %             'Saint Kitts and Nevis'
        %             'Saint Lucia'
        %             %'Saint Martin' % NOT supported in climada_create_GDP_entity
        %             'Saint Pierre and Miquelon'
        %             'Saint Vincent and the Grenadines'
        %             'Sao Tome and Principe'
        %             'Trinidad and Tobago'
        %             'Turks and Caicos Islands'
        %             'US Virgin Islands'
        %%             'United States'
        %             'Venezuela'
        %             };
        
        country_list={ % atl exposed from selected_countries_all_in_one
            'Colombia'
            'Costa Rica'
            'Dominican Republic'
            'Mexico'
            'Panama'
            'United States'
            };
        
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.05; % 8% growth in wpa-exposed countries (for sure more than the global average 2%)
        climada_global.global_CAGR=CAGR; % to pass it on the emdat_read
        %
        % the TC atl damage function
        %[damagefunctions,dmf_info_str]=climada_damagefunction_generate(1:5:120,20,1,1.0,'s-shape','TC',0); % until 20150212 noon
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(1:5:120,20,1,0.9,'s-shape','TC',0);
        
    case 'wpa_TC'
        country_risk_calc_method=-999; % to force combination of TC and TS into TC (not calling country_risk_calc, all done in code below)
        % the list of reasonable countries to calibrate wpa TC
        country_list={
            'Cambodia'
            'China'
            'Hong Kong'
            'Indonesia'
            'Japan'
            'Korea'
            'Laos'
            'Malaysia'
            'Micronesia'
            'Myanmar'
            'Philippines'
            'Singapore'
            'Taiwan'
            'Thailand'
            'Vietnam'
            };
        
        country_list={ % TC wpa exposed from selected_countries_all_in_one
            'Cambodia'
            'China'
            'Indonesia'
            'Japan'
            'Laos'
            'Myanmar'
            'Philippines'
            'Singapore'
            'Korea'
            'Taiwan'
            'Thailand'
            'Vietnam'
            };
        
        %         country_list={ % short lits for TESTS
        %             'Hong Kong'
        %             'Myanmar'
        %             'Philippines'
        %             'Singapore'
        %             'Taiwan'
        %             };
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.05; % 8% growth in wpa-exposed countries (for sure more than the global average 2%)
        climada_global.global_CAGR=CAGR; % to pass it on the emdat_read
        %
        % define the TEST damagefunctions
        %         damagefunctions.filename=mfilename;
        %         damagefunctions.Intensity=[0 20 30 40 50 60 70 80 100];
        %         damagefunctions.MDD=[0 0 0.0219 0.0359 0.0540 0.1035 0.1804 0.4108 0.4108];
        %         damagefunctions.PAA=[0 0.0050 0.0420 0.1600 0.3985 0.6570 1.0000 1.0000 1.0000];
        %         damagefunctions.DamageFunID=ones(1,length(damagefunctions.Intensity));
        %         damagefunctions.peril_ID=cellstr(repmat(peril_ID,length(damagefunctions.Intensity),1));
        %         % first CRUDE correction for wpa
        %         damagefunctions.MDD=damagefunctions.MDD/5;
        %         damagefunctions.PAA=damagefunctions.PAA/5;
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(1:5:120,15,1,1.0,'s-shape','TC',0);
        
    case 'she_TC'
        country_risk_calc_method=-999; % to force combination of TC and TS into TC (not calling country_risk_calc, all done in code below)
        
        country_list={ % TC she exposed from selected_countries_all_in_one
            'Australia'
            'Indonesia'
            'New Zealand'
            'South Africa'
            };
        
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.05; % 8% growth in wpa-exposed countries (for sure more than the global average 2%)
        climada_global.global_CAGR=CAGR; % to pass it on the emdat_read
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(1:5:120,20,1,1.0,'s-shape','TC',0); % 15 to 25
        
    case 'nio_TC'
        country_risk_calc_method=-999; % to force combination of TC and TS into TC (not calling country_risk_calc, all done in code below)
        
        country_list={ % nio exposed from selected_countries_all_in_one
            'Bangladesh'
            'India'
            'Pakistan'
            };
        
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.05; % 8% growth in wpa-exposed countries (for sure more than the global average 2%)
        climada_global.global_CAGR=CAGR; % to pass it on the emdat_read
        
        [damagefunctions,dmf_info_str]=climada_damagefunction_generate(1:5:120,15,2,1.0,'s-shape','TC',0); % 15 to 20
        
        
    case 'glb_EQ'
        country_list={
            'Cambodia'
            'China'
            'Hong Kong'
            'Indonesia'
            'Japan'
            'Korea'
            'Laos'
            'Malaysia'
            'Micronesia'
            'Myanmar'
            'Philippines'
            'Singapore'
            'Taiwan'
            'Thailand'
            'Vietnam'
            };
        
        country_list={ % EQ glb exposed from selected_countries_all_in_one
            'Algeria'
            'Australia'
            'Austria'
            'Bangladesh'
            'Brazil'
            'Canada'
            'Chile'
            'China'
            'Colombia'
            'Costa Rica'
            'Dominican Republic'
            'Ecuador'
            'France'
            'Germany'
            'Greece'
            'Hungary'
            'India'
            'Indonesia'
            'Israel'
            'Italy'
            'Japan'
            'Kenya'
            'Laos'
            'Mexico'
            'Morocco'
            'Myanmar'
            'Netherlands'
            'New Zealand'
            'Pakistan'
            'Panama'
            'Peru'
            'Philippines'
            'Portugal'
            'Slovenia'
            'South Africa'
            %'Switzerland' % no hazard set at the moment
            'Korea'
            'Spain'
            'Taiwan'
            'Thailand'
            'Turkey'
            'United Kingdom'
            'United States'
            'Vietnam'
            };
        
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.05; % 5% growth in wpa-exposed countries (for sure more than the global average 2%)
        climada_global.global_CAGR=CAGR; % to pass it on the emdat_read
        damagefunctions=[]; % use the default damagefunctions as in entities
        
    case 'eur_WS'
        % the list of reasonable countries to calibrate wpa TC
        country_list={
            'Austria'
            'Belgium'
            'Denmark'
            'France'
            'Germany'
            'Ireland'
            'Netherlands'
            'Norway'
            'Sweden'
            'Switzerland'
            'United Kingdom'
            };
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.04; % 4% growth in wpa-exposed countries (for sure more than the global average 2%)
        climada_global.global_CAGR=CAGR; % to pass it on the emdat_read
        damagefunctions=[]; % use the default damagefunctions as in entities
        
    otherwise
        fprintf('NOT implemented, aborted\n')
        return
end
%
% more technical parameters
climada_global.waitbar=0; % switch waitbar off (especially without Xwindows)
%
% the file with target damage frequency curves (DFCs), need to have columns
% country, peril_ID, return period and damage (TIV and GDP are read, if present)
% the matching country and peril DFC will be plotted for reference (i.e. to
% help calibrate climada to any given (other model) results
target_DFC_file=[climada_global.data_dir filesep 'results' filesep 'target_DFC.xls'];

if ~isempty(damagefunctions) && REPLACE_damagefunctions
    fprintf('replacing %s (DamageFunID=1) damage function in:\n',peril_ID)
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        fprintf('- %s %s\n',country_ISO3,country_name)
        entity_file=[climada_global.data_dir filesep 'entities' filesep ...
            country_ISO3 '_' strrep(country_name,' ','') '_entity.mat'];
        load(entity_file)
        entity=climada_damagefunctions_replace(entity,damagefunctions);
        save(entity_file,'entity');
    end % country_i
    fprintf('STOP after replacing damage functions (set damagefunctions=[])\n')
    return
end

% calculate damage on admin0 (country) level
if country_risk_calc_method==-7
    
    country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0,[peril_region  '_' peril_ID],damagefunctions);
    
elseif country_risk_calc_method==-999
    
    clear country_risk % since it's a batch code
    
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        
        fprintf('******** %s %s *****************\n',country_ISO3,country_name)
        
        country_risk(country_i).res.country_name = country_name;
        country_risk(country_i).res.country_ISO3 = country_ISO3;
        
        entity_file=[climada_global.data_dir filesep 'entities' filesep ...
            country_ISO3 '_' strrep(country_name,' ','') '_entity.mat'];
        
        if exist(entity_file,'file')
            load(entity_file) % contains entity
            
            if ~isempty(damagefunctions),entity.damagefunctions=damagefunctions;end
            
            next_hazard_i=1;
            hazard_TC_file=[climada_global.data_dir filesep 'hazards' filesep ...
                country_ISO3 '_' strrep(country_name,' ','') '_' peril_region '_' 'TC.mat'];
            if exist(hazard_TC_file,'file')
                country_risk(country_i).res.hazard(next_hazard_i).hazard_set_file=hazard_TC_file;
                load(hazard_TC_file); % contains hazard
                country_risk(country_i).res.hazard(next_hazard_i).EDS=climada_EDS_calc(entity,hazard);
                country_risk(country_i).res.hazard(next_hazard_i).peril_ID='TC';
                next_hazard_i=next_hazard_i+1;
            else
                fprintf('WARNING: %s %s TC hazard not found, skipped\n',country_ISO3,country_name)
            end
            
            load(entity_file) % contains entity, load again to get original damagefunctions
            hazard_TS_file=[climada_global.data_dir filesep 'hazards' filesep ...
                country_ISO3 '_' strrep(country_name,' ','') '_' peril_region '_' 'TS.mat'];
            if exist(hazard_TS_file,'file')
                country_risk(country_i).res.hazard(next_hazard_i).hazard_set_file=hazard_TS_file;
                load(hazard_TS_file); % contains hazard
                % hazard.peril_ID,unique(entity.damagefunctions.peril_ID) % to check
                country_risk(country_i).res.hazard(next_hazard_i).EDS=climada_EDS_calc(entity,hazard);
                country_risk(country_i).res.hazard(next_hazard_i).peril_ID='TS';
                next_hazard_i=next_hazard_i+1;
            else
                fprintf('WARNING: %s %s TS hazard not found, skipped\n',country_ISO3,country_name)
            end
            
        else
            fprintf('WARNING: %s %s entity not found, skipped\n',country_ISO3,country_name)
        end
        
    end % country_i
else
    country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0,peril_ID,damagefunctions);
end

if ~isempty(damagefunctions)
    % plot damagefunction
    if show_plot,fig_visible='on';else fig_visible='off';end
    dmf_fig = figure('Name','damage function','visible',fig_visible,'Color',[1 1 1],'Position',[430 20 920 650]);
    climada_damagefunctions_plot(damagefunctions)
    hold on;title(dmf_info_str)
    
    plot_dmf_png_name=[country_DFC_plot_dir filesep peril_ID '_' peril_region ...
        '_' strrep(strrep(dmf_info_str,'*','p'),' ','') '.png'];
    if ~exist(country_DFC_plot_dir,'dir'),mkdir(country_DFC_plot_dir);end
    if ~isempty(plot_dmf_png_name),saveas(dmf_fig,plot_dmf_png_name,'png');end
    if ~show_plot,delete(dmf_fig);end
end % ~isempty(damagefunctions)

% next line allows to combine sub-perils, such as wind (TC) and surge (TS)
% EDC is the maximally combined EDS, i.e. only one fully combined EDS per
% hazard and region, i.e. one EDS for all TC Atlantic damages summed up
% (per event), one for TC Pacific etc.
[country_risk,EDC]=country_risk_EDS_combine(country_risk); % combine TC and TS and calculate EDC

if ~isempty(country_risk_results_mat_file)
    fprintf('storing country_risk and EDC in %s\n',country_risk_results_mat_file);
    save(country_risk_results_mat_file,'country_risk','EDC')
end % country_risk_results_mat_file

if ~isempty(damage_report_filename)
    if calculate_admin1
        country_risk_report([country_risk country_risk1],1,damage_report_filename);
    else
        country_risk_report(country_risk,1,damage_report_filename);
    end
end % generate_damage_report


if plot_global_DFC
    
    % plot the DFCs of all EDSs
    if show_plot,fig_visible='on';else fig_visible='off';end
    DFC_fig = figure('Name','EDC','visible',fig_visible,'Color',[1 1 1],'Position',[430 20 920 650]);
    max_RP_damage=0; % init
    
    % plot the aggregate per event (PE) and annual aggregate (AA) damage
    % frequency curve for each basin as well as the total global aggregate
    
    PE_damage=[];PE_frequency=[]; % init
    legend_str={}; % init
    AA_damage=[];AA_frequency=[]; % init for annual aggregate
    plot_symboll={'-b','-g','-r','-c','-m','-y'}; % line
    plot_symbold={':b',':g',':r',':c',':m',':y'}; % dotted
    for EDC_i=1:length(EDC)
        % the per event perspective:
        PE_damage=[PE_damage EDC(EDC_i).EDS.damage]; % collect per event damage
        PE_frequency=[PE_frequency EDC(EDC_i).EDS.frequency]; % collect per event frequency
        DFC=climada_EDS2DFC(EDC(EDC_i).EDS);
        plot(DFC.return_period,DFC.damage,plot_symboll{EDC_i},'LineWidth',2);hold on
        legend_str{end+1}=strrep(EDC(EDC_i).EDS.comment,'_',' ');
        
        max_damage = interp1(DFC.return_period,DFC.damage,plot_max_RP); % interp to plot_max_RP
        max_RP_damage=max(max_RP_damage,max_damage);
        
        % and the annual aggregate perspective
        YDS=climada_EDS2YDS(EDC(EDC_i).EDS);
        if ~isempty(YDS)
            AA_damage=[AA_damage YDS.damage]; % collect AA damage
            AA_frequency=[AA_frequency YDS.frequency]; % collect AA frequency
            YFC=climada_EDS2DFC(YDS);
            plot(YFC.return_period,YFC.damage,plot_symbold{EDC_i},'LineWidth',2);hold on
            legend_str{end+1}=[strrep(EDC(EDC_i).EDS.comment,'_',' ') ' annual aggregate'];
            
            max_damage = interp1(YFC.return_period,YFC.damage,plot_max_RP); % interp to plot_max_RP
            max_RP_damage=max(max_RP_damage,max_damage);
        end
    end % EDC_i
    
    % the per event perspective:
    [sorted_damage,exceedence_freq]=climada_damage_exceedence(PE_damage',PE_frequency);
    nonzero_pos      = find(exceedence_freq);
    agg_PE_damage       = sorted_damage(nonzero_pos);
    exceedence_freq  = exceedence_freq(nonzero_pos);
    agg_PE_return_period    = 1./exceedence_freq;
    plot(agg_PE_return_period,agg_PE_damage,'-k','LineWidth',2);
    legend_str{end+1}='full global aggregate';
    
    max_damage = interp1(agg_PE_return_period,agg_PE_damage,plot_max_RP); % interp to plot_max_RP
    max_RP_damage=max(max_RP_damage,max_damage);
    
    if ~isempty(AA_damage)
        % the AA perspective:
        [sorted_damage,exceedence_freq]=climada_damage_exceedence(AA_damage',AA_frequency);
        nonzero_pos      = find(exceedence_freq);
        agg_AA_damage       = sorted_damage(nonzero_pos);
        exceedence_freq  = exceedence_freq(nonzero_pos);
        agg_AA_return_period    = 1./exceedence_freq;
        plot(agg_AA_return_period,agg_AA_damage,':k','LineWidth',2);
        legend_str{end+1}='full global annual aggregate';
        
        max_damage = interp1(agg_AA_return_period,agg_AA_damage,plot_max_RP); % interp to plot_max_RP
        max_RP_damage=max(max_RP_damage,max_damage);
        
    end
    
    em_data=emdat_read('',country_list,peril_ID,1,1,CAGR);
    if ~isempty(em_data)
        plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og'); hold on
        legend_str{end+1}='EM-DAT';
        
        plot(em_data.DFC.return_period,em_data.DFC.damage,'xg'); hold on
        legend_str{end+1}='EM-DAT indexed';
        
        max_RP_damage=max(max_RP_damage,max(em_data.DFC.damage));
        
        em_data.YDS.DFC=climada_EDS2DFC(em_data.YDS);
        plot(em_data.YDS.DFC.return_period,em_data.YDS.DFC.damage,'sg'); hold on
        legend_str{end+1}=em_data.YDS.DFC.annotation_name;
        
        max_RP_damage=max(max_RP_damage,max(em_data.YDS.DFC.damage));
        
    end
    
    legend(legend_str);title([peril_ID ' ' peril_region ' global aggregate'])
    
    % zoom to 0..plot_max_RP years return period
    axis([0 plot_max_RP 0 max_RP_damage]);
    
    aggregate_DFC_plot_name=[country_DFC_plot_dir filesep peril_ID '_' peril_region '_aggregate.png'];
    if ~exist(country_DFC_plot_dir,'dir'),mkdir(country_DFC_plot_dir);end
    if ~isempty(aggregate_DFC_plot_name),saveas(DFC_fig,aggregate_DFC_plot_name,'png');end
    if ~show_plot,delete(DFC_fig);end
    
end % plot_global_DFC

if country_DFC_plot
    
    n_entities=length(country_risk);
    
    for entity_i=1:n_entities
        if show_plot,fig_visible='on';else fig_visible='off';end
        fprintf('%s (%i)\n',country_risk(entity_i).res.country_name,entity_i);
        
        if isfield(country_risk(entity_i).res,'hazard') % country exposed
            
            n_hazards=length(country_risk(entity_i).res.hazard);
            for hazard_i=1:n_hazards
                if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                    
                    country_name=country_risk(entity_i).res.country_name;
                    country_ISO3=country_risk(entity_i).res.country_ISO3;
                    
                    peril_ID=country_risk(entity_i).res.hazard(hazard_i).EDS.peril_ID;
                    DFC=climada_EDS2DFC(country_risk(entity_i).res.hazard(hazard_i).EDS);
                    
                    DFC_plot = figure('visible',fig_visible,'Color',[1 1 1],'Position',[430 20 920 650]);
                    legend_str={};max_RP_damage=0; % init
                    
                    plot(DFC.return_period,DFC.damage,'-b','LineWidth',2);hold on
                    max_damage   =interp1(DFC.return_period,DFC.damage,plot_max_RP); % interp to plot_max_RP
                    max_RP_damage=max(max_RP_damage,max_damage);
                    legend_str{end+1}=country_name;
                    
                    % add EM-DAT
                    em_data=emdat_read('',country_name,peril_ID,1,1);
                    if ~isempty(em_data)
                        [adj_EDS,climada2emdat_factor_weighted] = climada_EDS_emdat_adjust(country_risk(entity_i).res.hazard(hazard_i).EDS);
                        if abs(climada2emdat_factor_weighted-1)>10*eps
                            adj_DFC=climada_EDS2DFC(adj_EDS);
                            plot(adj_DFC.return_period,adj_DFC.damage,':b','LineWidth',1);
                            legend_str{end+1}='EM-DAT adjusted';
                        end
                        
                        plot(em_data.DFC.return_period,em_data.DFC.damage,'dg');
                        legend_str{end+1} = em_data.DFC.annotation_name;
                        plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og');
                        legend_str{end+1} = em_data.DFC_orig.annotation_name;
                        max_RP_damage=max(max_RP_damage,max(em_data.DFC.damage));
                    end % em_data
                    
                    % add cmp results in case they exist
                    cmp_DFC_file=[climada_global.data_dir filesep 'results' filesep 'cmp_results' ...
                        filesep peril_ID filesep country_ISO3 '_' ...
                        strrep(country_name,' ','') '_' ...
                        peril_region '_' peril_ID '_cmp_results.xlsx'];
                    
                    if exist(cmp_DFC_file,'file')
                        fprintf('cmp: %s\n',cmp_DFC_file);
                        DFC_cmp=climada_DFC_read(cmp_DFC_file);
                        if ~isempty(DFC_cmp)
                            hold on
                            plot(DFC_cmp.return_period,DFC_cmp.damage,'-k','LineWidth',2);
                            max_damage   =interp1(DFC_cmp.return_period,DFC_cmp.damage,plot_max_RP); % interp to plot_max_RP
                            max_RP_damage=max(max_RP_damage,max_damage);
                            legend_str{end+1} = 'cmp';
                        end
                    end
                    
                    if exist(target_DFC_file,'file') && isfield(entity.assets,'admin0_name')
                        try
                            target_DFC=climada_spreadsheet_read('no',target_DFC_file,'target_DFC',1);
                            country_pos=strmatch(country_name,target_DFC.country_name);
                            peril_pos=strmatch(peril_ID,target_DFC.peril_ID(country_pos));
                            country_pos=country_pos(peril_pos);
                            if ~isempty(country_pos)
                                plot(target_DFC.return_period(country_pos),target_DFC.damage(country_pos),':k','LineWidth',2)
                                max_damage   =interp1(target_DFC.return_period(country_pos),target_DFC.damage(country_pos),plot_max_RP); % interp to plot_max_RP
                                max_RP_damage=max(max_RP_damage,max_damage);
                                legend_str{end+1} = 'target';
                            end
                        catch
                            fprintf('Warning: troubles reading/processing %s\n',target_DFC_file);
                        end
                    end
                    
                    axis([0 plot_max_RP 0 max_RP_damage]);
                    
                    legend(legend_str,'Location','NorthWest'); % show legend
                    title([peril_ID ' ' peril_region ' ' country_ISO3 ' ' country_name]);
                    
                    country_DFC_plot_name=[country_DFC_plot_dir filesep peril_ID '_' ...
                        peril_region '_' country_ISO3 '_' strrep(country_name,' ','') '_check.png'];
                    if ~exist(country_DFC_plot_dir,'dir'),mkdir(country_DFC_plot_dir);end
                    if ~isempty(country_DFC_plot_name),saveas(DFC_plot,country_DFC_plot_name,'png');end
                    if ~show_plot,delete(DFC_plot);end
                    
                end % ~isempty(EDS)
            end % hazard_i
            
        end % country exposed
        
    end % entity_i
    
end % country_DFC_plot

if country_DFC_sensitivity
    
    probabilistic=0;if country_risk_calc_method<0,probabilistic=1;end
    
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        fprintf('%s: %s %s\n',country_list{country_i},country_name,country_ISO3);
        
        cr_country_DFC_sensitivity(country_ISO3,1,probabilistic,damagefunctions,peril_ID,peril_region);
        
    end % country_i
end % country_DFC_sensitivity
