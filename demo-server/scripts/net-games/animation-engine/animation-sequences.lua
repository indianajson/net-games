-- animation-sequences.lua
-- Pre-built animation sequences for common animation patterns
-- Directly requires animation-engine and animation-enums modules

local Sequences = {}
local Enums = require("scripts/net-games/animation-engine/animation-enums")
local Math = require("scripts/net-games/animation-engine/math-utils")
-- ==============================
-- Default Configuration
-- ==============================

Sequences.config = {
    -- Default animation parameters
    default_duration = 0.25,
    default_easing = "ease_in_out",

    -- Summon animation: fly in with arc, scale pulse, and rotation wobble
    summon = {
        arc_height = 24,           -- Height of the arc curve
        peak_scale_mul = 1.35,     -- Scale multiplier at peak of animation
        wobble_ro_deg = 5,         -- Maximum rotation wobble in degrees
        duration = 0.25            -- Default duration in seconds
    },

    -- Position change animation: for changing position/rotation with visual feedback
    position_change = {
        duration = 0.18,           -- Default duration in seconds
        peak_scale_mul = 1.15,     -- Scale multiplier at midpoint
        flip_min = 0.06            -- Minimum scale for flip effect
    },

    -- Attack animation: recoil back, then lunge forward, then return
    attack = {
        duration = 0.22,           -- Total duration in seconds
        recoil_distance = 5,       -- Distance to recoil (negative Y)
        lunge_distance = 15,       -- Distance to lunge forward (positive Y)
        t1 = 0.25,                 -- Time fraction when recoil ends (0-1)
        t2 = 0.60                  -- Time fraction when lunge ends (0-1)
    },

    -- Slide animation: smooth linear movement
    slide = {
        duration = 0.15,           -- Default duration in seconds
        easing = "ease_out"        -- Default easing function
    },

    -- Bob animation: vertical bouncing for idle/menu animations
    bob = {
        duration = 1.0,            -- Full bob cycle duration
        distance = 3,              -- Vertical distance to move
        easing = "smoothstep",     -- Easing for smooth motion
        loop = true,               -- Loop continuously by default
        ping_pong = true           -- Reverse direction each cycle
    },

    -- Pulse animation: scale and alpha pulsing for highlighting
    pulse = {
        duration = 0.8,            -- Pulse cycle duration
        scale_from = 1.0,          -- Starting scale
        scale_to = 1.1,            -- Target scale
        alpha_from = 255,          -- Starting alpha (0-255)
        alpha_to = 200,            -- Target alpha (0-255)
        easing = "ease_in_out",    -- Easing function
        loop = true,               -- Loop continuously
        ping_pong = true           -- Ping-pong between values
    },

    -- Fade animation: smooth alpha transitions
    fade = {
        duration = 0.3,            -- Default fade duration
        easing = "ease_in_out"     -- Default easing
    },

    -- Shake animation: screen shake effect for impacts
    shake = {
        duration = 0.5,            -- Total shake duration
        intensity = 5,             -- Maximum shake distance
        frequency = 15,            -- Oscillations per second
        easing = "ease_out"        -- Shake intensity decays over time
    },

    -- Color pulse animation: color transition with looping
    color_pulse = {
        duration = 0.8,            -- Color transition duration
        easing = "ease_in_out",    -- Color interpolation easing
        loop = true,               -- Loop continuously
        ping_pong = true           -- Ping-pong between colors
    }
}

-- ==============================
-- Core Animation Sequences
-- ==============================

