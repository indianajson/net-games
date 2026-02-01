-- widgets/widget-grid.lua
-- Grid widget for arranging items in rows and columns

local Widget = require('scripts/net-games/widgets/base-widget')
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local Grid = {}
setmetatable(Grid, {__index = Widget})

function Grid.new(id, player_id)
    local self = Widget.new(id, player_id, "Grid")
    setmetatable(self, {__index = Grid})
    
    self.columns = 3
    self.horizontal_spacing = 0
    self.vertical_spacing = 0
    self.cell_width = 0  -- 0 means auto-size
    self.cell_height = 0 -- 0 means auto-size
    self.items = {}
    self.selected_index = 0
    self.on_selection_changed = nil
    
    debug_print("INFO", "Grid created: %s", self.id)
    
    return self
end

function Grid:setColumns(columns)
    self.columns = math.max(1, columns or 3)
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Grid.setColumns: %s = %d", self.id, self.columns)
    
    return self
end

function Grid:setSpacing(horizontal, vertical)
    self.horizontal_spacing = horizontal or self.horizontal_spacing
    self.vertical_spacing = vertical or self.vertical_spacing
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Grid.setSpacing: %s = h=%g, v=%g", 
               self.id, self.horizontal_spacing, self.vertical_spacing)
    
    return self
end

function Grid:setCellSize(width, height)
    self.cell_width = width or 0
    self.cell_height = height or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Grid.setCellSize: %s = %gx%g", 
               self.id, self.cell_width, self.cell_height)
    
    return self
end

