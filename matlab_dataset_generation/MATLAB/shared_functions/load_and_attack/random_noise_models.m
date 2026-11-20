function noise = random_noise_models(NOISE, PMU, M, nb1, L, N, PMU_BUSES)
    noise.rtu.bus_sigma  = rand_between(NOISE.bus_sigma_rng(1),  NOISE.bus_sigma_rng(2));
    noise.rtu.flow_sigma = rand_between(NOISE.flow_sigma_rng(1), NOISE.flow_sigma_rng(2));
    noise.rtu.rho        = rand_between(NOISE.rho_rng(1),        NOISE.rho_rng(2));
    noise.rtu.bias_std   = rand_between(NOISE.bias_std_rng(1),   NOISE.bias_std_rng(2));
    noise.rtu.sigma_vec  = [noise.rtu.bus_sigma*ones(nb1,1); noise.rtu.flow_sigma*ones(L,1)];
    noise.rtu.bias_vec   = noise.rtu.bias_std * randn(M,1);

    noise.pmu.theta_sigma = rand_between(PMU.theta_sigma_rng(1), PMU.theta_sigma_rng(2));
    noise.pmu.bias_std    = rand_between(PMU.bias_std_rng(1),    PMU.bias_std_rng(2));

    pmu_mask = false(N,1);
    pmu_mask(PMU_BUSES) = true;
    noise.pmu.mask = pmu_mask;

    noise.pmu.bias_vec = zeros(N,1);
    noise.pmu.bias_vec(pmu_mask) = noise.pmu.bias_std * randn(nnz(pmu_mask),1);
end
