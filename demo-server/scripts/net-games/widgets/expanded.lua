-- widgets/widget-expanded.lua
-- Expanded widget that takes all available space

local Widget = require('scripts/net-games/widgets/base-widget')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print

local Expanded = {}
setmetatable(Expanded, {__index = Widget})

function Expanded.new(id, player_id)
    local self = Widget.new(id, player_id, "Expanded")
    setmetatable(self, {__index = Expanded})
    
    self.flex = 1
    self.child = nil
    
    debug_print("INFO", "Expanded created: %s", self.id)
    
    return self
end

function Expanded:setFlex(flex)
    self.flex = math.max(1, flex or 1)
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Expanded.setFlex: %s = %d", self.id, self.flex)
    
    return self
end

function Expanded:setChild(widget)
    debug_print("INFO", "Expanded.setChild: %s setting child to %s", 
               self.id, widget and widget.id or "nil")
    
    if self.child then
        debug_print("VERBOSE", "  Removing previous child")
        self:removeWidget(self.child.id)
    end
    
    self.child = widget
    if widget then
        widget.parent = self
        self:addWidget(widget)
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Expanded:calculateLayout(available_width, available_height)
    if not self.child then
        debug_print("WARN", "Expanded.calculateLayout: %s has no child", self.id)
        return 0, 0, {}
    end
    
    debug_print("DETAILED", "Expanded.calculateLayout: %s with child %s, taking %dx%d", 
               self.id, self.child.id, available_width, available_height)
    
    -- Expanded takes all available space
    self.child:setSize(available_width, available_height)
    self.child:updateLayout()
    
    local child_layout_width, child_layout_height = self.child:getCalculatedSize()
    
    local positioned_children = {{
        widget = self.child,
        x = 0,
        y = 0,
        visible = self.state.visible
    }}
    
    return child_layout_width, child_layout_height, positioned_children
end

return Expanded