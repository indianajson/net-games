-- widgets/sprite-dimension-cache.lua
-- Caches sprite dimensions from animation files
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local SpriteDimensionCache = {}
local _dimension_cache = {} -- texture_path|anim_path|anim_state -> {width, height}

function SpriteDimensionCache.get_dimensions(texture_path, anim_path, anim_state)
    if not texture_path then
        debug_print("ERROR", "get_dimensions: texture_path is nil!")
        return 0, 0
    end

    local key = texture_path .. "|" .. (anim_path or "no_anim") .. "|" ..
                    (anim_state or "")

    debug_print("VERBOSE",
                "get_dimensions called: texture=%s, anim=%s, state=%s",
                texture_path, anim_path or "nil", anim_state or "nil")

    if _dimension_cache[key] then
        debug_print("VERBOSE", "Cache hit for key: %s = %dx%d", key,
                    _dimension_cache[key].width, _dimension_cache[key].height)
        return _dimension_cache[key].width, _dimension_cache[key].height
    end

    debug_print("INFO", "Cache miss for key: %s, parsing...", key)

    -- If no anim_path is provided, try to guess it
    local actual_anim_path = anim_path
    if not actual_anim_path and texture_path then
        -- Try common animation file extensions
        if texture_path:match("%.png$") then
            actual_anim_path = texture_path:gsub("%.png$", ".anim")
        else
            actual_anim_path = texture_path .. ".anim"
        end
        debug_print("VERBOSE", "Guessed anim_path: %s", actual_anim_path)
    end

    if not actual_anim_path then
        debug_print("WARN",
                    "No animation path provided or guessed, using fallback 0x0")
        _dimension_cache[key] = {width = 0, height = 0}
        return 0, 0
    end

    -- Try to parse the animation file
    local elements, errors = utils.parse_animation_file(actual_anim_path)

    debug_print("VERBOSE", "Parser result: elements count=%d, errors count=%d",
                elements and #elements or 0, errors and #errors or 0)

    if elements and #elements > 0 then
        local width, height = 0, 0

        -- Look for any frame
        for _, element in ipairs(elements) do
            if element.text == "frame" then
                -- Try different attribute names for width and height
                width = utils.get_element_attribute_int(element, "w", 0)
                height = utils.get_element_attribute_int(element, "h", 0)

                -- If w/h not found, try alternative names
                if width == 0 then
                    width = utils.get_element_attribute_int(element,
                                                            "frame_width", 0)
                end
                if height == 0 then
                    height = utils.get_element_attribute_int(element,
                                                             "frame_height", 0)
                end

                -- If still not found, try width/height without frame_ prefix
                if width == 0 then
                    width = utils.get_element_attribute_int(element, "width", 0)
                end
                if height == 0 then
                    height = utils.get_element_attribute_int(element, "height",
                                                             0)
                end

                if width > 0 and height > 0 then
                    debug_print("DETAILED",
                                "Found frame dimensions: %dx%d (using attributes w/h)",
                                width, height)
                    break
                end
            end
        end

        if width == 0 or height == 0 then
            debug_print("WARN",
                        "Could not find frame dimensions in animation file: %s",
                        actual_anim_path)
            width, height = 0, 0
        end

        -- Cache the dimensions (in original sprite pixels)
        _dimension_cache[key] = {width = width, height = height}
        debug_print("INFO", "Cached dimensions for %s: %dx%d", key, width,
                    height)
        return width, height
    else
        -- Parse failed or no elements, use fallback
        debug_print("WARN",
                    "Failed to parse animation file or no elements: %s, using fallback 0x0",
                    actual_anim_path)
        _dimension_cache[key] = {width = 0, height = 0}
        return 0, 0
    end
end

function SpriteDimensionCache.clear()
    _dimension_cache = {}
    debug_print("INFO", "Cleared dimension cache")
end

function SpriteDimensionCache.stats()
    local count = 0
    for _ in pairs(_dimension_cache) do count = count + 1 end
    debug_print("INFO", "Dimension cache: %d entries", count)
    return count
end

return SpriteDimensionCache
