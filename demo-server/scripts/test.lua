-- simple_widget_example.lua
local Widgets = require('scripts/net-games/widgets/widget')

-- Initialize
Widgets.init()
Widgets.Events.initialize()


Net:on("player_join", function(event)

local player_id = event.player_id

-- Create the widget structure
local column = Widgets.Column.new("main_menu", player_id)
    :setPosition(0, 0)
    :setSize(0, 160)
    :setSpacing(20)

local row1 = Widgets.Row.new("menu_item_1", player_id)
    :setSize(240, 30)
    :setAlignment("center", "center")

-- FIX 1: Add 'id' field to child table
row1:addChild({
    type = "sprite",
    id = "option_1",  -- REQUIRED: This was missing!
    sprite_id = "option_1",
    texture_path = "/server/assets/demo/order_points.png",
    anim_path = "/server/assets/demo/order_points.anim",
    anim_state = "8POINT"  -- Note: should be animation_state, not anim_state
})

local row2 = Widgets.Row.new("menu_item_2", player_id)
    :setSize(240, 30)
    :setPosition(0, 30)
    :setAlignment("center", "center")

row2:addChild({
    type = "sprite",
    id = "option_2",  -- REQUIRED: This was missing!
    sprite_id = "option_2",
    y = 30,
    texture_path = "/server/assets/demo/order_points.png",
    anim_path = "/server/assets/demo/order_points.anim",
    anim_state = "7POINT"  -- Note: should be animation_state, not anim_state
})

-- Enable detailed debugging
Widgets.enableDebug("VERBOSE")

-- Print debug info
row1:printDebugInfo()
column:printDebugInfo()

-- Check dimension cache
local w, h = Widgets.SpriteDimensionCache.get_dimensions(
    "/server/assets/demo/order_points.png",
    "/server/assets/demo/order_points.anim",
    "8POINT"
)
print("Sprite dimensions: " .. w .. "x" .. h)

-- FIX 2: Use colon notation to pass self correctly
row1:draw(true)  -- This calls row1.draw(row1, true)

-- Also need to add the row to the column for layout
column:addWidget(row1)
column:addWidget(row2)
--row1.Animations:fadeWidget(row1, 0, 2, {on_complete = function() end})

-- Update layout and draw the column
column:updateLayout()
column:draw(true)

-- Add some animation
-- Widgets.Animations.fadeWidget(column, 255, 1.0, "ease_in", {})
-- 
-- -- Make the first item pulse to indicate it's selectable
-- Widgets.Animations.pulseWidget(row1, 1.0, 1.1, 0.8, "elastic_out", true)
-- 
-- -- Register for selection
-- Widgets.Events.selection_manager:registerWidget(column)

print("Widget example setup complete!")

end)