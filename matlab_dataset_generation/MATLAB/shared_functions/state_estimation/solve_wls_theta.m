function theta_hat = solve_wls_theta(H, y, w, lambda, min_rcond_A)
    W = spdiags(w(:), 0, numel(w), numel(w));
    A = (H' * W * H) + lambda * speye(size(H,2));
    if rcond(full(A)) < min_rcond_A
        theta_hat = NaN(size(H,2),1);
        return;
    end
    b = (H' * W * y);
    theta_hat = A \ b;
end
