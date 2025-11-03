-- Minimal Displayer Example - Working Version with Global Timer and Scrolling Lists
local Displayer = require("scripts/displayer/displayer")

-- Initialize the displayer system
local displayer = Displayer:init()
if not displayer then
    print("Failed to initialize Displayer API")
    return
end

print("Displayer API loaded successfully!")

-- Simple state management
local player_data = {}
local global_timer = {
    elapsed_time = 0,
    running = false
}

-- Player join handler
Net:on("player_join", function(event)
    local player_id = event.player_id
    print("Player joined: " .. player_id)
    
    -- Initialize player data
    player_data[player_id] = {
        elapsed_time = 0,
        countdown_time = 60,
        countdown_running = false,
        session_started = false,
        join_time = os.clock(),
        scrolling_list_created = false,
        scrolling_list_timer = 0,
        countdown_text_id = nil,
        fullscreen_scroll_created = false
    }
    
    -- Hide default HUD
    displayer:hidePlayerHUD(player_id)
    -- In the player_join handler, change the global timer display creation to:
    displayer.TimerDisplay:createGlobalTimerDisplay("global_timer", 10, 10, "default")

    -- And ensure the scrolling list has a lower z-order:
    displayer.ScrollingText:createList(player_id, "fullscreen_display", 0, 0, 480, 320, {
        -- ... other config
        z_order = 50,  -- Lower than timer display's 100
        -- ... other config
    })
    displayer.TimerDisplay:updateGlobalTimerDisplay("global_timer", global_timer.elapsed_time)
    
    -- Create news marquee (top-center)
    displayer.Text:drawMarqueeText(player_id, "news_ticker", 
        "Welcome! Fullscreen display will appear in 5 seconds!", 
        30, "THICK", 1.0, 100, "slow", {
            x = 10, y = 25, width = 220, height = 15,
            padding_x = 8, padding_y = 2
        })
    
    -- Create player timer displays (left side)
    displayer.TimerDisplay:createPlayerTimerDisplay(player_id, "player_timer", 10, 50, "default")
    displayer.TimerDisplay:createPlayerCountdownDisplay(player_id, "player_countdown", 10, 70, "default")
    
    -- Add labels for timers
    displayer.Text:drawText(player_id, "PLAY TIME", 12, 40, "THICK", 0.7, 100)
    displayer.Text:drawText(player_id, "MISSION TIMER", 12, 60, "THICK", 0.7, 100)
    
    -- Create initial countdown text
    player_data[player_id].countdown_text_id = displayer.Text:drawText(player_id, "Fullscreen in: 5", 12, 90, "THICK", 0.7, 100)
    
    -- Mark for delayed start
    player_data[player_id].waiting_for_start = true
    
    -- DEBUG: Create a simple test text to verify display is working
    displayer.Text:drawText(player_id, "DEBUG: Display working", 10, 110, "THICK", 0.7, 100)
end)

-- Player disconnect handler
Net:on("player_disconnect", function(event)
    local player_id = event.player_id
    print("Player disconnected: " .. player_id)
    player_data[player_id] = nil
end)

