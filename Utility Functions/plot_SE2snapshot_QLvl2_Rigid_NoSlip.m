function hA = plot_SE2snapshot_QLvl2_Rigid_NoSlip(ax, pltTraj, fNo, trajCase)
%ANIMATEQLVL2_RIGID_NOSLIP animate the rigid quadrupedal robot given the trajectory structure
%   The trajectory structure needed to run this function is generated by "StitchQuadSE2gaits.m" and for example refer to "se2_GenericQuad_trot.mlx". The
%   plotting structure follows the general outline in "qlevel2noslip_mp.m". This function returns the plotted objects for deletion in the parent animation
%   function.

    % if the trajectory case is not provided-- snapshot case
    if nargin < 3
        fNo = pltTraj.dnum; % plot the last frame if the number is not provided
        trajCase = 0;       % not in the animation case
    end

    % Unpack everything needed plotting
    plot_info = pltTraj.plot_info;
    lW = plot_info.lW; 
    lW_s = plot_info.lW_s; lW_r = plot_info.lW_r;
    lW_qf = plot_info.lW_qf; lW_kq = plot_info.lW_kq;
    frame_scale = plot_info.frame_scale; circS = plot_info.circS;

    anim_lim = pltTraj.anim_lim;
    leg__x = pltTraj.leg__x; leg__y = pltTraj.leg__y;
    legtip__x = pltTraj.legtip__x; legtip__y = pltTraj.legtip__y;
    O_leg__x = pltTraj.O_leg__x; O_leg__y = pltTraj.O_leg__y;
    body_link__x = pltTraj.body_link__x; body_link__y = pltTraj.body_link__y;
    body__x = pltTraj.body__x; body__y = pltTraj.body__y;
    bodyf__x = pltTraj.bodyf__x; bodyf__y = pltTraj.bodyf__y;
    ksq__x = pltTraj.ksq__x; ksq__y = pltTraj.ksq__y;
    col_t = pltTraj.col_t; S = pltTraj.S;
    phi_tau = pltTraj.phi_tau; x = pltTraj.x; y = pltTraj.y;


    % Initialize and start plotting ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    hA = cell(1, 0);
    m = 1;
    % plot body and limbs
    for i = 1:4
        hA{m}  = plot(ax, body_link__x{i}(:,fNo), body_link__y{i}(:,fNo), 'Color', col_t{5}(:,fNo), 'LineWidth', lW); m = m + 1; % plot body i
        if i == 1
            set(ax, 'xticklabel', []); set(ax, 'yticklabel', []); box("off");
            xline(ax, 0, ':', 'LineWidth', 0.5, 'Color', 'k');
            yline(ax, 0, ':', 'LineWidth', 0.5, 'Color', 'k');
            hold on; axis equal; axis(anim_lim);
        end
        hA{m}  = plot(ax, leg__x{i}(:,fNo), leg__y{i}(:,fNo), 'Color', col_t{i}(:,fNo), 'LineWidth', lW); m = m + 1; % leg i
        % if ith limb is in the current contact state
        if i == S(phi_tau(fNo), 1) || i == S(phi_tau(fNo), 2)
            hA{m}  = plot(ax, O_leg__x{i}(:,fNo), O_leg__y{i}(:,fNo), '--', 'Color', col_t{i}(:,fNo), 'LineWidth', lW_r); m = m + 1; % leg i origin
            hA{m}  = scatter(ax, legtip__x{i}(:,fNo), legtip__y{i}(:,fNo), circS, col_t{i}(:,fNo)', 'filled'); m = m + 1; % legtip i scatter
        end
    end
    % plot the body axis frames
    hA{m} = quiver(ax, body__x(fNo), body__y(fNo), frame_scale*bodyf__x(1,fNo), frame_scale*bodyf__x(2,fNo), 'LineWidth', lW_qf, 'Color', col_t{5}(:,fNo),...
            'AutoScale', 'off', 'ShowArrowHead', 'off'); m = m + 1;
    hA{m} = quiver(ax, body__x(fNo), body__y(fNo), frame_scale*bodyf__y(1,fNo), frame_scale*bodyf__y(2,fNo), 'LineWidth', lW_qf, 'Color', col_t{5}(:,fNo),...
        'AutoScale', 'off', 'ShowArrowHead', 'off'); m = m + 1;
    % plot the squared inter-leg distance
    hA{m} = plot(ax, ksq__x{phi_tau(fNo)}(:,fNo), ksq__y{phi_tau(fNo)}(:,fNo), 'Color', col_t{6}(:,fNo), 'LineWidth', lW_kq, 'LineStyle', '--'); m = m + 1;
    % plot the body trajectory (not returned because this will remain static)-- not plotted in the last time step
    switch trajCase
        case 0 % snapshot case
            plotSeqSE2traj(ax, fNo, x, y, lW_s, phi_tau, col_t{7});
        case 1 % animation case (except for the first frame)
            plot(ax, x(fNo-1:fNo), y(fNo-1:fNo), 'LineWidth', 2*lW_s, 'Color', col_t{7}(:,fNo));
    end

end

%% TRAJECTORY SEQUENTIAL PLOT FUNCTION
function plotSeqSE2traj(ax, fNo, x, y, lW_s, phi_tau, colS)
    
    % Just iterate over every single trajectory point
    for i = 2:fNo
        plot(ax, x(i-1:i), y(i-1:i), 'LineWidth', 2*lW_s, 'Color', colS(:,i-1));
    end

end

