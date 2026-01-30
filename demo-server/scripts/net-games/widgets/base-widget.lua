-- widgets/base-widget.lua
-- Base Widget class for the widget system

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')
local SpriteObject = require('scripts/net-games/widgets/sprite-object')
local WidgetCache = require('scripts/net-games/widgets/cache')

local Widget = {}
Widget.__index = Widget

function Widget.new(id, player_id, widget_type)
    local self = setmetatable({}, Widget)
    
    self.id = id or utils.generate_unique_id("widget")
    self.player_id = player_id
    self.x = 0
    self.y = 0
    self.sx = 1.0  -- Scale X
    self.sy = 1.0  -- Scale Y
    self.ro = 0    -- Rotation
    self.opacity = 255
    self.r = 255
    self.g = 255
    self.b = 255
    self.a = 255
    self.width = 0  -- 0 means size to content
    self.height = 0 -- 0 means size to content
    self.padding = {top = 0, right = 0, bottom = 0, left = 0}
    self.margin = {top = 0, right = 0, bottom = 0, left = 0}
    self.children = {}  -- For layout positioning
    self.sprite_objects = {}  -- sprite_id -> SpriteObject
    self.sprite_groups = {}   -- group_name -> {sprite_id1, sprite_id2, ...}
    self.state = {
        visible = true,
        enabled = true,
        dirty = true,
        needs_layout = true
    }
    self.z_order = 0
    self.parent = nil
    self._calculated_size = {width = 0, height = 0}
    self._child_widgets = {} -- For nested widgets
    self.widget_type = widget_type or "Widget"  -- For debugging
    
    -- Animation tracking
    self.active_animations = {}
    self.active_sequences = {}
    
    -- Track if widget is currently being animated (so layout doesn't override)
    self._layout_animation_active = false
    self._layout_animation_type = nil  -- "position", "scale", "rotation", "transform"
    
    -- Register in cache
    WidgetCache.register(self)
    
    debug_print("INFO", "Widget created: id=%s, player=%s, type=%s", self.id, self.player_id, self.widget_type)
    
    return self
end

-- ===========================================================
-- WIDGET ANIMATION FUNCTIONS (UPDATED TO ANIMATE SPRITES)
-- ===========================================================

-- Purpose: Smoothly slide/move a widget from current position to target position
function Widget:slide_widget(target_x, target_y, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.slide_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "linear"
    
    debug_print("INFO", "Widget.slide_widget: %s to (%d,%d) in %f seconds", 
               self.id, target_x, target_y, duration)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    
    -- Get starting position
    local start_x = self.x
    local start_y = self.y
    
    -- Calculate delta for all sprites
    local delta_x = target_x - start_x
    local delta_y = target_y - start_y
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "position", delta_x = delta_x, delta_y = delta_y})
        
        local sprite_props = sprite:get_properties()
        local sprite_target_x = sprite_props.x + delta_x
        local sprite_target_y = sprite_props.y + delta_y
        
        local anim_id = sprite:slide_sprite(sprite_target_x, sprite_target_y, duration, easing)
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:slide_widget(
            child_widget.x + delta_x,
            child_widget.y + delta_y,
            duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    -- Animate the widget's position for layout purposes
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.slide_widget: AnimationEngine not loaded")
        return nil
    end
    local anim_id = nil
    anim_id = AnimationEngine.animate(
        {x = start_x, y = start_y},
        {x = target_x, y = target_y},
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget position
                self:setPosition(values.x, values.y)
                
                -- Update sprites' absolute positions through their widget-relative positions
                -- (already handled by sprite animations)
            end,
            on_complete = function(values, interrupted)
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Clear sprite animation flags
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                -- Clear child widget animation flags
                for _, child_data in ipairs(child_animations) do
                    if child_data.widget then
                        child_data.widget._layout_animation_active = false
                        child_data.widget._layout_animation_type = nil
                    end
                end
                
                self.active_animations[anim_id] = nil
                if on_complete then
                    on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Smoothly slide/move a widget from specified start to target position
function Widget:set_slide_widget(start_x, start_y, target_x, target_y, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_slide_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.set_slide_widget: %s from (%d,%d) to (%d,%d) in %f seconds", 
               self.id, start_x, start_y, target_x, target_y, duration)
    
    -- Set starting position immediately
    self:setPosition(start_x, start_y)
    
    return self:slide_widget(target_x, target_y, duration, easing, on_complete)
end

-- Purpose: Smoothly move a widget relative to its current position
function Widget:move_widget(offset_x, offset_y, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.move_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Calculate target position
    local target_x = self.x + offset_x
    local target_y = self.y + offset_y
    
    debug_print("INFO", "Widget.move_widget: %s by (%d,%d) to (%d,%d)", 
               self.id, offset_x, offset_y, target_x, target_y)
    
    return self:slide_widget(target_x, target_y, duration, easing, on_complete)
end

-- Purpose: Smoothly scale a widget (consistent with slide pattern)
function Widget:scale_widget(target_scale, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.scale_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current scale
    local current_scale = self.sx or 1.0
    
    debug_print("INFO", "Widget.scale_widget: %s from scale %f to %f", 
               self.id, current_scale, target_scale)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "scale"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "scale", target_scale = target_scale})
        
        local anim_id = sprite:scale_sprite(target_scale, duration, easing)
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:scale_widget(target_scale, duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.scale_widget: AnimationEngine not available")
        return nil
    end
    
    local anim_id = AnimationEngine.animate(
        {sx = current_scale, sy = current_scale},
        {sx = target_scale, sy = target_scale},
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget scale
                self:setScale(values.sx, values.sy)
                
                -- Sprites are already being animated separately
            end,
            on_complete = function(values, interrupted)
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Clear sprite animation flags
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                -- Clear child widget animation flags
                for _, child_data in ipairs(child_animations) do
                    if child_data.widget then
                        child_data.widget._layout_animation_active = false
                        child_data.widget._layout_animation_type = nil
                    end
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Smoothly rotate a widget (consistent with slide pattern)
function Widget:rotate_widget(target_rotation, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.rotate_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current rotation
    local current_rotation = self.ro or 0
    
    debug_print("INFO", "Widget.rotate_widget: %s from rotation %f to %f", 
               self.id, current_rotation, target_rotation)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "rotation"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "rotation", target_rotation = target_rotation})
        
        local anim_id = sprite:rotate_sprite(target_rotation, duration, easing)
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:rotate_widget(target_rotation, duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.rotate_widget: AnimationEngine not available")
        return nil
    end
    
    local anim_id = AnimationEngine.animate(
        {ro = current_rotation},
        {ro = target_rotation},
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget rotation
                self:setRotation(values.ro)
                
                -- Sprites are already being animated separately
            end,
            on_complete = function(values, interrupted)
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Clear sprite animation flags
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                -- Clear child widget animation flags
                for _, child_data in ipairs(child_animations) do
                    if child_data.widget then
                        child_data.widget._layout_animation_active = false
                        child_data.widget._layout_animation_type = nil
                    end
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Complex animation that combines slide, scale, and rotation
function Widget:transform_widget(properties, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.transform_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.transform_widget: %s with %d properties", 
               self.id, #properties)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Calculate deltas for sprites
    local delta_x = (properties.x or self.x) - self.x
    local delta_y = (properties.y or self.y) - self.y
    local target_scale = properties.sx or self.sx
    local target_rotation = properties.ro or self.ro
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {
            type = "transform", 
            delta_x = delta_x,
            delta_y = delta_y,
            target_scale = target_scale,
            target_rotation = target_rotation
        })
        
        local sprite_props = sprite:get_properties()
        local sprite_target_x = sprite_props.x + delta_x
        local sprite_target_y = sprite_props.y + delta_y
        
        -- Animate sprite with all properties
        local anim_id = sprite:animate({
            x = sprite_target_x,
            y = sprite_target_y,
            sx = target_scale,
            sy = target_scale,
            ro = target_rotation
        }, duration, {easing = easing})
        
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local child_props = {}
        if properties.x then child_props.x = child_widget.x + delta_x end
        if properties.y then child_props.y = child_widget.y + delta_y end
        if properties.sx then child_props.sx = target_scale end
        if properties.sy then child_props.sy = target_scale end
        if properties.ro then child_props.ro = target_rotation end
        
        local anim_id = child_widget:transform_widget(child_props, duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.transform_widget: AnimationEngine not available")
        return nil
    end
    
    local start_properties = {
        x = self.x,
        y = self.y,
        sx = self.sx,
        sy = self.sy,
        ro = self.ro
    }
    
    local target_properties = {}
    for key, value in pairs(properties) do
        if start_properties[key] ~= nil then
            target_properties[key] = value
        end
    end
    
    local anim_id = AnimationEngine.animate(start_properties, target_properties, duration, {
        easing = easing,
        on_update = function(values)
            -- Update widget properties
            if values.x or values.y then
                self:setPosition(values.x or self.x, values.y or self.y)
            end
            if values.sx or values.sy then
                self:setScale(values.sx or self.sx, values.sy or self.sy)
            end
            if values.ro then
                self:setRotation(values.ro)
            end
            
            -- Sprites are already being animated separately
        end,
        on_complete = function(values, interrupted)
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
            end
            
            -- Clear child widget animation flags
            for _, child_data in ipairs(child_animations) do
                if child_data.widget then
                    child_data.widget._layout_animation_active = false
                    child_data.widget._layout_animation_type = nil
                end
            end
            
            if on_complete then
                on_complete(values, interrupted)
            end
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Apply Bob animation to a widget
function Widget:bob_widget(distance, duration, easing, loop, ping_pong)
    if not self then
        debug_print("ERROR", "Widget.bob_widget: Invalid widget")
        return nil
    end
    
    local start_y = self.y or 0
    distance = distance or 3
    duration = duration or 1.0
    easing = easing or "smoothstep"
    loop = loop or true
    ping_pong = ping_pong or true
    
    debug_print("INFO", "Widget.bob_widget: %s bob distance %d, duration %f", 
               self.id, distance, duration)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "bob", distance = distance})
        
        local sprite_props = sprite:get_properties()
        local anim_id = sprite:animate(
            {y = sprite_props.y - distance},
            duration,
            {
                easing = easing,
                loop = loop,
                ping_pong = ping_pong
            }
        )
        
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:bob_widget(distance, duration, easing, loop, ping_pong)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.bob_widget: AnimationEngine not available")
        return nil
    end
    
    local anim_id = AnimationEngine.animate(
        {y = start_y},
        {y = start_y - distance},
        duration,
        {
            easing = easing,
            loop = loop,
            ping_pong = ping_pong,
            on_update = function(values)
                -- Update widget position
                self:setPosition(self.x, values.y)
                
                -- Sprites are already being animated separately
            end,
            on_complete = function(values, interrupted)
                if not loop then
                    -- Clear animation flags
                    self._layout_animation_active = false
                    self._layout_animation_type = nil
                    
                    -- Clear sprite animation flags
                    for sprite_id, sprite in pairs(self.sprite_objects) do
                        sprite:set_widget_animated(false)
                    end
                    
                    -- Clear child widget animation flags
                    for _, child_data in ipairs(child_animations) do
                        if child_data.widget then
                            child_data.widget._layout_animation_active = false
                            child_data.widget._layout_animation_type = nil
                        end
                    end
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Pulse the scale of a widget
function Widget:pulse_scale_widget(min_scale, max_scale, pulse_duration, easing, loops, on_complete)
    if not self then
        debug_print("ERROR", "Widget.pulse_scale_widget: Invalid widget")
        return nil
    end
    
    local current_scale = self.sx or 1.0
    min_scale = min_scale or current_scale * 0.9
    max_scale = max_scale or current_scale * 1.1
    pulse_duration = pulse_duration or 0.5
    
    debug_print("INFO", "Widget.pulse_scale_widget: %s pulse scale %f->%f", 
               self.id, min_scale, max_scale)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "scale"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "pulse", min_scale = min_scale, max_scale = max_scale})
        
        -- Create pulse animation for each sprite
        local start_properties = {scale = min_scale}
        local target_properties = {scale = max_scale}
        
        local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
        
        if not AnimationEngine then
            debug_print("WARN", "Widget.pulse_scale_widget: AnimationEngine not available")
            return nil
        end
        
        local anim_id = AnimationEngine.animate(start_properties, target_properties, pulse_duration / 2, {
            easing = easing or "ease_in_out",
            on_update = function(values)
                sprite:set_scale(values.scale)
            end,
            loop = loops or 1,
            ping_pong = true
        })
        
        if anim_id then
            sprite.active_animations[anim_id] = true
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:pulse_scale_widget(min_scale, max_scale, pulse_duration, easing, loops)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    -- We'll use a custom animation for this because it's a ping-pong between two scales
    local start_properties = {scale = min_scale}
    local target_properties = {scale = max_scale}
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.pulse_scale_widget: AnimationEngine not available")
        return nil
    end
    
    local anim_id = AnimationEngine.animate(start_properties, target_properties, pulse_duration / 2, {
        easing = easing or "ease_in_out",
        on_update = function(values)
            self:setScale(values.scale)
        end,
        on_complete = on_complete,
        loop = loops or 1,
        ping_pong = true
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
        
        -- Store cleanup function
        self.active_animations[anim_id .. "_cleanup"] = function()
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
            end
            
            -- Clear child widget animation flags
            for _, child_data in ipairs(child_animations) do
                if child_data.widget then
                    child_data.widget._layout_animation_active = false
                    child_data.widget._layout_animation_type = nil
                end
            end
        end
    end
    
    return anim_id
end

-- Purpose: Apply color pulse from current color
function Widget:color_pulse_from_current(target_color)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_from_current: Invalid widget")
        return nil
    end
    
    local current_color = {
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        a = self.a or 255
    }
    
    return self:color_pulse_widget(current_color, target_color)
end

-- Purpose: Apply summon animation to widget (flies with arc)
function Widget:summon_widget(start_x, start_y, start_scale, 
                            end_x, end_y, end_scale, duration, arc_height, peak_scale_mul, wobble_deg, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.summon_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.25
    arc_height = arc_height or 24
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 5
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.summon_widget: %s summon from (%d,%d) to (%d,%d)", 
               self.id, start_x, start_y, end_x, end_y)
    
    -- Set starting position and scale
    self:setPosition(start_x, start_y)
    self:setScale(start_scale)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Calculate deltas for sprites
    local delta_x = end_x - start_x
    local delta_y = end_y - start_y
    local scale_delta = end_scale - start_scale
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {
            type = "summon",
            delta_x = delta_x,
            delta_y = delta_y,
            start_scale = start_scale,
            end_scale = end_scale,
            arc_height = arc_height
        })
        
        local sprite_props = sprite:get_properties()
        local sprite_end_x = sprite_props.x + delta_x
        local sprite_end_y = sprite_props.y + delta_y
        
        -- We'll handle sprite summoning separately below
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.summon_widget: AnimationEngine not available")
        return nil
    end
    
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        {progress = 0},
        {progress = 1},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local t = values.progress
                local u = 1 - t
                local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
                local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
                
                local base_scale = start_scale + (end_scale - start_scale) * t
                local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
                local current_scale = base_scale * pulse
                
                local rotation = 0
                if wobble_deg ~= 0 then
                    rotation = math.sin(math.pi * 2 * t) * wobble_deg * (1 - t)
                end
                
                self:setPosition(x, y)
                self:setScale(current_scale)
                self:setRotation(rotation)
                
                -- Update all sprites with same transform
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local sprite_props = sprite:get_properties()
                    local sprite_x = sprite_props.x + (x - start_x)
                    local sprite_y = sprite_props.y + (y - start_y)
                    
                    sprite:update({
                        x = sprite_x,
                        y = sprite_y,
                        sx = current_scale,
                        sy = current_scale,
                        ro = rotation
                    })
                end
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    self:setPosition(end_x, end_y)
                    self:setScale(end_scale)
                    self:setRotation(0)
                    
                    -- Update all sprites to final position
                    for sprite_id, sprite in pairs(self.sprite_objects) do
                        local sprite_props = sprite:get_properties()
                        local sprite_end_x = sprite_props.x + delta_x
                        local sprite_end_y = sprite_props.y + delta_y
                        
                        sprite:update({
                            x = sprite_end_x,
                            y = sprite_end_y,
                            sx = end_scale,
                            sy = end_scale,
                            ro = 0
                        })
                        
                        sprite:set_widget_animated(false)
                    end
                end
                
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                if self.active_animations and anim_id then
                    self.active_animations[anim_id] = nil
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Apply complex summon animation
function Widget:complex_summon_widget(start_x, start_y, start_scale,
                                    end_x, end_y, end_scale, arc_duration, wobble_duration, settle_duration, 
                                    arc_height, peak_scale_mul, wobble_deg, easing, on_complete, 
                                    on_update_step1, on_update_step2, on_update_step3)
    if not self then
        debug_print("ERROR", "Widget.complex_summon_widget: Invalid widget")
        return nil
    end
    
    arc_duration = arc_duration or 0.25
    wobble_duration = wobble_duration or 0.1
    settle_duration = settle_duration or 0.05
    arc_height = arc_height or 40
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 10
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.complex_summon_widget: %s complex summon", self.id)
    
    -- Set starting position and scale
    self:setPosition(start_x, start_y)
    self:setScale(start_scale)
    self:setRotation(0)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Calculate deltas for sprites
    local delta_x = end_x - start_x
    local delta_y = end_y - start_y
    local scale_delta = end_scale - start_scale
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.complex_summon_widget: AnimationEngine not available")
        return nil
    end
    
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    local sequence_steps = {}
    
    -- Step 1: Arc movement with scale pulse
    table.insert(sequence_steps, {
        type = "animate",
        duration = arc_duration,
        easing = easing,
        on_update = function(values, t, phase)
            local u = 1 - t
            local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
            local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
            
            local base_scale = start_scale + (end_scale - start_scale) * t
            local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
            local current_scale = base_scale * pulse
            
            self:setPosition(x, y)
            self:setScale(current_scale)
            self:setRotation(0)
            
            -- Update all sprites with same transform
            for sprite_id, sprite in pairs(self.sprite_objects) do
                local sprite_props = sprite:get_properties()
                local sprite_x = sprite_props.x + (x - start_x)
                local sprite_y = sprite_props.y + (y - start_y)
                
                sprite:update({
                    x = sprite_x,
                    y = sprite_y,
                    sx = current_scale,
                    sy = current_scale,
                    ro = 0
                })
            end
            
            if on_update_step1 then
                on_update_step1({x = x, y = y, scale = current_scale, progress = t})
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
                self:setRotation(wobble)
                
                -- Update all sprites with same rotation
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:update({ro = wobble})
                end
                
                if on_update_step2 then
                    on_update_step2({rotation = wobble, progress = t})
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
            local settle_scale = end_scale * (1 - 0.05 * (1 - t))
            self:setScale(settle_scale)
            self:setRotation(0)
            
            -- Update all sprites with same scale
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:update({
                    sx = settle_scale,
                    sy = settle_scale,
                    ro = 0
                })
            end
            
            if on_update_step3 then
                on_update_step3({scale = settle_scale, progress = t})
            end
        end,
        on_complete = function(values, interrupted)
            if not interrupted then
                self:setPosition(end_x, end_y)
                self:setScale(end_scale)
                self:setRotation(0)
                
                -- Update all sprites to final position
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local sprite_props = sprite:get_properties()
                    local sprite_end_x = sprite_props.x + delta_x
                    local sprite_end_y = sprite_props.y + delta_y
                    
                    sprite:update({
                        x = sprite_end_x,
                        y = sprite_end_y,
                        sx = end_scale,
                        sy = end_scale,
                        ro = 0
                    })
                    
                    sprite:set_widget_animated(false)
                end
            end
            
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            if on_complete then
                on_complete(values, interrupted)
            end
        end
    })
    
    local seq_id = AnimationEngine.create_sequence(sequence_steps, {
        id = "complex_summon_" .. self.id .. "_" .. math.random(1000, 9999)
    })
    
    if seq_id then
        self.active_sequences[seq_id] = true
        AnimationEngine.start_sequence(seq_id)
    end
    
    return seq_id
end

-- Purpose: Apply fade animation to widget
function Widget:set_opacity_widget(target_opacity, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_opacity_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.set_opacity_widget: %s to opacity %d", 
               self.id, target_opacity)
    
    return self:animate_opacity(target_opacity, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

-- Purpose: Apply tint animation to widget
function Widget:set_widget_color(r, g, b, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_widget_color: Invalid widget")
        return nil
    end
    
    duration = duration or 0.25
    easing = easing or "ease_in_out"
    
    r = math.max(0, math.min(255, r or 255))
    g = math.max(0, math.min(255, g or 255))
    b = math.max(0, math.min(255, b or 255))
    
    debug_print("INFO", "Widget.set_widget_color: %s to color (%d,%d,%d)", 
               self.id, r, g, b)
    
    -- Animate ALL sprite objects within this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_color_sprite(r, g, b, duration, easing)
    end
    
    -- Also animate child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:set_widget_color(r, g, b, duration, easing)
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.set_widget_color: AnimationEngine not available")
        return nil
    end
    
    local anim_id = AnimationEngine.animate(
        {r = self.r, g = self.g, b = self.b},
        {r = r, g = g, b = b},
        duration,
        {
            easing = easing,
            on_complete = on_complete
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Apply color pulse animation to widget
function Widget:color_pulse_widget(start_color, target_color)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationSequences then
        debug_print("WARN", "Widget.color_pulse_widget: AnimationSequences not available")
        return nil
    end
    
    debug_print("INFO", "Widget.color_pulse_widget: %s color pulse", self.id)
    
    -- Create a proxy object for the animation
    local proxy = {
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        a = self.a or 255,
        setColor = function(_, r, g, b, a)
            self:setColor(r, g, b, a)
            
            -- Update all sprites with same color
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_color(r, g, b, a)
            end
        end,
        setAlpha = function(_, alpha)
            self:setOpacity(alpha)
            
            -- Update all sprites with same opacity
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_opacity(alpha)
            end
        end
    }
    
    local anim_id = AnimationSequences.color_pulse(proxy, start_color, target_color)
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Simple color pulse with RGB values
function Widget:color_pulse_rgb(start_r, start_g, start_b, start_a, 
                               target_r, target_g, target_b, target_a)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_rgb: Invalid widget")
        return nil
    end
    
    local start_color = {
        r = start_r or 255,
        g = start_g or 255,
        b = start_b or 255,
        a = start_a or 255
    }
    
    local target_color = {
        r = target_r or 255,
        g = target_g or 255,
        b = target_b or 255,
        a = target_a or start_color.a
    }
    
    return self:color_pulse_widget(start_color, target_color)
end

-- Purpose: Apply menu cursor animation (bob + pulse)
function Widget:menu_cursor_widget(bob_distance, pulse_scale, bob_duration, pulse_duration, 
                                  orientation, easing, back_easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.menu_cursor_widget: Invalid widget")
        return nil
    end
    
    pulse_scale = pulse_scale or 1.1
    bob_distance = bob_distance or 3
    bob_duration = bob_duration or 0.8
    pulse_duration = pulse_duration or (bob_duration * 1.5)
    easing = easing or "smootherstep"
    back_easing = back_easing or "smootherstep"
    
    local orientation = orientation or "vertical"
    local axis = (orientation == "vertical") and "y" or "x"
    
    debug_print("INFO", "Widget.menu_cursor_widget: %s menu cursor animation", self.id)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Animate ALL sprite objects within this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {
            type = "menu_cursor",
            axis = axis,
            bob_distance = bob_distance,
            pulse_scale = pulse_scale
        })
        
        -- Bob animation for sprite
        local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
        
        if AnimationEngine then
            local bob_id = AnimationEngine.animate(
                {[axis] = sprite.properties[axis]},
                {[axis] = sprite.properties[axis] - bob_distance},
                bob_duration,
                {
                    easing = easing,
                    easing_back = back_easing,
                    on_update = function(values)
                        if axis == "y" then
                            sprite:update({y = values[axis]})
                        else
                            sprite:update({x = values[axis]})
                        end
                    end,
                    loop = true,
                    ping_pong = true
                }
            )
            
            -- Pulse animation for sprite
            local pulse_id = AnimationEngine.animate(
                {scale = 1.0},
                {scale = pulse_scale},
                pulse_duration,
                {
                    easing = "ease_in_out",
                    on_update = function(values)
                        sprite:update({sx = values.scale, sy = values.scale})
                    end,
                    loop = true,
                    ping_pong = true
                }
            )
            
            if bob_id then sprite.active_animations[bob_id] = true end
            if pulse_id then sprite.active_animations[pulse_id] = true end
        end
    end
    
    -- Also animate child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:menu_cursor_widget(bob_distance, pulse_scale, bob_duration, pulse_duration, 
                                      orientation, easing, back_easing, on_complete)
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.menu_cursor_widget: AnimationEngine not available")
        return nil
    end
    
    -- Bob animation for widget
    local bob_id = AnimationEngine.animate(
        {[axis] = self[axis]},
        {[axis] = self[axis] - bob_distance},
        bob_duration,
        {
            easing = easing,
            easing_back = back_easing,
            on_update = function(values)
                if axis == "y" then
                    self:setPosition(self.x, values[axis])
                else
                    self:setPosition(values[axis], self.y)
                end
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    -- Pulse animation for widget
    local pulse_id = AnimationEngine.animate(
        {scale = 1.0},
        {scale = pulse_scale},
        pulse_duration,
        {
            easing = "ease_in_out",
            on_update = function(values)
                self:setScale(values.scale)
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    if bob_id then self.active_animations[bob_id] = true end
    if pulse_id then self.active_animations[pulse_id] = true end
    
    return {
        bob = bob_id,
        pulse = pulse_id,
        stop = function()
            AnimationEngine.stop_animation(bob_id)
            AnimationEngine.stop_animation(pulse_id)
            if self.active_animations then
                self.active_animations[bob_id] = nil
                self.active_animations[pulse_id] = nil
            end
            
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
                sprite:stop_animation()
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
                child_widget:stop_widget_animation()
            end
            
            if on_complete then
                on_complete()
            end
        end
    }
end

-- Purpose: Apply shake animation to widget
function Widget:shake_widget(intensity, duration, frequency, on_complete)
    if not self then
        debug_print("ERROR", "Widget.shake_widget: Invalid widget")
        return nil
    end
    
    intensity = intensity or 5
    duration = duration or 0.5
    frequency = frequency or 15
    
    debug_print("INFO", "Widget.shake_widget: %s shake intensity %d", self.id, intensity)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    
    -- Animate ALL sprite objects within this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "shake", intensity = intensity})
        
        -- Create shake animation for each sprite
        local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
        
        if AnimationSequences then
            local proxy = {
                x = sprite.properties.x,
                y = sprite.properties.y,
                rotation = sprite.properties.ro or 0,
                setPosition = function(_, x, y)
                    sprite:update({x = x, y = y})
                end,
                setRotation = function(_, rotation)
                    sprite:update({ro = rotation})
                end
            }
            
            AnimationSequences.shake(proxy, {
                intensity = intensity,
                duration = duration,
                frequency = frequency
            })
        end
    end
    
    -- Also animate child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:shake_widget(intensity, duration, frequency)
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationSequences then
        debug_print("WARN", "Widget.shake_widget: AnimationSequences not available")
        return nil
    end
    
    -- Create a proxy object for the animation
    local proxy = {
        x = self.x,
        y = self.y,
        rotation = self.ro or 0,
        setPosition = function(_, x, y)
            self:setPosition(x, y)
        end,
        setRotation = function(_, rotation)
            self:setRotation(rotation)
        end
    }
    
    local seq_id = AnimationSequences.shake(proxy, {
        intensity = intensity,
        duration = duration,
        frequency = frequency,
        on_complete = function()
            if self.active_sequences then
                self.active_sequences[seq_id] = nil
            end
            
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
            end
            
            if on_complete then
                on_complete()
            end
        end
    })
    
    if seq_id then
        self.active_sequences[seq_id] = true
    end
    
    return seq_id
end

-- Purpose: Apply instant transition (no animation)
function Widget:set_widget_instant(properties)
    if not self then
        debug_print("ERROR", "Widget.set_widget_instant: Invalid widget")
        return
    end
    
    debug_print("INFO", "Widget.set_widget_instant: %s instant update", self.id)
    
    for key, value in pairs(properties) do
        if key == "x" or key == "y" then
            self:setPosition(value, properties.y or self.y)
            
            -- Update all sprite positions
            local delta_x = (properties.x or self.x) - self.x
            local delta_y = (properties.y or self.y) - self.y
            
            for sprite_id, sprite in pairs(self.sprite_objects) do
                local sprite_props = sprite:get_properties()
                sprite:update({
                    x = sprite_props.x + delta_x,
                    y = sprite_props.y + delta_y
                })
            end
        elseif key == "sx" or key == "sy" then
            self:setScale(value, properties.sy or value)
            
            -- Update all sprite scales
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:update({
                    sx = value,
                    sy = properties.sy or value
                })
            end
        elseif key == "ro" then
            self:setRotation(value)
            
            -- Update all sprite rotations
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:update({ro = value})
            end
        elseif key == "opacity" then
            self:setOpacity(value)
            
            -- Update all sprite opacities
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_opacity(value)
            end
        elseif key == "r" or key == "g" or key == "b" or key == "a" then
            self:setColor(
                properties.r or self.r,
                properties.g or self.g,
                properties.b or self.b,
                properties.a or self.a
            )
            
            -- Update all sprite colors
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_color(
                    properties.r or self.r,
                    properties.g or self.g,
                    properties.b or self.b,
                    properties.a or self.a
                )
            end
        end
    end
end

-- Purpose: Reset widget to its initial state
function Widget:reset_widget(initial_values)
    if not self then
        debug_print("ERROR", "Widget.reset_widget: Invalid widget")
        return
    end
    
    debug_print("INFO", "Widget.reset_widget: %s resetting", self.id)
    
    self:stop_widget_animation()
    
    local reset_props = initial_values or {
        x = self.x or 0,
        y = self.y or 0,
        sx = self.sx or 1.0,
        sy = self.sy or 1.0,
        ro = self.ro or 0,
        opacity = self.opacity or 255,
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255
    }
    
    self:set_widget_instant(reset_props)
end

-- Purpose: Stop widget animation
function Widget:stop_widget_animation(anim_id)
    if not self then
        debug_print("ERROR", "Widget.stop_widget_animation: Invalid widget")
        return false
    end
    
    if anim_id then
        local success = false
        local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
        
        if AnimationEngine then
            success = AnimationEngine.stop_animation(anim_id)
            if not success then
                success = AnimationEngine.stop_sequence(anim_id)
            end
        end
        
        if success then
            if self.active_animations then
                self.active_animations[anim_id] = nil
            end
            if self.active_sequences then
                self.active_sequences[anim_id] = nil
            end
        end
        return success
    else
        -- Stop all animations
        local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
        
        if AnimationEngine then
            if self.active_animations then
                for id, _ in pairs(self.active_animations) do
                    AnimationEngine.stop_animation(id)
                end
                self.active_animations = {}
            end
            if self.active_sequences then
                for id, _ in pairs(self.active_sequences) do
                    AnimationEngine.stop_sequence(id)
                end
                self.active_sequences = {}
            end
        end
        
        -- Clear animation flags
        self._layout_animation_active = false
        self._layout_animation_type = nil
        
        -- Stop animations on all sprites
        for _, sprite in pairs(self.sprite_objects) do
            sprite:stop_animation()
            sprite:set_widget_animated(false)
        end
        
        -- Stop animations on child widgets
        for _, widget in pairs(self._child_widgets) do
            widget:stop_widget_animation()
        end
        
        return true
    end
end

-- Purpose: Check if a widget has active animations
function Widget:has_active_animations()
    if not self then return false end
    
    local has_animations = false
    
    if self.active_animations and next(self.active_animations) ~= nil then
        has_animations = true
    end
    
    if self.active_sequences and next(self.active_sequences) ~= nil then
        has_animations = true
    end
    
    return has_animations
end

-- Purpose: Check if a specific animation is running on a widget
function Widget:is_animation_running(anim_id)
    if not self then return false end
    
    local is_running = false
    
    if self.active_animations and self.active_animations[anim_id] then
        is_running = true
    end
    
    if self.active_sequences and self.active_sequences[anim_id] then
        is_running = true
    end
    
    return is_running
end

-- Purpose: Get widget properties
function Widget:get_widget_properties()
    if not self then return nil end
    
    return {
        x = self.x,
        y = self.y,
        sx = self.sx,
        sy = self.sy,
        ro = self.ro,
        opacity = self.opacity,
        r = self.r,
        g = self.g,
        b = self.b,
        a = self.a,
        visible = self.state.visible,
        enabled = self.state.enabled,
        has_animations = self:has_active_animations()
    }
end

-- ===========================================================
-- WIDGET BASE METHODS (CONTINUED)
-- ===========================================================

-- Create and manage sprite objects with optional layout dimensions
function Widget:create_sprite(sprite_id, texture_path, anim_path, anim_state, layout_width, layout_height)
    -- Generate unique sprite ID if not provided
    local unique_sprite_id = sprite_id or utils.generate_unique_id("sprite")
    
    if self.sprite_objects[unique_sprite_id] then
        debug_print("WARN", "Widget.create_sprite: Sprite %s already exists in widget %s", 
                   unique_sprite_id, self.id)
        return self.sprite_objects[unique_sprite_id]
    end
    
    local sprite = SpriteObject.new(unique_sprite_id, self.id, self.player_id, 
                                   texture_path, anim_path, anim_state)
    
    -- Set custom layout dimensions if provided
    if layout_width and layout_height then
        sprite:set_layout_dimensions(width, height)
    end
    
    self.sprite_objects[unique_sprite_id] = sprite
    
    -- Add to children for layout
    table.insert(self.children, {
        type = "sprite",
        sprite_id = unique_sprite_id,
        sprite = sprite,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state,
        layout_width = layout_width,  -- Store custom dimensions
        layout_height = layout_height,
        id = unique_sprite_id
    })
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.create_sprite: %s added to widget %s with layout dimensions %dx%d", 
               unique_sprite_id, self.id, layout_width or 0, layout_height or 0)
    return sprite
end

-- Create sprite group
function Widget:create_sprite_group(group_name, sprite_ids)
    self.sprite_groups[group_name] = sprite_ids or {}
    debug_print("INFO", "Widget.create_sprite_group: Group %s created with %d sprites", 
               group_name, #self.sprite_groups[group_name])
    return self
end

-- Add sprite to group
function Widget:add_sprite_to_group(group_name, sprite_id)
    if not self.sprite_groups[group_name] then
        self.sprite_groups[group_name] = {}
    end
    
    if not utils.table_contains(self.sprite_groups[group_name], sprite_id) then
        table.insert(self.sprite_groups[group_name], sprite_id)
        debug_print("DETAILED", "Widget.add_sprite_to_group: %s added to group %s", 
                   sprite_id, group_name)
    end
    
    return self
end

-- Set properties for specific sprite
function Widget:set_sprite_properties(sprite_id, properties)
    local sprite = self.sprite_objects[sprite_id]
    if sprite then
        debug_print("DETAILED", "Widget.set_sprite_properties: %s in widget %s", 
                   sprite_id, self.id)
        return sprite:update(properties)
    else
        debug_print("WARN", "Widget.set_sprite_properties: Sprite %s not found in widget %s", 
                   sprite_id, self.id)
        return false
    end
end

-- Set layout dimensions for sprite (pre-scaling)
function Widget:set_sprite_layout_dimensions(sprite_id, width, height)
    local sprite = self.sprite_objects[sprite_id]
    if sprite then
        sprite:set_layout_dimensions(width, height)
        
        -- Update the child entry with layout dimensions
        for _, child in ipairs(self.children) do
            if child.type == "sprite" and child.sprite_id == sprite_id then
                child.layout_width = width
                child.layout_height = height
                break
            end
        end
        
        self.state.dirty = true
        self.state.needs_layout = true
        
        debug_print("INFO", "Widget.set_sprite_layout_dimensions: %s = %dx%d", 
                   sprite_id, width, height)
        return true
    else
        debug_print("WARN", "Widget.set_sprite_layout_dimensions: Sprite %s not found", sprite_id)
        return false
    end
end

-- Set properties for sprite group
function Widget:set_group_properties(group_name, properties)
    local group = self.sprite_groups[group_name]
    if group then
        debug_print("DETAILED", "Widget.set_group_properties: Group %s in widget %s (%d sprites)", 
                   group_name, self.id, #group)
        local success = true
        for _, sprite_id in ipairs(group) do
            if not self:set_sprite_properties(sprite_id, properties) then
                success = false
            end
        end
        return success
    else
        debug_print("WARN", "Widget.set_group_properties: Group %s not found in widget %s", 
                   group_name, self.id)
        return false
    end
end

-- Set properties for all sprites in widget
function Widget:set_all_sprites_properties(properties, recursive)
    debug_print("DETAILED", "Widget.set_all_sprites_properties: Widget %s (%d sprites)", 
               self.id, utils.table_count(self.sprite_objects))
    
    local success = true
    
    -- Set for all sprites in this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        if not sprite:update(properties) then
            success = false
        end
    end
    
    -- Recursively set for child widgets
    if recursive then
        for _, child_widget in pairs(self._child_widgets) do
            if not child_widget:set_all_sprites_properties(properties, recursive) then
                success = false
            end
        end
    end
    
    return success
end

-- Get sprite by ID
function Widget:get_sprite(sprite_id)
    return self.sprite_objects[sprite_id]
end

-- Get all sprites
function Widget:get_all_sprites()
    local sprites = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprites[sprite_id] = sprite
    end
    return sprites
end


function Widget:setPosition(x, y)
    if not self then
        debug_print("ERROR", "Widget.setPosition: Invalid widget")
        return nil
    end
    
    self.x = x or self.x
    self.y = y or self.y
    self.state.dirty = true
    
    debug_print("DETAILED", "Widget.setPosition: %s to (%d,%d)", self.id, self.x, self.y)
    
    return self
end

function Widget:setSize(width, height)
    if not self then
        debug_print("ERROR", "Widget.setSize: Invalid widget")
        return nil
    end
    
    self.width = width or self.width
    self.height = height or self.height
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Widget.setSize: %s = %dx%d", self.id, self.width, self.height)
    
    return self
end

function Widget:setColor(r, g, b, a)
    debug_print("VERBOSE", "Widget.setColor: %s to (%d,%d,%d,%d)", 
               self.id, r, g, b, a)
    
    self.r = r or self.r
    self.g = g or self.g
    self.b = b or self.b
    self.a = a or self.a
    self.state.dirty = true
    return self
end

function Widget:setMargin(top, right, bottom, left)
    self.margin = {
        top = top or self.margin.top,
        right = right or (bottom and top or self.margin.right),
        bottom = bottom or top or self.margin.bottom,
        left = left or (right and top or self.margin.left)
    }
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("VERBOSE", "Widget.setMargin: %s = top=%d, right=%d, bottom=%d, left=%d",
               self.id, self.margin.top, self.margin.right, self.margin.bottom, self.margin.left)
    
    return self
end

function Widget:setZOrder(z_order)
    self.z_order = z_order or 0
    debug_print("VERBOSE", "Widget.setZOrder: %s = %d", self.id, self.z_order)
    return self
end
function Widget:addChild(child)
    if child and child.id then
        child.parent = self
        
        if child.type == "sprite" and child.texture_path then
            -- Create sprite object with optional layout dimensions
            local unique_sprite_id = child.sprite_id or utils.generate_unique_id("sprite")
            local sprite = self:create_sprite(
                unique_sprite_id,
                child.texture_path,
                child.anim_path,
                child.anim_state,
                child.layout_width,  -- Pass custom dimensions
                child.layout_height
            )
            
            -- Set initial properties if provided
            if child.x or child.y then
                sprite:set_position(child.x or 0, child.y or 0)
            end
            if child.scale then
                sprite:set_scale(child.scale)
            end
            if child.visible ~= nil then
                sprite:set_visible(child.visible)
            end
            
            debug_print("DETAILED", "Widget.addChild: Added sprite %s to widget %s with layout %dx%d", 
                       sprite.id, self.id, child.layout_width or 0, child.layout_height or 0)
        else
            -- IMPORTANT: Add widget child to children array for layout
            table.insert(self.children, child)
            
            -- If the child has a widget, add it to _child_widgets
            if child.widget then
                self._child_widgets[child.widget.id] = child.widget
                child.widget.parent = self
            end
            
            debug_print("DETAILED", "Widget.addChild: Added child with id=%s to widget %s, type=%s",
                       child.id or "unknown", self.id, child.widget and "widget" or "other")
        end
        
        self.state.dirty = true
        self.state.needs_layout = true
        
    else
        debug_print("ERROR", "Widget.addChild: Invalid child provided to %s", self.id)
    end
    return self
end

function Widget:removeChild(child_id)
    debug_print("INFO", "Widget.removeChild: %s removing child_id=%s", self.id, child_id)
    
    -- Check if it's a sprite
    if self.sprite_objects[child_id] then
        return self:remove_sprite(child_id)
    end
    
    -- Check children list
    for i, child in ipairs(self.children) do
        if child.id == child_id then
            -- If it's a widget, destroy it
            if child.widget then
                child.widget:destroy()
            end
            
            table.remove(self.children, i)
            self.state.dirty = true
            self.state.needs_layout = true
            
            debug_print("INFO", "  Successfully removed child at index %d", i)
            return true
        end
    end
    
    debug_print("WARN", "  Child not found: %s", child_id)
    return false
end

function Widget:clearChildren()
    debug_print("INFO", "Widget.clearChildren: %s clearing %d children and %d sprites", 
               self.id, #self.children, utils.table_count(self.sprite_objects))
    
    -- Remove all sprites
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:remove()
    end
    self.sprite_objects = {}
    self.sprite_groups = {}
    
    -- Clear children list
    self.children = {}
    self.state.dirty = true
    self.state.needs_layout = true
    
    return self
end

function Widget:removeWidget(widget_id)
    debug_print("INFO", "Widget.removeWidget: %s removing widget_id=%s", self.id, widget_id)
    
    if self._child_widgets[widget_id] then
        -- Remove from child widgets
        self._child_widgets[widget_id] = nil
        
        -- Remove from children list
        for i, child in ipairs(self.children) do
            if child.widget and child.widget.id == widget_id then
                table.remove(self.children, i)
                break
            end
        end
        
        self.state.dirty = true
        self.state.needs_layout = true
        
        debug_print("INFO", "  Successfully removed widget")
        return true
    end
    
    debug_print("WARN", "  Widget not found: %s", widget_id)
    return false
end

-- Abstract method to be overridden
function Widget:calculateLayout(available_width, available_height)
    debug_print("VERBOSE", "Widget.calculateLayout (base): %s available=%dx%d", 
               self.id, available_width, available_height)
    
    -- Returns: {width, height, positioned_children}
    return 0, 0, {}
end

-- UPDATED: Enhanced logging for debugging nested widgets with proper child widget positioning
function Widget:updateLayout(force)
    debug_print("VERBOSE", "Widget.updateLayout: %s dirty=%s, force=%s, needs_layout=%s, layout_animation=%s, parent=%s", 
               self.id, tostring(self.state.dirty), tostring(force), tostring(self.state.needs_layout),
               tostring(self._layout_animation_active), self.parent and self.parent.id or "none")
    
    if self.state.dirty or force or self.state.needs_layout then
        -- Skip layout updates if widget is being animated (unless forced)
        if self._layout_animation_active and not force then
            debug_print("DETAILED", "  Skipping layout update due to active animation")
            return false
        end
        
        -- Calculate available space considering parent constraints
        local available_width = self.width > 0 and self.width or 9999
        local available_height = self.height > 0 and self.height or 9999
        
        debug_print("DETAILED", "  Available space: %dx%d", available_width, available_height)
        
        local layout_width, layout_height, positioned_children = 
            self:calculateLayout(available_width, available_height)
        
        -- Update calculated size
        self._calculated_size = {
            width = layout_width,
            height = layout_height
        }
        
        debug_print("DETAILED", "  Calculated layout: %dx%d, children positioned: %d",
                   layout_width, layout_height, #positioned_children)
        
        -- Position children (sprites and widgets)
        for i, child in ipairs(positioned_children) do
            -- Calculate widget-relative position (relative to this widget's top-left)
            local child_widget_x = child.x + self.padding.left + self.margin.left
            local child_widget_y = child.y + self.padding.top + self.margin.top
            
            debug_print("DETAILED", "  Child %d: type=%s, widget-relative=(%d,%d), layout=(%d,%d), abs_parent=(%d,%d)",
                       i, child.sprite_id and "sprite" or "widget", 
                       child_widget_x, child_widget_y, child.x, child.y,
                       self.x, self.y)
            
            if child.sprite_id then
                -- Update sprite position (using widget-relative coordinates)
                local sprite = self.sprite_objects[child.sprite_id]
                if sprite then
                    -- Check if sprite is being animated by widget
                    if not sprite:is_widget_animated() then
                        -- Only set sprite position if it's not being animated
                        sprite:set_position(child_widget_x, child_widget_y)
                        debug_print("DETAILED", "    Sprite %s positioned at widget-relative (%d,%d) in widget %s (abs=%d,%d)", 
                                   child.sprite_id, child_widget_x, child_widget_y, self.id, self.x, self.y)
                    else
                        debug_print("DETAILED", "    Sprite %s is being animated, skipping layout position", 
                                   child.sprite_id)
                    end
                    
                    if child.visible ~= nil then
                        sprite:set_visible(self.state.visible and child.visible)
                    else
                        sprite:set_visible(self.state.visible)
                    end
                else
                    debug_print("WARN", "    Sprite not found: %s", child.sprite_id)
                end
            elseif child.widget then
                -- Update child widget position (relative to this widget's screen position)
                debug_print("DETAILED", "    Updating child widget: %s, parent_abs=(%d,%d), child_rel=(%d,%d), child_abs=(%d,%d)", 
                           child.widget.id, self.x, self.y, child_widget_x, child_widget_y, 
                           self.x + child_widget_x, self.y + child_widget_y)
                
                -- Check if child widget is being animated
                if not child.widget._layout_animation_active then
                    -- Set child widget position relative to parent widget's position
                    child.widget:setPosition(self.x + child_widget_x, self.y + child_widget_y)
                    
                    -- IMPORTANT: Update the child widget's layout AFTER setting its position
                    child.widget:updateLayout(force)
                else
                    debug_print("DETAILED", "    Child widget %s is being animated, skipping layout position", 
                               child.widget.id)
                end
            end
        end
        
        -- Update child widgets that might not have been in positioned_children
        local widget_count = 0
        for _, widget in pairs(self._child_widgets) do
            widget_count = widget_count + 1
            if not widget._layout_animation_active then
                widget:updateLayout(force)
            else
                debug_print("DETAILED", "  Child widget %s is being animated, skipping layout update", widget.id)
            end
        end
        
        if widget_count > 0 then
            debug_print("DETAILED", "  Updated %d child widgets", widget_count)
        end
        
        self.state.dirty = false
        self.state.needs_layout = false
        debug_print("INFO", "Widget layout updated: %s at position (%d,%d)", self.id, self.x, self.y)
        return true
    else
        debug_print("VERBOSE", "  Widget not dirty, skipping update")
        return false
    end
end

-- Draw all sprites in widget
function Widget:draw(force)
    debug_print("VERBOSE", "Widget.draw: %s with %d sprites at position (%d,%d)", 
               self.id, utils.table_count(self.sprite_objects), self.x, self.y)
    
    local success = true
    
    -- Draw all sprites in this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        if force or not sprite.drawn or (sprite.drawn_properties and sprite.drawn_properties.visible ~= sprite.properties.visible) then
            if not sprite:draw() then
                success = false
                debug_print("ERROR", "  Failed to draw sprite: %s", sprite_id)
            end
        end
    end
    
    -- Draw child widgets
    for _, widget in pairs(self._child_widgets) do
        if not widget:draw(force) then
            success = false
        end
    end
    
    return success
end

-- Tick-based update method
function Widget:update(dt)
    debug_print("VERBOSE", "Widget.update: %s with dt=%f, position=(%d,%d)", self.id, dt, self.x, self.y)
    
    local updated = false
    
    -- Update animations through AnimationEngine (which is already updated via tick event)
    -- Check if we need to update layout due to animations
    if self:is_animating() then
        self.state.dirty = true
    end
    
    -- Update layout if dirty and not being animated
    if self.state.dirty and not self._layout_animation_active then
        if self:updateLayout(false) then
            updated = true
        end
    end
    
    -- Update child widgets
    for _, widget in pairs(self._child_widgets) do
        if widget:update(dt) then
            updated = true
        end
    end
    
    return updated
end

-- Proper destruction with cache cleanup
function Widget:destroy()
    debug_print("INFO", "Widget.destroy: %s destroying %d sprites and %d child widgets", 
               self.id, utils.table_count(self.sprite_objects), utils.table_count(self._child_widgets))
    
    -- Stop all animations
    self:stop_all_animations()
    
    -- Remove all sprite objects
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:remove()
    end
    self.sprite_objects = {}
    self.sprite_groups = {}
    
    -- Destroy child widgets
    local widget_count = 0
    for _, widget in pairs(self._child_widgets) do
        widget_count = widget_count + 1
        widget:destroy()
    end
    self._child_widgets = {}
    
    -- Clear children list
    self.children = {}
    
    -- Unregister from cache
    WidgetCache.unregister(self.id, self.player_id)
    
    self.state.dirty = true
    
    debug_print("INFO", "Widget destroyed: %s", self.id)
end

function Widget:getCalculatedSize()
    debug_print("VERBOSE", "Widget.getCalculatedSize: %s = %dx%d", 
               self.id, self._calculated_size.width, self._calculated_size.height)
    
    return self._calculated_size.width, self._calculated_size.height
end

-- Animation methods
function Widget:animate_position(target_x, target_y, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.animate_position: AnimationEngine not available")
        return nil
    end
    
    local anim_id = AnimationEngine.animate(
        {x = self.x, y = self.y},
        {x = target_x, y = target_y},
        duration,
        {
            easing = options.easing or "ease_in_out",
            on_update = function(values)
                self:setPosition(values.x, values.y)
                if options.on_update then
                    options.on_update(values)
                end
            end,
            on_complete = function(values, interrupted)
                self.active_animations[anim_id] = nil
                if options.on_complete then
                    options.on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

function Widget:animate_properties(properties, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.animate_properties: AnimationEngine not available")
        return nil
    end
    
    local start_properties = {
        x = self.x,
        y = self.y,
        sx = self.sx,
        sy = self.sy,
        ro = self.ro,
        opacity = self.opacity,
        r = self.r,
        g = self.g,
        b = self.b,
        a = self.a
    }
    
    local target_properties = {}
    for key, value in pairs(properties) do
        if start_properties[key] ~= nil then
            target_properties[key] = value
        end
    end
    
    local anim_id = AnimationEngine.animate(start_properties, target_properties, duration, {
        easing = options.easing or "ease_in_out",
        on_update = function(values)
            if values.x or values.y then
                self:setPosition(values.x or self.x, values.y or self.y)
            end
            if values.sx or values.sy then
                self:setScale(values.sx or self.sx, values.sy or self.sy)
            end
            if values.ro then
                self:setRotation(values.ro)
            end
            if values.opacity then
                self:setOpacity(values.opacity)
            end
            if values.r or values.g or values.b or values.a then
                self:setColor(values.r or self.r, values.g or self.g, values.b or self.b, values.a or self.a)
            end
            if options.on_update then
                options.on_update(values)
            end
        end,
        on_complete = function(values, interrupted)
            self.active_animations[anim_id] = nil
            if options.on_complete then
                options.on_complete(values, interrupted)
            end
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

function Widget:animate_opacity(target_opacity, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.animate_opacity: AnimationEngine not available")
        return nil
    end
    
    local anim_id = AnimationEngine.animate(
        {opacity = self.opacity},
        {opacity = target_opacity},
        duration,
        {
            easing = options.easing or "ease_in_out",
            on_update = function(values)
                self:setOpacity(values.opacity, options.recursive or false)
                if options.on_update then
                    options.on_update(values)
                end
            end,
            on_complete = function(values, interrupted)
                self.active_animations[anim_id] = nil
                if options.on_complete then
                    options.on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

function Widget:stop_animation(anim_id)
    if anim_id then
        local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
        if AnimationEngine then
            AnimationEngine.stop_animation(anim_id)
        end
        self.active_animations[anim_id] = nil
    else
        -- Stop all animations
        for id, _ in pairs(self.active_animations) do
            local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
            if AnimationEngine then
                AnimationEngine.stop_animation(id)
            end
        end
        self.active_animations = {}
    end
end

function Widget:stop_all_animations()
    self:stop_animation()
    
    -- Stop animations on all sprites
    for _, sprite in pairs(self.sprite_objects) do
        sprite:stop_animation()
    end
    
    -- Stop animations on child widgets
    for _, widget in pairs(self._child_widgets) do
        widget:stop_all_animations()
    end
end

function Widget:is_animating()
    if next(self.active_animations) ~= nil then
        return true
    end
    
    -- Check sprites
    for _, sprite in pairs(self.sprite_objects) do
        if sprite:is_animating() then
            return true
        end
    end
    
    -- Check child widgets
    for _, widget in pairs(self._child_widgets) do
        if widget:is_animating() then
            return true
        end
    end
    
    return false
end

function Widget:printDebugInfo(level)
    level = level or 0
    local indent = string.rep("  ", level)
    
    print(indent .. "Widget: " .. self.id .. " (" .. self.widget_type .. ")")
    print(indent .. "  Position: (" .. self.x .. ", " .. self.y .. ")")
    print(indent .. "  Size: " .. self.width .. "x" .. self.height)
    print(indent .. "  State: visible=" .. tostring(self.state.visible) .. 
          ", enabled=" .. tostring(self.state.enabled) .. 
          ", dirty=" .. tostring(self.state.dirty))
    print(indent .. "  Layout Animation Active: " .. tostring(self._layout_animation_active))
    print(indent .. "  Layout Animation Type: " .. (self._layout_animation_type or "none"))
    print(indent .. "  Sprites: " .. utils.table_count(self.sprite_objects))
    print(indent .. "  Sprite Groups: " .. utils.table_count(self.sprite_groups))
    print(indent .. "  Children: " .. #self.children)
    print(indent .. "  Child Widgets: " .. utils.table_count(self._child_widgets))
    print(indent .. "  Active Animations: " .. utils.table_count(self.active_animations))
    
    if utils.table_count(self.sprite_objects) > 0 then
        print(indent .. "  Sprite details:")
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local layout_width, layout_height = sprite:get_layout_dimensions()
            local visual_width, visual_height = sprite:get_visual_dimensions()
            print(indent .. "    " .. sprite_id .. ": " .. 
                  (sprite.texture_path or "unknown") .. 
                  " (template: " .. sprite.template_id .. 
                  ", layout: " .. layout_width .. "x" .. layout_height ..
                  ", visual: " .. visual_width .. "x" .. visual_height ..
                  ", position: (" .. sprite.properties.x .. "," .. sprite.properties.y .. ")" ..
                  ", widget animated: " .. tostring(sprite:is_widget_animated()) ..
                  ", animating: " .. tostring(sprite:is_animating()) .. ")")
        end
    end
    
    if utils.table_count(self.sprite_groups) > 0 then
        print(indent .. "  Sprite Group details:")
        for group_name, sprite_ids in pairs(self.sprite_groups) do
            print(indent .. "    " .. group_name .. ": " .. #sprite_ids .. " sprites")
        end
    end
end

return Widget