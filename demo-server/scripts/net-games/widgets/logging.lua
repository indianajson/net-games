-- widgets/widget-logging.lua
-- Logging module for the widget system

local LOGGING = {}
local DEBUG_LEVELS = {
    ERROR = 1,
    WARN = 2,
    INFO = 3,
    DETAILED = 4,
    VERBOSE = 5
}
local current_level = DEBUG_LEVELS.INFO
local debug_enabled = false

function LOGGING.set_debug_level(level)
    if type(level) == "string" then
        current_level = DEBUG_LEVELS[level:upper()] or DEBUG_LEVELS.INFO
    elseif type(level) == "number" then
        current_level = math.max(1, math.min(5, level))
    end
end

function LOGGING.get_debug_level()
    return current_level
end

function LOGGING.enable_debug()
    debug_enabled = true
end

function LOGGING.disable_debug()
    debug_enabled = false
end

function LOGGING.is_debug_enabled()
    return debug_enabled
end

function LOGGING.debug_print(level, message, ...)
    if not debug_enabled then return end
    
    local level_num = DEBUG_LEVELS[level:upper()] or 0
    if level_num <= current_level then
        local success, formatted = pcall(string.format, message, ...)
        if success then
            print("[Widgets:" .. level:upper() .. "] " .. formatted)
        else
            print("[Widgets:" .. level:upper() .. "] ERROR formatting message: " .. tostring(message))
        end
    end
end

function LOGGING.error(message, ...)
    LOGGING.debug_print("ERROR", message, ...)
end

function LOGGING.warn(message, ...)
    LOGGING.debug_print("WARN", message, ...)
end

function LOGGING.info(message, ...)
    LOGGING.debug_print("INFO", message, ...)
end

function LOGGING.detailed(message, ...)
    LOGGING.debug_print("DETAILED", message, ...)
end

function LOGGING.verbose(message, ...)
    LOGGING.debug_print("VERBOSE", message, ...)
end

return LOGGING