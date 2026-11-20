function models = precompute_candidate_topology_models( ...
    mpc0, keep_b, slack, BR_STATUS, F_BUS, T_BUS, min_rcond_B)
    L = size(mpc0.branch,1);
    models.H = cell(L,1);
    models.valid = false(L,1);
    models.rcond_B = NaN(L,1);
    for ell = 1:L
        mpc_try = mpc0;
        mpc_try.branch(ell,BR_STATUS) = 0;
        if ~is_connected_to_slack(mpc_try, slack, F_BUS, T_BUS, BR_STATUS)
            continue;
        end
        try
            [BBUSc, BFc, ~, ~] = makeBdc(mpc_try.baseMVA, mpc_try.bus, mpc_try.branch);
            models.rcond_B(ell) = rcond(full(BBUSc(keep_b,keep_b)));
            if models.rcond_B(ell) < min_rcond_B
                continue;
            end
            models.H{ell} = [BBUSc(keep_b,:); BFc];
            models.valid(ell) = true;
        catch
            models.valid(ell) = false;
        end
    end
end
