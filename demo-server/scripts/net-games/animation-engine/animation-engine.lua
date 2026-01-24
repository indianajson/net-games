-- /server/scripts/ezlibs-custom/animation_engine.lua
-- Reusable animation and interpolation engine

local AnimationEngine = {}
_G.AnimationEngine = AnimationEngine
AnimationEngine.__index = AnimationEngine

AnimationEngine.AnimEnums = require("scripts/net-games/animation-engine/animation-enums")

-- ---------------------------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------------------------
local cfg = {
    -- Default interpolation settings
    default_interp_speed = 10, -- units per second
    default_ro_speed = 180, -- degrees per second
    default_color_speed = 5, -- color component change per second
    default_scale_speed = 2, -- scale change per second
    
    -- Easing functions
    easing_functions = {
        linear = function(t) return t end,
        square=function(t) return t*t end,
        cubic=function(t) return t*t*t end,
        ease_in = function(t) return t * t end,
        ease_out = function(t) return t * (2 - t) end,
        ease_in_out = function(t)
            if t < 0.5 then
                return 2 * t * t
            else
                return -1 + (4 - 2 * t) * t
            end
        end,
        smoothstep = function(t) return t * t * (3 - 2 * t) end,
        smootherstep = function(t) return t * t * t * (t * (6 * t - 15) + 10) end,
        -- Elastic easing functions
        elastic_in = function(t)
            if t == 0 or t == 1 then return t end
            local p = 0.3
            local s = p / 4
            return -(2^(10 * (t - 1))) * math.sin((t - 1 - s) * (2 * math.pi) / p)
        end,
        elastic_out = function(t)
            if t == 0 or t == 1 then return t end
            local p = 0.3
            local s = p / 4
            return 2^(-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
        end,
        bounce_out = function(t)
            if t < 1 / 2.75 then
                return 7.5625 * t * t
            elseif t < 2 / 2.75 then
                t = t - 1.5 / 2.75
                return 7.5625 * t * t + 0.75
            elseif t < 2.5 / 2.75 then
                t = t - 2.25 / 2.75
                return 7.5625 * t * t + 0.9375
            else
                t = t - 2.625 / 2.75
                return 7.5625 * t * t + 0.984375
            end
        end,
        bounce_in = function(t)
            t = 1 - t
            if t < 1 / 2.75 then
                return 1 - 7.5625 * t * t
            elseif t < 2 / 2.75 then
                t = t - 1.5 / 2.75
                return 1 - (7.5625 * t * t + 0.75)
            elseif t < 2.5 / 2.75 then
                t = t - 2.25 / 2.75
                return 1 - (7.5625 * t * t + 0.9375)
            else
                t = t - 2.625 / 2.75
                return 1 - (7.5625 * t * t + 0.984375)
            end
        end,
        elastic_in_out = function(t)
            if t == 0 or t == 1 then return t end
            local p = 0.3
            local s = p / 4

            if t < 0.5 then
                t = t * 2  -- Scale t to [0, 1]
                return -0.5 * (2^(10 * (t - 1))) * math.sin((t - 1 - s) * (2 * math.pi) / p)
            else
                t = (t - 0.5) * 2  -- Scale t to [0, 1]
                return 0.5 * (2^(-10 * t)) * math.sin((t - s) * (2 * math.pi) / p) + 0.5
            end
        end,
    },
    
    -- Logging
    debug = true,
    log_prefix = "[AnimationEngine] "
}

-- ---------------------------------------------------------------------------
-- State Management
-- ---------------------------------------------------------------------------

local animations = {} -- Active animations by ID
local sequences = {} -- Active sequences by ID
local callbacks = {} -- Scheduled callbacks

local animation_id_counter = 0

local function generate_id()
    animation_id_counter = animation_id_counter + 1
    return "anim_" .. animation_id_counter .. "_" .. math.random(1000, 9999)
end

local function log(message)
    if cfg.debug and message then
        print(cfg.log_prefix .. tostring(message))
    end
end

-- ---------------------------------------------------------------------------
-- Core Interpolation Functions
-- ---------------------------------------------------------------------------

-- Generic interpolation function with support for discrete values
function AnimationEngine.interpolate(start, target, t, easing, discrete)
    local ease_func = cfg.easing_functions[easing] or cfg.easing_functions.linear
    local eased_t = ease_func(t)
    
    -- Create a set of discrete keys for fast lookup
    local discrete_set = {}
    if discrete then
        for _, key in ipairs(discrete) do
            discrete_set[key] = true
        end
    end
    
    if type(start) == "number" and type(target) == "number" then
        return start + (target - start) * eased_t
    elseif type(start) == "table" and type(target) == "table" then
        local result = {}
        for key, start_value in pairs(start) do
            local target_value = target[key]
            
            -- Check if this key should be discrete
            if discrete_set[key] then
                -- Discrete value: only change at the end of animation
                if t >= 1.0 then
                    result[key] = target_value or start_value
                else
                    result[key] = start_value
                end
            elseif type(start_value) == "number" and type(target_value) == "number" then
                -- Regular interpolation for numeric values
                result[key] = start_value + (target_value - start_value) * eased_t
            else
                -- Non-numeric or mismatched types - set to target immediately
                result[key] = target_value or start_value
            end
        end
        
        -- Also include any keys in target that aren't in start
        for key, target_value in pairs(target) do
            if not start[key] then
                -- Check if this key should be discrete
                if discrete_set[key] then
                    -- Discrete value: only change at the end of animation
                    if t >= 1.0 then
                        result[key] = target_value
                    end
                else
                    -- Non-numeric or new value - set to target immediately
                    result[key] = target_value
                end
            end
        end
        
        return result
    end
    
    return target or start
end

-- Create a smooth animation between values with looping support
function AnimationEngine.animate(start_values, target_values, duration, options)
    options = options or {}
    local easing = options.easing or "linear"
    local easing_back = options.easing_back or easing -- Optional different easing for the return trip
    local on_update = options.on_update
    local on_complete = options.on_complete
    local loop = options.loop or false -- Can be true (infinite), false (no loop), or a number (loop count)
    local ping_pong = options.ping_pong or false -- If true, alternates between start and target
    local discrete = options.discrete or {} -- Array of keys that should change discretely (not interpolated)
    local id = options.id or generate_id()
    
    local max_cycles = nil
    if type(loop) == "number" and loop > 0 then
        max_cycles = loop
        loop = true
    end
    
    local current_cycle = 0
    local phase = 1 -- 1 = forward (start->target), 2 = backward (target->start)
    local original_start_values = {}
    local original_target_values = {}
    
    -- Deep copy original values
    for k, v in pairs(start_values) do
        original_start_values[k] = v
    end
    for k, v in pairs(target_values) do
        original_target_values[k] = v
    end
    
    animations[id] = {
        id = id,
        start_time = os.clock(),
        duration = duration,
        easing = easing,
        easing_back = easing_back,
        start_values = start_values,
        target_values = target_values,
        original_start_values = original_start_values,
        original_target_values = original_target_values,
        discrete = discrete,
        on_update = on_update,
        on_complete = on_complete,
        loop = loop,
        ping_pong = ping_pong,
        max_cycles = max_cycles,
        current_cycle = current_cycle,
        phase = phase,
        current_values = {}
    }
    
    log("Started animation: " .. id .. (loop and " (looping)" or "") .. (#discrete > 0 and " (discrete keys: " .. table.concat(discrete, ", ") .. ")" or ""))
    return id
end

-- Update all active animations
function AnimationEngine.update(dt)
    local current_time = os.clock()
    local to_remove = {}
    local to_process = {}
    
    -- First, collect all animations to process
    for id, anim in pairs(animations) do
        to_process[id] = anim
    end
    
    -- Then process them
    for id, anim in pairs(to_process) do
        -- Skip if animation was removed during processing
        if animations[id] == nil then
            goto continue
        end
        
        local elapsed = current_time - anim.start_time
        local t = math.min(elapsed / anim.duration, 1.0)
        
        -- Determine which easing to use based on phase
        local current_easing = anim.phase == 1 and anim.easing or anim.easing_back
        
        -- Determine which values to use based on phase
        local phase_start_values, phase_target_values
        
        if anim.phase == 1 then
            phase_start_values = anim.start_values
            phase_target_values = anim.target_values
        else
            phase_start_values = anim.target_values
            phase_target_values = anim.start_values
        end
        
        -- Interpolate all values with discrete keys support
        anim.current_values = AnimationEngine.interpolate(
            phase_start_values, 
            phase_target_values, 
            t, 
            current_easing,
            anim.discrete
        )
        
        -- Call update callback
        if anim.on_update then
            anim.on_update(anim.current_values, t, anim.phase)
        end
        
        -- Check if complete for current phase
        if t >= 1.0 then
            if anim.phase == 1 then
                -- Completed forward phase
                if anim.ping_pong then
                    -- Start backward phase
                    anim.phase = 2
                    anim.start_time = current_time
                elseif anim.loop then
                    -- Check if we should continue looping
                    if anim.max_cycles and anim.current_cycle + 1 >= anim.max_cycles then
                        -- Reached max cycles
                        if anim.on_complete then
                            anim.on_complete(anim.current_values, false)
                        end
                        table.insert(to_remove, id)
                        log("Completed animation (reached max cycles): " .. id)
                    else
                        -- Continue looping
                        anim.current_cycle = anim.current_cycle + 1
                        anim.start_time = current_time
                    end
                else
                    -- Not looping, complete the animation
                    if anim.on_complete then
                        anim.on_complete(anim.current_values, false)
                    end
                    table.insert(to_remove, id)
                    log("Completed animation: " .. id)
                end
            else
                -- Completed backward phase (ping-pong)
                if anim.loop then
                    -- Check if we should continue looping
                    if anim.max_cycles and anim.current_cycle + 1 >= anim.max_cycles then
                        -- Reached max cycles
                        if anim.on_complete then
                            anim.on_complete(anim.current_values, false)
                        end
                        table.insert(to_remove, id)
                        log("Completed animation (reached max cycles): " .. id)
                    else
                        -- Continue looping
                        anim.current_cycle = anim.current_cycle + 1
                        anim.phase = 1
                        anim.start_time = current_time
                    end
                else
                    -- Not looping, complete the animation
                    if anim.on_complete then
                        anim.on_complete(anim.current_values, false)
                    end
                    table.insert(to_remove, id)
                    log("Completed animation: " .. id)
                end
            end
        end
        
        ::continue::
    end
    
    -- Clean up completed animations
    for _, id in ipairs(to_remove) do
        animations[id] = nil
    end
end

-- Stop an active animation
function AnimationEngine.stop_animation(id)
    if animations[id] then
        if animations[id].on_complete then
            animations[id].on_complete(animations[id].current_values, true) -- true = interrupted
        end
        animations[id] = nil
        log("Stopped animation: " .. id)
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Animation Sequences
-- ---------------------------------------------------------------------------

function AnimationEngine.create_sequence(steps, options)
    options = options or {}
    local id = options.id or generate_id()
    local loop = options.loop or false
    local on_complete = options.on_complete
    
    sequences[id] = {
        id = id,
        steps = steps,
        current_step = 1,
        start_time = os.clock(),
        loop = loop,
        on_complete = on_complete,
        active_animation = nil,
        step_data = {}
    }
    
    log("Created sequence: " .. id)
    return id
end

function AnimationEngine.start_sequence(id)
    local seq = sequences[id]
    if not seq then
        log("Sequence not found: " .. id)
        return false
    end
    
    seq.start_time = os.clock()
    seq.current_step = 1
    seq.active_animation = nil
    
    -- Start first step
    AnimationEngine._execute_sequence_step(id)
    
    log("Started sequence: " .. id)
    return true
end

function AnimationEngine._execute_sequence_step(seq_id)
    local seq = sequences[seq_id]
    if not seq or seq.current_step > #seq.steps then
        return false
    end
    
    local step = seq.steps[seq.current_step]
    step.id = step.id or (seq_id .. "_step_" .. seq.current_step)
    
    -- Store original values for "current" references
    if not seq.step_data[seq.current_step] then
        seq.step_data[seq.current_step] = {}
    end
    
    -- Handle different step types
    if step.type == "delay" then
        seq.next_step_time = os.clock() + step.duration
        seq.active_animation = nil
        
    elseif step.type == "animate" then
        -- Resolve "current" and "original" references
        local start_values = {}
        local target_values = {}
        
        for key, value in pairs(step.start or {}) do
            if type(value) == "string" then
                if value:find("^current%+") then
                    local offset = tonumber(value:match("current%+(.-)$"))
                    start_values[key] = (seq.step_data[seq.current_step][key] or 0) + offset
                elseif value == "current" then
                    start_values[key] = seq.step_data[seq.current_step][key] or 0
                elseif value == "original" then
                    start_values[key] = seq.original_values and seq.original_values[key] or 0
                else
                    start_values[key] = tonumber(value) or value
                end
            else
                start_values[key] = value
            end
        end
        
        for key, value in pairs(step.target or {}) do
            if type(value) == "string" then
                if value:find("^current%+") then
                    local offset = tonumber(value:match("current%+(.-)$"))
                    target_values[key] = (seq.step_data[seq.current_step][key] or 0) + offset
                elseif value == "current" then
                    target_values[key] = seq.step_data[seq.current_step][key] or 0
                elseif value == "original" then
                    target_values[key] = seq.original_values and seq.original_values[key] or 0
                else
                    target_values[key] = tonumber(value) or value
                end
            else
                target_values[key] = value
            end
        end
        
        -- Store start values for future reference
        for key, value in pairs(start_values) do
            seq.step_data[seq.current_step][key] = value
        end
        
        -- Start animation with discrete keys support
        seq.active_animation = AnimationEngine.animate(start_values, target_values, step.duration, {
            easing = step.easing,
            discrete = step.discrete, -- Pass through discrete keys
            on_update = step.on_update,
            on_complete = function(values, interrupted)
                if not interrupted then
                    -- Store final values
                    for key, value in pairs(values) do
                        seq.step_data[seq.current_step][key] = value
                    end
                    AnimationEngine._sequence_step_complete(seq_id)
                end
            end
        })
        
    elseif step.type == "callback" then
        if step.callback then
            step.callback()
        end
        AnimationEngine._sequence_step_complete(seq_id)
    end
    
    return true
end

function AnimationEngine._sequence_step_complete(seq_id)
    local seq = sequences[seq_id]
    if not seq then return end
    
    seq.current_step = seq.current_step + 1
    seq.active_animation = nil
    
    if seq.current_step > #seq.steps then
        -- Sequence complete
        if seq.loop then
            seq.current_step = 1
            AnimationEngine._execute_sequence_step(seq_id)
        else
            if seq.on_complete then
                seq.on_complete()
            end
            sequences[seq_id] = nil
            log("Sequence completed: " .. seq_id)
        end
    else
        -- Move to next step
        AnimationEngine._execute_sequence_step(seq_id)
    end
end

function AnimationEngine.update_sequences(dt)
    local current_time = os.clock()
    
    for seq_id, seq in pairs(sequences) do
        if seq.next_step_time and current_time >= seq.next_step_time then
            seq.next_step_time = nil
            AnimationEngine._sequence_step_complete(seq_id)
        end
    end
end

function AnimationEngine.stop_sequence(id)
    local seq = sequences[id]
    if not seq then return false end
    
    -- Stop any active animation
    if seq.active_animation then
        AnimationEngine.stop_animation(seq.active_animation)
    end
    
    sequences[id] = nil
    log("Stopped sequence: " .. id)
    return true
end

-- ---------------------------------------------------------------------------
-- Pre-built Animation Effects with Discrete Value Support
-- ---------------------------------------------------------------------------

-- Simple move animation with looping support
function AnimationEngine.move_to(object, target_x, target_y, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
    return AnimationEngine.animate(
        {x = object.x or 0, y = object.y or 0},
        {x = target_x, y = target_y},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
            discrete = discrete,
            on_update = function(values)
                if object.setPosition then
                    object:setPosition(values.x, values.y)
                else
                    object.x = values.x
                    object.y = values.y
                end
            end,
            on_complete = on_complete,
            loop = loop,
            ping_pong = ping_pong
        }
    )
end

-- Scale animation with looping support
function AnimationEngine.scale_to(object, target_scale, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
    return AnimationEngine.animate(
        {scale = object.scale or 1},
        {scale = target_scale},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
            discrete = discrete,
            on_update = function(values)
                if object.setScale then
                    object:setScale(values.scale)
                else
                    object.scale = values.scale
                end
            end,
            on_complete = on_complete,
            loop = loop,
            ping_pong = ping_pong
        }
    )
end

-- Rotation animation with looping support
function AnimationEngine.rotate_to(object, target_angle, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
    return AnimationEngine.animate(
        {angle = object.angle or 0},
        {angle = target_angle},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
            discrete = discrete,
            on_update = function(values)
                if object.setRotation then
                    object:setRotation(values.angle)
                else
                    object.angle = values.angle
                end
            end,
            on_complete = on_complete,
            loop = loop,
            ping_pong = ping_pong
        }
    )
end

-- Fade animation with looping support
function AnimationEngine.fade_to(object, target_alpha, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
    return AnimationEngine.animate(
        {alpha = object.alpha or 255},
        {alpha = target_alpha},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
            discrete = discrete,
            on_update = function(values)
                if object.setAlpha then
                    object:setAlpha(values.alpha)
                else
                    object.alpha = values.alpha
                end
            end,
            on_complete = on_complete,
            loop = loop,
            ping_pong = ping_pong
        }
    )
end

-- Color tint animation with looping support
function AnimationEngine.tint_to(object, target_r, target_g, target_b, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
    return AnimationEngine.animate(
        {r = object.r or 255, g = object.g or 255, b = object.b or 255},
        {r = target_r, g = target_g, b = target_b},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
            discrete = discrete,
            on_update = function(values)
                if object.setColor then
                    object:setColor(values.r, values.g, values.b)
                else
                    object.r = values.r
                    object.g = values.g
                    object.b = values.b
                end
            end,
            on_complete = on_complete,
            loop = loop,
            ping_pong = ping_pong
        }
    )
end

-- ---------------------------------------------------------------------------
-- Utility Functions
-- ---------------------------------------------------------------------------

-- Schedule a delayed callback
function AnimationEngine.delay(duration, callback)
    local id = "delay_" .. generate_id()
    callbacks[id] = {
        trigger_time = os.clock() + duration,
        callback = callback
    }
    return id
end

-- Update scheduled callbacks
function AnimationEngine.update_callbacks()
    local current_time = os.clock()
    local to_remove = {}
    local to_process = {}
    
    -- First collect all callbacks
    for id, cb in pairs(callbacks) do
        to_process[id] = cb
    end
    
    -- Then process them
    for id, cb in pairs(to_process) do
        if current_time >= cb.trigger_time then
            cb.callback()
            table.insert(to_remove, id)
        end
    end
    
    for _, id in ipairs(to_remove) do
        callbacks[id] = nil
    end
end

-- Get active animation count
function AnimationEngine.get_active_count()
    local count = 0
    for _ in pairs(animations) do count = count + 1 end
    return count
end

-- Get active sequence count
function AnimationEngine.get_sequence_count()
    local count = 0
    for _ in pairs(sequences) do count = count + 1 end
    return count
end

-- Clear all animations
function AnimationEngine.clear_all()
    for id, _ in pairs(animations) do
        AnimationEngine.stop_animation(id)
    end
    
    for id, _ in pairs(sequences) do
        AnimationEngine.stop_sequence(id)
    end
    
    callbacks = {}
    log("Cleared all animations")
end

-- ---------------------------------------------------------------------------
-- Main Update Function (to be called in game loop)
-- ---------------------------------------------------------------------------

Net:on("tick", function (event)
    AnimationEngine.tick(event.delta_time)
end)

function AnimationEngine.tick(dt)
    AnimationEngine.update(dt)
    AnimationEngine.update_sequences(dt)
    AnimationEngine.update_callbacks()
end

-- ---------------------------------------------------------------------------
-- Configuration Setters
-- ---------------------------------------------------------------------------

function AnimationEngine.set_debug(enabled)
    cfg.debug = enabled == true
end

function AnimationEngine.set_interpolation_speeds(position, ro, color, scale)
    if position then cfg.default_interp_speed = position end
    if ro then cfg.default_ro_speed = ro end
    if color then cfg.default_color_speed = color end
    if scale then cfg.default_scale_speed = scale end
end

function AnimationEngine.add_easing_function(name, func)
    if type(func) == "function" then
        cfg.easing_functions[name] = func
    end
end

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------

return AnimationEngine
----------------------
-- USE CASE EXAMPLE --
----------------------

--[[
-- Load the animation engine
local AnimationEngine = require("/server/scripts/ezlibs-custom/animation_engine")

-- Simple object to animate
local myObject = {
    x = 100,
    y = 100,
    scale = 1,
    angle = 0,
    alpha = 255,
    color_mode = 1
}

-- Example 1: Move with color_mode as discrete value
-- color_mode will stay at 1 until the end of animation, then jump to 2
AnimationEngine.animate(
    {x = 100, y = 100, color_mode = 1},
    {x = 200, y = 150, color_mode = 2},
    2.0,
    {
        easing = "ease_in_out",
        discrete = {"color_mode"}, -- color_mode won't interpolate, changes at end
        on_update = function(values)
            myObject.x = values.x
            myObject.y = values.y
            myObject.color_mode = values.color_mode
            print("x:", values.x, "y:", values.y, "color_mode:", values.color_mode)
        end,
        on_complete = function(values)
            print("Animation complete! color_mode is now:", values.color_mode)
        end
    }
)

-- Example 2: Using the pre-built functions with discrete values
AnimationEngine.move_to(myObject, 300, 200, 1.5, "ease_in_out", 
    function() print("Move complete!") end,
    false, false, nil, {"color_mode"} -- Last parameter is discrete keys
)

-- Example 3: Multiple discrete values
local anotherObject = {
    x = 50,
    y = 50,
    visible = true,
    layer = 1,
    special_flag = false
}

AnimationEngine.animate(
    {x = 50, y = 50, visible = true, layer = 1, special_flag = false},
    {x = 200, y = 200, visible = false, layer = 3, special_flag = true},
    3.0,
    {
        easing = "linear",
        discrete = {"visible", "layer", "special_flag"}, -- All these change discretely at the end
        on_update = function(values)
            anotherObject.x = values.x
            anotherObject.y = values.y
            anotherObject.visible = values.visible
            anotherObject.layer = values.layer
            anotherObject.special_flag = values.special_flag
            
            -- During animation: visible stays true, layer stays 1, special_flag stays false
            -- At the end: visible becomes false, layer becomes 3, special_flag becomes true
        end
    }
)

-- Example 4: Discrete values in sequences
local seqId = AnimationEngine.create_sequence({
    {
        type = "animate",
        target = {x = 300, y = 200, mode = 1},
        duration = 1,
        easing = "ease_out",
        discrete = {"mode"}, -- mode changes discretely at the end of this step
        on_update = function(values)
            myObject.x = values.x
            myObject.y = values.y
            myObject.mode = values.mode
        end
    },
    {
        type = "delay",
        duration = 0.5
    },
    {
        type = "animate",
        target = {scale = 2, mode = 2},
        duration = 2,
        easing = "ease_in_out",
        discrete = {"mode"} -- mode changes discretely again
    }
})

-- In your game loop
function onTick(dt)
    AnimationEngine.tick(dt)
end
]]--
