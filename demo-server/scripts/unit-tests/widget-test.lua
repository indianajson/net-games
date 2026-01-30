-- widget-tests.lua
-- Comprehensive widget system testing with consistent asset paths

-- Import the widget and widget-logging modules separately
local widget = require('scripts/net-games/widgets/widget')
local widget_logging = require('scripts/net-games/widgets/widget-logging')
local WidgetTests = {}

-- Purpose: Shorthand for async
local function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end

-- Purpose: Shorthand for await
local function await(v) 
    return Async.await(v) 
end

-- Path constants for consistent usage
local TEXTURE_PATH = "assets/net-games/text_cursor.png"
local ANIM_PATH = "assets/net-games/text_cursor.anim"

-- ===========================================================
-- TEST SETUP FUNCTIONS
-- ===========================================================

-- Async test setup function
WidgetTests.setup_test_async = function()
    return async(function()
        print("=== Widget System Test ===")
        
        -- Initialize logging system (async)
        print("1. Initializing logging system...")
        widget_logging.init_logging()
        await(Async.sleep(0.1)) -- Allow time for initialization
        
        -- Configure logging
        widget_logging.LOGGING.set_severity("INFO")
        widget_logging.LOGGING.enable_file_logging()
        
        -- Create a test player
        local test_player_id = "player_test_1"
        print("2. Setting up test player: " .. test_player_id)
        
        return test_player_id
    end)
end

-- ===========================================================
-- BASIC WIDGET TESTS
-- ===========================================================

-- Async function to test basic widget creation
WidgetTests.test_basic_widget_async =  function(player_id)
    return async(function()
        print("\n3. Testing basic widget creation...")
        
        -- Create a basic widget
        local widget_obj = widget.Widget.new("test_widget", player_id)
        widget_obj:setPosition(100, 100)
        widget_obj:setSize(200, 100)
        widget_obj:setVisible(true)
        
        -- Add a sprite
        local sprite = widget_obj:create_sprite(
            "test_sprite",
            TEXTURE_PATH,
            ANIM_PATH,
            "CURSOR_RIGHT"
        )
        
        -- Set sprite properties
        sprite:set_position(0, 0)
        sprite:set_scale(1.0)
        sprite:set_visible(true)
        
        -- Update layout
        widget_obj:updateLayout(true)
        widget_obj:draw(true)
        
        print("   Basic widget created: " .. widget_obj.id)
        return widget_obj
    end)
end

-- ===========================================================
-- LAYOUT WIDGET TESTS
-- ===========================================================

