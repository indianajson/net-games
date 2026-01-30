-- widgets/widget-builder.lua
-- Builder functions for creating common widget configurations

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')
local Row = require('scripts/net-games/widgets/row')
local Column = require('scripts/net-games/widgets/column')
local Grid = require('scripts/net-games/widgets/grid')

local WidgetBuilder = {}

function WidgetBuilder.createMenu(id, player_id, options)
    debug_print("INFO", "WidgetBuilder.createMenu: %s with %d options", id, #options)
    
    local menu = Column.new(id, player_id)
        :setSpacing(10)
        :setAlignment("start", "center")
    
    for i, option in ipairs(options) do
        debug_print("DETAILED", "  Adding menu option %d: %s", i, option.id or i)
        
        menu:addChild({
            type = "sprite",
            sprite_id = utils.generate_unique_id(id .. "_option"),
            texture_path = option.texture_path,
            anim_path = option.anim_path,
            anim_state = option.anim_state or "normal",
            layout_width = option.width,  -- Support custom width
            layout_height = option.height, -- Support custom height
            id = option.id or ("option_" .. i)
        })
    end
    
    return menu
end

function WidgetBuilder.createInventoryGrid(id, player_id, columns, cell_size)
    debug_print("INFO", "WidgetBuilder.createInventoryGrid: %s, columns=%d, cell_size=%d", 
               id, columns, cell_size)
    
    local grid = Grid.new(id, player_id)
        :setColumns(columns)
        :setSpacing(5, 5)
        :setCellSize(cell_size, cell_size)
    
    return grid
end

function WidgetBuilder.createHUD(id, player_id, elements)
    debug_print("INFO", "WidgetBuilder.createHUD: %s with %d elements", id, #elements)
    
    local hud = Row.new(id, player_id)
        :setSpacing(20)
        :setAlignment("space_between", "center")
    
    for i, element in ipairs(elements) do
        debug_print("DETAILED", "  Adding HUD element %d: %s", i, element.id)
        
        hud:addChild({
            type = "sprite",
            sprite_id = utils.generate_unique_id(id .. "_" .. element.id),
            texture_path = element.texture_path,
            anim_path = element.anim_path,
            anim_state = element.anim_state,
            layout_width = element.width,  -- Support custom width
            layout_height = element.height, -- Support custom height
            id = element.id
        })
    end
    
    return hud
end

return WidgetBuilder