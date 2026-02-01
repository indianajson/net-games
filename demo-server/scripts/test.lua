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
    column:setSize(240, 0)  -- Fixed height to ensure space
    column:setPosition(0, 0)  -- Move to visible position

    -- Set column properties
    column:setSpacing(5)
    column:setAlignment("start", "stretch")

    -- Create rows with proper layout
    local row1 = Widgets.Row.new("menu_item_1", player_id)
    row1:setSize(240, 17) 
    row1:setSpacing(10)
    row1:setAlignment("space_around", "center")
    
    -- Create sprites directly with custom layout dimensions
    -- create_sprite already adds them to the widget
    row1:create_sprite(
        "option_1",
        "/server/assets/demo/order_points.png",
        "/server/assets/demo/order_points.anim",
        "8POINT",
        78,  -- layout_width
        17    -- layout_height
    )
    
    row1:create_sprite(
        "option_2", 
        "/server/assets/demo/order_points.png",
        "/server/assets/demo/order_points.anim",
        "8POINT",
        78,
        17
    )
    
    local row2 = Widgets.Row.new("menu_item_2", player_id)
    row2:setSize(240, 17)
    row2:setSpacing(10)
    row2:setAlignment("space_around", "center")
    
    -- Create sprites for row2
    row2:create_sprite(
        "option_3",
        "/server/assets/demo/order_points.png",
        "/server/assets/demo/order_points.anim",
        "7POINT",
        78,
        17
    )
    
    row2:create_sprite(
        "option_4",
        "/server/assets/demo/order_points.png",
        "/server/assets/demo/order_points.anim",
        "6POINT",
        78,
        17
    )

    local row3 = Widgets.Row.new("menu_item_3", player_id)
    row3:setSize(240,17)
    row3:setSpacing(10)
    row3:setAlignment("space_around", "center")
    
    -- Create sprites for row3 with UNIQUE IDs
    row3:create_sprite(
        "option_5",
        "/server/assets/demo/order_points.png",
        "/server/assets/demo/order_points.anim",
        "5POINT",
        78,
        17
    )
    
    row3:create_sprite(
        "option_6",
        "/server/assets/demo/order_points.png",
        "/server/assets/demo/order_points.anim",
        "4POINT",
        78,
        17
    )
    
    row3:create_sprite(
        "option_7",  -- Changed from option_6 to option_7
        "/server/assets/demo/order_points.png",
        "/server/assets/demo/order_points.anim",
        "3POINT",
        78,
        17
    )
    
    -- Add rows to column
    column:addChild({widget = row1, id = row1.id})
    column:addChild({widget = row2, id = row2.id})
    column:addChild({widget = row3, id = row3.id})
    row1:updateLayout(true)
    row2:updateLayout(true)
    row3:updateLayout(true)
    -- Update layout
    column:updateLayout(true)
    
    -- Draw everything
    column:draw(true)

    -- Test animation (will fall back to direct positioning if AnimationEngine not available)
    -- row1:slide_widget(0, 100, 2, "ease_in", function()
    --     print("Slide animation complete!")
    -- end)
    
    local row1_x, row1_y = row1:getAbsolutePosition()
    local row2_x, row2_y = row2:getAbsolutePosition()
    local row3_x, row3_y = row3:getAbsolutePosition()

    print("ROW1 POS "..row1_x..","..row1_y)
    print("ROW2 POS "..row2_x..","..row2_y)
    print("ROW3 POS "..row3_x..","..row3_y)
    
    -- Print cache stats
    print("\n=== Cache Statistics ===")
    Widgets.printCacheStats()
    
    print("\n=== Widget example setup complete! ===")
    
    -- Store reference to widgets for later use
    local player_widgets = {
        column = column,
        rows = {row1, row2, row3}
    }

    row1:slide_widget(0,100,2,"ease_in", function() end)
    row2:shake_widget(10,100,15,function () end)
    row3:summon_widget(10, 10, 0, 10, 10, 2.0, 5, 10, .45, .10, "ease_in", function() end)
end)

    -- Example: Clean up when player leaves
Net:on("player_disconnect", function(event)    
            -- Remove cursor
            -- Widgets.removeCursor("menu_cursor", player_id)
            
            -- Clear widgets
            Widgets.clearPlayerWidgets(event.player_id)
            -- Widgets.clearPlayerCursors(event.player_id)
            
            -- Optional: Shutdown widget system if no players left
            -- Widgets.shutdown()
end)
