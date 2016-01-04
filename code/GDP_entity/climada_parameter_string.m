function pp_str = climada_parameter_string(pp)

% create parameter string from parameters
% NAME:
%   climada_parameter_string
% PURPOSE:
%   create parameter string from parameters
% CALLING SEQUENCE:
%   pp_str = climada_parameter_string(pp)
% EXAMPLE:
%   pp_str = climada_parameter_string
% INPUTS:
%   pp
% OUTPUTS:
%   pp_str
% MODIFICATION HISTORY:
% Lea Mueller, muellele@gmail.com, 20141017
%-

global climada_global
if ~climada_init_vars,return;end % init/import global variables
if ~exist('pp'       , 'var'), pp        = []; end

%init
pp_str  = '';

if isempty(pp), return, end

pp_str = 'y = ';
for i = length(pp):-1:1
    if pp(i)~=0
        if  ~strcmp(pp_str,'y = ')
            pp_str = [pp_str ' +'];
        end
        pp_str = sprintf('%s %0.4f*x^%d',pp_str,pp(i), length(pp)-(i));
    end
end
if ~isempty(pp)
    pp_str_      = strrep(strrep(strrep(strrep(strrep(strrep(pp_str,' ',''),'^',''),'0.',''),'+','_'),'*',''),'.','');
    pp_str_(1:2) = []; 
else
    %pp_str_ = 'unknown';
    pp_str_ = '';
end
    
    
    