-- Async function to test Row widget
WidgetTests.test_row_widget_async= function(player_id)
    return async(function()
        print("\n4. Testing Row widget...")
        
        -- Create a Row widget
        local row = widget.createRow("test_row", player_id)
        row:setPosition(50, 200)
        row:setSpacing(20)
        row:setAlignment("center", "center")
        
        -- Add multiple sprites to the row
        for i = 1, 3 do
            row:addChild({
                type = "sprite",
                sprite_id = "row_sprite_" .. i,
                texture_path = TEXTURE_PATH,
                anim_path = ANIM_PATH,
                animation_state = "CURSOR_RIGHT",
                id = "row_item_" .. i
            })
        end
        
        -- Update and draw
        row:updateLayout(true)
        row:draw(true)
        
        print("   Row widget created with " .. #row.children .. " children")
        return row
    end)
end

-- Async function to test Column widget
WidgetTests.test_column_widget_async= function(player_id)
    return async(function()
        print("\n4b. Testing Column widget...")
        
        -- Create a Column widget
        local column = widget.createColumn("test_column", player_id)
        column:setPosition(50, 300)
        column:setSpacing(15)
        column:setAlignment("center", "center")
        
        -- Add multiple sprites to the column
        for i = 1, 4 do
            column:addChild({
                type = "sprite",
                sprite_id = "column_sprite_" .. i,
                texture_path = TEXTURE_PATH,
                anim_path = ANIM_PATH,
                animation_state = "CURSOR_RIGHT",
                id = "column_item_" .. i
            })
        end
        
        -- Update and draw
        column:updateLayout(true)
        column:draw(true)
        
        print("   Column widget created with " .. #column.children .. " children")
        return column
    end)
end

-- Async function to test Grid widget
WidgetTests.test_grid_widget_async= function(player_id)
    return async(function()
        print("\n5. Testing Grid widget...")
        
        -- Create a Grid widget
        local grid = widget.createGrid("test_grid", player_id)
        grid:setPosition(300, 100)
        grid:setColumns(4)
        grid:setSpacing(10, 10)
        grid:setCellSize(64, 64)
        
        -- Add items to grid
        for i = 1, 8 do
            grid:addItem(
                "grid_item_" .. i,
                TEXTURE_PATH,
                ANIM_PATH,
                "idle",
                { value = i * 100 }
            )
        end
        
        -- Set up selection callback
        grid.on_selection_changed = function(index, item)
            print("   Grid selection changed: index=" .. index .. ", item=" .. (item and item.id or "none"))
        end
        
        -- Update and draw
        grid:updateLayout(true)
        grid:draw(true)
        
        print("   Grid widget created with " .. #grid.items .. " items")
        return grid
    end)
end

-- Async function to test Container widget
WidgetTests.test_container_widget_async = function(player_id)
    return async(function()
        print("\n5b. Testing Container widget...")
        
        -- Create a Container widget
        local container = widget.createContainer("test_container_simple", player_id)
        container:setPosition(400, 300)
        container:setSize(150, 150)
        container:setPadding(10, 10, 10, 10)
        
        -- Create a child widget
        local child = widget.createRow("container_child", player_id)
        child:setSpacing(5)
        
        -- Add sprites to child
        for i = 1, 2 do
            child:addChild({
                type = "sprite",
                sprite_id = "container_sprite_" .. i,
                texture_path = TEXTURE_PATH,
                anim_path = ANIM_PATH,
                animation_state = "CURSOR_RIGHT"
            })
        end
        
        -- Set child and update
        container:setChild(child)
        container:updateLayout(true)
        container:draw(true)
        
        print("   Container widget created with child widget")
        return container
    end)
end

-- Async function to test Expanded widget
WidgetTests.test_expanded_widget_async = function(player_id)
    return async(function()
        print("\n5c. Testing Expanded widget...")
        
        -- Create an Expanded widget
        local expanded = widget.createExpanded("test_expanded", player_id)
        expanded:setPosition(600, 100)
        expanded:setFlex(2)
        
        -- Create a child widget
        local child = widget.createRow("expanded_child", player_id)
        child:setSpacing(10)
        
        -- Add sprites to child
        for i = 1, 3 do
            child:addChild({
                type = "sprite",
                sprite_id = "expanded_sprite_" .. i,
                texture_path = TEXTURE_PATH,
                anim_path = ANIM_PATH,
                animation_state = "CURSOR_RIGHT"
            })
        end
        
        -- Set child and update
        expanded:setChild(child)
        expanded:updateLayout(true)
        expanded:draw(true)
        
        print("   Expanded widget created with child widget")
        return expanded
    end)
end

-- ===========================================================
-- ANIMATION TESTS
-- ===========================================================

-- Async function to test animations
WidgetTests.test_animations_async = function(widget_obj)
    return async(function()
        print("\n6. Testing animations...")
        
        if not widget_obj then
            print("   No widget provided for animation test")
            return
        end
        
        -- Test position animation
        print("   Testing position animation...")
        local anim_id = widget_obj:animate_position(300, 150, 1.0, {
            easing = "ease_in_out",
            on_complete = function(values, interrupted)
                print("     Position animation complete")
            end
        })
        
        await(Async.sleep(1.2)) -- Wait for animation to complete
        
        -- Test opacity animation
        print("   Testing opacity animation...")
        widget_obj:animate_opacity(128, 0.5, {
            easing = "ease_in_out",
            recursive = true,
            on_complete = function(values, interrupted)
                print("     Opacity animation complete")
            end
        })
        
        await(Async.sleep(0.7)) -- Wait for animation to complete
        
        -- Fade back in
        widget_obj:animate_opacity(255, 0.5, {
            easing = "ease_in_out",
            recursive = true
        })
        
        await(Async.sleep(0.7))
        
        print("   Animation tests completed")
    end)
end

-- ===========================================================
-- EVENT SYSTEM TESTS
-- ===========================================================

-- Async function to test widget events
WidgetTests.test_widget_events_async = function(player_id)
    return async(function()
        print("\n7. Testing widget events...")
        
        -- Initialize widget events
        widget.Events.initialize()
        
        -- Create a selection manager
        local selection_manager = widget.SelectionManager.new()
        
        -- Create a test menu
        local menu_options = {
            { id = "option1", texture_path = TEXTURE_PATH, animation_state = "CURSOR_RIGHT" },
            { id = "option2", texture_path = TEXTURE_PATH, animation_state = "CURSOR_RIGHT" },
            { id = "option3", texture_path = TEXTURE_PATH, animation_state = "CURSOR_RIGHT" }
        }
        
        local menu = widget.Builder.createMenu("test_menu", player_id, menu_options)
        menu:setPosition(400, 50)
        menu:updateLayout(true)
        menu:draw(true)
        
        -- Register with selection manager
        selection_manager:registerWidget(menu)
        
        -- Test selection
        print("   Testing widget selection...")
        selection_manager:selectWidget("test_menu", 1)
        
        -- Simulate navigation
        print("   Simulating navigation...")
        selection_manager:moveSelection("down")
        await(Async.sleep(0.5))
        
        selection_manager:moveSelection("down")
        await(Async.sleep(0.5))
        
        selection_manager:moveSelection("up")
        
        print("   Event tests completed")
        return selection_manager
    end)
end

-- ===========================================================
-- LOGGING TESTS
-- ===========================================================

-- Async function to test logging features
WidgetTests.test_logging_features_async = function()
    return async(function()
        print("\n8. Testing logging features...")
        
        -- Test log severity change
        print("   Changing log severity to DETAILED...")
        widget_logging.LOGGING.set_severity("DETAILED")
        
        -- Read current logs
        print("   Reading log file...")
        local log_data = await(widget_logging.LOGGING.read_logs_async(10))
        print("   Found " .. log_data.total .. " log entries")
        
        -- Get log stats
        local stats = widget_logging.LOGGING.get_log_stats()
        print("   Log buffer size: " .. stats.buffer_size)
        
        -- Manually flush logs
        print("   Flushing log buffer...")
        widget_logging.LOGGING.flush_logs()
        
        -- Clear log file (optional)
        -- widget_logging.Log.clear_log_file()
        
        print("   Logging tests completed")
    end)
end

-- ===========================================================
-- COMPLEX LAYOUT TESTS
-- ===========================================================

-- Async function to test complex widget hierarchy
WidgetTests.test_complex_hierarchy_async= function(player_id)
    return async(function()
        print("\n9. Testing complex widget hierarchy...")
        
        -- Create a container
        local container = widget.createContainer("test_container", player_id)
        container:setPosition(100, 350)
        container:setSize(400, 200)
        container:setPadding(10, 10, 10, 10)
        
        -- Create a column inside the container
        local column = widget.createColumn("nested_column", player_id)
        column:setSpacing(15)
        column:setAlignment("start", "center")
        
        -- Add widgets to the column
        for i = 1, 3 do
            local row = widget.createRow("nested_row_" .. i, player_id)
            row:setSpacing(10)
            
            for j = 1, 2 do
                row:addChild({
                    type = "sprite",
                    sprite_id = "nested_sprite_" .. i .. "_" .. j,
                    texture_path = TEXTURE_PATH,
                    anim_path = ANIM_PATH,
                    animation_state = "CURSOR_RIGHT"
                })
            end
            
            column:addWidget(row)
        end
        
        -- Add column to container
        container:setChild(column)
        
        -- Update and draw
        container:updateLayout(true)
        container:draw(true)
        
        print("   Complex hierarchy created")
        
        -- Print debug info
        print("\n   Container structure:")
        widget.Debug.printWidgetTree(container)
        
        return container
    end)
end

-- ===========================================================
-- ANIMATION HELPER TESTS
-- ===========================================================

-- Async function to test animation helpers
WidgetTests.test_animation_helpers_async = function(player_id)
    return async(function()
        print("\n10. Testing animation helpers...")
        
        -- Create two widgets for hero animation test
        local widget1 = widget.createRow("anim_widget1", player_id)
        widget1:setPosition(500, 300)
        
        local widget2 = widget.createRow("anim_widget2", player_id)
        widget2:setPosition(600, 300)
        
        -- Add sprites to both widgets
        widget1:addChild({
            type = "sprite",
            sprite_id = "hero_sprite1",
            texture_path = TEXTURE_PATH,
            anim_path = ANIM_PATH
        })
        
        widget2:addChild({
            type = "sprite",
            sprite_id = "hero_sprite2",
            texture_path = TEXTURE_PATH,
            anim_path = ANIM_PATH
        })
        
        widget1:updateLayout(true)
        widget2:updateLayout(true)
        widget1:draw(true)
        widget2:draw(true)
        
        -- Test slide animation
        print("   Testing slide animation...")
        widget.Animations.slideWidget(widget1, 550, 300, 1.0, "ease_in_out", function()
            print("     Slide animation complete")
        end)
        
        await(Async.sleep(1.5))
        
        -- Test fade animation
        print("   Testing fade animation...")
        widget.Animations.fadeWidget(widget2, 100, 0.8, "ease_in_out", function()
            print("     Fade animation complete")
        end)
        
        await(Async.sleep(1.0))
        
        -- Fade back in
        widget.Animations.fadeWidget(widget2, 255, 0.8, "ease_in_out")
        
        await(Async.sleep(1.0))
        
        -- Test pulse animation
        print("   Testing pulse animation...")
        local pulse_anims = widget.Animations.pulseWidget(widget1, 1.0, 1.2, 1.5, "elastic_out", false, function()
            print("     Pulse animation complete")
        end)
        
        await(Async.sleep(2.0))
        
        -- Test shake animation
        print("   Testing shake animation...")
        local shake_anims = widget.Animations.shakeWidget(widget2, 3, 0.3, "elastic_out", function()
            print("     Shake animation complete")
        end)
        
        await(Async.sleep(0.5))
        
        print("   Animation helper tests completed")
        return {widget1, widget2}
    end)
end

-- ===========================================================
-- SPRITE OBJECT TESTS
-- ===========================================================

-- Async function to test sprite object features
WidgetTests.test_sprite_features_async = function(player_id)
    return async(function()
        print("\n10b. Testing SpriteObject features...")
        
        -- Create a widget
        local widget_obj = widget.Widget.new("sprite_test_widget", player_id)
        widget_obj:setPosition(700, 100)
        widget_obj:setSize(100, 100)
        
        -- Create multiple sprites
        local sprite1 = widget_obj:create_sprite("sprite_feature_1", TEXTURE_PATH, ANIM_PATH, "CURSOR_RIGHT")
        local sprite2 = widget_obj:create_sprite("sprite_feature_2", TEXTURE_PATH, ANIM_PATH, "CURSOR_RIGHT")
        local sprite3 = widget_obj:create_sprite("sprite_feature_3", TEXTURE_PATH, ANIM_PATH, "CURSOR_RIGHT")
        
        -- Test sprite positioning
        sprite1:set_position(0, 0)
        sprite2:set_position(20, 20)
        sprite3:set_position(40, 40)
        
        -- Test sprite scaling
        sprite1:set_scale(1.0)
        sprite2:set_scale(1.5)
        sprite3:set_scale(0.8)
        
        -- Test sprite rotation
        sprite2:set_rotation(45)
        
        -- Test sprite color
        sprite3:set_color(255, 200, 150, 200)
        
        -- Test sprite opacity
        sprite1:set_opacity(180)
        
        -- Create a sprite group
        widget_obj:create_sprite_group("feature_group", {"sprite_feature_1", "sprite_feature_2"})
        
        -- Set properties for group
        widget_obj:set_group_properties("feature_group", {
            visible = true,
            opacity = 150
        })
        
        -- Update and draw
        widget_obj:updateLayout(true)
        widget_obj:draw(true)
        
        print("   Sprite feature tests completed")
        return widget_obj
    end)
end

-- ===========================================================
-- DIMENSION CACHE TESTS
-- ===========================================================

-- Async function to test dimension cache
WidgetTests.test_dimension_cache_async= function()
    return async(function()
        print("\n10c. Testing dimension cache...")
        
        -- Clear cache first
        widget.SpriteDimensionCache.clear()
        
        -- Get dimensions multiple times (should cache)
        local w1, h1 = widget.SpriteDimensionCache.get_dimensions(TEXTURE_PATH, ANIM_PATH, "CURSOR_RIGHT")
        print("   First call - Width: " .. w1 .. ", Height: " .. h1)
        
        local w2, h2 = widget.SpriteDimensionCache.get_dimensions(TEXTURE_PATH, ANIM_PATH, "CURSOR_RIGHT")
        print("   Second call (cached) - Width: " .. w2 .. ", Height: " .. h2)
        
        -- Get stats
        local cache_stats = widget.SpriteDimensionCache.stats()
        print("   Cache entries: " .. cache_stats)
        
        -- Clear cache and check again
        widget.SpriteDimensionCache.clear()
        local cache_stats_after = widget.SpriteDimensionCache.stats()
        print("   Cache entries after clear: " .. cache_stats_after)
        
        print("   Dimension cache tests completed")
    end)
end

-- ===========================================================
-- CLEANUP TESTS
-- ===========================================================

-- Async function to test cleanup
WidgetTests.test_cleanup_async = function(player_id, widgets_list)
    return async(function()
        print("\n11. Testing cleanup...")
        
        -- Clear all widgets for player
        local cleared = widget.clearPlayerWidgets(player_id)
        print("   Cleared " .. cleared .. " widgets for player " .. player_id)
        
        -- Stop all animations
        widget.stopAllAnimations()
        print("   Stopped all animations")
        
        -- Print cache stats
        print("   Cache stats:")
        widget.printCacheStats()
        
        -- Print system stats
        print("   System stats:")
        widget.Debug.getStats()
        
        -- Final log flush
        widget_logging.LOGGING.flush_logs()
        print("   Final log flush completed")
    end)
end

-- ===========================================================
-- MAIN TEST RUNNER
-- ===========================================================

-- Main async test runner
WidgetTests.run_widget_tests_async = function()
    return async(function()
        print("Starting widget system tests...")
        
        -- Setup
        local player_id = await(WidgetTests.setup_test_async())
        
        -- Run individual tests
        local basic_widget = await(WidgetTests.test_basic_widget_async(player_id))
        local row_widget = await(WidgetTests.test_row_widget_async(player_id))
        local column_widget = await(WidgetTests.test_column_widget_async(player_id))
        local grid_widget = await(WidgetTests.test_grid_widget_async(player_id))
        local container_widget = await(WidgetTests.test_container_widget_async(player_id))
        local expanded_widget = await(WidgetTests.test_expanded_widget_async(player_id))
        await(WidgetTests.test_animations_async(basic_widget))
        local selection_manager = await(WidgetTests.test_widget_events_async(player_id))
        await(WidgetTests.test_logging_features_async())
        local container = await(WidgetTests.test_complex_hierarchy_async(player_id))
        local anim_widgets = await(WidgetTests.test_animation_helpers_async(player_id))
        local sprite_test_widget = await(WidgetTests.test_sprite_features_async(player_id))
        await(WidgetTests.test_dimension_cache_async())
        
        -- Collect all widgets for cleanup
        local all_widgets = {
            basic_widget,
            row_widget,
            column_widget,
            grid_widget,
            container_widget,
            expanded_widget,
            container,
            sprite_test_widget,
            table.unpack(anim_widgets or {})
        }
        
        -- Wait a bit before cleanup to see everything
        print("\nWaiting 3 seconds before cleanup...")
        await(Async.sleep(3.0))
        
        -- Cleanup
        await(WidgetTests.test_cleanup_async(player_id, all_widgets))
        
        print("\n=== All widget tests completed successfully ===")
        return true
    end)
end

-- ===========================================================
-- UTILITY FUNCTIONS
-- ===========================================================

-- Error handling wrapper
WidgetTests.run_tests_safely = function()
    return async(function()
        local success, result = pcall(function()
            return await(WidgetTests.run_widget_tests_async())
        end)
        
        if success then
            print("Tests completed: " .. tostring(result))
            return result
        else
            print("Error running tests: " .. tostring(result))
            -- Try to flush logs even on error
            pcall(function() widget_logging.LOGGING.flush_logs() end)
            return false
        end
    end)
end

-- Utility function for quick testing
WidgetTests.quick_widget_test = function(player_id)
    return async(function()
        print("[Quick Widget Test] for player: " .. player_id)
        
        -- Simple test: create a basic widget
        local widget_obj = widget.createRow("quick_test", player_id)
        widget_obj:setPosition(100, 100)
        widget_obj:setSpacing(20)
        
        -- Add a few sprites
        for i = 1, 3 do
            widget_obj:addChild({
                type = "sprite",
                sprite_id = "quick_sprite_" .. i,
                texture_path = TEXTURE_PATH,
                anim_path = ANIM_PATH,
                id = "quick_" .. i
            })
        end
        
        widget_obj:updateLayout(true)
        widget_obj:draw(true)
        
        print("[Quick Widget Test] Widget created: " .. widget_obj.id)
        return widget_obj
    end)
end

-- ===========================================================
-- PUBLIC API
-- ===========================================================

-- Exported test function (call this from your game)
WidgetTests.run_widget_tests = function()
    print("[Widget Tests] Starting widget system tests...")
    
    -- Run tests asynchronously
    WidgetTests.run_tests_safely():and_then(function(success)
        if success then
            print("[Widget Tests] All tests passed!")
        else
            print("[Widget Tests] Some tests failed!")
        end
    end):catch(function(error)
        print("[Widget Tests] Error in tests: " .. tostring(error))
    end)
end

-- Module exports
return {
    -- Main test functions
    runTests = WidgetTests.run_widget_tests,
    quickTest = function(player_id) 
        WidgetTests.quick_widget_test(player_id) 
    end,
    runFullTests = WidgetTests.run_widget_tests_async,
    
    -- Individual test components (for selective testing)
    testBasicWidget = WidgetTests.test_basic_widget_async,
    testRowWidget = WidgetTests.test_row_widget_async,
    testColumnWidget = WidgetTests.test_column_widget_async,
    testGridWidget = WidgetTests.test_grid_widget_async,
    testContainerWidget = WidgetTests.test_container_widget_async,
    testExpandedWidget = WidgetTests.test_expanded_widget_async,
    testAnimations = WidgetTests.test_animations_async,
    testWidgetEvents = WidgetTests.test_widget_events_async,
    testLogging = WidgetTests.test_logging_features_async,
    testComplexHierarchy = WidgetTests.test_complex_hierarchy_async,
    testAnimationHelpers = WidgetTests.test_animation_helpers_async,
    testSpriteFeatures = WidgetTests.test_sprite_features_async,
    testDimensionCache = WidgetTests.test_dimension_cache_async,
    testCleanup = WidgetTests.test_cleanup_async,
    
    -- Utility functions for manual testing
    createTestWidget = function(player_id, x, y)
        return async(function()
            local widget_obj = widget.createColumn("manual_test", player_id)
            widget_obj:setPosition(x or 50, y or 50)
            widget_obj:setSpacing(10)
            
            for i = 1, 2 do
                widget_obj:addChild({
                    type = "sprite",
                    sprite_id = "manual_sprite_" .. i,
                    texture_path = TEXTURE_PATH,
                    anim_path = ANIM_PATH,
                    id = "manual_" .. i
                })
            end
            
            widget_obj:updateLayout(true)
            widget_obj:draw(true)
            return widget_obj
        end)
    end,
    
    testAnimation = function(widget_obj, target_x, target_y)
        return async(function()
            if widget_obj and widget_obj.animate_position then
                widget_obj:animate_position(target_x or widget_obj.x + 100, target_y or widget_obj.y, 1.0, {
                    easing = "ease_in_out",
                    on_complete = function()
                        print("Manual animation complete")
                    end
                })
            end
        end)
    end,
    
    -- Asset path constants
    TEXTURE_PATH = TEXTURE_PATH,
    ANIM_PATH = ANIM_PATH,
    
    -- Widget creation shortcuts
    createRow = function(player_id, id, x, y)
        return async(function()
            local widget_obj = widget.createRow(id or "test_row", player_id)
            widget_obj:setPosition(x or 100, y or 100)
            widget_obj:setSpacing(10)
            widget_obj:updateLayout(true)
            widget_obj:draw(true)
            return widget_obj
        end)
    end,
    
    createGrid = function(player_id, id, x, y, columns)
        return async(function()
            local widget_obj = widget.createGrid(id or "test_grid", player_id)
            widget_obj:setPosition(x or 200, y or 200)
            widget_obj:setColumns(columns or 3)
            widget_obj:setSpacing(5, 5)
            widget_obj:setCellSize(50, 50)
            
            for i = 1, 6 do
                widget_obj:addItem(
                    "item_" .. i,
                    TEXTURE_PATH,
                    ANIM_PATH,
                    "CURSOR_RIGHT",
                    { index = i }
                )
            end
            
            widget_obj:updateLayout(true)
            widget_obj:draw(true)
            return widget_obj
        end)
    end,
    
    -- Export the modules for external use
    widget = widget,
    widget_logging = widget_logging
}