function write_line_coverage_report(meta_file, output_file, eligible_lines, ineligible_lines, do_assert)
    Tmeta = readtable(meta_file, 'TextType','string');
    required = {'Split','ClassName','TLO_lines','TLO_AnchorLine','TLO_NumLines'};
    assert(all(ismember(required, Tmeta.Properties.VariableNames)), ...
        'runs_metadata is missing v10 coverage fields.');

    split_names = ["train","val","test"];
    physical_classes = ["TLO","CCPA_FULL","CCPA_PARTIAL"];
    L = max([eligible_lines(:); ineligible_lines(:)]);

    split_col = string(Tmeta.Split);
    class_col = string(Tmeta.ClassName);
    anchor_col = str2double(string(Tmeta.TLO_AnchorLine));
    num_lines_col = str2double(string(Tmeta.TLO_NumLines));
    line_sets = cell(height(Tmeta),1);
    for i = 1:height(Tmeta)
        line_sets{i} = parse_line_set(Tmeta.TLO_lines(i));
    end

    nrows = numel(split_names) * numel(physical_classes) * L;
    Split = strings(nrows,1);
    Scenario = strings(nrows,1);
    BranchID = zeros(nrows,1);
    EligibleAnchor = false(nrows,1);
    IneligibleAnchor = false(nrows,1);
    ScenarioSplitRuns = zeros(nrows,1);
    ExpectedMinimumAnchorRuns = zeros(nrows,1);
    AnchorRuns = zeros(nrows,1);
    PositiveRuns = zeros(nrows,1);
    SingleLineRuns = zeros(nrows,1);
    MultiLineRuns = zeros(nrows,1);

    row = 0;
    for si = 1:numel(split_names)
        for ci = 1:numel(physical_classes)
            group_mask = split_col == split_names(si) & class_col == physical_classes(ci);
            group_n = nnz(group_mask);
            expected_min = floor(group_n / numel(eligible_lines));
            group_indices = find(group_mask);
            for ell = 1:L
                row = row + 1;
                included = false(height(Tmeta),1);
                for jj = 1:numel(group_indices)
                    i = group_indices(jj);
                    included(i) = any(line_sets{i} == ell);
                end

                Split(row) = split_names(si);
                Scenario(row) = physical_classes(ci);
                BranchID(row) = ell;
                EligibleAnchor(row) = ismember(ell,eligible_lines);
                IneligibleAnchor(row) = ismember(ell,ineligible_lines);
                ScenarioSplitRuns(row) = group_n;
                ExpectedMinimumAnchorRuns(row) = expected_min;
                AnchorRuns(row) = nnz(group_mask & anchor_col == ell);
                PositiveRuns(row) = nnz(group_mask & included);
                SingleLineRuns(row) = nnz(group_mask & included & num_lines_col == 1);
                MultiLineRuns(row) = nnz(group_mask & included & num_lines_col > 1);
            end
        end
    end

    Tcoverage = table(Split, Scenario, BranchID, EligibleAnchor, IneligibleAnchor, ...
        ScenarioSplitRuns, ExpectedMinimumAnchorRuns, AnchorRuns, PositiveRuns, ...
        SingleLineRuns, MultiLineRuns);
    writetable(Tcoverage, output_file);

    if do_assert
        eligible_rows = Tcoverage.EligibleAnchor;
        assert(all(Tcoverage.AnchorRuns(eligible_rows) >= Tcoverage.ExpectedMinimumAnchorRuns(eligible_rows)), ...
            'Realized anchor coverage fell below the balanced-plan minimum.');
        assert(all(Tcoverage.AnchorRuns(Tcoverage.IneligibleAnchor) == 0), ...
            'An ineligible line appeared as an anchor.');
        assert(all(Tcoverage.PositiveRuns(Tcoverage.IneligibleAnchor) == 0), ...
            'An ineligible line appeared in an accepted outage set.');
        assert(all(num_lines_col <= 2), ...
            'A realized run exceeded the final primary maximum of two outaged lines.');
    end
end
