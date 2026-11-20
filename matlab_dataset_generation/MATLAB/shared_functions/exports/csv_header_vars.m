function vars = csv_header_vars(filename)
    fid = fopen(filename, 'r');
    assert(fid ~= -1, 'Could not open CSV file: %s', filename);
    cleanupObj = onCleanup(@() fclose(fid));
    header = fgetl(fid);
    assert(ischar(header) || isstring(header), 'CSV file has no header: %s', filename);
    vars = strsplit(string(header), ',');
end
