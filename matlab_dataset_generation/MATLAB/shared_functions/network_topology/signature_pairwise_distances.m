function [minimum_distance, mean_distance] = signature_pairwise_distances(signature_rows)
    n = size(signature_rows,1);
    if n < 2
        minimum_distance = 0;
        mean_distance = 0;
        return;
    end
    values = zeros(n*(n-1)/2,1);
    q = 0;
    for i = 1:n-1
        for j = i+1:n
            q = q + 1;
            values(q) = norm(signature_rows(i,:) - signature_rows(j,:), 2);
        end
    end
    minimum_distance = min(values);
    mean_distance = mean(values);
end
