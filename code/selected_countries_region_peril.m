% selected_countries_region_peril
% climada batch code
% MODULE:
%   country_risk
% NAME:
%   selected_countries_region_peril
% PURPOSE:
%   Run all countries for a given region and hazard in order to e.g. adjust
%   damage functions for this peril and region. On first call, you might
%   have to set peril_region='' in order to generate all hazard event sets
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
%   selected_countries_region_peril % a batch code
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

global climada_global
if ~climada_init_vars,return;end % init/import global variables

% PARAMETERS
%
% switches to run only parts of the code:
% ---------------------------------------
%
% define the peril to treat. If ='', run TC, TS and TR (and also EQ and WS,
% but this does not take much time, see PARAMETERS section in
% centroids_generate_hazard_sets)
%peril_ID='TC';peril_region='wpa_'; % default='TC' and 'wpa_'
peril_ID='TC';peril_region='atl_'; % default='TC' and 'wpa_'
%peril_ID='EQ';peril_region='glb_'; % EQ global
%peril_ID='WS';peril_region='eur_'; % WS europe
%
%climada_global.tc.default_raw_data_ext='.nc'; % to restrict to netCDF TC track files
climada_global.tc.default_raw_data_ext='.txt'; % to restrict to UNISYS TC track files
%
% parameters for country_risk_calc
% method=-3: default, using GDP_entity and probabilistic sets, see country_risk_calc
% method=3: FAST for checks, using GDP_entity and historic sets, see country_risk_calc
% method=-7: skip entity and hazard generation, probabilistic sets, see country_risk_calc
country_risk_calc_method=-7; % default=-3, using GDP_entity and probabilistic sets, see country_risk_calc
country_risk_calc_force_recalc=0; % default=0, see country_risk_calc
%
% whether we check for each country
country_DFC_sensitivity=1;
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
plot_max_RP=500; % the maxium RP we show (to zoom in a bit)
%
% the explicit list of countires we'd like to process
% see climada_country_name('ALL'); to obtain it. The ones either not TC
% exposed or otherwise not needed are just commented out
%
% only wpa (West Pacific Ocean)
switch [peril_region peril_ID]
    case 'wpa_TC'
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
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.08; % 8% growth in wpa-exposed countries (for sure more than the global average 2%)
    case 'atl_TC'
        % the list of reasonable countries to calibrate wpa TC
        country_list={
            'Anguilla'
            'Antigua and Barbuda'
            'Aruba'
            'Bahamas'
            'Barbados'
            'Belize'
            'Bermuda'
            'British Virgin Islands'
            'Cayman Islands'
            'Colombia'
            'Costa Rica'
            'Cuba'
            'Dominica'
            'Dominican Republic'
            'El Salvador'
            'Grenada'
            'Guatemala'
            'Guyana'
            'Haiti'
            'Honduras'
            'Jamaica'
            'Mexico'
            'Nicaragua'
            'Panama'
            'Puerto Rico'
            'Saint Kitts and Nevis'
            'Saint Lucia'
            %'Saint Martin' % NOT supported in climada_create_GDP_entity
            'Saint Pierre and Miquelon'
            'Saint Vincent and the Grenadines'
            'Sao Tome and Principe'
            'Trinidad and Tobago'
            'Turks and Caicos Islands'
            'US Virgin Islands'
            'United States'
            'Venezuela'
            };
        
        % short for tests
        country_list={
            'Barbados'
            'Cayman Islands'
            'Dominican Republic'
%             'El Salvador'
%             'Guatemala'
%             'Jamaica'
%             'Nicaragua'
%             'Puerto Rico'
%             'Saint Lucia'
%             'United States'
            };
        
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.08; % 8% growth in wpa-exposed countries (for sure more than the global average 2%)
    case 'glb_EQ'
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
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.08; % 7% growth in wpa-exposed countries (for sure more than the global average 2%)
    case 'eur_WS'
        % the list of reasonable countries to calibrate wpa TC
        country_list={
            'France'
            'Germany'
            'United Kingdom'
            'Netherlands'
            };
        % the compound annual growth rate to inflate historic EM-DAT damages with
        CAGR=0.04; % 4% growth in wpa-exposed countries (for sure more than the global average 2%)
        
    otherwise
        fprintf('NOT implemented, aborted\n')
        return
