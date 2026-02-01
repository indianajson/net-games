-- -- animation-sequences.lua
-- -- General purpose animation sequences that mimic duels.lua behaviors
-- -- Works with any sprite_id and object properties
-- 
-- local AnimationSequences = {}
-- _G.AnimationSequences = AnimationSequences
-- 
-- -- Load the animation engine
-- local AnimationEngine = _G.AnimationEngine or require("scripts/net-games/animation-engine/animation-engine")
-- local AnimationEnums = _G.AnimationEnums or require("scripts/net-games/animation-engine/animation-enums")
-- local MathUtils = require("scripts/net-games/animation-engine/math-utils")
-- 
-- -- ---------------------------------------------------------------------------
-- -- Configuration
-- -- ---------------------------------------------------------------------------
-- AnimationSequences.config = {
--     -- Default animation parameters
--     default_duration = 0.25,
--     default_easing = "ease_in_out",
--     
--     -- Summon animation defaults
--     summon = {
--         arc_height = 24,
--         peak_scale_mul = 1.35,
--         wobble_ro_deg = 5,
--         duration = 0.25,
--         z_offset = 10
--     },
--     
--     -- Position change animation defaults
--     position_change = {
--         duration = 0.18,
--         peak_scale_mul = 1.15,
--         flip_min = 0.06,
--         swap_t = 0.5
--     },
--     
--     -- Attack animation defaults
--     attack = {
--         duration = 0.22,
--         recoil_distance = 5,
--         lunge_distance = 15,
--         t1 = 0.25,  -- end recoil
--         t2 = 0.60,  -- end lunge
--         z_offset = 12
--     },
--     
--     -- Slide animation defaults
--     slide = {
--         duration = 0.15,
--         easing = "ease_out"
--     },
--     
--     -- Bob animation defaults (for idle/menu animations)
--     bob = {
--         duration = 1.0,
--         distance = 3,
--         easing = "smoothstep",
--         loop = true,
--         ping_pong = true
--     },
--     
--     -- Pulse animation defaults (for highlighting)
--     pulse = {
--         duration = 0.8,
--         scale_from = 1.0,
--         scale_to = 1.1,
--         alpha_from = 255,
--         alpha_to = 200,
--         easing = "elastic_out",
--         loop = true,
--         ping_pong = true
--     },
--     
--     -- Shake animation defaults (for hit/recoil)
--     shake = {
--         duration = 0.15,
--         intensity = 3,
--         frequency = 15,
--         easing = "elastic_out"
--     },
--     
--     -- Fade animation defaults
--     fade = {
--         duration = 0.3,
--         easing = "ease_in_out"
--     },
--     
--     -- Color pulse animation defaults
--     color_pulse = {
--         duration = 0.8,
--         easing = "ease_in_out",
--         loop = true,
--         ping_pong = true
--     }
-- }
-- 
-- -- ---------------------------------------------------------------------------
-- -- Core Animation Sequences
-- -- ---------------------------------------------------------------------------
-- 
-- -- Create a summon animation (card flies from start to end with arc)
-- function AnimationSequences.summon(object, start_x, start_y, start_scale, 
--                                  end_x, end_y, end_scale, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.summon
--     local duration = options.duration or cfg.duration
--     local arc_height = options.arc_height or cfg.arc_height
--     local peak_scale_mul = options.peak_scale_mul or cfg.peak_scale_mul
--     local wobble_deg = options.wobble_deg or cfg.wobble_ro_deg
--     local easing = options.easing or AnimationSequences.config.default_easing
--     local on_complete = options.on_complete
--     local on_update = options.on_update
--     
--     -- Calculate control point for arc
--     local control_x = (start_x + end_x) * 0.5
--     local control_y = (start_y + end_y) * 0.5 - arc_height
--     
--     -- Store initial properties
--     local initial_values = {
--         x = start_x,
--         y = start_y,
--         scale = start_scale,
--         progress = 0
--     }
--     
--     -- Create animation sequence
--     local sequence_id = AnimationEngine.create_sequence({
--         {
--             type = "animate",
--             duration = duration,
--             easing = easing,
--             on_update = function(values, t, phase)
--                 -- Calculate bezier position
--                 local x, y = MathUtils.quadratic_bezier(
--                     {x = start_x, y = start_y},
--                     {x = control_x, y = control_y},
--                     {x = end_x, y = end_y},
--                     t
--                 )
--                 
--                 -- Calculate scale with pulse
--                 local base_scale = MathUtils.lerp(start_scale, end_scale, t)
--                 local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
--                 local current_scale = base_scale * pulse
--                 
--                 -- Calculate rotation with wobble
--                 local base_rotation = MathUtils.lerp(0, 0, t) -- No base rotation
--                 local wobble = wobble_deg ~= 0 and math.sin(math.pi * 2 * t) * wobble_deg or 0
--                 local current_rotation = base_rotation + wobble
--                 
--                 -- Apply to object
--                 object.x = x
--                 object.y = y
--                 object.scale = current_scale
--                 object.rotation = current_rotation
--                 
--                 -- Call custom update if provided
--                 if on_update then
--                     on_update({
--                         x = x,
--                         y = y,
--                         scale = current_scale,
--                         rotation = current_rotation,
--                         progress = t
--                     }, t, phase)
--                 end
--             end,
--             on_complete = on_complete
--         }
--     })
--     
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Create a set animation (similar to summon but with flip and rotation)
-- function AnimationSequences.set(object, start_x, start_y, start_scale, start_rotation,
--                               end_x, end_y, end_scale, end_rotation, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.position_change
--     local duration = options.duration or cfg.duration
--     local peak_scale_mul = options.peak_scale_mul or cfg.peak_scale_mul
--     local flip_min = options.flip_min or cfg.flip_min
--     local swap_t = options.swap_t or cfg.swap_t
--     local easing = options.easing or AnimationSequences.config.default_easing
--     local on_complete = options.on_complete
--     local on_update = options.on_update
--     
--     local sequence_id = AnimationEngine.create_sequence({
--         {
--             type = "animate",
--             duration = duration,
--             easing = easing,
--             on_update = function(values, t, phase)
--                 -- Linear interpolation for position
--                 local x = MathUtils.lerp(start_x, end_x, t)
--                 local y = MathUtils.lerp(start_y, end_y, t)
--                 
--                 -- Linear interpolation for rotation
--                 local rotation = MathUtils.lerp(start_rotation, end_rotation, t)
--                 
--                 -- Calculate scale with midpoint pulse
--                 local base_scale = MathUtils.lerp(start_scale, end_scale, t)
--                 local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
--                 local current_scale = base_scale * pulse
--                 
--                 -- Flip effect: width shrinks at midpoint
--                 local edge = math.abs(2 * t - 1) -- 1 at ends, 0 at mid
--                 local width_scale = flip_min + (1 - flip_min) * edge
--                 
--                 -- Apply to object (with flip effect on X scale)
--                 object.x = x
--                 object.y = y
--                 object.rotation = rotation
--                 object.scaleX = current_scale * width_scale
--                 object.scaleY = current_scale
--                 
--                 -- Call custom update if provided
--                 if on_update then
--                     on_update({
--                         x = x,
--                         y = y,
--                         scaleX = current_scale * width_scale,
--                         scaleY = current_scale,
--                         rotation = rotation,
--                         progress = t
--                     }, t, phase)
--                 end
--             end,
--             on_complete = on_complete
--         }
--     })
--     
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Create a position change animation (rotate and reveal)
-- function AnimationSequences.positionChange(object, start_rotation, end_rotation, 
--                                          options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.position_change
--     local duration = options.duration or cfg.duration
--     local peak_scale_mul = options.peak_scale_mul or cfg.peak_scale_mul
--     local easing = options.easing or AnimationSequences.config.default_easing
--     local on_complete = options.on_complete
--     local on_update = options.on_update
--     
--     -- Store initial values
--     local start_scale = object.scale or 1
--     local start_x = object.x or 0
--     local start_y = object.y or 0
--     
--     local sequence_id = AnimationEngine.create_sequence({
--         {
--             type = "animate",
--             duration = duration,
--             easing = easing,
--             on_update = function(values, t, phase)
--                 -- Interpolate rotation
--                 local rotation = MathUtils.lerp(start_rotation, end_rotation, t)
--                 
--                 -- Scale pulse at midpoint
--                 local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
--                 local current_scale = start_scale * pulse
--                 
--                 -- Apply to object
--                 object.rotation = rotation
--                 object.scale = current_scale
--                 
--                 -- Call custom update if provided
--                 if on_update then
--                     on_update({
--                         rotation = rotation,
--                         scale = current_scale,
--                         x = start_x,
--                         y = start_y,
--                         progress = t
--                     }, t, phase)
--                 end
--             end,
--             on_complete = on_complete
--         }
--     })
--     
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Create an attack animation (recoil then lunge)
-- function AnimationSequences.attack(object, recoil_offset, lunge_offset, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.attack
--     local duration = options.duration or cfg.duration
--     local t1 = options.t1 or cfg.t1
--     local t2 = options.t2 or cfg.t2
--     local easing = options.easing or AnimationSequences.config.default_easing
--     local on_complete = options.on_complete
--     local on_update = options.on_update
--     
--     -- Store initial position
--     local start_x = object.x or 0
--     local start_y = object.y or 0
--     
--     local sequence_id = AnimationEngine.create_sequence({
--         {
--             type = "animate",
--             duration = duration,
--             easing = easing,
--             on_update = function(values, t, phase)
--                 local offset_y = 0
--                 
--                 -- Three-phase movement: recoil -> lunge -> return
--                 if t < t1 then
--                     -- Recoil phase
--                     local u = MathUtils.easing_functions.smoothstep(t / t1)
--                     offset_y = MathUtils.lerp(0, recoil_offset, u)
--                 elseif t < t2 then
--                     -- Lunge phase
--                     local u = MathUtils.easing_functions.smoothstep((t - t1) / (t2 - t1))
--                     offset_y = MathUtils.lerp(recoil_offset, lunge_offset, u)
--                 else
--                     -- Return phase
--                     local u = MathUtils.easing_functions.smoothstep((t - t2) / (1 - t2))
--                     offset_y = MathUtils.lerp(lunge_offset, 0, u)
--                 end
--                 
--                 -- Apply movement
--                 object.y = start_y + offset_y
--                 
--                 -- Add slight scale change for impact
--                 local impact_scale = 1.0 + 0.1 * math.sin(math.pi * t)
--                 object.scale = impact_scale
--                 
--                 -- Call custom update if provided
--                 if on_update then
--                     on_update({
--                         x = start_x,
--                         y = start_y + offset_y,
--                         scale = impact_scale,
--                         offset = offset_y,
--                         progress = t
--                     }, t, phase)
--                 end
--             end,
--             on_complete = on_complete
--         }
--     })
--     
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Create a slide animation (move from offscreen to position)
-- function AnimationSequences.slideIn(object, start_x, start_y, end_x, end_y, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.slide
--     local duration = options.duration or cfg.duration
--     local easing = options.easing or cfg.easing
--     local on_complete = options.on_complete
--     local on_update = options.on_update
--     
--     local sequence_id = AnimationEngine.create_sequence({
--         {
--             type = "animate",
--             start = {x = start_x, y = start_y},
--             target = {x = end_x, y = end_y},
--             duration = duration,
--             easing = easing,
--             on_update = function(values)
--                 object.x = values.x
--                 object.y = values.y
--                 
--                 if on_update then
--                     on_update(values)
--                 end
--             end,
--             on_complete = on_complete
--         }
--     })
--     
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Create a bob animation (up and down movement)
-- function AnimationSequences.bob(object, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.bob
--     local duration = options.duration or cfg.duration
--     local distance = options.distance or cfg.distance
--     local easing = options.easing or cfg.easing
--     local loop = options.loop ~= nil and options.loop or cfg.loop
--     local ping_pong = options.ping_pong ~= nil and options.ping_pong or cfg.ping_pong
--     local on_update = options.on_update
--     
--     -- Store initial position
--     local start_y = object.y or 0
--     
--     return AnimationEngine.animate(
--         {y = start_y},
--         {y = start_y - distance},
--         duration,
--         {
--             easing = easing,
--             on_update = function(values)
--                 object.y = values.y
--                 
--                 if on_update then
--                     on_update(values)
--                 end
--             end,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- Create a pulse animation (scale and alpha pulsing)
-- function AnimationSequences.pulse(object, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.pulse
--     local duration = options.duration or cfg.duration
--     local scale_from = options.scale_from or cfg.scale_from
--     local scale_to = options.scale_to or cfg.scale_to
--     local alpha_from = options.alpha_from or cfg.alpha_from
--     local alpha_to = options.alpha_to or cfg.alpha_to
--     local easing = options.easing or cfg.easing
--     local loop = options.loop ~= nil and options.loop or cfg.loop
--     local ping_pong = options.ping_pong ~= nil and options.ping_pong or cfg.ping_pong
--     local on_update = options.on_update
--     
--     return AnimationEngine.animate(
--         {scale = scale_from, alpha = alpha_from},
--         {scale = scale_to, alpha = alpha_to},
--         duration,
--         {
--             easing = easing,
--             on_update = function(values)
--                 object.scale = values.scale
--                 object.alpha = values.alpha
--                 
--                 if on_update then
--                     on_update(values)
--                 end
--             end,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- Create a color pulse animation (transition between two color sets)
-- function AnimationSequences.color_pulse(object, start_color, target_color, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.color_pulse
--     local duration = options.duration or cfg.duration
--     local easing = options.easing or cfg.easing
--     local loop = options.loop ~= nil and options.loop or cfg.loop
--     local ping_pong = options.ping_pong ~= nil and options.ping_pong or cfg.ping_pong
--     local on_complete = options.on_complete
--     local on_update = options.on_update
--     
--     -- Ensure colors have alpha values
--     local start_r = start_color.r or start_color[1] or 255
--     local start_g = start_color.g or start_color[2] or 255
--     local start_b = start_color.b or start_color[3] or 255
--     local start_a = start_color.a or start_color[4] or (object.alpha or 255)
--     
--     local target_r = target_color.r or target_color[1] or 255
--     local target_g = target_color.g or target_color[2] or 255
--     local target_b = target_color.b or target_color[3] or 255
--     local target_a = target_color.a or target_color[4] or start_a
--     
--     -- Use the AnimationEngine to create a ping-pong animation between the two colors
--     return AnimationEngine.animate(
--         {r = start_r, g = start_g, b = start_b, a = start_a},
--         {r = target_r, g = target_g, b = target_b, a = target_a},
--         duration,
--         {
--             easing = easing,
--             on_update = function(values)
--                 -- Apply color and alpha to object
--                 if object.setColor then
--                     object:setColor(values.r, values.g, values.b)
--                 else
--                     object.r = values.r
--                     object.g = values.g
--                     object.b = values.b
--                 end
--                 
--                 if object.setAlpha then
--                     object:setAlpha(values.a)
--                 else
--                     object.alpha = values.a
--                 end
--                 
--                 -- Call custom update if provided
--                 if on_update then
--                     on_update(values)
--                 end
--             end,
--             on_complete = on_complete,
--             loop = loop,
--             ping_pong = ping_pong,
--             easing_back = options.easing_back or easing
--         }
--     )
-- end
-- 
-- -- Alternative version that uses the object's current color as starting point
-- function AnimationSequences.color_pulse_from_current(object, target_color, options)
--     options = options or {}
--     
--     -- Get current color from object
--     local current_color = {
--         r = object.r or 255,
--         g = object.g or 255,
--         b = object.b or 255,
--         a = object.alpha or 255
--     }
--     
--     return AnimationSequences.color_pulse(object, current_color, target_color, options)
-- end
-- 
-- -- Create a shake animation (screen shake effect)
-- function AnimationSequences.shake(object, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.shake
--     local duration = options.duration or cfg.duration
--     local intensity = options.intensity or cfg.intensity
--     local frequency = options.frequency or cfg.frequency
--     local easing = options.easing or cfg.easing
--     local on_complete = options.on_complete
--     local on_update = options.on_update
--     
--     -- Store initial position
--     local start_x = object.x or 0
--     local start_y = object.y or 0
--     
--     local sequence_id = AnimationEngine.create_sequence({
--         {
--             type = "animate",
--             duration = duration,
--             easing = easing,
--             on_update = function(values, t, phase)
--                 -- Calculate shake intensity (decays over time)
--                 local current_intensity = intensity * (1 - t)
--                 
--                 -- Calculate shake offset using sine waves
--                 local shake_x = math.sin(t * frequency * math.pi * 2) * current_intensity
--                 local shake_y = math.cos(t * frequency * math.pi * 2) * current_intensity * 0.7
--                 
--                 -- Apply shake
--                 object.x = start_x + shake_x
--                 object.y = start_y + shake_y
--                 
--                 -- Add rotation shake
--                 object.rotation = math.sin(t * frequency * math.pi * 3) * current_intensity * 0.5
--                 
--                 -- Call custom update if provided
--                 if on_update then
--                     on_update({
--                         x = start_x + shake_x,
--                         y = start_y + shake_y,
--                         rotation = object.rotation,
--                         intensity = current_intensity,
--                         progress = t
--                     }, t, phase)
--                 end
--             end,
--             on_complete = on_complete
--         }
--     })
--     
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Create a fade animation (fade in/out)
-- function AnimationSequences.fade(object, target_alpha, options)
--     options = options or {}
--     
--     local cfg = AnimationSequences.config.fade
--     local duration = options.duration or cfg.duration
--     local easing = options.easing or cfg.easing
--     local on_complete = options.on_complete
--     local discrete = options.discrete
--     
--     return AnimationEngine.animate(
--         {alpha = object.alpha or 255},
--         {alpha = target_alpha},
--         duration,
--         {
--             easing = easing,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setAlpha then
--                     object:setAlpha(values.alpha)
--                 else
--                     object.alpha = values.alpha
--                 end
--             end,
--             on_complete = on_complete,
--             loop = options.loop,
--             ping_pong = options.ping_pong,
--             easing_back = options.easing_back
--         }
--     )
-- end
-- 
-- -- Create a color tint animation
-- function AnimationSequences.tint(object, target_r, target_g, target_b, options)
--     options = options or {}
--     
--     local duration = options.duration or AnimationSequences.config.default_duration
--     local easing = options.easing or AnimationSequences.config.default_easing
--     local on_complete = options.on_complete
--     local discrete = options.discrete
--     
--     return AnimationEngine.animate(
--         {r = object.r or 255, g = object.g or 255, b = object.b or 255},
--         {r = target_r, g = target_g, b = target_b},
--         duration,
--         {
--             easing = easing,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setColor then
--                     object:setColor(values.r, values.g, values.b)
--                 else
--                     object.r = values.r
--                     object.g = values.g
--                     object.b = values.b
--                 end
--             end,
--             on_complete = on_complete,
--             loop = options.loop,
--             ping_pong = options.ping_pong,
--             easing_back = options.easing_back
--         }
--     )
-- end
-- 
-- -- Create a complex sequence that mimics duels.lua summon with all effects
-- function AnimationSequences.complexSummon(object, start_x, start_y, start_scale,
--                                         end_x, end_y, end_scale, options)
--     options = options or {}
--     
--     local sequence_steps = {}
--     
--     -- Step 1: Arc movement with scale pulse
--     table.insert(sequence_steps, {
--         type = "animate",
--         duration = options.arc_duration or 0.25,
--         easing = options.easing or "ease_in_out",
--         on_update = function(values, t, phase)
--             -- Arc calculation
--             local control_x = (start_x + end_x) * 0.5
--             local control_y = (start_y + end_y) * 0.5 - (options.arc_height or 24)
--             
--             local x, y = MathUtils.quadratic_bezier(
--                 {x = start_x, y = start_y},
--                 {x = control_x, y = control_y},
--                 {x = end_x, y = end_y},
--                 t
--             )
--             
--             -- Scale with pulse
--             local base_scale = MathUtils.lerp(start_scale, end_scale, t)
--             local pulse = 1.0 + ((options.peak_scale_mul or 1.35) - 1.0) * math.sin(math.pi * t)
--             local current_scale = base_scale * pulse
--             
--             -- Apply
--             object.x = x
--             object.y = y
--             object.scale = current_scale
--             
--             if options.on_update_step1 then
--                 options.on_update_step1({x = x, y = y, scale = current_scale, progress = t})
--             end
--         end
--     })
--     
--     -- Step 2: Rotation wobble
--     if options.wobble_deg and options.wobble_deg > 0 then
--         table.insert(sequence_steps, {
--             type = "animate",
--             duration = options.wobble_duration or 0.1,
--             easing = "elastic_out",
--             on_update = function(values, t, phase)
--                 local wobble = math.sin(t * math.pi * 4) * options.wobble_deg * (1 - t)
--                 object.rotation = wobble
--                 
--                 if options.on_update_step2 then
--                     options.on_update_step2({rotation = wobble, progress = t})
--                 end
--             end
--         })
--     end
--     
--     -- Step 3: Final settle
--     table.insert(sequence_steps, {
--         type = "animate",
--         duration = options.settle_duration or 0.05,
--         easing = "bounce_out",
--         on_update = function(values, t, phase)
--             object.scale = end_scale * (1 - 0.05 * (1 - t))
--             
--             if options.on_update_step3 then
--                 options.on_update_step3({scale = object.scale, progress = t})
--             end
--         end,
--         on_complete = options.on_complete
--     })
--     
--     local sequence_id = AnimationEngine.create_sequence(sequence_steps)
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Create a menu cursor animation (bob + pulse)
-- function AnimationSequences.menuCursor(object, options)
--     options = options or {}
--     
--     local bob_distance = options.bob_distance or 2
--     local pulse_scale = options.pulse_scale or 1.1
--     local duration = options.duration or 0.8
--     
--     -- Start both animations
--     local bob_id = AnimationSequences.bob(object, {
--         distance = bob_distance,
--         duration = duration,
--         loop = true,
--         ping_pong = true
--     })
--     
--     local pulse_id = AnimationSequences.pulse(object, {
--         scale_from = 1.0,
--         scale_to = pulse_scale,
--         duration = duration * 1.5,
--         loop = true,
--         ping_pong = true
--     })
--     
--     return {bob = bob_id, pulse = pulse_id}
-- end
-- 
-- -- Create a card highlight animation (lift + glow)
-- function AnimationSequences.highlightCard(object, options)
--     options = options or {}
--     
--     local lift_amount = options.lift_amount or 5
--     local glow_alpha = options.glow_alpha or 100
--     local duration = options.duration or 0.15
--     
--     local start_y = object.y or 0
--     local start_alpha = object.alpha or 255
--     
--     return AnimationEngine.animate(
--         {y = start_y, alpha = start_alpha},
--         {y = start_y - lift_amount, alpha = glow_alpha},
--         duration,
--         {
--             easing = "ease_out",
--             on_update = function(values)
--                 object.y = values.y
--                 object.alpha = values.alpha
--             end,
--             on_complete = options.on_complete
--         }
--     )
-- end
-- 
-- -- ---------------------------------------------------------------------------
-- -- Pre-built Animation Effects (from animation-engine.lua)
-- -- ---------------------------------------------------------------------------
-- 
-- -- Simple move animation with looping support
-- function AnimationSequences.move_to(object, target_x, target_y, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
--     duration = duration or AnimationSequences.config.default_duration
--     easing = easing or AnimationSequences.config.default_easing
--     
--     return AnimationEngine.animate(
--         {x = object.x or 0, y = object.y or 0},
--         {x = target_x, y = target_y},
--         duration,
--         {
--             easing = easing,
--             easing_back = easing_back,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setPosition then
--                     object:setPosition(values.x, values.y)
--                 else
--                     object.x = values.x
--                     object.y = values.y
--                 end
--             end,
--             on_complete = on_complete,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- Scale animation with looping support
-- function AnimationSequences.scale_to(object, target_scale, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
--     duration = duration or AnimationSequences.config.default_duration
--     easing = easing or AnimationSequences.config.default_easing
--     
--     return AnimationEngine.animate(
--         {scale = object.scale or 1},
--         {scale = target_scale},
--         duration,
--         {
--             easing = easing,
--             easing_back = easing_back,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setScale then
--                     object:setScale(values.scale)
--                 else
--                     object.scale = values.scale
--                 end
--             end,
--             on_complete = on_complete,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- Rotation animation with looping support
-- function AnimationSequences.rotate_to(object, target_angle, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
--     duration = duration or AnimationSequences.config.default_duration
--     easing = easing or AnimationSequences.config.default_easing
--     
--     return AnimationEngine.animate(
--         {angle = object.angle or 0},
--         {angle = target_angle},
--         duration,
--         {
--             easing = easing,
--             easing_back = easing_back,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setRotation then
--                     object:setRotation(values.angle)
--                 else
--                     object.angle = values.angle
--                 end
--             end,
--             on_complete = on_complete,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- Fade animation with looping support
-- function AnimationSequences.fade_to(object, target_alpha, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
--     duration = duration or AnimationSequences.config.default_duration
--     easing = easing or AnimationSequences.config.default_easing
--     
--     return AnimationEngine.animate(
--         {alpha = object.alpha or 255},
--         {alpha = target_alpha},
--         duration,
--         {
--             easing = easing,
--             easing_back = easing_back,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setAlpha then
--                     object:setAlpha(values.alpha)
--                 else
--                     object.alpha = values.alpha
--                 end
--             end,
--             on_complete = on_complete,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- Color tint animation with looping support
-- function AnimationSequences.tint_to(object, target_r, target_g, target_b, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
--     duration = duration or AnimationSequences.config.default_duration
--     easing = easing or AnimationSequences.config.default_easing
--     
--     return AnimationEngine.animate(
--         {r = object.r or 255, g = object.g or 255, b = object.b or 255},
--         {r = target_r, g = target_g, b = target_b},
--         duration,
--         {
--             easing = easing,
--             easing_back = easing_back,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setColor then
--                     object:setColor(values.r, values.g, values.b)
--                 else
--                     object.r = values.r
--                     object.g = values.g
--                     object.b = values.b
--                 end
--             end,
--             on_complete = on_complete,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- Color pulse animation with looping support (convenience wrapper)
-- function AnimationSequences.color_pulse_to(object, target_r, target_g, target_b, target_a, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
--     duration = duration or 0.8
--     easing = easing or "ease_in_out"
--     loop = loop ~= nil and loop or true
--     ping_pong = ping_pong ~= nil and ping_pong or true
--     
--     -- Get current color from object
--     local current_color = {
--         r = object.r or 255,
--         g = object.g or 255,
--         b = object.b or 255,
--         a = object.alpha or 255
--     }
--     
--     local target_color = {
--         r = target_r,
--         g = target_g,
--         b = target_b,
--         a = target_a or current_color.a
--     }
--     
--     return AnimationSequences.color_pulse(object, current_color, target_color, {
--         duration = duration,
--         easing = easing,
--         on_complete = on_complete,
--         loop = loop,
--         ping_pong = ping_pong,
--         easing_back = easing_back,
--         discrete = discrete
--     })
-- end
-- 
-- -- Discrete-first move animation
-- function AnimationSequences.move_to_discrete_first(object, target_x, target_y, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
--     duration = duration or AnimationSequences.config.default_duration
--     easing = easing or AnimationSequences.config.default_easing
--     
--     return AnimationEngine.animate_discrete_first(
--         {x = object.x or 0, y = object.y or 0},
--         {x = target_x, y = target_y},
--         duration,
--         {
--             easing = easing,
--             easing_back = easing_back,
--             discrete = discrete,
--             on_update = function(values)
--                 if object.setPosition then
--                     object:setPosition(values.x, values.y)
--                 else
--                     object.x = values.x
--                     object.y = values.y
--                 end
--             end,
--             on_complete = on_complete,
--             loop = loop,
--             ping_pong = ping_pong
--         }
--     )
-- end
-- 
-- -- ---------------------------------------------------------------------------
-- -- Utility Functions
-- -- ---------------------------------------------------------------------------
-- 
-- -- Stop all animations for an object
-- function AnimationSequences.stopAll(object_id_prefix)
--     -- This would need to track animations by object
--     -- For now, provides a placeholder
--     print("Stop animations for: " .. (object_id_prefix or "all"))
-- end
-- 
-- -- Check if any animations are running for an object
-- function AnimationSequences.isAnimating(object_id_prefix)
--     -- Placeholder implementation
--     return false
-- end
-- 
-- -- Reset object to its initial state
-- function AnimationSequences.reset(object, initial_values)
--     initial_values = initial_values or {}
--     
--     AnimationEngine.set_to(object, {
--         x = initial_values.x or object.x,
--         y = initial_values.y or object.y,
--         scale = initial_values.scale or 1,
--         rotation = initial_values.rotation or 0,
--         alpha = initial_values.alpha or 255
--     })
-- end
-- 
-- -- Create a sequence animation for multiple sprites (animates sprites one after another)
-- function AnimationSequences.sequenceAnimate(sprites, start_properties, end_properties, options)
--     options = options or {}
--     
--     local set_to_start_first = options.set_to_start_first ~= false  -- Default to true
--     local duration = options.duration or AnimationSequences.config.default_duration
--     local delay_between = options.delay_between or 0
--     local easing = options.easing or AnimationSequences.config.default_easing
--     local on_complete = options.on_complete
--     local on_sprite_complete = options.on_sprite_complete
--     local discrete = options.discrete or {}
--     
--     -- First, set all sprites to start properties if requested
--     if set_to_start_first then
--         for _, sprite in ipairs(sprites) do
--             for key, value in pairs(start_properties) do
--                 if sprite.properties then
--                     -- Handle sprite with properties table
--                     sprite.properties[key] = value
--                 else
--                     -- Handle regular object
--                     sprite[key] = value
--                 end
--             end
--         end
--     end
--     
--     -- Create a sequence of animations, one for each sprite
--     local sequence_steps = {}
--     
--     for i, sprite in ipairs(sprites) do
--         -- Add delay between sprites (except for first one)
--         if i > 1 and delay_between > 0 then
--             table.insert(sequence_steps, {
--                 type = "delay",
--                 duration = delay_between
--             })
--         end
--         
--         -- Create animation step for this sprite
--         table.insert(sequence_steps, {
--             type = "animate",
--             duration = duration,
--             easing = easing,
--             discrete = discrete,
--             on_update = function(values, t, phase)
--                 -- Apply animated values to sprite
--                 for key, value in pairs(values) do
--                     if sprite.properties then
--                         -- Handle sprite with properties table
--                         
--                         -- Map animation property names to sprite property names
--                         local sprite_key = key
--                         if key == "scale" then
--                             sprite_key = "sx"
--                             sprite.properties.sy = value  -- Apply to both sx and sy for uniform scaling
--                         elseif key == "scaleX" then
--                             sprite_key = "sx"
--                         elseif key == "scaleY" then
--                             sprite_key = "sy"
--                         elseif key == "rotation" then
--                             sprite_key = "ro"
--                         elseif key == "alpha" then
--                             sprite_key = "opacity"
--                             sprite.properties.a = value  -- Also set color alpha
--                         elseif key == "x" or key == "y" or key == "z" then
--                             -- Direct mapping for position
--                             sprite_key = key
--                         elseif key == "r" or key == "g" or key == "b" or key == "a" then
--                             -- Direct mapping for color
--                             sprite_key = key
--                         end
--                         
--                         sprite.properties[sprite_key] = value
--                     else
--                         -- Handle regular object
--                         sprite[key] = value
--                     end
--                 end
--             end,
--             on_complete = function(values, interrupted)
--                 if not interrupted and on_sprite_complete then
--                     on_sprite_complete(sprite, i, #sprites)
--                 end
--             end
--         })
--     end
--     
--     -- Create and start the sequence
--     local sequence_id = AnimationEngine.create_sequence(sequence_steps, {
--         on_complete = function()
--             if on_complete then
--                 on_complete(sprites)
--             end
--         end
--     })
--     
--     AnimationEngine.start_sequence(sequence_id)
--     return sequence_id
-- end
-- 
-- -- Alternative version that animates sprites in parallel instead of series
-- function AnimationSequences.parallelAnimate(sprites, start_properties, end_properties, options)
--     options = options or {}
--     
--     local set_to_start_first = options.set_to_start_first ~= false  -- Default to true
--     local duration = options.duration or AnimationSequences.config.default_duration
--     local easing = options.easing or AnimationSequences.config.default_easing
--     local on_complete = options.on_complete
--     local on_sprite_complete = options.on_sprite_complete
--     local discrete = options.discrete or {}
--     
--     -- First, set all sprites to start properties if requested
--     if set_to_start_first then
--         for _, sprite in ipairs(sprites) do
--             for key, value in pairs(start_properties) do
--                 if sprite.properties then
--                     sprite.properties[key] = value
--                 else
--                     sprite[key] = value
--                 end
--             end
--         end
--     end
--     
--     -- Start all animations in parallel
--     local animation_ids = {}
--     local completed_count = 0
--     local total_count = #sprites
--     
--     for i, sprite in ipairs(sprites) do
--         -- Determine which properties to animate (only those in both start and end)
--         local anim_properties = {}
--         for key, _ in pairs(start_properties) do
--             if end_properties[key] ~= nil then
--                 anim_properties[key] = true
--             end
--         end
--         for key, _ in pairs(end_properties) do
--             if start_properties[key] ~= nil then
--                 anim_properties[key] = true
--             end
--         end
--         
--         -- Get start and target values for this sprite
--         local start_values = {}
--         local target_values = {}
--         
--         for key, _ in pairs(anim_properties) do
--             if sprite.properties then
--                 start_values[key] = start_properties[key] or (function()
--                     -- Map from sprite properties to animation properties
--                     if key == "scale" then return sprite.properties.sx
--                     elseif key == "scaleX" then return sprite.properties.sx
--                     elseif key == "scaleY" then return sprite.properties.sy
--                     elseif key == "rotation" then return sprite.properties.ro
--                     elseif key == "alpha" then return sprite.properties.opacity
--                     elseif key == "x" or key == "y" or key == "z" then
--                         return sprite.properties[key]
--                     elseif key == "r" or key == "g" or key == "b" or key == "a" then
--                         return sprite.properties[key]
--                     end
--                     return 0
--                 end)()
--             else
--                 start_values[key] = start_properties[key] or sprite[key] or 0
--             end
--             
--             target_values[key] = end_properties[key]
--         end
--         
--         -- Start animation
--         local anim_id = AnimationEngine.animate(start_values, target_values, duration, {
--             easing = easing,
--             discrete = discrete,
--             on_update = function(values)
--                 -- Apply animated values to sprite
--                 for key, value in pairs(values) do
--                     if sprite.properties then
--                         -- Map animation property names to sprite property names
--                         local sprite_key = key
--                         if key == "scale" then
--                             sprite_key = "sx"
--                             sprite.properties.sy = value
--                         elseif key == "scaleX" then
--                             sprite_key = "sx"
--                         elseif key == "scaleY" then
--                             sprite_key = "sy"
--                         elseif key == "rotation" then
--                             sprite_key = "ro"
--                         elseif key == "alpha" then
--                             sprite_key = "opacity"
--                             sprite.properties.a = value
--                         elseif key == "x" or key == "y" or key == "z" then
--                             sprite_key = key
--                         elseif key == "r" or key == "g" or key == "b" or key == "a" then
--                             sprite_key = key
--                         end
--                         
--                         sprite.properties[sprite_key] = value
--                     else
--                         sprite[key] = value
--                     end
--                 end
--                 
--                 if on_sprite_complete then
--                     on_sprite_complete(sprite, i, total_count, values)
--                 end
--             end,
--             on_complete = function(values, interrupted)
--                 if not interrupted then
--                     completed_count = completed_count + 1
--                     if completed_count >= total_count and on_complete then
--                         on_complete(sprites)
--                     end
--                 end
--             end
--         })
--         
--         table.insert(animation_ids, {
--             id = anim_id,
--             sprite = sprite,
--             index = i
--         })
--     end
--     
--     return {
--         ids = animation_ids,
--         stop = function()
--             for _, anim in ipairs(animation_ids) do
--                 AnimationEngine.stop_animation(anim.id)
--             end
--         end,
--         is_complete = function()
--             return completed_count >= total_count
--         end
--     }
-- end
-- 
-- -- ---------------------------------------------------------------------------
-- -- Example Usage
-- -- ---------------------------------------------------------------------------
-- --[[
-- -- Example object
-- local mySprite = {
--     x = 100,
--     y = 100,
--     scale = 1,
--     rotation = 0,
--     alpha = 255
-- }
-- 
-- -- Summon animation
-- AnimationSequences.summon(mySprite, 
--     0, 100, 0.5,   -- Start: x, y, scale
--     100, 100, 1.0, -- End: x, y, scale
--     {
--         duration = 0.3,
--         arc_height = 30,
--         on_complete = function()
--             print("Summon complete!")
--         end
--     }
-- )
-- 
-- -- Bob animation
-- AnimationSequences.bob(mySprite, {
--     distance = 3,
--     duration = 1.0
-- })
-- 
-- -- Color pulse animation
-- AnimationSequences.color_pulse(mySprite,
--     {r = 255, g = 100, b = 100, a = 255},  -- Start color (red)
--     {r = 100, g = 100, b = 255, a = 200},  -- Target color (blue)
--     {
--         duration = 1.0,
--         easing = "ease_in_out",
--         loop = true,
--         ping_pong = true,
--         on_complete = function()
--             print("Color pulse complete!")
--         end
--     }
-- )
-- 
-- -- Or using the convenience function
-- AnimationSequences.color_pulse_to(mySprite,
--     255, 0, 0, 200,  -- Target color: red with 200 alpha
--     0.8, "elastic_in_out",
--     function() print("Red pulse complete!") end
-- )
-- 
-- -- Single pulse (one cycle)
-- AnimationSequences.color_pulse_to(mySprite,
--     0, 255, 0, 255,  -- Green flash
--     0.5, "ease_out",
--     function() print("Flash complete!") end,
--     1, true  -- loop = 1 (single cycle), ping_pong = true
-- )
-- 
-- -- Shake animation
-- AnimationSequences.shake(mySprite, {
--     intensity = 5,
--     duration = 0.2,
--     on_complete = function()
--         print("Shake complete!")
--     end
-- })
-- 
-- -- Complex sequence
-- AnimationSequences.complexSummon(mySprite,
--     50, 150, 0.3,
--     150, 150, 1.0,
--     {
--         arc_height = 40,
--         wobble_deg = 10,
--         on_complete = function()
--             print("Complex summon complete!")
--         end
--     }
-- )
-- ]]
-- 
-- return AnimationSequences

-- ==============================
-- Pre-built Sequences
-- ==============================

-- animation-sequences.lua
-- Pre-built animation sequences (engine-injected, sequence-runner compatible)

local Sequences = {}
local Engine = nil
local MathUtils = nil

-- ==============================
-- Dependency Injection
-- ==============================
function Sequences.set_engine(animation_engine)
    Engine = animation_engine
    MathUtils = animation_engine.Math
end

-- ==============================
-- Default Config
-- ==============================
Sequences.config = {
    default_duration = 0.25,
    default_easing = "ease_in_out",

    summon = {
        arc_height = 24,
        peak_scale_mul = 1.35,
        wobble_ro_deg = 5,
        duration = 0.25
    },

    position_change = {
        duration = 0.18,
        peak_scale_mul = 1.15,
        flip_min = 0.06
    },

    attack = {
        duration = 0.22,
        recoil_distance = 5,
        lunge_distance = 15,
        t1 = 0.25,
        t2 = 0.60
    },

    slide = {
        duration = 0.15,
        easing = "ease_out"
    },

    bob = {
        duration = 1.0,
        distance = 3,
        easing = "smoothstep",
        loop = true,
        ping_pong = true
    },

    pulse = {
        duration = 0.8,
        scale_from = 1.0,
        scale_to = 1.1,
        alpha_from = 255,
        alpha_to = 200,
        easing = "ease_in_out",
        loop = true,
        ping_pong = true
    },

    fade = {
        duration = 0.3,
        easing = "ease_in_out"
    }
}

-- ==============================
-- Helper
-- ==============================
local function assert_engine()
    assert(Engine, "AnimationEngine not injected into AnimationSequences")
end

-- ==============================
-- SUMMON (arc + scale + wobble)
-- ==============================
function Sequences.summon(object, sx, sy, ss, ex, ey, es, options)
    assert_engine()
    options = options or {}
    local cfg = Sequences.config.summon

    local arc = options.arc_height or cfg.arc_height
    local peak = options.peak_scale_mul or cfg.peak_scale_mul
    local wobble = options.wobble_deg or cfg.wobble_ro_deg
    local duration = options.duration or cfg.duration
    local easing = options.easing or Sequences.config.default_easing

    local cx = (sx + ex) * 0.5
    local cy = (sy + ey) * 0.5 - arc

    local seq = Engine.create_sequence({
        {
            type = "animate",
            duration = duration,
            easing = easing,
            on_update = function(_, t)
                local x, y = MathUtils.quadratic_bezier(
                    {x = sx, y = sy},
                    {x = cx, y = cy},
                    {x = ex, y = ey},
                    t
                )

                local scale = MathUtils.lerp(ss, es, t)
                scale = scale * (1 + (peak - 1) * math.sin(math.pi * t))

                object.x = x
                object.y = y
                object.scale = scale
                object.rotation = wobble * math.sin(t * math.pi * 2)
            end,
            on_complete = options.on_complete
        }
    })

    Engine.start_sequence(seq)
    return seq
end

-- ==============================
-- POSITION CHANGE / SET
-- ==============================
function Sequences.positionChange(object, start_rot, end_rot, options)
    assert_engine()
    options = options or {}
    local cfg = Sequences.config.position_change

    local duration = options.duration or cfg.duration
    local peak = options.peak_scale_mul or cfg.peak_scale_mul
    local easing = options.easing or Sequences.config.default_easing
    local base_scale = object.scale or 1

    local seq = Engine.create_sequence({
        {
            type = "animate",
            duration = duration,
            easing = easing,
            on_update = function(_, t)
                object.rotation = MathUtils.lerp(start_rot, end_rot, t)
                object.scale = base_scale * (1 + (peak - 1) * math.sin(math.pi * t))
            end,
            on_complete = options.on_complete
        }
    })

    Engine.start_sequence(seq)
    return seq
end

-- ==============================
-- ATTACK (recoil → lunge → return)
-- ==============================
function Sequences.attack(object, recoil, lunge, options)
    assert_engine()
    options = options or {}
    local cfg = Sequences.config.attack

    local duration = options.duration or cfg.duration
    local t1 = options.t1 or cfg.t1
    local t2 = options.t2 or cfg.t2
    local start_y = object.y or 0

    local seq = Engine.create_sequence({
        {
            type = "animate",
            duration = duration,
            easing = Sequences.config.default_easing,
            on_update = function(_, t)
                local offset
                if t < t1 then
                    offset = MathUtils.lerp(0, recoil, t / t1)
                elseif t < t2 then
                    offset = MathUtils.lerp(recoil, lunge, (t - t1) / (t2 - t1))
                else
                    offset = MathUtils.lerp(lunge, 0, (t - t2) / (1 - t2))
                end
                object.y = start_y + offset
                object.scale = 1 + 0.1 * math.sin(math.pi * t)
            end,
            on_complete = options.on_complete
        }
    })

    Engine.start_sequence(seq)
    return seq
end

-- ==============================
-- SLIDE IN
-- ==============================
function Sequences.slideIn(object, sx, sy, ex, ey, options)
    assert_engine()
    options = options or {}
    local cfg = Sequences.config.slide

    return Engine.animate(
        {x = sx, y = sy},
        {x = ex, y = ey},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            on_update = function(v)
                object.x = v.x
                object.y = v.y
            end,
            on_complete = options.on_complete
        }
    )
end

-- ==============================
-- BOB (idle loop)
-- ==============================
function Sequences.bob(object, options)
    assert_engine()
    options = options or {}
    local cfg = Sequences.config.bob
    local y0 = object.y or 0

    return Engine.animate(
        {y = y0},
        {y = y0 - (options.distance or cfg.distance)},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            loop = options.loop ~= false,
            ping_pong = options.ping_pong ~= false,
            on_update = function(v) object.y = v.y end
        }
    )
end

-- ==============================
-- PULSE (scale + alpha)
-- ==============================
function Sequences.pulse(object, options)
    assert_engine()
    options = options or {}
    local cfg = Sequences.config.pulse

    return Engine.animate(
        {scale = cfg.scale_from, alpha = cfg.alpha_from},
        {scale = cfg.scale_to, alpha = cfg.alpha_to},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            loop = options.loop ~= false,
            ping_pong = options.ping_pong ~= false,
            on_update = function(v)
                object.scale = v.scale
                object.alpha = v.alpha
            end
        }
    )
end

-- ==============================
-- FADE
-- ==============================
function Sequences.fade(object, target_alpha, options)
    assert_engine()
    options = options or {}
    local cfg = Sequences.config.fade

    return Engine.animate(
        {alpha = object.alpha or 255},
        {alpha = target_alpha},
        options.duration or cfg.duration,
        {
            easing = options.easing or cfg.easing,
            on_update = function(v) object.alpha = v.alpha end,
            on_complete = options.on_complete
        }
    )
end

-- ==============================
-- RESET
-- ==============================
function Sequences.reset(object, initial)
    initial = initial or {}
    Engine.set_to(object, {
        x = initial.x or object.x,
        y = initial.y or object.y,
        scale = initial.scale or 1,
        rotation = initial.rotation or 0,
        alpha = initial.alpha or 255
    })
end

return Sequences
