-- widgets/cursor.lua
-- Dedicated cursor management for the widget system

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local Cursor = {}

-- Cache for cursors: player_id -> cursor_id -> cursor_data
local _cursor_cache = {}

function Cursor.new(cursor_id, player_id, options)
    if not cursor_id or not player_id then
        debug_print("ERROR", "Cursor.new: Invalid parameters")
        return nil
    end
    
    local self = {}
    setmetatable(self, {__index = Cursor})
    
    self.id = cursor_id
    self.player_id = player_id
    self.widget = nil
    self.sprite = nil
    self.options = {
        selections = options.selections or {},
        movement = options.movement or "vertical",
        current_index = 1,
        locked = false,
        name = cursor_id
    }
    self.event_handlers = {}
    
    -- Initialize
    self:_initialize(options)
    
    return self
end

function Cursor:_initialize(options)
    debug_print("INFO", "Cursor._initialize: %s for player %s", self.id, self.player_id)
    
    -- Create widget for the cursor
    local Container = require('scripts/net-games/widgets/container')
    self.widget = Container.new(self.id .. "_widget", self.player_id)
    self.widget:setPosition(0, 0)
    
    -- Add the cursor sprite
    self.sprite = self.widget:create_sprite(
        self.id .. "_sprite",
        options.texture or "path/to/default/cursor",
        options.anim_path or "",
        options.anim_state or "normal"
    )
    
    if options.x and options.y then
        self.sprite:set_position(options.x, options.y)
    end
    
    -- Set initial position if selections exist
    if #self.options.selections > 0 then
        local initial_selection = self.options.selections[1]
        self.widget:setPosition(initial_selection.x, initial_selection.y)
        if initial_selection.state then
            self.sprite:update({anim_state = initial_selection.state})
        end
    end
    
    -- Lock player input if specified
    if options.lock_input then
        if Net and Net.lock_player_input then
            Net.lock_player_input(self.player_id)
        end
    end
    
    -- Store in cache
    if not _cursor_cache[self.player_id] then
        _cursor_cache[self.player_id] = {}
    end
    _cursor_cache[self.player_id][self.id] = self
    
    debug_print("INFO", "Cursor initialized: %s with %d selections", 
               self.id, #self.options.selections)
end

function Cursor:destroy()
    debug_print("INFO", "Cursor.destroy: %s", self.id)
    
    -- Clean up event handlers
    if self.event_handlers and self.event_handlers.virtual_input then
        -- Note: Unregistering event handlers depends on your Net API
        self.event_handlers.virtual_input = nil
    end
    
    -- Remove the widget
    if self.widget then
        self.widget:destroy()
    end
    
    -- Remove from cache
    if _cursor_cache[self.player_id] then
        _cursor_cache[self.player_id][self.id] = nil
    end
    
    -- Unlock player input
    if Net and Net.unlock_player_input then
        Net.unlock_player_input(self.player_id)
    end
    
    return true
end

function Cursor:moveToSelection(selection_name)
    local selections = self.options.selections
    
    -- Find selection by name
    for i, selection in ipairs(selections) do
        if selection.name == selection_name then
            self.options.current_index = i
            
            -- Animate cursor movement
            self.widget:slide_widget(
                selection.x, 
                selection.y, 
                0.15,  -- duration
                "ease_out_quad",  -- easing
                function()
                    -- Update animation state
                    if selection.state then
                        self.sprite:update({anim_state = selection.state})
                    end
                    
                    -- Emit hover event
                    if Net and Net.emit then
                        Net:emit("cursor_hover", {
                            player_id = self.player_id,
                            cursor = self.id,
                            selection = selection_name
                        })
                    end
                end
            )
            
            return true
        end
    end
    
    return false
end

function Cursor:moveToPosition(x, y, duration, easing)
    duration = duration or 0.15
    easing = easing or "ease_out_quad"
    
    self.widget:slide_widget(
        x, 
        y, 
        duration,
        easing,
        function()
            if Net and Net.emit then
                Net:emit("cursor_moved", {
                    player_id = self.player_id,
                    cursor = self.id,
                    x = x,
                    y = y
                })
            end
        end
    )
    
    return true
end

function Cursor:moveToIndex(index)
    local selections = self.options.selections
    if index < 1 or index > #selections then
        return false
    end
    
    local selection = selections[index]
    self.options.current_index = index
    
    return self:moveToSelection(selection.name)
end

function Cursor:move(direction)
    local selections = self.options.selections
    if #selections == 0 then
        return false
    end
    
    local current_index = self.options.current_index or 1
    local new_index = current_index
    
    if direction == "down" or direction == "right" then
        new_index = (current_index == #selections) and 1 or (current_index + 1)
    elseif direction == "up" or direction == "left" then
        new_index = (current_index == 1) and #selections or (current_index - 1)
    else
        return false
    end
    
    return self:moveToIndex(new_index)
end

function Cursor:getCurrentSelection()
    local current_index = self.options.current_index
    
    if current_index and self.options.selections[current_index] then
        return self.options.selections[current_index]
    end
    
    return nil
end

function Cursor:setLocked(locked)
    self.options.locked = locked ~= false
    return true
end

function Cursor:isLocked()
    return self.options.locked or false
end

function Cursor:updateOptions(new_options)
    -- Merge new options
    if new_options.selections then
        self.options.selections = new_options.selections
    end
    if new_options.movement then
        self.options.movement = new_options.movement
    end
    if new_options.current_index then
        self.options.current_index = new_options.current_index
    end
    if new_options.locked ~= nil then
        self.options.locked = new_options.locked
    end
    
    return true
end

function Cursor:setupControls()
    if not Net or not Net.on then
        debug_print("WARN", "Cursor.setupControls: Net module not available")
        return false
    end
    
    local function handle_cursor_input(event)
        if event.player_id ~= self.player_id then
            return
        end
        
        if self.options.locked then
            return
        end
        
        local direction = self.options.movement or "vertical"
        
        for _, button in ipairs(event.events) do
            -- Cursor movement
            local should_move = false
            local move_direction = nil
            
            if direction == "vertical" then
                if (button.name == "Move Down" and (button.state == 1 or button.state == 4)) then
                    should_move = true
                    move_direction = "down"
                elseif (button.name == "Move Up" and (button.state == 1 or button.state == 4)) then
                    should_move = true
                    move_direction = "up"
                end
            elseif direction == "horizontal" then
                if (button.name == "Move Right" and (button.state == 1 or button.state == 4)) then
                    should_move = true
                    move_direction = "right"
                elseif (button.name == "Move Left" and (button.state == 1 or button.state == 4)) then
                    should_move = true
                    move_direction = "left"
                end
            elseif direction == "shoulder" then
                if (button.name == "Shoulder R" and (button.state == 1 or button.state == 4)) then
                    should_move = true
                    move_direction = "right"
                elseif (button.name == "Shoulder L" and (button.state == 1 or button.state == 4)) then
                    should_move = true
                    move_direction = "left"
                end
            end
            
            if should_move then
                self:move(move_direction)
                
            -- Cursor selection
            elseif (button.name == "Interact" or button.name == "Confirm") and button.state == 1 then
                local current_selection = self:getCurrentSelection()
                if current_selection then
                    if Net and Net.emit then
                        Net:emit("cursor_selection", {
                            player_id = self.player_id,
                            cursor = self.id,
                            selection = current_selection.name
                        })
                    end
                end
            end
        end
    end
    
    -- Register the event handler
    Net:on("virtual_input", handle_cursor_input)
    
    -- Store for cleanup
    self.event_handlers.virtual_input = handle_cursor_input
    
    return true
end

-- Static methods
function Cursor.get(cursor_id, player_id)
    if not _cursor_cache[player_id] then
        return nil
    end
    
    return _cursor_cache[player_id][cursor_id]
end

function Cursor.getAll(player_id)
    if not _cursor_cache[player_id] then
        return {}
    end
    
    local cursors = {}
    for cursor_id, cursor in pairs(_cursor_cache[player_id]) do
        table.insert(cursors, cursor)
    end
    
    return cursors
end

function Cursor.clearAll(player_id)
    if not _cursor_cache[player_id] then
        return 0
    end
    
    local count = 0
    for cursor_id, cursor in pairs(_cursor_cache[player_id]) do
        cursor:destroy()
        count = count + 1
    end
    
    _cursor_cache[player_id] = nil
    
    debug_print("INFO", "Cursor.clearAll: Cleared %d cursors for player %s", count, player_id)
    return count
end

-- Helper function to create selections from widget
function Cursor.createSelectionsFromWidget(widget, spacing_x, spacing_y, start_x, start_y)
    if not widget or not widget.children then
        return {}
    end
    
    local selections = {}
    local current_x = start_x or 0
    local current_y = start_y or 0
    
    for i, child in ipairs(widget.children) do
        local selection = {
            name = child.id or ("selection_" .. i),
            x = current_x,
            y = current_y,
            state = child.anim_state or "normal"
        }
        
        table.insert(selections, selection)
        
        -- Update position for next selection
        if widget.widget_type == "Row" then
            current_x = current_x + (child.layout_width or 32) + (spacing_x or 10)
        elseif widget.widget_type == "Column" then
            current_y = current_y + (child.layout_height or 32) + (spacing_y or 10)
        elseif widget.widget_type == "Grid" then
            local columns = widget.columns or 3
            if i % columns == 0 then
                current_x = start_x or 0
                current_y = current_y + (child.layout_height or 32) + (spacing_y or 10)
            else
                current_x = current_x + (child.layout_width or 32) + (spacing_x or 10)
            end
        end
    end
    
    return selections
end

return Cursor