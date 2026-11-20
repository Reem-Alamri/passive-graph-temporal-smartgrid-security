function run = realize_measurements_with_attacks_RTU_PMU_protected_WLSpre_faults( ...
    run, mpc0, H, noise, BBUS, BF, PD, VA, BR_STATUS, ...
    WLS, F_BUS, T_BUS, FAULTS, ROBUST, CCPA_MASKING_MODE, REFERENCE_EQ_TOL, ...
    CANDIDATE_MODELS, ENRICH)

    T  = run.T_total;
    N  = size(mpc0.bus,1);
    L  = size(mpc0.branch,1);
    nb1 = numel(run.keep_b);
    M  = nb1 + L;

    run.bus_res    = cell(T,1);
    run.branch_res = cell(T,1);
    run.gen_res    = cell(T,1);

    run.pmu_mask = noise.pmu.mask;
    run.pmu_theta_meas = cell(T,1);

    run.Z = cell(T,1);
    run.rtu_pinj_meas  = cell(T,1);
    run.rtu_pflow_meas = cell(T,1);

    run.rtu_resid_joint = cell(T,1);
    run.rtu_norm_resid_joint = cell(T,1);
    run.rtu_resid_rtuonly = cell(T,1);
    run.rtu_norm_resid_rtuonly = cell(T,1);
    run.pmu_theta_resid_joint = cell(T,1);
    run.pmu_theta_norm_resid_joint = cell(T,1);

    run.theta_true_pre = cell(T,1);
    run.theta_true_post = cell(T,1);
    run.z_clean_pre = cell(T,1);
    run.z_clean_post = cell(T,1);
    run.z_attacked_clean = cell(T,1);
    run.physical_effect = cell(T,1);
    run.cyber_effect = cell(T,1);
    run.cyber_writable_mask = cell(T,1);
    run.cyber_modified_mask = cell(T,1);

    run.candidate_joint_rms = NaN(T,L);
    run.candidate_rtu_rms = NaN(T,L);
    run.candidate_joint_improvement = NaN(T,L);
    run.candidate_rtu_improvement = NaN(T,L);

    run.theta_hat_wls_pre  = cell(T,1);
    run.pinj_est_wls_pre   = cell(T,1);
    run.pflow_est_wls_pre  = cell(T,1);
    run.wls_resid_pre      = NaN(T,1);

    run.theta_hat_wls_pre_rtu  = cell(T,1);
    run.pinj_est_wls_pre_rtu   = cell(T,1);
    run.pflow_est_wls_pre_rtu  = cell(T,1);
    run.wls_resid_pre_rtu      = NaN(T,1);

    e_prev = zeros(M,1);

    rtu_stuck_cnt  = zeros(M,1);
    rtu_stuck_val  = NaN(M,1);

    pmu_stuck_cnt  = zeros(N,1);
    pmu_stuck_val  = NaN(N,1);

    rtu_outlier_ct = 0; rtu_missing_ct = 0; rtu_stuck_ct = 0;
    pmu_outlier_ct = 0; pmu_missing_ct = 0; pmu_stuck_ct = 0;
    total_rtu_slots = T*M;
    total_pmu_slots = T*nnz(run.pmu_mask);

    for t = 1:T
        mpc_post = mpc0;  mpc_post.bus(:, PD) = run.PD_series{t};
        mpc_pre  = mpc0;  mpc_pre.bus(:, PD)  = run.PD_series{t};

        use_post = isfield(run,'TLO') && ~isempty(run.TLO) && t >= run.TLO.t0;
        if use_post
            mpc_post.branch(run.TLO.lines, BR_STATUS) = 0;
            H_use = run.Hp;
            [BBUSp, BFp, ~, ~] = makeBdc(mpc_post.baseMVA, mpc_post.bus, mpc_post.branch);
            BBUS_use = BBUSp;
            BF_use   = BFp;

            Bred = BBUSp(run.keep_b, run.keep_b);

            min_rcond_B_use = ROBUST.min_rcond_B;
            if isfield(run,'meta') && isfield(run.meta,'min_rcond_B_eff') && isfinite(run.meta.min_rcond_B_eff)
                min_rcond_B_use = run.meta.min_rcond_B_eff;
            end

            if rcond(full(Bred)) < min_rcond_B_use
                error('Post topology B is near-singular at t=%d.', t);
            end
        else
            H_use = H;
            BBUS_use = BBUS;
            BF_use   = BF;
        end

        res_post = rundcpf(mpc_post);
        if ~isfield(res_post,'success') || res_post.success ~= 1
            error('DC PF failed at t=%d (post).', t);
        end
        theta_p  = res_post.bus(:, VA) * pi/180;
        z_base   = H_use * theta_p;

        theta_pre_true = run.node_feats{t}(:,1) * pi/180;
        z_pre_clean = H * theta_pre_true;
        cyber_t = zeros(M,1);

        th_meas = NaN(N,1);
        pmu_idx = find(run.pmu_mask);

        th_meas(pmu_idx) = theta_p(pmu_idx) + noise.pmu.bias_vec(pmu_idx) + ...
                           noise.pmu.theta_sigma*randn(numel(pmu_idx),1);

        use_ccpa = isfield(run,'CCPA') && ~isempty(run.CCPA) && t >= run.CCPA.t_FDIA;
        use_fdia = isfield(run,'FDIA') && ~isempty(run.FDIA) && t >= run.FDIA.t0;

        if use_ccpa
            res_pre = rundcpf(mpc_pre);
            if ~isfield(res_pre,'success') || res_pre.success ~= 1
                error('DC PF failed at t=%d (pre).', t);
            end
            theta   = res_pre.bus(:, VA) * pi/180;

            dH   = run.Hp - H;
            dx   = theta_p - theta;
            dHxp = dH*theta_p;
            ap_t = H*dx + dHxp;

            if strcmp(char(CCPA_MASKING_MODE), 'paper_faithful')

                if strcmp(run.events.CCPA_type, "FULL")
                    ac_t = -ap_t;
                else
                    ac_t = -dHxp;
                end

            else

                ac_t = - run.CCPA.alpha * ap_t;
                if isfield(run.CCPA,'mask') && ~isempty(run.CCPA.mask)
                    ac_t = ac_t .* run.CCPA.mask;
                end
            end
            cyber_t = ac_t;
            z_use = z_base + cyber_t;

            if strcmp(char(CCPA_MASKING_MODE), 'paper_faithful')
                z_pre_reference = H * theta;
                if strcmp(run.events.CCPA_type, "FULL")
                    z_expected_reference = z_pre_reference;
                    equation_name = 'Chen2022_eq6_FULL';
                else
                    z_expected_reference = z_pre_reference + H*dx;
                    equation_name = 'Chen2022_eq4_PARTIAL';
                end
                reference_error = norm(z_use - z_expected_reference, inf);
                reference_scale = max(1.0, norm(z_expected_reference, inf));
                assert(reference_error <= REFERENCE_EQ_TOL * reference_scale, ...
                    '%s invariant failed at t=%d: abs_err=%.3e rel_err=%.3e', ...
                    equation_name, t, reference_error, reference_error/reference_scale);
            end

        elseif use_fdia
            cyber_t = run.FDIA.a;
            z_use = z_base + cyber_t;

            fdia_error = norm(cyber_t - H*run.FDIA.c, inf);
            fdia_scale = max(1.0, norm(cyber_t, inf));
            assert(fdia_error <= REFERENCE_EQ_TOL * fdia_scale, ...
                ['Canonical FDIA invariant failed at t=%d: ' ...
                 '||a-H*c||_inf=%.3e.'], t, fdia_error);

            z_expected_fdia = H * (theta_p + run.FDIA.c);
            state_shift_error = norm(z_use - z_expected_fdia, inf);
            state_shift_scale = max(1.0, norm(z_expected_fdia, inf));
            assert(state_shift_error <= REFERENCE_EQ_TOL * state_shift_scale, ...
                ['Canonical FDIA state-shift invariant failed at t=%d: ' ...
                 '||z_a-H*(theta+c)||_inf=%.3e.'], t, state_shift_error);
        else
            z_use = z_base;
        end

        run.theta_true_pre{t} = theta_pre_true;
        run.theta_true_post{t} = theta_p;
        run.z_clean_pre{t} = z_pre_clean;
        run.z_clean_post{t} = z_base;
        run.z_attacked_clean{t} = z_use;
        run.physical_effect{t} = z_base - z_pre_clean;
        run.cyber_effect{t} = cyber_t;
        if use_ccpa || use_fdia
            writable_mask_t = double(run.meta.mask(:));
        else
            writable_mask_t = zeros(M,1);
        end
        run.cyber_writable_mask{t} = writable_mask_t;
        run.cyber_modified_mask{t} = double(abs(cyber_t) > ENRICH.attack_value_tolerance);

        rho  = noise.rtu.rho;
        sigv = noise.rtu.sigma_vec;

        innov = sqrt(max(0,1-rho^2)) * (sigv .* randn(M,1));
        e_t   = rho * e_prev + innov;
        e_prev = e_t;

        z_use = z_use + noise.rtu.bias_vec + e_t;

        if FAULTS.enable
            [z_use, rtu_stuck_cnt, rtu_stuck_val, o1, m1, s1] = apply_faults_vector( ...
                z_use, sigv, rtu_stuck_cnt, rtu_stuck_val, ...
                FAULTS.RTU.p_outlier, FAULTS.RTU.outlier_k, ...
                FAULTS.RTU.p_missing, ...
                FAULTS.RTU.p_stuck, FAULTS.RTU.stuck_len_rng);

            rtu_outlier_ct = rtu_outlier_ct + o1;
            rtu_missing_ct = rtu_missing_ct + m1;
            rtu_stuck_ct   = rtu_stuck_ct   + s1;

            th_sub = th_meas(pmu_idx);
            sigp   = noise.pmu.theta_sigma * ones(size(th_sub));

            [th_sub2, pmu_stuck_cnt(pmu_idx), pmu_stuck_val(pmu_idx), o2, m2, s2] = apply_faults_vector( ...
                th_sub, sigp, pmu_stuck_cnt(pmu_idx), pmu_stuck_val(pmu_idx), ...
                FAULTS.PMU.p_outlier, FAULTS.PMU.outlier_k, ...
                FAULTS.PMU.p_missing, ...
                FAULTS.PMU.p_stuck, FAULTS.PMU.stuck_len_rng);

            th_meas(pmu_idx) = th_sub2;

            pmu_outlier_ct = pmu_outlier_ct + o2;
            pmu_missing_ct = pmu_missing_ct + m2;
            pmu_stuck_ct   = pmu_stuck_ct   + s2;
        end

        run.Z{t} = z_use;
        run.pmu_theta_meas{t} = th_meas;

        z_bus = z_use(1:nb1);
        z_flw = z_use(nb1+1 : nb1+L);

        Pinj_meas = NaN(N,1);
        Pinj_meas(run.keep_b) = z_bus;
        Pinj_meas(run.slack)  = 0;

        run.rtu_pinj_meas{t}  = Pinj_meas;
        run.rtu_pflow_meas{t} = z_flw;

        y_pmu = th_meas(pmu_idx);
        S = sparse(1:numel(pmu_idx), pmu_idx, 1, numel(pmu_idx), N);

        H_aug_pre  = [H; S];
        y_aug      = [z_use; y_pmu];

        rtu_var = (noise.rtu.sigma_vec).^2;
        pmu_var = (noise.pmu.theta_sigma).^2 * ones(numel(pmu_idx),1);

        w_rtu = WLS.rtu_w_scale ./ max(1e-12, rtu_var);
        w_pmu = WLS.pmu_w_scale ./ max(1e-12, pmu_var);
        w_aug = [w_rtu; w_pmu];

        good = isfinite(y_aug) & isfinite(w_aug);
        y_f  = y_aug(good);
        w_f  = w_aug(good);
        Hf_pre  = H_aug_pre(good,:);

        if numel(y_f) < max(3, round(0.2*N))
            theta_pre = NaN(N,1);
        else
            theta_pre = solve_wls_theta(Hf_pre, y_f, w_f, WLS.lambda, ROBUST.min_rcond_A);
        end

        run.wls_resid_pre(t) = wls_resid_rms(Hf_pre, y_f, w_f, theta_pre);

        run.theta_hat_wls_pre{t} = theta_pre;
        if any(isnan(theta_pre))
            run.pinj_est_wls_pre{t}  = NaN(N,1);
            run.pflow_est_wls_pre{t} = NaN(L,1);
        else
            run.pinj_est_wls_pre{t}  = BBUS * theta_pre;
            run.pflow_est_wls_pre{t} = BF * theta_pre;
        end

        good_rtu   = isfinite(z_use) & isfinite(w_rtu);
        y_f_rtu    = z_use(good_rtu);
        w_f_rtu    = w_rtu(good_rtu);
        Hf_pre_rtu = H(good_rtu, :);

        if numel(y_f_rtu) < max(3, round(0.2*N))
            theta_pre_rtu = NaN(N,1);
        else
            theta_pre_rtu = solve_wls_theta_slack_reference( ...
                Hf_pre_rtu, y_f_rtu, w_f_rtu, WLS.lambda, ROBUST.min_rcond_A, run.slack);
        end

        run.wls_resid_pre_rtu(t) = wls_resid_rms(Hf_pre_rtu, y_f_rtu, w_f_rtu, theta_pre_rtu);
        run.theta_hat_wls_pre_rtu{t} = theta_pre_rtu;
        if any(isnan(theta_pre_rtu))
            run.pinj_est_wls_pre_rtu{t}  = NaN(N,1);
            run.pflow_est_wls_pre_rtu{t} = NaN(L,1);
        else
            run.pinj_est_wls_pre_rtu{t}  = BBUS * theta_pre_rtu;
            run.pflow_est_wls_pre_rtu{t} = BF * theta_pre_rtu;
        end

        if any(isnan(theta_pre))
            resid_joint = NaN(M,1);
            pmu_resid_joint = NaN(N,1);
        else
            resid_joint = z_use - H*theta_pre;
            pmu_resid_joint = NaN(N,1);
            pmu_resid_joint(pmu_idx) = th_meas(pmu_idx) - theta_pre(pmu_idx);
        end
        if any(isnan(theta_pre_rtu))
            resid_rtuonly = NaN(M,1);
        else
            resid_rtuonly = z_use - H*theta_pre_rtu;
        end
        run.rtu_resid_joint{t} = resid_joint;
        run.rtu_norm_resid_joint{t} = resid_joint ./ max(noise.rtu.sigma_vec, 1e-12);
        run.rtu_resid_rtuonly{t} = resid_rtuonly;
        run.rtu_norm_resid_rtuonly{t} = resid_rtuonly ./ max(noise.rtu.sigma_vec, 1e-12);
        run.pmu_theta_resid_joint{t} = pmu_resid_joint;
        run.pmu_theta_norm_resid_joint{t} = pmu_resid_joint ./ max(noise.pmu.theta_sigma, 1e-12);

        if ENRICH.compute_candidate_topology
            do_candidate_score = (t == 1) || (mod(t-1, ENRICH.candidate_score_stride) == 0);
            if do_candidate_score
                [joint_rms, rtu_rms] = score_candidate_topologies( ...
                    CANDIDATE_MODELS, z_use, th_meas, pmu_idx, w_rtu, w_pmu, ...
                    WLS.lambda, ROBUST.min_rcond_A, ENRICH.candidate_min_measurements, run.slack);
                run.candidate_joint_rms(t,:) = joint_rms(:)';
                run.candidate_rtu_rms(t,:) = rtu_rms(:)';
                run.candidate_joint_improvement(t,:) = run.wls_resid_pre(t) - joint_rms(:)';
                run.candidate_rtu_improvement(t,:) = run.wls_resid_pre_rtu(t) - rtu_rms(:)';
            elseif t > 1
                run.candidate_joint_rms(t,:) = run.candidate_joint_rms(t-1,:);
                run.candidate_rtu_rms(t,:) = run.candidate_rtu_rms(t-1,:);
                run.candidate_joint_improvement(t,:) = run.candidate_joint_improvement(t-1,:);
                run.candidate_rtu_improvement(t,:) = run.candidate_rtu_improvement(t-1,:);
            end
        end

        run.bus_res{t}    = res_post.bus;
        run.branch_res{t} = res_post.branch;
        run.gen_res{t}    = res_post.gen;

        BBUS_use = BBUS_use; BF_use = BF_use;
    end

    run.faults_stats.RTU_outlier_rate = rtu_outlier_ct / max(1, total_rtu_slots);
    run.faults_stats.RTU_missing_rate = rtu_missing_ct / max(1, total_rtu_slots);
    run.faults_stats.RTU_stuck_rate   = rtu_stuck_ct   / max(1, total_rtu_slots);

    run.faults_stats.PMU_outlier_rate = pmu_outlier_ct / max(1, total_pmu_slots);
    run.faults_stats.PMU_missing_rate = pmu_missing_ct / max(1, total_pmu_slots);
    run.faults_stats.PMU_stuck_rate   = pmu_stuck_ct   / max(1, total_pmu_slots);
end
