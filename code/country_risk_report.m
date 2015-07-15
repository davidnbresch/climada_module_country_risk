function country_risk_report(country_risk,print_format,report_filename,plot_DFC)
% climada
% MODULE:
%   country_risk
% NAME:
%   country_risk_report
% PURPOSE:
%   produce a report (country, peril, damage) based on the results from
%   country_risk_calc and country_admin1_risk_calc
%
%   previous call: country_risk_calc and/or country_admin1_risk_calc
%   see also: country_risk_report_raw for a raw report (to stdout)
% CALLING SEQUENCE:
%   country_risk_report(country_risk,print_format,report_filename,plot_DFC)
% EXAMPLE:
%   country_risk_report(country_risk_calc('Barbados')); % all in one
%
%   country_risk0=country_risk_calc('Switzerland'); % country, admin0 level
%   country_risk1=country_admin1_risk_calc('Switzerland'); % admin1 level
%   country_risk_report([country_risk0 country_risk1]) % report all
% INPUTS:
%   country_risk: a structure with the results from country_risk_calc
% OPTIONAL INPUT PARAMETERS:
%   print_format: =1, report damages in the order they have been calculated
%       =2 show by descending damages (default)
%       if negative, omit reporting all to stdout
%       =0, call country_risk_report_raw (one line with ED per country)
%   report_filename: the filename of the Excel file the report is written
%       to. Prompted for if not given (if Cancel pressed, write to stdout only)
%   plot_DFC: if =1, plot damage frequency curves (DFC) of all EDSs (!) in
%       country_risk, =0 not (default)
%       if =2, plot logarithmic scale both axes
% OUTPUTS:
% MODIFICATION HISTORY:
% David N. Bresch, david.bresch@gmail.com, 20141209, initial
% David N. Bresch, david.bresch@gmail.com, 20141211, header added to Excel report
% David N. Bresch, david.bresch@gmail.com, 20150715, bug fix for empty EDS (e.g. if combine EDS is called prior to report)
% David N. Bresch, david.bresch@gmail.com, 20150715, empty EDS not reported any more
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables

%%if climada_global.verbose_mode,fprintf('*** %s ***\n',mfilename);end % show routine name on stdout

% poor man's version to check arguments
if ~exist('country_risk','var'),return;end
if ~exist('print_format','var'),print_format=1;end
if ~exist('report_filename','var'),report_filename='';end
if ~exist('plot_DFC','var'),plot_DFC=0;end

% PARAMETERS
%
% define the return periods we report damage for
% set =[] to report expected damage (ED) only
% (note that the ED will be denoted as return period=0 in the report)
DFC_return_periods=[100 250]; % [100 250]
%
%climada_global.csv_delimiter=','; % to locally adjust delimiter (not recommended ;-)

if print_format==0 % backward compatibility
    country_risk_report_raw(country_risk,0,plot_DFC);
    return
end

% prompt for report_filename if not given
if isempty(report_filename) % local GUI
    report_filename=[climada_global.data_dir filesep 'results' filesep 'country_risk_report.xls'];
    [filename, pathname] = uiputfile(report_filename, 'Save report as:');
    if isequal(filename,0) || isequal(pathname,0)
        report_filename=''; % cancel
    else
        report_filename=fullfile(pathname,filename);
    end
end

n_entities=length(country_risk);

next_res=1;

% prepare header and print format
header_str='admin0(country);ISO3;admin1(state/province);admin1_code;value;peril;return_period;damage;damage/value\n';
format_str='%s;%s;%s;%s;%g;%s;%i;%g;%f\n';
header_str=strrep(header_str,';',climada_global.csv_delimiter);
format_str=strrep(format_str,';',climada_global.csv_delimiter);

if ~isempty(DFC_return_periods),DFC_exceedence_freq = 1./DFC_return_periods;end

% collect results

