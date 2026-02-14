--[[
    Widget Framework Core for Pure Sprite Widget Framework
    Central widget registry and management API
]]

local WidgetFramework = {}
WidgetFramework.__index = WidgetFramework

function WidgetFramework.new()
    local self = setmetatable({}, WidgetFramework)
    
    -- Initialize managers
    self.sprite_manager = nil  -- Will be set in initialize
    self.animation_manager = nil  -- Will be set in initialize
    
    -- Widget registry: [player_id][widget_id] = widget_object
    self.widget_registry = {}
    
    -- Player widget trees: [player_id] = {root_widget_ids}
    self.widget_trees = {}
    
    -- Event registry: [player_id][event_type][widget_id] = callback
    self.event_registry = {}
    
    -- Dirty widgets queue for rendering optimization
    self.dirty_widgets = {}
    
    -- Widget ID counter
    self.next_widget_id = 1
    
    -- Event types
    self.EVENT_TYPES = {
        TAP = "tap",
        HOVER_ENTER = "hover_enter",
        HOVER_LEAVE = "hover_leave",
        NAVIGATE = "navigate",
        FOCUS = "focus",
        BLUR = "blur"
    }
    
    return self
end

-- Initialize framework with managers
WidgetFramework.initialize = function(sprite_manager, animation_manager)
    if not sprite_manager or not animation_manager then
        return false, "Missing required managers"
    end
    
    WidgetFramework.sprite_manager = sprite_manager
    WidgetFramework.animation_manager = animation_manager
    
    return true
end

-- Generate unique widget ID
function WidgetFramework:_generateWidgetId(prefix)
    local id = (prefix or "widget") .. "_" .. self.next_widget_id
    self.next_widget_id = self.next_widget_id + 1
    return id
end

-- Create a widget
function WidgetFramework:createWidget(player_id, widget_id, widget_type, properties, parent_id)
    if not player_id or not widget_type then
        return nil, "Missing required parameters"
    end
    
    -- Generate widget ID if not provided
    if not widget_id then
        widget_id = self:_generateWidgetId(widget_type)
    end
    
    -- Check if widget already exists
    if self.widget_registry[player_id] and self.widget_registry[player_id][widget_id] then
        return self.widget_registry[player_id][widget_id], "Widget already exists"
    end
    
    -- Create widget instance based on type
    local widget = nil
    local error_msg = nil
    
    if widget_type == "sprite" then
        widget = SpriteWidget.new(player_id, widget_id, properties)
    elseif widget_type == "text_sprite" then
        widget = TextSpriteWidget.new(player_id, widget_id, properties)
    elseif widget_type == "container" then
        widget = ContainerWidget.new(player_id, widget_id, properties)
    else
        return nil, "Invalid widget type: " .. tostring(widget_type)
    end
    
    if not widget then
        return nil, "Failed to create widget"
    end
    
    -- Initialize player registry if needed
    if not self.widget_registry[player_id] then
        self.widget_registry[player_id] = {}
        self.widget_trees[player_id] = {}
        self.event_registry[player_id] = {}
        self.dirty_widgets[player_id] = {}
    end
    
    -- Store widget in registry
    self.widget_registry[player_id][widget_id] = widget
    
    -- Set parent if specified
    if parent_id then
        local parent = self.widget_registry[player_id][parent_id]
        if parent then
            parent:addChild(widget)
        else
            widget.properties.parent = parent_id
            widget.parent = parent_id
        end
    else
        -- Add to root widget tree
        table.insert(self.widget_trees[player_id], widget_id)
    end
    
    return widget, nil
end

-- Build a widget (create sprites)
function WidgetFramework:buildWidget(player_id, widget_id)
    if not player_id or not widget_id then
        return false, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return false, "Widget not found"
    end
    
    local success, error = widget:build()
    if success then
        self:markWidgetDirty(player_id, widget_id)
        
        -- If it's a container, build all children
        if widget.type == "container" then
            for _, child_id in ipairs(widget.children) do
                self:buildWidget(player_id, child_id)
            end
        end
    end
    
    return success, error
end

