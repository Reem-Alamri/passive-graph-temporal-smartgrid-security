function export_raw_run(run, run_id, split_tag, scenario, CLASS_NAMES, L, N, ...
                        det_cols, loc_cols, cyber_bus_cols, cyber_branch_cols, ...
                        fbus, tbus, BF, FN_RAW_NODES, FN_RAW_BRANCH, FN_RAW_GENS, FN_RAW_LABELS, ...
                        FN_RAW_TRUTH_NODES, FN_RAW_TRUTH_BRANCH, ENRICH)

    for t = 1:run.T_total

        theta_pmu = run.pmu_theta_meas{t};
        pmu_placed = double(run.pmu_mask);
        pmu_avail = double(isfinite(theta_pmu));
        rtu_pinj = run.rtu_pinj_meas{t};
        pinj_wls_pre = run.pinj_est_wls_pre{t};
        theta_wls_pre = run.theta_hat_wls_pre{t};
        resid_pre = repmat(run.wls_resid_pre(t), N, 1);

        pinj_wls_pre_rtu  = run.pinj_est_wls_pre_rtu{t};
        theta_wls_pre_rtu = run.theta_hat_wls_pre_rtu{t};
        resid_pre_rtu     = repmat(run.wls_resid_pre_rtu(t), N, 1);

        resid_joint = run.rtu_resid_joint{t};
        norm_resid_joint = run.rtu_norm_resid_joint{t};
        resid_rtuonly = run.rtu_resid_rtuonly{t};
        norm_resid_rtuonly = run.rtu_norm_resid_rtuonly{t};
        pinj_resid_joint = NaN(N,1); pinj_resid_joint(run.keep_b) = resid_joint(1:numel(run.keep_b));
        pinj_norm_resid_joint = NaN(N,1); pinj_norm_resid_joint(run.keep_b) = norm_resid_joint(1:numel(run.keep_b));
        pinj_resid_rtuonly = NaN(N,1); pinj_resid_rtuonly(run.keep_b) = resid_rtuonly(1:numel(run.keep_b));
        pinj_norm_resid_rtuonly = NaN(N,1); pinj_norm_resid_rtuonly(run.keep_b) = norm_resid_rtuonly(1:numel(run.keep_b));
        pmu_theta_resid_joint = run.pmu_theta_resid_joint{t};
        pmu_theta_norm_resid_joint = run.pmu_theta_norm_resid_joint{t};

        Run_ID = repmat(run_id, N, 1);
        BaseState_ID = repmat(run.meta.base_state_id, N, 1);
        Split = repmat(string(split_tag), N, 1);
        Scenario = repmat(string(scenario), N, 1);
        Time_Step = repmat(t, N, 1);
        BusIndex = (1:N)';

        TnodesRaw = table(Run_ID, BaseState_ID, Split, Scenario, Time_Step, BusIndex, ...
                          theta_pmu, pmu_placed, pmu_avail, rtu_pinj, pinj_wls_pre, theta_wls_pre, resid_pre, ...
                          pinj_wls_pre_rtu, theta_wls_pre_rtu, resid_pre_rtu, ...
                          pinj_resid_joint, pinj_norm_resid_joint, ...
                          pinj_resid_rtuonly, pinj_norm_resid_rtuonly, ...
                          pmu_theta_resid_joint, pmu_theta_norm_resid_joint, ...
            'VariableNames', {'Run_ID','BaseState_ID','Split','Scenario','Time_Step','BusIndex', ...
            'PMU_Theta_meas_rad','PMU_Placed','PMU_Avail','RTU_Pinj_meas', ...
            'Pinj_est_WLS_preTopo','Theta_est_WLS_preTopo','WLS_ResidRMS_preTopo', ...
            'Pinj_est_WLS_RTUonly','Theta_est_WLS_RTUonly','WLS_ResidRMS_RTUonly', ...
            'Resid_Pinj_JointWLS','NormResid_Pinj_JointWLS', ...
            'Resid_Pinj_RTUonlyWLS','NormResid_Pinj_RTUonlyWLS', ...
            'PMU_ThetaResid_JointWLS','PMU_ThetaNormResid_JointWLS'});
        append_csv(TnodesRaw, FN_RAW_NODES);

        rtu_pflow = run.rtu_pflow_meas{t};
        pflow_wls_pre = run.pflow_est_wls_pre{t};
        pflow_wls_pre_rtu = run.pflow_est_wls_pre_rtu{t};
        th = run.pmu_theta_meas{t};
        pmu_dtheta = NaN(L,1);
        pmu_endpoint_placed = false(L,1);
        pmu_av = false(L,1);
        for ell = 1:L
            fb = fbus(ell);
            tb = tbus(ell);
            pmu_endpoint_placed(ell) = run.pmu_mask(fb) && run.pmu_mask(tb);
            if ~isnan(th(fb)) && ~isnan(th(tb))
                pmu_dtheta(ell) = th(fb) - th(tb);
                pmu_av(ell) = true;
            end
        end
        line_outage = double(run.edge_outage(t,:)');

        nb1_local = numel(run.keep_b);
        flow_resid_joint = run.rtu_resid_joint{t}(nb1_local+1:nb1_local+L);
        flow_norm_resid_joint = run.rtu_norm_resid_joint{t}(nb1_local+1:nb1_local+L);
        flow_resid_rtuonly = run.rtu_resid_rtuonly{t}(nb1_local+1:nb1_local+L);
        flow_norm_resid_rtuonly = run.rtu_norm_resid_rtuonly{t}(nb1_local+1:nb1_local+L);
        candidate_joint_rms = run.candidate_joint_rms(t,:)';
        candidate_rtu_rms = run.candidate_rtu_rms(t,:)';
        candidate_joint_improvement = run.candidate_joint_improvement(t,:)';
        candidate_rtu_improvement = run.candidate_rtu_improvement(t,:)';
        candidate_joint_rank = rank_descending_nan(candidate_joint_improvement);
        candidate_rtu_rank = rank_descending_nan(candidate_rtu_improvement);

        pmu_pflow_est = NaN(L,1);
        pmu_minus_rtu_flow = NaN(L,1);
        pmu_minus_joint_wls_flow = NaN(L,1);
        for ell = 1:L
            if pmu_av(ell)
                pmu_pflow_est(ell) = BF(ell,fbus(ell))*th(fbus(ell)) + BF(ell,tbus(ell))*th(tbus(ell));
                pmu_minus_rtu_flow(ell) = pmu_pflow_est(ell) - rtu_pflow(ell);
                pmu_minus_joint_wls_flow(ell) = pmu_pflow_est(ell) - pflow_wls_pre(ell);
            end
        end

        Run_ID = repmat(run_id, L, 1);
        BaseState_ID = repmat(run.meta.base_state_id, L, 1);
        Split = repmat(string(split_tag), L, 1);
        Scenario = repmat(string(scenario), L, 1);
        Time_Step = repmat(t, L, 1);
        BranchID = (1:L)';

        TbrRaw = table(Run_ID, BaseState_ID, Split, Scenario, Time_Step, BranchID, ...
                       rtu_pflow, pflow_wls_pre, pflow_wls_pre_rtu, double(pmu_endpoint_placed), double(pmu_av), pmu_dtheta, ...
                       pmu_pflow_est, pmu_minus_rtu_flow, pmu_minus_joint_wls_flow, ...
                       flow_resid_joint, flow_norm_resid_joint, flow_resid_rtuonly, flow_norm_resid_rtuonly, ...
                       candidate_joint_rms, candidate_rtu_rms, candidate_joint_improvement, candidate_rtu_improvement, ...
                       candidate_joint_rank, candidate_rtu_rank, fbus, tbus, line_outage, ...
            'VariableNames', {'Run_ID','BaseState_ID','Split','Scenario','Time_Step','BranchID', ...
            'RTU_Pflow_meas','Pflow_est_WLS_preTopo','Pflow_est_WLS_RTUonly','PMU_EndpointPlaced','PMU_Avail','PMU_Dtheta_meas_rad', ...
            'PMU_Pflow_est','PMU_minus_RTU_Pflow','PMU_minus_JointWLS_Pflow', ...
            'Resid_Pflow_JointWLS','NormResid_Pflow_JointWLS','Resid_Pflow_RTUonlyWLS','NormResid_Pflow_RTUonlyWLS', ...
            'CandidateJointRMS','CandidateRTURMS','CandidateJointImprovement','CandidateRTUImprovement', ...
            'CandidateJointRank','CandidateRTURank','F_BUS','T_BUS','Line_Outage_Label'});
        append_csv(TbrRaw, FN_RAW_BRANCH);

        if ENRICH.export_truth_targets
            theta_true_pre = run.theta_true_pre{t};
            theta_true_post = run.theta_true_post{t};
            z_clean_pre = run.z_clean_pre{t};
            z_clean_post = run.z_clean_post{t};
            z_attacked_clean = run.z_attacked_clean{t};
            physical_effect = run.physical_effect{t};
            cyber_effect = run.cyber_effect{t};
            writable_mask = run.cyber_writable_mask{t};
            modified_mask = run.cyber_modified_mask{t};
            nb1_truth = numel(run.keep_b);

            fdia_c_state_shift = NaN(N,1);
            if isfield(run,'FDIA') && ~isempty(run.FDIA) && isfield(run.FDIA,'c')
                fdia_c_state_shift = run.FDIA.c(:);
            end

            pinj_true_pre = NaN(N,1); pinj_true_pre(run.keep_b) = z_clean_pre(1:nb1_truth); pinj_true_pre(run.slack) = 0;
            pinj_true_post = NaN(N,1); pinj_true_post(run.keep_b) = z_clean_post(1:nb1_truth); pinj_true_post(run.slack) = 0;
            pinj_attacked_clean = NaN(N,1); pinj_attacked_clean(run.keep_b) = z_attacked_clean(1:nb1_truth); pinj_attacked_clean(run.slack) = 0;
            pinj_physical_effect = zeros(N,1); pinj_physical_effect(run.keep_b) = physical_effect(1:nb1_truth);
            pinj_cyber_effect = zeros(N,1); pinj_cyber_effect(run.keep_b) = cyber_effect(1:nb1_truth);
            pinj_writable = zeros(N,1); pinj_writable(run.keep_b) = writable_mask(1:nb1_truth);
            pinj_modified = zeros(N,1); pinj_modified(run.keep_b) = modified_mask(1:nb1_truth);
            pinj_measurement_exists = zeros(N,1); pinj_measurement_exists(run.keep_b) = 1;

            Run_ID_truth = repmat(run_id, N, 1);
            BaseState_ID_truth = repmat(run.meta.base_state_id, N, 1);
            Split_truth = repmat(string(split_tag), N, 1);
            Scenario_truth = repmat(string(scenario), N, 1);
            Time_Step_truth = repmat(t, N, 1);
            BusIndex_truth = (1:N)';
            TtruthNodes = table(Run_ID_truth, BaseState_ID_truth, Split_truth, Scenario_truth, ...
                Time_Step_truth, BusIndex_truth, theta_true_pre, theta_true_post, ...
                fdia_c_state_shift, pinj_true_pre, pinj_true_post, pinj_attacked_clean, ...
                pinj_physical_effect, pinj_cyber_effect, pinj_writable, pinj_modified, ...
                pinj_measurement_exists, rtu_pinj, ...
                'VariableNames', {'Run_ID','BaseState_ID','Split','Scenario','Time_Step','BusIndex', ...
                'Theta_true_pre_rad','Theta_true_post_rad','FDIA_c_StateShift', ...
                'RTU_Pinj_clean_pre','RTU_Pinj_clean_post', ...
                'RTU_Pinj_attacked_clean','PhysicalEffect_Pinj','CyberAttackValue_Pinj', ...
                'CyberWritableMask_Pinj','CyberModifiedMask_Pinj','RTU_PinjMeasurementExists','RTU_Pinj_observed'});
            append_csv(TtruthNodes, FN_RAW_TRUTH_NODES);

            pflow_clean_pre = z_clean_pre(nb1_truth+1:nb1_truth+L);
            pflow_clean_post = z_clean_post(nb1_truth+1:nb1_truth+L);
            pflow_attacked_clean = z_attacked_clean(nb1_truth+1:nb1_truth+L);
            pflow_physical_effect = physical_effect(nb1_truth+1:nb1_truth+L);
            pflow_cyber_effect = cyber_effect(nb1_truth+1:nb1_truth+L);
            pflow_writable = writable_mask(nb1_truth+1:nb1_truth+L);
            pflow_modified = modified_mask(nb1_truth+1:nb1_truth+L);

            Run_ID_truth = repmat(run_id, L, 1);
            BaseState_ID_truth = repmat(run.meta.base_state_id, L, 1);
            Split_truth = repmat(string(split_tag), L, 1);
            Scenario_truth = repmat(string(scenario), L, 1);
            Time_Step_truth = repmat(t, L, 1);
            BranchID_truth = (1:L)';
            TtruthBranch = table(Run_ID_truth, BaseState_ID_truth, Split_truth, Scenario_truth, ...
                Time_Step_truth, BranchID_truth, pflow_clean_pre, pflow_clean_post, ...
                pflow_attacked_clean, pflow_physical_effect, pflow_cyber_effect, ...
                pflow_writable, pflow_modified, rtu_pflow, line_outage, fbus, tbus, ...
                'VariableNames', {'Run_ID','BaseState_ID','Split','Scenario','Time_Step','BranchID', ...
                'RTU_Pflow_clean_pre','RTU_Pflow_clean_post','RTU_Pflow_attacked_clean', ...
                'PhysicalEffect_Pflow','CyberAttackValue_Pflow','CyberWritableMask_Pflow', ...
                'CyberModifiedMask_Pflow','RTU_Pflow_observed','Line_Outage_Label','F_BUS','T_BUS'});
            append_csv(TtruthBranch, FN_RAW_TRUTH_BRANCH);
        end

        if ~isempty(run.gen_res{t})
            G = run.gen_res{t};
            Run_ID = repmat(run_id, size(G,1), 1);
            BaseState_ID = repmat(run.meta.base_state_id, size(G,1), 1);
            Split = repmat(string(split_tag), size(G,1), 1);
            Scenario = repmat(string(scenario), size(G,1), 1);
            Time_Step = repmat(t, size(G,1), 1);
            GenID = (1:size(G,1))';
            TgenRaw = table(Run_ID, BaseState_ID, Split, Scenario, Time_Step, GenID);
            for kcol = 1:size(G,2)
                TgenRaw.(sprintf('gen_col_%d',kcol)) = G(:,kcol);
            end
            append_csv(TgenRaw, FN_RAW_GENS);
        end

        det_name = detect_label_persistent(run.events, t);
        ydet = zeros(1, numel(CLASS_NAMES));
        k = find(CLASS_NAMES == string(det_name), 1);
        if isempty(k), k = 1; end
        ydet(k) = 1;

        yloc_final = double(run.edge_outage(t,:));
        cyber_on = is_cyber_active_time(run, t);
        if cyber_on
            bus_mask_t = run.cyber.bus_mask(:);
            br_mask_t  = run.cyber.branch_mask(:);
        else
            bus_mask_t = zeros(N,1);
            br_mask_t  = zeros(L,1);
        end

        TrawLab = table(run_id, run.meta.base_state_id, string(split_tag), string(scenario), t, string(det_name), ...
            'VariableNames', {'Run_ID','BaseState_ID','Split','Scenario','Time_Step','ClassName'});
        for ii = 1:numel(det_cols), TrawLab.(det_cols{ii}) = ydet(ii); end
        for jj = 1:numel(loc_cols), TrawLab.(loc_cols{jj}) = yloc_final(jj); end
        for i = 1:N, TrawLab.(cyber_bus_cols{i}) = bus_mask_t(i); end
        for e = 1:L, TrawLab.(cyber_branch_cols{e}) = br_mask_t(e); end

        TrawLab.IsCyberActive = double(cyber_on);
        TrawLab.IsPhysicalOutageActive = double(any(yloc_final));
        append_csv(TrawLab, FN_RAW_LABELS);
    end
end
