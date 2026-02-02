-- animation-engine.lua
-- Public API & main entry point for the Animation Engine
-- Provides core animation management, pre-built sequences, and utility functions
-- Usage: local AnimationEngine = require("scripts/net-games/animation-engine/animation-engine")

local AnimationEngine = {}

-- ==============================
-- Internal Requires
-- ==============================
local Enums = require("scripts/net-games/animation-engine/animation-enums")
local MathUtils = require("scripts/net-games/animation-engine/math-utils")
local AnimationSequences = require("scripts/net-games/animation-engine/animation-sequences")

-- Backward compatibility for legacy code
_G.AnimationEngine = AnimationEngine
AnimationEngine.__index = AnimationEngine

-- ==============================
-- Internal State
-- ==============================
local _animations = {}      -- Active individual animations
local _sequences = {}       -- Active animation sequences
local _debug = false        -- Debug logging flag

-- ==============================
-- Core Helpers
-- ==============================
local function log(...)
    if _debug then
        print("[AnimationEngine]", ...)
    end
end

-- Linear interpolation between two values
-- @param a (number): Starting value
-- @param b (number): Ending value
-- @param t (number): Interpolation factor (0-1)
-- @return (number): Interpolated value
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Apply easing function to interpolation factor
-- @param easing (string): Name of easing function (e.g., "ease_in_out", "bounce_out")
-- @param t (number): Raw interpolation factor (0-1)
-- @return (number): Eased interpolation factor (0-1)
local function apply_easing(easing, t)
    local fn = Enums.Easing[easing] or Enums.Easing["linear"]
    return fn(t)
end

-- ==============================
-- Core Animation API
-- ==============================

--- Create and start a new animation
-- @param start_values (table): Table of starting property values {property = value}
-- @param target_values (table): Table of target property values {property = value}
-- @param duration (number): Animation duration in seconds
-- @param options (table, optional): Animation configuration options:
--   - id (string): Custom animation ID (auto-generated if not provided)
--   - easing (string): Easing function name (default: "linear")
--   - loop (boolean/table): Loop configuration:
--        true: infinite loop
--        false/nil: no loop
--        table: {count = number, ping_pong = boolean}
--   - on_update (function): Callback called each frame with interpolated values
--   - on_complete (function): Callback called when animation completes
-- @return (string): Animation ID for tracking and control
function AnimationEngine.animate(start_values, target_values, duration, options)
    options = options or {}
    
    local id = options.id or ("anim_" .. tostring(os.clock()))
    local easing = options.easing or "linear"
    
    _animations[id] = {
        start = start_values,
        target = target_values,
        duration = duration,
        elapsed = 0,
        easing = easing,
        loop = options.loop,
        on_update = options.on_update,
        on_complete = options.on_complete,
        ping_pong = options.ping_pong or (type(options.loop) == "table" and options.loop.ping_pong)
    }
    
    log("Animation started:", id)
    return id
end

--- Stop a running animation
-- @param id (string): Animation ID to stop
-- @return (boolean): True if animation was found and stopped, false otherwise
function AnimationEngine.stop_animation(id)
    if _animations[id] then
        _animations[id] = nil
        log("Animation stopped:", id)
        return true
    end
    return false
end

--- Create a delayed callback (convenience wrapper for animate)
-- @param duration (number): Delay duration in seconds
-- @param callback (function): Function to call after delay
-- @param options (table, optional): Additional options passed to animate()
-- @return (string): Animation ID for the delay
function AnimationEngine.delay(duration, callback, options)
    return AnimationEngine.animate({}, {}, duration, {
        on_complete = callback,
        easing = "instant",
        id = options and options.id
    })
end

-- ==============================
-- Sequence API
-- ==============================

--- Create an animation sequence from multiple steps
-- @param steps (table): Array of step definitions, each step can be:
--   - {type="delay", duration=number}
--   - {type="animate", duration=number, easing=string, from=table, to=table, on_update=function}
--   - {type="callback", fn=function}
-- @param options (table, optional): Sequence configuration:
--   - id (string): Custom sequence ID
--   - loop (boolean): Whether to loop the sequence
--   - on_complete (function): Callback when sequence completes
-- @return (string): Sequence ID for tracking and control
function AnimationEngine.create_sequence(steps, options)
    options = options or {}
    
    local id = options.id or ("seq_" .. tostring(os.clock()))
    
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
-- @param id (string): Sequence ID to start
function AnimationEngine.start_sequence(id)
    local seq = _sequences[id]
    if not seq then 
        log("WARN: Sequence not found:", id)
        return 
    end
    
    seq.index = 1
    seq.elapsed = 0
    seq.active_anim = nil
    
    log("Sequence started:", id)
end

--- Stop and remove a sequence
-- @param id (string): Sequence ID to stop
function AnimationEngine.stop_sequence(id)
    if _sequences[id] then
        _sequences[id] = nil
        log("Sequence stopped:", id)
    end
