function [ok, Hp, ap] = evaluate_tlo_candidate(mpc0, run, H, PD, VA, BR_STATUS, F_BUS, T_BUS, lines_set, min_rcond_B)

    ok = false; Hp = []; ap = [];

    mpc_post = mpc0;
    mpc_post.branch(lines_set, BR_STATUS) = 0;

    if ~is_connected_to_slack(mpc_post, run.slack, F_BUS, T_BUS, BR_STATUS)
        return;
    end

    try
        [BBUSp, BFp, ~, ~] = makeBdc(mpc_post.baseMVA, mpc_post.bus, mpc_post.branch);

        Bred = BBUSp(run.keep_b, run.keep_b);
        if rcond(full(Bred)) < min_rcond_B
            return;
        end

        Hp = [BBUSp(run.keep_b,:); BFp];

        t0 = min(max(1, run.TLO.t0), run.T_total);

        mpc_pre = mpc0;
        mpc_pre.bus(:, PD) = run.PD_series{t0};
        mpc_post.bus(:, PD) = mpc_pre.bus(:, PD);

        res_pre  = rundcpf(mpc_pre);
        if ~isfield(res_pre,'success') || res_pre.success ~= 1
            ok = false; Hp = []; ap = []; return;
        end

        res_post = rundcpf(mpc_post);
        if ~isfield(res_post,'success') || res_post.success ~= 1
            ok = false; Hp = []; ap = []; return;
        end

        x  = res_pre.bus(:, VA)*pi/180;
        xp = res_post.bus(:, VA)*pi/180;

        dH = Hp - H;
        dx = xp - x;
        ap = H*dx + dH*xp;

        ok = true;
    catch
        ok = false; Hp = []; ap = [];
    end
end
