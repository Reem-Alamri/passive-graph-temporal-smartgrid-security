function ok = is_connected_to_slack(mpc, slack, F_BUS, T_BUS, BR_STATUS)
    N = size(mpc.bus,1);
    st = (mpc.branch(:,BR_STATUS) > 0);
    fb = mpc.branch(st, F_BUS);
    tb = mpc.branch(st, T_BUS);
    G = graph(fb, tb, [], N);
    comp = conncomp(G);
    ok = all(comp == comp(slack));
end
