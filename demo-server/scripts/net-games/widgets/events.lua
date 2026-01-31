-- widgets/widget-events.lua
-- Event handling for widgets with cursor integration

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local SelectionManager = require('scripts/net-games/widgets/selection-manager')

local WidgetEvents = {
    selection_manager = nil
}

function WidgetEvents.initialize()
    debug_print("INFO", "WidgetEvents.initialize")
    
    WidgetEvents.selection_manager = SelectionManager.new()
    
    -- Hook into virtual_input events
    Net:on("virtual_input", function(event)
        if not WidgetEvents.selection_manager then
            debug_print("WARN", "WidgetEvents: selection_manager not initialized")
            return
        end
        
        debug_print("VERBOSE", "WidgetEvents: virtual_input from player %s", event.player_id)
        
        for _, button in ipairs(event.events) do
            debug_print("VERBOSE", "  Button: %s, state: %d", button.name, button.state)
            
            if button.state == 1 then -- Button pressed
                if button.name == "Move Up" then
                    debug_print("INFO", "WidgetEvents: Move Up pressed")
                    WidgetEvents.selection_manager:moveSelection("up")
                elseif button.name == "Move Down" then
                    debug_print("INFO", "WidgetEvents: Move Down pressed")
                    WidgetEvents.selection_manager:moveSelection("down")
                elseif button.name == "Move Left" then
                    debug_print("INFO", "WidgetEvents: Move Left pressed")
                    WidgetEvents.selection_manager:moveSelection("left")
                elseif button.name == "Move Right" then
                    debug_print("INFO", "WidgetEvents: Move Right pressed")
                    WidgetEvents.selection_manager:moveSelection("right")
                elseif button.name == "Interact" or button.name == "Confirm" then
                    debug_print("INFO", "WidgetEvents: Confirm pressed")
                    local selected_item = WidgetEvents.selection_manager:getSelectedItem()
                    if selected_item then
                        debug_print("INFO", "WidgetEvents: Emitting widget_item_selected for %s", selected_item.id)
                        Net:emit("widget_item_selected", {
                            player_id = event.player_id,
                            item = selected_item
                        })
                    else
                        debug_print("WARN", "WidgetEvents: No item selected")
                    end
                end
            end
        end
    end)
    
    -- Widget item selected event
    Net:on("widget_item_selected", function(event)
        debug_print("INFO", "WidgetEvents: widget_item_selected: %s", 
                   event.item and event.item.id or "unknown")
        print("[widgets] Item selected: " .. (event.item.id or "unknown"))
    end)
    
    -- Cursor events integration
    Net:on("cursor_move", function(event)
        debug_print("INFO", "WidgetEvents: cursor_move: %s direction %s", 
                   event.cursor, event.direction or "unknown")
        
        -- Optionally sync selection manager with cursor movement
        if WidgetEvents.selection_manager and WidgetEvents.selection_manager.cursor_id == event.cursor then
            if event.direction == "up" then
                WidgetEvents.selection_manager:moveSelection("up")
            elseif event.direction == "down" then
                WidgetEvents.selection_manager:moveSelection("down")
            elseif event.direction == "left" then
                WidgetEvents.selection_manager:moveSelection("left")
            elseif event.direction == "right" then
                WidgetEvents.selection_manager:moveSelection("right")
            end
        end
    end)
    
    Net:on("cursor_selection", function(event)
        debug_print("INFO", "WidgetEvents: cursor_selection: %s selected %s", 
                   event.cursor, event.selection)
        
        -- Forward cursor selection as widget item selection
        Net:emit("widget_item_selected", {
            player_id = event.player_id,
            cursor = event.cursor,
            selection = event.selection
        })
    end)
    
    Net:on("cursor_hover", function(event)
        debug_print("VERBOSE", "WidgetEvents: cursor_hover: %s hovering over %s", 
                   event.cursor, event.selection)
        
        -- Can be used for highlighting or other hover effects
    end)
    
    debug_print("INFO", "WidgetEvents initialized successfully with cursor integration")
end

return WidgetEvents