--- Create a summon animation (flies with arc, scales, and wobbles)
-- @param object (table): The object to animate (must have x, y, scale, rotation properties)
-- @param sx (number): Starting X position
-- @param sy (number): Starting Y position
-- @param ss (number): Starting scale factor
-- @param ex (number): Ending X position
-- @param ey (number): Ending Y position
-- @param es (number): Ending scale factor
-- @param options (table, optional): Animation options:
--   - duration (number): Animation duration in seconds
--   - arc_height (number): Height of the arc curve
--   - peak_scale_mul (number): Scale multiplier at animation peak
--   - wobble_deg (number): Maximum rotation wobble in degrees
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation (receives current values)
--   - on_complete (function): Callback when animation completes
-- @return (string): Sequence ID for tracking and control
function Sequences.summon(object, sx, sy, ss, ex, ey, es, options)
    options = options or {}
    local cfg = Sequences.config.summon

    local arc = options.arc_height or cfg.arc_height
    local peak = options.peak_scale_mul or cfg.peak_scale_mul
    local wobble = options.wobble_deg or cfg.wobble_ro_deg
    local duration = options.duration or cfg.duration
    local easing = options.easing or Sequences.config.default_easing

    -- Control point for quadratic bezier curve (creates arc)
    local cx = (sx + ex) * 0.5
    local cy = (sy + ey) * 0.5 - arc

    local seq = AnimationEngine.create_sequence({
        {
            type = "animate",
            duration = duration,
            easing = easing,
            on_update = function(_, t)
                -- Calculate position along quadratic bezier curve
                local x, y = MathUtils.quadratic_bezier(
                    {x = sx, y = sy},
                    {x = cx, y = cy},
                    {x = ex, y = ey},
                    t
                )

                -- Scale with sine wave pulse effect
                local scale = MathUtils.lerp(ss, es, t)
                scale = scale * (1 + (peak - 1) * math.sin(math.pi * t))

                -- Rotation wobble effect
                local rotation = wobble * math.sin(t * math.pi * 2)

                -- Apply to object
                object.x = x
                object.y = y
                object.scale = scale
                object.rotation = rotation
                
                -- Call custom update callback if provided
                if options.on_update then
                    options.on_update({
                        x = x, y = y, scale = scale, rotation = rotation,
                        progress = t
                    }, t)
                end
            end,
            on_complete = options.on_complete
        }
    })

    AnimationEngine.start_sequence(seq)
    return seq
end

--- Create a position change animation (rotate and scale pulse)
-- @param object (table): The object to animate (must have rotation, scale properties)
-- @param start_rot (number): Starting rotation in degrees
-- @param end_rot (number): Ending rotation in degrees
-- @param options (table, optional): Animation options:
--   - duration (number): Animation duration in seconds
--   - peak_scale_mul (number): Scale multiplier at animation midpoint
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Sequence ID for tracking and control
function Sequences.positionChange(object, start_rot, end_rot, options)
    options = options or {}
    local cfg = Sequences.config.position_change

    local duration = options.duration or cfg.duration
    local peak = options.peak_scale_mul or cfg.peak_scale_mul
    local easing = options.easing or Sequences.config.default_easing
    local base_scale = object.scale or 1

    local seq = AnimationEngine.create_sequence({
        {
            type = "animate",
            duration = duration,
            easing = easing,
            on_update = function(_, t)
                -- Interpolate rotation
                object.rotation = MathUtils.lerp(start_rot, end_rot, t)
                
                -- Scale pulse effect (largest at midpoint)
                object.scale = base_scale * (1 + (peak - 1) * math.sin(math.pi * t))
                
                if options.on_update then
                    options.on_update({
                        rotation = object.rotation, scale = object.scale,
                        progress = t
                    }, t)
                end
            end,
            on_complete = options.on_complete
        }
    })

    AnimationEngine.start_sequence(seq)
    return seq
end