end

-- ==============================
-- Tick / Update Loop
-- ==============================

--- Update all active animations and sequences (call once per frame)
-- @param dt (number): Delta time in seconds since last frame
function AnimationEngine.tick(dt)
    -- Update individual animations
    for id, anim in pairs(_animations) do
        anim.elapsed = anim.elapsed + dt
        local t = math.min(anim.elapsed / anim.duration, 1)
        t = apply_easing(anim.easing, t)
        
        local values = {}
        for k, v in pairs(anim.start) do
            if type(v) == "number" and type(anim.target[k]) == "number" then
                values[k] = lerp(v, anim.target[k], t)
            else
                values[k] = anim.target[k]
            end
        end
        
        if anim.on_update then
            anim.on_update(values, t)
        end
        
        if anim.elapsed >= anim.duration then
            if anim.on_complete then
                anim.on_complete(values)
            end
            if anim.loop then
                anim.elapsed = 0
            else
                _animations[id] = nil
            end
        end
    end
    
    -- Update sequences
    for _, seq in pairs(_sequences) do
        local step = seq.steps[seq.index]
        if not step then
            if seq.loop then
                seq.index = 1
            else
                if seq.on_complete then seq.on_complete() end
                _sequences[seq.id] = nil
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
                seq.active_anim = AnimationEngine.animate(
                    step.from,
                    step.to,
                    step.duration,
                    {
                        easing = step.easing,
                        on_update = step.on_update,
                        on_complete = function()
                            seq.active_anim = nil
                            seq.index = seq.index + 1
                        end
                    }
                )
            end
            
        elseif step.type == "callback" then
            if step.fn then step.fn() end
            seq.index = seq.index + 1
        end
        
        ::continue::
    end
end

-- ==============================
-- Utilities
-- ==============================

--- Stop all animations and sequences
function AnimationEngine.clear_all()
    _animations = {}
    _sequences = {}
    log("All animations and sequences cleared")
end

--- Enable/disable debug logging
-- @param enabled (boolean): True to enable debug logging
function AnimationEngine.set_debug(enabled)
    _debug = enabled
    log("Debug logging " .. (enabled and "enabled" or "disabled"))
end

--- Add a custom easing function
-- @param name (string): Name to register the easing function under
-- @param fn (function): Easing function that takes t (0-1) and returns eased t (0-1)
function AnimationEngine.add_easing_function(name, fn)
    if type(fn) == "function" then
        Enums.Easing[name] = fn
        log("Easing function added:", name)
    else
        log("ERROR: Invalid easing function for name:", name)
    end
end

--- Check if an animation or sequence is currently running
-- @param id (string): Animation/Sequence ID to check
-- @return (boolean): True if animation/sequence is active
function AnimationEngine.is_running(id)
    return _animations[id] ~= nil or _sequences[id] ~= nil
end

--- Get number of active animations and sequences
-- @return (number, number): Count of active animations, count of active sequences
function AnimationEngine.get_active_count()
    local anim_count = 0
    local seq_count = 0
    for _ in pairs(_animations) do anim_count = anim_count + 1 end
    for _ in pairs(_sequences) do seq_count = seq_count + 1 end
    return anim_count, seq_count
end

-- ==============================
-- Animation Sequences Integration
-- ==============================

-- Expose the AnimationSequences module
AnimationEngine.Sequences = AnimationSequences

-- Expose popular sequences directly on AnimationEngine for convenience
local popular_sequences = {
    "summon", "bob", "pulse", "slideIn", "attack", 
    "positionChange", "fade", "shake", "color_pulse", "reset",
    "menu_cursor", "highlight", "complex_summon"
}

for _, seq_name in ipairs(popular_sequences) do
    if AnimationSequences[seq_name] then
        AnimationEngine[seq_name] = function(...)
            return AnimationSequences[seq_name](...)
        end
    end
end

-- ==============================
-- Widget-Specific Animation Helpers
-- ==============================

