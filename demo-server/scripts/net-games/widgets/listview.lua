-- widgets/listview.lua
-- ListView widget for displaying scrollable lists of items
-- Supports vertical/horizontal scrolling, viewport management, and item animations

local Widget = require('scripts/net-games/widgets/base-widget')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local ListView = {}
setmetatable(ListView, {__index = Widget})

-- Animation presets for item appearance/disappearance
local ITEM_ANIMATIONS = {
    NONE = "none",
    FADE = "fade",
    SLIDE = "slide",
    SCALE = "scale",
    BOUNCE = "bounce",
    SUMMON = "summon",
    CUSTOM = "custom"
}

-- Scroll directions
local SCROLL_DIRECTIONS = {
    VERTICAL = "vertical",
    HORIZONTAL = "horizontal",
    BOTH = "both"
}

-- Scroll behaviors
local SCROLL_BEHAVIORS = {
    MANUAL = "manual",          -- User controls scrolling
    AUTO = "auto",              -- Automatic scrolling at defined speed
    PAGINATED = "paginated",    -- Scroll by pages
    INERTIA = "inertia",        -- Scroll with inertia/momentum
    SNAP = "snap"               -- Snap to items
}

function ListView.new(id, player_id)
    local self = Widget.new(id, player_id, "ListView")
    setmetatable(self, {__index = ListView})
    
    -- Core properties
    self.orientation = SCROLL_DIRECTIONS.VERTICAL
    self.scroll_behavior = SCROLL_BEHAVIORS.MANUAL
    self.scroll_speed = 0  -- Pixels per second for auto-scroll
    self.scroll_position = 0  -- Current scroll offset (pixels)
    self.max_scroll_position = 0  -- Maximum allowed scroll
    
    -- Viewport settings
    self.viewport_width = 0  -- 0 = use widget width
    self.viewport_height = 0 -- 0 = use widget height
    self.viewport_x = 0      -- Viewport offset within widget
    self.viewport_y = 0
    
    -- Item management
    self.all_items = {}      -- All items in the list (even those not in view)
    self.items_in_view = {}  -- Items currently visible in viewport
    self.item_spacing = 0    -- Spacing between items
    self.item_alignment = "start"  -- "start", "center", "end", "space_between", "space_around", "space_evenly"
    
    -- Animation settings
    self.entry_animation = ITEM_ANIMATIONS.FADE
    self.exit_animation = ITEM_ANIMATIONS.FADE
    self.entry_duration = 0.3
    self.exit_duration = 0.3
    self.entry_easing = "ease_out"
    self.exit_easing = "ease_in"
    self.animate_on_scroll = false  -- Animate items as they enter/exit view during scroll
    
    -- Scroll physics
    self.scroll_friction = 0.95     -- Deceleration factor (0.95 = 5% loss per frame)
    self.scroll_velocity = 0        -- Current scroll velocity (pixels per second)
    self.scroll_inertia_enabled = true
    self.scroll_bounce_enabled = true
    self.scroll_bounce_strength = 0.2  -- 0-1, higher = more bounce
    
    -- Input handling (adapted to match cursor.lua style)
    self.accepts_input = true
    self.event_handlers = {}
    self.virtual_input_enabled = false
    
    -- Snap scrolling settings
    self.snap_enabled = false
    self.snap_duration = 0.2
    self.snap_easing = "ease_out_quad"
    self.snap_alignment = "center"  -- "start", "center", "end", "nearest"
    
    -- Pagination
    self.page_size = 1      -- How many items per page (0 = use viewport size)
    self.current_page = 1
    self.page_spacing = 0   -- Spacing between pages
    
    -- Performance optimization
    self.virtualization_enabled = true  -- Only render items in viewport
    self.item_cache = {}    -- Cache for item dimensions and positions
    self.needs_rebuild = true  -- Flag to rebuild layout
    
    -- Callbacks
    self.on_scroll_start = nil
    self.on_scroll_end = nil
    self.on_page_change = nil
    self.on_item_enter_view = nil
    self.on_item_exit_view = nil
    self.on_item_selected = nil  -- New: for item selection
    
    -- Selection state (for keyboard/gamepad navigation)
    self.selection_enabled = false
    self.selected_item_index = nil
    self.selected_item_id = nil
    self.highlighted_item_index = nil
    self.highlighted_item_id = nil
    
    -- Scroll step for virtual input
    self.scroll_step = 50  -- Pixels per virtual input event
    
    -- Container for visible items
    self.viewport_container = nil  -- Will be created as a child widget
    
    debug_print("INFO", "ListView created: %s", self.id)
    
    return self
end

-- ===========================================================
-- SETUP METHODS
-- ===========================================================

-- Set scrolling orientation
function ListView:setOrientation(orientation)
    if orientation ~= SCROLL_DIRECTIONS.VERTICAL and 
       orientation ~= SCROLL_DIRECTIONS.HORIZONTAL and
       orientation ~= SCROLL_DIRECTIONS.BOTH then
        debug_print("ERROR", "ListView.setOrientation: Invalid orientation '%s' for %s", orientation, self.id)
        return self
    end
    
    self.orientation = orientation
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "ListView.setOrientation: %s = %s", self.id, orientation)
    return self
end

-- Set scroll behavior
function ListView:setScrollBehavior(behavior)
    if not SCROLL_BEHAVIORS[behavior:upper()] then
        debug_print("ERROR", "ListView.setScrollBehavior: Invalid behavior '%s' for %s", behavior, self.id)
        return self
    end
    
    self.scroll_behavior = behavior
    debug_print("DETAILED", "ListView.setScrollBehavior: %s = %s", self.id, behavior)
    return self
end

-- Set auto-scroll speed (pixels per second)
function ListView:setAutoScrollSpeed(speed)
    self.scroll_speed = speed or 0
    debug_print("DETAILED", "ListView.setAutoScrollSpeed: %s = %f px/sec", self.id, self.scroll_speed)
    return self
end

-- Set viewport dimensions (0 = use widget size)
function ListView:setViewportSize(width, height)
    self.viewport_width = width or 0
    self.viewport_height = height or 0
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "ListView.setViewportSize: %s = %gx%g", 
               self.id, self.viewport_width, self.viewport_height)
    return self
end

-- Set viewport offset within widget
function ListView:setViewportOffset(x, y)
    self.viewport_x = x or 0
    self.viewport_y = y or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "ListView.setViewportOffset: %s = (%g,%g)", self.id, x, y)
    return self
end

-- Set item spacing
function ListView:setItemSpacing(spacing)
    self.item_spacing = spacing or 0
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "ListView.setItemSpacing: %s = %g", self.id, spacing)
    return self
end

-- Set item alignment
function ListView:setItemAlignment(alignment)
    local valid_alignments = {"start", "center", "end", "space_between", "space_around", "space_evenly"}
    if not utils.table_contains(valid_alignments, alignment) then
        debug_print("ERROR", "ListView.setItemAlignment: Invalid alignment '%s' for %s", alignment, self.id)
        return self
    end
    
    self.item_alignment = alignment
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "ListView.setItemAlignment: %s = %s", self.id, alignment)
    return self
end

-- Set entry/exit animations
function ListView:setItemAnimations(entry, exit, entry_duration, exit_duration)
    self.entry_animation = entry or ITEM_ANIMATIONS.FADE
    self.exit_animation = exit or ITEM_ANIMATIONS.FADE
    self.entry_duration = entry_duration or self.entry_duration
    self.exit_duration = exit_duration or self.exit_duration
    
    debug_print("DETAILED", "ListView.setItemAnimations: %s = entry:%s, exit:%s", 
               self.id, self.entry_animation, self.exit_animation)
    return self
