local Copier = {}
function Copier.deepCopy(obj, ignoreKeys, seen)
    -- Handle non-tables and previously-seen tables
    if type(obj) ~= 'table' then return obj end
    seen = seen or {}
    
    -- Check if we've seen this table before
    if seen[obj] then return seen[obj] end
    
    -- Create new table and mark it as seen
    local res = {}
    seen[obj] = res
    
    -- Handle metatables separately
    local mt = getmetatable(obj)
    if mt then
        setmetatable(res, {})
    end
    
    -- Copy all keys except ignored ones
    for k, v in next, obj do
        if ignoreKeys and ignoreKeys[k] then
            goto skip_key
        end
        
        res[Copier.deepCopy(k, ignoreKeys, seen)] = Copier.deepCopy(v, ignoreKeys, seen)
        ::skip_key::
    end
    
    -- Restore metatable if original had one
    if mt then
        setmetatable(res, mt)
    end
    
    return res
end
return Copier