for entity_i=1:n_entities
    
    if isfield(country_risk(entity_i).res,'hazard') % country exposed
        
        n_hazards=length(country_risk(entity_i).res.hazard);
        for hazard_i=1:n_hazards
            
            res(next_res).country_name=country_risk(entity_i).res.country_name;
            res(next_res).country_ISO3=country_risk(entity_i).res.country_ISO3;
            
            if isfield(country_risk(entity_i).res.hazard(hazard_i),'admin1_name')
                res(next_res).admin1_name=country_risk(entity_i).res.hazard(hazard_i).admin1_name;
                res(next_res).admin1_code=country_risk(entity_i).res.hazard(hazard_i).admin1_code; % does also exist
            else
                res(next_res).admin1_name='';
                res(next_res).admin1_code='';
            end
            
            if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                
                res(next_res).Value   =country_risk(entity_i).res.hazard(hazard_i).EDS.Value;
                res(next_res).peril_ID=country_risk(entity_i).res.hazard(hazard_i).EDS.hazard.peril_ID;

                ED(next_res)=country_risk(entity_i).res.hazard(hazard_i).EDS.ED; % we need for sort later
                res(next_res).return_period=0;
                res(next_res).damage=ED(next_res);
                res(next_res).damage_oL=country_risk(entity_i).res.hazard(hazard_i).EDS.ED/...
                    country_risk(entity_i).res.hazard(hazard_i).EDS.Value;
                res(next_res).annotation_name=country_risk(entity_i).res.hazard(hazard_i).EDS.annotation_name;
                
                if ~isempty(DFC_return_periods)
                    % calculate a few points on DFC
                    [sorted_damage,exceedence_freq] = climada_damage_exceedence(...
                        country_risk(entity_i).res.hazard(hazard_i).EDS.damage,...
                        country_risk(entity_i).res.hazard(hazard_i).EDS.frequency);
                    
                    nonzero_pos     = find(exceedence_freq);
                    sorted_damage   = sorted_damage(nonzero_pos);
                    exceedence_freq = exceedence_freq(nonzero_pos);
                    
                    RP_damage       = interp1(exceedence_freq,sorted_damage,DFC_exceedence_freq);
                    
                    for RP_i=1:length(RP_damage)
                        res(next_res+1)=res(next_res); % copy
                        ED(next_res+1)=ED(next_res); % copy
                        next_res=next_res+1;
                        res(next_res).return_period=DFC_return_periods(RP_i);
                        res(next_res).damage=RP_damage(RP_i);
                        res(next_res).damage_oL=RP_damage(RP_i)/...
                            country_risk(entity_i).res.hazard(hazard_i).EDS.Value;
                    end % RP_i
                end % ~isempty(DFC_return_periods)
                next_res=next_res+1;

            else
%                 % do not write empty results any more (since 20150715)
%                 ED(next_res)          =0;
%                 res(next_res).ED      =0;
%                 res(next_res).EDoL    =0;
%                 res(next_res).Value   =0;
%                 try
%                     % backward compatibility
%                     res(next_res).peril_ID=country_risk(entity_i).res.hazard(hazard_i).peril_ID;
%                 catch
%                     res(next_res).peril_ID='';
%                 end
%                 res(next_res).annotation_name='EMPTY';
%                 res(next_res).admin1_name='';
%                 next_res=next_res+1;
            end % ~isempty(EDS)
            
        end % hazard_i
        
    end % country exposed
    
end % entity_i

% print results table

if abs(print_format)==2
    [~,ED_index] = sort(ED); % sort expected damage (ED)
else
    ED_index=length(ED):-1:1; % unsorted
end

if print_format>0,fprintf(header_str);end

