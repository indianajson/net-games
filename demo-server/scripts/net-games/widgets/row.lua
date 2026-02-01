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

-- Reorder sprites by their Z value (lower Z = drawn first)
function Row:reorder_sprites_by_z_order()
    debug_print("INFO", "Row.reorder_sprites_by_z_order: Reordering sprites by Z order in %s", self.id)
    
    return self:sort_children(function(a, b)
        local a_z = 0
        local b_z = 0
        
        if a.type == "sprite" and a.sprite_id then
            local sprite = self.sprite_objects[a.sprite_id]
            if sprite then 
                a_z = sprite.properties.z or 0 
                debug_print("DETAILED", "  Sprite %s Z = %d", a.sprite_id, a_z)
            end
        end
        
        if b.type == "sprite" and b.sprite_id then
            local sprite = self.sprite_objects[b.sprite_id]
            if sprite then 
                b_z = sprite.properties.z or 0 
                debug_print("DETAILED", "  Sprite %s Z = %d", b.sprite_id, b_z)
            end
        end
        
        return a_z < b_z  -- Lower Z values come first (drawn earlier)
    end)
end

-- Reverse the order of all children
function Row:reverse_sprites()
    local reversed = {}
    for i = #self.children, 1, -1 do
        table.insert(reversed, self.sprite_objects[i])
    end
    self.children = reversed
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Row.reverse_sprites: Reversed %d children in %s", #self.children, self.id)
    return self
end

-- Get all sprites in their current layout order
function Row:get_sprites_in_order()
    local sprites = {}
    for i, child in ipairs(self.children) do
        if child.type == "sprite" and child.sprite_id then
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                table.insert(sprites, {
                    sprite = sprite,
                    index = i,
                    id = child.sprite_id,
                    child_data = child
                })
            end
        end
    end
    return sprites
end

-- Get sprite at specific position in row
function Row:get_sprite_at_index(index)
    if index < 1 or index > #self.children then
        debug_print("ERROR", "Row.get_sprite_at_index: Index %d out of bounds (1-%d) in %s", 
                   index, #self.children, self.id)
        return nil
    end
    
    local child = self.children[index]
    if child and child.type == "sprite" and child.sprite_id then
        return self.sprite_objects[child.sprite_id]
    end
    
    debug_print("WARN", "Row.get_sprite_at_index: Child at index %d is not a sprite in %s", 
               index, self.id)
    return nil
end

-- Move sprite to a specific position in the row
function Row:move_sprite_to_position(sprite_id, new_position)
    if new_position < 1 or new_position > #self.children then
        debug_print("ERROR", "Row.move_sprite_to_position: Invalid position %d for sprite %s in %s", 
                   new_position, sprite_id, self.id)
        return false
    end
    
    -- Find current position
    local current_index = nil
    for i, child in ipairs(self.children) do
        if child.sprite_id == sprite_id then
            current_index = i
            break
        end
    end
    
    if not current_index then
        debug_print("ERROR", "Row.move_sprite_to_position: Sprite %s not found in %s", 
                   sprite_id, self.id)
        return false
    end
    
    if current_index == new_position then
        debug_print("DETAILED", "Row.move_sprite_to_position: Sprite %s already at position %d in %s", 
                   sprite_id, new_position, self.id)
        return true
    end
    
    -- Remove from current position
    local sprite_data = table.remove(self.children, current_index)
    
    -- Adjust target index if we removed before it
    if current_index < new_position then
        new_position = new_position - 1
    end
    
    -- Insert at new position
    table.insert(self.children, new_position, sprite_data)
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Row.move_sprite_to_position: Moved sprite %s from %d to %d in %s", 
               sprite_id, current_index, new_position, self.id)
    return true
end

