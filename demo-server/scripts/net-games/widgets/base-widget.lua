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
    self.sx = utils.SCREEN_SCALE  -- Default to 2.0 for 240x160 -> 480x320 upscale
    self.sy = utils.SCREEN_SCALE  -- Default to 2.0
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
    
    -- Screen constraint tracking
    self._constrain_to_screen = false
    
    -- Layout cache for performance
    self._layout_cache = nil
    self._layout_cache_key = nil
    
    -- Register in cache
    WidgetCache.register(self)
    
    debug_print("INFO", "Widget created: id=%s, player=%s, type=%s, scale=%f", 
               self.id, self.player_id, self.widget_type, self.sx)
    
    return self
end

-- Enable/disable screen boundary constraints
function Widget:setScreenConstraints(enabled)
    self._constrain_to_screen = enabled ~= false
    self.state.dirty = true
    debug_print("DETAILED", "Widget.setScreenConstraints: %s = %s", 
               self.id, tostring(self._constrain_to_screen))
    return self
end

-- Apply screen boundary constraints
function Widget:applyScreenConstraints()
    if self._constrain_to_screen and self._calculated_size then
        local constrained_x, constrained_y = utils.constrain_to_screen(
            self.x, self.y, 
            self._calculated_size.width, 
            self._calculated_size.height
        )
        
        if self.x ~= constrained_x or self.y ~= constrained_y then
            debug_print("DETAILED", "Widget.applyScreenConstraints: %s constrained from (%g,%g) to (%g,%g)",
                       self.id, self.x, self.y, constrained_x, constrained_y)
            self:setPosition(constrained_x, constrained_y)
            return true
        end
    end
    return false
end

-- Modified setPosition with screen constraints
function Widget:setPosition(x, y)
    if not self then
        debug_print("ERROR", "Widget.setPosition: Invalid widget")
        return nil
    end
    
    self.x = x or self.x
    self.y = y or self.y
    
    -- Apply screen constraints if enabled
    if self._constrain_to_screen then
        self:applyScreenConstraints()
    end
    
    self.state.dirty = true
    
    debug_print("DETAILED", "Widget.setPosition: %s to (%g,%g) (screen space)", self.id, self.x, self.y)
    
    return self
end

-- Modified setSize to handle screen space properly
function Widget:setSize(width, height)
    if not self then
        debug_print("ERROR", "Widget.setSize: Invalid widget")
        return nil
    end
    
    self.width = width or self.width
    self.height = height or self.height
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Widget.setSize: %s = %gx%g (screen space)", self.id, self.width, self.height)
    
    return self
end

function Widget:setScale(sx, sy)
    self.sx = sx or self.sx
    self.sy = sy or self.sy
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Widget.setScale: %s = %f,%f", self.id, self.sx, self.sy)
    return self
end

function Widget:setRotation(rotation)
    self.ro = rotation or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Widget.setRotation: %s = %f", self.id, self.ro)
    return self
end

function Widget:setOpacity(opacity, recursive)
    self.opacity = math.max(0, math.min(255, opacity or 255))
    self.a = self.opacity
    self.state.dirty = true
    
    debug_print("DETAILED", "Widget.setOpacity: %s = %d", self.id, self.opacity)
    
    -- Recursively set opacity for child sprites
    if recursive then
        for _, sprite in pairs(self.sprite_objects) do
            sprite:set_opacity(self.opacity)
        end
        for _, child_widget in pairs(self._child_widgets) do
            child_widget:setOpacity(self.opacity, recursive)
        end
    end
    
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

function Widget:setVisible(visible)
    self.state.visible = visible ~= false
    self.state.dirty = true
    
    debug_print("DETAILED", "Widget.setVisible: %s = %s", self.id, tostring(self.state.visible))
    return self
end

function Widget:setEnabled(enabled)
    self.state.enabled = enabled ~= false
    
    debug_print("DETAILED", "Widget.setEnabled: %s = %s", self.id, tostring(self.state.enabled))
    return self
end

function Widget:setPadding(top, right, bottom, left)
    self.padding = {
        top = top or self.padding.top,
        right = right or (bottom and top or self.padding.right),
        bottom = bottom or top or self.padding.bottom,
        left = left or (right and top or self.padding.left)
    }
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("VERBOSE", "Widget.setPadding: %s = top=%d, right=%d, bottom=%d, left=%d",
               self.id, self.padding.top, self.padding.right, self.padding.bottom, self.padding.left)
    
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

-- Get absolute screen position (in scaled coordinates)
function Widget:getAbsolutePosition()
    local abs_x = self.x
    local abs_y = self.y
    
    -- Add parent positions
    local parent = self.parent
    while parent do
        abs_x = abs_x + parent.x
        abs_y = abs_y + parent.y
        parent = parent.parent
    end
    
    -- Scale to screen coordinates
    local scaled_x = utils.normalize_x(abs_x)
    local scaled_y = utils.normalize_y(abs_y)
    
    debug_print("VERBOSE", "Widget.getAbsolutePosition: %s = screen(%g,%g) -> scaled(%g,%g)",
               self.id, abs_x, abs_y, scaled_x, scaled_y)
    
    return scaled_x, scaled_y
end

-- Get scaled dimensions for this widget
function Widget:getScaledDimensions()
    local width, height = self:getCalculatedSize()
    local scaled_width = utils.normalize_x(width)
    local scaled_height = utils.normalize_y(height)
    
    debug_print("VERBOSE", "Widget.getScaledDimensions: %s = %gx%g -> %gx%g",
               self.id, width, height, scaled_width, scaled_height)
    
    return scaled_width, scaled_height
end

-- Check if widget is within screen bounds
function Widget:isWithinScreen()
    local scaled_x, scaled_y = self:getAbsolutePosition()
    local scaled_width, scaled_height = self:getScaledDimensions()
    
    return utils.is_within_screen(self.x, self.y, scaled_width / utils.SCREEN_SCALE, scaled_height / utils.SCREEN_SCALE)
end

-- Center widget on screen
function Widget:centerOnScreen()
    local width, height = self:getCalculatedSize()
    local center_x = (utils.SCREEN_WIDTH - width) / 2
    local center_y = (utils.SCREEN_HEIGHT - height) / 2
    
    debug_print("INFO", "Widget.centerOnScreen: %s to (%g,%g)", self.id, center_x, center_y)
    
    return self:setPosition(center_x, center_y)
end

-- Create and manage sprite objects with proper default properties
function Widget:create_sprite(sprite_id, texture_path, anim_path, anim_state, layout_width, layout_height, properties)
    -- Generate unique sprite ID if not provided
    local unique_sprite_id = sprite_id or utils.generate_unique_id("sprite")
    
    if self.sprite_objects[unique_sprite_id] then
        debug_print("WARN", "Widget.create_sprite: Sprite %s already exists in widget %s", 
                   unique_sprite_id, self.id)
        return self.sprite_objects[unique_sprite_id]
    end
    
    local sprite = SpriteObject.new(unique_sprite_id, self.id, self.player_id, 
                                   texture_path, anim_path, anim_state, layout_width, layout_height)
    
    self.sprite_objects[unique_sprite_id] = sprite
    
    -- Set default sprite properties based on widget's current state
    local default_properties = {
        -- Position and scale from widget (relative to widget)
        x = 0,  -- Will be positioned by layout
        y = 0,  -- Will be positioned by layout
        sx = self.sx or utils.SCREEN_SCALE,  -- Inherit widget scale
        sy = self.sy or utils.SCREEN_SCALE,
        ro = self.ro or 0,  -- No rotation by default
        ox = self.ox or 0,  -- Origin at top-left
        oy = self.oy or 0,
        
        -- Color and opacity from widget
        a = self.a or 255,
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        color_mode = self.color_mode or 0,  -- Normal color mode
        opacity = self.opacity or 255,
        
        -- Animation state
        animation_state = anim_state or "",
        
        -- Visibility
        visible = self.state.visible
    }
    
    -- Merge with provided properties (override defaults)
    if properties then
        for key, value in pairs(properties) do
            if default_properties[key] ~= nil then
                default_properties[key] = value
            end
        end
    end
    
    -- Apply all properties to sprite at once
    sprite:update(default_properties)
    
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
        id = unique_sprite_id,
        properties = default_properties  -- Store for reference
    })
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.create_sprite: %s added to widget %s with properties: scale=%f,%f, opacity=%d, color=(%d,%d,%d,%d)", 
               unique_sprite_id, self.id, default_properties.sx, default_properties.sy, 
               default_properties.opacity, default_properties.r, default_properties.g, 
               default_properties.b, default_properties.a)
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

-- Helper function to set sprite properties with all available options
function Widget:set_sprite_full_properties(sprite_id, properties)
    local sprite = self.sprite_objects[sprite_id]
    if sprite then
        debug_print("DETAILED", "Widget.set_sprite_full_properties: %s in widget %s", 
                   sprite_id, self.id)
        
        -- Define all possible sprite properties with defaults
        local full_properties = {
            x = properties.x or sprite.properties.x,
            y = properties.y or sprite.properties.y,
            sx = properties.sx or sprite.properties.sx,
            sy = properties.sy or sprite.properties.sy,
            ro = properties.ro or sprite.properties.ro or 0,
            ox = properties.ox or sprite.properties.ox or 0,
            oy = properties.oy or sprite.properties.oy or 0,
            a = properties.a or sprite.properties.a or 255,
            r = properties.r or sprite.properties.r or 255,
            g = properties.g or sprite.properties.g or 255,
            b = properties.b or sprite.properties.b or 255,
            color_mode = properties.color_mode or sprite.properties.color_mode or 0,
            animation_state = properties.animation_state or sprite.properties.animation_state or "",
            opacity = properties.opacity or sprite.properties.opacity or 255,
            visible = properties.visible ~= nil and properties.visible or sprite.properties.visible
        }
        
        return sprite:update(full_properties)
    else
        debug_print("WARN", "Widget.set_sprite_full_properties: Sprite %s not found in widget %s", 
                   sprite_id, self.id)
        return false
    end
end

-- ===========================================================
-- REORDERING METHODS FOR SPRITES AND CHILDREN
-- ===========================================================

-- Move a child (sprite or widget) to a new position in the children array
function Widget:move_child_to_index(child_id, new_index)
    if new_index < 1 or new_index > #self.children then
        debug_print("ERROR", "Widget.move_child_to_index: Invalid index %d for child %s", 
                   new_index, child_id)
        return false
    end
    
    -- Find the child in the current children array
    local current_index = nil
    local child_data = nil
    
    for i, child in ipairs(self.children) do
        if child.sprite_id == child_id or child.id == child_id or 
           (child.widget and child.widget.id == child_id) then
            current_index = i
            child_data = child
            break
        end
    end
    
    if not current_index then
        debug_print("ERROR", "Widget.move_child_to_index: Child %s not found", child_id)
        return false
    end
    
    -- If already at the target index, do nothing
    if current_index == new_index then
        debug_print("DETAILED", "Widget.move_child_to_index: Child %s already at index %d", 
                   child_id, new_index)
        return true
    end
    
    -- Remove from current position
    table.remove(self.children, current_index)
    
    -- Adjust target index if we removed before it
    if current_index < new_index then
        new_index = new_index - 1
    end
    
    -- Insert at new position
    table.insert(self.children, new_index, child_data)
    
    -- Mark for layout update
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.move_child_to_index: Moved child %s from index %d to %d", 
               child_id, current_index, new_index)
    return true
end

-- Swap positions of two children
function Widget:swap_children(child1_id, child2_id)
    local index1, index2 = nil, nil
    
    -- Find indices of both children
    for i, child in ipairs(self.children) do
        if child.sprite_id == child1_id or child.id == child1_id or 
           (child.widget and child.widget.id == child1_id) then
            index1 = i
        end
        if child.sprite_id == child2_id or child.id == child2_id or 
           (child.widget and child.widget.id == child2_id) then
            index2 = i
        end
    end
    
    if not index1 then
        debug_print("ERROR", "Widget.swap_children: Child1 %s not found", child1_id)
        return false
    end
    
    if not index2 then
        debug_print("ERROR", "Widget.swap_children: Child2 %s not found", child2_id)
        return false
    end
    
    -- Swap in children array
    self.children[index1], self.children[index2] = self.children[index2], self.children[index1]
    
    -- Mark for layout update
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.swap_children: Swapped %s (index %d) with %s (index %d)", 
               child1_id, index1, child2_id, index2)
    return true
