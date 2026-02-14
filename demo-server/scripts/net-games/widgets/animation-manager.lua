--[[
    Animation Manager for Pure Sprite Widget Framework
    Provides sprite-based animation system with easing functions
]]

local AnimationManager = {}
AnimationManager.__index = AnimationManager

-- Easing functions
AnimationManager.EASING_FUNCTIONS = {
    linear = function(t)
        return t
    end,
    
    ease_in = function(t)
        return t * t
    end,
    
    ease_out = function(t)
        return t * (2 - t)
    end,
    
    ease_in_out = function(t)
        if t < 0.5 then
            return 2 * t * t
        else
            return -1 + (4 - 2 * t) * t
        end
    end,
    
    smoothstep = function(t)
        return t * t * (3 - 2 * t)
    end,
    
    ease_in_back = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        return c3 * t * t * t - c1 * t * t
    end,
    
    ease_out_back = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        return 1 + c3 * (t - 1) * (t - 1) * (t - 1) + c1 * (t - 1) * (t - 1)
    end,
    
    elastic = function(t)
        if t == 0 or t == 1 then return t end
        return 2^(-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
    end,
    
    bounce = function(t)
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
    end
}

-- Animation types
AnimationManager.ANIMATION_TYPES = {
    COLOR_PULSE = "color_pulse",
    PULSE_SCALE = "pulse_scale",
    SLIDE = "slide",
    ROTATION = "rotation",
    FADE = "fade",
    SHAKE = "shake",
    BOB = "bob",
    TRANSFORM = "transform"
}

function AnimationManager.new()
    local self = setmetatable({}, AnimationManager)
    
    -- Active animations: [player_id][animation_id] = animation_data
    self.activeAnimations = {}
    
    -- Animation ID counter
    self.nextAnimationId = 1
    
    -- Default animation options
    self.defaultOptions = {
        duration = 0.5,
        easing = "ease_in_out",
        loop = false,
        ping_pong = false,
        delay = 0,
        on_start = nil,
        on_update = nil,
        on_complete = nil
    }
    
    return self
end

-- Generate unique animation ID
function AnimationManager:_generateAnimationId()
    local id = "anim_" .. self.nextAnimationId
    self.nextAnimationId = self.nextAnimationId + 1
    return id
end

-- Calculate progress with easing
function AnimationManager:_calculateProgress(animation, current_time)
    local elapsed = current_time - animation.start_time - (animation.options.delay or 0)
    
    if elapsed < 0 then
        return 0  -- Still in delay phase
    end
    
    local progress = math.min(elapsed / animation.duration, 1)
    
    -- Apply easing
    local easing_func = self.EASING_FUNCTIONS[animation.easing] or self.EASING_FUNCTIONS.linear
    return easing_func(progress)
end

-- Interpolate between two values
function AnimationManager:_interpolate(start_val, end_val, progress, is_color)
    if is_color then
        -- Color interpolation (RGBA)
        return {
            r = math.floor(start_val.r + (end_val.r - start_val.r) * progress),
            g = math.floor(start_val.g + (end_val.g - start_val.g) * progress),
            b = math.floor(start_val.b + (end_val.b - start_val.b) * progress),
            a = math.floor(start_val.a + (end_val.a - start_val.a) * progress)
        }
    else
        -- Numeric interpolation
        return start_val + (end_val - start_val) * progress
    end
end

-- Create color pulse animation
function AnimationManager:createColorPulse(widget_id, player_id, start_color, end_color, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.COLOR_PULSE,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        start_color = start_color,
        end_color = end_color,
        ping_pong_state = false  -- false = forward, true = reverse
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Create scale pulse animation
function AnimationManager:createPulseScale(widget_id, player_id, min_scale, max_scale, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.PULSE_SCALE,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        min_scale = min_scale,
        max_scale = max_scale,
        ping_pong_state = false
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Create slide animation
function AnimationManager:createSlide(widget_id, player_id, start_x, start_y, target_x, target_y, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.SLIDE,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        start_x = start_x,
        start_y = start_y,
        target_x = target_x,
        target_y = target_y,
        ping_pong_state = false
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Create rotation animation
function AnimationManager:createRotation(widget_id, player_id, start_rotation, end_rotation, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.ROTATION,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        start_rotation = start_rotation,
        end_rotation = end_rotation,
        ping_pong_state = false
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Create fade animation
function AnimationManager:createFade(widget_id, player_id, start_opacity, end_opacity, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.FADE,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        start_opacity = start_opacity,
        end_opacity = end_opacity,
        ping_pong_state = false
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Create shake animation
function AnimationManager:createShake(widget_id, player_id, intensity, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.SHAKE,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        intensity = intensity or 5,
        original_x = 0,  -- Will be set when animation starts
        original_y = 0
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Create bob (floating) animation
function AnimationManager:createBob(widget_id, player_id, distance, speed, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.BOB,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        distance = distance or 10,
        speed = speed or 1,
        original_y = 0  -- Will be set when animation starts
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Create transform animation (multiple properties)
function AnimationManager:createTransform(widget_id, player_id, start_props, end_props, options)
    local animation_id = self:_generateAnimationId()
    local merged_options = self:_mergeOptions(options)
    
    local animation = {
        id = animation_id,
        type = self.ANIMATION_TYPES.TRANSFORM,
        widget_id = widget_id,
        player_id = player_id,
        start_time = os.clock(),
        duration = merged_options.duration,
        easing = merged_options.easing,
        options = merged_options,
        start_props = start_props,
        end_props = end_props,
        ping_pong_state = false
    }
    
    return self:_addAnimation(player_id, animation_id, animation)
end

-- Add animation to active list
function AnimationManager:_addAnimation(player_id, animation_id, animation)
    if not self.activeAnimations[player_id] then
        self.activeAnimations[player_id] = {}
    end
    
    self.activeAnimations[player_id][animation_id] = animation
    
    -- Call on_start callback
    if animation.options.on_start then
        animation.options.on_start(animation)
    end
    
    return animation_id
end

-- Merge user options with defaults
function AnimationManager:_mergeOptions(user_options)
    local merged = {}
    
    -- Copy defaults
    for key, value in pairs(self.defaultOptions) do
        merged[key] = value
    end
    
    -- Override with user options
    if user_options then
        for key, value in pairs(user_options) do
            merged[key] = value
        end
    end
    
    return merged
end

-- Update all animations for a player
function AnimationManager:update(player_id, current_time)
    if not player_id or not self.activeAnimations[player_id] then
        return {}
    end
    
    local updated_widgets = {}
    local completed_animations = {}
    local current_time = current_time or os.clock()
    
    for anim_id, animation in pairs(self.activeAnimations[player_id]) do
        local progress = self:_calculateProgress(animation, current_time)
        
        if progress >= 0 then  -- Not in delay phase
            -- Calculate current values based on animation type
            local current_values = {}
            
            if animation.type == self.ANIMATION_TYPES.COLOR_PULSE then
                local effective_progress = animation.ping_pong_state and (1 - progress) or progress
                current_values.color = self:_interpolate(
                    animation.start_color,
                    animation.end_color,
                    effective_progress,
                    true
                )
                
            elseif animation.type == self.ANIMATION_TYPES.PULSE_SCALE then
                local effective_progress = animation.ping_pong_state and (1 - progress) or progress
                current_values.scale = self:_interpolate(
                    animation.min_scale,
                    animation.max_scale,
                    effective_progress,
                    false
                )
                
            elseif animation.type == self.ANIMATION_TYPES.SLIDE then
                current_values.x = self:_interpolate(
                    animation.start_x,
                    animation.target_x,
                    progress,
                    false
                )
                current_values.y = self:_interpolate(
                    animation.start_y,
                    animation.target_y,
                    progress,
                    false
                )
                
            elseif animation.type == self.ANIMATION_TYPES.ROTATION then
                current_values.rotation = self:_interpolate(
                    animation.start_rotation,
                    animation.end_rotation,
                    progress,
                    false
                )
                
            elseif animation.type == self.ANIMATION_TYPES.FADE then
                current_values.opacity = self:_interpolate(
                    animation.start_opacity,
                    animation.end_opacity,
                    progress,
                    false
                )
                
            elseif animation.type == self.ANIMATION_TYPES.SHAKE then
                -- Random offset for shake effect
                if not animation.original_x then
                    -- Store original position on first frame
                    animation.original_x = 0  -- Will be set by widget
                    animation.original_y = 0
                end
                
                local shake_amount = animation.intensity * (1 - progress)
                current_values.x = animation.original_x + (math.random() * 2 - 1) * shake_amount
                current_values.y = animation.original_y + (math.random() * 2 - 1) * shake_amount
                
            elseif animation.type == self.ANIMATION_TYPES.BOB then
                if not animation.original_y then
                    animation.original_y = 0  -- Will be set by widget
                end
                
                local time_elapsed = current_time - animation.start_time
                local bob_offset = math.sin(time_elapsed * animation.speed * math.pi * 2) * animation.distance
                current_values.y = animation.original_y + bob_offset
                
            elseif animation.type == self.ANIMATION_TYPES.TRANSFORM then
                -- Interpolate multiple properties
                for prop_name, start_val in pairs(animation.start_props) do
                    local end_val = animation.end_props[prop_name]
                    if end_val ~= nil then
                        if type(start_val) == "table" and start_val.r and start_val.g then
                            -- Color property
                            current_values[prop_name] = self:_interpolate(
                                start_val,
                                end_val,
                                progress,
                                true
                            )
                        else
                            -- Numeric property
                            current_values[prop_name] = self:_interpolate(
                                start_val,
                                end_val,
                                progress,
                                false
                            )
                        end
                    end
                end
            end
            
            -- Call on_update callback
            if animation.options.on_update then
                animation.options.on_update(animation, current_values, progress)
            end
            
            -- Track updated widget
            updated_widgets[animation.widget_id] = current_values
            
            -- Check if animation is complete
            if progress >= 1 then
                if animation.options.loop then
                    if animation.options.ping_pong then
                        -- Toggle ping-pong direction
                        animation.ping_pong_state = not animation.ping_pong_state
                    end
                    -- Restart animation
                    animation.start_time = current_time
                else
                    -- Mark for removal
                    table.insert(completed_animations, anim_id)
                end
            end
        end
    end
    
    -- Remove completed animations
    for _, anim_id in ipairs(completed_animations) do
        local animation = self.activeAnimations[player_id][anim_id]
        if animation and animation.options.on_complete then
            animation.options.on_complete(animation, false)  -- false = not interrupted
        end
        self.activeAnimations[player_id][anim_id] = nil
    end
    
    return updated_widgets
end

-- Stop an animation
function AnimationManager:stopAnimation(player_id, animation_id, call_complete)
    if not player_id or not animation_id then
        return false
    end
    
    if self.activeAnimations[player_id] and self.activeAnimations[player_id][animation_id] then
        local animation = self.activeAnimations[player_id][animation_id]
        
        if call_complete and animation.options.on_complete then
            animation.options.on_complete(animation, true)  -- true = interrupted
        end
        
        self.activeAnimations[player_id][animation_id] = nil
        return true
    end
    
    return false
end

-- Stop all animations for a widget
function AnimationManager:stopWidgetAnimations(player_id, widget_id, call_complete)
    if not player_id or not widget_id then
        return 0
    end
    
    if not self.activeAnimations[player_id] then
        return 0
    end
    
    local stopped_count = 0
    for anim_id, animation in pairs(self.activeAnimations[player_id]) do
        if animation.widget_id == widget_id then
            if call_complete and animation.options.on_complete then
                animation.options.on_complete(animation, true)
            end
            self.activeAnimations[player_id][anim_id] = nil
            stopped_count = stopped_count + 1
        end
    end
    
    return stopped_count
end

-- Stop all animations for a player
function AnimationManager:stopAllAnimations(player_id, call_complete)
    if not player_id or not self.activeAnimations[player_id] then
        return 0
    end
    
    local stopped_count = 0
    for anim_id, animation in pairs(self.activeAnimations[player_id]) do
        if call_complete and animation.options.on_complete then
            animation.options.on_complete(animation, true)
        end
        stopped_count = stopped_count + 1
    end
    
    self.activeAnimations[player_id] = {}
    return stopped_count
end

-- Check if widget has active animations
function AnimationManager:hasActiveAnimations(player_id, widget_id)
    if not player_id or not widget_id then
        return false
    end
    
    if not self.activeAnimations[player_id] then
        return false
    end
    
    for _, animation in pairs(self.activeAnimations[player_id]) do
        if animation.widget_id == widget_id then
            return true
        end
    end
    
    return false
end

-- Get all animations for a widget
function AnimationManager:getWidgetAnimations(player_id, widget_id)
    if not player_id or not widget_id then
        return {}
    end
    
    if not self.activeAnimations[player_id] then
        return {}
    end
    
    local animations = {}
    for anim_id, animation in pairs(self.activeAnimations[player_id]) do
        if animation.widget_id == widget_id then
            animations[anim_id] = animation
        end
    end
    
    return animations
end

-- Clean up all animations for a player
function AnimationManager:cleanupPlayer(player_id)
    if player_id then
        self.activeAnimations[player_id] = nil
    end
end

return AnimationManager