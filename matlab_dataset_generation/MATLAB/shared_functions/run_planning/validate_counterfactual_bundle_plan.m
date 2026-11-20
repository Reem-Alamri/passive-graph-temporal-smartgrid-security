function validate_counterfactual_bundle_plan(scenario_pool, split_pool, base_state_plan, ...
    anchor_plan, tlo_time_plan, fdia_time_plan, CLASS_NAMES)
    unique_base = unique(base_state_plan);
    for b = unique_base(:)'
        idx = find(base_state_plan == b);
        assert(numel(idx) == numel(CLASS_NAMES), ...
            'BaseState_ID=%d does not contain exactly one run per class.', b);
        assert(numel(unique(split_pool(idx))) == 1, ...
            'Counterfactual bundle BaseState_ID=%d crosses split boundaries.', b);
        assert(isequal(sort(scenario_pool(idx)), sort(CLASS_NAMES)), ...
            'BaseState_ID=%d is missing or duplicating a class.', b);
        physical_idx = idx(ismember(scenario_pool(idx), ["TLO","CCPA_FULL","CCPA_PARTIAL"]));
        assert(numel(unique(anchor_plan(physical_idx))) == 1, ...
            'Physical counterfactuals do not share the same anchor for BaseState_ID=%d.', b);
        assert(numel(unique(tlo_time_plan(physical_idx))) == 1, ...
            'Physical counterfactuals do not share TLO timing for BaseState_ID=%d.', b);
        cyber_idx = idx(ismember(scenario_pool(idx), ["FDIA","CCPA_FULL","CCPA_PARTIAL"]));
        assert(numel(unique(fdia_time_plan(cyber_idx))) == 1, ...
            'Cyber counterfactuals do not share FDIA timing for BaseState_ID=%d.', b);
    end
end

function [load_scale, bus_idio, busvar_sigma, busvar_rho] = ...
    make_counterfactual_operating_profile(N, T_total, LOADPROFILE, seed)
    old_rng = rng;
    cleanupObj = onCleanup(@() rng(old_rng));
    rng(seed, 'twister');
    load_scale = random_load_profile_vec(T_total);
    busvar_sigma = rand_between(LOADPROFILE.busvar_sigma_rng(1), LOADPROFILE.busvar_sigma_rng(2));
    busvar_rho = rand_between(LOADPROFILE.busvar_rho_rng(1), LOADPROFILE.busvar_rho_rng(2));
    bus_idio = per_bus_idiosyncratic_noise(N, T_total, busvar_sigma, busvar_rho);
end
