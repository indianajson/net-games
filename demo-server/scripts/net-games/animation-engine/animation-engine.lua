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

-- Generic interpolation function
function AnimationEngine.interpolate(start, target, t, easing)
    local ease_func = cfg.easing_functions[easing] or cfg.easing_functions.linear
    local eased_t = ease_func(t)
    
    if type(start) == "number" and type(target) == "number" then
        return start + (target - start) * eased_t
    elseif type(start) == "table" and type(target) == "table" then
        local result = {}
        for key, start_value in pairs(start) do
            local target_value = target[key]
            if type(start_value) == "number" and type(target_value) == "number" then
                result[key] = start_value + (target_value - start_value) * eased_t
            else
                result[key] = target_value or start_value
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
        on_update = on_update,
        on_complete = on_complete,
        loop = loop,
        ping_pong = ping_pong,
        max_cycles = max_cycles,
        current_cycle = current_cycle,
        phase = phase,
        current_values = {}
    }
    
    log("Started animation: " .. id .. (loop and " (looping)" or ""))
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
        
        -- Interpolate all values
        if anim.phase == 1 then
            anim.current_values = AnimationEngine.interpolate(
                anim.start_values, 
                anim.target_values, 
                t, 
                current_easing
            )
        else
            anim.current_values = AnimationEngine.interpolate(
                anim.target_values, 
                anim.start_values, 
                t, 
                current_easing
            )
        end
        
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
        
        -- Start animation
        seq.active_animation = AnimationEngine.animate(start_values, target_values, step.duration, {
            easing = step.easing,
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
-- Pre-built Animation Effects
-- ---------------------------------------------------------------------------
-- Simple move animation with looping support
function AnimationEngine.move_to(object, target_x, target_y, duration, easing, on_complete, loop, ping_pong, easing_back)
    return AnimationEngine.animate(
        {x = object.x or 0, y = object.y or 0},
        {x = target_x, y = target_y},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
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
function AnimationEngine.scale_to(object, target_scale, duration, easing, on_complete, loop, ping_pong, easing_back)
    return AnimationEngine.animate(
        {scale = object.scale or 1},
        {scale = target_scale},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
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
function AnimationEngine.rotate_to(object, target_angle, duration, easing, on_complete, loop, ping_pong, easing_back)
    return AnimationEngine.animate(
        {angle = object.angle or 0},
        {angle = target_angle},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
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
function AnimationEngine.fade_to(object, target_alpha, duration, easing, on_complete, loop, ping_pong, easing_back)
    return AnimationEngine.animate(
        {alpha = object.alpha or 255},
        {alpha = target_alpha},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
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
function AnimationEngine.tint_to(object, target_r, target_g, target_b, duration, easing, on_complete, loop, ping_pong, easing_back)
    return AnimationEngine.animate(
        {r = object.r or 255, g = object.g or 255, b = object.b or 255},
        {r = target_r, g = target_g, b = target_b},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
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
-- Pulse effect with enhanced looping support
function AnimationEngine.pulse(object, min_scale, max_scale, duration, loops, on_complete, easing, easing_back)
    local sequence = {
        {
            type = "animate",
            target = {scale = max_scale},
            duration = duration / 2,
            easing = easing or "ease_in_out"
        },
        {
            type = "animate",
            target = {scale = min_scale},
            duration = duration / 2,
            easing = easing_back or (easing or "ease_in_out")
        }
    }
    
    -- If loops is provided, use the new animate function with loop parameter
    if loops then
        return AnimationEngine.animate(
            {scale = object.scale or 1},
            {scale = max_scale},
            duration / 2,
            {
                easing = easing or "ease_in_out",
                easing_back = easing_back or (easing or "ease_in_out"),
                on_update = function(values)
                    if object.setScale then
                        object:setScale(values.scale)
                    else
                        object.scale = values.scale
                    end
                end,
                on_complete = on_complete,
                loop = loops,
                ping_pong = true
            }
        )
    end
    
    local seq_id = AnimationEngine.create_sequence(sequence, {
        loop = (loops == nil),
        on_complete = on_complete
    })
    
    -- Store original scale
    sequences[seq_id].original_values = {scale = object.scale or 1}
    
    -- Set up update callbacks
    for _, step in ipairs(sequences[seq_id].steps) do
        if step.type == "animate" then
            step.on_update = function(values)
                if object.setScale then
                    object:setScale(values.scale)
                else
                    object.scale = values.scale
                end
            end
        end
    end
    
    AnimationEngine.start_sequence(seq_id)
    return seq_id
end

-- Shake effect
function AnimationEngine.shake(object, intensity, duration, frequency, on_complete)
    local steps = math.floor(duration * frequency)
    local sequence = {}
    local original_x = object.x or 0
    local original_y = object.y or 0
    
    -- Store original position
    local seq_id = AnimationEngine.create_sequence(sequence, {
        on_complete = on_complete
    })
    sequences[seq_id].original_values = {x = original_x, y = original_y}
    
    for i = 1, steps do
        local offset_x = (math.random() * 2 - 1) * intensity
        local offset_y = (math.random() * 2 - 1) * intensity
        
        table.insert(sequence, {
            type = "animate",
            target = {x = original_x + offset_x, y = original_y + offset_y},
            duration = 1 / frequency,
            easing = "linear"
        })
    end
    
    -- Return to original position
    table.insert(sequence, {
        type = "animate",
        target = {x = original_x, y = original_y},
        duration = 0.1,
        easing = "ease_out"
    })
    
    sequences[seq_id].steps = sequence
    
    -- Set up update callbacks
    for _, step in ipairs(sequences[seq_id].steps) do
        if step.type == "animate" then
            step.on_update = function(values)
                if object.setPosition then
                    object:setPosition(values.x, values.y)
                else
                    object.x = values.x
                    object.y = values.y
                end
            end
        end
    end
    
    AnimationEngine.start_sequence(seq_id)
    return seq_id
end

-- Bounce in effect
function AnimationEngine.bounce_in(object, start_scale, duration, on_complete)
    local sequence = {
        {
            type = "animate",
            start = {scale = start_scale},
            target = {scale = 1.2},
            duration = duration * 0.6,
            easing = "elastic_out"
        },
        {
            type = "animate",
            target = {scale = 1.0},
            duration = duration * 0.4,
            easing = "bounce_out"
        }
    }
    
    local seq_id = AnimationEngine.create_sequence(sequence, {
        on_complete = on_complete
    })
    
    -- Set up update callbacks
    for _, step in ipairs(sequences[seq_id].steps) do
        if step.type == "animate" then
            step.on_update = function(values)
                if object.setScale then
                    object:setScale(values.scale)
                else
                    object.scale = values.scale
                end
            end
        end
    end
    
    AnimationEngine.start_sequence(seq_id)
    return seq_id
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
    alpha = 255
}

-- Move animation with infinite looping (ping-pong)
AnimationEngine.move_to(myObject, 200, 150, 1.5, "ease_in_out", function()
    print("Move complete!")
end, true, true, "ease_in_out")

-- Scale animation that loops 3 times
AnimationEngine.scale_to(myObject, 2.0, 1.0, "ease_in_out", function()
    print("Scale animation looped 3 times!")
end, 3, true, "ease_out")

-- Rotation animation that loops infinitely with different easing for return trip
AnimationEngine.rotate_to(myObject, 360, 2.0, "ease_in", function()
    print("This won't be called for infinite loop!")
end, true, true, "ease_out")

-- Fade animation that loops 5 times
AnimationEngine.fade_to(myObject, 100, 0.5, "linear", function()
    print("Fade animation completed 5 loops!")
end, 5, true)

-- Create custom animation sequence
local seqId = AnimationEngine.create_sequence({
    {
        type = "animate",
        target = {x = 300, y = 200},
        duration = 1,
        easing = "ease_out",
        on_update = function(values)
            myObject.x = values.x
            myObject.y = values.y
        end
    },
    {
        type = "delay",
        duration = 0.5
    },
    {
        type = "animate",
        target = {scale = 2, angle = 360},
        duration = 2,
        easing = "ease_in_out"
    }
})

-- In your game loop
function onTick(dt)
    AnimationEngine.tick(dt)
end
]]--