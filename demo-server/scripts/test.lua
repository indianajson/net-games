-- simple_widget_example.lua
local Widgets = require('scripts/net-games/widgets/widget')

-- Initialize
Widgets.init()
Widgets.Events.initialize()

Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Enable detailed debugging
    Widgets.enableDebug("VERBOSE")
    
    print("=== Setting up widget system for player: " .. player_id .. " ===")
    
    -- Create the widget structure
    local column = Widgets.Column.new("main_menu", player_id)
        :setPosition(0, 0)  -- Set a clear position for debugging
        :setSize(240, 160)

    local row1 = Widgets.Row.new("menu_item_1", player_id)
        :setSize(240, 34)  -- Explicit size for row
        :setSpacing(10)
        :setAlignment("space_evenly", "center")
    
    -- Add sprites to row1 with custom layout dimensions
    row1:addChild({
        type = "sprite",
        id = "option_1",
        sprite_id = "option_1",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "8POINT",
        layout_width = 78,  -- Custom width for layout (pre-scaling)
        layout_height = 16, -- Custom height for layout (pre-scaling)
        scale = 2.0  -- Visual scale (will be applied on top of layout dimensions)
    })
    
    local row2 = Widgets.Row.new("menu_item_2", player_id)
        :setSize(240, 34)
        :setSpacing(10)
        :setAlignment("center", "center")
    
    -- Add sprites to row2 with custom layout dimensions
    row2:addChild({
        type = "sprite",
        id = "option_2",
        sprite_id = "option_2",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "7POINT",
        layout_width = 78,  -- Custom width
        layout_height = 16, -- Custom height
        scale = 2.0
    })
    
    row2:addChild({
        type = "sprite",
        id = "option_3", 
        sprite_id = "option_3",
        texture_path = "/server/assets/demo/order_points.png",
        anim_path = "/server/assets/demo/order_points.anim",
        anim_state = "6POINT",
        layout_width = 78,  -- Custom width
        layout_height = 16, -- Custom height
        scale = 2.0
    })
    
    -- Add rows to column
    column:addWidget(row1)
    column:addWidget(row2)
    row1:updateLayout()
    row2:updateLayout()
    
    -- Print initial debug info
    print("=== Initial State ===")
    column:printDebugInfo()
    
    -- Update layout and draw everything
    print("\n=== Updating Layout ===")
    column:updateLayout(true)  -- Force layout update
    
    print("\n=== Drawing ===")
    column:draw(true)  -- Force draw
    
    -- Print final state
    print("\n=== Final State ===")
    column:printDebugInfo()
    
    -- Check sprite positions
    print("\n=== Sprite Positions ===")
    for sprite_id, sprite in pairs(row1.sprite_objects) do
        local props = sprite:get_properties()
        print("Row1 Sprite " .. sprite_id .. " position: (" .. props.x .. "," .. props.y .. ")")
    end
    
    for sprite_id, sprite in pairs(row2.sprite_objects) do
        local props = sprite:get_properties()
        print("Row2 Sprite " .. sprite_id .. " position: (" .. props.x .. "," .. props.y .. ")")
    end
    
    -- Print calculated sizes
    local col_width, col_height = column:getCalculatedSize()
    local row1_width, row1_height = row1:getCalculatedSize()
    local row2_width, row2_height = row2:getCalculatedSize()
    
    print("\n=== Calculated Sizes ===")
    print("Column: " .. col_width .. "x" .. col_height)
    print("Row1: " .. row1_width .. "x" .. row1_height)
    print("Row2: " .. row2_width .. "x" .. row2_height)
    
    -- Print cache stats
    print("\n=== Cache Statistics ===")
    Widgets.printCacheStats()
    
    print("\n=== Widget example setup complete! ===")
    
    -- Test updating layout dimensions after creation
    print("\n=== Testing dynamic layout dimension update ===")
    Widgets.set_sprite_layout_dimensions(row1, "option_1", 64, 64)
    column:updateLayout(true)
    column:draw(true)
    
    -- Add some visual effects
    Widgets.Animations.pulseWidget(row1, 1.0, 1.2, 1.0, "ease_in_out", true)
end)