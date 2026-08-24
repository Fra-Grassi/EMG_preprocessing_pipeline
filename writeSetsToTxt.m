function writeSetsToTxt(S, filename)
    fid = fopen(filename, 'w');
    assert(fid ~= -1, 'Could not open file for writing.');

    pairs = flattenStruct(S, "");

    for i = 1:size(pairs, 1)
        fprintf(fid, "%s\t: %s\n", ...
            pairs{i,1}, valueToString(pairs{i,2}));
    end

    fclose(fid);
end

% ===== Local helper functions (private) =====

function pairs = flattenStruct(S, prefix)
% Returns Nx2 cell array: {path, value}

pairs = {};

if ~isstruct(S)
    % Leaf value
    pairs = {char(prefix), S};
    return;
end

% Struct array case (e.g., component(1), component(2), ...)
if numel(S) > 1
    for k = 1:numel(S)
        idxPrefix = prefix;
        if strlength(idxPrefix) == 0
            idxPrefix = sprintf("(%d)", k); % rare case: top-level is array
        else
            idxPrefix = sprintf("%s(%d)", prefix, k);
        end
        pairs_k = flattenStruct(S(k), idxPrefix);
        pairs   = [pairs; pairs_k]; %#ok<AGROW>
    end
    return;
end

% Scalar struct: iterate fields
fn = fieldnames(S);
for i = 1:numel(fn)
    f = fn{i};
    if strlength(prefix) == 0
        newPrefix = string(f);
    else
        newPrefix = prefix + "." + string(f);
    end
    pairs_f = flattenStruct(S.(f), newPrefix);
    pairs   = [pairs; pairs_f]; %#ok<AGROW>
end
end

function str = valueToString(value)

if isnumeric(value)
    if isscalar(value)
        str = num2str(value);
    else
        str = mat2str(value);
    end

elseif islogical(value)
    str = mat2str(value);

elseif ischar(value)
    str = value;

elseif isstring(value)
    if isscalar(value)
        str = char(value);
    else
        str = "[" + strjoin(string(value), ", ") + "]";
    end

elseif iscell(value)
    try
        parts = cellfun(@valueToString, value, 'UniformOutput', false);
        str = "{"+ strjoin(string(parts), ", ") +"}";
    catch
        str = "[cell]";
    end

elseif isstruct(value)
    % Normally flattenStruct would have handled this, but just in case:
    if isempty(fieldnames(value))
        str = "[struct (empty)]";
    else
        str = "[struct]";
    end

else
    str = "[" + string(class(value)) + "]";
end

str = char(str);
end


