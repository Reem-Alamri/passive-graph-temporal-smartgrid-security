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

    signature_norm2 = sum(signatures.^2, 2);
    distance2 = signature_norm2 + signature_norm2' - 2*(signatures*signatures');
    distance_matrix = sqrt(max(distance2, 0));

    eligible_fbus = mpc0.branch(eligible_lines,F_BUS);
    eligible_tbus = mpc0.branch(eligible_lines,T_BUS);

    selected = unique(slack(:)');
    selected_mask = false(N,1);
    selected_mask(selected) = true;
    candidates = setdiff(1:N, selected);

    current_pair_count = numel(selected)*(numel(selected)-1)/2;
    current_pair_sum = 0;
    current_minimum_distance = inf;
    if current_pair_count > 0
        D0 = distance_matrix(selected,selected);
        upper = triu(true(numel(selected)),1);
        d0 = D0(upper);
        current_pair_sum = sum(d0);
        current_minimum_distance = min(d0);
    end

    while numel(selected) < k && ~isempty(candidates)
        best_bus = candidates(1);
        best_objective = -inf;

        for bus = candidates
            d_new = distance_matrix(bus, selected);
            trial_pair_count = current_pair_count + numel(selected);
            trial_pair_sum = current_pair_sum + sum(d_new);
            trial_mean_distance = trial_pair_sum / max(1, trial_pair_count);
            trial_minimum_distance = min(current_minimum_distance, min(d_new));

            trial_mask = selected_mask;
            trial_mask(bus) = true;
            coverage_fraction = nnz( ...
                trial_mask(eligible_fbus) & trial_mask(eligible_tbus)) / max(1,E);

            objective = trial_minimum_distance + ...
                mean_weight*trial_mean_distance + ...
                endpoint_weight*coverage_fraction;

            if objective > best_objective + 1e-15
                best_objective = objective;
                best_bus = bus;
            end
        end

        d_new = distance_matrix(best_bus, selected);
        current_pair_sum = current_pair_sum + sum(d_new);
        current_pair_count = current_pair_count + numel(selected);
        current_minimum_distance = min(current_minimum_distance, min(d_new));

        selected = unique([selected, best_bus]);
        selected_mask(best_bus) = true;
        candidates = setdiff(candidates, best_bus);
    end
    PMU_BUSES = selected(:);
end