--- Animate widget properties with sprite synchronization
-- @param widget (table): Widget object with sprite_objects table
-- @param properties (table): Target properties {x=, y=, sx=, sy=, ro=, opacity=, r=, g=, b=, a=}
-- @param duration (number): Animation duration in seconds
-- @param options (table, optional): Animation options:
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
--   - mark_sprites (boolean): Whether to mark sprites as widget-animated (default: true)
-- @return (string): Animation ID
function AnimationEngine.animate_widget(widget, properties, duration, options)
    options = options or {}
    
    if not widget or not widget.sprite_objects then
        log("ERROR: Invalid widget passed to animate_widget")
        return nil
    end
    
    duration = duration or 0.3
    
    -- Mark sprites as widget-animated if requested
    local mark_sprites = options.mark_sprites ~= false
    if mark_sprites then
        for sprite_id, sprite in pairs(widget.sprite_objects) do
            if sprite.set_widget_animated then
                sprite:set_widget_animated(true, {type = "properties"})
            end
        end
    end
    
    -- Set animation flag on widget if available
    if widget._layout_animation_active ~= nil then
        widget._layout_animation_active = true
        widget._layout_animation_type = "properties"
    end
    
    -- Get current values from widget
    local start_values = {
        x = widget.x or 0,
        y = widget.y or 0,
        sx = widget.sx or 1,
        sy = widget.sy or 1,
        ro = widget.ro or 0,
        opacity = widget.opacity or 255,
        r = widget.r or 255,
        g = widget.g or 255,
        b = widget.b or 255,
        a = widget.a or 255
    }
    
    -- Create target values
    local target_values = {}
    for key, value in pairs(properties) do
        if start_values[key] ~= nil then
            target_values[key] = value
        end
    end
    
    local anim_id = AnimationEngine.animate(start_values, target_values, duration, {
        easing = options.easing or "ease_in_out",
        on_update = function(values)
            -- Update widget properties
            for key, value in pairs(values) do
                if widget[key] ~= nil then
                    widget[key] = value
                end
            end
            
            -- Update sprites to match widget
            for sprite_id, sprite in pairs(widget.sprite_objects) do
                if sprite.update then
                    local sprite_props = {}
                    if values.x then sprite_props.x = values.x end
                    if values.y then sprite_props.y = values.y end
                    if values.sx then sprite_props.sx = values.sx end
                    if values.sy then sprite_props.sy = values.sy end
                    if values.ro then sprite_props.ro = values.ro end
                    if values.opacity then sprite_props.opacity = values.opacity end
                    if values.r then sprite_props.r = values.r end
                    if values.g then sprite_props.g = values.g end
                    if values.b then sprite_props.b = values.b end
                    if values.a then sprite_props.a = values.a end
                    
                    sprite:update(sprite_props)
                end
            end
            
            if options.on_update then
                options.on_update(values)
            end
        end,
        on_complete = function(values, interrupted)
            -- Clear widget animation flags if available
            if widget._layout_animation_active ~= nil then
                widget._layout_animation_active = false
                widget._layout_animation_type = nil
            end
            
            -- Unmark sprites if they were marked
            if mark_sprites then
                for sprite_id, sprite in pairs(widget.sprite_objects) do
                    if sprite.set_widget_animated then
                        sprite:set_widget_animated(false)
                    end
                end
            end
            
            if options.on_complete then
                options.on_complete(values, interrupted)
            end
        end
    })
    
    return anim_id
end

--- Create a summon animation for a widget (convenience wrapper)
-- @param widget (table): Widget object to animate
-- @param start_x (number): Starting X position
-- @param start_y (number): Starting Y position
-- @param start_scale (number): Starting scale factor
-- @param end_x (number): Target X position
-- @param end_y (number): Target Y position
-- @param end_scale (number): Target scale factor
-- @param options (table, optional): Animation options including:
--   - duration (number): Animation duration
--   - arc_height (number): Height of the arc curve
--   - peak_scale_mul (number): Peak scale multiplier during animation
--   - wobble_deg (number): Rotation wobble in degrees
--   - easing (string): Easing function name
--   - on_complete (function): Completion callback
-- @return (string): Animation/Sequence ID
function AnimationEngine.summon_widget(widget, start_x, start_y, start_scale, end_x, end_y, end_scale, options)
    return AnimationEngine.summon(widget, start_x, start_y, start_scale, 
                                 end_x, end_y, end_scale, options)
end

--- Create a bob animation for a widget (convenience wrapper)
-- @param widget (table): Widget object to animate
-- @param options (table, optional): Animation options:
--   - distance (number): Vertical bobbing distance
--   - duration (number): Full bob cycle duration
--   - easing (string): Easing function name
--   - loop (boolean): Whether to loop continuously
--   - ping_pong (boolean): Whether to reverse direction each cycle
--   - on_complete (function): Completion callback
-- @return (string): Animation ID
function AnimationEngine.bob_widget(widget, options)
    return AnimationEngine.bob(widget, options)
end

-- ==============================
-- Public API Surface
-- ==============================
AnimationEngine.Enums = Enums        -- Easing functions and animation constants
AnimationEngine.Math = MathUtils     -- Mathematical utilities and helpers

-- ==============================
-- Backward Compatibility Functions
-- ==============================

--- Load animation modules (for backward compatibility with existing code)
-- @return table, table, table: AnimationEngine, AnimationSequences, AnimationEnums
function AnimationEngine.load_animation_modules()
    log("Loading animation modules via AnimationEngine.load_animation_modules()")
    return AnimationEngine, AnimationEngine.Sequences, AnimationEngine.Enums
end

return AnimationEngine