-- Swap positions of two sprites in the row
function Row:swap_sprite_positions(sprite1_id, sprite2_id)
    local index1, index2 = nil, nil
    local sprite1_data, sprite2_data = nil, nil
    
    -- Find both sprites
    for i, child in ipairs(self.children) do
        if child.sprite_id == sprite1_id then
            index1 = i
            sprite1_data = child
        elseif child.sprite_id == sprite2_id then
            index2 = i
            sprite2_data = child
        end
    end
    
    if not index1 then
        debug_print("ERROR", "Row.swap_sprite_positions: Sprite %s not found in %s", 
                   sprite1_id, self.id)
        return false
    end
    
    if not index2 then
        debug_print("ERROR", "Row.swap_sprite_positions: Sprite %s not found in %s", 
                   sprite2_id, self.id)
        return false
    end
    
    -- Swap positions
    self.children[index1] = sprite2_data
    self.children[index2] = sprite1_data
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Row.swap_sprite_positions: Swapped %s (pos %d) with %s (pos %d) in %s", 
               sprite1_id, index1, sprite2_id, index2, self.id)
    return true
end


function Row:swap_and_animate_sprites_in_layout(sprite1_id, sprite2_id, duration, easing, on_complete)
    if not sprite1_id or not sprite2_id or sprite1_id == sprite2_id then
        debug_print("ERROR", "Row.swap_and_animate_sprites_in_layout: Invalid sprite IDs in %s", self.id)
        if on_complete then on_complete({success = false, reason = "invalid_ids"}, false) end
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Row.swap_and_animate_sprites_in_layout: Swapping %s and %s in %s", 
               sprite1_id, sprite2_id, self.id)
    
    -- Get current indices
    local index1 = self:get_sprite_position(sprite1_id)
    local index2 = self:get_sprite_position(sprite2_id)
    
    if not index1 or not index2 then
        debug_print("ERROR", "  One or both sprites not found in layout")
        if on_complete then on_complete({success = false, reason = "not_found"}, false) end
        return nil
    end
    
    debug_print("DETAILED", "  Current positions: %s at %d, %s at %d", 
               sprite1_id, index1, sprite2_id, index2)
    
    -- Get sprite objects
    local sprite1 = self.sprite_objects[sprite1_id]
    local sprite2 = self.sprite_objects[sprite2_id]
    
    if not sprite1 or not sprite2 then
        debug_print("ERROR", "  Sprite objects not found")
        if on_complete then on_complete({success = false, reason = "no_objects"}, false) end
        return nil
    end
    
    -- Store current positions BEFORE swapping in layout
    local original_pos1 = {x = sprite1.properties.x, y = sprite1.properties.y}
    local original_pos2 = {x = sprite2.properties.x, y = sprite2.properties.y}
    
    -- Swap positions in children array
    local success = self:swap_sprite_positions(sprite1_id, sprite2_id)
    if not success then
        if on_complete then on_complete({success = false, reason = "swap_failed"}, false) end
        return nil
    end
    
    -- Update layout to calculate new positions
    self:updateLayout(true)
    
    -- Get new positions from sprite properties (after layout update)
    local new_pos1 = {x = sprite1.properties.x, y = sprite1.properties.y}
    local new_pos2 = {x = sprite2.properties.x, y = sprite2.properties.y}
    
    debug_print("DETAILED", "  Original positions: %s=(%g,%g), %s=(%g,%g)", 
               sprite1_id, original_pos1.x, original_pos1.y, 
               sprite2_id, original_pos2.x, original_pos2.y)
    debug_print("DETAILED", "  New positions: %s=(%g,%g), %s=(%g,%g)", 
               sprite1_id, new_pos1.x, new_pos1.y, 
               sprite2_id, new_pos2.x, new_pos2.y)
    
    -- Temporarily set sprites back to original positions so we can animate
    sprite1:set_position(original_pos1.x, original_pos1.y)
    sprite2:set_position(original_pos2.x, original_pos2.y)
    
    -- Mark sprites as widget-animated to prevent layout from overriding
    sprite1:set_widget_animated(true, {type = "layout_swap"})
    sprite2:set_widget_animated(true, {type = "layout_swap"})
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine then
        debug_print("WARN", "  AnimationEngine not available, setting directly")
        
        -- Set to new positions
        sprite1:set_position(new_pos1.x, new_pos1.y)
        sprite2:set_position(new_pos2.x, new_pos2.y)
        
        -- Unmark sprites
        sprite1:set_widget_animated(false)
        sprite2:set_widget_animated(false)
        
        if on_complete then
            on_complete({
                sprite1 = sprite1_id, 
                sprite2 = sprite2_id, 
                success = true,
                new_index1 = index2,
                new_index2 = index1
            }, false)
        end
        return nil
    end
    
    local animations_completed = 0
    local total_animations = 2
    
    local function check_completion()
        animations_completed = animations_completed + 1
        if animations_completed >= total_animations then
            -- Unmark sprites
            sprite1:set_widget_animated(false)
            sprite2:set_widget_animated(false)
            
            -- Final layout update
            self:updateLayout(true)
            
            if on_complete then
                on_complete({
                    sprite1 = sprite1_id, 
                    sprite2 = sprite2_id, 
                    success = true,
                    new_index1 = index2,
                    new_index2 = index1
                }, false)
            end
            
            debug_print("INFO", "Row.swap_and_animate_sprites_in_layout: Layout swap completed")
        end
    end
    
    -- Animate sprite1 to new position
    local anim_id1 = sprite1:slide_sprite(new_pos1.x, new_pos1.y, duration, easing, function()
        check_completion()
    end)
    
    -- Animate sprite2 to new position
    local anim_id2 = sprite2:slide_sprite(new_pos2.x, new_pos2.y, duration, easing, function()
        check_completion()
    end)
    
    -- Track both animations
    if anim_id1 then
        self.active_animations[anim_id1] = true
    end
    if anim_id2 then
        self.active_animations[anim_id2] = true
    end
    
    return {anim1 = anim_id1, anim2 = anim_id2}
