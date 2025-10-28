local TableUtils = {}

function TableUtils.Contains(tbl, value)
    local found = false
    for _, v in pairs(tbl) do
        if v == value then 
            found = true 
        end
    end
    return found
end

--- Creates a deep copy of a table, optionally ignoring specified keys
function TableUtils.deepCopy(obj, ignoreKeys, seen)
    -- Handle non-tables and previously-seen tables
    if type(obj) ~= 'table' then return obj end
    seen = seen or {}
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
        res[TableUtils.deepCopy(k, ignoreKeys, seen)] = TableUtils.deepCopy(v, ignoreKeys, seen)
        ::skip_key::
    end
    
    -- Restore metatable if original had one
    if mt then
        setmetatable(res, mt)
    end
    return res
end

function TableUtils.GetAllTiledObjOfXType(area_id, type)
    local objects = Net.list_objects(area_id)
    local results = {}
    for i, object_id in next, objects do
        local object = Net.get_object_by_id(area_id, object_id)
        object_id = tostring(object_id)
        if object.type == type or object.class == type then
            table.insert(results, object)
        end
    end
    return results
end

function TableUtils.SelectRandomItemsFromTableClamped(tbl, limit)
    -- Check if inputs are valid
    if not tbl or limit <= 0 then return {} end

    -- Ensure we don't exceed table length
    local new_count = math.min(limit, #tbl)

    -- Create a copy of the original table
    local tempTable = {}
    for i = 1, #tbl do
        tempTable[i] = tbl[i]
    end

    -- Create result table
    local result = {}

    -- Select random items
    for i = 1, new_count do
        -- Get random index from remaining items
        local randomIndex = math.random(#tempTable)

        -- Add selected item to result
        table.insert(result, tempTable[randomIndex])

        -- Remove selected item from temporary table
        table.remove(tempTable, randomIndex)
    end

    return result
end


function TableUtils.deepSearch(tbl, searchKey, searchValue, path)
    -- Initialize path tracking if not provided
    path = path or {}
    
    -- Track current position in path
    local currentPosition = #path + 1
    
    -- Iterate through all key-value pairs in the table
    for k, v in pairs(tbl) do
        -- Create current path string for debugging
        local currentPath = table.concat(path, ".") .. "." .. tostring(k)
        
        -- Check if we're looking for a specific key
        if searchKey ~= nil and k == searchKey then
            return true, currentPath
        end
        
        -- Check if we're looking for a specific value
        if searchValue ~= nil and v == searchValue then
            return true, currentPath
        end
        
        -- If value is a table, recurse into it
        if type(v) == "table" then
            local found, fullPath = TableUtils.deepSearch(v, searchKey, searchValue, path)
            
            -- If something was found in the recursive call, return it
            if found then
                return true, fullPath
            end
        end
    end
    
    -- Nothing found in this branch
    return false, nil
end

-- Helper function to format results nicely
function TableUtils.searchTable(tbl, searchKey, searchValue)
    local found, path = TableUtils.deepSearch(tbl, searchKey, searchValue)
    if found then
        print(path)
        return path
    else
        return nil
    end
end

function TableUtils.shallow_copy(original)
  local copy = {}

  for key, value in pairs(original) do
    copy[key] = value
  end

  return copy
end

function TableUtils.shuffle(tbl)
    local shuffled = {}
    for i = 1, #tbl do
        shuffled[i] = tbl[i]
    end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    return shuffled
end

return TableUtils