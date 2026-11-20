function det = detect_label_persistent(events, t_end)
    tT = inf; tF = inf;
    if isfield(events,'TLO_times')  && ~isempty(events.TLO_times),  tT = min(events.TLO_times);  end
    if isfield(events,'FDIA_times') && ~isempty(events.FDIA_times), tF = min(events.FDIA_times); end
    activeT = isfinite(tT) && (t_end >= tT);
    activeF = isfinite(tF) && (t_end >= tF);

    if ~activeT && ~activeF
        det = "NORMAL";
    elseif activeT && ~activeF
        det = "TLO";
    elseif ~activeT && activeF
        det = "FDIA";
    else
        if isfield(events,'CCPA_type') && strcmpi(events.CCPA_type,"PARTIAL")
            det = "CCPA_PARTIAL";
        else
            det = "CCPA_FULL";
        end
    end
end