end

-- Bring child to front (last in children array)
function Widget:bring_to_front(child_id)
    return self:move_child_to_index(child_id, #self.children)
end

-- Send child to back (first in children array)
function Widget:send_to_back(child_id)
    return self:move_child_to_index(child_id, 1)
end

-- Get current index of a child
function Widget:get_child_index(child_id)
    for i, child in ipairs(self.children) do
        if child.sprite_id == child_id or child.id == child_id or 
           (child.widget and child.widget.id == child_id) then
            return i
        end
    end
    return nil
end

-- Reorder children by a list of IDs
function Widget:reorder_children(ordered_ids)
    -- Create a lookup table for child data
    local child_data = {}
    for i, child in ipairs(self.children) do
        local id = child.sprite_id or child.id or (child.widget and child.widget.id)
        if id then
            child_data[id] = child
        end
    end
    
    -- Rebuild children array in the specified order
    local new_children = {}
    for _, id in ipairs(ordered_ids) do
        local data = child_data[id]
        if data then
            table.insert(new_children, data)
            child_data[id] = nil  -- Remove to track which were used
        else
            debug_print("WARN", "Widget.reorder_children: Child %s not found in current children", id)
        end
    end
    
    -- Add any remaining children (in their original order)
    for _, child in ipairs(self.children) do
        local id = child.sprite_id or child.id or (child.widget and child.widget.id)
        if child_data[id] then  -- Still in lookup table, wasn't in ordered_ids
            table.insert(new_children, child)
        end
    end
    
    -- Replace children array
    self.children = new_children
    
    -- Mark for layout update
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.reorder_children: Reordered %d children", #ordered_ids)
    return true
end

-- Sort children using a comparison function
function Widget:sort_children(compare_func)
    table.sort(self.children, compare_func)
    
    -- Mark for layout update
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.sort_children: Sorted %d children", #self.children)
    return true
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
        
        debug_print("INFO", "Widget.set_sprite_layout_dimensions: %s = %gx%g", 
                   sprite_id, width, height)
        return true
    else
        debug_print("WARN", "Widget.set_sprite_layout_dimensions: Sprite %s not found", sprite_id)
        return false
    end
end

-- Swap two sprites and animate their positions
function Widget:swap_and_animate_sprites(sprite1_id, sprite2_id, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.swap_and_animate_sprites: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.swap_and_animate_sprites: Swapping %s and %s in %s", 
               sprite1_id, sprite2_id, self.id)
    
    -- Get the sprite objects
    local sprite1 = self.sprite_objects[sprite1_id]
    local sprite2 = self.sprite_objects[sprite2_id]
    
    if not sprite1 or not sprite2 then
        debug_print("ERROR", "  One or both sprites not found: %s, %s", sprite1_id, sprite2_id)
        if user_on_complete then
            user_on_complete({success = false, reason = "sprites_not_found"}, false)
        end
        return nil
    end
    
    -- Get current positions of both sprites (relative to widget)
    local pos1 = {x = sprite1.properties.x, y = sprite1.properties.y}
    local pos2 = {x = sprite2.properties.x, y = sprite2.properties.y}
    
    -- Mark sprites as widget-animated
    sprite1:set_widget_animated(true, {type = "swap"})
    sprite2:set_widget_animated(true, {type = "swap"})
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.swap_and_animate_sprites: AnimationEngine not available")
        
        -- Just swap positions without animation
        sprite1:set_position(pos2.x, pos2.y)
        sprite2:set_position(pos1.x, pos1.y)
        
        -- Unmark sprites
        sprite1:set_widget_animated(false)
        sprite2:set_widget_animated(false)
        
        if user_on_complete then
            user_on_complete({sprite1 = sprite1_id, sprite2 = sprite2_id, success = true}, false)
        end
        return nil
    end
    
    local anim_id1, anim_id2
    
    -- Animate sprite1 to sprite2's position
    anim_id1 = sprite1:slide_sprite(pos2.x, pos2.y, duration, easing)
    
    -- Animate sprite2 to sprite1's position
    anim_id2 = sprite2:slide_sprite(pos1.x, pos1.y, duration, easing)
    
    -- Track both animations
    if anim_id1 then
        self.active_animations[anim_id1] = true
    end
    if anim_id2 then
        self.active_animations[anim_id2] = true
    end
    
    -- Set up completion handler
    local animations_completed = 0
    local function check_completion()
        animations_completed = animations_completed + 1
        if animations_completed >= 2 then
            -- Unmark sprites
            sprite1:set_widget_animated(false)
            sprite2:set_widget_animated(false)
            
            -- Clean up animation tracking
            if anim_id1 then
                self.active_animations[anim_id1] = nil
            end
            if anim_id2 then
                self.active_animations[anim_id2] = nil
            end
            
            if user_on_complete then
                user_on_complete({sprite1 = sprite1_id, sprite2 = sprite2_id, success = true}, false)
            end
            
            debug_print("INFO", "Widget.swap_and_animate_sprites: Swap completed for %s and %s", 
                       sprite1_id, sprite2_id)
        end
    end
    
    -- If animations were created, set up their completion handlers
    if anim_id1 then
        AnimationEngine.set_animation_callback(anim_id1, "on_complete", check_completion)
    else
        check_completion()
    end
    
    if anim_id2 then
        AnimationEngine.set_animation_callback(anim_id2, "on_complete", check_completion)
    else
        check_completion()
    end
    
    return {anim1 = anim_id1, anim2 = anim_id2}
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

function Widget:addChild(child)
    if child then
        child.parent = self
        
        if child.type == "sprite" and child.texture_path then
            -- Create sprite object with properties
            local unique_sprite_id = child.sprite_id or utils.generate_unique_id("sprite")
            
            -- Prepare properties from child definition
            local sprite_properties = {
                x = child.x or 0,
                y = child.y or 0,
                sx = child.scale or self.sx or utils.SCREEN_SCALE,
                sy = child.scale or self.sy or utils.SCREEN_SCALE,
                ro = child.ro or 0,
                ox = child.ox or 0,
                oy = child.oy or 0,
                a = child.a or self.a or 255,
                r = child.r or self.r or 255,
                g = child.g or self.g or 255,
                b = child.b or self.b or 255,
                color_mode = child.color_mode or 0,
                animation_state = child.anim_state,
                opacity = child.opacity or self.opacity or 255,
                visible = child.visible ~= nil and child.visible or self.state.visible
            }
            
            local sprite = self:create_sprite(
                unique_sprite_id,
                child.texture_path,
                child.anim_path,
                child.anim_state,
                child.layout_width,
                child.layout_height,
                sprite_properties
            )
            
            debug_print("DETAILED", "Widget.addChild: Added sprite %s to widget %s with properties %s", 
                       sprite.id, self.id, utils.table_to_string(sprite_properties))
        elseif child.widget then
            -- IMPORTANT: Add widget child to children array for layout
            table.insert(self.children, child)
            
            -- Add to child widgets
            self._child_widgets[child.widget.id] = child.widget
            child.widget.parent = self
            
            debug_print("DETAILED", "Widget.addChild: Added child widget %s to widget %s",
                       child.widget.id, self.id)
        elseif child.id then
            -- Generic child with id
            table.insert(self.children, child)
            debug_print("DETAILED", "Widget.addChild: Added generic child with id=%s to widget %s",
                       child.id, self.id)
        else
            debug_print("ERROR", "Widget.addChild: Invalid child provided to %s", self.id)
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
                self._child_widgets[child.widget.id] = nil
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

function Widget:addWidget(widget)
    if widget and widget.id then
        self._child_widgets[widget.id] = widget
        widget.parent = self
        
        -- Add to children list for layout
        table.insert(self.children, {
            type = "widget",
            widget = widget,
            id = widget.id
        })
        
        self.state.dirty = true
        self.state.needs_layout = true
        
        debug_print("INFO", "Widget.addWidget: %s added to widget %s", widget.id, self.id)
        return true
    end
    
    debug_print("ERROR", "Widget.addWidget: Invalid widget")
    return false
end

-- Internal layout calculation with caching
function Widget:_doCalculateLayout(available_width, available_height)
    debug_print("VERBOSE", "Widget._doCalculateLayout (base): %s available=%gx%g", 
               self.id, available_width, available_height)
    
    -- Base implementation returns empty layout
    return 0, 0, {}
end

-- Calculate layout with caching
function Widget:calculateLayout(available_width, available_height)
    -- Create cache key
    local cache_key = string.format("%d_%d_%d_%d_%d_%d_%d", 
        available_width, available_height,
        #self.children,
        self.width, self.height,
        self.padding.left + self.padding.right,
        self.padding.top + self.padding.bottom)
    
    -- Check cache
    if self._layout_cache_key == cache_key and self._layout_cache then
        debug_print("VERBOSE", "Widget.calculateLayout: Using cached layout for %s", self.id)
        return unpack(self._layout_cache)
    end
    
    -- Calculate layout (subclass implementation)
    local width, height, positioned_children = self:_doCalculateLayout(available_width, available_height)
    
    -- Cache results
    self._layout_cache = {width, height, positioned_children}
    self._layout_cache_key = cache_key
    
    return width, height, positioned_children
end

function Widget:slide_widget(target_x, target_y, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.slide_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "linear"
    
    debug_print("INFO", "Widget.slide_widget: %s to screen(%g,%g) in %f seconds", 
               self.id, target_x, target_y, duration)
    
    -- Get starting position
    local start_x = self.x
    local start_y = self.y
    local delta_x = target_x - start_x
    local delta_y = target_y - start_y
    
    -- Store starting positions of all sprites (relative to widget)
    local sprite_start_positions = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_positions[sprite_id] = {
            x = props.x,
            y = props.y
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "position"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting positions of child widgets
    local child_widget_start_positions = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_positions[child_widget.id] = {
            x = child_widget.x,
            y = child_widget.y
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "position"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.slide_widget: AnimationEngine not available")
        self:setPosition(target_x, target_y)
        
        -- UNMARK SPRITES HERE (on_complete for fallback case)
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({x = target_x, y = target_y}, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    local anim_id
    -- Create a single animation that updates both widget and sprites
    anim_id = AnimationEngine.animate(
        {t = 0},  -- t goes from 0 to 1
        {t = 1},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local t = values.t
                local current_x = start_x + delta_x * t
                local current_y = start_y + delta_y * t
                
                -- Update widget position ONLY (don't trigger layout)
                self.x = current_x
                self.y = current_y
                
                -- Update ALL sprites to match widget position
                -- Each sprite gets: widget_position + sprite_original_relative_position
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_pos = sprite_start_positions[sprite_id]
                    if start_pos then
                        -- Calculate sprite's absolute position
                        local sprite_x = current_x + start_pos.x
                        local sprite_y = current_y + start_pos.y
                        
                        -- Set sprite position directly (no animation on sprite object)
                        sprite.properties.x = sprite_x
                        sprite.properties.y = sprite_y
                        
                        -- Force redraw
                        sprite:draw()
                        debug_print("DETAILED", "  Updated sprite %s to (%g,%g)", 
                                   sprite_id, sprite_x, sprite_y)
                    end
                end
                
                -- Update child widgets to maintain their relative positions
                for _, child_widget in pairs(self._child_widgets) do
                    local start_pos = child_widget_start_positions[child_widget.id]
                    if start_pos then
                        -- Child maintains same relative position to parent
                        child_widget.x = start_pos.x
                        child_widget.y = start_pos.y
                        
                        -- Update child's layout (which will update its sprites)
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "  Updated child widget %s position", 
                                   child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Apply screen constraints after animation
                if self._constrain_to_screen then
                    self:applyScreenConstraints()
                end
                
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete({x = target_x, y = target_y}, interrupted)
                end
                
                debug_print("INFO", "Widget.slide_widget completed: %s at (%g,%g)", 
                           self.id, target_x, target_y)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.slide_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

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
    
    debug_print("INFO", "Widget.move_widget: %s by (%g,%g) to (%g,%g)", 
               self.id, offset_x, offset_y, target_x, target_y)
    
    return self:slide_widget(target_x, target_y, duration, easing, on_complete)
end

function Widget:scale_widget(target_scale, duration, easing, user_on_complete)
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
    
    -- Store starting scales of all sprites
    local sprite_start_scales = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_scales[sprite_id] = {
            sx = props.sx,
            sy = props.sy
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "scale"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting scales of child widgets
    local child_widget_start_scales = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_scales[child_widget.id] = {
            sx = child_widget.sx,
            sy = child_widget.sy
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "scale"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.scale_widget: AnimationEngine not available")
        self:setScale(target_scale, target_scale)
        
        -- Update all sprites to match widget scale
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:update({
                sx = target_scale,
                sy = target_scale
            })
        end
        
        -- UNMARK SPRITES HERE (on_complete for fallback case)
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({sx = target_scale, sy = target_scale}, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "scale"
    local anim_id
    
    anim_id = AnimationEngine.animate(
        {sx = current_scale, sy = current_scale},
        {sx = target_scale, sy = target_scale},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local current_sx = values.sx
                local current_sy = values.sy
                
                -- Update widget scale ONLY (don't trigger layout)
                self.sx = current_sx
                self.sy = current_sy
                
                -- Update ALL sprites to match widget scale
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    -- Set sprite scale directly
                    sprite.properties.sx = current_sx
                    sprite.properties.sy = current_sy
                    
                    -- Force redraw
                    sprite:draw()
                    debug_print("DETAILED", "  Updated sprite %s scale to %f,%f", 
                               sprite_id, current_sx, current_sy)
                end
                
                -- Update child widgets to maintain their relative scales
                for _, child_widget in pairs(self._child_widgets) do
                    local start_scale = child_widget_start_scales[child_widget.id]
                    if start_scale then
                        -- Child maintains same relative scale to parent
                        child_widget.sx = start_scale.sx
                        child_widget.sy = start_scale.sy
                        
                        -- Update child's layout (which will update its sprites)
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "  Updated child widget %s scale", 
                                   child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
                
                debug_print("INFO", "Widget.scale_widget completed: %s scale (%f,%f)", 
                           self.id, values.sx, values.sy)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.scale_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

function Widget:rotate_widget(target_rotation, duration, easing, user_on_complete)
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
    
    -- Store starting rotations of all sprites
    local sprite_start_rotations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_rotations[sprite_id] = {
            ro = props.ro or 0
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "rotation"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting rotations of child widgets
    local child_widget_start_rotations = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_rotations[child_widget.id] = {
            ro = child_widget.ro
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "rotation"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.rotate_widget: AnimationEngine not available")
        self:setRotation(target_rotation)
        
        -- Update all sprites to match widget rotation
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:update({
                ro = target_rotation
            })
        end
        
        -- UNMARK SPRITES HERE (on_complete for fallback case)
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({ro = target_rotation}, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "rotation"
    local anim_id
    
    anim_id = AnimationEngine.animate(
        {ro = current_rotation},
        {ro = target_rotation},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local current_rotation = values.ro
                
                -- Update widget rotation ONLY (don't trigger layout)
                self.ro = current_rotation
                
                -- Update ALL sprites to match widget rotation
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    -- Set sprite rotation directly
                    sprite.properties.ro = current_rotation
                    
                    -- Force redraw
                    sprite:draw()
                    debug_print("DETAILED", "  Updated sprite %s rotation to %f", 
                               sprite_id, current_rotation)
                end
                
                -- Update child widgets to maintain their relative rotations
                for _, child_widget in pairs(self._child_widgets) do
                    local start_rotation = child_widget_start_rotations[child_widget.id]
                    if start_rotation then
                        -- Child maintains same relative rotation to parent
                        child_widget.ro = start_rotation.ro
                        
                        -- Update child's layout (which will update its sprites)
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "  Updated child widget %s rotation", 
                                   child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
                
                debug_print("INFO", "Widget.rotate_widget completed: %s rotation %f", 
                           self.id, values.ro)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.rotate_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

function Widget:set_opacity_widget(target_opacity, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_opacity_widget: Invalid widget")
        return nil
    end
    
    debug_print("INFO", "Widget.set_opacity_widget: %s to opacity %d", 
               self.id, target_opacity)
    
    return self:animate_opacity(target_opacity, duration, {
        easing = easing,
        on_complete = user_on_complete
    })
end

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
        local available_width = self.width > 0 and self.width or utils.SCREEN_WIDTH
        local available_height = self.height > 0 and self.height or utils.SCREEN_HEIGHT
        
        debug_print("DETAILED", "  Available space: %gx%g (screen space)", available_width, available_height)
        
        local layout_width, layout_height, positioned_children = 
            self:calculateLayout(available_width, available_height)
        
        -- Update calculated size
        self._calculated_size = {
            width = layout_width,
            height = layout_height
        }
        
        debug_print("DETAILED", "  Calculated layout: %gx%g (screen space), children positioned: %d",
                   layout_width, layout_height, #positioned_children)
        
        -- Apply screen constraints after layout calculation
        if self._constrain_to_screen then
            self:applyScreenConstraints()
        end
        
        -- Position children (sprites and widgets)
        for i, child in ipairs(positioned_children) do
            -- Calculate widget-relative position (relative to this widget's top-left in screen space)
            local child_widget_x = child.x + self.padding.left + self.margin.left
            local child_widget_y = child.y + self.padding.top + self.margin.top
            
            debug_print("DETAILED", "  Child %d: type=%s, widget-relative=(%g,%g), layout=(%g,%g), abs_parent=(%g,%g), origin=(%g,%g)",
                       i, child.sprite_id and "sprite" or "widget", 
                       child_widget_x, child_widget_y, child.x, child.y,
                       self.x, self.y, child.ox or 0, child.oy or 0)
            
            if child.sprite_id then
                -- Update sprite position (using widget-relative coordinates in screen space)
                local sprite = self.sprite_objects[child.sprite_id]
                if sprite then
                    -- Check if sprite is being animated by widget
                    if not sprite:is_widget_animated() then
                        -- IMPORTANT: The positioned_children table now stores TOP-LEFT positions
                        -- We need to convert this to ORIGIN position for the sprite
                        local origin_x = child_widget_x + (child.ox or 0)
                        local origin_y = child_widget_y + (child.oy or 0)
                        
                        -- Set sprite's origin position
                        sprite:set_position(origin_x, origin_y)
                        debug_print("DETAILED", "    Sprite %s: top-left=(%g,%g), origin=(%g,%g), origin_offset=(%g,%g)", 
                                   child.sprite_id, child_widget_x, child_widget_y,
                                   origin_x, origin_y, child.ox or 0, child.oy or 0)
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
                debug_print("DETAILED", "    Updating child widget: %s, parent_abs=(%g,%g), child_rel=(%g,%g), child_abs=(%g,%g)", 
                           child.widget.id, self.x, self.y, child_widget_x, child_widget_y, 
                           self.x + child_widget_x, self.y + child_widget_y)
                
                -- Check if child widget is being animated
                if not child.widget._layout_animation_active then
                    -- Set child widget position relative to parent widget's position (screen space)
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
        debug_print("INFO", "Widget layout updated: %s at position (%g,%g) screen space", self.id, self.x, self.y)
        return true
    else
        debug_print("VERBOSE", "  Widget not dirty, skipping update")
        return false
    end
end

-- Draw all sprites in widget
function Widget:draw(force)
    debug_print("VERBOSE", "Widget.draw: %s with %d sprites at position (%g,%g)", 
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
    debug_print("VERBOSE", "Widget.update: %s with dt=%f, position=(%g,%g)", self.id, dt, self.x, self.y)
    
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
    debug_print("VERBOSE", "Widget.getCalculatedSize: %s = %gx%g", 
               self.id, self._calculated_size.width, self._calculated_size.height)
    
    return self._calculated_size.width, self._calculated_size.height
end

function Widget:animate_position(target_x, target_y, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    -- Mark sprites as widget-animated
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "position"})
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.animate_position: AnimationEngine not available")
        self:setPosition(target_x, target_y)
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if options.on_complete then
            options.on_complete({x = target_x, y = target_y}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    
    local anim_id = nil
    anim_id = AnimationEngine.animate(
        {x = self.x, y = self.y},
        {x = target_x, y = target_y},
        duration,
        {
            easing = options.easing or "ease_in_out",
            on_update = function(values)
                self.x = values.x
                self.y = values.y
                
                -- Update all sprites
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_position(values.x, values.y)
                end
                
                if options.on_update then
                    options.on_update(values)
                end
            end,
            on_complete = function(values, interrupted)
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Unmark all sprites
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
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
    if not self then
        debug_print("ERROR", "Widget.animate_properties: Invalid widget")
        return nil
    end
    
    options = options or {}
    duration = duration or 0.3
    
    debug_print("INFO", "Widget.animate_properties: %s animating properties: %s", 
               self.id, utils.table_to_string(properties))
    
    -- Store starting states of all sprites
    local sprite_start_states = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_states[sprite_id] = {
            x = props.x,
            y = props.y,
            sx = props.sx,
            sy = props.sy,
            ro = props.ro or 0,
            ox = props.ox or 0,
            oy = props.oy or 0,
            a = props.a or 255,
            r = props.r or 255,
            g = props.g or 255,
            b = props.b or 255,
            color_mode = props.color_mode or 0,
            animation_state = props.animation_state or "",
            opacity = props.opacity or 255
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "properties"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting states of child widgets
    local child_widget_start_states = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_states[child_widget.id] = {
            x = child_widget.x,
            y = child_widget.y,
            sx = child_widget.sx,
            sy = child_widget.sy,
            ro = child_widget.ro,
            opacity = child_widget.opacity,
            r = child_widget.r,
            g = child_widget.g,
            b = child_widget.b,
            a = child_widget.a
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "properties"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.animate_properties: AnimationEngine not available")
        
        -- Apply properties directly
        if properties.x or properties.y then
            self:setPosition(properties.x or self.x, properties.y or self.y)
        end
        if properties.sx or properties.sy then
            self:setScale(properties.sx or self.sx, properties.sy or self.sy)
        end
        if properties.ro then
            self:setRotation(properties.ro)
        end
        if properties.opacity then
            self:setOpacity(properties.opacity)
        end
        if properties.r or properties.g or properties.b or properties.a then
            self:setColor(properties.r or self.r, properties.g or self.g, 
                         properties.b or self.b, properties.a or self.a)
        end
        
        -- Update all sprites with final properties
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local update_props = {}
            
            if properties.x or properties.y then
                update_props.x = self.x
                update_props.y = self.y
            end
            if properties.sx or properties.sy then
                update_props.sx = self.sx
                update_props.sy = self.sy
            end
            if properties.ro then
                update_props.ro = self.ro
            end
            if properties.opacity then
                update_props.opacity = self.opacity
            end
            if properties.r or properties.g or properties.b or properties.a then
                update_props.r = self.r
                update_props.g = self.g
                update_props.b = self.b
                update_props.a = self.a
            end
            
            if next(update_props) ~= nil then
                sprite:update(update_props)
            end
        end
        
        -- UNMARK SPRITES
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if options.on_complete then
            options.on_complete(properties, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "properties"
    
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
    
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(start_properties, target_properties, duration, {
        easing = options.easing or "ease_in_out",
        on_update = function(values)
            -- Update widget properties
            if values.x ~= nil then self.x = values.x end
            if values.y ~= nil then self.y = values.y end
            if values.sx ~= nil then self.sx = values.sx end
            if values.sy ~= nil then self.sy = values.sy end
            if values.ro ~= nil then self.ro = values.ro end
            if values.opacity ~= nil then self.opacity = values.opacity end
            if values.r ~= nil then self.r = values.r end
            if values.g ~= nil then self.g = values.g end
            if values.b ~= nil then self.b = values.b end
            if values.a ~= nil then self.a = values.a end
            
            -- Update ALL sprites to match widget properties
            for sprite_id, sprite in pairs(self.sprite_objects) do
                local start_state = sprite_start_states[sprite_id]
                if start_state then
                    -- Calculate sprite's absolute properties based on relative position
                    local sprite_x = values.x + (start_state.x - start_properties.x)
                    local sprite_y = values.y + (start_state.y - start_properties.y)
                    
                    -- Prepare update properties for sprite
                    local sprite_update = {
                        x = sprite_x,
                        y = sprite_y,
                        sx = values.sx or start_state.sx,
                        sy = values.sy or start_state.sy,
                        ro = values.ro or start_state.ro,
                        opacity = values.opacity or start_state.opacity,
                        r = values.r or start_state.r,
                        g = values.g or start_state.g,
                        b = values.b or start_state.b,
                        a = values.a or start_state.a
                    }
                    
                    -- Apply update to sprite
                    sprite:update(sprite_update)
                    debug_print("DETAILED", "  Updated sprite %s properties", sprite_id)
                end
            end
            
            -- Update child widgets to maintain their relative states
            for _, child_widget in pairs(self._child_widgets) do
                local start_state = child_widget_start_states[child_widget.id]
                if start_state then
                    -- Child maintains same relative state to parent
                    child_widget.x = start_state.x
                    child_widget.y = start_state.y
                    child_widget.sx = start_state.sx
                    child_widget.sy = start_state.sy
                    child_widget.ro = start_state.ro
                    child_widget.opacity = start_state.opacity
                    child_widget.r = start_state.r
                    child_widget.g = start_state.g
                    child_widget.b = start_state.b
                    child_widget.a = start_state.a
                    
                    -- Update child's layout
                    child_widget:updateLayout(false)
                end
            end
            
            if options.on_update then
                options.on_update(values)
            end
        end,
        on_complete = function(values, interrupted)
            -- Apply screen constraints after animation
            if self._constrain_to_screen then
                self:applyScreenConstraints()
            end
            
            -- Clear widget animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- UNMARK ALL SPRITES HERE
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
                debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
            end
            
            -- Force final layout update
            self:updateLayout(true)
            
            self.active_animations[anim_id] = nil
            if options.on_complete then
                options.on_complete(values, interrupted)
            end
            
            debug_print("INFO", "Widget.animate_properties completed: %s", self.id)
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

function Widget:animate_opacity(target_opacity, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    -- Mark sprites as widget-animated
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "opacity"})
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.animate_opacity: AnimationEngine not available")
        self:setOpacity(target_opacity, options.recursive or false)
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if options.on_complete then
            options.on_complete({opacity = target_opacity}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "opacity"
    local anim_id = nil
    anim_id = AnimationEngine.animate(
        {opacity = self.opacity},
        {opacity = target_opacity},
        duration,
        {
            easing = options.easing or "ease_in_out",
            on_update = function(values)
                self.opacity = values.opacity
                
                -- Update all sprites' opacity
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_opacity(values.opacity)
                end
                
                if options.on_update then
                    options.on_update(values)
                end
            end,
            on_complete = function(values, interrupted)
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Unmark all sprites
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
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

-- ===========================================================
-- NEW ANIMATION METHODS FOLLOWING slide_widget PATTERN
-- ===========================================================

-- Complex transform animation combining multiple properties - Following slide_widget pattern
function Widget:transform_widget(properties, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.transform_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.transform_widget: %s with properties", self.id)
    
    -- Store starting states of all sprites
    local sprite_start_states = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_states[sprite_id] = {
            x = props.x,
            y = props.y,
            sx = props.sx,
            sy = props.sy,
            ro = props.ro or 0,
            opacity = props.opacity or 255,
            r = props.r or 255,
            g = props.g or 255,
            b = props.b or 255,
            a = props.a or 255
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "transform"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting states of child widgets
    local child_widget_start_states = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_states[child_widget.id] = {
            x = child_widget.x,
            y = child_widget.y,
            sx = child_widget.sx,
            sy = child_widget.sy,
            ro = child_widget.ro,
            opacity = child_widget.opacity,
            r = child_widget.r,
            g = child_widget.g,
            b = child_widget.b,
            a = child_widget.a
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "transform"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.transform_widget: AnimationEngine not available")
        
        -- Apply properties directly
        if properties.x or properties.y then self:setPosition(properties.x or self.x, properties.y or self.y) end
        if properties.sx or properties.sy then self:setScale(properties.sx or self.sx, properties.sy or self.sy) end
        if properties.ro then self:setRotation(properties.ro) end
        if properties.opacity then self:setOpacity(properties.opacity) end
        if properties.r or properties.g or properties.b or properties.a then 
            self:setColor(properties.r or self.r, properties.g or self.g, 
                         properties.b or self.b, properties.a or self.a) 
        end
        
        -- UNMARK SPRITES HERE
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete(properties, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
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
    
    local anim_id
    
    anim_id = AnimationEngine.animate(
        start_properties,
        target_properties,
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget properties
                if values.x ~= nil then self.x = values.x end
                if values.y ~= nil then self.y = values.y end
                if values.sx ~= nil then self.sx = values.sx end
                if values.sy ~= nil then self.sy = values.sy end
                if values.ro ~= nil then self.ro = values.ro end
                if values.opacity ~= nil then self.opacity = values.opacity end
                if values.r ~= nil then self.r = values.r end
                if values.g ~= nil then self.g = values.g end
                if values.b ~= nil then self.b = values.b end
                if values.a ~= nil then self.a = values.a end
                
                -- Update ALL sprites to match widget properties
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_state = sprite_start_states[sprite_id]
                    if start_state then
                        -- Calculate sprite's absolute properties
                        local sprite_x = self.x + (start_state.x - start_properties.x)
                        local sprite_y = self.y + (start_state.y - start_properties.y)
                        
                        -- Calculate relative scale, rotation, etc.
                        local sprite_sx = values.sx or start_state.sx
                        local sprite_sy = values.sy or start_state.sy
                        local sprite_ro = values.ro or start_state.ro
                        local sprite_opacity = values.opacity or start_state.opacity
                        local sprite_r = values.r or start_state.r
                        local sprite_g = values.g or start_state.g
                        local sprite_b = values.b or start_state.b
                        local sprite_a = values.a or start_state.a
                        
                        -- Set sprite properties directly
                        sprite.properties.x = sprite_x
                        sprite.properties.y = sprite_y
                        sprite.properties.sx = sprite_sx
                        sprite.properties.sy = sprite_sy
                        sprite.properties.ro = sprite_ro
                        sprite.properties.opacity = sprite_opacity
                        sprite.properties.r = sprite_r
                        sprite.properties.g = sprite_g
                        sprite.properties.b = sprite_b
                        sprite.properties.a = sprite_a
                        
                        -- Force redraw
                        sprite:draw()
                    end
                end
                
                -- Update child widgets to maintain their relative states
                for _, child_widget in pairs(self._child_widgets) do
                    local start_state = child_widget_start_states[child_widget.id]
                    if start_state then
                        -- Child maintains same relative state to parent
                        child_widget.x = start_state.x
                        child_widget.y = start_state.y
                        child_widget.sx = start_state.sx
                        child_widget.sy = start_state.sy
                        child_widget.ro = start_state.ro
                        child_widget.opacity = start_state.opacity
                        child_widget.r = start_state.r
                        child_widget.g = start_state.g
                        child_widget.b = start_state.b
                        child_widget.a = start_state.a
                        
                        -- Update child's layout
                        child_widget:updateLayout(false)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Apply screen constraints after animation
                if self._constrain_to_screen then
                    self:applyScreenConstraints()
                end
                
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
                
                debug_print("INFO", "Widget.transform_widget completed: %s", self.id)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.transform_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

-- Apply Bob animation (vertical bobbing) - Following slide_widget pattern
function Widget:bob_widget(distance, duration, easing, loop, ping_pong, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.bob_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 1.0
    easing = easing or "smoothstep"
    loop = loop or true
    ping_pong = ping_pong or true
    distance = distance or 3
    
    debug_print("INFO", "Widget.bob_widget: %s with distance %f, duration %f", 
               self.id, distance, duration)
    
    -- Get starting position
    local start_y = self.y
    
    -- Store starting positions of all sprites (relative to widget)
    local sprite_start_positions = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_positions[sprite_id] = {
            x = props.x,
            y = props.y
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "bob"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting positions of child widgets
    local child_widget_start_positions = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_positions[child_widget.id] = {
            x = child_widget.x,
            y = child_widget.y
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "bob"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.bob_widget: AnimationEngine not available")
        
        -- UNMARK SPRITES HERE (on_complete for fallback case)
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({y = start_y - distance}, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "bob"
    local anim_id
    
    anim_id = AnimationEngine.animate(
        {y = start_y},
        {y = start_y - distance},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local current_y = values.y
                
                -- Update widget position ONLY (don't trigger layout)
                self.y = current_y
                
                -- Update ALL sprites to match widget position
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_pos = sprite_start_positions[sprite_id]
                    if start_pos then
                        -- Calculate sprite's absolute position
                        local sprite_x = self.x + start_pos.x
                        local sprite_y = current_y + start_pos.y
                        
                        -- Set sprite position directly
                        sprite.properties.x = sprite_x
                        sprite.properties.y = sprite_y
                        
                        -- Force redraw
                        sprite:draw()
                        debug_print("DETAILED", "  Updated sprite %s to (%g,%g)", 
                                   sprite_id, sprite_x, sprite_y)
                    end
                end
                
                -- Update child widgets to maintain their relative positions
                for _, child_widget in pairs(self._child_widgets) do
                    local start_pos = child_widget_start_positions[child_widget.id]
                    if start_pos then
                        -- Child maintains same relative position to parent
                        child_widget.y = start_pos.y
                        
                        -- Update child's layout (which will update its sprites)
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "  Updated child widget %s position", 
                                   child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Apply screen constraints after animation
                if self._constrain_to_screen then
                    self:applyScreenConstraints()
                end
                
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
                
                debug_print("INFO", "Widget.bob_widget completed: %s", self.id)
            end,
            loop = loop,
            ping_pong = ping_pong
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.bob_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

-- Pulse the scale of a widget - Following slide_widget pattern
function Widget:pulse_scale_widget(min_scale, max_scale, pulse_duration, easing, loops, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.pulse_scale_widget: Invalid widget")
        return nil
    end
    
    local current_scale = self.sx or 1.0
    min_scale = min_scale or current_scale * 0.9
    max_scale = max_scale or current_scale * 1.1
    pulse_duration = pulse_duration or 0.5
    loops = loops or 1
    
    debug_print("INFO", "Widget.pulse_scale_widget: %s scale from %f to %f", 
               self.id, min_scale, max_scale)
    
    -- Store starting scales of all sprites
    local sprite_start_scales = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_scales[sprite_id] = {
            sx = props.sx,
            sy = props.sy
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "pulse_scale"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting scales of child widgets
    local child_widget_start_scales = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_scales[child_widget.id] = {
            sx = child_widget.sx,
            sy = child_widget.sy
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "pulse_scale"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.pulse_scale_widget: AnimationEngine not available")
        self:setScale(max_scale, max_scale)
        
        -- Update all sprites to match widget scale
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:update({
                sx = max_scale,
                sy = max_scale
            })
        end
        
        -- UNMARK SPRITES HERE (on_complete for fallback case)
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({sx = max_scale, sy = max_scale}, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "pulse_scale"
    local anim_id
    
    anim_id = AnimationEngine.animate(
        {scale = min_scale},
        {scale = max_scale},
        pulse_duration / 2,
        {
            easing = easing or "ease_in_out",
            on_update = function(values)
                local current_scale = values.scale
                
                -- Update widget scale ONLY (don't trigger layout)
                self.sx = current_scale
                self.sy = current_scale
                
                -- Update ALL sprites to match widget scale
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    -- Set sprite scale directly
                    sprite.properties.sx = current_scale
                    sprite.properties.sy = current_scale
                    
                    -- Force redraw
                    sprite:draw()
                    debug_print("DETAILED", "  Updated sprite %s scale to %f", 
                               sprite_id, current_scale)
                end
                
                -- Update child widgets to maintain their relative scales
                for _, child_widget in pairs(self._child_widgets) do
                    local start_scale = child_widget_start_scales[child_widget.id]
                    if start_scale then
                        -- Child maintains same relative scale to parent
                        child_widget.sx = start_scale.sx
                        child_widget.sy = start_scale.sy
                        
                        -- Update child's layout (which will update its sprites)
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "  Updated child widget %s scale", 
                                   child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
                
                debug_print("INFO", "Widget.pulse_scale_widget completed: %s", self.id)
            end,
            loop = loops,
            ping_pong = true
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.pulse_scale_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

-- Apply shake animation - Following slide_widget pattern
function Widget:shake_widget(intensity, duration, frequency, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.shake_widget: Invalid widget")
        return nil
    end
    
    intensity = intensity or 5
    duration = duration or 0.5
    frequency = frequency or 15
    
    debug_print("INFO", "Widget.shake_widget: %s intensity %f, duration %f", 
               self.id, intensity, duration)
    
    -- Store starting positions of all sprites
    local sprite_start_positions = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_positions[sprite_id] = {
            x = props.x,
            y = props.y
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "shake"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting positions of child widgets
    local child_widget_start_positions = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_positions[child_widget.id] = {
            x = child_widget.x,
            y = child_widget.y
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "shake"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.shake_widget: AnimationEngine not available")
        
        -- UNMARK SPRITES HERE (on_complete for fallback case)
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({shake_completed = true}, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "shake"
    
    local start_x = self.x
    local start_y = self.y
    local elapsed_time = 0
    local anim_id
    
    anim_id = AnimationEngine.animate(
        {t = 0},
        {t = 1},
        duration,
        {
            easing = "linear",
            on_update = function(values)
                local t = values.t
                elapsed_time = t * duration
                
                -- Calculate shake offset using sine waves
                local shake_x = math.sin(elapsed_time * frequency * math.pi * 2) * intensity
                local shake_y = math.cos(elapsed_time * frequency * math.pi * 2) * intensity
                
                -- Dampen shake over time
                local dampen = 1.0 - t
                shake_x = shake_x * dampen
                shake_y = shake_y * dampen
                
                -- Update widget position
                local current_x = start_x + shake_x
                local current_y = start_y + shake_y
                self.x = current_x
                self.y = current_y
                
                -- Update ALL sprites to match widget position with shake
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_pos = sprite_start_positions[sprite_id]
                    if start_pos then
                        -- Calculate sprite's absolute position with shake
                        local sprite_x = current_x + start_pos.x
                        local sprite_y = current_y + start_pos.y
                        
                        -- Set sprite position directly
                        sprite.properties.x = sprite_x
                        sprite.properties.y = sprite_y
                        
                        -- Force redraw
                        sprite:draw()
                        debug_print("DETAILED", "  Updated sprite %s to (%g,%g)", 
                                   sprite_id, sprite_x, sprite_y)
                    end
                end
                
                -- Update child widgets to maintain their relative positions
                for _, child_widget in pairs(self._child_widgets) do
                    local start_pos = child_widget_start_positions[child_widget.id]
                    if start_pos then
                        -- Child gets shake effect too
                        child_widget.x = start_pos.x + shake_x
                        child_widget.y = start_pos.y + shake_y
                        
                        -- Update child's layout
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "  Updated child widget %s with shake", 
                                   child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Reset to original position
                self.x = start_x
                self.y = start_y
                
                -- Apply screen constraints after animation
                if self._constrain_to_screen then
                    self:applyScreenConstraints()
                end
                
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags and reset positions
                for _, child_widget in pairs(self._child_widgets) do
                    local start_pos = child_widget_start_positions[child_widget.id]
                    if start_pos then
                        child_widget.x = start_pos.x
                        child_widget.y = start_pos.y
                    end
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete({shake_completed = true}, interrupted)
                end
                
                debug_print("INFO", "Widget.shake_widget completed: %s", self.id)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.shake_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

-- Apply summon animation (flies with arc) - Following slide_widget pattern
function Widget:summon_widget(start_x, start_y, start_scale, end_x, end_y, end_scale, 
                             duration, arc_height, peak_scale_mul, wobble_deg, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.summon_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.25
    arc_height = arc_height or 24
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 5
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.summon_widget: %s from screen(%g,%g) to screen(%g,%g) scale %f->%f", 
               self.id, start_x, start_y, end_x, end_y, start_scale, end_scale)
    
    -- Set starting position and scale (these are in SCREEN SPACE already)
    self:setPosition(start_x, start_y)
    self:setScale(start_scale, start_scale)
    
    -- Store starting states of all sprites (relative to widget in screen space)
    local sprite_start_states = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_states[sprite_id] = {
            x = props.x,  -- Sprite's origin position (screen space, relative to widget)
            y = props.y,
            sx = props.sx,  -- Sprite's own scale
            sy = props.sy,
            ro = props.ro or 0,
            ox = sprite.origin_x or 0,  -- Origin offset (screen space)
            oy = sprite.origin_y or 0
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "summon"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated, origin offset=(%g,%g)", 
                   sprite_id, sprite.origin_x or 0, sprite.origin_y or 0)
    end
    
    -- Store starting states of child widgets
    local child_widget_start_states = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_states[child_widget.id] = {
            x = child_widget.x,  -- Position in screen space (relative to parent)
            y = child_widget.y,
            sx = child_widget.sx,  -- Widget's scale
            sy = child_widget.sy,
            ro = child_widget.ro
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "summon"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.summon_widget: AnimationEngine not available")
        
        -- Set directly to end position
        self:setPosition(end_x, end_y)
        self:setScale(end_scale, end_scale)
        
        -- Update all sprites to new position
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local start_state = sprite_start_states[sprite_id]
            if start_state then
                -- Calculate sprite's new origin position (screen space)
                local sprite_x = end_x + (start_state.x - start_x)
                local sprite_y = end_y + (start_state.y - start_y)
                
                sprite:update({
                    x = sprite_x,
                    y = sprite_y,
                    sx = start_state.sx,  -- Keep sprite's own scale
                    sy = start_state.sy,
                    ro = 0
                })
            end
        end
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "summon"
    local anim_id = nil
    -- Control point for Bezier curve (in screen space)
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    
    anim_id = AnimationEngine.animate(
        {progress = 0},
        {progress = 1},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local t = values.progress
                local u = 1 - t
                
                -- Calculate position along quadratic Bezier curve (in SCREEN SPACE)
                local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
                local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
                
                -- Calculate scale with pulse effect (widget scale, not sprite scale)
                local base_scale = start_scale + (end_scale - start_scale) * t
                local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
                local current_widget_scale = base_scale * pulse
                
                -- Calculate rotation wobble (degrees)
                local rotation = 0
                if wobble_deg ~= 0 then
                    rotation = math.sin(math.pi * 2 * t) * wobble_deg * (1 - t)
                end
                
                -- Update widget properties (screen space)
                self.x = x
                self.y = y
                self.sx = current_widget_scale
                self.sy = current_widget_scale
                self.ro = rotation
                
                -- Update ALL sprites to match widget properties
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_state = sprite_start_states[sprite_id]
                    if start_state then
                        -- Calculate sprite's absolute origin position (screen space)
                        -- Relative position from start + widget movement
                        local sprite_x = x + (start_state.x - start_x)
                        local sprite_y = y + (start_state.y - start_y)
                        
                        -- IMPORTANT: We're setting the ORIGIN position here
                        -- The sprite's draw() method will convert to top-left using origin offset
                        sprite.properties.x = sprite_x
                        sprite.properties.y = sprite_y
                        
                        -- Keep sprite's own scale (don't override with widget scale)
                        -- The widget scale will be applied in the sprite's draw() method
                        sprite.properties.sx = start_state.sx
                        sprite.properties.sy = start_state.sy
                        
                        -- Apply rotation
                        sprite.properties.ro = rotation
                        
                        -- Force redraw
                        sprite:draw()
                        
                        debug_print("DETAILED", "    Sprite %s: origin at screen(%g,%g)", 
                                   sprite_id, sprite_x, sprite_y)
                    end
                end
                
                -- Update child widgets to maintain their relative states
                for _, child_widget in pairs(self._child_widgets) do
                    local start_state = child_widget_start_states[child_widget.id]
                    if start_state then
                        -- Child maintains same relative position to parent (screen space)
                        child_widget.x = start_state.x
                        child_widget.y = start_state.y
                        
                        -- Child maintains its own scale (don't inherit parent's animated scale)
                        child_widget.sx = start_state.sx
                        child_widget.sy = start_state.sy
                        child_widget.ro = start_state.ro
                        
                        -- Update child's layout (which will update its sprites)
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "    Updated child widget %s", child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    -- Ensure final position and scale (screen space)
                    self:setPosition(end_x, end_y)
                    self:setScale(end_scale, end_scale)
                    self:setRotation(0)
                    
                    -- Update all sprites to final state
                    for sprite_id, sprite in pairs(self.sprite_objects) do
                        local start_state = sprite_start_states[sprite_id]
                        if start_state then
                            -- Calculate final sprite origin position (screen space)
                            local sprite_x = end_x + (start_state.x - start_x)
                            local sprite_y = end_y + (start_state.y - start_y)
                            
                            sprite:update({
                                x = sprite_x,
                                y = sprite_y,
                                ro = 0
                            })
                        end
                    end
                end
                
                -- Apply screen constraints after animation
                if self._constrain_to_screen then
                    self:applyScreenConstraints()
                end
                
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, interrupted)
                end
                
                debug_print("INFO", "Widget.summon_widget completed: %s at screen(%g,%g) scale=%f", 
                           self.id, end_x, end_y, end_scale)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.summon_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

-- Apply complex summon animation with multiple steps - Following slide_widget pattern
function Widget:complex_summon_widget(start_x, start_y, start_scale, end_x, end_y, end_scale,
                                     arc_duration, wobble_duration, settle_duration, arc_height,
                                     peak_scale_mul, wobble_deg, easing, user_on_complete,
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
    
    debug_print("INFO", "Widget.complex_summon_widget: %s from screen(%g,%g) to screen(%g,%g)", 
               self.id, start_x, start_y, end_x, end_y)
    
    -- Set starting position and scale (screen space)
    self:setPosition(start_x, start_y)
    self:setScale(start_scale, start_scale)
    self:setRotation(0)
    
    -- Store starting states of all sprites
    local sprite_start_states = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_states[sprite_id] = {
            x = props.x,  -- Sprite origin position (screen space, relative to widget)
            y = props.y,
            sx = props.sx,  -- Sprite's own scale
            sy = props.sy,
            ro = props.ro or 0,
            ox = sprite.origin_x or 0,  -- Origin offset (screen space)
            oy = sprite.origin_y or 0
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "complex_summon"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated, origin offset=(%g,%g)", 
                   sprite_id, sprite.origin_x or 0, sprite.origin_y or 0)
    end
    
    -- Store starting states of child widgets
    local child_widget_start_states = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_states[child_widget.id] = {
            x = child_widget.x,  -- Position in screen space
            y = child_widget.y,
            sx = child_widget.sx,  -- Widget's scale
            sy = child_widget.sy,
            ro = child_widget.ro
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "complex_summon"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.complex_summon_widget: AnimationEngine not available")
        
        -- Set directly to end position
        self:setPosition(end_x, end_y)
        self:setScale(end_scale, end_scale)
        
        -- Update all sprites to final position
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local start_state = sprite_start_states[sprite_id]
            if start_state then
                -- Calculate final sprite origin position (screen space)
                local sprite_x = end_x + (start_state.x - start_x)
                local sprite_y = end_y + (start_state.y - start_y)
                
                sprite:update({
                    x = sprite_x,
                    y = sprite_y,
                    ro = 0
                })
            end
        end
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "complex_summon"
    
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
            -- Calculate position along quadratic Bezier curve (screen space)
            local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
            local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
            
            local base_scale = start_scale + (end_scale - start_scale) * t
            local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
            local current_widget_scale = base_scale * pulse
            
            -- Update widget (screen space)
            self.x = x
            self.y = y
            self.sx = current_widget_scale
            self.sy = current_widget_scale
            
            -- Update ALL sprites to match widget properties
            for sprite_id, sprite in pairs(self.sprite_objects) do
                local start_state = sprite_start_states[sprite_id]
                if start_state then
                    -- Calculate sprite's absolute origin position (screen space)
                    local sprite_x = x + (start_state.x - start_x)
                    local sprite_y = y + (start_state.y - start_y)
                    
                    -- Set sprite's origin position
                    sprite.properties.x = sprite_x
                    sprite.properties.y = sprite_y
                    
                    -- Keep sprite's own scale (don't override with widget scale)
                    sprite.properties.sx = start_state.sx
                    sprite.properties.sy = start_state.sy
                    sprite.properties.ro = 0
                    
                    -- Force redraw
                    sprite:draw()
                end
            end
            
            -- Update child widgets to maintain their relative states
            for _, child_widget in pairs(self._child_widgets) do
                local start_state = child_widget_start_states[child_widget.id]
                if start_state then
                    -- Child maintains same relative state to parent
                    child_widget.x = start_state.x
                    child_widget.y = start_state.y
                    child_widget.sx = start_state.sx
                    child_widget.sy = start_state.sy
                    child_widget.ro = start_state.ro
                    
                    -- Update child's layout
                    child_widget:updateLayout(false)
                end
            end
            
            if on_update_step1 then
                on_update_step1({x = x, y = y, scale = current_widget_scale, progress = t})
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
                self.ro = wobble
                
                -- Update all sprites with wobble (keep their positions, just add rotation)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite.properties.ro = wobble
                    sprite:draw()
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
            self.sx = settle_scale
            self.sy = settle_scale
            self.ro = 0
            
            -- Update all sprites with settle (keep positions, update rotation)
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite.properties.ro = 0
                sprite:draw()
            end
            
            if on_update_step3 then
                on_update_step3({scale = settle_scale, progress = t})
            end
        end,
        on_complete = function(values, interrupted)
            if not interrupted then
                -- Ensure final position and scale (screen space)
                self:setPosition(end_x, end_y)
                self:setScale(end_scale, end_scale)
                self:setRotation(0)
                
                -- Update all sprites to final state
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_state = sprite_start_states[sprite_id]
                    if start_state then
                        -- Calculate final sprite origin position (screen space)
                        local sprite_x = end_x + (start_state.x - start_x)
                        local sprite_y = end_y + (start_state.y - start_y)
                        
                        sprite:update({
                            x = sprite_x,
                            y = sprite_y,
                            sx = start_state.sx,  -- Keep sprite's own scale
                            sy = start_state.sy,
                            ro = 0
                        })
                    end
                end
            end
            
            -- Apply screen constraints after animation
            if self._constrain_to_screen then
                self:applyScreenConstraints()
            end
            
            -- Clear widget animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- UNMARK ALL SPRITES HERE (in on_complete)
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
                debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
            end
            
            -- Force final layout update
            self:updateLayout(true)
            
            if user_on_complete then
                user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, interrupted)
            end
            
            debug_print("INFO", "Widget.complex_summon_widget completed: %s at screen(%g,%g) scale=%f", 
                       self.id, end_x, end_y, end_scale)
        end
    })
    
    local seq_id = nil
    seq_id = AnimationEngine.create_sequence(sequence_steps, {
        id = "complex_summon_" .. self.id .. "_" .. math.random(1000, 9999),
        on_complete = function()
            -- Clean up animation tracking
            if seq_id then
                self.active_sequences[seq_id] = nil
            end
        end
    })
    
    if seq_id then
        self.active_sequences[seq_id] = true
        AnimationEngine.start_sequence(seq_id)
    end
    
    return seq_id
end

-- Apply summon animation from current position to relative offset
function Widget:summon_widget_relative(offset_x, offset_y, scale_offset, 
                                      duration, arc_height, peak_scale_mul, wobble_deg, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.summon_widget_relative: Invalid widget")
        return nil
    end
    
    duration = duration or 0.25
    arc_height = arc_height or 24
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 5
    easing = easing or "ease_in_out"
    scale_offset = scale_offset or 0  -- Relative scale change (0 = no change, 0.5 = increase by 50%)
    
    -- Calculate target position and scale relative to current
    local start_x, start_y = self.x, self.y
    local start_scale = self.sx or 1.0
    local end_x = start_x + offset_x
    local end_y = start_y + offset_y
    local end_scale = start_scale + scale_offset
    
    debug_print("INFO", "Widget.summon_widget_relative: %s from current screen(%g,%g) to relative screen(%g,%g) scale %f->%f", 
               self.id, start_x, start_y, end_x, end_y, start_scale, end_scale)
    
    -- Store starting states of all sprites (relative to widget in screen space)
    local sprite_start_states = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_states[sprite_id] = {
            x = props.x,  -- Sprite's origin position (screen space, relative to widget)
            y = props.y,
            sx = props.sx,  -- Sprite's own scale
            sy = props.sy,
            ro = props.ro or 0,
            ox = sprite.origin_x or 0,  -- Origin offset (screen space)
            oy = sprite.origin_y or 0
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "summon_relative"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated, origin offset=(%g,%g)", 
                   sprite_id, sprite.origin_x or 0, sprite.origin_y or 0)
    end
    
    -- Store starting states of child widgets
    local child_widget_start_states = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_states[child_widget.id] = {
            x = child_widget.x,  -- Position in screen space (relative to parent)
            y = child_widget.y,
            sx = child_widget.sx,  -- Widget's scale
            sy = child_widget.sy,
            ro = child_widget.ro
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "summon_relative"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.summon_widget_relative: AnimationEngine not available")
        
        -- Set directly to end position
        self:setPosition(end_x, end_y)
        self:setScale(end_scale, end_scale)
        
        -- Update all sprites to new position
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local start_state = sprite_start_states[sprite_id]
            if start_state then
                -- Calculate sprite's new origin position (screen space)
                local sprite_x = end_x + (start_state.x - start_x)
                local sprite_y = end_y + (start_state.y - start_y)
                
                sprite:update({
                    x = sprite_x,
                    y = sprite_y,
                    sx = start_state.sx,  -- Keep sprite's own scale
                    sy = start_state.sy,
                    ro = 0
                })
            end
        end
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "summon_relative"
    local anim_id = nil
    -- Control point for Bezier curve (in screen space)
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    
    anim_id = AnimationEngine.animate(
        {progress = 0},
        {progress = 1},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local t = values.progress
                local u = 1 - t
                
                -- Calculate position along quadratic Bezier curve (in SCREEN SPACE)
                local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
                local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
                
                -- Calculate scale with pulse effect (widget scale, not sprite scale)
                local base_scale = start_scale + (end_scale - start_scale) * t
                local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
                local current_widget_scale = base_scale * pulse
                
                -- Calculate rotation wobble (degrees)
                local rotation = 0
                if wobble_deg ~= 0 then
                    rotation = math.sin(math.pi * 2 * t) * wobble_deg * (1 - t)
                end
                
                -- Update widget properties (screen space)
                self.x = x
                self.y = y
                self.sx = current_widget_scale
                self.sy = current_widget_scale
                self.ro = rotation
                
                -- Update ALL sprites to match widget properties
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_state = sprite_start_states[sprite_id]
                    if start_state then
                        -- Calculate sprite's absolute origin position (screen space)
                        -- Relative position from start + widget movement
                        local sprite_x = x + (start_state.x - start_x)
                        local sprite_y = y + (start_state.y - start_y)
                        
                        -- IMPORTANT: We're setting the ORIGIN position here
                        sprite.properties.x = sprite_x
                        sprite.properties.y = sprite_y
                        
                        -- Keep sprite's own scale (don't override with widget scale)
                        sprite.properties.sx = start_state.sx
                        sprite.properties.sy = start_state.sy
                        
                        -- Apply rotation
                        sprite.properties.ro = rotation
                        
                        -- Force redraw
                        sprite:draw()
                        
                        debug_print("DETAILED", "    Sprite %s: origin at screen(%g,%g)", 
                                   sprite_id, sprite_x, sprite_y)
                    end
                end
                
                -- Update child widgets to maintain their relative states
                for _, child_widget in pairs(self._child_widgets) do
                    local start_state = child_widget_start_states[child_widget.id]
                    if start_state then
                        -- Child maintains same relative position to parent (screen space)
                        child_widget.x = start_state.x
                        child_widget.y = start_state.y
                        
                        -- Child maintains its own scale
                        child_widget.sx = start_state.sx
                        child_widget.sy = start_state.sy
                        child_widget.ro = start_state.ro
                        
                        -- Update child's layout
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "    Updated child widget %s", child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    -- Ensure final position and scale (screen space)
                    self:setPosition(end_x, end_y)
                    self:setScale(end_scale, end_scale)
                    self:setRotation(0)
                    
                    -- Update all sprites to final state
                    for sprite_id, sprite in pairs(self.sprite_objects) do
                        local start_state = sprite_start_states[sprite_id]
                        if start_state then
                            -- Calculate final sprite origin position (screen space)
                            local sprite_x = end_x + (start_state.x - start_x)
                            local sprite_y = end_y + (start_state.y - start_y)
                            
                            sprite:update({
                                x = sprite_x,
                                y = sprite_y,
                                ro = 0
                            })
                        end
                    end
                end
                
                -- Apply screen constraints after animation
                if self._constrain_to_screen then
                    self:applyScreenConstraints()
                end
                
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, interrupted)
                end
                
                debug_print("INFO", "Widget.summon_widget_relative completed: %s at screen(%g,%g) scale=%f", 
                           self.id, end_x, end_y, end_scale)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.summon_widget_relative started animation: %s", anim_id)
    end
    
    return anim_id
end

-- Apply complex summon animation from current position to relative offset
function Widget:complex_summon_widget_relative(offset_x, offset_y, scale_offset,
                                             arc_duration, wobble_duration, settle_duration, arc_height,
                                             peak_scale_mul, wobble_deg, easing, user_on_complete,
                                             on_update_step1, on_update_step2, on_update_step3)
    if not self then
        debug_print("ERROR", "Widget.complex_summon_widget_relative: Invalid widget")
        return nil
    end
    
    arc_duration = arc_duration or 0.25
    wobble_duration = wobble_duration or 0.1
    settle_duration = settle_duration or 0.05
    arc_height = arc_height or 40
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 10
    easing = easing or "ease_in_out"
    scale_offset = scale_offset or 0  -- Relative scale change
    
    -- Calculate target position and scale relative to current
    local start_x, start_y = self.x, self.y
    local start_scale = self.sx or 2.0
    local end_x = start_x + offset_x
    local end_y = start_y + offset_y
    local end_scale = start_scale + scale_offset
    
    debug_print("INFO", "Widget.complex_summon_widget_relative: %s from current screen(%g,%g) to relative screen(%g,%g)", 
               self.id, start_x, start_y, end_x, end_y)
    
    -- Store starting states of all sprites
    local sprite_start_states = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_states[sprite_id] = {
            x = props.x,  -- Sprite origin position (screen space, relative to widget)
            y = props.y,
            sx = props.sx,  -- Sprite's own scale
            sy = props.sy,
            ro = props.ro or 0,
            ox = sprite.origin_x or 0,  -- Origin offset (screen space)
            oy = sprite.origin_y or 0
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "complex_summon_relative"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated, origin offset=(%g,%g)", 
                   sprite_id, sprite.origin_x or 0, sprite.origin_y or 0)
    end
    
    -- Store starting states of child widgets
    local child_widget_start_states = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_states[child_widget.id] = {
            x = child_widget.x,  -- Position in screen space
            y = child_widget.y,
            sx = child_widget.sx,  -- Widget's scale
            sy = child_widget.sy,
            ro = child_widget.ro
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "complex_summon_relative"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.complex_summon_widget_relative: AnimationEngine not available")
        
        -- Set directly to end position
        self:setPosition(end_x, end_y)
        self:setScale(end_scale, end_scale)
        
        -- Update all sprites to final position
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local start_state = sprite_start_states[sprite_id]
            if start_state then
                -- Calculate final sprite origin position (screen space)
                local sprite_x = end_x + (start_state.x - start_x)
                local sprite_y = end_y + (start_state.y - start_y)
                
                sprite:update({
                    x = sprite_x,
                    y = sprite_y,
                    ro = 0
                })
            end
        end
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "complex_summon_relative"
    
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
            -- Calculate position along quadratic Bezier curve (screen space)
            local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
            local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
            
            local base_scale = start_scale + (end_scale - start_scale) * t
            local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
            local current_widget_scale = base_scale * pulse
            
            -- Update widget (screen space)
            self.x = x
            self.y = y
            self.sx = current_widget_scale
            self.sy = current_widget_scale
            
            -- Update ALL sprites to match widget properties
            for sprite_id, sprite in pairs(self.sprite_objects) do
                local start_state = sprite_start_states[sprite_id]
                if start_state then
                    -- Calculate sprite's absolute origin position (screen space)
                    local sprite_x = x + (start_state.x - start_x)
                    local sprite_y = y + (start_state.y - start_y)
                    
                    -- Set sprite's origin position
                    sprite.properties.x = sprite_x
                    sprite.properties.y = sprite_y
                    
                    -- Keep sprite's own scale (don't override with widget scale)
                    sprite.properties.sx = start_state.sx
                    sprite.properties.sy = start_state.sy
                    sprite.properties.ro = 0
                    
                    -- Force redraw
                    sprite:draw()
                end
            end
            
            -- Update child widgets to maintain their relative states
            for _, child_widget in pairs(self._child_widgets) do
                local start_state = child_widget_start_states[child_widget.id]
                if start_state then
                    -- Child maintains same relative state to parent
                    child_widget.x = start_state.x
                    child_widget.y = start_state.y
                    child_widget.sx = start_state.sx
                    child_widget.sy = start_state.sy
                    child_widget.ro = start_state.ro
                    
                    -- Update child's layout
                    child_widget:updateLayout(false)
                end
            end
            
            if on_update_step1 then
                on_update_step1({x = x, y = y, scale = current_widget_scale, progress = t})
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
                self.ro = wobble
                
                -- Update all sprites with wobble (keep their positions, just add rotation)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite.properties.ro = wobble
                    sprite:draw()
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
            self.sx = settle_scale
            self.sy = settle_scale
            self.ro = 0
            
            -- Update all sprites with settle (keep positions, update rotation)
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite.properties.ro = 0
                sprite:draw()
            end
            
            if on_update_step3 then
                on_update_step3({scale = settle_scale, progress = t})
            end
        end,
        on_complete = function(values, interrupted)
            if not interrupted then
                -- Ensure final position and scale (screen space)
                self:setPosition(end_x, end_y)
                self:setScale(end_scale, end_scale)
                self:setRotation(0)
                
                -- Update all sprites to final state
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_state = sprite_start_states[sprite_id]
                    if start_state then
                        -- Calculate final sprite origin position (screen space)
                        local sprite_x = end_x + (start_state.x - start_x)
                        local sprite_y = end_y + (start_state.y - start_y)
                        
                        sprite:update({
                            x = sprite_x,
                            y = sprite_y,
                            sx = start_state.sx,  -- Keep sprite's own scale
                            sy = start_state.sy,
                            ro = 0
                        })
                    end
                end
            end
            
            -- Apply screen constraints after animation
            if self._constrain_to_screen then
                self:applyScreenConstraints()
            end
            
            -- Clear widget animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- UNMARK ALL SPRITES HERE (in on_complete)
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
                debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
            end
            
            -- Force final layout update
            self:updateLayout(true)
            
            if user_on_complete then
                user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, interrupted)
            end
            
            debug_print("INFO", "Widget.complex_summon_widget_relative completed: %s at screen(%g,%g) scale=%f", 
                       self.id, end_x, end_y, end_scale)
        end
    })
    
    local seq_id = nil
    seq_id = AnimationEngine.create_sequence(sequence_steps, {
        id = "complex_summon_relative_" .. self.id .. "_" .. math.random(1000, 9999),
        on_complete = function()
            -- Clean up animation tracking
            if seq_id then
                self.active_sequences[seq_id] = nil
            end
        end
    })
    
    if seq_id then
        self.active_sequences[seq_id] = true
        AnimationEngine.start_sequence(seq_id)
    end
    
    return seq_id
end

-- Apply menu cursor animation (bob + pulse) - Following slide_widget pattern
function Widget:menu_cursor_widget(bob_distance, pulse_scale, bob_duration, pulse_duration, orientation, easing, back_easing, user_on_complete)
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
    orientation = orientation or "vertical"
    
    debug_print("INFO", "Widget.menu_cursor_widget: %s menu cursor animation", self.id)
    
    -- Store starting states of all sprites
    local sprite_start_states = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_states[sprite_id] = {
            x = props.x,
            y = props.y,
            sx = props.sx,
            sy = props.sy
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "menu_cursor"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting states of child widgets
    local child_widget_start_states = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_states[child_widget.id] = {
            x = child_widget.x,
            y = child_widget.y,
            sx = child_widget.sx,
            sy = child_widget.sy
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "menu_cursor"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.menu_cursor_widget: AnimationEngine not available")
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({menu_cursor_completed = true}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "menu_cursor"
    
    local axis = nil
    if orientation == "vertical" then
        axis = "y"
    else
        axis = "x"
    end
    
    local start_pos = self[axis] or 0
    local start_scale = self.sx or 1.0
    
    -- Bob animation
    local bob_id = AnimationEngine.animate(
        {[axis] = start_pos},
        {[axis] = start_pos - bob_distance},
        bob_duration,
        {
            easing = easing,
            easing_back = back_easing,
            on_update = function(values)
                self[axis] = values[axis]
                
                -- Update ALL sprites to match widget position
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_state = sprite_start_states[sprite_id]
                    if start_state then
                        -- Update appropriate axis
                        if axis == "y" then
                            sprite.properties.y = self.y + (start_state.y - start_pos)
                        else
                            sprite.properties.x = self.x + (start_state.x - start_pos)
                        end
                        
                        -- Force redraw
                        sprite:draw()
                    end
                end
                
                -- Update child widgets
                for _, child_widget in pairs(self._child_widgets) do
                    local start_state = child_widget_start_states[child_widget.id]
                    if start_state then
                        -- Child maintains same relative position
                        child_widget[axis] = start_state[axis]
                        
                        -- Update child's layout
                        child_widget:updateLayout(false)
                    end
                end
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    -- Pulse scale animation
    local pulse_id = AnimationEngine.animate(
        {scale = 1.0},
        {scale = pulse_scale},
        pulse_duration,
        {
            easing = "ease_in_out",
            on_update = function(values)
                local scale = start_scale * values.scale
                self.sx = scale
                self.sy = scale
                
                -- Update ALL sprites to match widget scale
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite.properties.sx = scale
                    sprite.properties.sy = scale
                    sprite:draw()
                end
                
                -- Update child widgets
                for _, child_widget in pairs(self._child_widgets) do
                    local start_state = child_widget_start_states[child_widget.id]
                    if start_state then
                        -- Child maintains same relative scale
                        child_widget.sx = start_state.sx
                        child_widget.sy = start_state.sy
                        
                        -- Update child's layout
                        child_widget:updateLayout(false)
                    end
                end
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    if bob_id then
        self.active_animations[bob_id] = true
    end
    if pulse_id then
        self.active_animations[pulse_id] = true
    end
    
    -- Return a controller object to stop both animations
    return {
        bob = bob_id,
        pulse = pulse_id,
        stop = function()
            if bob_id then
                AnimationEngine.stop_animation(bob_id)
                self.active_animations[bob_id] = nil
            end
            if pulse_id then
                AnimationEngine.stop_animation(pulse_id)
                self.active_animations[pulse_id] = nil
            end
            
            -- Clear widget animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- UNMARK ALL SPRITES HERE
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
                debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
            end
            
            -- Force final layout update
            self:updateLayout(true)
            
            if user_on_complete then
                user_on_complete({stopped = true}, true)
            end
            
            debug_print("INFO", "Widget.menu_cursor_widget stopped: %s", self.id)
        end
    }
end

-- Set widget properties instantly (no animation) - Following slide_widget pattern
function Widget:set_widget_instant(properties)
    if not self then
        debug_print("ERROR", "Widget.set_widget_instant: Invalid widget")
        return
    end
    
    debug_print("INFO", "Widget.set_widget_instant: %s setting properties instantly", self.id)
    
    -- Apply each property directly with proper setters
    if properties.x or properties.y then
        self:setPosition(properties.x or self.x, properties.y or self.y)
    end
    if properties.sx or properties.sy then
        self:setScale(properties.sx or self.sx, properties.sy or self.sy)
    end
    if properties.ro then
        self:setRotation(properties.ro)
    end
    if properties.opacity then
        self:setOpacity(properties.opacity)
    end
    if properties.r or properties.g or properties.b or properties.a then
        self:setColor(properties.r or self.r, properties.g or self.g, 
                     properties.b or self.b, properties.a or self.a)
    end
    if properties.visible ~= nil then
        self:setVisible(properties.visible)
    end
    
    -- Update all sprites directly
    for sprite_id, sprite in pairs(self.sprite_objects) do
        if properties.x or properties.y then
            sprite:set_position(self.x, self.y)
        end
        if properties.sx or properties.sy then
            sprite:set_scale(self.sx, self.sy)
        end
        if properties.ro then
            sprite:set_rotation(self.ro)
        end
        if properties.opacity then
            sprite:set_opacity(self.opacity)
        end
        if properties.r or properties.g or properties.b or properties.a then
            sprite:set_color(self.r, self.g, self.b, self.a)
        end
        if properties.visible ~= nil then
            sprite:set_visible(properties.visible)
        end
    end
    
    -- Update child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:set_widget_instant(properties)
    end
    
    -- Force immediate update
    self:updateLayout(true)
    self:draw(true)
    
    debug_print("DETAILED", "Widget.set_widget_instant: %s completed", self.id)
end

-- Reset widget to initial state - Following slide_widget pattern
function Widget:reset_widget(initial_values, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.reset_widget: Invalid widget")
        return
    end
    
    debug_print("INFO", "Widget.reset_widget: %s resetting widget", self.id)
    
    -- Stop all animations first
    self:stop_all_animations()
    
    -- Define default reset values
    local reset_props = initial_values or {
        x = 0,
        y = 0,
        sx = utils.SCREEN_SCALE,
        sy = utils.SCREEN_SCALE,
        ro = 0,
        opacity = 255,
        r = 255,
        g = 255,
        b = 255,
        a = 255,
        visible = true,
        enabled = true
    }
    
    -- Use instant set for reset
    self:set_widget_instant(reset_props)
    
    if user_on_complete then
        user_on_complete(reset_props, false)
    end
    
    debug_print("DETAILED", "Widget.reset_widget: %s reset completed", self.id)
end

-- Apply color pulse animation - Using existing animate_properties for simplicity
function Widget:color_pulse_widget(start_color, target_color, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.5
    easing = easing or "ease_in_out"
    
    -- Normalize colors
    start_color = start_color or {r = self.r, g = self.g, b = self.b, a = self.a}
    target_color = target_color or start_color
    
    debug_print("INFO", "Widget.color_pulse_widget: %s from (%d,%d,%d,%d) to (%d,%d,%d,%d) in %f seconds", 
               self.id, start_color.r, start_color.g, start_color.b, start_color.a,
               target_color.r, target_color.g, target_color.b, target_color.a, duration)
    
    -- Store starting colors of all sprites
    local sprite_start_colors = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_colors[sprite_id] = {
            r = props.r,
            g = props.g,
            b = props.b,
            a = props.a
        }
        -- MARK SPRITES AS WIDGET-ANIMATED HERE
        sprite:set_widget_animated(true, {type = "color_pulse"})
        debug_print("DETAILED", "  Marked sprite %s as widget-animated", sprite_id)
    end
    
    -- Store starting colors of child widgets
    local child_widget_start_colors = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_colors[child_widget.id] = {
            r = child_widget.r,
            g = child_widget.g,
            b = child_widget.b,
            a = child_widget.a
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "color_pulse"
        debug_print("DETAILED", "  Marked child widget %s for animation", child_widget.id)
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.color_pulse_widget: AnimationEngine not available")
        self:setColor(target_color.r, target_color.g, target_color.b, target_color.a)
        
        -- Update all sprites to match widget color
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:update({
                r = target_color.r,
                g = target_color.g,
                b = target_color.b,
                a = target_color.a or 255
            })
        end
        
        -- UNMARK SPRITES HERE (on_complete for fallback case)
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({r = target_color.r, g = target_color.g, b = target_color.b, a = target_color.a}, false)
        end
        return nil
    end
    
    -- Set animation flag
    self._layout_animation_active = true
    self._layout_animation_type = "color_pulse"
    local anim_id
    
    anim_id = AnimationEngine.animate(
        {r = start_color.r, g = start_color.g, b = start_color.b, a = start_color.a or 255},
        {r = target_color.r, g = target_color.g, b = target_color.b, a = target_color.a or 255},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local current_r = values.r
                local current_g = values.g
                local current_b = values.b
                local current_a = values.a
                
                -- Update widget color ONLY (don't trigger layout)
                self.r = current_r
                self.g = current_g
                self.b = current_b
                self.a = current_a
                
                -- Update ALL sprites to match widget color
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    -- Set sprite color directly
                    sprite.properties.r = current_r
                    sprite.properties.g = current_g
                    sprite.properties.b = current_b
                    sprite.properties.a = current_a
                    
                    -- Force redraw
                    sprite:draw()
                    debug_print("DETAILED", "  Updated sprite %s color to (%d,%d,%d,%d)", 
                               sprite_id, current_r, current_g, current_b, current_a)
                end
                
                -- Update child widgets to maintain their relative colors
                for _, child_widget in pairs(self._child_widgets) do
                    local start_color = child_widget_start_colors[child_widget.id]
                    if start_color then
                        -- Child maintains same relative color to parent
                        child_widget.r = start_color.r
                        child_widget.g = start_color.g
                        child_widget.b = start_color.b
                        child_widget.a = start_color.a
                        
                        -- Update child's layout (which will update its sprites)
                        child_widget:updateLayout(false)
                        debug_print("DETAILED", "  Updated child widget %s color", 
                                   child_widget.id)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                -- Clear widget animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- UNMARK ALL SPRITES HERE (in on_complete)
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                    debug_print("DETAILED", "  Unmarked sprite %s as widget-animated", sprite_id)
                end
                
                -- Clear child widget animation flags
                for _, child_widget in pairs(self._child_widgets) do
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                -- Force final layout update
                self:updateLayout(true)
                
                self.active_animations[anim_id] = nil
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
                
                debug_print("INFO", "Widget.color_pulse_widget completed: %s color (%d,%d,%d,%d)", 
                           self.id, values.r, values.g, values.b, values.a)
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.color_pulse_widget started animation: %s", anim_id)
    end
    
    return anim_id
end

-- Simple color pulse with RGB values
function Widget:color_pulse_rgb(start_r, start_g, start_b, start_a, target_r, target_g, target_b, target_a, duration, easing, user_on_complete)
    local start_color = {
        r = start_r or self.r,
        g = start_g or self.g,
        b = start_b or self.b,
        a = start_a or self.a
    }
    
    local target_color = {
        r = target_r or start_color.r,
        g = target_g or start_color.g,
        b = target_b or start_color.b,
        a = target_a or start_color.a
    }
    
    return self:color_pulse_widget(start_color, target_color, duration, easing, user_on_complete)
end

-- Color pulse from current color
function Widget:color_pulse_from_current(target_color, duration, easing, user_on_complete)
    local current_color = {
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        a = self.a or 255
    }
    
    return self:color_pulse_widget(current_color, target_color, duration, easing, user_on_complete)
end

-- Check if widget has active animations
function Widget:has_active_animations()
    if next(self.active_animations) ~= nil then
        return true
    end
    
    if next(self.active_sequences) ~= nil then
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
        if widget:has_active_animations() then
            return true
        end
    end
    
    return false
end

-- Check if specific animation is running
function Widget:is_animation_running(anim_id)
    if not anim_id then
        return self:has_active_animations()
    end
    
    if self.active_animations[anim_id] then
        return true
    end
    
    if self.active_sequences[anim_id] then
        return true
    end
    
    -- Check sprites
    for _, sprite in pairs(self.sprite_objects) do
        if sprite:is_animating() and sprite:get_animation_id() == anim_id then
            return true
        end
    end
    
    -- Check child widgets recursively
    for _, widget in pairs(self._child_widgets) do
        if widget:is_animation_running(anim_id) then
            return true
        end
    end
    
    return false
end

function Widget:printDebugInfo(level)
    level = level or 0
    local indent = string.rep("  ", level)
    
    print(indent .. "Widget: " .. self.id .. " (" .. self.widget_type .. ")")
    print(indent .. "  Position: (" .. string.format("%g", self.x) .. ", " .. string.format("%g", self.y) .. ") (screen space)")
    print(indent .. "  Scale: " .. string.format("%f", self.sx) .. "," .. string.format("%f", self.sy))
    print(indent .. "  Size: " .. string.format("%g", self.width) .. "x" .. string.format("%g", self.height) .. " (screen space)")
    print(indent .. "  Calculated Size: " .. string.format("%g", self._calculated_size.width) .. "x" .. string.format("%g", self._calculated_size.height) .. " (screen space)")
    print(indent .. "  State: visible=" .. tostring(self.state.visible) .. 
          ", enabled=" .. tostring(self.state.enabled) .. 
          ", dirty=" .. tostring(self.state.dirty))
    print(indent .. "  Layout Animation Active: " .. tostring(self._layout_animation_active))
    print(indent .. "  Layout Animation Type: " .. (self._layout_animation_type or "none"))
    print(indent .. "  Screen Constraints: " .. tostring(self._constrain_to_screen))
    print(indent .. "  Sprites: " .. utils.table_count(self.sprite_objects))
    print(indent .. "  Sprite Groups: " .. utils.table_count(self.sprite_groups))
    print(indent .. "  Children: " .. #self.children)
    print(indent .. "  Child Widgets: " .. utils.table_count(self._child_widgets))
    print(indent .. "  Active Animations: " .. utils.table_count(self.active_animations))
    print(indent .. "  Active Sequences: " .. utils.table_count(self.active_sequences))
    
    if utils.table_count(self.sprite_objects) > 0 then
        print(indent .. "  Sprite details:")
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local layout_width, layout_height = sprite:get_layout_dimensions()
            local visual_width, visual_height = sprite:get_visual_dimensions()
            print(indent .. "    " .. sprite_id .. ": " .. 
                  (sprite.texture_path or "unknown") .. 
                  " (template: " .. sprite.template_id .. 
                  ", layout: " .. string.format("%g", layout_width) .. "x" .. string.format("%g", layout_height) .. " screen space" ..
                  ", visual: " .. string.format("%g", visual_width) .. "x" .. string.format("%g", visual_height) .. " scaled" ..
                  ", position: (" .. string.format("%g", sprite.properties.x) .. "," .. string.format("%g", sprite.properties.y) .. ") screen space" ..
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

-- ===========================================================
-- WIDGET SWAPPING METHODS (for swapping child widgets)
-- ===========================================================

-- Swap two child widgets and animate their positions
function Widget:swap_and_animate_child_widgets(widget1_id, widget2_id, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.swap_and_animate_child_widgets: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.swap_and_animate_child_widgets: Swapping %s and %s in %s", 
               widget1_id, widget2_id, self.id)
    
    -- Find the child widgets in our children array
    local child1_data, child2_data = nil, nil
    local index1, index2 = nil, nil
    
    for i, child in ipairs(self.children) do
        if child.widget and child.widget.id == widget1_id then
            child1_data = child
            index1 = i
        elseif child.widget and child.widget.id == widget2_id then
            child2_data = child
            index2 = i
        end
    end
    
    if not child1_data or not child2_data then
        debug_print("ERROR", "  One or both child widgets not found")
        if on_complete then on_complete({success = false, reason = "not_found"}, false) end
        return nil
    end
    
    local widget1 = child1_data.widget
    local widget2 = child2_data.widget
    
    debug_print("DETAILED", "  Found widgets: %s at index %d, %s at index %d", 
               widget1.id, index1, widget2.id, index2)
    
    -- Store current positions (relative to parent)
    local pos1 = {x = widget1.x, y = widget1.y}
    local pos2 = {x = widget2.x, y = widget2.y}
    
    -- Swap in children array
    self.children[index1], self.children[index2] = self.children[index2], self.children[index1]
    
    -- Update layout to calculate new positions
    self:updateLayout(true)
    
    -- Get new positions
    local new_pos1 = {x = widget1.x, y = widget1.y}
    local new_pos2 = {x = widget2.x, y = widget2.y}
    
    debug_print("DETAILED", "  Original positions: %s=(%g,%g), %s=(%g,%g)", 
               widget1.id, pos1.x, pos1.y, widget2.id, pos2.x, pos2.y)
    debug_print("DETAILED", "  New positions: %s=(%g,%g), %s=(%g,%g)", 
               widget1.id, new_pos1.x, new_pos1.y, widget2.id, new_pos2.x, new_pos2.y)
    
    -- Temporarily set back to original positions
    widget1:setPosition(pos1.x, pos1.y)
    widget2:setPosition(pos2.x, pos2.y)
    
    -- Set animation flags on the widgets
    widget1._layout_animation_active = true
    widget1._layout_animation_type = "widget_swap"
    widget2._layout_animation_active = true
    widget2._layout_animation_type = "widget_swap"
    
    -- Animate both widgets to their new positions
    local animations_completed = 0
    local total_animations = 2
    
    local function check_completion()
        animations_completed = animations_completed + 1
        if animations_completed >= total_animations then
            -- Clear animation flags
            widget1._layout_animation_active = false
            widget1._layout_animation_type = nil
            widget2._layout_animation_active = false
            widget2._layout_animation_type = nil
            
            -- Final layout update
            self:updateLayout(true)
            
            if on_complete then
                on_complete({
                    widget1 = widget1_id, 
                    widget2 = widget2_id, 
                    success = true,
                    new_index1 = index2,
                    new_index2 = index1
                }, false)
            end
            
            debug_print("INFO", "Widget.swap_and_animate_child_widgets: Swap completed")
        end
    end
    
    -- Animate widget1
    widget1:slide_widget(new_pos1.x, new_pos1.y, duration, easing, function()
        check_completion()
    end)
    
    -- Animate widget2
    widget2:slide_widget(new_pos2.x, new_pos2.y, duration, easing, function()
        check_completion()
    end)
    
    return {widget1_anim = widget1.id, widget2_anim = widget2.id}
end

-- Simple swap of child widgets
function Widget:simple_swap_child_widgets(widget1_id, widget2_id, duration, easing, on_complete)
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.simple_swap_child_widgets: Swapping %s and %s in %s", 
               widget1_id, widget2_id, self.id)
    
    -- Find the child widgets
    local widget1, widget2 = nil, nil
    local index1, index2 = nil, nil
    
    for i, child in ipairs(self.children) do
        if child.widget and child.widget.id == widget1_id then
            widget1 = child.widget
            index1 = i
        elseif child.widget and child.widget.id == widget2_id then
            widget2 = child.widget
            index2 = i
        end
    end
    
    if not widget1 or not widget2 then
        debug_print("ERROR", "  Child widgets not found")
        if on_complete then on_complete(false) end
        return false
    end
    
    -- Store positions
    local pos1 = {x = widget1.x, y = widget1.y}
    local pos2 = {x = widget2.x, y = widget2.y}
    
    -- Swap in children array
    self.children[index1], self.children[index2] = self.children[index2], self.children[index1]
    
    -- Update layout
    self:updateLayout(true)
    
    -- Get new positions
    local new_pos1 = {x = widget1.x, y = widget1.y}
    local new_pos2 = {x = widget2.x, y = widget2.y}
    
    -- Set back to original positions
    widget1:setPosition(pos1.x, pos1.y)
    widget2:setPosition(pos2.x, pos2.y)
    
    -- Animate
    widget1:slide_widget(new_pos1.x, new_pos1.y, duration, easing)
    widget2:slide_widget(new_pos2.x, new_pos2.y, duration, easing, function()
        self:updateLayout(true)
        if on_complete then on_complete(true) end
    end)
    
    return true
end

-- Get child widget by ID
function Widget:get_child_widget(widget_id)
    for _, child in ipairs(self.children) do
        if child.widget and child.widget.id == widget_id then
            return child.widget
        end
    end
    return nil
end

-- Get position (index) of child widget
function Widget:get_child_widget_position(widget_id)
    for i, child in ipairs(self.children) do
        if child.widget and child.widget.id == widget_id then
            return i
        end
    end
    return nil
end

return Widget