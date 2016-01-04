function [values_out, pp] = climada_nightlight_nonlinear_transformation(values_in, pp, check_figure, check_printplot)

% transform night light intensity values (between 1 and 63) nonlinearly 
% into distributed GDP assets (based on relationship between night lights
% and asset distribution), use a second order polynomial without y-indent,
% e.g. y = pp(1)*x^2 + pp(2)*x;
% NAME:
%   climada_nightlight2GDP
% PURPOSE:
%   nonlinearly transform night light with second order polynomial
%   this function is used within climada_GDP_distribute
% CALLING SEQUENCE:
%   [values_out pp] = climada_nightlight2GDP(values_in, pp, check_figure)
% EXAMPLE:
%   [values_out pp] = climada_nightlight2GDP(values_in, pp)
% INPUTS:
%   values_in   : original night light values (matrix) (values between
%                 1 and 63)
%   pp          : parameters of second order polynomial function, 
%                 y = pp(2)*x^2 + pp(1)*x
% OPTIONAL INPUT PARAMETERS:
%   check_figure   : set to 1 to show figure distributed GDP
%   check_printplot: set to 1 to save figure
% OUTPUTS:
%   values_out  : transformed night light values
%   pp          : parameters of second order polynomial function
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20120813
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables
if ~exist('values_in'      , 'var'), values_in       = []; end
if ~exist('pp'             , 'var'), pp              = []; end
if ~exist('check_figure'   , 'var'), check_figure    = []; end
if ~exist('check_printplot', 'var'), check_printplot = []; end

% set modul data directory
modul_data_dir = [fileparts(fileparts(mfilename('fullpath'))) filesep 'data'];

if isempty(pp), 
    try
        %load([climada_global.modules_dir{dir_index} filesep 'night_light_vs_prtf_assets_poly_forth_order'])
        %pp = pp{4}; %all regions combined
        
        %%load([climada_global.modules_dir{dir_index} filesep 'night_light_vs_prtf_assets_poly_second_order'])
        %%pp = pp{3}; %new orleans
        
        %load([climada_global.modules_dir{dir_index} filesep 'night_light_vs_prtf_assets_poly_second_order_without_y'])
        %pp = pp{4}; %all regions combined
        
        % second order polynom based on 28 km resolution of assets (US
        % Market Portfolio)
        load([modul_data_dir filesep 'night_light_vs_prtf_assets_28km'])
    catch
        fprintf('\t No polynomal function found\n')
        pp            = [0 1 0];
        %tot_assets_pp = 1;
    end
end

nl_max_stretched = polyval(pp,1:63);
pp               = pp/max(nl_max_stretched)*63;

values_out       = polyval(pp,values_in);
values_out(values_out<0) = 0;

% values_out    = polyval(pp,values_in)/tot_assets_pp;
% values_out = quad_a*values_in + quad_b*values_in.^2;

if check_figure
    fig = climada_figuresize(0.4,0.6);
    nl  = min(values_in(:)):1:max(values_in(:));
    plot(nl,nl,':k')
    hold on
    plot(nl,polyval(pp,nl),'.-')
    %plot(nl,quad_a*nl + quad_b*nl.^2,'.-')
    % axis equal
    legend('linear','second order polynomial function','location','nw')
    ylabel('Nonlinear transformed night light values (-)')
    xlabel('Original night light values (-)')  
    pp_str = 'y = ';
    for i = length(pp):-1:1
        pp_str = sprintf('%s %0.4f*x^%d +',pp_str,pp(i), length(pp) - (i));
    end
    pp_str(end-1:end) = [];
    titlestr = sprintf('Nonlinear tranformation of night lights with polynomial function\n %s',pp_str);
    title(titlestr)

    if check_printplot %(>=1) 
        pp_str_ = strrep(strrep(strrep(strrep(strrep(strrep(pp_str,' ',''),'^',''),'0.',''),'+','_'),'*',''),'.','');
        pp_str_(1:2) = []; 
        foldername = [filesep 'results' filesep 'Polynom_function_night_light_' pp_str_ '.pdf'];
        print(fig,'-dpdf',[climada_global.data_dir foldername])
        %close
        cprintf([255 127 36 ]/255,'\t\t saved 1 FIGURE in folder ..%s \n', foldername);
       
    end
end



end

