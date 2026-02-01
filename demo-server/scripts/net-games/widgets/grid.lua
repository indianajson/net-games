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

return Grid