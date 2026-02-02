-- Base Widget class for the widget system
-- Updated to use AnimationEngine pre-built sequences for all animations

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')
local SpriteObject = require('scripts/net-games/widgets/sprite-object')
local WidgetCache = require('scripts/net-games/widgets/cache')

local Widget = {}
Widget.__index = Widget

--- Load AnimationEngine helper
function Widget:_load_animation_engine()
    -- Check global first
    if _G.AnimationEngine then
        return _G.AnimationEngine
    end
    
    -- Try to require it
    local success, engine = pcall(require, 'scripts/net-games/animation-engine/animation-engine')
    if success then
        _G.AnimationEngine = engine
        return engine
    end
    
    debug_print("ERROR", "Widget._load_animation_engine: Failed to load AnimationEngine")
    return nil
end

--- Mark sprites as widget-animated before animation starts
-- @param animation_type (string): Type of animation for tracking
function Widget:_mark_sprites_for_animation(animation_type)
    debug_print("DETAILED", "Widget._mark_sprites_for_animation: Marking sprites for %s animation", animation_type)
    
    local marked_count = 0
    for sprite_id, sprite in pairs(self.sprite_objects) do
        if sprite.set_widget_animated then
            sprite:set_widget_animated(true, {type = animation_type})
            marked_count = marked_count + 1
        end
    end
    
    debug_print("DETAILED", "  Marked %d sprites for animation", marked_count)
end

--- Unmark sprites after animation completes
function Widget:_unmark_sprites_after_animation()
    debug_print("DETAILED", "Widget._unmark_sprites_after_animation: Unmarking sprites")
    
    local unmarked_count = 0
    for sprite_id, sprite in pairs(self.sprite_objects) do
        if sprite.set_widget_animated then
            sprite:set_widget_animated(false)
            unmarked_count = unmarked_count + 1
        end
    end
    
    debug_print("DETAILED", "  Unmarked %d sprites", unmarked_count)
end

--- Set widget animation flags
-- @param animation_type (string): Type of animation for tracking
function Widget:_set_animation_flags(animation_type)
    self._layout_animation_active = true
    self._layout_animation_type = animation_type
    debug_print("DETAILED", "Widget._set_animation_flags: Set animation flags for %s", animation_type)
end

--- Clear widget animation flags
function Widget:_clear_animation_flags()
    self._layout_animation_active = false
    self._layout_animation_type = nil
    debug_print("DETAILED", "Widget._clear_animation_flags: Cleared animation flags")
end

--- Common animation completion handler
-- @param values (table): Final animation values
-- @param interrupted (boolean): Whether animation was interrupted
-- @param user_on_complete (function): User callback function
-- @param animation_type (string): Type of animation for logging
function Widget:_handle_animation_completion(values, interrupted, user_on_complete, animation_type)
    -- Apply screen constraints
    if self._constrain_to_screen then
        self:applyScreenConstraints()
    end
    
    -- Clear animation flags
    self:_clear_animation_flags()
    
    -- Unmark sprites
    self:_unmark_sprites_after_animation()
    
    -- Clear child widget animation flags
    for _, child_widget in pairs(self._child_widgets) do
        child_widget._layout_animation_active = false
        child_widget._layout_animation_type = nil
    end
    
    -- Force final layout update
    self:updateLayout(true)
    
    -- Call user callback
    if user_on_complete then
        user_on_complete(values, interrupted)
    end
    
    debug_print("INFO", "Widget animation completed: %s %s", animation_type, self.id)
end

--- Helper to update child widgets during animation
function Widget:_update_child_widgets_for_animation()
    for _, child_widget in pairs(self._child_widgets) do
        if not child_widget._layout_animation_active then
            child_widget:updateLayout(false)
        end
    end
end

-- ==============================
-- Constructor and Core Methods
-- ==============================

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
    
    -- Animation tracking (updated for AnimationEngine integration)
    self.active_animations = {}
    self.active_sequences = {}
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

-- ==============================
-- Sprite Management
-- ==============================

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

-- ==============================
-- REORDERING METHODS FOR SPRITES AND CHILDREN
-- ==============================

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

-- ==============================
-- Child Widget Management
-- ==============================

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

-- ==============================
-- Layout Management
-- ==============================

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

-- ==============================
-- Drawing and Updates
-- ==============================

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

-- ==============================
-- Migrated Animation Methods
-- ==============================

