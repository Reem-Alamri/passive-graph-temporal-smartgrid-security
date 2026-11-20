function lines = parse_line_set(value)

    if iscell(value)
        if isempty(value)
            lines = [];
            return;
        end
        value = value{1};
    end

    if isempty(value)
        lines = [];
        return;
    end

    if isnumeric(value)
        numeric_values = value(isfinite(value));
        lines = unique(round(numeric_values(:)'));
        return;
    end

    sv = string(value);
    if isempty(sv) || any(ismissing(sv(:)))
        lines = [];
        return;
    end

    sv = strtrim(sv(1));
    if strlength(sv) == 0 || strcmpi(sv, "NaN") || strcmpi(sv, "<missing>")
        lines = [];
        return;
    end

    s = char(sv);
    s = regexprep(s, '[\[\],;]', ' ');
    lines = sscanf(s, '%f')';
    lines = unique(round(lines(isfinite(lines))));
end
