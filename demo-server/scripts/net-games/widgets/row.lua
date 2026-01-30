-- widgets/widget-row.lua
-- Row widget that arranges children horizontally

local Widget = require('scripts/net-games/widgets/base-widget')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local Row = {}
setmetatable(Row, {__index = Widget})

function Row.new(id, player_id)
    local self = Widget.new(id, player_id, "Row")
    setmetatable(self, {__index = Row})
    
    self.main_axis_alignment = "start"
    self.cross_axis_alignment = "start"
    self.spacing = 0
    
    debug_print("INFO", "Row created: %s", self.id)
    
    return self
end

function Row:setAlignment(main_axis, cross_axis)
    self.main_axis_alignment = main_axis or self.main_axis_alignment
    self.cross_axis_alignment = cross_axis or self.cross_axis_alignment
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Row.setAlignment: %s main=%s, cross=%s", 
               self.id, self.main_axis_alignment, self.cross_axis_alignment)
    
    return self
end

function Row:setSpacing(spacing)
    self.spacing = spacing or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Row.setSpacing: %s = %d", self.id, self.spacing)
    
    return self
end

function Row:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "Row.calculateLayout: %s with %d children, available=%dx%d, position=(%d,%d)", 
               self.id, #self.children, available_width, available_height, self.x, self.y)
    
    local total_width = 0
    local max_height = 0
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
                    debug_print("DETAILED", "  Child %d sprite using custom layout: %dx%d", 
                               i, child_width, child_height)
                else
                    -- Use visual dimensions (including scale)
                    child_width, child_height = sprite:get_visual_dimensions()
                    debug_print("DETAILED", "  Child %d sprite using visual dimensions: %dx%d", 
                               i, child_width, child_height)
                end
            end
        elseif child.widget then
            child_id = child.widget.id
            child_widget = child.widget
            debug_print("DETAILED", "  Child %d is a widget: %s", i, child_widget.id)
            
            -- Set widget size based on available height unless specified
            if child_widget.height <= 0 then
                child_widget:setSize(child_widget.width, available_height)
            end
            
            -- Update the widget's layout first so it knows its own size
            child_widget:updateLayout()
            
            -- Get the widget's calculated size
            child_width, child_height = child_widget:getCalculatedSize()
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
        if self.cross_axis_alignment == "stretch" and child_widget then
            -- Only stretch widgets, not sprites
            child_widget:setSize(child_width, available_height)
            child_widget:updateLayout()
            child_width, child_height = child_widget:getCalculatedSize()
            debug_print("DETAILED", "    Stretched widget height to: %d", child_height)
        end
        
        -- Create positioned child object
        local positioned_child = {
            x = total_width,
            y = 0,
            width = child_width,
            height = child_height,
            visible = child.visible ~= false,
            id = child_id
        }
        
        -- Set type-specific properties
        if child_sprite_id then
            positioned_child.sprite_id = child_sprite_id
            positioned_child.is_sprite = true
        elseif child_widget then
            positioned_child.widget = child_widget
            positioned_child.is_widget = true
            positioned_child.widget_type = child_widget.widget_type or "Widget"
        end
        
        table.insert(positioned_children, positioned_child)
        
        debug_print("DETAILED", "  Child %d positioned at x=%d, y=%d, size=%dx%d, type=%s", 
                   i, positioned_child.x, positioned_child.y, child_width, child_height,
                   child_sprite_id and "sprite" or "widget")
        
        total_width = total_width + child_width
        max_height = math.max(max_height, child_height)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_width = total_width + self.spacing
            debug_print("DETAILED", "  Added spacing: total_width now %d", total_width)
        end
    end
    
    debug_print("DETAILED", "  First pass total: total_width=%d, max_height=%d", total_width, max_height)
    
    -- Adjust for main axis alignment
    local extra_width = available_width - total_width - self.padding.left - self.padding.right
    debug_print("DETAILED", "  Extra width available: %d", extra_width)
    
    if extra_width > 0 then
        local start_x = 0
        
        if self.main_axis_alignment == "center" then
            start_x = extra_width / 2
            debug_print("DETAILED", "  Center alignment: start_x=%d", start_x)
        elseif self.main_axis_alignment == "end" then
            start_x = extra_width
            debug_print("DETAILED", "  End alignment: start_x=%d", start_x)
        elseif self.main_axis_alignment == "space_between" then
            if #positioned_children > 1 then
                local spacing = extra_width / (#positioned_children - 1)
                debug_print("DETAILED", "  Space between: spacing=%d", spacing)
                for i = 2, #positioned_children do
                    positioned_children[i].x = positioned_children[i].x + (spacing * (i - 1))
                end
            end
        elseif self.main_axis_alignment == "space_around" then
            local spacing = extra_width / #positioned_children
            debug_print("DETAILED", "  Space around: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].x = positioned_children[i].x + (spacing * (i - 0.5))
            end
        elseif self.main_axis_alignment == "space_evenly" then
            local spacing = extra_width / (#positioned_children + 1)
            debug_print("DETAILED", "  Space evenly: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].x = positioned_children[i].x + (spacing * i)
            end
        end
        
        -- Apply start offset
        if start_x > 0 then
            debug_print("DETAILED", "  Applying start offset: %d", start_x)
            for _, child in ipairs(positioned_children) do
                child.x = child.x + start_x
            end
        end
    end
    
    -- Adjust for cross axis alignment
    for i, child in ipairs(positioned_children) do
        local extra_height = max_height - child.height
        
        if self.cross_axis_alignment == "center" then
            child.y = extra_height / 2
            debug_print("DETAILED", "  Child %d centered vertically: y=%d", i, child.y)
        elseif self.cross_axis_alignment == "end" then
            child.y = extra_height
            debug_print("DETAILED", "  Child %d aligned to end: y=%d", i, child.y)
        elseif self.cross_axis_alignment == "stretch" then
            if child.is_widget then
                -- Widget is already stretched, position at 0
                child.y = 0
            else
                -- For non-widgets, use start alignment
                child.y = 0
            end
            debug_print("DETAILED", "  Child %d stretched/start aligned: y=0", i)
        else
            debug_print("DETAILED", "  Child %d aligned to start: y=0", i)
        end
    end
    
    local layout_width = math.max(total_width, self.width)
    local layout_height = math.max(max_height, self.height)
    
    debug_print("INFO", "Row layout calculated: %s = %dx%d at position (%d,%d), positioned %d children", 
               self.id, layout_width, layout_height, self.x, self.y, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

return Row