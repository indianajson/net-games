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
    self.sy = sy or sx or self.sy
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
                                   texture_path, anim_path, anim_state, layout_width, layout_height)
    
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
    
    debug_print("INFO", "Widget.create_sprite: %s added to widget %s with layout dimensions %gx%g", 
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

function Widget:addChild(child)
    if child then
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
            
            debug_print("DETAILED", "Widget.addChild: Added sprite %s to widget %s with layout %gx%g", 
                       sprite.id, self.id, child.layout_width or 0, child.layout_height or 0)
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
    
    -- Mark sprites as widget-animated
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "scale"})
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.scale_widget: AnimationEngine not available, setting scale directly")
        self:setScale(target_scale, target_scale)
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({sx = target_scale, sy = target_scale}, false)
        end
        return nil
    end
    
    -- Animation engine is available
    self._layout_animation_active = true
    self._layout_animation_type = "scale"
    
    local anim_id = AnimationEngine.animate(
        {sx = current_scale, sy = current_scale},
        {sx = target_scale, sy = target_scale},
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget scale
                self.sx = values.sx
                self.sy = values.sy
                
                -- Update all sprites with new scale
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_scale(values.sx, values.sy)
                end
            end,
            on_complete = function(values, interrupted)
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Unmark all sprites
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
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
    
    -- Mark sprites as widget-animated
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "rotation"})
    end
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "Widget.rotate_widget: AnimationEngine not available, setting rotation directly")
        self:setRotation(target_rotation)
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if user_on_complete then
            user_on_complete({ro = target_rotation}, false)
        end
        return nil
    end
    
    -- Animation engine is available
    self._layout_animation_active = true
    self._layout_animation_type = "rotation"
    
    local anim_id = AnimationEngine.animate(
        {ro = current_rotation},
        {ro = target_rotation},
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget rotation
                self.ro = values.ro
                
                -- Update all sprites with new rotation
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_rotation(values.ro)
                end
            end,
            on_complete = function(values, interrupted)
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Unmark all sprites
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                if user_on_complete then
                    user_on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
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

-- Modified updateLayout to handle screen constraints
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
            
            debug_print("DETAILED", "  Child %d: type=%s, widget-relative=(%g,%g), layout=(%g,%g), abs_parent=(%g,%g)",
                       i, child.sprite_id and "sprite" or "widget", 
                       child_widget_x, child_widget_y, child.x, child.y,
                       self.x, self.y)
            
            if child.sprite_id then
                -- Update sprite position (using widget-relative coordinates in screen space)
                local sprite = self.sprite_objects[child.sprite_id]
                if sprite then
                    -- Check if sprite is being animated by widget
                    if not sprite:is_widget_animated() then
                        -- Only set sprite position if it's not being animated
                        sprite:set_position(child_widget_x, child_widget_y)
                        debug_print("DETAILED", "    Sprite %s positioned at widget-relative (%g,%g) in widget %s (abs=%g,%g)", 
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
    options = options or {}  -- Ensure options is always a table
    
    -- Mark sprites as widget-animated
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "properties"})
    end
    
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
            self:setColor(properties.r or self.r, properties.g or self.g, properties.b or self.b, properties.a or self.a)
        end
        
        -- Unmark sprites
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite:set_widget_animated(false)
        end
        
        if options.on_complete then
            options.on_complete(properties, false)
        end
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
    
    self._layout_animation_active = true
    self._layout_animation_type = "properties"
    
    local anim_id = nil
    anim_id = AnimationEngine.animate(start_properties, target_properties, duration, {
        easing = options.easing or "ease_in_out",
        on_update = function(values)
            if values.x or values.y then
                self.x = values.x or self.x
                self.y = values.y or self.y
                
                -- Update sprite positions
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_position(values.x or self.x, values.y or self.y)
                end
            end
            if values.sx or values.sy then
                self.sx = values.sx or self.sx
                self.sy = values.sy or self.sy
                
                -- Update sprite scales
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_scale(values.sx or self.sx, values.sy or self.sy)
                end
            end
            if values.ro then
                self.ro = values.ro
                
                -- Update sprite rotations
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_rotation(values.ro)
                end
            end
            if values.opacity then
                self.opacity = values.opacity
                
                -- Update sprite opacity
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_opacity(values.opacity)
                end
            end
            if values.r or values.g or values.b or values.a then
                self.r = values.r or self.r
                self.g = values.g or self.g
                self.b = values.b or self.b
                self.a = values.a or self.a
                
                -- Update sprite colors
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_color(values.r or self.r, values.g or self.g, values.b or self.b, values.a or self.a)
                end
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