-- widgets/align.lua
-- Align widget that positions a child within a bounding box with precise alignment

local Widget = require('scripts/net-games/widgets/base-widget')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local Align = {}
setmetatable(Align, {__index = Widget})

function Align.new(id, player_id)
    local self = Widget.new(id, player_id, "Align")
    setmetatable(self, {__index = Align})
    
    -- Alignment settings
    self.alignment = {
        horizontal = "center",  -- "left", "center", "right", "stretch"
        vertical = "center"     -- "top", "center", "bottom", "stretch"
    }
    
    -- Offset settings (can be nil to not use)
    self.offset = {
        top = nil,      -- Positive values push down from top
        left = nil,     -- Positive values push right from left
        right = nil,    -- Positive values push left from right
        bottom = nil    -- Positive values push up from bottom
    }
    
    -- Bounding box (if nil, uses widget size or full screen)
    self.bounding_box = nil  -- {x, y, width, height} in screen space
    
    debug_print("INFO", "Align created: %s", self.id)
    
    return self
end

-- ===========================================================
-- ALIGNMENT SETUP METHODS
-- ===========================================================

-- Set horizontal alignment: "left", "center", "right", or "stretch"
function Align:setHorizontalAlignment(alignment)
    local valid_alignments = {"left", "center", "right", "stretch"}
    if not utils.table_contains(valid_alignments, alignment) then
        debug_print("ERROR", "Align.setHorizontalAlignment: Invalid alignment '%s' for %s", alignment, self.id)
        return self
    end
    
    self.alignment.horizontal = alignment
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Align.setHorizontalAlignment: %s = %s", self.id, alignment)
    return self
end

-- Set vertical alignment: "top", "center", "bottom", or "stretch"
function Align:setVerticalAlignment(alignment)
    local valid_alignments = {"top", "center", "bottom", "stretch"}
    if not utils.table_contains(valid_alignments, alignment) then
        debug_print("ERROR", "Align.setVerticalAlignment: Invalid alignment '%s' for %s", alignment, self.id)
        return self
    end
    
    self.alignment.vertical = alignment
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Align.setVerticalAlignment: %s = %s", self.id, alignment)
    return self
end

-- Set both alignments at once
function Align:setAlignment(horizontal, vertical)
    if horizontal then self:setHorizontalAlignment(horizontal) end
    if vertical then self:setVerticalAlignment(vertical) end
    return self
end

-- Set alignment using Flutter-style Alignment class values (-1 to 1 for both axes)
function Align:setFlutterAlignment(x, y)
    -- Convert Flutter alignment (-1 to 1) to our alignment strings
    local horizontal, vertical
    
    -- Horizontal: -1 = left, 0 = center, 1 = right
    if x <= -0.5 then
        horizontal = "left"
    elseif x >= 0.5 then
        horizontal = "right"
    else
        horizontal = "center"
    end
    
    -- Vertical: -1 = top, 0 = center, 1 = bottom
    if y <= -0.5 then
        vertical = "top"
    elseif y >= 0.5 then
        vertical = "bottom"
    else
        vertical = "center"
    end
    
    self:setAlignment(horizontal, vertical)
    
    debug_print("DETAILED", "Align.setFlutterAlignment: %s = (%g,%g) -> %s/%s", 
               self.id, x, y, horizontal, vertical)
    return self
end

-- Set offset from specific edges
function Align:setOffset(top, left, right, bottom)
    self.offset = {
        top = top,
        left = left,
        right = right,
        bottom = bottom
    }
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Align.setOffset: %s = top=%s, left=%s, right=%s, bottom=%s",
               self.id, tostring(top), tostring(left), tostring(right), tostring(bottom))
    return self
end

-- Set bounding box for alignment (in screen space coordinates)
function Align:setBoundingBox(x, y, width, height)
    self.bounding_box = {
        x = x or 0,
        y = y or 0,
        width = width or (self.width > 0 and self.width or utils.SCREEN_WIDTH),
        height = height or (self.height > 0 and self.height or utils.SCREEN_HEIGHT)
    }
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Align.setBoundingBox: %s = (%g,%g) %gx%g (screen space)",
               self.id, self.bounding_box.x, self.bounding_box.y, 
               self.bounding_box.width, self.bounding_box.height)
    return self
end

-- Set bounding box to fill the entire screen
function Align:setBoundingBoxToScreen()
    return self:setBoundingBox(0, 0, utils.SCREEN_WIDTH, utils.SCREEN_HEIGHT)
