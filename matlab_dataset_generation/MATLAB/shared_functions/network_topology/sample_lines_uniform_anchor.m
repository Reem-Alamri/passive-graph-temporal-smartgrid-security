function lines_set = sample_lines_uniform_anchor(eligible_lines, k, anchor_line)

    eligible_lines = reshape(eligible_lines, 1, []);
    assert(ismember(anchor_line, eligible_lines), 'Anchor line is not eligible.');
    assert(k == 1 || k == 2, 'Primary sampler supports only one or two lines.');

    if k == 1
        lines_set = anchor_line;
        return;
    end

    remaining = setdiff(eligible_lines, anchor_line, 'stable');
    assert(~isempty(remaining), 'No eligible second line is available.');
    second_line = remaining(randi(numel(remaining)));
    lines_set = sort([anchor_line, second_line]);
end