-- Update widget properties
function WidgetFramework:updateWidget(player_id, widget_id, new_properties)
    if not player_id or not widget_id then
        return false, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return false, "Widget not found"
    end
    
    local success, error = widget:update(new_properties)
    if success then
        self:markWidgetDirty(player_id, widget_id)
        
        -- If it's a container and layout properties changed, update layout
        if widget.type == "container" then
            local layout_props = {"layout", "spacing", "padding"}
            for _, prop in ipairs(layout_props) do
                if new_properties[prop] ~= nil then
                    widget:updateLayout(self.widget_registry[player_id])
                    break
                end
            end
        end
    end
    
    return success, error
end

-- Render a widget (update sprites)
function WidgetFramework:renderWidget(player_id, widget_id)
    if not player_id or not widget_id then
        return false, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return false, "Widget not found"
    end
    
    local success, error = widget:render(self.sprite_manager)
    if success then
        self:clearWidgetDirty(player_id, widget_id)
    end
    
    return success, error
end

-- Render all dirty widgets for a player
function WidgetFramework:renderDirtyWidgets(player_id)
    if not player_id or not self.dirty_widgets[player_id] then
        return 0
    end
    
    local rendered_count = 0
    for widget_id, _ in pairs(self.dirty_widgets[player_id]) do
        if self:renderWidget(player_id, widget_id) then
            rendered_count = rendered_count + 1
        end
    end
    
    return rendered_count
end

-- Dispose of a widget
function WidgetFramework:disposeWidget(player_id, widget_id, dispose_children)
    if not player_id or not widget_id then
        return false, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return false, "Widget not found"
    end
    
    -- Dispose children first if requested
    if dispose_children then
        for _, child_id in ipairs(widget.children) do
            self:disposeWidget(player_id, child_id, true)
        end
    else
        -- Remove from parent
        if widget.parent then
            local parent = self:getWidget(player_id, widget.parent)
            if parent then
                parent:removeChild(widget_id)
            end
        else
            -- Remove from root tree
            local root_tree = self.widget_trees[player_id]
            if root_tree then
                for i, root_id in ipairs(root_tree) do
                    if root_id == widget_id then
                        table.remove(root_tree, i)
                        break
                    end
                end
            end
        end
    end
    
    -- Stop all animations for this widget
    self.animation_manager:stopWidgetAnimations(player_id, widget_id, true)
    
    -- Dispose widget resources
    local success, error = widget:dispose(self.sprite_manager)
    
    -- Remove from registry
    if success then
        if self.widget_registry[player_id] then
            self.widget_registry[player_id][widget_id] = nil
        end
        
        if self.dirty_widgets[player_id] then
            self.dirty_widgets[player_id][widget_id] = nil
        end
        
        -- Remove event handlers
        self:unregisterAllWidgetEvents(player_id, widget_id)
    end
    
    return success, error
end

-- Get a widget by ID
function WidgetFramework:getWidget(player_id, widget_id)
    if not player_id or not widget_id then
        return nil
    end
    
    if self.widget_registry[player_id] then
        return self.widget_registry[player_id][widget_id]
    end
    
    return nil
end

-- Mark widget as dirty (needs rendering)
function WidgetFramework:markWidgetDirty(player_id, widget_id)
    if not player_id or not widget_id then
        return
    end
    
    if not self.dirty_widgets[player_id] then
        self.dirty_widgets[player_id] = {}
    end
    
    self.dirty_widgets[player_id][widget_id] = true
end

-- Clear widget dirty flag
function WidgetFramework:clearWidgetDirty(player_id, widget_id)
    if not player_id or not widget_id then
        return
    end
    
    if self.dirty_widgets[player_id] then
        self.dirty_widgets[player_id][widget_id] = nil
    end
end

-- Animation API Methods

-- Color pulse animation
function WidgetFramework:colorPulseWidget(widget_id, player_id, start_color, end_color, options)
    if not widget_id or not player_id then
        return nil, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return nil, "Widget not found"
    end
    
    return self.animation_manager:createColorPulse(widget_id, player_id, start_color, end_color, options)
end

-- Scale pulse animation
function WidgetFramework:pulseScaleWidget(widget_id, player_id, min_scale, max_scale, options)
    if not widget_id or not player_id then
        return nil, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return nil, "Widget not found"
    end
    
    return self.animation_manager:createPulseScale(widget_id, player_id, min_scale, max_scale, options)
