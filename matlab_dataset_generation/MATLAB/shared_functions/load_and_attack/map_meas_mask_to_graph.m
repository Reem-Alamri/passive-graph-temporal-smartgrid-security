function [bus_mask, branch_mask] = map_meas_mask_to_graph(meas_mask, keep_b, N, L)
    nb1 = numel(keep_b);
    bus_mask = zeros(N,1);
    branch_mask = zeros(L,1);

    mbus = meas_mask(1:nb1);
    mbr  = meas_mask(nb1+1:nb1+L);

    bus_mask(keep_b) = mbus(:);
    branch_mask(:) = mbr(:);
end
