-- widget-logging.lua
-- Generic logging and debugging module
-- Version 2.0 - No file I/O, console only

local LOGGING = {}
LOGGING.__index = LOGGING

-- Debug configuration
LOGGING.DEBUG = true
LOGGING.DEBUG_LEVEL = "DETAILED" -- "BASIC", "DETAILED", "VERBOSE"
LOGGING.COLORS_ENABLED = true

-- Severity levels mapping
LOGGING.SEVERITY_LEVELS = {
    VERBOSE = 1,
    DETAILED = 2,
    INFO = 3,
    WARN = 4,
    ERROR = 5
}

-- Color codes for console output
LOGGING.COLORS = {
    RESET = "\27[0m",
    RED = "\27[31m",
    GREEN = "\27[32m",
    YELLOW = "\27[33m",
    BLUE = "\27[34m",
    MAGENTA = "\27[35m",
    CYAN = "\27[36m",
    WHITE = "\27[37m",
    GRAY = "\27[90m"
}

LOGGING.get_severity_value = function(severity)
    return LOGGING.SEVERITY_LEVELS[severity:upper()] or LOGGING.SEVERITY_LEVELS.INFO
end

LOGGING.should_log = function(level)
    if not LOGGING.DEBUG then return false end
    local current_level_value = LOGGING.get_severity_value(LOGGING.DEBUG_LEVEL)
    local message_level_value = LOGGING.get_severity_value(level)
    return message_level_value >= current_level_value
end

LOGGING.get_color_for_level = function(level)
    if not LOGGING.COLORS_ENABLED then return "", "" end
    
    local level_upper = level:upper()
    if level_upper == "ERROR" then
        return LOGGING.COLORS.RED, LOGGING.COLORS.RESET
    elseif level_upper == "WARN" then
        return LOGGING.COLORS.YELLOW, LOGGING.COLORS.RESET
    elseif level_upper == "INFO" then
        return LOGGING.COLORS.GREEN, LOGGING.COLORS.RESET
    elseif level_upper == "DETAILED" then
        return LOGGING.COLORS.CYAN, LOGGING.COLORS.RESET
    elseif level_upper == "VERBOSE" then
        return LOGGING.COLORS.GRAY, LOGGING.COLORS.RESET
    else
        return LOGGING.COLORS.WHITE, LOGGING.COLORS.RESET
    end
end

LOGGING.format_log_message = function(level, message, ...)
    local timestamp = os.date("%H:%M:%S")
    local formatted_message = message
    
    -- Format message with arguments if provided
    if ... then
        local args = {...}
        formatted_message = string.format(message, table.unpack(args))
    end
    
    return string.format("[%s] [%s] %s", timestamp, level:upper(), formatted_message)
end

LOGGING.debug_print = function(level, message, ...)
    if not LOGGING.should_log(level) then
        return
    end
    
    local formatted_message = LOGGING.format_log_message(level, message, ...)
    local color_start, color_end = LOGGING.get_color_for_level(level)
    
    print(color_start .. formatted_message .. color_end)
end

-- Public API
return {
    -- Core logging function
    debug_print = LOGGING.debug_print,
    
    -- Configuration
    set_debug_level = function(level)
        if LOGGING.SEVERITY_LEVELS[level:upper()] then
            LOGGING.DEBUG_LEVEL = level:upper()
            LOGGING.debug_print("INFO", "Debug level set to: %s", LOGGING.DEBUG_LEVEL)
            return true
        end
        return false
    end,
    
    enable_debug = function()
        LOGGING.DEBUG = true
        LOGGING.debug_print("INFO", "Debug enabled")
    end,
    
    disable_debug = function()
        LOGGING.DEBUG = false
        -- Can't use debug_print here since debug is disabled
        print("[Widgets] Debug disabled")
    end,
    
    enable_colors = function()
        LOGGING.COLORS_ENABLED = true
        LOGGING.debug_print("INFO", "Console colors enabled")
    end,
    
    disable_colors = function()
        LOGGING.COLORS_ENABLED = false
        LOGGING.debug_print("INFO", "Console colors disabled")
    end,
    
    get_debug_level = function()
        return LOGGING.DEBUG_LEVEL
    end,
    
    is_debug_enabled = function()
        return LOGGING.DEBUG
    end,
    
    -- Utility: Get all severity levels
    get_severity_levels = function()
        local levels = {}
        for name, value in pairs(LOGGING.SEVERITY_LEVELS) do
            table.insert(levels, name)
        end
        return levels
    end,
    
    -- Quick logging functions (optional shortcuts)
    verbose = function(message, ...)
        LOGGING.debug_print("VERBOSE", message, ...)
    end,
    
    detailed = function(message, ...)
        LOGGING.debug_print("DETAILED", message, ...)
    end,
    
    info = function(message, ...)
        LOGGING.debug_print("INFO", message, ...)
    end,
    
    warn = function(message, ...)
        LOGGING.debug_print("WARN", message, ...)
    end,
    
    error = function(message, ...)
        LOGGING.debug_print("ERROR", message, ...)
    end
}