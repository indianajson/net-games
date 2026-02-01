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
    
    debug_print("DETAILED", "Row.setSpacing: %s = %g", self.id, self.spacing)
    
    return self
end

function Row:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "Row.calculateLayout: %s with %d children, available=%gx%g, position=(%g,%g)", 
               self.id, #self.children, available_width, available_height, self.x, self.y)
    
    local total_width = 0
    local max_height = 0
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
            
            -- Set widget size based on available height unless specified
            if child_widget.height <= 0 then
                child_widget:setSize(child_widget.width, available_height)
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
            debug_print("WARN", "  Child %d has no dimensions! Type: %s, ID: %s", 
                       i, child.type or "unknown", child.id or "unknown")
            -- Assign default dimensions to prevent layout errors
            child_width = 32
            child_height = 32
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
        
        total_width = total_width + child_width
        max_height = math.max(max_height, child_height)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_width = total_width + self.spacing
            debug_print("DETAILED", "  Added spacing: total_width now %g", total_width)
        end
    end
    
    debug_print("DETAILED", "  First pass total: total_width=%g, max_height=%g", total_width, max_height)
    
    -- Calculate distribution for main axis alignment
    local start_x, effective_spacing = utils.distribute_children_with_origin(
        #self.children, available_width, total_width, self.spacing, 
        self.main_axis_alignment, true)
    
    debug_print("DETAILED", "  Distribution: start_x=%g, spacing=%g", start_x, effective_spacing)
    
    -- Position children with proper origin offset handling
    local current_x = start_x
    
    for i, child_info in ipairs(child_sizes) do
        local child_width = child_info.width
        local child_height = child_info.height
        local child_ox = child_info.ox or 0
        local child_oy = child_info.oy or 0
        
        -- Calculate Y position based on cross axis alignment
        local y = 0
        if self.cross_axis_alignment == "center" then
            y = (max_height - child_height) / 2
        elseif self.cross_axis_alignment == "end" then
            y = max_height - child_height
        elseif self.cross_axis_alignment == "stretch" and child_info.widget then
            -- Only stretch widgets, not sprites
            child_info.widget:setSize(child_width, max_height)
            child_info.widget:updateLayout()
            child_width, child_height = child_info.widget:getCalculatedSize()
            debug_print("DETAILED", "    Stretched widget height to: %g", child_height)
        end
        
        -- Adjust Y position for origin offset
        -- We're positioning the TOP-LEFT corner, so subtract origin Y offset
        local top_left_y = y - child_oy
        
        -- Adjust X position for origin offset
        -- We're positioning the TOP-LEFT corner, so subtract origin X offset
        local top_left_x = current_x - child_ox
        
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
            positioned_child.is_sprite = true
        elseif child_info.widget then
            positioned_child.widget = child_info.widget
            positioned_child.is_widget = true
            positioned_child.widget_type = child_info.widget.widget_type or "Widget"
        end
        
        table.insert(positioned_children, positioned_child)
        
        debug_print("DETAILED", "  Child %d positioned: top-left=(%g,%g), size=%gx%g, origin=(%g,%g)", 
                   i, top_left_x, top_left_y, child_width, child_height, child_ox, child_oy)
        
        -- Move to next position
        current_x = current_x + child_width + effective_spacing
    end
    
    local layout_width = math.max(total_width, self.width)
    local layout_height = math.max(max_height, self.height)
    
    debug_print("INFO", "Row layout calculated: %s = %gx%g at position (%g,%g), positioned %d children", 
               self.id, layout_width, layout_height, self.x, self.y, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

return Row