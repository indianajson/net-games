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

return TableUtils