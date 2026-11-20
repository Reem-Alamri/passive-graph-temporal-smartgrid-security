function [WinList, YdList, YlList, idxList, WinClassList] = windows_all(run, T_win, stride, CLASS_NAMES, L)
    T = run.T_total;
    WinList = {}; YdList = {}; YlList = {}; idxList = {};
    WinClassList = strings(0,1);

    for ts = 1:stride:(T - T_win + 1)
        te = ts + T_win - 1;

        det_name = detect_label_persistent(run.events, te);
        WinClassList(end+1,1) = string(det_name);

        ydet = zeros(1, numel(CLASS_NAMES));
        k = find(CLASS_NAMES == string(det_name), 1);
        if isempty(k), k = 1; end
        ydet(k) = 1;

        yloc = zeros(1, L);
        for tt = ts:te
            yloc = yloc | run.edge_outage(tt,:);
        end

        WinList{end+1} = [ts, te];
        YdList{end+1}  = ydet;
        YlList{end+1}  = yloc;
        idxList{end+1} = struct('ts', ts, 'te', te);
    end
end