--- Create an attack animation (recoil → lunge → return)
-- @param object (table): The object to animate (must have y, scale properties)
-- @param recoil (number): Recoil distance (negative = up/back)
-- @param lunge (number): Lunge distance (positive = down/forward)
-- @param options (table, optional): Animation options:
--   - duration (number): Total animation duration in seconds
--   - t1 (number): Time fraction when recoil phase ends (0-1)
--   - t2 (number): Time fraction when lunge phase ends (0-1)
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Sequence ID for tracking and control
function Sequences.attack(object, recoil, lunge, options)
    options = options or {}
    local cfg = Sequences.config.attack

    local duration = options.duration or cfg.duration
    local t1 = options.t1 or cfg.t1
    local t2 = options.t2 or cfg.t2
    local start_y = object.y or 0
    local seq = nil
    seq = AnimationEngine.create_sequence({
        {
            type = "animate",
            duration = duration,
            easing = Sequences.config.default_easing,
            on_update = function(_, t)
                local offset = 0
                
                -- Three-phase movement: recoil → lunge → return
                if t < t1 then
                    -- Recoil phase: move backward
                    offset = MathUtils.lerp(0, recoil, t / t1)
                elseif t < t2 then
                    -- Lunge phase: move forward
                    offset = MathUtils.lerp(recoil, lunge, (t - t1) / (t2 - t1))
                else
                    -- Return phase: move back to original position
                    offset = MathUtils.lerp(lunge, 0, (t - t2) / (1 - t2))
                end
                
                -- Apply Y offset
                object.y = start_y + offset
                
                -- Add slight scale pulse for impact effect
                object.scale = 1 + 0.1 * math.sin(math.pi * t)
                
                if options.on_update then
                    options.on_update({
                        y = object.y, offset = offset, scale = object.scale,
                        progress = t
                    }, t)
                end
            end,
            on_complete = options.on_complete
        }
    })

    AnimationEngine.start_sequence(seq)
    return seq
end

--- Create a slide in animation (smooth linear movement)
-- @param object (table): The object to animate (must have x, y properties)
-- @param sx (number): Starting X position
-- @param sy (number): Starting Y position
-- @param ex (number): Ending X position
-- @param ey (number): Ending Y position
-- @param options (table, optional): Animation options:
--   - duration (number): Animation duration in seconds
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Animation ID for tracking and control
function Sequences.slideIn(object, sx, sy, ex, ey, options)
    options = options or {}
    local cfg = Sequences.config.slide

    return AnimationEngine.animate(
        {x = sx, y = sy},
        {x = ex, y = ey},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            on_update = function(v)
                object.x = v.x
                object.y = v.y
                if options.on_update then
                    options.on_update(v)
                end
            end,
            on_complete = options.on_complete
        }
    )
end

--- Create a bob animation (vertical bouncing)
-- @param object (table): The object to animate (must have y property)
-- @param options (table, optional): Animation options:
--   - distance (number): Vertical distance to move
--   - duration (number): Full bob cycle duration
--   - easing (string): Easing function name
--   - loop (boolean): Whether to loop continuously
--   - ping_pong (boolean): Whether to reverse direction each cycle
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes (called once if loop=false)
-- @return (string): Animation ID for tracking and control
function Sequences.bob(object, options)
    options = options or {}
    local cfg = Sequences.config.bob
    local y0 = object.y or 0

    return AnimationEngine.animate(
        {y = y0},
        {y = y0 - (options.distance or cfg.distance)},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            loop = options.loop ~= false,
            ping_pong = options.ping_pong ~= false,
            on_update = function(v) 
                object.y = v.y 
                if options.on_update then
                    options.on_update(v)
                end
            end,
            on_complete = options.on_complete
        }
    )
end

--- Create a pulse animation (scale and alpha pulsing)
-- @param object (table): The object to animate (must have scale, alpha/opacity properties)
-- @param options (table, optional): Animation options:
--   - scale_from (number): Starting scale factor
--   - scale_to (number): Target scale factor
--   - alpha_from (number): Starting alpha value (0-255)
--   - alpha_to (number): Target alpha value (0-255)
--   - duration (number): Pulse cycle duration
--   - easing (string): Easing function name
--   - loop (boolean): Whether to loop continuously
--   - ping_pong (boolean): Whether to reverse direction each cycle
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Animation ID for tracking and control
function Sequences.pulse(object, options)
    options = options or {}
    local cfg = Sequences.config.pulse

    return AnimationEngine.animate(
        {
            scale = options.scale_from or cfg.scale_from, 
            alpha = options.alpha_from or cfg.alpha_from
        },
        {
            scale = options.scale_to or cfg.scale_to, 
            alpha = options.alpha_to or cfg.alpha_to
        },
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            loop = options.loop ~= false,
            ping_pong = options.ping_pong ~= false,
            on_update = function(v)
                object.scale = v.scale
                object.alpha = v.alpha
                if options.on_update then
                    options.on_update(v)
                end
            end,
            on_complete = options.on_complete
        }
    )
