function PMU_BUSES = choose_pmu_buses(N, slack, ratio)
    k = max(1, round(ratio * N));
    cand = setdiff(1:N, slack);
    if k-1 > numel(cand), k = numel(cand)+1; end
    pick = cand(randperm(numel(cand), k-1));
    PMU_BUSES = unique([slack; pick(:)]);
end