-- Main update loop
Net:on("tick", function(event)
    local delta = event.delta_time or 0
    local current_time = os.clock()
    
    -- Update global timer (always runs)
    global_timer.elapsed_time = global_timer.elapsed_time + delta
    displayer.TimerDisplay:updateGlobalTimerDisplay("global_timer", global_timer.elapsed_time)
    
    -- Handle delayed starts for players and scrolling list creation
    for player_id, data in pairs(player_data) do
        -- Create fullscreen 3x scale scrolling list after 5 seconds
        if not data.fullscreen_scroll_created and data.scrolling_list_timer >= 5.0 then
            data.fullscreen_scroll_created = true
            
            -- Remove countdown text
            if data.countdown_text_id then
                displayer.Text:removeText(player_id, data.countdown_text_id)
                data.countdown_text_id = nil
            end
            
            -- Create fullscreen 3x scale scrolling text list
            local fullscreen_messages = {
                "=== FULLSCREEN DISPLAY ===",
                "Scale: 3.0x",
                "Backdrop: Full Screen",
                "Text: Large and Clear",
                "Perfect for announcements",
                "or important messages!",
                "This text is scaled 3x",
                "Monospace preserved!",
                "Character spacing maintained",
                "Easy to read from distance",
                "Great for titles and headers",
                "Backdrop covers entire screen",
                "Using marquee-backdrop.png",
                "Dimensions: 240x160",
                "Position: 0,0",
                "Enjoy the enhanced visibility!",
                "======================"
            }
            
            -- FIXED: Create the fullscreen scrolling list with proper configuration
            local success = displayer.ScrollingText:createList(player_id, "fullscreen_display", 0, 0, 480, 320, {
                texts = fullscreen_messages,
                scroll_speed = 40,  -- Increased speed for large text
                entry_delay = 2.0,
                font = "THICK",    -- Use BATTLE font for better visibility at large scale
                scale = 2.0,        -- 3x scale
                z_order = 50,       -- Lower z-order to ensure it's visible
                loop = true,
                backdrop = {
                    x = 0, y = 0, width = 480, height = 320,
                    padding_x = 0,  -- Increased padding for large text
                    padding_y = 0
                },
                destroy_when_finished = false
            })
            
            if success then
                print("Fullscreen 3x scale scrolling list created successfully for player " .. player_id)
                
                -- DEBUG: Add a test message to verify the list is working
                displayer.ScrollingText:addText(player_id, "fullscreen_display", "DEBUG: List is working!")
            else
                print("ERROR: Failed to create fullscreen scrolling list for player " .. player_id)
                
                -- Show error message
                displayer.Text:drawText(player_id, "ERROR: Fullscreen failed", 10, 120, "THICK", 0.7, 100)
            end
        end
        
        -- Update scrolling list timer
        if not data.fullscreen_scroll_created then
            data.scrolling_list_timer = data.scrolling_list_timer + delta
            local time_remaining = math.max(0, 5 - data.scrolling_list_timer)
            
            -- Update countdown text using the stored text ID
            if data.countdown_text_id then
                displayer.Text:updateText(player_id, data.countdown_text_id, "Fullscreen in: " .. math.ceil(time_remaining))
            end
        end
        
        if data.waiting_for_start and not data.session_started then
            -- Check if 3 seconds have passed since join
            if current_time - data.join_time >= 3.0 then
                data.session_started = true
                data.countdown_running = true
                data.waiting_for_start = false
                displayer.Text:createTextBox(player_id, "start_msg", 
                    "Mission started! Defeat enemies!", 
                    150, 100, 80, 40, "THICK", 0.9, 100, {
                        x = 145, y = 95, width = 90, height = 50,
                        padding_x = 4, padding_y = 4
                    }, 35)
                print("Starting timers for player " .. player_id)
            end
        end
        
        -- Update timers if session has started
        if data.session_started then
            -- Update elapsed timer (counts up)
            data.elapsed_time = data.elapsed_time + delta
            displayer.TimerDisplay:updatePlayerTimerDisplay(player_id, "player_timer", data.elapsed_time)
            
            -- Update countdown if running
            if data.countdown_running then
                data.countdown_time = math.max(0, data.countdown_time - delta)
                displayer.TimerDisplay:updatePlayerCountdownDisplay(player_id, "player_countdown", data.countdown_time)
                
                -- Handle countdown completion
                if data.countdown_time <= 0 then
                    data.countdown_running = false
                    displayer.Text:createTextBox(player_id, "countdown_complete", 
                        "Time's up! Mission complete!", 
                        150, 120, 80, 40, "THICK", 0.9, 100, {
                            x = 145, y = 115, width = 90, height = 50,
                            padding_x = 4, padding_y = 4
                        }, 35)
                end
            end
        end
    end
end)