end

-- Slide animation
function WidgetFramework:slideWidget(widget_id, player_id, target_x, target_y, options)
    if not widget_id or not player_id then
        return nil, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return nil, "Widget not found"
    end
    
    local start_x = widget.properties.x
    local start_y = widget.properties.y
    
    return self.animation_manager:createSlide(widget_id, player_id, start_x, start_y, target_x, target_y, options)
end

-- Transform animation (multiple properties)
function WidgetFramework:transformWidget(widget_id, player_id, target_properties, options)
    if not widget_id or not player_id then
        return nil, "Missing required parameters"
    end
    
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return nil, "Widget not found"
    end
    
    -- Extract start properties from widget
    local start_props = {}
    for prop_name, _ in pairs(target_properties) do
        start_props[prop_name] = widget.properties[prop_name]
    end
    
    return self.animation_manager:createTransform(widget_id, player_id, start_props, target_properties, options)
end

-- Stop animations for a widget
function WidgetFramework:stopWidgetAnimations(widget_id, player_id, call_complete)
    if not widget_id or not player_id then
        return 0
    end
    
    return self.animation_manager:stopWidgetAnimations(player_id, widget_id, call_complete)
end

-- Event System Methods

-- Register an event handler for a widget
function WidgetFramework:registerWidgetEvent(player_id, widget_id, event_type, callback)
    if not player_id or not widget_id or not event_type or not callback then
        return false, "Missing required parameters"
    end
    
    if not self.event_registry[player_id] then
        self.event_registry[player_id] = {}
    end
    
    if not self.event_registry[player_id][event_type] then
        self.event_registry[player_id][event_type] = {}
    end
    
    self.event_registry[player_id][event_type][widget_id] = callback
    return true
end

-- Unregister an event handler
function WidgetFramework:unregisterWidgetEvent(player_id, widget_id, event_type)
    if not player_id or not widget_id or not event_type then
        return false
    end
    
    if self.event_registry[player_id] and 
       self.event_registry[player_id][event_type] then
        self.event_registry[player_id][event_type][widget_id] = nil
        return true
    end
    
    return false
end

-- Unregister all events for a widget
function WidgetFramework:unregisterAllWidgetEvents(player_id, widget_id)
    if not player_id or not widget_id then
        return 0
    end
    
    local removed_count = 0
    
    if self.event_registry[player_id] then
        for event_type, widgets in pairs(self.event_registry[player_id]) do
            if widgets[widget_id] then
                widgets[widget_id] = nil
                removed_count = removed_count + 1
            end
        end
    end
    
    return removed_count
end

-- Process input event (tap)
function WidgetFramework:processTapEvent(player_id, x, y)
    if not player_id then
        return false
    end
    
    local hit_widget = nil
    local hit_widget_id = nil
    
    -- Check widgets in reverse render order (top-most first)
    local widgets_to_check = {}
    
    -- Collect all widgets
    if self.widget_registry[player_id] then
        for widget_id, widget in pairs(self.widget_registry[player_id]) do
            if widget.state.visible and widget.state.enabled then
                table.insert(widgets_to_check, {id = widget_id, widget = widget, z = widget.properties.z or 0})
            end
        end
    end
    
    -- Sort by z-index (highest first)
    table.sort(widgets_to_check, function(a, b)
        return a.z > b.z
    end)
    
    -- Find top-most widget at tap position
    for _, widget_data in ipairs(widgets_to_check) do
        if widget_data.widget:hitTest(x, y) then
            hit_widget = widget_data.widget
            hit_widget_id = widget_data.id
            break
        end
    end
    
    if hit_widget and hit_widget_id then
        -- Trigger tap event
        local event_callbacks = self.event_registry[player_id] and 
                               self.event_registry[player_id][self.EVENT_TYPES.TAP]
        
        if event_callbacks and event_callbacks[hit_widget_id] then
            event_callbacks[hit_widget_id](hit_widget, {
                type = self.EVENT_TYPES.TAP,
                x = x,
                y = y,
                widget_id = hit_widget_id
            })
            return true
        end
    end
    
    return false
