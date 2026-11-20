function run = inject_canonical_FDIA(run, t0, c, a, info)
    run.FDIA.t0 = t0;
    run.FDIA.c  = c;
    run.FDIA.a  = a;
    run.FDIA.state_support_size = info.support_size;
    run.FDIA.state_support_ratio = info.support_ratio;
    run.FDIA.base_scale = info.base_scale;
    run.FDIA.amplitude_factor = info.amplitude_factor;
    run.events.FDIA_times(end+1) = t0;
end