-- NEW COMMAND: Create fullscreen 3x scale scrolling list on demand (DEBUG VERSION)
Net:on("create_fullscreen", function(event)
    local player_id = event.player_id
    
    local messages = {
        "=== FULLSCREEN 3X SCALE ===",
        "Created on demand!",
        "Scale: 3.0x", 
        "Backdrop: Full Screen",
        "Position: 0,0",
        "Size: 240x160",
        "Font: BATTLE",
        "Monospace preserved!",
        "Perfect for announcements!",
        "======================"
    }
    
    -- Remove any existing fullscreen list first
    displayer.ScrollingText:removeList(player_id, "manual_fullscreen")
    
    local success = displayer.ScrollingText:createList(player_id, "manual_fullscreen", 120, 80, 240, 160, {
        texts = messages,
        scroll_speed = 40,
        entry_delay = 2.0,
        font = "THICK",
        scale = 3.0,
        z_order = 50,
        loop = true,
        backdrop = {
            x = 0, y = 0, width = 240, height = 160,
            padding_x = 20,
            padding_y = 20
        },
        destroy_when_finished = false
    })
    
    if success then
        displayer.Text:createTextBox(player_id, "fullscreen_created", 
            "Fullscreen 3x display created successfully!", 
            10, 130, 120, 30, "THICK", 0.8, 100, nil, 40)
        print("Manual fullscreen display created for player " .. player_id)
    else
        displayer.Text:createTextBox(player_id, "fullscreen_error", 
            "ERROR: Failed to create fullscreen!", 
            10, 130, 120, 30, "THICK", 0.8, 100, nil, 40)
        print("ERROR: Failed to create manual fullscreen display for player " .. player_id)
    end
end)

-- DEBUG COMMAND: Check if scrolling text list system is working
Net:on("debug_scroll", function(event)
    local player_id = event.player_id
    
    -- Test with a simple small scrolling list first
    local test_messages = {
        "DEBUG: Small test",
        "This should work",
        "If this appears,",
        "system is working!",
        "Scale: 1.0",
        "Position: 10,140"
    }
    
    displayer.ScrollingText:createList(player_id, "debug_list", 10, 140, 100, 50, {
        texts = test_messages,
        scroll_speed = 20,
        entry_delay = 1.0,
        font = "THICK",
        scale = 1.0,
        z_order = 100,
        loop = true,
        backdrop = {
            x = 5, y = 135, width = 110, height = 60,
            padding_x = 8,
            padding_y = 8
        },
        destroy_when_finished = false
    })
    
    displayer.Text:drawText(player_id, "DEBUG: Test list created", 10, 200, "THICK", 0.7, 100)
end)

-- Simple commands for testing
Net:on("reset", function(event)
    local player_id = event.player_id
    if player_data[player_id] then
        player_data[player_id].countdown_time = 60
        player_data[player_id].countdown_running = true
        displayer.TimerDisplay:updatePlayerCountdownDisplay(player_id, "player_countdown", 60)
        displayer.Text:createTextBox(player_id, "reset_msg", "Countdown reset to 60 seconds!", 
            150, 60, 80, 30, "THICK", 0.8, 100, nil, 40)
    end
end)

Net:on("add_text", function(event)
    local player_id = event.player_id
    local text = event.text or "This is a test message!"
    displayer.Text:createTextBox(player_id, "custom_text", text, 
        150, 160, 80, 30, "THICK", 0.8, 100, nil, 35)
end)

Net:on("clear_all", function(event)
    local player_id = event.player_id
    -- Remove all scrolling lists
    displayer.ScrollingText:removeList(player_id, "fullscreen_display")
    displayer.ScrollingText:removeList(player_id, "manual_fullscreen") 
    displayer.ScrollingText:removeList(player_id, "debug_list")
    
    displayer.Text:createTextBox(player_id, "cleared", "All displays cleared!", 
        150, 180, 80, 30, "THICK", 0.8, 100, nil, 40)
end)

print("Enhanced Displayer example with fullscreen 3x scale display loaded and ready!")
print("Use 'create_fullscreen' command to test manually")
print("Use 'debug_scroll' command to test with small list")
print("Use 'clear_all' command to remove all displays")