end

--- Create a fade animation (alpha transition)
-- @param object (table): The object to animate (must have alpha/opacity property)
-- @param target_alpha (number): Target alpha value (0-255)
-- @param options (table, optional): Animation options:
--   - duration (number): Fade duration in seconds
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Animation ID for tracking and control
function Sequences.fade(object, target_alpha, options)
    options = options or {}
    local cfg = Sequences.config.fade

    return AnimationEngine.animate(
        {alpha = object.alpha or 255},
        {alpha = target_alpha},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            on_update = function(v) 
                object.alpha = v.alpha 
                if options.on_update then
                    options.on_update(v)
                end
            end,
            on_complete = options.on_complete
        }
    )
end

--- Create a shake animation (screen shake effect)
-- @param object (table): The object to animate (must have x, y properties)
-- @param options (table, optional): Animation options:
--   - intensity (number): Maximum shake distance
--   - duration (number): Total shake duration
--   - frequency (number): Oscillations per second
--   - easing (string): Easing for intensity decay
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Animation ID for tracking and control
function Sequences.shake(object, options)
    options = options or {}
    local cfg = Sequences.config.shake

    local intensity = options.intensity or cfg.intensity
    local duration = options.duration or cfg.duration
    local frequency = options.frequency or cfg.frequency
    local easing = options.easing or cfg.easing
    local start_x = object.x or 0
    local start_y = object.y or 0

    return AnimationEngine.animate(
        {t = 0},
        {t = 1},
        duration,
        {
            easing = easing,
            on_update = function(v)
                local t = v.t
                -- Calculate shake intensity (decays over time)
                local current_intensity = intensity * (1 - t)
                
                -- Calculate shake offset using sine waves
                local shake_x = math.sin(t * frequency * math.pi * 2) * current_intensity
                local shake_y = math.cos(t * frequency * math.pi * 2) * current_intensity * 0.7
                
                -- Apply shake to object
                object.x = start_x + shake_x
                object.y = start_y + shake_y
                
                if options.on_update then
                    options.on_update({
                        x = object.x, y = object.y,
                        intensity = current_intensity, progress = t
                    })
                end
            end,
            on_complete = function()
                -- Return to original position
                object.x = start_x
                object.y = start_y
                if options.on_complete then
                    options.on_complete()
                end
            end
        }
    )
end

--- Create a color pulse animation (transition between two colors)
-- @param object (table): The object to animate (must have r,g,b,a or setColor method)
-- @param start_color (table): Starting color {r,g,b,a} (each 0-255)
-- @param target_color (table): Target color {r,g,b,a} (each 0-255)
-- @param options (table, optional): Animation options:
--   - duration (number): Color transition duration
--   - easing (string): Easing function name
--   - loop (boolean): Whether to loop continuously
--   - ping_pong (boolean): Whether to reverse direction each cycle
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Animation ID for tracking and control
function Sequences.color_pulse(object, start_color, target_color, options)
    options = options or {}
    local cfg = Sequences.config.color_pulse

    -- Normalize color values
    local start_r = start_color.r or start_color[1] or 255
    local start_g = start_color.g or start_color[2] or 255
    local start_b = start_color.b or start_color[3] or 255
    local start_a = start_color.a or start_color[4] or (object.alpha or 255)
    
    local target_r = target_color.r or target_color[1] or 255
    local target_g = target_color.g or target_color[2] or 255
    local target_b = target_color.b or target_color[3] or 255
    local target_a = target_color.a or target_color[4] or start_a

    return AnimationEngine.animate(
        {r = start_r, g = start_g, b = start_b, a = start_a},
        {r = target_r, g = target_g, b = target_b, a = target_a},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            loop = options.loop ~= false,
            ping_pong = options.ping_pong ~= false,
            on_update = function(v)
                -- Apply color to object
                if object.setColor then
                    object:setColor(v.r, v.g, v.b, v.a)
                else
                    object.r = v.r
                    object.g = v.g
                    object.b = v.b
                    object.a = v.a
                end
                
                if object.setAlpha and v.a then
                    object:setAlpha(v.a)
                elseif v.a then
                    object.alpha = v.a
                end
                
                if options.on_update then
                    options.on_update(v)
                end
            end,
            on_complete = options.on_complete
        }
    )
