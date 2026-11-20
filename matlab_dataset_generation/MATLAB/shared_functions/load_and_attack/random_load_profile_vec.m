function scale = random_load_profile_vec(T)
    rb = @(a,b) (a + (b-a).*rand);
    kind = randi(3);
    scale = zeros(T,1);

    switch kind
        case 1
            A   = 0.05 + 0.20*rand;
            w   = 2*pi / randi([80,200]);
            phi = 2*pi*rand;
            base= 0.85 + 0.25*rand;
            jit = 0.01*randn(T,1);
            for t=1:T
                scale(t) = base + A*sin(w*t + phi) + jit(t);
            end
        case 2
            start = 0.8 + 0.1*rand;
            slope = rb(-0.002, 0.002);
            for t=1:T
                scale(t) = start + slope*(t-1);
            end
        case 3
            base = 0.9 + 0.1*rand;
            step = rb(0.005, 0.02);
            scale(1) = base;
            for t=2:T
                scale(t) = scale(t-1) + step*randn;
            end
    end
    scale = min(1.3, max(0.6, scale));
end