end
%
% more technical parameters
climada_global.waitbar=0; % switch waitbar off (especially without Xwindows)

% calculate damage on admin0 (country) level
country_risk=country_risk_calc(country_list,country_risk_calc_method,country_risk_calc_force_recalc,0,[peril_region  peril_ID]);

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
    
    % plot the aggregate per event (PE) and annual aggregate (AA) damage
    % frequency curve for each basin as well as the total global aggregate
    
    PE_damage=[];PE_frequency=[]; % init
    legend_str={}; % init
    AA_damage=[];AA_frequency=[]; % init for annual aggregate
    plot_symboll={'-b','-g','-r','-c','-m','-y'}; % line
    plot_symbold={':b',':g',':r',':c',':m',':y'}; % dotted
    figure('Name','EDC','Color',[1 1 1]);
    for EDC_i=1:length(EDC)
        % the per event perspective:
        PE_damage=[PE_damage EDC(EDC_i).EDS.damage]; % collect per event damage
        PE_frequency=[PE_frequency EDC(EDC_i).EDS.frequency]; % collect per event frequency
        DFC=climada_EDS2DFC(EDC(EDC_i).EDS);
        plot(DFC.return_period,DFC.damage,plot_symboll{EDC_i},'LineWidth',2);hold on
        legend_str{end+1}=strrep(EDC(EDC_i).EDS.comment,'_',' ');
        % and the annual aggregate perspective
        YDS=climada_EDS2YDS(EDC(EDC_i).EDS);
        if ~isempty(YDS)
            AA_damage=[AA_damage YDS.damage]; % collect AA damage
            AA_frequency=[AA_frequency YDS.frequency]; % collect AA frequency
            YFC=climada_EDS2DFC(YDS);
            plot(YFC.return_period,YFC.damage,plot_symbold{EDC_i},'LineWidth',2);hold on
            legend_str{end+1}=[strrep(EDC(EDC_i).EDS.comment,'_',' ') ' annual aggregate'];
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
    
    if ~isempty(AA_damage)
        % the AA perspective:
        [sorted_damage,exceedence_freq]=climada_damage_exceedence(AA_damage',AA_frequency);
        nonzero_pos      = find(exceedence_freq);
        agg_AA_damage       = sorted_damage(nonzero_pos);
        exceedence_freq  = exceedence_freq(nonzero_pos);
        agg_AA_return_period    = 1./exceedence_freq;
        plot(agg_AA_return_period,agg_AA_damage,':k','LineWidth',2);
        legend_str{end+1}='full global annual aggregate';
    end
    
    em_data=emdat_read('',country_list,peril_ID,1,1,CAGR);
    
    plot(em_data.DFC.return_period,em_data.DFC_orig.damage,'og'); hold on
    legend_str{end+1}='EM-DAT';
    plot(em_data.DFC.return_period,em_data.DFC.damage,'xg'); hold on
    legend_str{end+1}='EM-DAT indexed';
    
    em_data.YDS.DFC=climada_EDS2DFC(em_data.YDS);
    plot(em_data.YDS.DFC.return_period,em_data.YDS.DFC.damage,'sg'); hold on
    legend_str{end+1}=em_data.YDS.DFC.annotation_name;
    
    legend(legend_str);title([peril_ID ' global aggregate'])
    % zoom to 0..plot_max_RP years return period
    YLim = get(get(gcf,'CurrentAxes'),'YLim');
    axis([0 plot_max_RP 0 YLim(2)]);
    
end % plot_global_DFC

if country_DFC_sensitivity
    
    probabilistic=0;if country_risk_calc_method>0,probabilistic=1;end
    
    for country_i=1:length(country_list)
        [country_name,country_ISO3,shape_index] = climada_country_name(country_list{country_i});
        fprintf('%s: %s %s\n',country_list{country_i},country_name,country_ISO3);
        
        cr_country_DFC_sensitivity(country_ISO3,1,probabilistic,[],peril_ID,strrep(peril_region,'_',''));
        %cr_country_DFC_sensitivity(country_ISO3,1,probabilistic,damagefunctions,strrep(peril_region,'_',''));
        
    end % country_i
end % country_DFC_sensitivity

