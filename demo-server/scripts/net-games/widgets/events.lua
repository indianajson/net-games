-- widgets/widget-events.lua
-- Event handling for widgets

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
    
    debug_print("INFO", "WidgetEvents initialized successfully")
end

return WidgetEvents