end

--- Reset an object to default/initial values
-- @param object (table): The object to reset
-- @param initial (table, optional): Initial values to set (defaults to common properties):
--   - x (number): X position (default: current x)
--   - y (number): Y position (default: current y)
--   - scale (number): Scale factor (default: 1)
--   - rotation (number): Rotation in degrees (default: 0)
--   - alpha (number): Alpha value 0-255 (default: 255)
function Sequences.reset(object, initial)
    initial = initial or {}
    
    -- Set properties directly
    if initial.x ~= nil then object.x = initial.x end
    if initial.y ~= nil then object.y = initial.y end
    object.scale = initial.scale or 1
    object.rotation = initial.rotation or 0
    object.alpha = initial.alpha or 255
    
    -- Also set color components if specified
    if initial.r then object.r = initial.r end
    if initial.g then object.g = initial.g end
    if initial.b then object.b = initial.b end
    if initial.a then object.a = initial.a end
end

--- Create a menu cursor animation (bob + pulse combination)
-- @param object (table): The object to animate
-- @param options (table, optional): Animation options:
--   - bob_distance (number): Vertical bobbing distance
--   - pulse_scale (number): Maximum scale during pulse
--   - bob_duration (number): Bob cycle duration
--   - pulse_duration (number): Pulse cycle duration
--   - orientation (string): "vertical" or "horizontal" bobbing
--   - easing (string): Easing function for bobbing
--   - back_easing (string): Easing function for return phase
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (table): Table with animation IDs and stop function: {bob=id1, pulse=id2, stop=function}
function Sequences.menu_cursor(object, options)
    options = options or {}
    
    local bob_distance = options.bob_distance or 2
    local pulse_scale = options.pulse_scale or 1.1
    local bob_duration = options.bob_duration or 0.8
    local pulse_duration = options.pulse_duration or (bob_duration * 1.5)
    local easing = options.easing or "smootherstep"
    local back_easing = options.back_easing or "smootherstep"
    local orientation = options.orientation or "vertical"
    
    local axis = (orientation == "vertical") and "y" or "x"
    local start_pos = object[axis] or 0
    local start_scale = object.scale or 1.0
    
    -- Start bob animation
    local bob_id = AnimationEngine.animate(
        {[axis] = start_pos},
        {[axis] = start_pos - bob_distance},
        bob_duration,
        {
            easing = easing,
            easing_back = back_easing,
            on_update = function(v)
                object[axis] = v[axis]
                if options.on_update then
                    options.on_update(v)
                end
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    -- Start pulse animation
    local pulse_id = AnimationEngine.animate(
        {scale = 1.0},
        {scale = pulse_scale},
        pulse_duration,
        {
            easing = "ease_in_out",
            on_update = function(v)
                object.scale = start_scale * v.scale
                if options.on_update then
                    options.on_update(v)
                end
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    -- Return controller object
    return {
        bob = bob_id,
        pulse = pulse_id,
        stop = function()
            if bob_id then AnimationEngine.stop_animation(bob_id) end
            if pulse_id then AnimationEngine.stop_animation(pulse_id) end
            if options.on_complete then
                options.on_complete({stopped = true})
            end
        end
    }
end

--- Create a highlight animation (lift up and glow)
-- @param object (table): The object to animate
-- @param options (table, optional): Animation options:
--   - lift_amount (number): Distance to lift up (negative Y)
--   - glow_alpha (number): Target alpha for glow effect
--   - duration (number): Animation duration
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Animation ID for tracking and control
function Sequences.highlight(object, options)
    options = options or {}
    
    local lift_amount = options.lift_amount or 5
    local glow_alpha = options.glow_alpha or 100
    local duration = options.duration or 0.15
    local easing = options.easing or "ease_out"
    local start_y = object.y or 0
    local start_alpha = object.alpha or 255
    
    return AnimationEngine.animate(
        {y = start_y, alpha = start_alpha},
        {y = start_y - lift_amount, alpha = glow_alpha},
        duration,
        {
            easing = easing,
            on_update = function(v)
                object.y = v.y
                object.alpha = v.alpha
                if options.on_update then
                    options.on_update(v)
                end
            end,
            on_complete = options.on_complete
        }
    )
end

--- Create a complex summon animation with multiple phases
-- @param object (table): The object to animate
-- @param sx (number): Starting X position
-- @param sy (number): Starting Y position
-- @param ss (number): Starting scale factor
-- @param ex (number): Ending X position
-- @param ey (number): Ending Y position
-- @param es (number): Ending scale factor
-- @param options (table, optional): Animation options:
--   - arc_duration (number): Duration of arc movement phase
--   - wobble_duration (number): Duration of wobble phase
--   - settle_duration (number): Duration of settle phase
--   - arc_height (number): Height of arc curve
--   - peak_scale_mul (number): Scale multiplier at peak
--   - wobble_deg (number): Maximum rotation wobble
--   - easing (string): Base easing function
--   - on_update_step1 (function): Callback during arc phase
--   - on_update_step2 (function): Callback during wobble phase
--   - on_update_step3 (function): Callback during settle phase
--   - on_complete (function): Callback when entire sequence completes
-- @return (string): Sequence ID for tracking and control
function Sequences.complex_summon(object, sx, sy, ss, ex, ey, es, options)
    options = options or {}
    
    local arc_duration = options.arc_duration or 0.25
    local wobble_duration = options.wobble_duration or 0.1
    local settle_duration = options.settle_duration or 0.05
    local arc_height = options.arc_height or 40
    local peak_scale_mul = options.peak_scale_mul or 1.35
    local wobble_deg = options.wobble_deg or 10
    local easing = options.easing or "ease_in_out"
    
    local control_x = (sx + ex) * 0.5
    local control_y = (sy + ey) * 0.5 - arc_height
    
    local sequence_steps = {}
    
    -- Step 1: Arc movement with scale pulse
    table.insert(sequence_steps, {
        type = "animate",
        duration = arc_duration,
        easing = easing,
        on_update = function(values, t, phase)
            local u = 1 - t
            local x = u*u*sx + 2*u*t*control_x + t*t*ex
            local y = u*u*sy + 2*u*t*control_y + t*t*ey
            
            local base_scale = MathUtils.lerp(ss, es, t)
            local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
            local current_scale = base_scale * pulse
            
            object.x = x
            object.y = y
            object.scale = current_scale
            
            if options.on_update_step1 then
                options.on_update_step1({x = x, y = y, scale = current_scale, progress = t})
            end
        end
    })
    
    -- Step 2: Rotation wobble
    if wobble_deg and wobble_deg > 0 then
        table.insert(sequence_steps, {
            type = "animate",
            duration = wobble_duration,
            easing = "elastic_out",
            on_update = function(values, t, phase)
                local wobble = math.sin(t * math.pi * 4) * wobble_deg * (1 - t)
                object.rotation = wobble
                
                if options.on_update_step2 then
                    options.on_update_step2({rotation = wobble, progress = t})
                end
            end
        })
    end
    
    -- Step 3: Final settle
    table.insert(sequence_steps, {
        type = "animate",
        duration = settle_duration,
        easing = "bounce_out",
        on_update = function(values, t, phase)
            object.scale = es * (1 - 0.05 * (1 - t))
            object.rotation = 0
            
            if options.on_update_step3 then
                options.on_update_step3({scale = object.scale, progress = t})
            end
        end,
        on_complete = options.on_complete
    })
    
    local seq_id = AnimationEngine.create_sequence(sequence_steps)
    AnimationEngine.start_sequence(seq_id)
    return seq_id
end

return Sequences