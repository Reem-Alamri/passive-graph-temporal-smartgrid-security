function run = simulate_run_with_profile(mpc0, T_total, load_scale_vec, bus_idio, BBUS, BF, VA, PD)
    run.T_total = T_total;
    N = size(mpc0.bus,1);
    L = size(mpc0.branch,1);

    run.PD_series   = cell(T_total,1);
    run.edge_outage = false(T_total, L);

    run.node_feats = cell(T_total,1);
    run.edge_feats = cell(T_total,1);

    for t = 1:T_total
        mpc = mpc0;

        per_bus_factor = load_scale_vec(t) * (1 + bus_idio(:,t));
        mpc.bus(:, PD) = mpc0.bus(:, PD) .* per_bus_factor;
        run.PD_series{t} = mpc.bus(:, PD);

        res = rundcpf(mpc);
        if ~isfield(res,'success') || res.success ~= 1
            error('Baseline DC PF failed at t=%d', t);
        end

        Th   = res.bus(:, VA);
        Pinj = BBUS * (Th*pi/180);
        Pflow= BF   * (Th*pi/180);

        run.node_feats{t} = [Th, Pinj];
        run.edge_feats{t} = Pflow;
    end
end