function Grid:addItem(item_id, texture_path, anim_path, anim_state, data, layout_width, layout_height)
    debug_print("INFO", "Grid.addItem: %s adding item %s", self.id, item_id)
    
    local item = {
        id = item_id,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state or "",
        data = data or {},
        sprite_id = utils.generate_unique_id(self.id .. "_item"),
        layout_width = layout_width,
        layout_height = layout_height
    }
    
    table.insert(self.items, item)
    
    -- Add as child sprite with optional layout dimensions
    self:addChild({
        type = "sprite",
        sprite_id = item.sprite_id,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state,
        layout_width = layout_width,
        layout_height = layout_height,
        id = item_id
    })
    
    debug_print("DETAILED", "  Item sprite_id: %s, layout: %gx%g", 
               item.sprite_id, layout_width or 0, layout_height or 0)
    debug_print("DETAILED", "  Total items: %d", #self.items)
    
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Grid:removeItem(item_id)
    debug_print("INFO", "Grid.removeItem: %s removing item %s", self.id, item_id)
    
    for i, item in ipairs(self.items) do
        if item.id == item_id then
            -- Remove sprite
            self:removeChild(item.sprite_id)
            
            -- Remove from items
            table.remove(self.items, i)
            
            -- Update selection if needed
            if self.selected_index >= i then
                self.selected_index = math.max(0, self.selected_index - 1)
            end
            
            debug_print("DETAILED", "  Item removed, selected_index now %d", self.selected_index)
            
            self.state.dirty = true
            self.state.needs_layout = true
            return true
        end
    end
    
    debug_print("WARN", "  Item not found: %s", item_id)
    return false
end

function Grid:clearItems()
    debug_print("INFO", "Grid.clearItems: %s clearing %d items", self.id, #self.items)
    
    for _, item in ipairs(self.items) do
        self:removeChild(item.sprite_id)
    end
    self.items = {}
    self.selected_index = 0
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Grid:setSelectedIndex(index, emit_event)
    local new_index = math.max(0, math.min(index, #self.items))
    
    debug_print("INFO", "Grid.setSelectedIndex: %s from %d to %d (total items: %d)",
               self.id, self.selected_index, new_index, #self.items)
    
    if new_index ~= self.selected_index then
        self.selected_index = new_index
        
        if emit_event ~= false and self.on_selection_changed then
            local selected_item = new_index > 0 and self.items[new_index] or nil
            debug_print("DETAILED", "  Calling on_selection_changed callback")
            self.on_selection_changed(new_index, selected_item)
        end
        
        self.state.dirty = true
    else
        debug_print("VERBOSE", "  Selection unchanged")
    end
    return self
end

function Grid:calculateLayout(available_width, available_height)
    if #self.items == 0 then
        debug_print("WARN", "Grid.calculateLayout: %s has no items", self.id)
        return 0, 0, {}
    end
    
    debug_print("DETAILED", "Grid.calculateLayout: %s with %d items, %d columns", 
               self.id, #self.items, self.columns)
    
    -- Calculate cell dimensions
    local cell_width = self.cell_width
    local cell_height = self.cell_height
    
    debug_print("DETAILED", "  Initial cell size: %gx%g", cell_width, cell_height)
    
    if cell_width == 0 or cell_height == 0 then
        -- Auto-size: find largest item using sprite object dimensions
        local max_item_width, max_item_height = 0, 0
        
        for i, item in ipairs(self.items) do
            local item_width, item_height
            local sprite = self.sprite_objects[item.sprite_id]
            
            if sprite then
                -- Use layout dimensions if specified
                if item.layout_width and item.layout_height then
                    item_width = item.layout_width
                    item_height = item.layout_height
                else
                    item_width, item_height = sprite:get_layout_dimensions()
                end
            else
                -- Fallback to item's layout dimensions or default
                item_width = item.layout_width or 32
                item_height = item.layout_height or 32
                debug_print("WARN", "  Sprite not found for item %d, using default dimensions", i)
            end
            
            debug_print("DETAILED", "  Item %d (%s) dimensions: %gx%g", 
                       i, item.id, item_width, item_height)
            
            max_item_width = math.max(max_item_width, item_width)
            max_item_height = math.max(max_item_height, item_height)
        end
        
        cell_width = cell_width == 0 and max_item_width or cell_width
        cell_height = cell_height == 0 and max_item_height or cell_height
        
        debug_print("DETAILED", "  Auto-sized cell: %gx%g", cell_width, cell_height)
    end
    
    -- Calculate grid dimensions
    local rows = math.ceil(#self.items / self.columns)
    local grid_width = (cell_width * self.columns) + (self.horizontal_spacing * (self.columns - 1))
    local grid_height = (cell_height * rows) + (self.vertical_spacing * (rows - 1))
    
    debug_print("DETAILED", "  Grid dimensions: %gx%g (rows=%d)", grid_width, grid_height, rows)
    
    -- Position items with origin offset handling
    local positioned_children = {}
    
    for i, item in ipairs(self.items) do
        local row = math.floor((i - 1) / self.columns)
        local col = (i - 1) % self.columns
        
        -- Calculate cell top-left position
        local cell_x = col * (cell_width + self.horizontal_spacing)
        local cell_y = row * (cell_height + self.vertical_spacing)
        
        debug_print("DETAILED", "  Item %d: row=%d, col=%d, cell position=(%g,%g)", 
                   i, row, col, cell_x, cell_y)
        
        -- Get item dimensions and origin offset from sprite object
        local sprite_width, sprite_height, ox, oy
        local sprite = self.sprite_objects[item.sprite_id]
        
        if sprite then
            if item.layout_width and item.layout_height then
                -- Use custom layout dimensions
                sprite_width = item.layout_width
                sprite_height = item.layout_height
            else
                -- Use layout dimensions
                sprite_width, sprite_height = sprite:get_layout_dimensions()
            end
            -- Get origin offset
            ox, oy = sprite:get_origin_offset()
        else
            -- Fallback to item's layout dimensions or default
            sprite_width = item.layout_width or 32
            sprite_height = item.layout_height or 32
            ox, oy = 0, 0
        end
        
        -- Calculate position to center the ORIGIN point in the cell
        -- First, calculate where we want the origin point to be (center of cell)
        local target_origin_x = cell_x + (cell_width / 2)
        local target_origin_y = cell_y + (cell_height / 2)
        
        -- Then calculate the top-left position needed to place the origin there
        local top_left_x = target_origin_x - ox
        local top_left_y = target_origin_y - oy
        
        debug_print("DETAILED", "    Sprite: %gx%g, origin=(%g,%g)", 
                   sprite_width, sprite_height, ox, oy)
        debug_print("DETAILED", "    Target origin at cell center: (%g,%g)", 
                   target_origin_x, target_origin_y)
        debug_print("DETAILED", "    Top-left position: (%g,%g)", top_left_x, top_left_y)
        
        table.insert(positioned_children, {
            sprite_id = item.sprite_id,
            x = top_left_x,
            y = top_left_y,
            ox = ox,
            oy = oy,
            visible = true
        })
    end
    
    debug_print("INFO", "Grid layout calculated: %s = %gx%g, positioned %d items", 
               self.id, grid_width, grid_height, #positioned_children)
    
    return grid_width, grid_height, positioned_children
end

-- ===========================================================
-- SPRITE REORDERING AND UTILITY METHODS FOR GRID
-- ===========================================================

-- Get sprite at specific index in grid
function Grid:get_sprite_at_index(index)
    if index < 1 or index > #self.items then
        debug_print("ERROR", "Grid.get_sprite_at_index: Index %d out of bounds (1-%d) in %s", 
                   index, #self.items, self.id)
        return nil
    end
    
    local item = self.items[index]
    if item and item.sprite_id then
        return self.sprite_objects[item.sprite_id]
    end
    
    debug_print("WARN", "Grid.get_sprite_at_index: Item at index %d has no sprite in %s", 
               index, self.id)
    return nil
end

-- Get position (index) of a sprite in the grid
function Grid:get_sprite_position(sprite_id)
    for i, item in ipairs(self.items) do
        if item.sprite_id == sprite_id then
            return i
        end
    end
    return nil
end

-- Get item at specific grid coordinates (row, col)
function Grid:get_item_at_grid_position(row, col)
    local index = (row - 1) * self.columns + col
    if index < 1 or index > #self.items then
        debug_print("ERROR", "Grid.get_item_at_grid_position: Position (%d,%d) out of bounds in %s", 
                   row, col, self.id)
        return nil
    end
    return self.items[index]
end

-- Get grid coordinates for a specific index
function Grid:get_grid_coordinates(index)
    if index < 1 or index > #self.items then
        debug_print("ERROR", "Grid.get_grid_coordinates: Index %d out of bounds in %s", 
                   index, self.id)
        return nil, nil
    end
    
    local row = math.floor((index - 1) / self.columns) + 1
    local col = ((index - 1) % self.columns) + 1
    return row, col
end

-- Move sprite to a specific position in the grid
function Grid:move_sprite_to_position(sprite_id, new_position)
    if new_position < 1 or new_position > #self.items then
        debug_print("ERROR", "Grid.move_sprite_to_position: Invalid position %d for sprite %s in %s", 
                   new_position, sprite_id, self.id)
        return false
    end
    
    -- Find current position
    local current_index = nil
    for i, item in ipairs(self.items) do
        if item.sprite_id == sprite_id then
            current_index = i
            break
        end
    end
    
    if not current_index then
        debug_print("ERROR", "Grid.move_sprite_to_position: Sprite %s not found in %s", 
                   sprite_id, self.id)
        return false
    end
    
    if current_index == new_position then
        debug_print("DETAILED", "Grid.move_sprite_to_position: Sprite %s already at position %d in %s", 
                   sprite_id, new_position, self.id)
        return true
    end
    
    -- Remove from current position
    local item_data = table.remove(self.items, current_index)
    local child_data = table.remove(self.children, current_index)
    
    -- Adjust target index if we removed before it
    if current_index < new_position then
        new_position = new_position - 1
    end
    
    -- Insert at new position
    table.insert(self.items, new_position, item_data)
    table.insert(self.children, new_position, child_data)
    
    -- Update selection if needed
    if self.selected_index == current_index then
        self.selected_index = new_position
    elseif self.selected_index > current_index and self.selected_index <= new_position then
        self.selected_index = self.selected_index - 1
    elseif self.selected_index < current_index and self.selected_index >= new_position then
        self.selected_index = self.selected_index + 1
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Grid.move_sprite_to_position: Moved sprite %s from %d to %d in %s", 
               sprite_id, current_index, new_position, self.id)
    return true
end

-- Swap positions of two sprites in the grid
function Grid:swap_sprite_positions(sprite1_id, sprite2_id)
    local index1, index2 = nil, nil
    local item1_data, item2_data = nil, nil
    local child1_data, child2_data = nil, nil
    
    -- Find both sprites
    for i, item in ipairs(self.items) do
        if item.sprite_id == sprite1_id then
            index1 = i
            item1_data = item
            child1_data = self.children[i]
        elseif item.sprite_id == sprite2_id then
            index2 = i
            item2_data = item
            child2_data = self.children[i]
        end
    end
    
    if not index1 then
        debug_print("ERROR", "Grid.swap_sprite_positions: Sprite %s not found in %s", 
                   sprite1_id, self.id)
        return false
    end
    
    if not index2 then
        debug_print("ERROR", "Grid.swap_sprite_positions: Sprite %s not found in %s", 
                   sprite2_id, self.id)
        return false
    end
    
    -- Swap positions
    self.items[index1] = item2_data
    self.items[index2] = item1_data
    self.children[index1] = child2_data
    self.children[index2] = child1_data
    
    -- Update selection if needed
    if self.selected_index == index1 then
        self.selected_index = index2
    elseif self.selected_index == index2 then
        self.selected_index = index1
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Grid.swap_sprite_positions: Swapped %s (pos %d) with %s (pos %d) in %s", 
               sprite1_id, index1, sprite2_id, index2, self.id)
    return true
end

-- Swap two items at specific grid coordinates
function Grid:swap_items_at_grid_positions(row1, col1, row2, col2)
    local index1 = (row1 - 1) * self.columns + col1
    local index2 = (row2 - 1) * self.columns + col2
    
    if index1 < 1 or index1 > #self.items or index2 < 1 or index2 > #self.items then
        debug_print("ERROR", "Grid.swap_items_at_grid_positions: Invalid grid positions in %s", self.id)
        return false
    end
    
    local item1 = self.items[index1]
    local item2 = self.items[index2]
    
    if not item1 or not item2 then
        debug_print("ERROR", "Grid.swap_items_at_grid_positions: Items not found at specified positions in %s", self.id)
        return false
    end
    
    return self:swap_sprite_positions(item1.sprite_id, item2.sprite_id)
end

-- Swap two sprites in the layout AND animate their positions
function Grid:swap_and_animate_sprites_in_layout(sprite1_id, sprite2_id, duration, easing, on_complete)
    if not sprite1_id or not sprite2_id or sprite1_id == sprite2_id then
        debug_print("ERROR", "Grid.swap_and_animate_sprites_in_layout: Invalid sprite IDs in %s", self.id)
        if on_complete then on_complete({success = false, reason = "invalid_ids"}, false) end
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Grid.swap_and_animate_sprites_in_layout: Swapping %s and %s in %s", 
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
    
    -- Swap positions in items and children arrays
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
            
            debug_print("INFO", "Grid.swap_and_animate_sprites_in_layout: Layout swap completed")
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
function Grid:swap_and_animate_sprites_at_indices(index1, index2, duration, easing, on_complete)
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Grid.swap_and_animate_sprites_at_indices: Swapping indices %d and %d in %s", 
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
function Grid:swap_with_arc_animation(sprite1_id, sprite2_id, duration, easing, arc_height, on_complete)
    duration = duration or 0.4
    easing = easing or "ease_in_out"
    arc_height = arc_height or 20
    
    debug_print("INFO", "Grid.swap_with_arc_animation: Swapping %s and %s with arc in %s", 
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
                    arc_animation = true
                }, false)
            end
        end
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
            on_complete = function()
                check_completion()
            end
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
                check_completion()
            end
        }
    )
    
    -- Track animations
    if anim1 then self.active_animations[anim1] = true end
    if anim2 then self.active_animations[anim2] = true end
    
    return {anim1 = anim1, anim2 = anim2}
end

-- Shuffle items randomly
function Grid:shuffle_items()
    debug_print("INFO", "Grid.shuffle_items: Shuffling items in %s", self.id)
    
    -- Fisher-Yates shuffle algorithm
    for i = #self.items, 2, -1 do
        local j = math.random(i)
        self.items[i], self.items[j] = self.items[j], self.items[i]
        self.children[i], self.children[j] = self.children[j], self.children[i]
    end
    
    -- Update selection if needed
    if self.selected_index > 0 then
        -- Find the selected item in new position
        for i, item in ipairs(self.items) do
            if item.id == self.items[self.selected_index].id then
                self.selected_index = i
                break
            end
        end
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "  Selected index after shuffle: %d", self.selected_index)
    return self
end

-- Sort items by a custom comparison function
function Grid:sort_items(compare_func)
    debug_print("INFO", "Grid.sort_items: Sorting items in %s", self.id)
    
    -- Sort items array
    table.sort(self.items, function(a, b)
        return compare_func(a, b)
    end)
    
    -- Rebuild children array to match sorted items
    local new_children = {}
    for _, item in ipairs(self.items) do
        -- Find the corresponding child
        for _, child in ipairs(self.children) do
            if child.sprite_id == item.sprite_id then
                table.insert(new_children, child)
                break
            end
        end
    end
    
    self.children = new_children
    
    -- Update selection if needed
    if self.selected_index > 0 then
        -- Find the selected item in new position
        for i, item in ipairs(self.items) do
            if item.id == self.items[self.selected_index].id then
                self.selected_index = i
                break
            end
        end
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "  Sorted %d items, selected index: %d", #self.items, self.selected_index)
    return self
end

-- Animate items to their new positions after reordering
function Grid:animate_reorder(duration, easing, on_complete)
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Grid.animate_reorder: Animating items to new positions in %s", self.id)
    
    -- Store current positions of all sprites
    local original_positions = {}
    for _, item in ipairs(self.items) do
        local sprite = self.sprite_objects[item.sprite_id]
        if sprite then
            original_positions[item.sprite_id] = {
                x = sprite.properties.x,
                y = sprite.properties.y
            }
        end
    end
    
    -- Update layout to calculate new positions
    self:updateLayout(true)
    
    -- Animate each sprite from old to new position
    local animations_completed = 0
    local total_sprites = 0
    
    for _, item in ipairs(self.items) do
        local sprite = self.sprite_objects[item.sprite_id]
        local old_pos = original_positions[item.sprite_id]
        
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
    
    -- If no animations needed, call on_complete immediately
    if animations_completed >= total_sprites and on_complete then
        on_complete()
    end
    
    return self
end

-- Find sprite by its display position in the grid (useful for click/touch)
function Grid:find_sprite_at_position(x, y, tolerance)
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
               x <= positioned_child.x + (self.cell_width or positioned_child.width) + tolerance and
               y >= positioned_child.y - tolerance and 
               y <= positioned_child.y + (self.cell_height or positioned_child.height) + tolerance then
                return self.sprite_objects[positioned_child.sprite_id]
            end
        end
    end
    
    return nil
end

-- Get all sprites in their current layout order
function Grid:get_sprites_in_order()
    local sprites = {}
    for i, item in ipairs(self.items) do
        local sprite = self.sprite_objects[item.sprite_id]
        if sprite then
            local row = math.floor((i - 1) / self.columns) + 1
            local col = ((i - 1) % self.columns) + 1
            
            table.insert(sprites, {
                sprite = sprite,
                index = i,
                row = row,
                col = col,
                id = item.sprite_id,
                item_data = item
            })
        end
    end
    return sprites
end

return Grid
