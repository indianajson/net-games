-- widgets/widget-container.lua
-- Container widget that holds a single child widget
local Widget = require('scripts/net-games/widgets/base-widget')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print

local Container = {}
setmetatable(Container, {__index = Widget})

function Container.new(id, player_id)
    local self = Widget.new(id, player_id, "Container")
    setmetatable(self, {__index = Container})

    self.child = nil

    debug_print("INFO", "Container created: %s", self.id)

    return self
end

function Container:setChild(widget)
    debug_print("INFO", "Container.setChild: %s setting child to %s", self.id,
                widget and widget.id or "nil")

    if self.child then
        debug_print("VERBOSE", "  Removing previous child")
        self:removeWidget(self.child.id)
    end

    self.child = widget
    if widget then
        widget.parent = self
        self:addWidget(widget)
        debug_print("VERBOSE", "  Child parent set")
    end

    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Container:calculateLayout(available_width, available_height)
    if not self.child then
        debug_print("WARN", "Container.calculateLayout: %s has no child",
                    self.id)
        return 0, 0, {}
    end

    debug_print("DETAILED", "Container.calculateLayout: %s with child %s",
                self.id, self.child.id)

    -- Calculate available space for child
    local child_width = available_width - self.padding.left - self.padding.right
    local child_height = available_height - self.padding.top -
                             self.padding.bottom

    debug_print("DETAILED", "  Available for child: %gx%g (after padding)",
                child_width, child_height)

    -- Update child layout
    self.child:setSize(child_width, child_height)
    self.child:updateLayout()

    local child_layout_width, child_layout_height =
        self.child:getCalculatedSize()

    debug_print("DETAILED", "  Child calculated size: %gx%g",
                child_layout_width, child_layout_height)

    -- Position child
    local positioned_children = {
        {
            widget = self.child,
            x = self.padding.left,
            y = self.padding.top,
            visible = self.state.visible
        }
    }

    local layout_width = child_layout_width + self.padding.left +
                             self.padding.right
    local layout_height = child_layout_height + self.padding.top +
                              self.padding.bottom

    debug_print("INFO", "Container layout calculated: %s = %gx%g", self.id,
                layout_width, layout_height)

    return layout_width, layout_height, positioned_children
end

return Container