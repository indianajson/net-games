-- widgets/selection-manager.lua
-- Manages selection between multiple widgets with optional cursor support
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print

local SelectionManager = {}

function SelectionManager.new()
    local self = {
        selected_widget = nil,
        selected_index = 0,
        widgets = {},
        on_selection_changed = nil,
        movement_type = "vertical", -- vertical, horizontal, grid
        cursor_id = nil, -- Optional cursor ID for visual feedback
        cursor_player_id = nil
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

            -- Move cursor if one is attached
            if self.cursor_id and self.cursor_player_id then
                self:moveCursorToSelectedItem()
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

            -- Move cursor if one is attached
            if self.cursor_id and self.cursor_player_id then
                self:moveCursorToSelectedItem()
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

    function self:moveCursorToSelectedItem()
        if not self.cursor_id or not self.cursor_player_id then
            return false
        end
        
        if not self.selected_widget then
            return false
        end
        
        -- Get the selected item
        local selected_item = self:getSelectedItem()
        if not selected_item then
            return false
        end
        
        -- Calculate cursor position based on selected item
        local cursor_x, cursor_y = 0, 0
        
        if self.selected_widget.widget_type == "Grid" then
            -- For grid, position cursor at the center of the selected cell
            local columns = self.selected_widget.columns or 3
            local row = math.floor((self.selected_index - 1) / columns)
            local col = (self.selected_index - 1) % columns
            
            local cell_width = self.selected_widget.cell_width or 32
            local cell_height = self.selected_widget.cell_height or 32
            local hspacing = self.selected_widget.horizontal_spacing or 0
            local vspacing = self.selected_widget.vertical_spacing or 0
            
            cursor_x = col * (cell_width + hspacing) + (cell_width / 2)
            cursor_y = row * (cell_height + vspacing) + (cell_height / 2)
            
            -- Add widget position
            cursor_x = cursor_x + self.selected_widget.x
            cursor_y = cursor_y + self.selected_widget.y
            
        elseif self.selected_widget.widget_type == "Row" then
            -- For row, position cursor at the center of the selected child
            local child = self.selected_widget.children[self.selected_index]
            if child then
                if child.widget then
                    cursor_x = child.widget.x + (child.widget.width or 32) / 2
                    cursor_y = child.widget.y + (child.widget.height or 32) / 2
                else
                    cursor_x = child.x or 0
                    cursor_y = child.y or 0
                end
            end
            
        elseif self.selected_widget.widget_type == "Column" then
            -- For column, position cursor at the center of the selected child
            local child = self.selected_widget.children[self.selected_index]
            if child then
                if child.widget then
                    cursor_x = child.widget.x + (child.widget.width or 32) / 2
                    cursor_y = child.widget.y + (child.widget.height or 32) / 2
                else
                    cursor_x = child.x or 0
                    cursor_y = child.y or 0
                end
            end
        end
        
        -- Move the cursor to the calculated position
        if Net and Net.emit then
            Net:emit("cursor_move_to_position", {
                player_id = self.cursor_player_id,
                cursor_id = self.cursor_id,
                x = cursor_x,
                y = cursor_y,
                selection_index = self.selected_index
            })
        end
        
        return true
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

    -- Attach a cursor to this selection manager
    function self:attachCursor(cursor_id, player_id)
        self.cursor_id = cursor_id
        self.cursor_player_id = player_id
        debug_print("INFO", "SelectionManager.attachCursor: %s for player %s",
                    cursor_id, player_id)
        return self
    end

    -- Detach cursor from selection manager
    function self:detachCursor()
        self.cursor_id = nil
        self.cursor_player_id = nil
        debug_print("INFO", "SelectionManager.detachCursor")
        return self
    end

    -- Get cursor position for current selection
    function self:getCursorPositionForSelection()
        if not self.selected_widget then
            return nil
        end
        
        local cursor_x, cursor_y = 0, 0
        
        if self.selected_widget.widget_type == "Grid" then
            local columns = self.selected_widget.columns or 3
            local row = math.floor((self.selected_index - 1) / columns)
            local col = (self.selected_index - 1) % columns
            
            local cell_width = self.selected_widget.cell_width or 32
            local cell_height = self.selected_widget.cell_height or 32
            local hspacing = self.selected_widget.horizontal_spacing or 0
            local vspacing = self.selected_widget.vertical_spacing or 0
            
            cursor_x = col * (cell_width + hspacing) + (cell_width / 2)
            cursor_y = row * (cell_height + vspacing) + (cell_height / 2)
            
        elseif self.selected_widget.widget_type == "Row" then
            local child = self.selected_widget.children[self.selected_index]
            if child then
                cursor_x = child.x or 0
                cursor_y = child.y or 0
                if child.widget then
                    cursor_x = cursor_x + (child.widget.width or 32) / 2
                    cursor_y = cursor_y + (child.widget.height or 32) / 2
                else
                    cursor_x = cursor_x + 16
                    cursor_y = cursor_y + 16
                end
            end
            
        elseif self.selected_widget.widget_type == "Column" then
            local child = self.selected_widget.children[self.selected_index]
            if child then
                cursor_x = child.x or 0
                cursor_y = child.y or 0
                if child.widget then
                    cursor_x = cursor_x + (child.widget.width or 32) / 2
                    cursor_y = cursor_y + (child.widget.height or 32) / 2
                else
                    cursor_x = cursor_x + 16
                    cursor_y = cursor_y + 16
                end
            end
        end
        
        -- Add widget position
        cursor_x = cursor_x + self.selected_widget.x
        cursor_y = cursor_y + self.selected_widget.y
        
        return cursor_x, cursor_y
    end

    function self:printDebugInfo()
        print("[SelectionManager Debug]")
        print("  Selected widget:",
              self.selected_widget and self.selected_widget.id or "nil")
        print("  Selected index:", self.selected_index)
        print("  Registered widgets:", #self.widgets)
        for id, _ in pairs(self.widgets) do print("    - " .. id) end
        print("  Cursor attached:", self.cursor_id or "none")
        if self.cursor_id then
            print("    - Cursor ID:", self.cursor_id)
            print("    - Player ID:", self.cursor_player_id)
        end
    end

    return self
end

return SelectionManager