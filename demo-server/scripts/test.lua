-- simple_widget_example.lua
local Widgets = require('scripts/net-games/widgets/widget')

-- Initialize
Widgets.init()
Widgets.Events.initialize()

Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Enable detailed debugging
    Widgets.Log.enable()
    Widgets.Log.set_level("INFO")
    
    print("=== Setting up widget system for player: " .. player_id .. " ===")
    
    -- Create the widget structure using the actual classes
    local column = Widgets.Column.new("main_menu", player_id)
    column:setSize(240, 0)
    column:setPosition(0, 0)  -- Give it a visible position

    -- Set column properties
    column:setSpacing(10)
    column:setAlignment("start", "center")

    -- Create rows
    local row1 = Widgets.Row.new("menu_item_1", player_id)
    row1:setSize(240, 34) 
    
    -- Set row properties
    row1:setSpacing(10)
    row1:setAlignment("space_evenly", "center")
    
    -- Add sprites to row1 with custom layout dimensions
    row1:addChild({
        type = "sprite",
        id = "option_1",
        sprite_id = "option_1",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "8POINT",
        layout_width = 156,
        layout_height = 34,
        scale = 2.0
    })
    
    local row2 = Widgets.Row.new("menu_item_2", player_id)
    row2:setSize(240, 34)
    
    -- Set row properties
    row2:setSpacing(10)
    row2:setAlignment("center", "center")
    
    -- Add sprites to row2 with custom layout dimensions
    row2:addChild({
        type = "sprite",
        id = "option_2",
        sprite_id = "option_2",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "7POINT",
        layout_width = 156,
        layout_height = 34,
        scale = 2.0
    })
    
    row2:addChild({
        type = "sprite",
        id = "option_3", 
        sprite_id = "option_3",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "6POINT",
        layout_width = 156,
        layout_height = 34,
        scale = 2.0
    })
    
    local row3 = Widgets.Row.new("menu_item_3", player_id)
    row3:setSize(240, 34)
    
    -- Set row properties
    row3:setSpacing(10)
    row3:setAlignment("center", "center")
    
    row3:addChild({
        type = "sprite",
        id = "option_4", 
        sprite_id = "option_4",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "5POINT",
        layout_width = 156,
        layout_height = 34,
        scale = 2.0
    })
    
    row3:addChild({
        type = "sprite",
        id = "option_5", 
        sprite_id = "option_5",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "4POINT",
        layout_width = 156,
        layout_height = 34,
        scale = 2.0
    })
    
    row3:addChild({
        type = "sprite",
        id = "option_6", 
        sprite_id = "option_6",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "3POINT",
        layout_width = 156,
        layout_height = 34,
        scale = 2.0
    })

    -- Add rows to column with proper id fields
    column:addChild({widget = row1, id = row1.id})
    column:addChild({widget = row2, id = row2.id})
    column:addChild({widget = row3, id = row3.id})
    
    -- Update layout
    column:updateLayout(true)
    
    -- Draw everything
    column:draw(true)
    
    -- Register widgets for selection management
    Widgets.Events.selection_manager:registerWidget(row1)
    Widgets.Events.selection_manager:registerWidget(row2)
    Widgets.Events.selection_manager:registerWidget(row3)
    
    -- Select the first widget
    Widgets.Events.selection_manager:selectWidget("menu_item_1", 1)
    
    -- Print debug info
    print("\n=== Final Widget Tree ===")
    Widgets.printWidgetTree(column)
    
    -- Print calculated sizes
    local col_width, col_height = column:getCalculatedSize()
    local row1_width, row1_height = row1:getCalculatedSize()
    local row2_width, row2_height = row2:getCalculatedSize()
    local row3_width, row3_height = row3:getCalculatedSize()

    print("\n=== Calculated Sizes ===")
    print("Column: " .. col_width .. "x" .. col_height .. " at (" .. column.x .. "," .. column.y .. ")")
    print("Row1: " .. row1_width .. "x" .. row1_height .. " at (" .. row1.x .. "," .. row1.y .. ")")
    print("Row2: " .. row2_width .. "x" .. row2_height .. " at (" .. row2.x .. "," .. row2.y .. ")")
    print("Row3: " .. row3_width .. "x" .. row3_height .. " at (" .. row3.x .. "," .. row3.y .. ")")
    
    -- Print cache stats
    print("\n=== Cache Statistics ===")
    Widgets.printCacheStats()
    
    print("\n=== Widget example setup complete! ===")
    
    -- Store reference to widgets for later use
    local player_widgets = {
        column = column,
        rows = {row1, row2, row3}
    }
    row1:slide_widget(100, 100, 2, "ease_in", nil)
    
    -- Example: Clean up when player leaves
    Net:on("player_disconnect", function(leave_event)
        if leave_event.player_id == player_id then
            print("Cleaning up widgets for player: " .. player_id)
            Widgets.clearPlayerWidgets(player_id)
        end
    end)
end)