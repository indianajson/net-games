local DEBUG_UTILS = {
    debug = true,
}

function DEBUG_UTILS.dprint(component_name, message)
    if DEBUG_UTILS.debug == true then
        print("[" ..string.upper(component_name) .."]: ", message)
    end
end

return DEBUG_UTILS