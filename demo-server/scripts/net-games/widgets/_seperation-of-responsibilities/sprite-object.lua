-- widgets/sprite-object.lua
-- Sprite object management with animation support

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local SpriteObject = {}
SpriteObject.__index = SpriteObject

function SpriteObject.new(sprite_id, widget_id, player_id, texture_path, anim_path, anim_state)
    local self = setmetatable({}, SpriteObject)
    
    -- Generate a unique ID for this sprite object
    self.id = sprite_id or utils.generate_unique_id("sprite")
    self.widget_id = widget_id
    self.player_id = player_id
    self.texture_path = texture_path
    self.anim_path = anim_path
    self.anim_state = anim_state or ""
    
    -- Generate a unique template ID for allocation (based on texture/anim paths)
    self.template_id = self.id .. "_template"
    
    -- Custom dimensions for layout (override intrinsic dimensions)
    self.layout_width = nil
    self.layout_height = nil
    
    -- Track if this sprite is currently being animated by its parent widget
    self.widget_animated = false
    self.widget_animation_properties = {}
    
    self.properties = {
        x = 0,
        y = 0,
        z = 0,
        sx = 2.0,
        sy = 2.0,
        ro = 0,
        opacity = 255,
        r = 255,
        g = 255,
        b = 255,
        a = 255,
        color_mode = 0,
        visible = true
    }
    self.allocated = false
    self.drawn = false
    self.drawn_properties = nil
    
    -- Animation tracking
    self.active_animations = {}
    
    debug_print("DETAILED", "SpriteObject created: %s for widget %s (template: %s)", 
               self.id, widget_id, self.template_id)
    
    return self
end

-- Mark sprite as being animated by parent widget
function SpriteObject:set_widget_animated(is_animated, properties)
    self.widget_animated = is_animated
    if is_animated and properties then
        self.widget_animation_properties = utils.table_deepcopy(properties)
    elseif not is_animated then
        self.widget_animation_properties = {}
    end
end

-- Check if sprite is being animated by parent widget
function SpriteObject:is_widget_animated()
    return self.widget_animated
end

-- Set custom dimensions for layout (pre-scaling)
function SpriteObject:set_layout_dimensions(width, height)
    self.layout_width = width
    self.layout_height = height
    debug_print("DETAILED", "SpriteObject.set_layout_dimensions: %s = %dx%d", 
               self.id, width or 0, height or 0)
    return self
end

-- Get dimensions for layout (either custom or from animation file)
function SpriteObject:get_layout_dimensions()
    if self.layout_width and self.layout_height then
        -- Use custom dimensions if set
        debug_print("VERBOSE", "SpriteObject.get_layout_dimensions: %s using custom %dx%d", 
                   self.id, self.layout_width, self.layout_height)
        return self.layout_width, self.layout_height
    end
    
    -- Otherwise, get dimensions from animation file (without scaling)
    local SpriteDimensionCache = require('scripts/net-games/widgets/sprite-dimension-cache')
    local width, height = SpriteDimensionCache.get_dimensions(
        self.texture_path, self.anim_path, self.anim_state)
    
    debug_print("VERBOSE", "SpriteObject.get_layout_dimensions: %s using intrinsic %dx%d", 
               self.id, width, height)
    return width, height
end

-- Get visual dimensions (including scale)
function SpriteObject:get_visual_dimensions()
    local width, height = self:get_layout_dimensions()
    
    -- Apply current scale
    local visual_width = width * (self.properties.sx or 1.0)
    local visual_height = height * (self.properties.sy or 1.0)
    
    debug_print("VERBOSE", "SpriteObject.get_visual_dimensions: %s = %dx%d * scale(%f,%f) = %dx%d", 
               self.id, width, height, 
               self.properties.sx or 1.0, self.properties.sy or 1.0,
               visual_width, visual_height)
    
    return visual_width, visual_height
end

function SpriteObject:allocate()
    if self.allocated then
        debug_print("VERBOSE", "SpriteObject.allocate: %s already allocated", self.id)
        return true
    end
    
    debug_print("DETAILED", "SpriteObject.allocate: %s with texture=%s, anim=%s, template_id=%s", 
               self.id, self.texture_path, self.anim_path or "none", self.template_id)
    
    -- Provide assets
    if self.anim_path and self.anim_path ~= "" then
        Net.provide_asset_for_player(self.player_id, self.anim_path)
    end
    Net.provide_asset_for_player(self.player_id, self.texture_path)
    
    -- Allocate sprite template
    local success, result = pcall(Net.player_alloc_sprite, self.player_id, self.template_id, {
        texture_path = self.texture_path,
        anim_path = self.anim_path or "",
        anim_state = self.anim_state
    })
    
    if success then
        self.allocated = true
        debug_print("INFO", "SpriteObject.allocate: %s allocated successfully (template: %s)", 
                   self.id, self.template_id)
        return true
    else
        debug_print("ERROR", "SpriteObject.allocate: Failed to allocate %s (template: %s) - %s", 
                   self.id, self.template_id, result)
        return false
    end
