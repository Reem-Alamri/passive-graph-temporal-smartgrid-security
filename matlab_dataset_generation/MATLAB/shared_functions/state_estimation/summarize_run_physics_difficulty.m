function summary = summarize_run_physics_difficulty(run, tolerance)
    summary = struct( ...
        'OutagedLinePreFlowMean', NaN, ...
        'OutagedLinePreFlowMax', NaN, ...
        'PhysicalEffectL2', 0, ...
        'CyberEffectL2', 0, ...
        'VisiblePostAttackL2', 0, ...
        'PMUAngleChangeL2', 0, ...
        'PostOutageFlowRedistributionL2', 0, ...
        'MaskingRatio', NaN);

    if isfield(run,'TLO') && ~isempty(run.TLO)
        t_phys = run.TLO.t0;
        lines = run.TLO.lines;
        pre_flow = abs(run.edge_feats{max(1,t_phys)}(lines));
        summary.OutagedLinePreFlowMean = mean(pre_flow);
        summary.OutagedLinePreFlowMax = max(pre_flow);
        summary.PhysicalEffectL2 = norm(run.physical_effect{t_phys},2);
        nb1 = numel(run.keep_b);
        summary.PostOutageFlowRedistributionL2 = norm( ...
            run.physical_effect{t_phys}(nb1+1:end), 2);
        pmu = run.pmu_mask & isfinite(run.theta_true_pre{t_phys}) & isfinite(run.theta_true_post{t_phys});
        summary.PMUAngleChangeL2 = norm( ...
            run.theta_true_post{t_phys}(pmu) - run.theta_true_pre{t_phys}(pmu), 2);
    end

    t_cyber = NaN;
    if isfield(run,'CCPA') && ~isempty(run.CCPA), t_cyber = run.CCPA.t_FDIA; end
    if isfield(run,'FDIA') && ~isempty(run.FDIA), t_cyber = run.FDIA.t0; end
    if isfinite(t_cyber)
        summary.CyberEffectL2 = norm(run.cyber_effect{t_cyber},2);
        visible = run.z_attacked_clean{t_cyber} - run.z_clean_pre{t_cyber};
        summary.VisiblePostAttackL2 = norm(visible,2);
        physical_norm = norm(run.physical_effect{t_cyber},2);
        if physical_norm > tolerance
            summary.MaskingRatio = 1 - summary.VisiblePostAttackL2/physical_norm;
        end
    elseif isfield(run,'TLO') && ~isempty(run.TLO)
        t_phys = run.TLO.t0;
        summary.VisiblePostAttackL2 = norm( ...
            run.z_attacked_clean{t_phys} - run.z_clean_pre{t_phys}, 2);
    end
end
