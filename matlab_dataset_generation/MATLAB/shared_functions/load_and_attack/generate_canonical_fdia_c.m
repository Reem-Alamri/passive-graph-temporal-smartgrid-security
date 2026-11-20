function [c, info, ok] = generate_canonical_fdia_c( ...
        N, slack, support_ratio_rng, scale_rng, zero_tol, max_tries)

    non_slack = setdiff((1:N)', slack, 'stable');
    num_states = numel(non_slack);

    k_min = max(1, round(support_ratio_rng(1) * num_states));
    k_max = min(num_states, max(k_min, round(support_ratio_rng(2) * num_states)));

    c = zeros(N,1);
    info = struct('support_size', NaN, 'support_ratio', NaN, ...
                  'base_scale', NaN, 'amplitude_factor', NaN);
    ok = false;

    for attempt = 1:max_tries
        k = randi([k_min, k_max]);
        selected = non_slack(randperm(num_states, k));

        base_scale = rand_between(scale_rng(1), scale_rng(2));
        amplitude_factor = 0.5 + 1.5*rand;

        candidate = zeros(N,1);
        candidate(selected) = ...
            base_scale * amplitude_factor .* randn(k,1);
        candidate(slack) = 0;

        if norm(candidate, 2) > zero_tol
            c = candidate;
            info.support_size = nnz(abs(c) > zero_tol);
            info.support_ratio = info.support_size / num_states;
            info.base_scale = base_scale;
            info.amplitude_factor = amplitude_factor;
            ok = true;
            return;
        end
    end
end

function [scenario_pool, split_pool, base_state_plan, anchor_plan, tlo_time_plan, fdia_time_plan] = ...
    build_counterfactual_bundle_plan(CLASS_NAMES, num_base_requested, T_total, eligible_lines, seed)

    old_rng = rng;
    cleanupObj = onCleanup(@() rng(old_rng));
    rng(seed, 'twister');

    if ~(isnumeric(num_base_requested) && isreal(num_base_requested) && ...
            isscalar(num_base_requested) && isfinite(num_base_requested) && ...
            num_base_requested == fix(num_base_requested) && ...
            num_base_requested >= 3)
        error(['Invalid num_base_requested inside bundle planner. ' ...
               'class=%s, size=%s, value=%s. Expected one finite integer >= 3.'], ...
              class(num_base_requested), mat2str(size(num_base_requested)), ...
              mat2str(num_base_requested));
    end

    num_base = double(num_base_requested);

    base_ids = (1:num_base)';
    shuffled = base_ids(randperm(num_base));

    nva = max(1, round(0.15*num_base));
    nte = max(1, round(0.15*num_base));
    ntr = num_base - nva - nte;
    assert(ntr >= 1, 'Smoke-test split allocation left no training bundle.');

    base_split = strings(num_base,1);
    base_split(shuffled(1:ntr)) = "train";
    base_split(shuffled(ntr+1:ntr+nva)) = "val";
    base_split(shuffled(ntr+nva+1:ntr+nva+nte)) = "test";

    base_anchor = NaN(num_base,1);
    split_names = ["train","val","test"];
    for si = 1:numel(split_names)
        idx = find(base_split == split_names(si));
        idx = idx(randperm(numel(idx)));
        cycle = eligible_lines(randperm(numel(eligible_lines)));
        assigned = repmat(cycle, 1, ceil(numel(idx)/numel(cycle)));
        base_anchor(idx) = assigned(1:numel(idx));
    end

    base_tlo_time = randi([5, T_total-7], num_base, 1);
    base_fdia_time = base_tlo_time + randi([1,2], num_base, 1);

    num_classes = numel(CLASS_NAMES);
    num_runs = num_base*num_classes;
    scenario_pool = strings(1,num_runs);
    split_pool = strings(1,num_runs);
    base_state_plan = zeros(1,num_runs);
    anchor_plan = NaN(1,num_runs);
    tlo_time_plan = NaN(1,num_runs);
    fdia_time_plan = NaN(1,num_runs);

    q = 0;
    for b = 1:num_base
        for ci = 1:num_classes
            q = q + 1;
            cls = CLASS_NAMES(ci);
            scenario_pool(q) = cls;
            split_pool(q) = base_split(b);
            base_state_plan(q) = b;
            if ismember(cls, ["TLO","CCPA_FULL","CCPA_PARTIAL"])
                anchor_plan(q) = base_anchor(b);
                tlo_time_plan(q) = base_tlo_time(b);
            end
            if ismember(cls, ["FDIA","CCPA_FULL","CCPA_PARTIAL"])
                fdia_time_plan(q) = base_fdia_time(b);
            end
        end
    end

    permutation = randperm(num_runs);
    scenario_pool = scenario_pool(permutation);
    split_pool = split_pool(permutation);
    base_state_plan = base_state_plan(permutation);
    anchor_plan = anchor_plan(permutation);
    tlo_time_plan = tlo_time_plan(permutation);
    fdia_time_plan = fdia_time_plan(permutation);
end