end

-- Swap sprites at specific indices and animate
function Row:swap_and_animate_sprites_at_indices(index1, index2, duration, easing, on_complete)
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Row.swap_and_animate_sprites_at_indices: Swapping indices %d and %d in %s", 
               index1, index2, self.id)
    
    -- Get sprites at these indices
    local sprite1 = self:get_sprite_at_index(index1)
    local sprite2 = self:get_sprite_at_index(index2)
    
    if not sprite1 or not sprite2 then
        debug_print("ERROR", "  One or both sprites not found at indices")
        if on_complete then on_complete({success = false, reason = "not_found"}, false) end
        return nil
    end
    
    local sprite1_id, sprite2_id
    
    -- Find sprite IDs
    for id, sprite in pairs(self.sprite_objects) do
        if sprite == sprite1 then sprite1_id = id end
        if sprite == sprite2 then sprite2_id = id end
    end
    
    if not sprite1_id or not sprite2_id then
        debug_print("ERROR", "  Could not find sprite IDs")
        if on_complete then on_complete({success = false, reason = "no_ids"}, false) end
        return nil
    end
    
    return self:swap_and_animate_sprites_in_layout(sprite1_id, sprite2_id, duration, easing, on_complete)
end

-- Animate sprites swapping with arc/circular motion
function Row:swap_with_arc_animation(sprite1_id, sprite2_id, duration, easing, arc_height, on_complete)
    duration = duration or 0.4
    easing = easing or "ease_in_out"
    arc_height = arc_height or 20
    
    debug_print("INFO", "Row.swap_with_arc_animation: Swapping %s and %s with arc in %s", 
               sprite1_id, sprite2_id, self.id)
    
    -- Get sprite objects
    local sprite1 = self.sprite_objects[sprite1_id]
    local sprite2 = self.sprite_objects[sprite2_id]
    
    if not sprite1 or not sprite2 then
        debug_print("ERROR", "  One or both sprites not found")
        if on_complete then on_complete({success = false, reason = "not_found"}, false) end
        return nil
    end
    
    -- Store current positions
    local pos1 = {x = sprite1.properties.x, y = sprite1.properties.y}
    local pos2 = {x = sprite2.properties.x, y = sprite2.properties.y}
    
    -- Calculate midpoint for arc control point
    local mid_x = (pos1.x + pos2.x) / 2
    local mid_y = (pos1.y + pos2.y) / 2
    
    -- Swap in layout first
    local layout_success = self:swap_sprite_positions(sprite1_id, sprite2_id)
    if not layout_success then
        if on_complete then on_complete({success = false, reason = "layout_swap_failed"}, false) end
        return nil
    end
    
    -- Update layout to get new positions
    self:updateLayout(true)
    
    -- Get new positions
    local new_pos1 = {x = sprite1.properties.x, y = sprite1.properties.y}
    local new_pos2 = {x = sprite2.properties.x, y = sprite2.properties.y}
    
    -- Temporarily set back to original positions
    sprite1:set_position(pos1.x, pos1.y)
    sprite2:set_position(pos2.x, pos2.y)
    
    -- Mark as widget-animated
    sprite1:set_widget_animated(true, {type = "arc_swap"})
    sprite2:set_widget_animated(true, {type = "arc_swap"})
    
    -- Try to load animation modules
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    
    if not AnimationEngine or not AnimationSequences then
        debug_print("WARN", "  Animation modules not available, using direct swap")
        return self:swap_and_animate_sprites_in_layout(sprite1_id, sprite2_id, duration, easing, on_complete)
    end
    
    -- Use summon animation for arc movement
    local anim1 = AnimationSequences.summon(sprite1, 
        pos1.x, pos1.y, 1.0,
        new_pos1.x, new_pos1.y, 1.0,
        {
            duration = duration,
            arc_height = arc_height,
            peak_scale_mul = 1.1,
            wobble_deg = 0,
            easing = easing,
            on_complete = nil
        }
    )
    
    local anim2 = AnimationSequences.summon(sprite2, 
        pos2.x, pos2.y, 1.0,
        new_pos2.x, new_pos2.y, 1.0,
        {
            duration = duration,
            arc_height = arc_height,
            peak_scale_mul = 1.1,
            wobble_deg = 0,
            easing = easing,
            on_complete = function()
                -- Unmark sprites
                sprite1:set_widget_animated(false)
                sprite2:set_widget_animated(false)
                
                -- Final layout update
                self:updateLayout(true)
                
                if on_complete then
                    on_complete({
                        sprite1 = sprite1_id, 
                        sprite2 = sprite2_id, 
                        success = true,
                        arc_animation = true
                    }, false)
                end
            end
        }
    )
    
    -- Track animations
    if anim1 then self.active_animations[anim1] = true end
    if anim2 then self.active_animations[anim2] = true end
    
    return {anim1 = anim1, anim2 = anim2}
