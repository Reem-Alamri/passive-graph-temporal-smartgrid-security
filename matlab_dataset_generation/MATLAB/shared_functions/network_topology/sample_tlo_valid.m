function [ok, lines_set, Hp, ap] = sample_tlo_valid( ...
    mpc0, run, H, PD, VA, BR_STATUS, F_BUS, T_BUS, ...
    max_try, k_min, k_max, min_rcond_B, anchor_line, eligible_lines)

    if nargin<9,  max_try=30; end
    if nargin<10, k_min=1; end
    if nargin<11, k_max=2; end
    if nargin<12, min_rcond_B=1e-12; end
    if nargin<13, anchor_line=NaN; end
    if nargin<14 || isempty(eligible_lines), eligible_lines=1:size(mpc0.branch,1); end

    assert(k_min >= 1 && k_max <= 2 && k_min <= k_max, ...
        'Primary outage cardinality must remain within one or two lines.');
    assert(isfinite(anchor_line) && ismember(anchor_line, eligible_lines), ...
        'Physical scenario requires a finite eligible planned anchor line.');

    ok = false; Hp = []; ap = []; lines_set = [];

    for attempt=1:max_try
        k = randi([k_min, k_max]);
        k = min(k, min(2, numel(eligible_lines)));
        lines_try = sample_lines_uniform_anchor(eligible_lines, k, anchor_line);

        [ok_try, Hp_try, ap_try] = evaluate_tlo_candidate( ...
            mpc0, run, H, PD, VA, BR_STATUS, F_BUS, T_BUS, lines_try, min_rcond_B);

        if ok_try
            ok = true;
            lines_set = lines_try;
            Hp = Hp_try;
            ap = ap_try;
            return;
        end
    end

    if k_min <= 1
        lines_try = anchor_line;
        [ok_try, Hp_try, ap_try] = evaluate_tlo_candidate( ...
            mpc0, run, H, PD, VA, BR_STATUS, F_BUS, T_BUS, lines_try, min_rcond_B);
        if ok_try
            ok = true;
            lines_set = lines_try;
            Hp = Hp_try;
            ap = ap_try;
        end
    end
end
