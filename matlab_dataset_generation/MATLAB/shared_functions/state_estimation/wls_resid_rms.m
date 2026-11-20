function r = wls_resid_rms(H, y, w, theta_hat)
    if isempty(y) || any(isnan(theta_hat))
        r = NaN;
        return;
    end
    e = y - H*theta_hat;
    ew = sqrt(w(:)) .* e;
    r = sqrt(mean(ew.^2));
end
