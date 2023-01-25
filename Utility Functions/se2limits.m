% This script computes the translation and rotation heatmap limits for an
% SE(2) system based on the heatmap sweeps provided in x, y, and theta
% direction.
function [tL,rL] = se2limits(xS,yS,thetaS)

% Compute the limits in each direction
x_lim = [min(xS,[],'all') max(xS,[],'all')]; 
y_lim = [min(yS,[],'all') max(yS,[],'all')];
theta_lim = [min(thetaS,[],'all') max(thetaS,[],'all')];
% Get the overall limits
tL = [min([x_lim y_lim],[],'all') max([x_lim y_lim],[],'all')];
rL = theta_lim;

end