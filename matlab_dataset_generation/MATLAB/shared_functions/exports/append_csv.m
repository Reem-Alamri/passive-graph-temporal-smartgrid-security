function append_csv(T, filename)
    if isfile(filename)
        writetable(T, filename, 'WriteMode','append', 'WriteVariableNames', false, 'FileType','text');
    else
        writetable(T, filename, 'WriteVariableNames', true, 'FileType','text');
    end
end
