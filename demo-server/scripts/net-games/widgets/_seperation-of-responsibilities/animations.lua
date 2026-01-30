-- widgets/widget-animations.lua
-- Animation helper functions for widgets

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local WidgetAnimations = {}

-- Slide widget animation using internal AnimationEngine
function WidgetAnimations.slideWidget(widget, target_x, target_y, duration, ...)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.slideWidget: Invalid widget")
        return nil
    end
    
    -- Handle variable arguments for backward compatibility
    local args = {...}
    local options = {}
    
    -- If the last argument is a function, treat it as on_complete
    if #args > 0 and type(args[#args]) == "function" then
        options.on_complete = args[#args]
        table.remove(args, #args)
    end
    
    -- If there's still an argument and it's a string, treat it as easing
    if #args > 0 and type(args[#args]) == "string" then
        options.easing = args[#args]
        table.remove(args, #args)
    end
    
    -- If the remaining argument is a table, merge it with options
    if #args > 0 and type(args[#args]) == "table" then
        for k, v in pairs(args[#args]) do
            options[k] = v
        end
    end
    
    -- Ensure animation modules are loaded
    utils.load_animation_modules()
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("ERROR", "WidgetAnimations.slideWidget: AnimationEngine not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.slideWidget: %s to (%d,%d) in %f seconds", 
               widget.id, target_x, target_y, duration or 0.5)
    
    -- Animate widget position (which will also animate sprites)
    return widget:slide_widget(target_x, target_y, duration, options.easing, options.on_complete)
end

-- Fade widget animation using internal AnimationEngine
function WidgetAnimations.fadeWidget(widget, target_opacity, duration, ...)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.fadeWidget: Invalid widget")
        return nil
    end
    
    -- Handle variable arguments for backward compatibility
    local args = {...}
    local options = {}
    
    -- If the last argument is a function, treat it as on_complete
    if #args > 0 and type(args[#args]) == "function" then
        options.on_complete = args[#args]
        table.remove(args, #args)
    end
    
    -- If there's still an argument and it's a string, treat it as easing
    if #args > 0 and type(args[#args]) == "string" then
        options.easing = args[#args]
        table.remove(args, #args)
    end
    
    -- If the remaining argument is a table, merge it with options
    if #args > 0 and type(args[#args]) == "table" then
        for k, v in pairs(args[#args]) do
            options[k] = v
        end
    end
    
    -- Ensure animation modules are loaded
    utils.load_animation_modules()
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("ERROR", "WidgetAnimations.fadeWidget: AnimationEngine not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.fadeWidget: %s to opacity %d in %f seconds", 
               widget.id, target_opacity, duration or 0.5)
    
    -- Animate widget opacity (which will also animate sprites)
    return widget:set_opacity_widget(target_opacity, duration, options.easing, options.on_complete)
end

-- Hero animation (sprite to sprite) using AnimationSequences
function WidgetAnimations.heroAnimation(from_widget, from_child_id, to_widget, to_child_id, 
                                       duration, arc_height, on_complete)
    if not from_widget or not to_widget then
        debug_print("ERROR", "WidgetAnimations.heroAnimation: Invalid widgets")
        return nil
    end
    
    -- Ensure animation modules are loaded
    utils.load_animation_modules()
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationSequences then
        debug_print("ERROR", "WidgetAnimations.heroAnimation: AnimationSequences not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.heroAnimation: %s.%s -> %s.%s", 
               from_widget.id, from_child_id, to_widget.id, to_child_id)
    
    -- Find the sprites
    local from_sprite, to_sprite
    
    for sprite_id, sprite in pairs(from_widget.sprite_objects) do
        if sprite_id == from_child_id then
            from_sprite = sprite
            debug_print("DETAILED", "  Found from_sprite: %s", sprite_id)
            break
        end
    end
    
    for sprite_id, sprite in pairs(to_widget.sprite_objects) do
        if sprite_id == to_child_id then
            to_sprite = sprite
            debug_print("DETAILED", "  Found to_sprite: %s", sprite_id)
            break
        end
    end
    
    if not from_sprite or not to_sprite then
        debug_print("ERROR", "  Could not find sprites")
        return nil
    end
    
    -- Get positions
    local from_props = from_sprite:get_properties()
    local to_props = to_sprite:get_properties()
    
    local start_x, start_y = from_sprite:get_absolute_position()
    local end_x, end_y = to_sprite:get_absolute_position()
    
    -- Convert to widget-relative coordinates for animation
    local start_scale = from_props.sx or 1.0
    local end_scale = to_props.sx or 1.0
    
    debug_print("DETAILED", "  Start: (%d,%d) scale=%f, End: (%d,%d) scale=%f", 
               start_x, start_y, start_scale, end_x, end_y, end_scale)
    
    -- Use summon animation from AnimationSequences
    return AnimationSequences.summon(from_sprite, 
        start_x, start_y, start_scale,
        end_x, end_y, end_scale,
        {
            duration = duration or 0.25,
            arc_height = arc_height or 24,
            peak_scale_mul = 1.2,
            wobble_deg = 5,
            easing = "ease_in_out",
            on_complete = on_complete
        }
    )
end

-- Pulse animation for highlighting
function WidgetAnimations.pulseWidget(widget, scale_from, scale_to, duration, easing, loop, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.pulseWidget: Invalid widget")
        return nil
    end
    
    -- Use widget's pulse animation (which will also animate sprites)
    return widget:pulse_scale_widget(scale_from, scale_to, duration, easing, loop, on_complete)
end

-- Shake animation
function WidgetAnimations.shakeWidget(widget, intensity, duration, easing, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.shakeWidget: Invalid widget")
        return nil
    end
    
    -- Use widget's shake animation (which will also animate sprites)
    return widget:shake_widget(intensity, duration, easing, on_complete)
end

-- Color pulse animation
function WidgetAnimations.colorPulseWidget(widget, target_color, duration, easing, loop, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.colorPulseWidget: Invalid widget")
        return nil
    end
    
    -- Use widget's color pulse animation (which will also animate sprites)
    return widget:color_pulse_widget(target_color, duration, easing, loop, on_complete)
end

return WidgetAnimations