end

function SpriteObject:get_origin_offset()
    -- Try to parse the animation file to get origin information
    if not self.anim_path or self.anim_path == "" then
        return 0, 0
    end
    
    local elements, errors = utils.parse_animation_file(self.anim_path)
    
    if not elements or #elements == 0 then
        debug_print("WARN", "SpriteObject.get_origin_offset: No elements found in %s", self.anim_path)
        return 0, 0
    end
    
    local ox, oy = 0, 0
    local in_correct_state = false
    
    debug_print("DETAILED", "Looking for origin in animation state: %s", self.anim_state or "default")
    
    for _, element in ipairs(elements) do
        -- Check if this element starts an animation state
        if element.text == "animation" then
            local state_attr = utils.get_element_attribute(element, "state", "")
            debug_print("VERBOSE", "Found animation element with state: %s", state_attr)
            
            in_correct_state = (state_attr == self.anim_state) or 
                              (self.anim_state == "" and state_attr == "") or
                              (self.anim_state == "" and state_attr == nil)
            
            if in_correct_state then
                debug_print("DETAILED", "Entering correct animation state")
            end
        elseif in_correct_state and element.text == "frame" then
            -- Get origin from frame attributes
            ox = utils.get_element_attribute_int(element, "originx", 0)
            oy = utils.get_element_attribute_int(element, "originy", 0)
            
            -- Try alternative attribute names
            if ox == 0 then
                ox = utils.get_element_attribute_int(element, "ox", 0)
            end
            if oy == 0 then
                oy = utils.get_element_attribute_int(element, "oy", 0)
            end
            
            if ox ~= 0 or oy ~= 0 then
                debug_print("DETAILED", "Found origin for sprite %s: ox=%d, oy=%d", 
                           self.id, ox, oy)
            end
            break
        end
    end
    
    return ox, oy
end

function SpriteObject:draw()
    if not self.allocated then
        if not self:allocate() then
            return false
        end
    end
    
    -- Only draw if visible
    if not self.properties.visible then
        debug_print("VERBOSE", "SpriteObject.draw: %s is not visible, skipping draw", self.id)
        return true
    end
    
    -- Get origin offset if available
    local ox, oy = self:get_origin_offset()
    
    -- Calculate absolute screen position
    -- The sprite's x/y properties are relative to its widget
    -- We need to find the widget and get its absolute position
    local absolute_x = self.properties.x * 2  -- Convert widget-relative to screen
    local absolute_y = self.properties.y * 2
    
    -- Try to find the widget and add its position
    local WidgetCache = require('scripts/net-games/widgets/cache')
    local widget = WidgetCache.get(self.widget_id, self.player_id)
    if widget then
        -- Widget's x/y are already in screen coordinates
        absolute_x = absolute_x + widget.x
        absolute_y = absolute_y + widget.y
        
        -- Also add any parent widget positions
        local parent = widget.parent
        while parent do
            absolute_x = absolute_x + parent.x
            absolute_y = absolute_y + parent.y
            parent = parent.parent
        end
    end
    
    local sprite_data = {
        id = self.id,  -- Use sprite object ID as the instance ID
        x = absolute_x,  -- Use absolute screen coordinates
        y = absolute_y,
        z = self.properties.z,
        sx = self.properties.sx,
        sy = self.properties.sy,
        ro = self.properties.ro,
        ox = self.properties.ox,  -- Use origin from animation file
        oy = self.properties.oy,  -- Use origin from animation file
        a = self.properties.a,
        r = self.properties.r,
        g = self.properties.g,
        b = self.properties.b,
        color_mode = self.properties.color_mode,
        anim_state = self.anim_state,
        opacity = self.properties.opacity
    }
    
    debug_print("VERBOSE", "SpriteObject.draw: %s at widget-relative (%d,%d) absolute (%d,%d) scale=%f,%f",
               self.id, self.properties.x, self.properties.y, absolute_x, absolute_y,
               self.properties.sx, self.properties.sy)
    
    -- Draw sprite instance using the template
    local success, result = pcall(Net.player_draw_sprite, self.player_id, self.template_id, sprite_data)
    
    if success then
        self.drawn = true
        self.drawn_properties = utils.table_deepcopy(self.properties)
        return true
    else
        debug_print("ERROR", "SpriteObject.draw: Failed to draw %s (template: %s) - %s", 
                   self.id, self.template_id, result)
        return false
    end
