-- Minimal Displayer Example - Working Version with Global Timer
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
        join_time = os.clock()
    }
    
    -- Hide default HUD
    displayer:hidePlayerHUD(player_id)
    
    -- UI Layout (non-overlapping positions):
    -- Top-left: Global timer (10, 10)
    -- Top-center: Marquee area (10, 30)
    -- Center-left: Player timers (10, 80)
    -- Center: Player character (120, 80)
    -- Center-right: Notifications (150, 80)
    -- Bottom: Text boxes (20, 140)
    
    -- Create global timer display (top-left)
    displayer.TimerDisplay:createGlobalTimerDisplay("global_timer", 10, 10, "large")
    displayer.TimerDisplay:updateGlobalTimerDisplay("global_timer", global_timer.elapsed_time)
    
    -- Create news marquee (top-center)
    displayer.Text:drawMarqueeText(player_id, "news_ticker", 
        "Welcome to the Tournament! New players joining every day!", 
        30, "THICK", 1.0, 100, "slow", {
            x = 10, y = 25, width = 220, height = 15,
            padding_x = 8, padding_y = 2
        })
    
    -- Create player timer displays (center-left)
    displayer.TimerDisplay:createPlayerTimerDisplay(player_id, "player_timer", 10, 80, "default")
    displayer.TimerDisplay:createPlayerCountdownDisplay(player_id, "player_countdown", 10, 100, "default")
    
    -- Create welcome message (bottom)
    displayer.Text:createTextBox(player_id, "welcome", 
        "Welcome to the Tournament Arena! Your mission begins in 3 seconds...", 
        20, 140, 200, 50, "THICK", 1.0, 100, {
            x = 15, y = 135, width = 210, height = 60,
            padding_x = 8, padding_y = 6
        }, 25)
    
    -- Mark for delayed start
    player_data[player_id].waiting_for_start = true
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
    
    -- Handle delayed starts for players
    for player_id, data in pairs(player_data) do
        if data.waiting_for_start and not data.session_started then
            -- Check if 3 seconds have passed since join
            if current_time - data.join_time >= 3.0 then
                data.session_started = true
                data.countdown_running = true
                data.waiting_for_start = false
                displayer.Text:createTextBox(player_id, "start_msg", 
                    "Mission started! Defeat enemies before time runs out!", 
                    150, 80, 80, 40, "THICK", 0.9, 100, {
                        x = 145, y = 75, width = 90, height = 50,
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
                        "Time's up! Mission complete! Score: 1500", 
                        150, 120, 80, 40, "THICK", 0.9, 100, {
                            x = 145, y = 115, width = 90, height = 50,
                            padding_x = 4, padding_y = 4
                        }, 35)
                end
            end
        end
    end
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

Net:on("marquee", function(event)
    local player_id = event.player_id
    local text = event.text or "This is a scrolling marquee message!"
    displayer.Text:drawMarqueeText(player_id, "test_marquee", text, 
        50, "THICK", 1.0, 100, "medium", {
            x = 10, y = 45, width = 220, height = 15,
            padding_x = 8, padding_y = 2
        })
end)

Net:on("story", function(event)
    local player_id = event.player_id
    local story_text = "In the year 210X, the digital world has become intertwined with our reality. " ..
                      "As a net operator, you have been chosen to participate in the annual tournament. " ..
                      "Your mission is to survive against waves of digital creatures and other operators. " ..
                      "Use your abilities wisely and remember: timing is everything!"
    
    displayer.Text:createTextBox(player_id, "story_box", story_text, 
        20, 50, 200, 80, "THICK", 1.0, 100, {
            x = 15, y = 45, width = 210, height = 90,
            padding_x = 8, padding_y = 6
        }, 20)
end)

Net:on("score", function(event)
    local player_id = event.player_id
    local score = event.score or "1000"
    displayer.Text:drawText(player_id, "SCORE: " .. score, 180, 10, "BATTLE", 1.2, 100)
    displayer.Text:addBackdrop(player_id, "score_display", {
        x = 175, y = 5, width = 60, height = 20,
        padding_x = 4, padding_y = 2
    })
end)

print("Minimal Displayer example with global timer loaded and ready!")