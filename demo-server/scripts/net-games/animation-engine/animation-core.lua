-- animation-core.lua
-- Core animation engine logic - no external dependencies
local AnimationCore = {}
_G.AnimationCore = AnimationCore
AnimationCore.__index = AnimationCore

-- ==============================
-- Internal State
-- ==============================
local _animations = {}      -- Active individual animations: {id = {start, target, duration, elapsed, easing, ...}}
local _sequences = {}       -- Active animation sequences: {id = {steps, index, active_anim, elapsed, ...}}
local _debug = false        -- Debug logging flag
local _next_id = 1          -- Counter for generating unique IDs

-- ==============================
-- Core Helpers
-- ==============================

local function log(...)
    if _debug then
        print("[AnimationCore]", ...)
    end
end

local function generate_id(prefix)
    local id = prefix .. "_" .. tostring(_next_id) .. "_" .. tostring(os.clock())
    _next_id = _next_id + 1
    return id
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- ==============================
-- Core Animation API
-- ==============================

--- Create and start a new animation
function AnimationCore.animate(start_values, target_values, duration, options)
    options = options or {}
    
    local id = options.id or generate_id("anim")
    
    _animations[id] = {
        start = start_values,
        target = target_values,
        duration = duration,
        elapsed = 0,
        easing = options.easing or "linear",
        loop = options.loop,
        on_update = options.on_update,
        on_complete = options.on_complete,
        ping_pong = options.ping_pong,
        direction = 1,  -- 1 = forward, -1 = backward (for ping-pong)
        loop_count = 0
    }
    
    log("Animation started:", id)
    return id
end

--- Stop a running animation
function AnimationCore.stop_animation(id)
    if _animations[id] then
        _animations[id] = nil
        log("Animation stopped:", id)
        return true
    end
    return false
end

--- Create an animation sequence from multiple steps
function AnimationCore.create_sequence(steps, options)
    options = options or {}
    
    local id = options.id or generate_id("seq")
    
    _sequences[id] = {
        id = id,
        steps = steps,
        index = 1,
        active_anim = nil,
        elapsed = 0,
        loop = options.loop,
        on_complete = options.on_complete
    }
    
    log("Sequence created:", id)
    return id
end

--- Start or restart a sequence
function AnimationCore.start_sequence(id)
    local seq = _sequences[id]
    if not seq then 
        log("WARN: Sequence not found:", id)
        return false
    end
    
    seq.index = 1
    seq.elapsed = 0
    seq.active_anim = nil
    
    log("Sequence started:", id)
    return true
end

--- Stop and remove a sequence
function AnimationCore.stop_sequence(id)
    if _sequences[id] then
        _sequences[id] = nil
        log("Sequence stopped:", id)
        return true
    end
    return false
end

--- Update all active animations and sequences (call once per frame)
function AnimationCore.tick(dt)
    -- Update individual animations
    for id, anim in pairs(_animations) do
        anim.elapsed = anim.elapsed + dt
        
        local effective_duration = anim.duration
        if anim.direction < 0 and anim.ping_pong then
            effective_duration = anim.duration / 2
        end
        
        local t = math.min(anim.elapsed / effective_duration, 1)
        
        -- Apply easing (easing function will be provided externally)
        local eased_t = t
        if anim.easing and anim.easing ~= "linear" then
            -- Easing will be applied externally via apply_easing callback
            eased_t = t  -- Placeholder
        end
        
        -- Interpolate values
        local values = {}
        for k, v in pairs(anim.start) do
            if type(v) == "number" and type(anim.target[k]) == "number" then
                values[k] = lerp(v, anim.target[k], eased_t)
            else
                values[k] = anim.target[k]
            end
        end
        
        -- Call update callback
        if anim.on_update then
            anim.on_update(values, eased_t)
        end
        
        -- Check if animation completed
        if anim.elapsed >= effective_duration then
            -- Handle completion
            if anim.on_complete then
                anim.on_complete(values)
            end
            
            -- Handle looping
            if anim.loop or anim.ping_pong then
                if anim.ping_pong then
                    anim.direction = -anim.direction
                    -- Swap start and target for ping-pong
                    if anim.direction < 0 then
                        local temp = anim.start
                        anim.start = anim.target
                        anim.target = temp
                    end
                end
                anim.elapsed = 0
                anim.loop_count = anim.loop_count + 1
            else
                _animations[id] = nil
            end
        end
    end
    
    -- Update sequences
    for id, seq in pairs(_sequences) do
        local step = seq.steps[seq.index]
        if not step then
            -- Sequence completed
            if seq.loop then
                seq.index = 1
            else
                if seq.on_complete then 
                    seq.on_complete(seq.id) 
                end
                _sequences[id] = nil
            end
            goto continue
        end
        
        if step.type == "delay" then
            seq.elapsed = seq.elapsed + dt
            if seq.elapsed >= step.duration then
                seq.elapsed = 0
                seq.index = seq.index + 1
            end
            
        elseif step.type == "animate" then
            if not seq.active_anim then
                -- Start the animation step
                seq.active_anim = {
                    elapsed = 0,
                    step = step
                }
            else
                -- Update the animation step
                seq.active_anim.elapsed = seq.active_anim.elapsed + dt
                local t = math.min(seq.active_anim.elapsed / step.duration, 1)
                
                if step.on_update then
                    step.on_update(nil, t, "animate")
                end
                
                if seq.active_anim.elapsed >= step.duration then
                    if step.on_complete then
                        step.on_complete()
                    end
                    seq.active_anim = nil
                    seq.index = seq.index + 1
                end
            end
            
        elseif step.type == "callback" then
            if step.fn then 
                step.fn() 
            end
            seq.index = seq.index + 1
        end
        
        ::continue::
    end
end

--- Stop all animations and sequences
function AnimationCore.clear_all()
    _animations = {}
    _sequences = {}
    log("All animations and sequences cleared")
end

--- Check if an animation or sequence is currently running
function AnimationCore.is_running(id)
    return _animations[id] ~= nil or _sequences[id] ~= nil
end

--- Get number of active animations and sequences
function AnimationCore.get_active_count()
    local anim_count = 0
    local seq_count = 0
    for _ in pairs(_animations) do anim_count = anim_count + 1 end
    for _ in pairs(_sequences) do seq_count = seq_count + 1 end
    return anim_count, seq_count
end

--- Enable/disable debug logging
function AnimationCore.set_debug(enabled)
    _debug = enabled
    log("Debug logging " .. (enabled and "enabled" or "disabled"))
end

--- Apply easing function to interpolation factor
function AnimationCore.apply_easing(easing_fn, t)
    if type(easing_fn) == "function" then
        return easing_fn(t)
    end
    return t  -- Default to linear if not a function
end

--- Create a delayed callback
function AnimationCore.delay(duration, callback, options)
    options = options or {}
    return AnimationCore.create_sequence({
        {
            type = "delay",
            duration = duration
        },
        {
            type = "callback",
            fn = callback
        }
    }, options)
end

--- Get animation state for debugging
function AnimationCore.get_animation_state(id)
    if _animations[id] then
        return { type = "animation", data = _animations[id] }
    elseif _sequences[id] then
        return { type = "sequence", data = _sequences[id] }
    end
    return nil
end

return AnimationCore