end

-- Process hover events
function WidgetFramework:processHoverEvent(player_id, x, y)
    if not player_id then
        return false
    end
    
    local hovered_widgets = {}
    
    -- Check all widgets
    if self.widget_registry[player_id] then
        for widget_id, widget in pairs(self.widget_registry[player_id]) do
            if widget.state.visible and widget.state.enabled then
                local is_hovered = widget:hitTest(x, y)
                local was_hovered = widget.state.hovered or false
                
                if is_hovered ~= was_hovered then
                    widget.state.hovered = is_hovered
                    
                    local event_type = is_hovered and self.EVENT_TYPES.HOVER_ENTER or self.EVENT_TYPES.HOVER_LEAVE
                    local event_callbacks = self.event_registry[player_id] and 
                                           self.event_registry[player_id][event_type]
                    
                    if event_callbacks and event_callbacks[widget_id] then
                        event_callbacks[widget_id](widget, {
                            type = event_type,
                            x = x,
                            y = y,
                            widget_id = widget_id
                        })
                    end
                end
            end
        end
    end
    
    return true
end

-- Update animations and render dirty widgets
function WidgetFramework:update()
    local current_time = os.clock()
    local total_rendered = 0
    
    -- Process animations for all players
    for player_id, _ in pairs(self.widget_registry) do
        -- Update animations
        local updated_widgets = self.animation_manager:update(player_id, current_time)
        
        -- Mark animated widgets as dirty
        for widget_id, updated_props in pairs(updated_widgets) do
            local widget = self:getWidget(player_id, widget_id)
            if widget then
                widget:update(updated_props)
                self:markWidgetDirty(player_id, widget_id)
            end
        end
        
        -- Render dirty widgets
        total_rendered = total_rendered + self:renderDirtyWidgets(player_id)
    end
    
    return total_rendered
end

-- Clean up all resources for a player
function WidgetFramework:cleanupPlayer(player_id)
    if not player_id then
        return
    end
    
    -- Dispose all widgets
    if self.widget_registry[player_id] then
        for widget_id, _ in pairs(self.widget_registry[player_id]) do
            self:disposeWidget(player_id, widget_id, false)
        end
        self.widget_registry[player_id] = nil
    end
    
    -- Clean up managers
    self.animation_manager:cleanupPlayer(player_id)
    self.sprite_manager:cleanupPlayer(player_id)
    
    -- Clean up framework structures
    self.widget_trees[player_id] = nil
    self.event_registry[player_id] = nil
    self.dirty_widgets[player_id] = nil
end

-- Get all widgets for a player
function WidgetFramework:getPlayerWidgets(player_id)
    if not player_id or not self.widget_registry[player_id] then
        return {}
    end
    
    return self.widget_registry[player_id]
end

-- Get widget children
function WidgetFramework:getWidgetChildren(player_id, widget_id)
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return {}
    end
    
    local children = {}
    for _, child_id in ipairs(widget.children) do
        local child = self:getWidget(player_id, child_id)
        if child then
            table.insert(children, child)
        end
    end
    
    return children
end

-- Find widget by custom property
function WidgetFramework:findWidgetByProperty(player_id, property_name, property_value)
    if not player_id or not property_name then
        return nil
    end
    
    if not self.widget_registry[player_id] then
        return nil
    end
    
    for widget_id, widget in pairs(self.widget_registry[player_id]) do
        if widget.properties[property_name] == property_value then
            return widget
        end
    end
    
    return nil
end

-- Set widget focus
function WidgetFramework:setWidgetFocus(player_id, widget_id, focused)
    local widget = self:getWidget(player_id, widget_id)
    if not widget then
        return false
    end
    
    widget:setFocused(focused)
    
    -- Trigger focus/blur events
    local event_type = focused and self.EVENT_TYPES.FOCUS or self.EVENT_TYPES.BLUR
    local event_callbacks = self.event_registry[player_id] and 
                           self.event_registry[player_id][event_type]
    
    if event_callbacks and event_callbacks[widget_id] then
        event_callbacks[widget_id](widget, {
            type = event_type,
            widget_id = widget_id,
            focused = focused
        })
    end
    
    return true
end

return WidgetFramework