end

-- Bring sprite to front (rightmost position)
function Row:bring_sprite_to_front(sprite_id)
    return self:move_sprite_to_position(sprite_id, #self.children)
end

-- Send sprite to back (leftmost position)
function Row:send_sprite_to_back(sprite_id)
    return self:move_sprite_to_position(sprite_id, 1)
end

-- Sort sprites by a custom comparison function
function Row:sort_sprites(compare_func)
    -- Filter only sprite children
    local sprite_children = {}
    local other_children = {}
    
    for _, child in ipairs(self.children) do
        if child.type == "sprite" and child.sprite_id then
            table.insert(sprite_children, child)
        else
            table.insert(other_children, child)
        end
    end
    
    -- Sort sprite children using the provided comparison function
    table.sort(sprite_children, function(a, b)
        local sprite_a = self.sprite_objects[a.sprite_id]
        local sprite_b = self.sprite_objects[b.sprite_id]
        return compare_func(sprite_a, sprite_b, a, b)
    end)
    
    -- Rebuild children array (sprite children first, then others)
    local new_children = {}
    for _, child in ipairs(sprite_children) do
        table.insert(new_children, child)
    end
    for _, child in ipairs(other_children) do
        table.insert(new_children, child)
    end
    
    self.children = new_children
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Row.sort_sprites: Sorted %d sprites in %s", #sprite_children, self.id)
    return true
end

-- Animate sprites to their new positions after reordering
function Row:animate_reorder(duration, easing, on_complete)
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Row.animate_reorder: Animating sprites to new positions in %s", self.id)
    
    -- Store current positions of all sprites
    local original_positions = {}
    for _, child in ipairs(self.children) do
        if child.type == "sprite" and child.sprite_id then
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                original_positions[child.sprite_id] = {
                    x = sprite.properties.x,
                    y = sprite.properties.y
                }
            end
        end
    end
    
    -- Update layout to calculate new positions
    self:updateLayout(true)
    
    -- Animate each sprite from old to new position
    local animations_completed = 0
    local total_sprites = 0
    
    for _, child in ipairs(self.children) do
        if child.type == "sprite" and child.sprite_id then
            local sprite = self.sprite_objects[child.sprite_id]
            local old_pos = original_positions[child.sprite_id]
            
            if sprite and old_pos then
                total_sprites = total_sprites + 1
                
                -- Only animate if position changed
                if sprite.properties.x ~= old_pos.x or sprite.properties.y ~= old_pos.y then
                    sprite:slide_sprite(
                        sprite.properties.x,
                        sprite.properties.y,
                        duration,
                        easing,
                        function()
                            animations_completed = animations_completed + 1
                            if animations_completed >= total_sprites and on_complete then
                                on_complete()
                            end
                        end
                    )
                else
                    animations_completed = animations_completed + 1
                end
            end
        end
    end
    
    -- If no animations needed, call on_complete immediately
    if animations_completed >= total_sprites and on_complete then
        on_complete()
    end
    
    return self
end

-- Find sprite by its display position in the row (useful for click/touch)
function Row:find_sprite_at_position(x, y, tolerance)
    tolerance = tolerance or 5
    
    if self.state.needs_layout then
        self:updateLayout()
    end
    
    -- Calculate layout to get positioned children
    local _, _, positioned_children = self:calculateLayout(
        self.width > 0 and self.width or utils.SCREEN_WIDTH,
        self.height > 0 and self.height or utils.SCREEN_HEIGHT
    )
    
    for _, positioned_child in ipairs(positioned_children) do
        if positioned_child.sprite_id then
            -- Check if point is within sprite bounds (considering tolerance)
            if x >= positioned_child.x - tolerance and 
               x <= positioned_child.x + positioned_child.width + tolerance and
               y >= positioned_child.y - tolerance and 
               y <= positioned_child.y + positioned_child.height + tolerance then
                return self.sprite_objects[positioned_child.sprite_id]
            end
        end
    end
    
    return nil
end

-- Shuffle sprites randomly
function Row:shuffle_sprites()
    debug_print("INFO", "Row.shuffle_sprites: Shuffling sprites in %s", self.id)
    
    -- Fisher-Yates shuffle algorithm
    for i = #self.children, 2, -1 do
        local j = math.random(i)
        self.children[i], self.children[j] = self.children[j], self.children[i]
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    return self
end

-- Get position (index) of a sprite in the row
function Row:get_sprite_position(sprite_id)
    for i, child in ipairs(self.children) do
        if child.sprite_id == sprite_id then
            return i
        end
    end
    return nil
end

-- Rotate sprites (move first to last)
function Row:rotate_sprites_forward()
    if #self.children < 2 then return self end
    
    local first = table.remove(self.children, 1)
    table.insert(self.children, first)
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Row.rotate_sprites_forward: Rotated sprites forward in %s", self.id)
    return self
end

-- Rotate sprites (move last to first)
function Row:rotate_sprites_backward()
    if #self.children < 2 then return self end
    
    local last = table.remove(self.children)
    table.insert(self.children, 1, last)
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Row.rotate_sprites_backward: Rotated sprites backward in %s", self.id)
    return self
end

return Row