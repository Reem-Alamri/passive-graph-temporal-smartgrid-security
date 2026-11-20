function rank_values = rank_descending_nan(values)
    values = values(:);
    rank_values = NaN(size(values));
    valid = find(isfinite(values));
    if isempty(valid), return; end
    [~, order] = sort(values(valid), 'descend');
    rank_values(valid(order)) = (1:numel(valid))';
end
