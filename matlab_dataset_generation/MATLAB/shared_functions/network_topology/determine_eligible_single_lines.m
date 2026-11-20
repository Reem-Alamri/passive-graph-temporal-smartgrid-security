function [eligible_lines, ineligible_lines, Teligibility] = determine_eligible_single_lines( ...
    mpc0, slack, keep_b, BR_STATUS, F_BUS, T_BUS, min_rcond_B)

    L = size(mpc0.branch,1);
    branch_id = (1:L)';
    fbus = mpc0.branch(:,F_BUS);
    tbus = mpc0.branch(:,T_BUS);
    connected = false(L,1);
    rcond_b = zeros(L,1);
    eligible = false(L,1);
    reason = strings(L,1);

    for ell = 1:L
        mpc_try = mpc0;
        mpc_try.branch(ell,BR_STATUS) = 0;
        connected(ell) = is_connected_to_slack(mpc_try, slack, F_BUS, T_BUS, BR_STATUS);
        if ~connected(ell)
            reason(ell) = "ISLANDING_OR_SLACK_DISCONNECTION";
            continue;
        end
        try
            [BBUSp, ~, ~, ~] = makeBdc(mpc_try.baseMVA, mpc_try.bus, mpc_try.branch);
            Bred = BBUSp(keep_b,keep_b);
            rcond_b(ell) = rcond(full(Bred));
            if rcond_b(ell) < min_rcond_B
                reason(ell) = "DC_B_MATRIX_ILL_CONDITIONED";
            else
                eligible(ell) = true;
                reason(ell) = "ELIGIBLE_CONNECTED_DC";
            end
        catch ME
            reason(ell) = "MATPOWER_ELIGIBILITY_FAILURE:" + string(ME.identifier);
        end
    end

    eligible_lines = find(eligible)';
    ineligible_lines = find(~eligible)';
    Teligibility = table(branch_id, fbus, tbus, connected, rcond_b, eligible, reason, ...
        'VariableNames', {'BranchID','F_BUS','T_BUS','ConnectedToSlack','RcondReducedB','EligibleAnchor','Reason'});
end
