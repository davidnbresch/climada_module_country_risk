% [x,y] = ginput(4)
% [x,y] = gline(3)
function polygon = climada_define_polygon

% define a polygon within an open figure
% NAME:
%   climada_define_polygon
% PURPOSE:
%   Define a polygon within a figure, specifically used within
%   climada_cut_out_global_portfolio
% CALLING SEQUENCE:
%   polygon = climada_define_polygon
% EXAMPLE:
%   polygon = climada_define_polygon
% INPUTS:
%   none
% OUTPUTS:
%   polygon with poylgon(:,1) longitude and polygon(:2) latitude
% MODIFICATION HISTORY:
% Lea Mueller, 20130412
%-


cprintf([255 165 0 ]/255,'Please define your region with mouse clicks on the graph.\n Quit with right mouse click.\n')

n       = 0;
but     = 1;
polygon = [];

while but == 1
    [xi,yi,but] = ginput(1);
    n = n+1;
    polygon(n,:) = [xi yi];
    plot(polygon(:,1),polygon(:,2),'-ro')
end

