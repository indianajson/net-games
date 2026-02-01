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
    
    debug_print("DETAILED", "Column.setSpacing: %s = %g", self.id, self.spacing)
    
    return self
end

function Column:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "Column.calculateLayout: %s with %d children, available=%gx%g", 
               self.id, #self.children, available_width, available_height)
    
    local total_height = 0
    local max_width = 0
    local positioned_children = {}
    local child_sizes = {}
    
    debug_print("VERBOSE", "  Main axis alignment: %s", self.main_axis_alignment)
    debug_print("VERBOSE", "  Cross axis alignment: %s", self.cross_axis_alignment)
    debug_print("VERBOSE", "  Spacing: %g", self.spacing)
    
    -- First pass: collect child dimensions and origin offsets
    for i, child in ipairs(self.children) do
        local child_width, child_height = 0, 0
        local child_ox, child_oy = 0, 0
        local child_id = nil
        local child_sprite_id = nil
        local child_widget = nil
        
        if child.type == "sprite" then
            child_id = child.id
            child_sprite_id = child.sprite_id
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                -- Use layout dimensions if specified
                if child.layout_width and child.layout_height then
                    child_width = child.layout_width
                    child_height = child.layout_height
                else
                    child_width, child_height = sprite:get_layout_dimensions()
                end
                -- Get origin offset for this sprite
                child_ox, child_oy = sprite:get_origin_offset()
                debug_print("DETAILED", "  Child %d sprite origin offset: (%g,%g)", 
                           i, child_ox, child_oy)
            else
                -- Sprite object not found, use layout dimensions if available
                child_width = child.layout_width or 32
                child_height = child.layout_height or 32
                debug_print("WARN", "  Child %d sprite object not found, using layout: %gx%g", 
                           i, child_width, child_height)
            end
        elseif child.widget then
            child_id = child.widget.id
            child_widget = child.widget
            debug_print("DETAILED", "  Child %d is a widget: %s", i, child_widget.id)
            
            -- Set widget size to fill available width unless specified otherwise
            if child_widget.width <= 0 then
                child_widget:setSize(available_width, child_widget.height)
            end
            
            -- Update the widget's layout first so it knows its own size
            child_widget:updateLayout()
            
            -- Get the widget's calculated size
            child_width, child_height = child_widget:getCalculatedSize()
            debug_print("DETAILED", "  Child %d widget dimensions: %gx%g", i, child_width, child_height)
        elseif child.width and child.height then
            child_id = child.id
            child_width = child.width
            child_height = child.height
            debug_print("DETAILED", "  Child %d explicit dimensions: %gx%g", i, child_width, child_height)
        else
            debug_print("WARN", "  Child %d has no dimensions!", i)
            child_width = 32
            child_height = 32
        end
        
        -- Adjust for cross axis alignment
        if self.cross_axis_alignment == "stretch" and child_widget then
            -- Only stretch widgets, not sprites
            child_widget:setSize(available_width, child_height)
            child_widget:updateLayout()
            child_width, child_height = child_widget:getCalculatedSize()
            debug_print("DETAILED", "    Stretched widget width to: %g", child_width)
        end
        
        -- Store child size information
        table.insert(child_sizes, {
            width = child_width,
            height = child_height,
            ox = child_ox,
            oy = child_oy,
            index = i,
            sprite_id = child_sprite_id,
            widget = child_widget,
            id = child_id,
            visible = child.visible ~= false
        })
        
        total_height = total_height + child_height
        max_width = math.max(max_width, child_width)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_height = total_height + self.spacing
            debug_print("DETAILED", "  Added spacing: total_height now %g", total_height)
        end
    end
    
    debug_print("DETAILED", "  First pass total: max_width=%g, total_height=%g", max_width, total_height)
    
    -- Calculate distribution for main axis alignment
    local start_y, effective_spacing = utils.distribute_children_with_origin(
        #self.children, available_height, total_height, self.spacing, 
        self.main_axis_alignment, false)
    
    debug_print("DETAILED", "  Distribution: start_y=%g, spacing=%g", start_y, effective_spacing)
    
    -- Position children with proper origin offset handling
    local current_y = start_y
    
    for i, child_info in ipairs(child_sizes) do
        local child_width = child_info.width
        local child_height = child_info.height
        local child_ox = child_info.ox or 0
        local child_oy = child_info.oy or 0
        
        -- Calculate X position based on cross axis alignment
        local x = 0
        if self.cross_axis_alignment == "center" then
            x = (max_width - child_width) / 2
        elseif self.cross_axis_alignment == "end" then
            x = max_width - child_width
        elseif self.cross_axis_alignment == "stretch" and child_info.widget then
            -- Widget is already stretched, position at 0
            x = 0
        end
        
        -- Adjust X position for origin offset
        -- We're positioning the TOP-LEFT corner, so subtract origin X offset
        local top_left_x = x - child_ox
        
        -- Adjust Y position for origin offset
        -- We're positioning the TOP-LEFT corner, so subtract origin Y offset
        local top_left_y = current_y - child_oy
        
        -- Create positioned child object
        local positioned_child = {
            x = top_left_x,
            y = top_left_y,
            width = child_width,
            height = child_height,
            ox = child_ox,
            oy = child_oy,
            visible = child_info.visible,
            id = child_info.id
        }
        
        -- Set type-specific properties
        if child_info.sprite_id then
            positioned_child.sprite_id = child_info.sprite_id
        elseif child_info.widget then
            positioned_child.widget = child_info.widget
            positioned_child.is_widget = true
            positioned_child.widget_type = child_info.widget.widget_type or "Widget"
        end
        
        table.insert(positioned_children, positioned_child)
        
        debug_print("DETAILED", "  Child %d positioned: top-left=(%g,%g), size=%gx%g, origin=(%g,%g)", 
                   i, top_left_x, top_left_y, child_width, child_height, child_ox, child_oy)
        
        -- Move to next position
        current_y = current_y + child_height + effective_spacing
    end
    
    local layout_width = math.max(max_width, self.width)
    local layout_height = math.max(total_height, self.height)
    
    debug_print("INFO", "Column layout calculated: %s = %gx%g, positioned %d children", 
               self.id, layout_width, layout_height, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

return Column