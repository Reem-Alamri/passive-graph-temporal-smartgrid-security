function [joint_rms, rtu_rms] = score_candidate_topologies( ...
    models, z_observed, theta_pmu, pmu_idx, w_rtu, w_pmu, lambda, min_rcond_A, min_measurements, slack)
    L = numel(models.H);
    N = size(models.H{find(models.valid,1,'first')},2);
    joint_rms = NaN(L,1);
    rtu_rms = NaN(L,1);
    y_pmu = theta_pmu(pmu_idx);
    S = sparse(1:numel(pmu_idx), pmu_idx, 1, numel(pmu_idx), N);

    for ell = 1:L
        if ~models.valid(ell), continue; end
        Hc = models.H{ell};

        Haug = [Hc; S];
        yaug = [z_observed; y_pmu];
        waug = [w_rtu; w_pmu];
        good = isfinite(yaug) & isfinite(waug);
        if nnz(good) >= min_measurements
            theta_joint = solve_wls_theta(Haug(good,:), yaug(good), waug(good), lambda, min_rcond_A);
            joint_rms(ell) = wls_resid_rms(Haug(good,:), yaug(good), waug(good), theta_joint);
        end

        good_rtu = isfinite(z_observed) & isfinite(w_rtu);
        if nnz(good_rtu) >= min_measurements
            theta_rtu = solve_wls_theta_slack_reference( ...
                Hc(good_rtu,:), z_observed(good_rtu), w_rtu(good_rtu), ...
                lambda, min_rcond_A, slack);
            rtu_rms(ell) = wls_resid_rms(Hc(good_rtu,:), z_observed(good_rtu), ...
                w_rtu(good_rtu), theta_rtu);
        end
    end
end
