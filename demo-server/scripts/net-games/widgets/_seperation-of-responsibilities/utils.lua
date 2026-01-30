-- widgets/utils.lua
-- Utility functions for the widget system

local trim = require('scripts/net-games/avatar_utils/lua_yes_parser/src/utils/trim')
local lib = require('scripts/net-games/avatar_utils/lua_yes_parser/lib')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print

local utils = {}

-- Table utilities
function utils.table_count(t)
    local count = 0
    if t then
        for _ in pairs(t) do count = count + 1 end
    end
    return count
end

function utils.table_deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.table_deepcopy(orig_key)] = utils.table_deepcopy(orig_value)
        end
        setmetatable(copy, utils.table_deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function utils.table_contains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

-- ID generation
function utils.generate_unique_id(prefix)
    local random_part = tostring(math.random(10000, 99999))
    local time_part = tostring(os.time()):sub(-6)
    return (prefix or "id") .. "_" .. time_part .. "_" .. random_part
end

-- Animation module loading
function utils.load_animation_modules()
    local AnimationEngine, AnimationSequences, AnimationEnums
    
    local success, engine = pcall(require, 'scripts/net-games/animation-engine/animation-engine')
    if success then
        AnimationEngine = engine
        debug_print("INFO", "AnimationEngine loaded successfully")
    else
        debug_print("ERROR", "Failed to load AnimationEngine: %s", engine)
        AnimationEngine = nil
    end
    
    local success2, sequences = pcall(require, 'scripts/net-games/animation-engine/animation-sequences')
    if success2 then
        AnimationSequences = sequences
        debug_print("INFO", "AnimationSequences loaded successfully")
    else
        debug_print("ERROR", "Failed to load AnimationSequences: %s", sequences)
        AnimationSequences = nil
    end
    
    local success3, enums = pcall(require, 'scripts/net-games/animation-engine/animation-enums')
    if success3 then
        AnimationEnums = enums
        debug_print("INFO", "AnimationEnums loaded successfully")
    else
        debug_print("ERROR", "Failed to load AnimationEnums: %s", enums)
        AnimationEnums = nil
    end
    
    return AnimationEngine, AnimationSequences, AnimationEnums
end

-- Parser helper functions
function utils.parse_animation_file(file_path)
    if not file_path or file_path == "" then
        debug_print("WARN", "parse_animation_file: Empty file path")
        return nil, {}
    end
    
    local success, elements, errors = pcall(lib.parse, file_path)
    
    if not success then
        debug_print("ERROR", "parse_animation_file: Failed to parse %s - %s", file_path, elements)
        return nil, { { line = 1, type = "FILE_READ_ERROR" } }
    end
    
    if errors and #errors > 0 then
        debug_print("WARN", "parse_animation_file: Found %d errors in %s", #errors, file_path)
        for i, err in ipairs(errors) do
            debug_print("WARN", "  Line %d: %s", err.line, err.type)
        end
    end
    
    return elements, errors or {}
end

function utils.get_element_attribute(element, attr_name, default_value)
    if not element or not element.getKeyValue then
        return default_value
    end
    
    local value = element:getKeyValue(attr_name)
    if value == nil or value == "" then
        return default_value
    end
    
    -- Try to parse as integer
    local num_value = tonumber(value)
    if num_value then
        return num_value
    end
    
    return value
end

function utils.get_element_attribute_int(element, attr_name, default_value)
    if not element or not element.getKeyValueAsInt then
        return default_value or 0
    end
    
    return element:getKeyValueAsInt(attr_name, default_value or 0)
end

-- Expose table_deepcopy globally for backward compatibility
if not table.deepcopy then
    table.deepcopy = utils.table_deepcopy
end

return utils