end

-- Set bounding box to fill the widget's current size
function Align:setBoundingBoxToWidget()
    local width, height = self:getCalculatedSize()
    return self:setBoundingBox(0, 0, width, height)
end

-- ===========================================================
-- LAYOUT CALCULATION
-- ===========================================================

function Align:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "Align.calculateLayout: %s with %d children, available=%gx%g", 
               self.id, #self.children, available_width, available_height)
    
    -- Determine bounding box dimensions
    local box_x, box_y, box_width, box_height
    
    if self.bounding_box then
        -- Use explicit bounding box (in WIDGET-RELATIVE coordinates)
        box_x = self.bounding_box.x
        box_y = self.bounding_box.y
        box_width = self.bounding_box.width
        box_height = self.bounding_box.height
        
        debug_print("VERBOSE", "  Using explicit bounding box: (%g,%g) %gx%g (widget-relative)",
                   box_x, box_y, box_width, box_height)
    else
        -- Use widget's available space (considering widget's own size)
        box_x = 0
        box_y = 0
        box_width = self.width > 0 and self.width or available_width
        box_height = self.height > 0 and self.height or available_height
        
        debug_print("VERBOSE", "  Using widget bounds: %gx%g (widget-relative)", 
                   box_width, box_height)
    end
    
    local positioned_children = {}
    local total_width = 0
    local total_height = 0
    
    -- Process each child
    for i, child in ipairs(self.children) do
        local child_width, child_height = 0, 0
        local child_ox, child_oy = 0, 0
        local child_id = nil
        local child_sprite_id = nil
        local child_widget = nil
        local is_stretch_horizontal = self.alignment.horizontal == "stretch"
        local is_stretch_vertical = self.alignment.vertical == "stretch"
        
        debug_print("VERBOSE", "  Processing child %d/%d", i, #self.children)
        
        if child.type == "sprite" then
            child_id = child.id
            child_sprite_id = child.sprite_id
            local sprite = self.sprite_objects[child_sprite_id]
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
                debug_print("VERBOSE", "    Sprite layout: %gx%g, origin offset: (%g,%g)",
                           child_width, child_height, child_ox, child_oy)
            else
                -- Sprite object not found
                child_width = child.layout_width or 32
                child_height = child.layout_height or 32
                debug_print("WARN", "    Sprite object not found, using layout: %gx%g",
                           child_width, child_height)
            end
        elseif child.widget then
            child_id = child.widget.id
            child_widget = child.widget
            debug_print("VERBOSE", "    Child is widget: %s", child_widget.id)
            
            -- Handle stretching if alignment is stretch
            if is_stretch_horizontal or is_stretch_vertical then
                local stretch_width = child_widget.width
                local stretch_height = child_widget.height
                
                if is_stretch_horizontal then
                    stretch_width = box_width
                    if self.offset.left then
                        stretch_width = stretch_width - (self.offset.left or 0)
                    end
                    if self.offset.right then
                        stretch_width = stretch_width - (self.offset.right or 0)
                    end
                end
                
                if is_stretch_vertical then
                    stretch_height = box_height
                    if self.offset.top then
                        stretch_height = stretch_height - (self.offset.top or 0)
                    end
                    if self.offset.bottom then
                        stretch_height = stretch_height - (self.offset.bottom or 0)
                    end
                end
                
                child_widget:setSize(stretch_width, stretch_height)
                debug_print("VERBOSE", "    Stretching widget to: %gx%g", stretch_width, stretch_height)
            end
            
            -- Update widget's layout to get calculated size
            child_widget:updateLayout()
            child_width, child_height = child_widget:getCalculatedSize()
            debug_print("VERBOSE", "    Widget dimensions: %gx%g", child_width, child_height)
        elseif child.width and child.height then
            child_id = child.id
            child_width = child.width
            child_height = child.height
            debug_print("VERBOSE", "    Explicit dimensions: %gx%g", child_width, child_height)
        else
            debug_print("WARN", "    Child has no dimensions, using default")
            child_width = 32
            child_height = 32
        end
        
        -- Calculate position within bounding box (widget-relative)
        local x, y = self:_calculateChildPosition(
            child_width, child_height, box_width, box_height,
            is_stretch_horizontal, is_stretch_vertical
        )
        
        debug_print("VERBOSE", "    Calculated base position: (%g,%g) in box %gx%g (widget-relative)",
                   x, y, box_width, box_height)
        
        -- Adjust for bounding box position (if not at 0,0)
        x = x + box_x
        y = y + box_y
        
        debug_print("VERBOSE", "    Adjusted for bounding box: (%g,%g) (widget-relative)", x, y)
        
        -- Adjust for sprite origin offset (convert to ORIGIN position from TOP-LEFT)
        -- For sprites: positioned_children stores TOP-LEFT, but sprites need ORIGIN position
        -- For widgets: positioned_children stores WIDGET-RELATIVE position
        local origin_x = x
        local origin_y = y
        
        if child_sprite_id then
            -- For sprites: convert top-left to origin position
            origin_x = x - child_ox
            origin_y = y - child_oy
        end
        
        debug_print("VERBOSE", "    Final position: (%g,%g) (widget-relative, %s)", 
                   origin_x, origin_y, child_sprite_id and "sprite origin" or "widget position")
        
        -- Update total dimensions (for widget's own size)
        total_width = math.max(total_width, child_width)
        total_height = math.max(total_height, child_height)
        
        -- Create positioned child object
        local positioned_child = {
            x = origin_x,  -- This is ORIGIN position for sprites, WIDGET-RELATIVE for widgets
            y = origin_y,
            width = child_width,
            height = child_height,
            ox = child_ox,
            oy = child_oy,
            visible = child.visible ~= false,
            id = child_id
        }
        
        -- Set type-specific properties
        if child_sprite_id then
            positioned_child.sprite_id = child_sprite_id
            positioned_child.is_sprite = true
            positioned_child.top_left_x = x  -- Store top-left for debugging
            positioned_child.top_left_y = y
        elseif child_widget then
            positioned_child.widget = child_widget
            positioned_child.is_widget = true
            positioned_child.widget_type = child_widget.widget_type or "Widget"
            positioned_child.origin_x = origin_x  -- Store widget-relative position
            positioned_child.origin_y = origin_y
        end
        
        table.insert(positioned_children, positioned_child)
        
        debug_print("INFO", "  Child %d positioned at: (%g,%g) size=%gx%g origin_offset=(%g,%g) type=%s",
                   i, origin_x, origin_y, child_width, child_height, child_ox, child_oy,
                   child_sprite_id and "sprite" or "widget")
    end
    
    -- The Align widget's size should be at least as big as its bounding box
    local layout_width = math.max(box_width, self.width > 0 and self.width or total_width)
    local layout_height = math.max(box_height, self.height > 0 and self.height or total_height)
    
    debug_print("INFO", "Align layout calculated: %s = %gx%g, positioned %d children",
               self.id, layout_width, layout_height, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

-- Internal method to calculate child position within bounding box (widget-relative coordinates)
function Align:_calculateChildPosition(child_width, child_height, box_width, box_height,
                                      is_stretch_horizontal, is_stretch_vertical)
    local x, y = 0, 0
    
    -- Calculate horizontal position
    if is_stretch_horizontal then
        -- Child is stretched to fill horizontal space (minus offsets)
        x = 0
        if self.offset.left then
            x = self.offset.left
            child_width = box_width - (self.offset.left or 0) - (self.offset.right or 0)
        end
    else
        -- Calculate based on horizontal alignment
        if self.alignment.horizontal == "left" then
            x = 0
            if self.offset.left then
                x = self.offset.left
            end
        elseif self.alignment.horizontal == "center" then
            x = (box_width - child_width) / 2
            -- For center alignment, left and right offsets adjust the center point
            if self.offset.left and self.offset.right then
                x = x + (self.offset.left - self.offset.right) / 2
            elseif self.offset.left then
                x = x + self.offset.left
            elseif self.offset.right then
                x = x - self.offset.right
            end
        elseif self.alignment.horizontal == "right" then
            x = box_width - child_width
            if self.offset.right then
                x = x - self.offset.right
            end
        end
    end
    
    -- Calculate vertical position
    if is_stretch_vertical then
        -- Child is stretched to fill vertical space (minus offsets)
        y = 0
        if self.offset.top then
            y = self.offset.top
            child_height = box_height - (self.offset.top or 0) - (self.offset.bottom or 0)
        end
    else
        -- Calculate based on vertical alignment
        if self.alignment.vertical == "top" then
            y = 0
            if self.offset.top then
                y = self.offset.top
            end
        elseif self.alignment.vertical == "center" then
            y = (box_height - child_height) / 2
            -- For center alignment, top and bottom offsets adjust the center point
            if self.offset.top and self.offset.bottom then
                y = y + (self.offset.top - self.offset.bottom) / 2
            elseif self.offset.top then
                y = y + self.offset.top
            elseif self.offset.bottom then
                y = y - self.offset.bottom
            end
        elseif self.alignment.vertical == "bottom" then
            y = box_height - child_height
            if self.offset.bottom then
                y = y - self.offset.bottom
            end
        end
    end
    
    return x, y
end

-- Override updateLayout to properly update sprite positions
function Align:updateLayout(force)
    debug_print("VERBOSE", "Align.updateLayout: %s dirty=%s, force=%s, needs_layout=%s", 
               self.id, tostring(self.state.dirty), tostring(force), tostring(self.state.needs_layout))
    
    if self.state.dirty or force or self.state.needs_layout then
        -- Skip if widget is being animated
        if self._layout_animation_active and not force then
            debug_print("DETAILED", "  Skipping layout update due to active animation")
            return false
        end
        
        -- Calculate available space
        local available_width = self.width > 0 and self.width or utils.SCREEN_WIDTH
        local available_height = self.height > 0 and self.height or utils.SCREEN_HEIGHT
        
        debug_print("DETAILED", "  Available space: %gx%g (screen space)", available_width, available_height)
        
        local layout_width, layout_height, positioned_children = 
            self:calculateLayout(available_width, available_height)
        
        -- Update calculated size
        self._calculated_size = {
            width = layout_width,
            height = layout_height
        }
        
        debug_print("DETAILED", "  Calculated layout: %gx%g, children positioned: %d",
                   layout_width, layout_height, #positioned_children)
        
        -- Position children (sprites and widgets)
        for i, child in ipairs(positioned_children) do
            -- Calculate widget-relative position (relative to this widget's top-left in screen space)
            local child_widget_x = child.x + self.padding.left + self.margin.left
            local child_widget_y = child.y + self.padding.top + self.margin.top
            
            debug_print("DETAILED", "  Child %d: type=%s, widget-relative=(%g,%g), parent_abs=(%g,%g)",
                       i, child.sprite_id and "sprite" or "widget", 
                       child_widget_x, child_widget_y, self.x, self.y)
            
            if child.sprite_id then
                -- Update sprite position (using widget-relative coordinates in screen space)
                local sprite = self.sprite_objects[child.sprite_id]
                if sprite then
                    -- Check if sprite is being animated by widget
                    if not sprite:is_widget_animated() then
                        -- IMPORTANT: positioned_children stores ORIGIN position for sprites
                        -- We need to convert widget-relative to absolute screen position
                        local screen_x = self.x + child_widget_x
                        local screen_y = self.y + child_widget_y
                        
                        -- Set sprite's origin position in screen space
                        sprite:set_position(screen_x, screen_y)
                        
                        debug_print("DETAILED", "    Sprite %s: widget-rel=(%g,%g), screen-abs=(%g,%g), origin_offset=(%g,%g)", 
                                   child.sprite_id, child_widget_x, child_widget_y,
                                   screen_x, screen_y, child.ox or 0, child.oy or 0)
                    else
                        debug_print("DETAILED", "    Sprite %s is being animated, skipping layout position", 
                                   child.sprite_id)
                    end
                    
                    if child.visible ~= nil then
                        sprite:set_visible(self.state.visible and child.visible)
                    else
                        sprite:set_visible(self.state.visible)
                    end
                else
                    debug_print("WARN", "    Sprite not found: %s", child.sprite_id)
                end
            elseif child.widget then
                -- Update child widget position (relative to this widget's screen position)
                debug_print("DETAILED", "    Updating child widget: %s, parent_abs=(%g,%g), child_rel=(%g,%g), child_abs=(%g,%g)", 
                           child.widget.id, self.x, self.y, child_widget_x, child_widget_y, 
                           self.x + child_widget_x, self.y + child_widget_y)
                
                -- Check if child widget is being animated
                if not child.widget._layout_animation_active then
                    -- Set child widget position relative to parent widget's position (screen space)
                    -- Note: child_widget_x/y are already widget-relative, add parent position
                    child.widget:setPosition(self.x + child_widget_x, self.y + child_widget_y)
                    
                    -- Update the child widget's layout
                    child.widget:updateLayout(force)
                else
                    debug_print("DETAILED", "    Child widget %s is being animated, skipping layout position", 
                               child.widget.id)
                end
            end
        end
        
        -- Update child widgets that might not have been in positioned_children
        local widget_count = 0
        for _, widget in pairs(self._child_widgets) do
            widget_count = widget_count + 1
            if not widget._layout_animation_active then
                widget:updateLayout(force)
            else
                debug_print("DETAILED", "  Child widget %s is being animated, skipping layout update", widget.id)
            end
        end
        
        if widget_count > 0 then
            debug_print("DETAILED", "  Updated %d child widgets", widget_count)
        end
        
        -- Apply screen constraints after layout calculation
        if self._constrain_to_screen then
            self:applyScreenConstraints()
        end
        
        self.state.dirty = false
        self.state.needs_layout = false
        debug_print("INFO", "Align layout updated: %s at position (%g,%g) screen space", self.id, self.x, self.y)
        return true
    else
        debug_print("VERBOSE", "  Align not dirty, skipping update")
        return false
    end
end

-- ===========================================================
-- CONVENIENCE METHODS
-- ===========================================================

-- Quick alignment presets
function Align:alignTopLeft(offset_x, offset_y)
    return self:setAlignment("left", "top")
           :setOffset(offset_y, offset_x, nil, nil)
end

function Align:alignTopCenter(offset_x, offset_y)
    return self:setAlignment("center", "top")
           :setOffset(offset_y, nil, nil, nil)
end

function Align:alignTopRight(offset_x, offset_y)
    return self:setAlignment("right", "top")
           :setOffset(offset_y, nil, offset_x, nil)
end

function Align:alignCenterLeft(offset_x, offset_y)
    return self:setAlignment("left", "center")
           :setOffset(nil, offset_x, nil, nil)
end

function Align:alignCenter(offset_x, offset_y)
    return self:setAlignment("center", "center")
end

function Align:alignCenterRight(offset_x, offset_y)
    return self:setAlignment("right", "center")
           :setOffset(nil, nil, offset_x, nil)
end

function Align:alignBottomLeft(offset_x, offset_y)
    return self:setAlignment("left", "bottom")
           :setOffset(nil, offset_x, nil, offset_y)
end

function Align:alignBottomCenter(offset_x, offset_y)
    return self:setAlignment("center", "bottom")
           :setOffset(nil, nil, nil, offset_y)
end

function Align:alignBottomRight(offset_x, offset_y)
    return self:setAlignment("right", "bottom")
           :setOffset(nil, nil, offset_x, offset_y)
end

-- Fill the bounding box (stretch in both directions)
function Align:alignFill(top_margin, left_margin, right_margin, bottom_margin)
    return self:setAlignment("stretch", "stretch")
           :setOffset(top_margin, left_margin, right_margin, bottom_margin)
end

-- ===========================================================
-- QUERY METHODS
-- ===========================================================

-- Get the current alignment
function Align:getAlignment()
    return self.alignment.horizontal, self.alignment.vertical
end

-- Get the current offsets
function Align:getOffsets()
    return self.offset.top, self.offset.left, self.offset.right, self.offset.bottom
end

-- Get the current bounding box
function Align:getBoundingBox()
    if self.bounding_box then
        return self.bounding_box.x, self.bounding_box.y, 
               self.bounding_box.width, self.bounding_box.height
    else
        local width, height = self:getCalculatedSize()
        return 0, 0, width, height
    end
end

-- Check if child would fit in current bounding box
function Align:wouldChildFit(child_width, child_height)
    local box_x, box_y, box_width, box_height = self:getBoundingBox()
    
    if self.alignment.horizontal == "stretch" then
        child_width = box_width
        if self.offset.left then child_width = child_width - (self.offset.left or 0) end
        if self.offset.right then child_width = child_width - (self.offset.right or 0) end
    end
    
    if self.alignment.vertical == "stretch" then
        child_height = box_height
        if self.offset.top then child_height = child_height - (self.offset.top or 0) end
        if self.offset.bottom then child_height = child_height - (self.offset.bottom or 0) end
    end
    
    return child_width <= box_width and child_height <= box_height
end

-- ===========================================================
-- DEBUG AND UTILITY METHODS
-- ===========================================================

function Align:printDebugInfo(level)
    level = level or 0
    local indent = string.rep("  ", level)
    
    Widget.printDebugInfo(self, level)
    
    print(indent .. "Align Widget Details:")
    print(indent .. "  Alignment: " .. self.alignment.horizontal .. "/" .. self.alignment.vertical)
    print(indent .. "  Offsets: top=" .. tostring(self.offset.top) .. 
          ", left=" .. tostring(self.offset.left) .. 
          ", right=" .. tostring(self.offset.right) .. 
          ", bottom=" .. tostring(self.offset.bottom))
    
    if self.bounding_box then
        print(indent .. "  Bounding Box: (" .. string.format("%g", self.bounding_box.x) .. 
              "," .. string.format("%g", self.bounding_box.y) .. ") " .. 
              string.format("%g", self.bounding_box.width) .. "x" .. 
              string.format("%g", self.bounding_box.height) .. " (widget-relative)")
    else
        local width, height = self:getCalculatedSize()
        print(indent .. "  Bounding Box: (0,0) " .. 
              string.format("%g", width) .. "x" .. string.format("%g", height) .. " (implicit)")
    end
    
    -- Show child alignment positions
    if #self.children > 0 then
        print(indent .. "  Child Alignment Positions:")
        local _, _, positioned_children = self:calculateLayout(
            self.width > 0 and self.width or utils.SCREEN_WIDTH,
            self.height > 0 and self.height or utils.SCREEN_HEIGHT
        )
        
        for i, child in ipairs(positioned_children) do
            local child_type = child.sprite_id and "sprite" or "widget"
            local child_id = child.sprite_id or (child.widget and child.widget.id) or child.id
            print(indent .. "    Child " .. i .. " (" .. child_type .. " " .. child_id .. "):")
            print(indent .. "      Widget-Relative: (" .. string.format("%g", child.x) .. 
                  "," .. string.format("%g", child.y) .. ")")
            print(indent .. "      Size: " .. string.format("%g", child.width) .. 
                  "x" .. string.format("%g", child.height))
            if child.sprite_id then
                print(indent .. "      Origin Offset: (" .. string.format("%g", child.ox) .. 
                      "," .. string.format("%g", child.oy) .. ")")
                print(indent .. "      Top-Left (widget-relative): (" .. 
                      string.format("%g", child.top_left_x or 0) .. "," .. 
                      string.format("%g", child.top_left_y or 0) .. ")")
            end
        end
    end
end

-- Get visual bounding box (for debugging/drawing)
function Align:getVisualBoundingBox()
    local x, y = self:getAbsolutePosition()
    local width, height = self:getCalculatedSize()
    
    if self.bounding_box then
        -- Adjust for bounding box within widget
        x = x + self.bounding_box.x
        y = y + self.bounding_box.y
        width = self.bounding_box.width
        height = self.bounding_box.height
    end
    
    return x, y, width, height
end

-- Check if a point is within the alignment bounding box
function Align:isPointInBoundingBox(point_x, point_y)
    local box_x, box_y, box_width, box_height = self:getVisualBoundingBox()
    local widget_x, widget_y = self:getAbsolutePosition()
    
    -- Convert point to widget-relative coordinates
    local rel_x = point_x - widget_x
    local rel_y = point_y - widget_y
    
    return rel_x >= box_x and rel_x <= box_x + box_width and
           rel_y >= box_y and rel_y <= box_y + box_height
end

-- Helper to directly position a sprite with alignment (useful for debugging)
function Align:positionSpriteDirectly(sprite_id)
    local sprite = self.sprite_objects[sprite_id]
    if not sprite then
        debug_print("ERROR", "Align.positionSpriteDirectly: Sprite %s not found in %s", sprite_id, self.id)
        return false
    end
    
    -- Get sprite dimensions
    local child_width, child_height = sprite:get_layout_dimensions()
    local child_ox, child_oy = sprite:get_origin_offset()
    
    -- Get bounding box
    local box_x, box_y, box_width, box_height = self:getBoundingBox()
    
    -- Calculate position
    local x, y = self:_calculateChildPosition(
        child_width, child_height, box_width, box_height,
        self.alignment.horizontal == "stretch",
        self.alignment.vertical == "stretch"
    )
    
    -- Adjust for bounding box position
    x = x + box_x
    y = y + box_y
    
    -- Adjust for sprite origin
    local screen_x = self.x + x - child_ox
    local screen_y = self.y + y - child_oy
    
    -- Set sprite position directly
    sprite:set_position(screen_x, screen_y)
    
    debug_print("INFO", "Align.positionSpriteDirectly: %s positioned at screen(%g,%g)", 
               sprite_id, screen_x, screen_y)
    return true
end

return Align
