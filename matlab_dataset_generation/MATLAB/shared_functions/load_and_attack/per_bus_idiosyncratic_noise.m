function E = per_bus_idiosyncratic_noise(N, T, sigma, rho)

    E = zeros(N, T);
    for i = 1:N
        E(i,1) = sigma*randn;
        for t = 2:T
            E(i,t) = rho*E(i,t-1) + sqrt(max(0, 1-rho^2))*sigma*randn;
        end
    end
end
