-- widgets/widget-column.lua
-- Column widget that arranges children vertically

local Widget = require('scripts/net-games/widgets/base-widget')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local Column = {}
setmetatable(Column, {__index = Widget})

function Column.new(id, player_id)
    local self = Widget.new(id, player_id, "Column")
    setmetatable(self, {__index = Column})
    
    self.main_axis_alignment = "start"
    self.cross_axis_alignment = "start"
    self.spacing = 0
    
    debug_print("INFO", "Column created: %s", self.id)
    
    return self
end

function Column:setAlignment(main_axis, cross_axis)
    self.main_axis_alignment = main_axis or self.main_axis_alignment
    self.cross_axis_alignment = cross_axis or self.cross_axis_alignment
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Column.setAlignment: %s main=%s, cross=%s", 
               self.id, self.main_axis_alignment, self.cross_axis_alignment)
    
    return self
end

function Column:setSpacing(spacing)
    self.spacing = spacing or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Column.setSpacing: %s = %d", self.id, self.spacing)
    
    return self
end

function Column:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "Column.calculateLayout: %s with %d children", 
               self.id, #self.children)
    
    local total_height = 0
    local max_width = 0
    local positioned_children = {}
    
    debug_print("VERBOSE", "  Main axis alignment: %s", self.main_axis_alignment)
    debug_print("VERBOSE", "  Cross axis alignment: %s", self.cross_axis_alignment)
    debug_print("VERBOSE", "  Spacing: %d", self.spacing)
    
    -- First pass: calculate dimensions and collect positioned children
    for i, child in ipairs(self.children) do
        local child_width, child_height = 0, 0
        local child_id = nil
        local child_sprite_id = nil
        local child_widget = nil
        
        if child.type == "sprite" then
            child_id = child.id
            child_sprite_id = child.sprite_id
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                -- Use layout dimensions if specified, otherwise use visual dimensions
                if child.layout_width and child.layout_height then
                    -- Use custom layout dimensions (pre-scaling)
                    child_width = child.layout_width
                    child_height = child.layout_height
                    debug_print("DETAILED", "  Child %d using custom layout: %dx%d", 
                               i, child_width, child_height)
                else
                    -- Use visual dimensions (including scale)
                    child_width, child_height = sprite:get_visual_dimensions()
                    debug_print("DETAILED", "  Child %d using visual dimensions: %dx%d", 
                               i, child_width, child_height)
                end
            end
        elseif child.widget then
            child_id = child.widget.id
            child_widget = child.widget
            child_width, child_height = child.widget:getCalculatedSize()
            debug_print("DETAILED", "  Child %d widget dimensions: %dx%d", i, child_width, child_height)
        elseif child.width and child.height then
            child_id = child.id
            child_width = child.width
            child_height = child.height
            debug_print("DETAILED", "  Child %d explicit dimensions: %dx%d", i, child_width, child_height)
        else
            debug_print("WARN", "  Child %d has no dimensions!", i)
        end
        
        -- Adjust for cross axis alignment
        if self.cross_axis_alignment == "stretch" then
            child_width = math.max(child_width, available_width - self.padding.left - self.padding.right)
            debug_print("DETAILED", "    Stretched width to: %d", child_width)
        end
        
        -- Create positioned child object
        local positioned_child = {
            x = 0,
            y = total_height,
            width = child_width,
            height = child_height,
            visible = child.visible ~= false,
            id = child_id
        }
        
        -- Set type-specific properties
        if child_sprite_id then
            positioned_child.sprite_id = child_sprite_id
        elseif child.widget then
            positioned_child.widget = child.widget
        end
        
        table.insert(positioned_children, positioned_child)
        
        debug_print("DETAILED", "  Child %d positioned at x=%d, y=%d, size=%dx%d", 
                   i, positioned_child.x, positioned_child.y, child_width, child_height)
        
        total_height = total_height + child_height
        max_width = math.max(max_width, child_width)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_height = total_height + self.spacing
            debug_print("DETAILED", "  Added spacing: total_height now %d", total_height)
        end
    end
    
    debug_print("DETAILED", "  First pass total: max_width=%d, height=%d", max_width, total_height)
    
    -- Adjust for main axis alignment
    local extra_height = available_height - total_height - self.padding.top - self.padding.bottom
    debug_print("DETAILED", "  Extra height available: %d", extra_height)
    
    if extra_height > 0 then
        local start_y = 0
        
        if self.main_axis_alignment == "center" then
            start_y = extra_height / 2
            debug_print("DETAILED", "  Center alignment: start_y=%d", start_y)
        elseif self.main_axis_alignment == "end" then
            start_y = extra_height
            debug_print("DETAILED", "  End alignment: start_y=%d", start_y)
        elseif self.main_axis_alignment == "space_between" then
            if #positioned_children > 1 then
                local spacing = extra_height / (#positioned_children - 1)
                debug_print("DETAILED", "  Space between: spacing=%d", spacing)
                for i = 2, #positioned_children do
                    positioned_children[i].y = positioned_children[i].y + (spacing * (i - 1))
                end
            end
        elseif self.main_axis_alignment == "space_around" then
            local spacing = extra_height / #positioned_children
            debug_print("DETAILED", "  Space around: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].y = positioned_children[i].y + (spacing * (i - 0.5))
            end
        elseif self.main_axis_alignment == "space_evenly" then
            local spacing = extra_height / (#positioned_children + 1)
            debug_print("DETAILED", "  Space evenly: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].y = positioned_children[i].y + (spacing * i)
            end
        end
        
        -- Apply start offset
        if start_y > 0 then
            debug_print("DETAILED", "  Applying start offset: %d", start_y)
            for _, child in ipairs(positioned_children) do
                child.y = child.y + start_y
            end
        end
    end
    
    -- Adjust for cross axis alignment
    for i, child in ipairs(positioned_children) do
        local extra_width = max_width - child.width
        
        if self.cross_axis_alignment == "center" then
            child.x = extra_width / 2
            debug_print("DETAILED", "  Child %d centered horizontally: x=%d", i, child.x)
        elseif self.cross_axis_alignment == "end" then
            child.x = extra_width
            debug_print("DETAILED", "  Child %d aligned to end: x=%d", i, child.x)
        else
            debug_print("DETAILED", "  Child %d aligned to start: x=0", i)
        end
    end
    
    local layout_width = math.max(max_width, self.width)
    local layout_height = math.max(total_height, self.height)
    
    debug_print("INFO", "Column layout calculated: %s = %dx%d, positioned %d children", 
               self.id, layout_width, layout_height, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

return Column