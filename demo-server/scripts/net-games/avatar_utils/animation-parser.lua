-- animation_parser.lua
-- Enhanced animation parser using lua_yes_parser with better structure
local parser = require('scripts/net-games/avatar_utils/lua_yes_parser/lib')

local AnimationParser = {}

-- Helper function to get argument value from args list
local function get_arg_by_key(args, key, transform)
    if not args then return nil end
    
    for _, arg in ipairs(args) do
        if arg.key == key then
            local value = arg.val
            -- Remove quotes from string values
            if type(value) == "string" then
                value = value:gsub('"', '')
            end
            
            if transform then
                return transform(value)
            end
            return value
        end
    end
    return nil
end

-- Helper function to parse duration (compatible with avatar_utils)
local function parse_duration(duration_str)
    if not duration_str then return 0 end
    
    local multi = 1
    if duration_str:sub(-1) == 'f' then
        -- If the duration is in frames, convert to seconds
        duration_str = duration_str:sub(1, -2) -- Remove the 'f'
        -- Assuming 60 FPS for conversion
        multi = 1/60
    end
    local duration = tonumber(duration_str) or 0
    return duration * multi * 1000 -- Convert to milliseconds
end

-- Parse animation file into structured format
function AnimationParser.parse_file(file_path)
    if not file_path or file_path == "" then
        print("[AnimationParser] WARN: Empty file path")
        return nil, {}
    end
    
    local elements, errors = parser.parse(file_path)
    
    if errors and #errors > 0 then
        print("[AnimationParser] WARN: Found " .. #errors .. " errors in " .. file_path)
        for i, err in ipairs(errors) do
            if err.line then
                print("[AnimationParser]   Line " .. err.line .. ": " .. (err.type or "unknown error"))
            else
                print("[AnimationParser]   " .. (err.type or "unknown error"))
            end
        end
    end
    
    -- Process elements to build animation data structure
    local animations = {}
    local current_animation = nil
    local current_attributes = {}
    
    for _, element in ipairs(elements) do
        if element.type == "attribute" then
            -- Store attribute for next animation/frame
            table.insert(current_attributes, element)
        elseif element.type == "standard" then
            if element.text == "animation" then
                -- Start a new animation
                local state = get_arg_by_key(element.args, "state")
                local id = get_arg_by_key(element.args, "id") or state or "animation_" .. #animations + 1
                
                current_animation = {
                    id = id,
                    state = state,
                    frames = {},
                    attributes = {}, -- Will be populated from current_attributes
                    sprite_width = 32, -- Default
                    sprite_height = 32, -- Default
                    total_duration_ms = 0
                }
                
                -- Copy current attributes to this animation
                for _, attr in ipairs(current_attributes) do
                    table.insert(current_animation.attributes, attr)
                end
                
                table.insert(animations, current_animation)
                current_attributes = {} -- Reset attributes for this animation
                
            elseif element.text == "frame" and current_animation then
                -- Parse frame data
                local x = get_arg_by_key(element.args, "x", tonumber) or 0
                local y = get_arg_by_key(element.args, "y", tonumber) or 0
                local w = get_arg_by_key(element.args, "w", tonumber) or 32
                local h = get_arg_by_key(element.args, "h", tonumber) or 32
                local duration_str = get_arg_by_key(element.args, "duration")
                local duration_ms = parse_duration(duration_str)
                local originx = get_arg_by_key(element.args, "originx", tonumber) or 0
                local originy = get_arg_by_key(element.args, "originy", tonumber) or 0
                
                -- Update animation dimensions from first frame
                if #current_animation.frames == 0 then
                    current_animation.sprite_width = w
                    current_animation.sprite_height = h
                end
                
                -- Add frame
                local frame = {
                    x = x,
                    y = y,
                    w = w,
                    h = h,
                    duration_ms = duration_ms,
                    originx = originx,
                    originy = originy,
                    attributes = {} -- Will be populated from current_attributes
                }
                
                -- Copy current attributes to this frame
                for _, attr in ipairs(current_attributes) do
                    table.insert(frame.attributes, attr)
                end
                
                table.insert(current_animation.frames, frame)
                current_animation.total_duration_ms = current_animation.total_duration_ms + duration_ms
                
                current_attributes = {} -- Reset attributes for next frame
            end
        end
    end
    
    local result = {
        animations = animations,
        element_count = #elements,
        animation_count = #animations
    }
    
    return result, errors or {}
end

-- Get frame dimensions from parsed animation data
function AnimationParser.get_frame_dimensions(parsed_result, anim_state)
    if not parsed_result or not parsed_result.animations or #parsed_result.animations == 0 then
        return 32, 32  -- Default fallback
    end
    
    -- Look for animation with matching state
    for _, anim in ipairs(parsed_result.animations) do
        -- If anim_state is specified, match by state
        if anim_state then
            if anim.state and anim.state == anim_state then
                return anim.sprite_width or 32, anim.sprite_height or 32
            elseif anim.id and anim.id:find(anim_state) then
                return anim.sprite_width or 32, anim.sprite_height or 32
            end
        else
            -- No state specified, use first animation
            return anim.sprite_width or 32, anim.sprite_height or 32
        end
    end
    
    -- Fallback to first animation if state not found
    local first_anim = parsed_result.animations[1]
    if first_anim then
        return first_anim.sprite_width or 32, first_anim.sprite_height or 32
    end
    
    return 32, 32  -- Default fallback
end

-- Get frame origin from parsed animation data
function AnimationParser.get_frame_origin(parsed_result, anim_state)
    if not parsed_result or not parsed_result.animations or #parsed_result.animations == 0 then
        return 0, 0
    end
    
    -- Look for animation with matching state
    for _, anim in ipairs(parsed_result.animations) do
        -- Check if this animation matches the state
        if anim_state then
            if anim.state and anim.state == anim_state then
                -- Check frames for origin
                if anim.frames and #anim.frames > 0 then
                    local first_frame = anim.frames[1]
                    return first_frame.originx or 0, first_frame.originy or 0
                end
                -- Check attributes for origin
                if anim.attributes and #anim.attributes > 0 then
                    for _, attr in ipairs(anim.attributes) do
                        if attr.text == "origin" then
                            local ox = get_arg_by_key(attr.args, "x", tonumber) or 
                                      get_arg_by_key(attr.args, "originx", tonumber) or 0
                            local oy = get_arg_by_key(attr.args, "y", tonumber) or 
                                      get_arg_by_key(attr.args, "originy", tonumber) or 0
                            return ox, oy
                        end
                    end
                end
            elseif anim.id and anim.id:find(anim_state) then
                -- Similar logic for ID-based matching
                if anim.frames and #anim.frames > 0 then
                    local first_frame = anim.frames[1]
                    return first_frame.originx or 0, first_frame.originy or 0
                end
                if anim.attributes and #anim.attributes > 0 then
                    for _, attr in ipairs(anim.attributes) do
                        if attr.text == "origin" then
                            local ox = get_arg_by_key(attr.args, "x", tonumber) or 
                                      get_arg_by_key(attr.args, "originx", tonumber) or 0
                            local oy = get_arg_by_key(attr.args, "y", tonumber) or 
                                      get_arg_by_key(attr.args, "originy", tonumber) or 0
                            return ox, oy
                        end
                    end
                end
            end
        else
            -- No state specified, use first animation
            if anim.frames and #anim.frames > 0 then
                local first_frame = anim.frames[1]
                return first_frame.originx or 0, first_frame.originy or 0
            end
            if anim.attributes and #anim.attributes > 0 then
                for _, attr in ipairs(anim.attributes) do
                    if attr.text == "origin" then
                        local ox = get_arg_by_key(attr.args, "x", tonumber) or 
                                  get_arg_by_key(attr.args, "originx", tonumber) or 0
                        local oy = get_arg_by_key(attr.args, "y", tonumber) or 
                                  get_arg_by_key(attr.args, "originy", tonumber) or 0
                        return ox, oy
                    end
                end
            end
        end
    end
    
    -- Fallback to first animation
    local first_anim = parsed_result.animations[1]
    if first_anim then
        if first_anim.frames and #first_anim.frames > 0 then
            local first_frame = first_anim.frames[1]
            return first_frame.originx or 0, first_frame.originy or 0
        end
    end
    
    return 0, 0
end

-- Parse a specific animation from file (cached)
local animation_cache = {}
function AnimationParser.parse_animation(file_path, anim_state)
    local cache_key = file_path .. "|" .. (anim_state or "")
    
    if animation_cache[cache_key] then
        return animation_cache[cache_key]
    end
    
    local parsed_result, errors = AnimationParser.parse_file(file_path)
    
    if not parsed_result or not parsed_result.animations or #parsed_result.animations == 0 then
        return nil, errors
    end
    
    -- Find specific animation if state is provided
    if anim_state then
        for _, anim in ipairs(parsed_result.animations) do
            if anim.state == anim_state or anim.id == anim_state then
                animation_cache[cache_key] = anim
                return anim, errors
            end
        end
    end
    
    -- Return first animation if no state specified
    animation_cache[cache_key] = parsed_result.animations[1]
    return parsed_result.animations[1], errors
end

-- Clear the animation cache
function AnimationParser.clear_cache()
    animation_cache = {}
    print("[AnimationParser] Cache cleared")
end

-- Get animation info (dimensions and origin) in one call
function AnimationParser.get_animation_info(file_path, anim_state)
    local anim, errors = AnimationParser.parse_animation(file_path, anim_state)
    
    if not anim then
        return nil, errors
    end
    
    local info = {
        id = anim.id,
        state = anim.state,
        width = anim.sprite_width or 32,
        height = anim.sprite_height or 32,
        frames = #anim.frames,
        total_duration = anim.total_duration_ms,
        origin = {x = 0, y = 0}
    }
    
    -- Get origin from first frame
    if anim.frames and #anim.frames > 0 then
        local first_frame = anim.frames[1]
        info.origin.x = first_frame.originx or 0
        info.origin.y = first_frame.originy or 0
    end
    
    return info, errors
end

return AnimationParser