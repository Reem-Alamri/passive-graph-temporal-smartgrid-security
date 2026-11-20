function on = is_cyber_active_time(run, t)
    on = false;
    if isfield(run,'CCPA') && ~isempty(run.CCPA)
        if t >= run.CCPA.t_FDIA, on = true; return; end
    end
    if isfield(run,'FDIA') && ~isempty(run.FDIA)
        if t >= run.FDIA.t0, on = true; return; end
    end
end