end

-- Set scroll physics
function ListView:setScrollPhysics(friction, bounce_enabled, bounce_strength)
    self.scroll_friction = friction or self.scroll_friction
    self.scroll_bounce_enabled = bounce_enabled ~= false
    self.scroll_bounce_strength = bounce_strength or self.scroll_bounce_strength
    
    debug_print("DETAILED", "ListView.setScrollPhysics: %s = friction:%f, bounce:%s", 
               self.id, self.scroll_friction, tostring(self.scroll_bounce_enabled))
    return self
end

-- Set pagination
function ListView:setPagination(page_size, page_spacing)
    self.page_size = page_size or self.page_size
    self.page_spacing = page_spacing or 0
    self.scroll_behavior = SCROLL_BEHAVIORS.PAGINATED
    
    debug_print("DETAILED", "ListView.setPagination: %s = %d items per page", self.id, self.page_size)
    return self
end

-- Enable/disable virtualization
function ListView:setVirtualization(enabled)
    self.virtualization_enabled = enabled ~= false
    debug_print("DETAILED", "ListView.setVirtualization: %s = %s", 
               self.id, tostring(self.virtualization_enabled))
    return self
end

-- Enable/disable input
function ListView:setAcceptsInput(enabled)
    self.accepts_input = enabled ~= false
    debug_print("DETAILED", "ListView.setAcceptsInput: %s = %s", 
               self.id, tostring(self.accepts_input))
    return self
end

-- New method: Enable virtual input handling (like cursor.lua)
function ListView:enableVirtualInput(enabled)
    self.virtual_input_enabled = enabled ~= false
    
    if self.virtual_input_enabled and not self.event_handlers.virtual_input then
        self:_setupVirtualInputHandler()
    elseif not self.virtual_input_enabled and self.event_handlers.virtual_input then
        self:_removeVirtualInputHandler()
    end
    
    debug_print("DETAILED", "ListView.enableVirtualInput: %s = %s", 
               self.id, tostring(self.virtual_input_enabled))
    return self
end

-- New method: Enable item selection
function ListView:enableSelection(enabled)
    self.selection_enabled = enabled ~= false
    
    if self.selection_enabled and self.all_items[1] then
        self:setSelectedItem(1, true)  -- Select first item with snap
    end
    
    debug_print("DETAILED", "ListView.enableSelection: %s = %s", 
               self.id, tostring(self.selection_enabled))
    return self
end

-- New method: Enable snap scrolling
function ListView:enableSnap(enabled)
    self.snap_enabled = enabled ~= false
    if self.snap_enabled then
        self.scroll_behavior = SCROLL_BEHAVIORS.SNAP
    end
    
    debug_print("DETAILED", "ListView.enableSnap: %s = %s", 
               self.id, tostring(self.snap_enabled))
    return self
end

-- Set snap settings
function ListView:setSnapSettings(duration, easing, alignment)
    self.snap_duration = duration or self.snap_duration
    self.snap_easing = easing or self.snap_easing
    self.snap_alignment = alignment or self.snap_alignment
    return self
end

-- Set scroll step for virtual input
function ListView:setScrollStep(step)
    self.scroll_step = step or 50
    debug_print("DETAILED", "ListView.setScrollStep: %s = %g", self.id, self.scroll_step)
    return self
end

-- Set callbacks (updated to include on_item_selected)
function ListView:setCallbacks(callbacks)
    if callbacks.on_scroll_start then self.on_scroll_start = callbacks.on_scroll_start end
    if callbacks.on_scroll_end then self.on_scroll_end = callbacks.on_scroll_end end
    if callbacks.on_page_change then self.on_page_change = callbacks.on_page_change end
    if callbacks.on_item_enter_view then self.on_item_enter_view = callbacks.on_item_enter_view end
    if callbacks.on_item_exit_view then self.on_item_exit_view = callbacks.on_item_exit_view end
    if callbacks.on_item_selected then self.on_item_selected = callbacks.on_item_selected end
    return self
end

-- ===========================================================
-- VIRTUAL INPUT HANDLING (like cursor.lua)
-- ===========================================================

