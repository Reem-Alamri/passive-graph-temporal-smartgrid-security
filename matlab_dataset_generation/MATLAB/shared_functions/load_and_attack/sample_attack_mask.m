function mask = sample_attack_mask(M, access_ratio)

    k = max(1, round(access_ratio * M));
    idx = randperm(M, k);
    mask = zeros(M,1);
    mask(idx) = 1;
end
