function theta_hat = solve_wls_theta_slack_reference( ...
    H, y, w, lambda, min_rcond_A, slack)

    N = size(H,2);
    slack = unique(round(slack(:)'));
    assert(~isempty(slack) && all(slack >= 1) && all(slack <= N), ...
        'A valid slack-bus index is required for RTU-only WLS.');

    keep = setdiff(1:N, slack, 'stable');
    Hred = H(:, keep);

    W = spdiags(w(:), 0, numel(w), numel(w));
    A = (Hred' * W * Hred) + lambda * speye(numel(keep));

    theta_hat = NaN(N,1);
    if isempty(keep) || rcond(full(A)) < min_rcond_A
        return;
    end

    b = Hred' * W * y;
    theta_red = A \ b;

    theta_hat = zeros(N,1);
    theta_hat(keep) = theta_red;
    theta_hat(slack) = 0;
end