end

function SpriteObject:update(properties)
    if not self.allocated then
        debug_print("WARN", "SpriteObject.update: %s not allocated yet, drawing first", self.id)
        return self:draw()
    end
    
    -- Merge properties
    for key, value in pairs(properties) do
        if self.properties[key] ~= nil then
            self.properties[key] = value
        end
    end
    
    -- Only redraw if properties changed
    local needs_redraw = false
    if not self.drawn_properties then
        needs_redraw = true
    else
        for key, value in pairs(properties) do
            if self.drawn_properties[key] ~= value then
                needs_redraw = true
                break
            end
        end
    end
    
    if needs_redraw then
        return self:draw()
    end
    
    return true
end

function SpriteObject:set_position(x, y)
    return self:update({x = x, y = y})
end

function SpriteObject:set_scale(sx, sy)
    return self:update({sx = sx or self.properties.sx, sy = sy or sx or self.properties.sy})
end

function SpriteObject:set_visible(visible)
    return self:update({visible = visible})
end

function SpriteObject:set_opacity(opacity)
    return self:update({opacity = opacity, a = opacity})
end

function SpriteObject:set_color(r, g, b, a)
    return self:update({
        r = r or self.properties.r,
        g = g or self.properties.g,
        b = b or self.properties.b,
        a = a or self.properties.a,
        opacity = a or self.properties.opacity
    })
end

function SpriteObject:set_rotation(rotation)
    return self:update({ro = rotation})
end

function SpriteObject:set_z(z)
    return self:update({z = z})
end

function SpriteObject:remove()
    if self.allocated then
        debug_print("INFO", "SpriteObject.remove: Removing %s (template: %s)", self.id, self.template_id)
        
        -- Remove the sprite instance
        local success, result = pcall(Net.player_erase_sprite, self.player_id, self.id)
        if success then
            self.allocated = false
            self.drawn = false
            self.drawn_properties = nil
            debug_print("INFO", "SpriteObject.remove: %s removed successfully", self.id)
        else
            debug_print("ERROR", "SpriteObject.remove: Failed to remove %s - %s", self.id, result)
        end
        return success
    end
    return true
end

function SpriteObject:get_properties()
    return utils.table_deepcopy(self.properties)
end

function SpriteObject:get_absolute_position()
    -- Calculate absolute screen position
    local absolute_x = self.properties.x * 2
    local absolute_y = self.properties.y * 2
    
    -- Try to find the widget and add its position
    local WidgetCache = require('scripts/net-games/widgets/cache')
    local widget = WidgetCache.get(self.widget_id, self.player_id)
    if widget then
        absolute_x = absolute_x + widget.x
        absolute_y = absolute_y + widget.y
        
        -- Also add any parent widget positions
        local parent = widget.parent
        while parent do
            absolute_x = absolute_x + parent.x
            absolute_y = absolute_y + parent.y
            parent = parent.parent
        end
    end
    
    return absolute_x, absolute_y
end

-- ===========================================================
-- SPRITE OBJECT ANIMATION FUNCTIONS
-- ===========================================================

-- Animation methods
function SpriteObject:animate(properties, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "SpriteObject.animate: AnimationEngine not loaded")
        return nil
    end
    
    local start_properties = self:get_properties()
    local target_properties = {}
    
    -- Build target properties
    for key, value in pairs(properties) do
        if start_properties[key] ~= nil then
            target_properties[key] = value
        end
    end
    
    local anim_id = AnimationEngine.animate(start_properties, target_properties, duration, {
        easing = options.easing or "ease_in_out",
        on_update = function(values)
            self:update(values)
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

function SpriteObject:stop_animation(anim_id)
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

function SpriteObject:is_animating()
    return next(self.active_animations) ~= nil
end

-- Sprite-specific animation methods
function SpriteObject:slide_sprite(target_x, target_y, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "linear"
    
    return self:animate({x = target_x, y = target_y}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:scale_sprite(target_scale, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    return self:animate({sx = target_scale, sy = target_scale}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:rotate_sprite(target_rotation, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    return self:animate({ro = target_rotation}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:set_opacity_sprite(target_opacity, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    return self:animate({opacity = target_opacity, a = target_opacity}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:set_color_sprite(r, g, b, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.25
    easing = easing or "ease_in_out"
    
    return self:animate({r = r, g = g, b = b}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:stop_sprite_animation(anim_id)
    return self:stop_animation(anim_id)
end

function SpriteObject:has_sprite_animations()
    return self:is_animating()
end

return SpriteObject