-- Internal: Setup virtual input handler (similar to cursor.lua's setupControls)
function ListView:_setupVirtualInputHandler()
    if not Net or not Net.on then
        debug_print("WARN", "ListView._setupVirtualInputHandler: Net module not available")
        return false
    end
    
    local function handle_virtual_input(event)
        if event.player_id ~= self.player_id then
            return
        end
        
        if not self.accepts_input or not self.virtual_input_enabled then
            return
        end
        
        debug_print("VERBOSE", "ListView: virtual_input from player %s", event.player_id)
        
        for _, button in ipairs(event.events) do
            debug_print("VERBOSE", "  Button: %s, state: %d", button.name, button.state)
            
            -- Handle button presses (state == 1) and repeats (state == 4)
            if button.state == 1 or button.state == 4 then
                if button.name == "Move Up" then
                    debug_print("INFO", "ListView: Move Up pressed")
                    self:_handleMove("up")
                elseif button.name == "Move Down" then
                    debug_print("INFO", "ListView: Move Down pressed")
                    self:_handleMove("down")
                elseif button.name == "Move Left" then
                    debug_print("INFO", "ListView: Move Left pressed")
                    self:_handleMove("left")
                elseif button.name == "Move Right" then
                    debug_print("INFO", "ListView: Move Right pressed")
                    self:_handleMove("right")
                elseif button.name == "Interact" or button.name == "Confirm" then
                    debug_print("INFO", "ListView: Confirm pressed")
                    self:_handleConfirm()
                elseif button.name == "Shoulder L" then
                    debug_print("INFO", "ListView: Shoulder L pressed")
                    self:_handleShoulder("left")
                elseif button.name == "Shoulder R" then
                    debug_print("INFO", "ListView: Shoulder R pressed")
                    self:_handleShoulder("right")
                end
            end
        end
    end
    
    -- Register the event handler
    Net:on("virtual_input", handle_virtual_input)
    
    -- Store for cleanup
    self.event_handlers.virtual_input = handle_virtual_input
    
    debug_print("INFO", "ListView._setupVirtualInputHandler: %s setup virtual input", self.id)
    return true
end

-- Internal: Remove virtual input handler
function ListView:_removeVirtualInputHandler()
    if self.event_handlers.virtual_input then
        -- Note: Unregistering depends on your Net API
        -- If Net.removeListener exists, use it
        if Net and Net.removeListener then
            Net:removeListener("virtual_input", self.event_handlers.virtual_input)
        end
        self.event_handlers.virtual_input = nil
    end
end

-- Internal: Handle movement based on orientation
function ListView:_handleMove(direction)
    local scroll_direction = nil
    local move_selection = false
    
    -- Determine action based on orientation and selection state
    if self.selection_enabled then
        -- Move selection with snap
        move_selection = true
        if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
            if direction == "up" then
                self:_moveSelection(-1)
            elseif direction == "down" then
                self:_moveSelection(1)
            end
        elseif self.orientation == SCROLL_DIRECTIONS.HORIZONTAL then
            if direction == "left" then
                self:_moveSelection(-1)
            elseif direction == "right" then
                self:_moveSelection(1)
            end
        end
    else
        -- Scroll the list
        if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
            if direction == "up" then
                scroll_direction = -self.scroll_step
            elseif direction == "down" then
                scroll_direction = self.scroll_step
            end
        elseif self.orientation == SCROLL_DIRECTIONS.HORIZONTAL then
            if direction == "left" then
                scroll_direction = -self.scroll_step
            elseif direction == "right" then
                scroll_direction = self.scroll_step
            end
        end
        
        if scroll_direction then
            if self.snap_enabled then
                -- In snap mode, find the nearest item to scroll to
                self:_snapToNearestItem(scroll_direction > 0 and 1 or -1)
            else
                self:scrollBy(scroll_direction, true, 0.1, "ease_out")
            end
            
            if self.on_scroll_start then
                self.on_scroll_start(self.scroll_position)
            end
        end
    end
    
    return move_selection
end

-- Internal: Handle shoulder button presses
function ListView:_handleShoulder(side)
    if side == "left" then
        -- Previous page or item
        if self.scroll_behavior == SCROLL_BEHAVIORS.PAGINATED then
            local prev_page = math.max(1, self.current_page - 1)
            self:scrollToPage(prev_page, true)
        elseif self.selection_enabled then
            self:_moveSelection(-5)  -- Jump 5 items
        else
            self:scrollBy(-self.scroll_step * 3, true, 0.15, "ease_out")
        end
    elseif side == "right" then
        -- Next page or item
        if self.scroll_behavior == SCROLL_BEHAVIORS.PAGINATED then
            local next_page = math.min(self:getPageCount(), self.current_page + 1)
            self:scrollToPage(next_page, true)
        elseif self.selection_enabled then
            self:_moveSelection(5)  -- Jump 5 items
        else
            self:scrollBy(self.scroll_step * 3, true, 0.15, "ease_out")
        end
    end
end

-- Internal: Handle confirm/selection
function ListView:_handleConfirm()
    local selected_item = nil
    
    -- Get the currently selected item
    if self.selected_item_index then
        selected_item = self.all_items[self.selected_item_index]
    elseif self.highlighted_item_index then
        selected_item = self.all_items[self.highlighted_item_index]
    end
    
    if selected_item then
        -- Emit selection event (like events.lua)
        if Net and Net.emit then
            debug_print("INFO", "ListView: Emitting widget_item_selected for %s", selected_item.id)
            Net:emit("widget_item_selected", {
                player_id = self.player_id,
                widget_id = self.id,
                item = selected_item
            })
        end
        
        -- Call callback
        if self.on_item_selected then
            self.on_item_selected(selected_item)
        end
        
        debug_print("INFO", "ListView._handleConfirm: %s selected item %s", 
                   self.id, selected_item.id)
    else
        debug_print("WARN", "ListView._handleConfirm: No item selected")
    end
end

-- ===========================================================
-- ITEM MANAGEMENT
-- ===========================================================

-- Add an item to the list
function ListView:addItem(item, index, animate)
    if not item then
        debug_print("ERROR", "ListView.addItem: No item provided for %s", self.id)
        return self
    end
    
    local item_id = item.id or utils.generate_unique_id("list_item")
    local is_widget = item.widget ~= nil
    local is_sprite = item.sprite_id ~= nil
    
    if not is_widget and not is_sprite then
        debug_print("ERROR", "ListView.addItem: Item must be a widget or sprite for %s", self.id)
        return self
    end
    
    -- Create item data structure
    local item_data = {
        id = item_id,
        data = item,
        is_widget = is_widget,
        is_sprite = is_sprite,
        visible = false,  -- Not visible until positioned in viewport
        index = index or (#self.all_items + 1),
        width = item.width or (is_widget and item.widget.width or 0),
        height = item.height or (is_widget and item.widget.height or 0),
        cached_position = nil,
        animation_id = nil
    }
    
    -- Insert at specified index or at the end
    if index and index <= #self.all_items then
        table.insert(self.all_items, index, item_data)
        -- Update indices for subsequent items
        for i = index + 1, #self.all_items do
            self.all_items[i].index = i
        end
    else
        table.insert(self.all_items, item_data)
    end
    
    -- If this is a widget, add it as a child
    if is_widget and item.widget then
        self:addWidget(item.widget)
    end
    
    -- If this is a sprite, create it
    if is_sprite and item.sprite_id then
        self:create_sprite(
            item.sprite_id,
            item.texture_path,
            item.anim_path,
            item.anim_state,
            item.layout_width,
            item.layout_height,
            item.properties
        )
    end
    
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "ListView.addItem: %s added item %s at index %d (total: %d)", 
               self.id, item_id, item_data.index, #self.all_items)
    
    -- Animate entry if requested and in view
    if animate ~= false and self.entry_animation ~= ITEM_ANIMATIONS.NONE then
        self:_animateItemEntry(item_data)
    end
    
    return self
end

-- Add multiple items at once
function ListView:addItems(items, start_index, animate)
    start_index = start_index or #self.all_items + 1
    for i, item in ipairs(items) do
        self:addItem(item, start_index + i - 1, animate)
    end
    return self
end

-- Remove an item from the list
function ListView:removeItem(item_id_or_index, animate)
    local item_data = nil
    local item_index = nil
    
    -- Find by ID or index
    if type(item_id_or_index) == "number" then
        item_index = item_id_or_index
        item_data = self.all_items[item_index]
    else
        for i, item in ipairs(self.all_items) do
            if item.id == item_id_or_index or 
               (item.is_widget and item.data.widget.id == item_id_or_index) or
               (item.is_sprite and item.data.sprite_id == item_id_or_index) then
                item_data = item
                item_index = i
                break
            end
        end
    end
    
    if not item_data then
        debug_print("WARN", "ListView.removeItem: Item not found in %s", self.id)
        return false
    end
    
    -- Animate exit if requested
    if animate ~= false and self.exit_animation ~= ITEM_ANIMATIONS.NONE then
        local animation_completed = false
        self:_animateItemExit(item_data, function()
            animation_completed = true
            self:_actuallyRemoveItem(item_data, item_index)
        end)
        
        -- If animation doesn't complete immediately, return pending
        if not animation_completed then
            return "pending"
        end
    end
    
    -- Remove immediately (no animation or animation completed)
    return self:_actuallyRemoveItem(item_data, item_index)
end

-- Internal: Actually remove the item after animation
function ListView:_actuallyRemoveItem(item_data, item_index)
    -- Remove from items in view
    for i, visible_item in ipairs(self.items_in_view) do
        if visible_item.id == item_data.id then
            table.remove(self.items_in_view, i)
            break
        end
    end
    
    -- Remove from all items
    table.remove(self.all_items, item_index)
    
    -- Update indices for remaining items
    for i = item_index, #self.all_items do
        self.all_items[i].index = i
    end
    
    -- If this is a widget, remove it
    if item_data.is_widget and item_data.data.widget then
        self:removeWidget(item_data.data.widget.id)
    end
    
    -- If this is a sprite, remove it
    if item_data.is_sprite and item_data.data.sprite_id then
        local sprite = self:get_sprite(item_data.data.sprite_id)
        if sprite then
            sprite:remove()
        end
        self.sprite_objects[item_data.data.sprite_id] = nil
    end
    
    -- Clean up cache
    self.item_cache[item_data.id] = nil
    
    -- Update selection if needed
    if self.selected_item_index == item_index then
        self.selected_item_index = nil
        self.selected_item_id = nil
        if #self.all_items > 0 then
            self:setSelectedItem(math.min(item_index, #self.all_items))
        end
    end
    
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "ListView._actuallyRemoveItem: %s removed item %s at index %d (remaining: %d)", 
               self.id, item_data.id, item_index, #self.all_items)
    
    return true
end

-- Clear all items
function ListView:clearItems(animate)
    if animate and self.exit_animation ~= ITEM_ANIMATIONS.NONE then
        local items_to_remove = utils.table_copy(self.all_items)
        local removal_count = #items_to_remove
        
        -- Animate all items out
        local completed_removals = 0
        for _, item_data in ipairs(items_to_remove) do
            self:_animateItemExit(item_data, function()
                completed_removals = completed_removals + 1
                if completed_removals >= removal_count then
                    -- All animations complete, actually clear
                    self:_clearAllItems()
                end
            end)
        end
    else
        self:_clearAllItems()
    end
    
    return self
end

-- Internal: Actually clear all items
function ListView:_clearAllItems()
    -- Clear data structures
    self.all_items = {}
    self.items_in_view = {}
    self.item_cache = {}
    
    -- Clear selection
    self.selected_item_index = nil
    self.selected_item_id = nil
    self.highlighted_item_index = nil
    self.highlighted_item_id = nil
    
    -- Clear child widgets and sprites
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:destroy()
    end
    self._child_widgets = {}
    
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:remove()
    end
    self.sprite_objects = {}
    
    -- Clear children list
    self.children = {}
    
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "ListView._clearAllItems: %s cleared all items", self.id)
end

-- Get item by ID or index
function ListView:getItem(item_id_or_index)
    if type(item_id_or_index) == "number" then
        return self.all_items[item_id_or_index]
    else
        for _, item in ipairs(self.all_items) do
            if item.id == item_id_or_index or
               (item.is_widget and item.data.widget.id == item_id_or_index) or
               (item.is_sprite and item.data.sprite_id == item_id_or_index) then
                return item
            end
        end
    end
    return nil
end

-- Get item count
function ListView:getItemCount()
    return #self.all_items
end

-- Get visible item count
function ListView:getVisibleItemCount()
    return #self.items_in_view
end

-- ===========================================================
-- SELECTION MANAGEMENT
-- ===========================================================

-- Internal: Move selection by delta
function ListView:_moveSelection(delta)
    if not self.selection_enabled or #self.all_items == 0 then
        return false
    end
    
    local current_index = self.selected_item_index or self.highlighted_item_index or 1
    local new_index = current_index + delta
    
    -- Wrap around
    if new_index < 1 then
        new_index = #self.all_items
    elseif new_index > #self.all_items then
        new_index = 1
    end
    
    self:setSelectedItem(new_index, true)  -- Snap to the selected item
    
    return true
end

-- Set selected item by index or ID
function ListView:setSelectedItem(item_id_or_index, snap)
    if not self.selection_enabled then
        return false
    end
    
    local old_index = self.selected_item_index
    local old_id = self.selected_item_id
    
    -- Find item
    if type(item_id_or_index) == "number" then
        if item_id_or_index < 1 or item_id_or_index > #self.all_items then
            return false
        end
        self.selected_item_index = item_id_or_index
        self.selected_item_id = self.all_items[item_id_or_index].id
    else
        for i, item in ipairs(self.all_items) do
            if item.id == item_id_or_index then
                self.selected_item_index = i
                self.selected_item_id = item_id_or_index
                break
            end
        end
    end
    
    -- Update visual state if needed
    if self.selected_item_index and self.selected_item_index ~= old_index then
        self:_updateItemSelectionState(old_index, self.selected_item_index)
        
        -- Snap to the selected item if requested or if snap is enabled
        if (snap or self.snap_enabled) and self.selected_item_index then
            if self.snap_enabled then
                self:scrollToItem(self.selected_item_index, self.snap_alignment, self.snap_duration > 0, self.snap_duration, self.snap_easing)
            else
                self:scrollToItem(self.selected_item_index, "center", true, 0.2, "ease_out")
            end
        end
        
        debug_print("DETAILED", "ListView.setSelectedItem: %s selected item %d (%s)", 
                   self.id, self.selected_item_index, self.selected_item_id or "none")
    end
    
    return true
end

-- Get selected item
function ListView:getSelectedItem()
    if self.selected_item_index then
        return self.all_items[self.selected_item_index]
    end
    return nil
end

-- Internal: Update item selection state
function ListView:_updateItemSelectionState(old_index, new_index)
    -- This is a placeholder - you would update visual states here
    -- For example, change sprite states or widget appearances
    
    if old_index and self.all_items[old_index] then
        local old_item = self.all_items[old_index]
        -- Reset old item's visual state
        if old_item.is_widget and old_item.data.widget then
            -- old_item.data.widget:setState("normal")
        elseif old_item.is_sprite then
            -- self.sprite_objects[old_item.data.sprite_id]:update({anim_state = "normal"})
        end
    end
    
    if new_index and self.all_items[new_index] then
        local new_item = self.all_items[new_index]
        -- Set new item's visual state to selected
        if new_item.is_widget and new_item.data.widget then
            -- new_item.data.widget:setState("selected")
        elseif new_item.is_sprite then
            -- self.sprite_objects[new_item.data.sprite_id]:update({anim_state = "selected"})
        end
    end
end

-- ===========================================================
-- SCROLL CONTROL
-- ===========================================================

-- Scroll to a specific position
function ListView:scrollTo(position, animate, duration, easing)
    if animate then
        duration = duration or 0.5
        easing = easing or "ease_in_out"
        
        local start_position = self.scroll_position
        local delta = position - start_position
        
        local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "ListView.scrollTo: AnimationEngine not available")
            self.scroll_position = position
            self:_constrainScrollPosition()
            self.needs_rebuild = true
            self.state.dirty = true
            return self
        end
        
        local anim_id = AnimationEngine.animate(
            {t = 0},
            {t = 1},
            duration,
            {
                easing = easing,
                on_update = function(values)
                    local t = values.t
                    self.scroll_position = start_position + delta * t
                    self.needs_rebuild = true
                    self.state.dirty = true
                end,
                on_complete = function()
                    self:_constrainScrollPosition()
                    self.needs_rebuild = true
                    self.state.dirty = true
                    if self.on_scroll_end then
                        self.on_scroll_end(self.scroll_position)
                    end
                end
            }
        )
        
        if anim_id then
            self.active_animations[anim_id] = true
        end
        
        if self.on_scroll_start then
            self.on_scroll_start(position)
        end
        
        debug_print("INFO", "ListView.scrollTo: %s animating to position %g", self.id, position)
    else
        self.scroll_position = position
        self:_constrainScrollPosition()
        self.needs_rebuild = true
        self.state.dirty = true
        
        debug_print("INFO", "ListView.scrollTo: %s jumped to position %g", self.id, position)
    end
    
    return self
end

-- Scroll by amount
function ListView:scrollBy(amount, animate, duration, easing)
    return self:scrollTo(self.scroll_position + amount, animate, duration, easing)
end

-- Scroll to item
function ListView:scrollToItem(item_id_or_index, align, animate, duration, easing)
    local item = self:getItem(item_id_or_index)
    if not item then
        debug_print("ERROR", "ListView.scrollToItem: Item not found in %s", self.id)
        return self
    end
    
    align = align or "center"  -- "start", "center", "end", "nearest"
    
    -- Get item position (need to rebuild first to get positions)
    if self.needs_rebuild then
        self:_rebuildLayout()
    end
    
    local item_pos = self:_getItemScrollPosition(item)
    if not item_pos then
        debug_print("ERROR", "ListView.scrollToItem: Could not get position for item in %s", self.id)
        return self
    end
    
    -- Calculate target scroll position based on alignment
    local viewport_size = self:_getViewportSize()
    local target_position = self.scroll_position
    
    if self.orientation == SCROLL_DIRECTIONS.VERTICAL or self.orientation == SCROLL_DIRECTIONS.BOTH then
        if align == "start" then
            target_position = item_pos.y
        elseif align == "center" then
            target_position = item_pos.y - (viewport_size.height - item_pos.height) / 2
        elseif align == "end" then
            target_position = item_pos.y - (viewport_size.height - item_pos.height)
        else -- "nearest"
            local item_top = item_pos.y
            local item_bottom = item_pos.y + item_pos.height
            local viewport_top = self.scroll_position
            local viewport_bottom = self.scroll_position + viewport_size.height
            
            if item_top < viewport_top then
                target_position = item_top
            elseif item_bottom > viewport_bottom then
                target_position = item_bottom - viewport_size.height
            end
        end
    else -- HORIZONTAL
        if align == "start" then
            target_position = item_pos.x
        elseif align == "center" then
            target_position = item_pos.x - (viewport_size.width - item_pos.width) / 2
        elseif align == "end" then
            target_position = item_pos.x - (viewport_size.width - item_pos.width)
        else -- "nearest"
            local item_left = item_pos.x
            local item_right = item_pos.x + item_pos.width
            local viewport_left = self.scroll_position
            local viewport_right = self.scroll_position + viewport_size.width
            
            if item_left < viewport_left then
                target_position = item_left
            elseif item_right > viewport_right then
                target_position = item_right - viewport_size.width
            end
        end
    end
    
    return self:scrollTo(target_position, animate, duration, easing)
end

-- Internal: Snap to nearest item in direction
function ListView:_snapToNearestItem(direction)
    if #self.all_items == 0 then
        return
    end
    
    -- Find the item nearest to the current scroll position
    local best_item_index = 1
    local best_distance = math.huge
    
    for i, item in ipairs(self.all_items) do
        local cached = self.item_cache[item.id]
        if cached then
            local item_center = 0
            local scroll_center = self.scroll_position
            
            if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
                item_center = cached.y + cached.height / 2
                scroll_center = self.scroll_position + self:_getViewportSize().height / 2
            else -- HORIZONTAL
                item_center = cached.x + cached.width / 2
                scroll_center = self.scroll_position + self:_getViewportSize().width / 2
            end
            
            local distance = math.abs(item_center - scroll_center)
            if distance < best_distance then
                best_distance = distance
                best_item_index = i
            end
        end
    end
    
    -- Move to the next/previous item based on direction
    if direction > 0 then
        best_item_index = math.min(#self.all_items, best_item_index + 1)
    else
        best_item_index = math.max(1, best_item_index - 1)
    end
    
    -- Scroll to the item
    self:scrollToItem(best_item_index, self.snap_alignment, self.snap_duration > 0, self.snap_duration, self.snap_easing)
    
    -- If selection is enabled, select the item
    if self.selection_enabled then
        self:setSelectedItem(best_item_index, false)  -- Don't snap again
    end
end

-- Scroll to page
function ListView:scrollToPage(page_number, animate, duration, easing)
    if self.scroll_behavior ~= SCROLL_BEHAVIORS.PAGINATED then
        debug_print("WARN", "ListView.scrollToPage: Not in paginated mode for %s", self.id)
        return self
    end
    
    local total_pages = self:getPageCount()
    if page_number < 1 or page_number > total_pages then
        debug_print("ERROR", "ListView.scrollToPage: Page %d out of range (1-%d) for %s", 
                   page_number, total_pages, self.id)
        return self
    end
    
    local viewport_size = self:_getViewportSize()
    local page_size = self.page_size > 0 and self.page_size or 
                     (self.orientation == SCROLL_DIRECTIONS.VERTICAL and viewport_size.height or viewport_size.width)
    
    local target_position = (page_number - 1) * (page_size + self.page_spacing)
    
    local old_page = self.current_page
    self.current_page = page_number
    
    if self.on_page_change then
        self.on_page_change(page_number, old_page)
    end
    
    debug_print("INFO", "ListView.scrollToPage: %s scrolling to page %d (position %g)", 
               self.id, page_number, target_position)
    
    return self:scrollTo(target_position, animate, duration, easing)
end

-- Start auto-scroll
function ListView:startAutoScroll()
    if self.scroll_behavior == SCROLL_BEHAVIORS.AUTO and self.scroll_speed ~= 0 then
        self.scroll_velocity = self.scroll_speed
        debug_print("INFO", "ListView.startAutoScroll: %s started at %g px/sec", 
                   self.id, self.scroll_velocity)
    end
    return self
end

-- Stop auto-scroll
function ListView:stopAutoScroll()
    self.scroll_velocity = 0
    debug_print("INFO", "ListView.stopAutoScroll: %s stopped", self.id)
    return self
end

-- Get current scroll position
function ListView:getScrollPosition()
    return self.scroll_position
end

-- Get maximum scroll position
function ListView:getMaxScrollPosition()
    return self.max_scroll_position
end

-- Get current page
function ListView:getCurrentPage()
    return self.current_page
end

-- Get total pages
function ListView:getPageCount()
    if self.scroll_behavior ~= SCROLL_BEHAVIORS.PAGINATED then
        return 1
    end
    
    local viewport_size = self:_getViewportSize()
    local page_size = self.page_size > 0 and self.page_size or 
                     (self.orientation == SCROLL_DIRECTIONS.VERTICAL and viewport_size.height or viewport_size.width)
    
    local total_size = self:_getTotalContentSize()
    local size_in_dir = self.orientation == SCROLL_DIRECTIONS.VERTICAL and total_size.height or total_size.width
    
    return math.ceil(size_in_dir / page_size)
end

-- ===========================================================
-- LAYOUT AND RENDERING
-- ===========================================================

-- Calculate layout
function ListView:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "ListView.calculateLayout: %s with %d items, available=%gx%g", 
               self.id, #self.all_items, available_width, available_height)
    
    -- Rebuild layout if needed
    if self.needs_rebuild then
        self:_rebuildLayout()
    end
    
    -- Determine viewport size
    local viewport_size = self:_getViewportSize()
    if viewport_size.width == 0 then viewport_size.width = available_width end
    if viewport_size.height == 0 then viewport_size.height = available_height end
    
    -- Constrain scroll position
    self:_constrainScrollPosition()
    
    -- Update which items are in view
    self:_updateVisibleItems()
    
    -- Position items in view
    local positioned_children = {}
    
    for _, item_data in ipairs(self.items_in_view) do
        if item_data.visible then
            -- Get cached position
            local cached_pos = self.item_cache[item_data.id]
            if cached_pos then
                -- Adjust position based on scroll
                local x = cached_pos.x - (self.orientation == SCROLL_DIRECTIONS.HORIZONTAL and self.scroll_position or 0)
                local y = cached_pos.y - (self.orientation == SCROLL_DIRECTIONS.VERTICAL and self.scroll_position or 0)
                
                -- Adjust for viewport offset
                x = x + self.viewport_x
                y = y + self.viewport_y
                
                -- Create positioned child entry
                local positioned_child = {
                    x = x,
                    y = y,
                    width = cached_pos.width,
                    height = cached_pos.height,
                    visible = true,
                    id = item_data.id
                }
                
                -- Add type-specific properties
                if item_data.is_widget then
                    positioned_child.widget = item_data.data.widget
                    positioned_child.is_widget = true
                elseif item_data.is_sprite then
                    positioned_child.sprite_id = item_data.data.sprite_id
                    positioned_child.is_sprite = true
                    positioned_child.ox = item_data.data.ox or 0
                    positioned_child.oy = item_data.data.oy or 0
                end
                
                table.insert(positioned_children, positioned_child)
                
                debug_print("VERBOSE", "  Item %s positioned at (%g,%g) size=%gx%g", 
                           item_data.id, x, y, cached_pos.width, cached_pos.height)
            end
        end
    end
    
    -- The ListView size is the viewport size
    local layout_width = viewport_size.width
    local layout_height = viewport_size.height
    
    debug_print("INFO", "ListView.layout calculated: %s = %gx%g, %d items visible", 
               self.id, layout_width, layout_height, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

-- Internal: Rebuild layout (positions all items)
function ListView:_rebuildLayout()
    debug_print("DETAILED", "ListView._rebuildLayout: Rebuilding layout for %s", self.id)
    
    -- Clear cache
    self.item_cache = {}
    
    -- Get viewport size for calculations
    local viewport_size = self:_getViewportSize()
    
    -- Calculate item positions based on orientation
    local current_x = 0
    local current_y = 0
    local max_width = 0
    local max_height = 0
    local row_height = 0
    local col_width = 0
    local item_count = #self.all_items
    
    -- Calculate total size for alignment
    if self.item_alignment:find("space") then
        -- For space distributions, we need total size
        for _, item_data in ipairs(self.all_items) do
            local width, height = self:_getItemSize(item_data)
            if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
                max_height = max_height + height
                max_width = math.max(max_width, width)
            elseif self.orientation == SCROLL_DIRECTIONS.HORIZONTAL then
                max_width = max_width + width
                max_height = math.max(max_height, height)
            else -- BOTH (grid-like)
                -- Simplified grid for now
                max_width = math.max(max_width, width)
                max_height = math.max(max_height, height)
            end
        end
        
        -- Add spacing
        if item_count > 1 then
            if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
                max_height = max_height + (item_count - 1) * self.item_spacing
            elseif self.orientation == SCROLL_DIRECTIONS.HORIZONTAL then
                max_width = max_width + (item_count - 1) * self.item_spacing
            end
        end
    end
    
    -- Position each item
    for i, item_data in ipairs(self.all_items) do
        local width, height = self:_getItemSize(item_data)
        
        -- Calculate position based on orientation and alignment
        local x, y = 0, 0
        
        if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
            -- Vertical layout
            x = self:_getAlignedPosition(width, viewport_size.width, self.item_alignment)
            y = current_y
            
            if self.item_alignment == "space_between" and item_count > 1 then
                y = current_y + ((viewport_size.height - max_height) / (item_count - 1)) * (i - 1)
            elseif self.item_alignment == "space_around" then
                y = current_y + ((viewport_size.height - max_height) / (item_count * 2)) * (2 * i - 1)
            elseif self.item_alignment == "space_evenly" then
                y = current_y + ((viewport_size.height - max_height) / (item_count + 1)) * i
            end
            
            current_y = y + height + self.item_spacing
            max_width = math.max(max_width, width)
            max_height = math.max(max_height, current_y)
            
        elseif self.orientation == SCROLL_DIRECTIONS.HORIZONTAL then
            -- Horizontal layout
            x = current_x
            y = self:_getAlignedPosition(height, viewport_size.height, self.item_alignment)
            
            if self.item_alignment == "space_between" and item_count > 1 then
                x = current_x + ((viewport_size.width - max_width) / (item_count - 1)) * (i - 1)
            elseif self.item_alignment == "space_around" then
                x = current_x + ((viewport_size.width - max_width) / (item_count * 2)) * (2 * i - 1)
            elseif self.item_alignment == "space_evenly" then
                x = current_x + ((viewport_size.width - max_width) / (item_count + 1)) * i
            end
            
            current_x = x + width + self.item_spacing
            max_width = math.max(max_width, current_x)
            max_height = math.max(max_height, height)
            
        else -- BOTH (grid layout)
            -- Simple grid: items flow left to right, top to bottom
            x = current_x
            y = current_y
            
            -- Move to next row if item doesn't fit
            if x + width > viewport_size.width and x > 0 then
                x = 0
                y = y + row_height + self.item_spacing
                current_x = width + self.item_spacing
                row_height = height
            else
                current_x = x + width + self.item_spacing
                row_height = math.max(row_height, height)
            end
            
            max_width = math.max(max_width, x + width)
            max_height = math.max(max_height, y + height)
        end
        
        -- Cache item position and size
        self.item_cache[item_data.id] = {
            x = x,
            y = y,
            width = width,
            height = height,
            index = i
        }
        
        debug_print("VERBOSE", "  Cached item %s at (%g,%g) size=%gx%g", 
                   item_data.id, x, y, width, height)
    end
    
    -- Calculate max scroll position
    self:_calculateMaxScroll()
    
    self.needs_rebuild = false
    debug_print("INFO", "ListView._rebuildLayout: %s layout rebuilt, max scroll: %g", 
               self.id, self.max_scroll_position)
end

-- Internal: Get item size
function ListView:_getItemSize(item_data)
    if item_data.is_widget and item_data.data.widget then
        -- Update widget layout to get accurate size
        item_data.data.widget:updateLayout()
        return item_data.data.widget:getCalculatedSize()
    elseif item_data.is_sprite then
        -- Use layout dimensions or default
        return item_data.width or 32, item_data.height or 32
    else
        return item_data.width or 32, item_data.height or 32
    end
end

-- Internal: Get aligned position
function ListView:_getAlignedPosition(item_size, container_size, alignment)
    if alignment == "start" then
        return 0
    elseif alignment == "center" then
        return (container_size - item_size) / 2
    elseif alignment == "end" then
        return container_size - item_size
    else
        return 0
    end
end

-- Internal: Get viewport size
function ListView:_getViewportSize()
    local width = self.viewport_width > 0 and self.viewport_width or 
                 (self.width > 0 and self.width or utils.SCREEN_WIDTH)
    local height = self.viewport_height > 0 and self.viewport_height or 
                  (self.height > 0 and self.height or utils.SCREEN_HEIGHT)
    
    return {width = width, height = height}
end

-- Internal: Get total content size
function ListView:_getTotalContentSize()
    local max_x = 0
    local max_y = 0
    
    for _, cached in pairs(self.item_cache) do
        max_x = math.max(max_x, cached.x + cached.width)
        max_y = math.max(max_y, cached.y + cached.height)
    end
    
    return {width = max_x, height = max_y}
end

-- Internal: Calculate maximum scroll position
function ListView:_calculateMaxScroll()
    local viewport_size = self:_getViewportSize()
    local total_size = self:_getTotalContentSize()
    
    if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
        self.max_scroll_position = math.max(0, total_size.height - viewport_size.height)
    elseif self.orientation == SCROLL_DIRECTIONS.HORIZONTAL then
        self.max_scroll_position = math.max(0, total_size.width - viewport_size.width)
    else -- BOTH
        -- Use the larger of the two dimensions
        self.max_scroll_position = math.max(
            math.max(0, total_size.width - viewport_size.width),
            math.max(0, total_size.height - viewport_size.height)
        )
    
    debug_print("VERBOSE", "ListView._calculateMaxScroll: %s max scroll = %g", 
               self.id, self.max_scroll_position)
    end
end

-- Internal: Constrain scroll position
function ListView:_constrainScrollPosition()
    local old_position = self.scroll_position
    
    if self.scroll_bounce_enabled then
        -- Allow some overscroll with bounce
        local overscroll_max = self.max_scroll_position * self.scroll_bounce_strength
        self.scroll_position = math.max(-overscroll_max, 
            math.min(self.max_scroll_position + overscroll_max, self.scroll_position))
    else
        -- Hard constraints
        self.scroll_position = math.max(0, 
            math.min(self.max_scroll_position, self.scroll_position))
    end
    
    if old_position ~= self.scroll_position then
        debug_print("VERBOSE", "ListView._constrainScrollPosition: %s constrained from %g to %g", 
                   self.id, old_position, self.scroll_position)
    end
end

-- Internal: Update which items are in view
function ListView:_updateVisibleItems()
    local viewport_size = self:_getViewportSize()
    local viewport_start_x = self.scroll_position
    local viewport_start_y = self.scroll_position
    local viewport_end_x = viewport_start_x + viewport_size.width
    local viewport_end_y = viewport_start_y + viewport_size.height
    
    -- Track previously visible items
    local previously_visible = {}
    for _, item in ipairs(self.items_in_view) do
        previously_visible[item.id] = true
    end
    
    -- Clear current visible items
    self.items_in_view = {}
    
    -- Find items currently in viewport
    for _, item_data in ipairs(self.all_items) do
        local cached = self.item_cache[item_data.id]
        if cached then
            local item_start_x = cached.x
            local item_start_y = cached.y
            local item_end_x = item_start_x + cached.width
            local item_end_y = item_start_y + cached.height
            
            local is_in_view = false
            
            if self.orientation == SCROLL_DIRECTIONS.VERTICAL then
                is_in_view = item_end_y > viewport_start_y and item_start_y < viewport_end_y
            elseif self.orientation == SCROLL_DIRECTIONS.HORIZONTAL then
                is_in_view = item_end_x > viewport_start_x and item_start_x < viewport_end_x
            else -- BOTH
                is_in_view = (item_end_x > viewport_start_x and item_start_x < viewport_end_x) and
                            (item_end_y > viewport_start_y and item_start_y < viewport_end_y)
            end
            
            item_data.visible = is_in_view
            
            if is_in_view then
                table.insert(self.items_in_view, item_data)
                
                -- Item entered view
                if not previously_visible[item_data.id] then
                    self:_onItemEnterView(item_data)
                end
            else
                -- Item exited view
                if previously_visible[item_data.id] then
                    self:_onItemExitView(item_data)
                end
            end
        end
    end
    
    -- Clean up items that are no longer visible
    for item_id, _ in pairs(previously_visible) do
        local still_visible = false
        for _, item in ipairs(self.items_in_view) do
            if item.id == item_id then
                still_visible = true
                break
            end
        end
        
        if not still_visible then
            -- Item fully exited view (not in items_in_view anymore)
            local item_data = self:getItem(item_id)
            if item_data then
                self:_onItemExitView(item_data)
            end
        end
    end
    
    debug_print("VERBOSE", "ListView._updateVisibleItems: %s has %d items in view", 
               self.id, #self.items_in_view)
end

-- Internal: Get item scroll position
function ListView:_getItemScrollPosition(item)
    return self.item_cache[item.id]
end

-- ===========================================================
-- ANIMATION HANDLING
-- ===========================================================

-- Internal: Animate item entry
function ListView:_animateItemEntry(item_data, callback)
    if self.entry_animation == ITEM_ANIMATIONS.NONE then
        if callback then callback() end
        return
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    if not AnimationEngine then
        debug_print("WARN", "ListView._animateItemEntry: AnimationEngine not available for %s", self.id)
        if callback then callback() end
        return
    end
    
    -- Get the actual object to animate
    local object_to_animate = nil
    if item_data.is_widget and item_data.data.widget then
        object_to_animate = item_data.data.widget
    elseif item_data.is_sprite then
        object_to_animate = self.sprite_objects[item_data.data.sprite_id]
    end
    
    if not object_to_animate then
        if callback then callback() end
        return
    end
    
    -- Store original properties for restoration
    local original_opacity = object_to_animate.opacity or 255
    local original_scale = object_to_animate.sx or 1.0
    local original_position = {x = object_to_animate.x or 0, y = object_to_animate.y or 0}
    
    -- Apply entry animation
    if self.entry_animation == ITEM_ANIMATIONS.FADE then
        object_to_animate:setOpacity(0)
        item_data.animation_id = object_to_animate:animate_opacity(
            original_opacity,
            self.entry_duration,
            {
                easing = self.entry_easing,
                on_complete = function()
                    item_data.animation_id = nil
                    if callback then callback() end
                end
            }
        )
        
    elseif self.entry_animation == ITEM_ANIMATIONS.SLIDE then
        local slide_from = self.orientation == SCROLL_DIRECTIONS.VERTICAL and 
                          {x = original_position.x, y = original_position.y - 50} or
                          {x = original_position.x - 50, y = original_position.y}
        
        object_to_animate:setPosition(slide_from.x, slide_from.y)
        item_data.animation_id = object_to_animate:animate_position(
            original_position.x, original_position.y,
            self.entry_duration,
            {
                easing = self.entry_easing,
                on_complete = function()
                    item_data.animation_id = nil
                    if callback then callback() end
                end
            }
        )
        
    elseif self.entry_animation == ITEM_ANIMATIONS.SCALE then
        object_to_animate:setScale(0.1, 0.1)
        item_data.animation_id = object_to_animate:scale_widget(
            original_scale,
            self.entry_duration,
            self.entry_easing,
            function()
                item_data.animation_id = nil
                if callback then callback() end
            end
        )
        
    elseif self.entry_animation == ITEM_ANIMATIONS.BOUNCE then
        object_to_animate:setScale(0.1, 0.1)
        item_data.animation_id = object_to_animate:pulse_scale_widget(
            0.1, original_scale * 1.2, self.entry_duration,
            self.entry_easing, 2, function()
                item_data.animation_id = nil
                if callback then callback() end
            end
        )
        
    elseif self.entry_animation == ITEM_ANIMATIONS.SUMMON then
        local summon_from = {
            x = original_position.x - 100,
            y = original_position.y - 100
        }
        
        object_to_animate:setPosition(summon_from.x, summon_from.y)
        object_to_animate:setScale(0.5, 0.5)
        
        item_data.animation_id = object_to_animate:summon_widget(
            summon_from.x, summon_from.y, 0.5,
            original_position.x, original_position.y, original_scale,
            self.entry_duration, 50, 1.5, 10, self.entry_easing,
            function()
                item_data.animation_id = nil
                if callback then callback() end
            end
        )
        
    elseif self.entry_animation == ITEM_ANIMATIONS.CUSTOM and self.custom_entry_animation then
        item_data.animation_id = self.custom_entry_animation(
            object_to_animate, item_data, 
            function()
                item_data.animation_id = nil
                if callback then callback() end
            end
        )
    end
    
    if item_data.animation_id then
        debug_print("DETAILED", "ListView._animateItemEntry: %s animating item %s entry", 
                   self.id, item_data.id)
    end
end

-- Internal: Animate item exit
function ListView:_animateItemExit(item_data, callback)
    if self.exit_animation == ITEM_ANIMATIONS.NONE then
        if callback then callback() end
        return
    end
    
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    if not AnimationEngine then
        debug_print("WARN", "ListView._animateItemExit: AnimationEngine not available for %s", self.id)
        if callback then callback() end
        return
    end
    
    -- Get the actual object to animate
    local object_to_animate = nil
    if item_data.is_widget and item_data.data.widget then
        object_to_animate = item_data.data.widget
    elseif item_data.is_sprite then
        object_to_animate = self.sprite_objects[item_data.data.sprite_id]
    end
    
    if not object_to_animate then
        if callback then callback() end
        return
    end
    
    -- Apply exit animation
    if self.exit_animation == ITEM_ANIMATIONS.FADE then
        item_data.animation_id = object_to_animate:animate_opacity(
            0,
            self.exit_duration,
            {
                easing = self.exit_easing,
                on_complete = function()
                    item_data.animation_id = nil
                    object_to_animate:setOpacity(255)  -- Restore for potential reuse
                    if callback then callback() end
                end
            }
        )
        
    elseif self.exit_animation == ITEM_ANIMATIONS.SLIDE then
        local slide_to = self.orientation == SCROLL_DIRECTIONS.VERTICAL and 
                        {x = object_to_animate.x, y = object_to_animate.y + 50} or
                        {x = object_to_animate.x + 50, y = object_to_animate.y}
        
        item_data.animation_id = object_to_animate:animate_position(
            slide_to.x, slide_to.y,
            self.exit_duration,
            {
                easing = self.exit_easing,
                on_complete = function()
                    item_data.animation_id = nil
                    if callback then callback() end
                end
            }
        )
        
    elseif self.exit_animation == ITEM_ANIMATIONS.SCALE then
        item_data.animation_id = object_to_animate:scale_widget(
            0.1,
            self.exit_duration,
            self.exit_easing,
            function()
                item_data.animation_id = nil
                if callback then callback() end
            end
        )
        
    elseif self.exit_animation == ITEM_ANIMATIONS.CUSTOM and self.custom_exit_animation then
        item_data.animation_id = self.custom_exit_animation(
            object_to_animate, item_data, 
            function()
                item_data.animation_id = nil
                if callback then callback() end
            end
        )
    end
    
    if item_data.animation_id then
        debug_print("DETAILED", "ListView._animateItemExit: %s animating item %s exit", 
                   self.id, item_data.id)
    end
end

-- Internal: Item entered view callback
function ListView:_onItemEnterView(item_data)
    if self.animate_on_scroll and self.entry_animation ~= ITEM_ANIMATIONS.NONE then
        self:_animateItemEntry(item_data)
    end
    
    if self.on_item_enter_view then
        self.on_item_enter_view(item_data)
    end
    
    debug_print("VERBOSE", "ListView._onItemEnterView: %s item %s entered view", 
               self.id, item_data.id)
end

-- Internal: Item exited view callback
function ListView:_onItemExitView(item_data)
    if self.animate_on_scroll and self.exit_animation ~= ITEM_ANIMATIONS.NONE then
        -- Don't animate exit during scroll if item might come back soon
        -- Could add a delay here
    end
    
    if self.on_item_exit_view then
        self.on_item_exit_view(item_data)
    end
    
    debug_print("VERBOSE", "ListView._onItemExitView: %s item %s exited view", 
               self.id, item_data.id)
end

-- Set custom animation functions
function ListView:setCustomAnimations(entry_func, exit_func)
    self.custom_entry_animation = entry_func
    self.custom_exit_animation = exit_func
    self.entry_animation = ITEM_ANIMATIONS.CUSTOM
    self.exit_animation = ITEM_ANIMATIONS.CUSTOM
    
    debug_print("DETAILED", "ListView.setCustomAnimations: %s set custom animations", self.id)
    return self
end

-- ===========================================================
-- UPDATE AND TICK
-- ===========================================================

-- Update method (called every frame)
function ListView:update(dt)
    debug_print("VERBOSE", "ListView.update: %s with dt=%f, scroll=%g, velocity=%g", 
               self.id, dt, self.scroll_position, self.scroll_velocity)
    
    local updated = false
    
    -- Handle auto-scroll
    if self.scroll_behavior == SCROLL_BEHAVIORS.AUTO and self.scroll_speed ~= 0 then
        self.scroll_position = self.scroll_position + self.scroll_speed * dt
        self.needs_rebuild = true
        updated = true
    end
    
    -- Handle inertia
    if self.scroll_velocity ~= 0 and self.scroll_inertia_enabled then
        self.scroll_position = self.scroll_position + self.scroll_velocity * dt
        self.scroll_velocity = self.scroll_velocity * self.scroll_friction
        
        -- Stop if velocity is very small
        if math.abs(self.scroll_velocity) < 0.1 then
            self.scroll_velocity = 0
        end
        
        self.needs_rebuild = true
        updated = true
    end
    
    -- Constrain scroll position (with bounce if enabled)
    self:_constrainScrollPosition()
    
    -- Update layout if needed
    if self.needs_rebuild or self.state.dirty then
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

-- ===========================================================
-- DESTROY METHOD (to clean up event handlers)
-- ===========================================================

function ListView:destroy()
    debug_print("INFO", "ListView.destroy: %s", self.id)
    
    -- Clean up event handlers (like cursor.lua)
    if self.event_handlers and self.event_handlers.virtual_input then
        self:_removeVirtualInputHandler()
    end
    
    -- Call parent destroy
    return Widget.destroy(self)
end

-- ===========================================================
-- DEBUG AND UTILITY METHODS
-- ===========================================================

function ListView:printDebugInfo(level)
    level = level or 0
    local indent = string.rep("  ", level)
    
    Widget.printDebugInfo(self, level)
    
    print(indent .. "ListView Widget Details:")
    print(indent .. "  Orientation: " .. self.orientation)
    print(indent .. "  Scroll Behavior: " .. self.scroll_behavior)
    print(indent .. "  Scroll Position: " .. string.format("%g", self.scroll_position) .. 
          "/" .. string.format("%g", self.max_scroll_position))
    print(indent .. "  Scroll Velocity: " .. string.format("%g", self.scroll_velocity))
    print(indent .. "  Items: " .. #self.all_items .. " total, " .. #self.items_in_view .. " visible")
    print(indent .. "  Item Spacing: " .. string.format("%g", self.item_spacing))
    print(indent .. "  Item Alignment: " .. self.item_alignment)
    print(indent .. "  Viewport: " .. string.format("%g", self.viewport_width) .. "x" .. 
          string.format("%g", self.viewport_height) .. " at (" .. 
          string.format("%g", self.viewport_x) .. "," .. string.format("%g", self.viewport_y) .. ")")
    print(indent .. "  Animations: entry=" .. self.entry_animation .. ", exit=" .. self.exit_animation)
    print(indent .. "  Accepts Input: " .. tostring(self.accepts_input))
    print(indent .. "  Virtual Input: " .. tostring(self.virtual_input_enabled))
    print(indent .. "  Selection Enabled: " .. tostring(self.selection_enabled))
    print(indent .. "  Selected Item: " .. tostring(self.selected_item_index) .. 
          " (" .. tostring(self.selected_item_id) .. ")")
    print(indent .. "  Snap Enabled: " .. tostring(self.snap_enabled))
    print(indent .. "  Virtualization: " .. tostring(self.virtualization_enabled))
    print(indent .. "  Needs Rebuild: " .. tostring(self.needs_rebuild))
    
    if #self.items_in_view > 0 then
        print(indent .. "  Items in View:")
        for i, item in ipairs(self.items_in_view) do
            local cached = self.item_cache[item.id]
            if cached then
                local selected = (self.selected_item_id == item.id) and " [SELECTED]" or ""
                print(indent .. "    " .. i .. ": " .. item.id .. 
                      " at (" .. string.format("%g", cached.x) .. "," .. 
                      string.format("%g", cached.y) .. ") " .. 
                      string.format("%g", cached.width) .. "x" .. 
                      string.format("%g", cached.height) .. selected)
            end
        end
    end
end

-- Get scroll percentage (0-1)
function ListView:getScrollPercentage()
    if self.max_scroll_position <= 0 then
        return 0
    end
    return self.scroll_position / self.max_scroll_position
end

-- Get viewport dimensions
function ListView:getViewportDimensions()
    local size = self:_getViewportSize()
    return self.viewport_x, self.viewport_y, size.width, size.height
end

-- Check if item is in view
function ListView:isItemInView(item_id)
    for _, item in ipairs(self.items_in_view) do
        if item.id == item_id then
            return true
        end
    end
    return false
end

-- Force rebuild of layout
function ListView:rebuild()
    self.needs_rebuild = true
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

-- ===========================================================
-- STATIC CONSTANTS (for external use)
-- ===========================================================

ListView.ITEM_ANIMATIONS = ITEM_ANIMATIONS
ListView.SCROLL_DIRECTIONS = SCROLL_DIRECTIONS
ListView.SCROLL_BEHAVIORS = SCROLL_BEHAVIORS

return ListView