for ED_i=length(ED_index):-1:1 % to sort descending
    
    % print to stdout
    
    if print_format>0
        fprintf(format_str,...
            res(ED_index(ED_i)).country_name,...
            res(ED_index(ED_i)).country_ISO3,...
            res(ED_index(ED_i)).admin1_name,...
            res(ED_index(ED_i)).admin1_code,...
            res(ED_index(ED_i)).Value,...
            res(ED_index(ED_i)).peril_ID,...
            res(ED_index(ED_i)).return_period,...
            res(ED_index(ED_i)).damage,...
            res(ED_index(ED_i)).damage_oL);
        % programmers note: edit below, too
    end
    
    % fill the table to write to the Excel file
    excel_data{length(ED_index)-ED_i+1,1}=res(ED_index(ED_i)).country_name;
    excel_data{length(ED_index)-ED_i+1,2}=res(ED_index(ED_i)).country_ISO3;
    excel_data{length(ED_index)-ED_i+1,3}=res(ED_index(ED_i)).admin1_name;
    excel_data{length(ED_index)-ED_i+1,4}=res(ED_index(ED_i)).admin1_code;
    excel_data{length(ED_index)-ED_i+1,5}=res(ED_index(ED_i)).Value;
    excel_data{length(ED_index)-ED_i+1,6}=res(ED_index(ED_i)).peril_ID;
    excel_data{length(ED_index)-ED_i+1,7}=res(ED_index(ED_i)).return_period;
    excel_data{length(ED_index)-ED_i+1,8}=res(ED_index(ED_i)).damage;
    excel_data{length(ED_index)-ED_i+1,9}=res(ED_index(ED_i)).damage_oL;
    
end % ED_i

if ~isempty(report_filename)
    
    % try writing Excel file
    if climada_global.octave_mode
        STATUS=xlswrite(report_filename,...
            {'admin0(country)','ISO3','admin1(state/province)','admin1_code','value','peril','return_period','damage','damage/value'});
        MESSAGE='Octave';
    else
        [STATUS,MESSAGE]=xlswrite(report_filename,...
            {'admin0(country)','ISO3','admin1(state/province)','admin1_code','value','peril','return_period','damage','damage/value'});
    end
    
    if ~STATUS || strcmp(MESSAGE.identifier,'MATLAB:xlswrite:NoCOMServer') % xlswrite failed, write .csv instead
        %MESSAGE.message % for debugging
        %MESSAGE.identifier % for debugging
        [fP,fN]=fileparts(report_filename);
        report_filename=[fP filesep fN '.csv'];
        fid=fopen(report_filename,'w');
        fprintf(fid,header_str);
        for ED_i=length(ED_index):-1:1
            fprintf(fid,format_str,...
                res(ED_index(ED_i)).country_name,...
                res(ED_index(ED_i)).country_ISO3,...
                res(ED_index(ED_i)).admin1_name,...
                res(ED_index(ED_i)).admin1_code,...
                res(ED_index(ED_i)).Value,...
                res(ED_index(ED_i)).peril_ID,...
                res(ED_index(ED_i)).return_period,...
                res(ED_index(ED_i)).damage,...
                res(ED_index(ED_i)).damage_oL);
        end % ED_i
        fclose(fid);
        fprintf('Excel failed, .csv report written to %s\n',report_filename);
    else
        [STATUS,MESSAGE]=xlswrite(report_filename,excel_data, 1,'A2'); %A2 not to overwrite header
        fprintf('report written to %s\n',report_filename);
    end
end

if plot_DFC
    
    % rearrange all EDSs to pass on to climada_EDS_DFC
    EDS_i=1;
    for entity_i=1:n_entities
        if isfield(country_risk(entity_i).res,'hazard') % country exposed
            n_hazards=length(country_risk(entity_i).res.hazard);
            for hazard_i=1:n_hazards
                if ~isempty(country_risk(entity_i).res.hazard(hazard_i).EDS)
                    EDS(EDS_i)=country_risk(entity_i).res.hazard(hazard_i).EDS;
                    EDS_i=EDS_i+1;
                end
            end % hazard_i
        end
    end % entity_i
    
    plot_loglog=0;if plot_DFC==2,plot_loglog=1;end
    climada_EDS_DFC(EDS,'',0,plot_loglog);
end

return
