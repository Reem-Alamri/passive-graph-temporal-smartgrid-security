function PMU_BUSES = choose_pmu_buses_outage_separation( ...
    mpc0, eligible_lines, slack, ratio, BR_STATUS, F_BUS, T_BUS, VA, ...
    endpoint_weight, mean_weight)
    N = size(mpc0.bus,1);
    k = max(1, round(ratio*N));
    k = min(k, N);

    base = rundcpf(mpc0);
    assert(isfield(base,'success') && base.success == 1, ...
        'Baseline DC PF failed during PMU placement.');
    theta0 = base.bus(:,VA)*pi/180;

    E = numel(eligible_lines);
    signatures = NaN(N,E);
    for j = 1:E
        mpc_try = mpc0;
        mpc_try.branch(eligible_lines(j),BR_STATUS) = 0;
        res = rundcpf(mpc_try);
        assert(isfield(res,'success') && res.success == 1, ...
            'Eligible line %d failed during PMU signature placement.', eligible_lines(j));
        signatures(:,j) = res.bus(:,VA)*pi/180 - theta0;
    end

    selected = unique(slack(:)');
    candidates = setdiff(1:N, selected);
    while numel(selected) < k && ~isempty(candidates)
        best_bus = candidates(1);
        best_objective = -inf;
        for bus = candidates
            trial = unique([selected, bus]);
            [minimum_distance, mean_distance] = signature_pairwise_distances(signatures(trial,:)');
            covered = 0;
            for j = 1:E
                ell = eligible_lines(j);
                if ismember(mpc0.branch(ell,F_BUS), trial) && ismember(mpc0.branch(ell,T_BUS), trial)
                    covered = covered + 1;
                end
            end
            coverage_fraction = covered/max(1,E);
            objective = minimum_distance + mean_weight*mean_distance + endpoint_weight*coverage_fraction;
            if objective > best_objective + 1e-15
                best_objective = objective;
                best_bus = bus;
            end
        end
        selected = unique([selected, best_bus]);
        candidates = setdiff(candidates, best_bus);
    end
    PMU_BUSES = selected(:);
end
