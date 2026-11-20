function validate_anchor_plan(scenario_pool, split_pool, anchor_plan, eligible_lines)
    physical = ismember(scenario_pool, ["TLO","CCPA_FULL","CCPA_PARTIAL"]);
    assert(all(isfinite(anchor_plan(physical))), 'A physical run is missing a planned TLO anchor.');
    assert(all(ismember(anchor_plan(physical), eligible_lines)), 'Anchor plan contains an ineligible line.');
    assert(all(isnan(anchor_plan(~physical))), 'NORMAL/FDIA runs must not have TLO anchors.');

    physical_classes = ["TLO","CCPA_FULL","CCPA_PARTIAL"];
    split_names = ["train","val","test"];
    for ci = 1:numel(physical_classes)
        for si = 1:numel(split_names)
            idx = scenario_pool == physical_classes(ci) & split_pool == split_names(si);
            counts = arrayfun(@(ell) nnz(anchor_plan(idx) == ell), eligible_lines);
            assert(max(counts)-min(counts) <= 1, ...
                'Anchor plan is not balanced for scenario=%s split=%s.', ...
                physical_classes(ci), split_names(si));
            assert(min(counts) >= floor(nnz(idx)/numel(eligible_lines)), ...
                'Anchor coverage is below the mathematically achievable balanced minimum.');
        end
    end
end
