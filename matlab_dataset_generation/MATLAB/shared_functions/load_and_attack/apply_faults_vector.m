function [x, stuck_cnt, stuck_val, out_ct, miss_ct, stuck_events_ct] = apply_faults_vector( ...
    x, sigma, stuck_cnt, stuck_val, p_outlier, outlier_k_rng, p_missing, p_stuck, stuck_len_rng)

    is_stuck = stuck_cnt > 0;
    x(is_stuck) = stuck_val(is_stuck);
    stuck_cnt(is_stuck) = stuck_cnt(is_stuck) - 1;

    out_ct = 0; miss_ct = 0; stuck_events_ct = 0;
    M = numel(x);

    can_start = (stuck_cnt == 0) & isfinite(x);
    start_stuck = can_start & (rand(M,1) < p_stuck);
    if any(start_stuck)
        len = randi([stuck_len_rng(1), stuck_len_rng(2)], nnz(start_stuck), 1);
        stuck_cnt(start_stuck) = len;
        stuck_val(start_stuck) = x(start_stuck);
        stuck_events_ct = stuck_events_ct + nnz(start_stuck);
    end

    can_miss = isfinite(x) & (stuck_cnt == 0);
    miss = can_miss & (rand(M,1) < p_missing);
    if any(miss)
        x(miss) = NaN;
        miss_ct = miss_ct + nnz(miss);
    end

    can_out = isfinite(x) & (stuck_cnt == 0);
    out = can_out & (rand(M,1) < p_outlier);
    if any(out)
        k = rand_between(outlier_k_rng(1), outlier_k_rng(2));
        x(out) = x(out) + k * sigma(out) .* randn(nnz(out),1);
        out_ct = out_ct + nnz(out);
    end
end
