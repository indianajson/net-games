local tiled_utils = {}

function tiled_utils.check_custom_prop_validity(object_props, custom_prop_name, empty_string_is_valid)
    local empty_string_is_check = false
    local result = false

    if object_props == nil then return end
    if custom_prop_name == nil then return end
    
    if empty_string_is_valid ~= nil then
    empty_string_is_check = empty_string_is_valid
    end
    
    if empty_string_is_check then
        if object_props[custom_prop_name] ~= nil then 
        result = true
        end
    end
    
    if object_props[custom_prop_name] ~= nil and object_props[custom_prop_name] ~= "" then
        result = true
    end
    return result    
end

return tiled_utils