local tiled_utils = {}

function tiled_utils.check_custom_prop_validity(object, custom_prop_name, empty_string_is_valid)
    local empty_string_is_check = false
    if object == nil then return end
    if custom_prop_name == nil then return end
    
    if empty_string_is_valid ~= nil then
    empty_string_is_check = empty_string_is_valid
    end
    
    if empty_string_is_check then
        if object.custom_properties[custom_prop_name] ~= nil then 
            return true  
        else 
            return false
        end
    end
    
    if object.custom_properties[custom_prop_name] ~= nil and object.custom_properties[custom_prop_name] ~= "" then
        return true 
    else 
        return false
    end
end

return tiled_utils