--- Create a summon animation using AnimationEngine.Sequences.summon
-- @param start_x (number): Starting X position in screen space
-- @param start_y (number): Starting Y position in screen space
-- @param start_scale (number): Starting scale factor
-- @param end_x (number): Target X position in screen space
-- @param end_y (number): Target Y position in screen space
-- @param end_scale (number): Target scale factor
-- @param duration (number, optional): Animation duration in seconds (default: 0.25)
-- @param arc_height (number, optional): Height of the arc curve (default: 24)
-- @param peak_scale_mul (number, optional): Scale multiplier at animation peak (default: 1.35)
-- @param wobble_deg (number, optional): Maximum rotation wobble in degrees (default: 5)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string/table): Animation/Sequence ID, or nil if failed
function Widget:summon_widget(start_x, start_y, start_scale, end_x, end_y, end_scale, 
                             duration, arc_height, peak_scale_mul, wobble_deg, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.summon_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.summon_widget: AnimationEngine not available, using direct positioning")
        self:setPosition(end_x, end_y)
        self:setScale(end_scale, end_scale)
        if user_on_complete then
            user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.summon_widget: %s from (%g,%g) scale %f to (%g,%g) scale %f", 
               self.id, start_x, start_y, start_scale, end_x, end_y, end_scale)
    
    -- Set starting position
    self:setPosition(start_x, start_y)
    self:setScale(start_scale, start_scale)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("summon")
    
    -- Set animation flags
    self:_set_animation_flags("summon")
    
    -- Use AnimationEngine.summon (direct method) or AnimationSequences.summon
    local anim_id = nil
    local summon_func = AnimationEngine.summon
    
    if summon_func then
        anim_id = summon_func(self, start_x, start_y, start_scale, 
                            end_x, end_y, end_scale,
                            {
            duration = duration or 0.25,
            arc_height = arc_height or 24,
            peak_scale_mul = peak_scale_mul or 1.35,
            wobble_deg = wobble_deg or 5,
            easing = easing or "ease_in_out",
            on_complete = function(values, interrupted)
                self:_handle_animation_completion(
                    {x = end_x, y = end_y, sx = end_scale, sy = end_scale},
                    interrupted,
                    user_on_complete,
                    "summon"
                )
            end
        })
    else
        -- Fallback to animate_widget if summon is not available
        debug_print("WARN", "Widget.summon_widget: summon function not available, using animate_widget")
        anim_id = AnimationEngine.animate_widget(self, {
            x = end_x,
            y = end_y,
            sx = end_scale,
            sy = end_scale
        }, duration or 0.25, {
            easing = easing or "ease_in_out",
            on_complete = function(values, interrupted)
                self:_handle_animation_completion(values, interrupted, user_on_complete, "summon")
            end
        })
    end
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.summon_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a bob animation using AnimationEngine.Sequences.bob
-- @param distance (number, optional): Vertical bobbing distance (default: 3)
-- @param duration (number, optional): Full bob cycle duration (default: 1.0)
-- @param easing (string, optional): Easing function name (default: "smoothstep")
-- @param loop (boolean, optional): Whether to loop continuously (default: true)
-- @param ping_pong (boolean, optional): Whether to reverse direction each cycle (default: true)
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:bob_widget(distance, duration, easing, loop, ping_pong, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.bob_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.bob_widget: AnimationEngine not available")
        if user_on_complete then
            user_on_complete({y = self.y}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.bob_widget: %s with distance %f, duration %f", 
               self.id, distance or 3, duration or 1.0)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("bob")
    
    -- Set animation flags
    self:_set_animation_flags("bob")
    
    -- Use AnimationEngine.bob (direct method) or AnimationSequences.bob
    local anim_id = nil
    local bob_func = AnimationEngine.bob
    
    if bob_func then
        anim_id = bob_func(self, {
            distance = distance,
            duration = duration,
            easing = easing,
            loop = loop,
            ping_pong = ping_pong,
            on_complete = function(values, interrupted)
                self:_handle_animation_completion(values, interrupted, user_on_complete, "bob")
            end,
            on_update = function(values)
                -- Update child widgets to maintain relative positions
                self:_update_child_widgets_for_animation()
            end
        })
    else
        -- Fallback implementation
        debug_print("WARN", "Widget.bob_widget: bob function not available, using animate")
        local start_y = self.y or 0
        anim_id = AnimationEngine.animate(
            {y = start_y},
            {y = start_y - (distance or 3)},
            duration or 1.0,
            {
                easing = easing or "smoothstep",
                loop = loop ~= false,
                ping_pong = ping_pong ~= false,
                on_update = function(values)
                    self.y = values.y
                    self:_update_child_widgets_for_animation()
                end,
                on_complete = function(values, interrupted)
                    self:_handle_animation_completion(values, interrupted, user_on_complete, "bob")
                end
            }
        )
    end
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.bob_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a pulse animation using AnimationEngine.Sequences.pulse
-- @param min_scale (number, optional): Minimum scale factor (default: 0.9)
-- @param max_scale (number, optional): Maximum scale factor (default: 1.1)
-- @param pulse_duration (number, optional): Pulse cycle duration (default: 0.5)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param loops (number/boolean, optional): Number of loops or true for infinite (default: true)
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:pulse_scale_widget(min_scale, max_scale, pulse_duration, easing, loops, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.pulse_scale_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.pulse_scale_widget: AnimationEngine not available")
        self:setScale(max_scale or 1.1, max_scale or 1.1)
        if user_on_complete then
            user_on_complete({sx = max_scale or 1.1, sy = max_scale or 1.1}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.pulse_scale_widget: %s scale from %f to %f", 
               self.id, min_scale or 0.9, max_scale or 1.1)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("pulse_scale")
    
    -- Set animation flags
    self:_set_animation_flags("pulse_scale")
    
    -- Use AnimationEngine.pulse (direct method) or AnimationSequences.pulse
    local anim_id = nil
    local pulse_func = AnimationEngine.pulse
    
    if pulse_func then
        anim_id = pulse_func(self, {
            scale_from = min_scale or 0.9,
            scale_to = max_scale or 1.1,
            duration = pulse_duration or 0.5,
            easing = easing or "ease_in_out",
            loop = loops ~= false,
            ping_pong = true,
            on_complete = function(values, interrupted)
                self:_handle_animation_completion(values, interrupted, user_on_complete, "pulse_scale")
            end,
            on_update = function(values)
                -- Update child widgets to maintain relative scales
                self:_update_child_widgets_for_animation()
            end
        })
    else
        -- Fallback implementation
        debug_print("WARN", "Widget.pulse_scale_widget: pulse function not available, using animate")
        local current_scale = self.sx or 1.0
        anim_id = AnimationEngine.animate(
            {scale = min_scale or 0.9},
            {scale = max_scale or 1.1},
            pulse_duration or 0.5,
            {
                easing = easing or "ease_in_out",
                loop = loops ~= false,
                ping_pong = true,
                on_update = function(values)
                    self.sx = values.scale
                    self.sy = values.scale
                    self:_update_child_widgets_for_animation()
                end,
                on_complete = function(values, interrupted)
                    self:_handle_animation_completion(values, interrupted, user_on_complete, "pulse_scale")
                end
            }
        )
    end
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.pulse_scale_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a shake animation using AnimationEngine.Sequences.shake
-- @param intensity (number, optional): Maximum shake distance (default: 5)
-- @param duration (number, optional): Total shake duration (default: 0.5)
-- @param frequency (number, optional): Oscillations per second (default: 15)
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:shake_widget(intensity, duration, frequency, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.shake_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.shake_widget: AnimationEngine not available")
        if user_on_complete then
            user_on_complete({shake_completed = true}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.shake_widget: %s intensity %f, duration %f", 
               self.id, intensity or 5, duration or 0.5)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("shake")
    
    -- Set animation flags
    self:_set_animation_flags("shake")
    
    -- Use AnimationEngine.shake (direct method) or AnimationSequences.shake
    local anim_id = nil
    local shake_func = AnimationEngine.shake
    
    if shake_func then
        anim_id = shake_func(self, {
            intensity = intensity,
            duration = duration,
            frequency = frequency,
            on_complete = function(values, interrupted)
                self:_handle_animation_completion(
                    {shake_completed = true},
                    interrupted,
                    user_on_complete,
                    "shake"
                )
            end,
            on_update = function(values)
                -- Update child widgets to maintain relative positions with shake
                self:_update_child_widgets_for_animation()
            end
        })
    else
        debug_print("WARN", "Widget.shake_widget: shake function not available, using legacy implementation")
        -- Keep legacy implementation as fallback
        return self:_legacy_shake_widget(intensity, duration, frequency, user_on_complete)
    end
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.shake_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a color pulse animation using AnimationEngine.Sequences.color_pulse
-- @param start_color (table, optional): Starting color {r,g,b,a} (default: current color)
-- @param target_color (table, optional): Target color {r,g,b,a} (default: different hue)
-- @param duration (number, optional): Color transition duration (default: 0.8)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @param loop (boolean, optional): Whether to loop continuously (default: true)
-- @param ping_pong (boolean, optional): Whether to reverse direction each cycle (default: true)
-- @return (string): Animation ID, or nil if failed
function Widget:color_pulse_widget(start_color, target_color, duration, easing, user_on_complete, loop, ping_pong)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.color_pulse_widget: AnimationEngine not available")
        if target_color then
            self:setColor(target_color.r or 255, target_color.g or 255, 
                         target_color.b or 255, target_color.a or 255)
        end
        if user_on_complete then
            user_on_complete({color_pulse_completed = true}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.color_pulse_widget: %s color pulse animation", self.id)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("color_pulse")
    
    -- Set animation flags
    self:_set_animation_flags("color_pulse")
    
    -- Prepare colors
    local current_color = {
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        a = self.a or 255
    }
    
    start_color = start_color or current_color
    target_color = target_color or {
        r = math.min(255, (start_color.r or 255) + 50),
        g = math.min(255, (start_color.g or 255) + 50),
        b = math.min(255, (start_color.b or 255) + 50),
        a = start_color.a or 255
    }
    
    -- Use AnimationEngine.color_pulse (direct method) or AnimationSequences.color_pulse
    local anim_id = nil
    local color_pulse_func = AnimationEngine.color_pulse
    
    if color_pulse_func then
        anim_id = color_pulse_func(self, start_color, target_color, {
            duration = duration,
            easing = easing,
            loop = loop,
            ping_pong = ping_pong,
            on_complete = function(values, interrupted)
                self:_handle_animation_completion(values, interrupted, user_on_complete, "color_pulse")
            end,
            on_update = function(values)
                -- Update child widgets to maintain relative colors
                self:_update_child_widgets_for_animation()
            end
        })
    else
        debug_print("WARN", "Widget.color_pulse_widget: color_pulse function not available, using animate")
        anim_id = AnimationEngine.animate(
            {
                r = start_color.r or 255,
                g = start_color.g or 255,
                b = start_color.b or 255,
                a = start_color.a or 255
            },
            {
                r = target_color.r or 255,
                g = target_color.g or 255,
                b = target_color.b or 255,
                a = target_color.a or 255
            },
            duration or 0.8,
            {
                easing = easing or "ease_in_out",
                loop = loop ~= false,
                ping_pong = ping_pong ~= false,
                on_update = function(values)
                    self:setColor(values.r, values.g, values.b, values.a)
                    self:_update_child_widgets_for_animation()
                end,
                on_complete = function(values, interrupted)
                    self:_handle_animation_completion(values, interrupted, user_on_complete, "color_pulse")
                end
            }
        )
    end
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.color_pulse_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a slide animation using AnimationEngine.Sequences.slideIn
-- @param target_x (number): Target X position
-- @param target_y (number): Target Y position
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "linear")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:slide_widget(target_x, target_y, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.slide_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.slide_widget: AnimationEngine not available")
        self:setPosition(target_x, target_y)
        if user_on_complete then
            user_on_complete({x = target_x, y = target_y}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.slide_widget: %s to (%g,%g) in %f seconds", 
               self.id, target_x, target_y, duration or 0.3)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("slide")
    
    -- Set animation flags
    self:_set_animation_flags("slide")
    
    -- Use animate_widget for sliding
    local anim_id = AnimationEngine.animate_widget(self, {
        x = target_x,
        y = target_y
    }, duration or 0.3, {
        easing = easing or "linear",
        on_update = function(values)
            self:_update_child_widgets_for_animation()
        end,
        on_complete = function(values, interrupted)
            self:_handle_animation_completion(values, interrupted, user_on_complete, "slide")
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.slide_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a fade animation using AnimationEngine.Sequences.fade
-- @param target_alpha (number): Target alpha value (0-255)
-- @param duration (number, optional): Fade duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:set_opacity_widget(target_alpha, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_opacity_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.set_opacity_widget: AnimationEngine not available")
        self:setOpacity(target_alpha)
        if user_on_complete then
            user_on_complete({opacity = target_alpha}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.set_opacity_widget: %s to opacity %d", 
               self.id, target_alpha)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("fade")
    
    -- Set animation flags
    self:_set_animation_flags("fade")
    
    -- Use animate_widget for opacity
    local anim_id = AnimationEngine.animate_widget(self, {
        opacity = target_alpha
    }, duration or 0.3, {
        easing = easing or "ease_in_out",
        on_update = function(values)
            -- Update child widgets to maintain relative opacity
            self:_update_child_widgets_for_animation()
        end,
        on_complete = function(values, interrupted)
            self:_handle_animation_completion(values, interrupted, user_on_complete, "fade")
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.set_opacity_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a rotate animation using AnimationEngine
-- @param target_rotation (number): Target rotation in degrees
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:rotate_widget(target_rotation, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.rotate_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.rotate_widget: AnimationEngine not available")
        self:setRotation(target_rotation)
        if user_on_complete then
            user_on_complete({ro = target_rotation}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.rotate_widget: %s to rotation %f", 
               self.id, target_rotation)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("rotate")
    
    -- Set animation flags
    self:_set_animation_flags("rotate")
    
    -- Use animate_widget for rotation
    local anim_id = AnimationEngine.animate_widget(self, {
        ro = target_rotation
    }, duration or 0.3, {
        easing = easing or "ease_in_out",
        on_update = function(values)
            -- Update child widgets to maintain relative rotation
            self:_update_child_widgets_for_animation()
        end,
        on_complete = function(values, interrupted)
            self:_handle_animation_completion(values, interrupted, user_on_complete, "rotate")
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.rotate_widget: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Create a menu cursor animation using AnimationEngine.Sequences.menu_cursor
-- @param bob_distance (number, optional): Vertical bobbing distance (default: 2)
-- @param pulse_scale (number, optional): Maximum scale during pulse (default: 1.1)
-- @param bob_duration (number, optional): Bob cycle duration (default: 0.8)
-- @param pulse_duration (number, optional): Pulse cycle duration (default: 1.2)
-- @param orientation (string, optional): "vertical" or "horizontal" (default: "vertical")
-- @param easing (string, optional): Easing function name (default: "smootherstep")
-- @param back_easing (string, optional): Return easing function (default: "smootherstep")
-- @param user_on_complete (function, optional): Callback when animation completes/stops
-- @return (table): Animation controller with stop function: {bob=id1, pulse=id2, stop=function}
function Widget:menu_cursor_widget(bob_distance, pulse_scale, bob_duration, pulse_duration, 
                                  orientation, easing, back_easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.menu_cursor_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.menu_cursor_widget: AnimationEngine not available")
        if user_on_complete then
            user_on_complete({menu_cursor_completed = true}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.menu_cursor_widget: %s menu cursor animation", self.id)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("menu_cursor")
    
    -- Set animation flags
    self:_set_animation_flags("menu_cursor")
    
    -- Use AnimationEngine.menu_cursor (direct method) or AnimationSequences.menu_cursor
    local cursor_func = AnimationEngine.menu_cursor
    local controller = nil
    
    if cursor_func then
        controller = cursor_func(self, {
            bob_distance = bob_distance,
            pulse_scale = pulse_scale,
            bob_duration = bob_duration,
            pulse_duration = pulse_duration,
            orientation = orientation,
            easing = easing,
            back_easing = back_easing,
            on_complete = function(values)
                self:_handle_animation_completion(values, false, user_on_complete, "menu_cursor")
            end
        })
        
        if controller and controller.bob then
            self.active_animations[controller.bob] = true
        end
        if controller and controller.pulse then
            self.active_animations[controller.pulse] = true
        end
        
        -- Wrap the stop function to clean up our tracking
        if controller and controller.stop then
            local original_stop = controller.stop
            controller.stop = function()
                if controller.bob then
                    self.active_animations[controller.bob] = nil
                end
                if controller.pulse then
                    self.active_animations[controller.pulse] = nil
                end
                original_stop()
                self:_clear_animation_flags()
                self:_unmark_sprites_after_animation()
            end
        end
    else
        debug_print("WARN", "Widget.menu_cursor_widget: menu_cursor function not available")
        -- Fallback to separate bob and pulse animations
        local bob_id = self:bob_widget(bob_distance, bob_duration, easing, true, true)
        local pulse_id = self:pulse_scale_widget(1.0, pulse_scale, pulse_duration, "ease_in_out", true, true)
        
        controller = {
            bob = bob_id,
            pulse = pulse_id,
            stop = function()
                self:stop_animation(bob_id)
                self:stop_animation(pulse_id)
                self:_clear_animation_flags()
                self:_unmark_sprites_after_animation()
                if user_on_complete then
                    user_on_complete({stopped = true}, true)
                end
            end
        }
    end
    
    debug_print("INFO", "Widget.menu_cursor_widget: Menu cursor animation started")
    return controller
end

--- Legacy implementation fallback for shake animation
function Widget:_legacy_shake_widget(intensity, duration, frequency, user_on_complete)
    -- Keep the original shake implementation as fallback
    intensity = intensity or 5
    duration = duration or 0.5
    frequency = frequency or 15
    
    local start_x = self.x
    local start_y = self.y
    
    -- Store starting positions
    local sprite_start_positions = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        local props = sprite:get_properties()
        sprite_start_positions[sprite_id] = {
            x = props.x,
            y = props.y
        }
        sprite:set_widget_animated(true, {type = "shake"})
    end
    
    -- Store child widget positions
    local child_widget_start_positions = {}
    for _, child_widget in pairs(self._child_widgets) do
        child_widget_start_positions[child_widget.id] = {
            x = child_widget.x,
            y = child_widget.y
        }
        child_widget._layout_animation_active = true
        child_widget._layout_animation_type = "shake"
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        -- Fallback without animation
        self:_unmark_sprites_after_animation()
        if user_on_complete then
            user_on_complete({shake_completed = true}, false)
        end
        return nil
    end
    
    self._layout_animation_active = true
    self._layout_animation_type = "shake"
    
    local anim_id = AnimationEngine.animate(
        {t = 0},
        {t = 1},
        duration,
        {
            easing = "linear",
            on_update = function(values)
                local t = values.t
                local elapsed_time = t * duration
                
                local shake_x = math.sin(elapsed_time * frequency * math.pi * 2) * intensity * (1 - t)
                local shake_y = math.cos(elapsed_time * frequency * math.pi * 2) * intensity * (1 - t)
                
                self.x = start_x + shake_x
                self.y = start_y + shake_y
                
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local start_pos = sprite_start_positions[sprite_id]
                    if start_pos then
                        sprite.properties.x = self.x + (start_pos.x - start_x)
                        sprite.properties.y = self.y + (start_pos.y - start_y)
                        sprite:draw()
                    end
                end
                
                for _, child_widget in pairs(self._child_widgets) do
                    local start_pos = child_widget_start_positions[child_widget.id]
                    if start_pos then
                        child_widget.x = start_pos.x + shake_x
                        child_widget.y = start_pos.y + shake_y
                        child_widget:updateLayout(false)
                    end
                end
            end,
            on_complete = function(values, interrupted)
                self.x = start_x
                self.y = start_y
                
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                for _, child_widget in pairs(self._child_widgets) do
                    local start_pos = child_widget_start_positions[child_widget.id]
                    if start_pos then
                        child_widget.x = start_pos.x
                        child_widget.y = start_pos.y
                    end
                    child_widget._layout_animation_active = false
                    child_widget._layout_animation_type = nil
                end
                
                self:updateLayout(true)
                
                if user_on_complete then
                    user_on_complete({shake_completed = true}, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

--- Complex summon animation with multiple steps
-- @param start_x (number): Starting X position
-- @param start_y (number): Starting Y position
-- @param start_scale (number): Starting scale factor
-- @param end_x (number): Target X position
-- @param end_y (number): Target Y position
-- @param end_scale (number): Target scale factor
-- @param arc_duration (number, optional): Duration of arc movement phase (default: 0.25)
-- @param wobble_duration (number, optional): Duration of wobble phase (default: 0.1)
-- @param settle_duration (number, optional): Duration of settle phase (default: 0.05)
-- @param arc_height (number, optional): Height of arc curve (default: 40)
-- @param peak_scale_mul (number, optional): Scale multiplier at peak (default: 1.35)
-- @param wobble_deg (number, optional): Maximum rotation wobble (default: 10)
-- @param easing (string, optional): Base easing function (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @param on_update_step1 (function, optional): Callback during arc phase
-- @param on_update_step2 (function, optional): Callback during wobble phase
-- @param on_update_step3 (function, optional): Callback during settle phase
-- @return (string): Sequence ID, or nil if failed
function Widget:complex_summon_widget(start_x, start_y, start_scale, end_x, end_y, end_scale,
                                     arc_duration, wobble_duration, settle_duration, arc_height,
                                     peak_scale_mul, wobble_deg, easing, user_on_complete,
                                     on_update_step1, on_update_step2, on_update_step3)
    if not self then
        debug_print("ERROR", "Widget.complex_summon_widget: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.complex_summon_widget: AnimationEngine not available")
        self:setPosition(end_x, end_y)
        self:setScale(end_scale, end_scale)
        if user_on_complete then
            user_on_complete({x = end_x, y = end_y, sx = end_scale, sy = end_scale}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.complex_summon_widget: %s from (%g,%g) to (%g,%g)", 
               self.id, start_x, start_y, end_x, end_y)
    
    -- Set starting position and scale
    self:setPosition(start_x, start_y)
    self:setScale(start_scale, start_scale)
    self:setRotation(0)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("complex_summon")
    
    -- Set animation flags
    self:_set_animation_flags("complex_summon")
    
    -- Use AnimationEngine.complex_summon (direct method) or AnimationSequences.complex_summon
    local complex_summon_func = AnimationEngine.complex_summon
    
    if complex_summon_func then
        local seq_id = complex_summon_func(self, start_x, start_y, start_scale, 
                                         end_x, end_y, end_scale,
                                         {
            arc_duration = arc_duration,
            wobble_duration = wobble_duration,
            settle_duration = settle_duration,
            arc_height = arc_height,
            peak_scale_mul = peak_scale_mul,
            wobble_deg = wobble_deg,
            easing = easing,
            on_complete = function(values, interrupted)
                self:_handle_animation_completion(
                    {x = end_x, y = end_y, sx = end_scale, sy = end_scale},
                    interrupted,
                    user_on_complete,
                    "complex_summon"
                )
            end,
            on_update_step1 = on_update_step1,
            on_update_step2 = on_update_step2,
            on_update_step3 = on_update_step3
        })
        
        if seq_id then
            self.active_sequences[seq_id] = true
        end
        
        return seq_id
    else
        debug_print("WARN", "Widget.complex_summon_widget: complex_summon function not available, using regular summon")
        -- Fallback to regular summon
        return self:summon_widget(start_x, start_y, start_scale, end_x, end_y, end_scale,
                                 arc_duration, arc_height, peak_scale_mul, wobble_deg, easing, user_on_complete)
    end
end

--- Move widget by offset (convenience wrapper for slide_widget)
-- @param offset_x (number): X offset to move
-- @param offset_y (number): Y offset to move
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:move_widget(offset_x, offset_y, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.move_widget: Invalid widget")
        return nil
    end
    
    -- Calculate target position
    local target_x = self.x + offset_x
    local target_y = self.y + offset_y
    
    debug_print("INFO", "Widget.move_widget: %s by (%g,%g) to (%g,%g)", 
               self.id, offset_x, offset_y, target_x, target_y)
    
    return self:slide_widget(target_x, target_y, duration, easing, on_complete)
end

--- Animate widget properties using AnimationEngine.animate_widget
-- @param properties (table): Target properties {x, y, sx, sy, ro, opacity, r, g, b, a}
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param options (table, optional): Animation options:
--   - easing (string): Easing function name
--   - on_update (function): Callback during animation
--   - on_complete (function): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:animate_properties(properties, duration, options)
    if not self then
        debug_print("ERROR", "Widget.animate_properties: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
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
        if options and options.on_complete then
            options.on_complete(properties, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.animate_properties: %s animating properties", self.id)
    
    -- Mark sprites for animation
    self:_mark_sprites_for_animation("properties")
    
    -- Set animation flags
    self:_set_animation_flags("properties")
    
    -- Use animate_widget
    local anim_id = AnimationEngine.animate_widget(self, properties, duration or 0.3, {
        easing = options and options.easing or "ease_in_out",
        on_update = options and options.on_update,
        on_complete = function(values, interrupted)
            self:_handle_animation_completion(values, interrupted, 
                                            options and options.on_complete, "properties")
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
        debug_print("INFO", "Widget.animate_properties: Animation started with ID %s", anim_id)
    end
    
    return anim_id
end

--- Scale widget using AnimationEngine
-- @param target_scale (number): Target scale factor
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:scale_widget(target_scale, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.scale_widget: Invalid widget")
        return nil
    end
    
    debug_print("INFO", "Widget.scale_widget: %s to scale %f", self.id, target_scale)
    
    return self:animate_properties({
        sx = target_scale,
        sy = target_scale
    }, duration or 0.3, {
        easing = easing or "ease_in_out",
        on_complete = user_on_complete
    })
end

--- Transform widget with multiple properties
-- @param properties (table): Target properties for transformation
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:transform_widget(properties, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.transform_widget: Invalid widget")
        return nil
    end
    
    debug_print("INFO", "Widget.transform_widget: %s transforming with properties", self.id)
    
    return self:animate_properties(properties, duration or 0.3, {
        easing = easing or "ease_in_out",
        on_complete = user_on_complete
    })
end

--- Set widget properties instantly (no animation)
-- @param properties (table): Properties to set {x, y, sx, sy, ro, opacity, r, g, b, a, visible}
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

--- Reset widget to initial state
-- @param initial_values (table, optional): Initial values to reset to (defaults to common properties)
-- @param user_on_complete (function, optional): Callback when reset completes
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

--- Simple color pulse with RGB values
-- @param start_r (number, optional): Starting red value (0-255, default: current)
-- @param start_g (number, optional): Starting green value (0-255, default: current)
-- @param start_b (number, optional): Starting blue value (0-255, default: current)
-- @param start_a (number, optional): Starting alpha value (0-255, default: current)
-- @param target_r (number, optional): Target red value (0-255, default: start_r)
-- @param target_g (number, optional): Target green value (0-255, default: start_g)
-- @param target_b (number, optional): Target blue value (0-255, default: start_b)
-- @param target_a (number, optional): Target alpha value (0-255, default: start_a)
-- @param duration (number, optional): Color transition duration (default: 0.8)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
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

--- Color pulse from current color to target
-- @param target_color (table): Target color {r,g,b,a}
-- @param duration (number, optional): Color transition duration (default: 0.8)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (string): Animation ID, or nil if failed
function Widget:color_pulse_from_current(target_color, duration, easing, user_on_complete)
    local current_color = {
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        a = self.a or 255
    }
    
    return self:color_pulse_widget(current_color, target_color, duration, easing, user_on_complete)
end

--- Swap two sprites and animate their positions
-- @param sprite1_id (string): First sprite ID
-- @param sprite2_id (string): Second sprite ID
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param user_on_complete (function, optional): Callback when animation completes
-- @return (table): Animation IDs {anim1=id1, anim2=id2}, or nil if failed
function Widget:swap_and_animate_sprites(sprite1_id, sprite2_id, duration, easing, user_on_complete)
    if not self then
        debug_print("ERROR", "Widget.swap_and_animate_sprites: Invalid widget")
        return nil
    end
    
    local AnimationEngine = self:_load_animation_engine()
    if not AnimationEngine then
        debug_print("WARN", "Widget.swap_and_animate_sprites: AnimationEngine not available")
        -- Swap positions directly
        local sprite1 = self.sprite_objects[sprite1_id]
        local sprite2 = self.sprite_objects[sprite2_id]
        if sprite1 and sprite2 then
            local temp_x, temp_y = sprite1.properties.x, sprite1.properties.y
            sprite1:set_position(sprite2.properties.x, sprite2.properties.y)
            sprite2:set_position(temp_x, temp_y)
        end
        if user_on_complete then
            user_on_complete({sprite1 = sprite1_id, sprite2 = sprite2_id, success = true}, false)
        end
        return nil
    end
    
    debug_print("INFO", "Widget.swap_and_animate_sprites: Swapping %s and %s in %s", 
               sprite1_id, sprite2_id, self.id)
    
    -- Get sprite objects
    local sprite1 = self.sprite_objects[sprite1_id]
    local sprite2 = self.sprite_objects[sprite2_id]
    
    if not sprite1 or not sprite2 then
        debug_print("ERROR", "  One or both sprites not found: %s, %s", sprite1_id, sprite2_id)
        if user_on_complete then
            user_on_complete({success = false, reason = "sprites_not_found"}, false)
        end
        return nil
    end
    
    -- Get current positions
    local pos1 = {x = sprite1.properties.x, y = sprite1.properties.y}
    local pos2 = {x = sprite2.properties.x, y = sprite2.properties.y}
    
    -- Mark sprites as widget-animated
    sprite1:set_widget_animated(true, {type = "swap"})
    sprite2:set_widget_animated(true, {type = "swap"})
    local anim_id1 = nil
    local anim_id2 = nil
    -- Track completion
    local animations_completed = 0
    
    local function check_completion()
        animations_completed = animations_completed + 1
        if animations_completed >= 2 then
            -- Clean up animation tracking
            if anim_id1 then
                self.active_animations[anim_id1] = nil
            end
            if anim_id2 then
                self.active_animations[anim_id2] = nil
            end
            
            -- Unmark sprites
            sprite1:set_widget_animated(false)
            sprite2:set_widget_animated(false)
            
            if user_on_complete then
                user_on_complete({sprite1 = sprite1_id, sprite2 = sprite2_id, success = true}, false)
            end
        end
    end
    
    -- Animate both sprites with on_complete callbacks
    local anim_id1 = AnimationEngine.animate(
        {x = pos1.x, y = pos1.y},
        {x = pos2.x, y = pos2.y},
        duration or 0.3,
        {
            easing = easing or "ease_in_out",
            on_update = function(values)
                sprite1:set_position(values.x, values.y)
            end,
            on_complete = check_completion
        }
    )
    
    local anim_id2 = AnimationEngine.animate(
        {x = pos2.x, y = pos2.y},
        {x = pos1.x, y = pos1.y},
        duration or 0.3,
        {
            easing = easing or "ease_in_out",
            on_update = function(values)
                sprite2:set_position(values.x, values.y)
            end,
            on_complete = check_completion
        }
    )
    
    -- Track animations
    if anim_id1 then
        self.active_animations[anim_id1] = true
    end
    if anim_id2 then
        self.active_animations[anim_id2] = true
    end
    
    return {anim1 = anim_id1, anim2 = anim_id2}
end

--- Swap two child widgets and animate their positions
-- @param widget1_id (string): First widget ID
-- @param widget2_id (string): Second widget ID
-- @param duration (number, optional): Animation duration (default: 0.3)
-- @param easing (string, optional): Easing function name (default: "ease_in_out")
-- @param on_complete (function, optional): Callback when animation completes
-- @return (table): Animation IDs {widget1_anim=id1, widget2_anim=id2}, or nil if failed
function Widget:swap_and_animate_child_widgets(widget1_id, widget2_id, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.swap_and_animate_child_widgets: Invalid widget")
        return nil
    end
    
    -- Find child widgets
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
        debug_print("ERROR", "  One or both child widgets not found")
        if on_complete then on_complete({success = false, reason = "not_found"}, false) end
        return nil
    end
    
    -- Store current positions
    local pos1 = {x = widget1.x, y = widget1.y}
    local pos2 = {x = widget2.x, y = widget2.y}
    
    -- Swap in children array
    self.children[index1], self.children[index2] = self.children[index2], self.children[index1]
    
    -- Update layout to calculate new positions
    self:updateLayout(true)
    
    -- Get new positions
    local new_pos1 = {x = widget1.x, y = widget1.y}
    local new_pos2 = {x = widget2.x, y = widget2.y}
    
    -- Temporarily set back to original positions
    widget1:setPosition(pos1.x, pos1.y)
    widget2:setPosition(pos2.x, pos2.y)
    
    -- Set animation flags
    widget1._layout_animation_active = true
    widget1._layout_animation_type = "widget_swap"
    widget2._layout_animation_active = true
    widget2._layout_animation_type = "widget_swap"
    
    -- Animate both widgets
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
        end
    end
    
    -- Animate widget1
    widget1:slide_widget(new_pos1.x, new_pos1.y, duration or 0.3, easing or "ease_in_out", function()
        check_completion()
    end)
    
    -- Animate widget2
    widget2:slide_widget(new_pos2.x, new_pos2.y, duration or 0.3, easing or "ease_in_out", function()
        check_completion()
    end)
    
    return {widget1_anim = widget1.id, widget2_anim = widget2.id}
end

-- ==============================
-- Animation Control Methods
-- ==============================

--- Stop a specific animation
-- @param anim_id (string): Animation ID to stop (if nil, stops all animations)
function Widget:stop_animation(anim_id)
    if anim_id then
        local AnimationEngine = self:_load_animation_engine()
        if AnimationEngine then
            AnimationEngine.stop_animation(anim_id)
        end
        self.active_animations[anim_id] = nil
        self.active_sequences[anim_id] = nil
        debug_print("DETAILED", "Widget.stop_animation: Stopped animation %s", anim_id)
    else
        -- Stop all animations
        self:stop_all_animations()
    end
end

--- Stop all animations on this widget and its children
function Widget:stop_all_animations()
    debug_print("INFO", "Widget.stop_all_animations: Stopping all animations for %s", self.id)
    
    -- Stop animations through AnimationEngine
    local AnimationEngine = self:_load_animation_engine()
    if AnimationEngine then
        for id, _ in pairs(self.active_animations) do
            AnimationEngine.stop_animation(id)
        end
        for id, _ in pairs(self.active_sequences) do
            AnimationEngine.stop_sequence(id)
        end
    end
    
    -- Clear tracking
    self.active_animations = {}
    self.active_sequences = {}
    
    -- Clear animation flags
    self:_clear_animation_flags()
    
    -- Unmark sprites
    self:_unmark_sprites_after_animation()
    
    -- Stop animations on child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:stop_all_animations()
    end
    
    -- Stop animations on sprites
    for _, sprite in pairs(self.sprite_objects) do
        sprite:stop_animation()
    end
    
    debug_print("DETAILED", "  All animations stopped for widget %s", self.id)
end

--- Check if widget has active animations
-- @return (boolean): True if any animations are active
function Widget:is_animating()
    if next(self.active_animations) ~= nil or next(self.active_sequences) ~= nil then
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

--- Check if widget has active animations (alias for is_animating)
-- @return (boolean): True if any animations are active
function Widget:has_active_animations()
    return self:is_animating()
end

--- Check if specific animation is running
-- @param anim_id (string): Animation ID to check (if nil, checks if any animation is running)
-- @return (boolean): True if animation is running
function Widget:is_animation_running(anim_id)
    if not anim_id then
        return self:is_animating()
    end
    
    if self.active_animations[anim_id] or self.active_sequences[anim_id] then
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

-- ==============================
-- Destruction and Cleanup
-- ==============================

--- Proper destruction with cache cleanup
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

-- ==============================
-- Utility Methods
-- ==============================

function Widget:getCalculatedSize()
    debug_print("VERBOSE", "Widget.getCalculatedSize: %s = %gx%g", 
               self.id, self._calculated_size.width, self._calculated_size.height)
    
    return self._calculated_size.width, self._calculated_size.height
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

return Widget