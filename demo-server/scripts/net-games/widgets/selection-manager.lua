-- widgets/selection-manager.lua
-- Manages selection between multiple widgets
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print

local SelectionManager = {}

function SelectionManager.new()
    local self = {
        selected_widget = nil,
        selected_index = 0,
        widgets = {},
        on_selection_changed = nil,
        movement_type = "vertical" -- vertical, horizontal, grid
    }

    debug_print("INFO", "SelectionManager created")

    function self:registerWidget(widget)
        if widget and widget.id then
            self.widgets[widget.id] = widget
            debug_print("INFO", "SelectionManager.registerWidget: %s", widget.id)
        else
            debug_print("ERROR",
                        "SelectionManager.registerWidget: Invalid widget")
        end
    end

    function self:unregisterWidget(widget_id)
        debug_print("INFO", "SelectionManager.unregisterWidget: %s", widget_id)
        self.widgets[widget_id] = nil
    end

    function self:selectWidget(widget_id, index)
        debug_print("INFO", "SelectionManager.selectWidget: %s at index %d",
                    widget_id, index or 0)

        if self.widgets[widget_id] then
            local prev_widget = self.selected_widget

            if prev_widget and prev_widget.setSelectedIndex then
                debug_print("DETAILED",
                            "  Clearing selection from previous widget")
                prev_widget:setSelectedIndex(0, false)
            end

            self.selected_widget = self.widgets[widget_id]
            self.selected_index = index or 1

            if self.selected_widget.setSelectedIndex then
                debug_print("DETAILED", "  Setting selection on widget")
                self.selected_widget:setSelectedIndex(self.selected_index, false)
            end

            if self.on_selection_changed then
                debug_print("DETAILED",
                            "  Calling on_selection_changed callback")
                self.on_selection_changed(self.selected_widget,
                                          self.selected_index)
            end

            debug_print("INFO", "  Widget selected successfully")
            return true
        end

        debug_print("ERROR", "  Widget not found: %s", widget_id)
        return false
    end

    function self:moveSelection(direction)
        if not self.selected_widget then
            debug_print("WARN",
                        "SelectionManager.moveSelection: No widget selected")
            return false
        end

        debug_print("INFO",
                    "SelectionManager.moveSelection: %s in direction %s",
                    self.selected_widget.id, direction)

        local new_index = self.selected_index

        if direction == "up" or direction == "left" then
            new_index = math.max(1, self.selected_index - 1)
            debug_print("VERBOSE", "  Moving up/left: %d -> %d",
                        self.selected_index, new_index)
        elseif direction == "down" or direction == "right" then
            if self.selected_widget.items then
                new_index = math.min(#self.selected_widget.items,
                                     self.selected_index + 1)
                debug_print("VERBOSE", "  Moving down/right (items): %d -> %d",
                            self.selected_index, new_index)
            elseif self.selected_widget.children then
                new_index = math.min(#self.selected_widget.children,
                                     self.selected_index + 1)
                debug_print("VERBOSE",
                            "  Moving down/right (children): %d -> %d",
                            self.selected_index, new_index)
            end
        end

        if new_index ~= self.selected_index then
            self.selected_index = new_index

            if self.selected_widget.setSelectedIndex then
                debug_print("DETAILED", "  Updating widget selection")
                self.selected_widget:setSelectedIndex(self.selected_index, false)
            end

            if self.on_selection_changed then
                debug_print("DETAILED",
                            "  Calling on_selection_changed callback")
                self.on_selection_changed(self.selected_widget,
                                          self.selected_index)
            end

            debug_print("INFO", "  Selection moved successfully")
            return true
        end

        debug_print("VERBOSE", "  Selection unchanged")
        return false
    end

    function self:getSelectedItem()
        if not self.selected_widget or not self.selected_widget.items then
            debug_print("VERBOSE",
                        "SelectionManager.getSelectedItem: No item selected")
            return nil
        end

        local item = self.selected_widget.items[self.selected_index]
        debug_print("VERBOSE", "SelectionManager.getSelectedItem: %s",
                    item and item.id or "nil")
        return item
    end

    function self:clearSelection()
        debug_print("INFO", "SelectionManager.clearSelection")

        if self.selected_widget and self.selected_widget.setSelectedIndex then
            self.selected_widget:setSelectedIndex(0, false)
        end

        self.selected_widget = nil
        self.selected_index = 0
    end

    function self:printDebugInfo()
        print("[SelectionManager Debug]")
        print("  Selected widget:",
              self.selected_widget and self.selected_widget.id or "nil")
        print("  Selected index:", self.selected_index)
        print("  Registered widgets:", #self.widgets)
        for id, _ in pairs(self.widgets) do print("    - " .. id) end
    end

    return self
end

return SelectionManager
