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
        countdown_text_id = nil
    }
    
    -- Hide default HUD
    displayer:hidePlayerHUD(player_id)
    
    -- Enhanced UI Layout with scrolling text areas:
    -- Top-left: Global timer (10, 10)
    -- Top-center: Marquee area (10, 30)
    -- Left: Player timers (10, 50-80)
    -- Center-left: System messages (10, 90+) - WILL APPEAR AFTER 10 SECONDS
    -- Center: Player character (120, 80)
    -- Center-right: News feed (180, 40)
    -- Right: Notifications (150, 80+)
    -- Bottom: Text boxes (20, 160+)
    
    -- Create global timer display (top-left)
    displayer.TimerDisplay:createGlobalTimerDisplay("global_timer", 10, 10, "large")
    displayer.TimerDisplay:updateGlobalTimerDisplay("global_timer", global_timer.elapsed_time)
    
    -- Create news marquee (top-center)
    displayer.Text:drawMarqueeText(player_id, "news_ticker", 
        "Welcome to the Tournament! Important messages will appear on the left in 10 seconds!", 
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
    player_data[player_id].countdown_text_id = displayer.Text:drawText(player_id, "Messages in: 10", 12, 90, "THICK", 0.7, 100)
    
    -- Create live news feed (center-right)
    local initial_news = {
        "Live: Welcome to the arena!",
        "Update: Game version 1.0",
        "Event: Tournament starting soon",
        "Tip: Watch for system messages",
        "Alert: Important info in 10s"
    }
    
    displayer.ScrollingText:createList(player_id, "news_feed", 180, 40, 50, 100, {
        texts = initial_news,
        scroll_speed = 12,
        entry_delay = 4.0,
        font = "THICK",
        scale = 0.6,
        loop = true,
        backdrop = {
            x = 175, y = 35, width = 60, height = 110,
            padding_x = 4,
            padding_y = 4
        },
        destroy_when_finished = false
    })
    
    -- Create welcome message (bottom)
    displayer.Text:createTextBox(player_id, "welcome", 
        "Welcome! System messages will appear on the left side in 10 seconds. Watch the countdown above!", 
        20, 210, 200, 40, "THICK", 1.0, 100, {
            x = 15, y = 205, width = 210, height = 50,
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
    
    -- Handle delayed starts for players and scrolling list creation
    for player_id, data in pairs(player_data) do
        -- Update scrolling list timer and countdown display
        if not data.scrolling_list_created then
            data.scrolling_list_timer = data.scrolling_list_timer + delta
            local time_remaining = math.max(0, 10 - data.scrolling_list_timer)
            
            -- Update countdown text using the stored text ID
            if data.countdown_text_id then
                displayer.Text:updateText(player_id, data.countdown_text_id, "Messages in: " .. math.ceil(time_remaining))
            end
            
            -- Create scrolling list after 10 seconds
            if data.scrolling_list_timer >= 10.0 and not data.scrolling_list_created then
                data.scrolling_list_created = true
                
                -- Remove countdown text
                if data.countdown_text_id then
                    displayer.Text:removeText(player_id, data.countdown_text_id)
                    data.countdown_text_id = nil
                end
                
                -- Create system messages scroller (center-left)
                local system_messages = {
                    "=== SYSTEM MESSAGES ===",
                    "Player " .. player_id .. " connected",
                    "Session time: " .. os.date("%H:%M:%S"),
                    "Game status: ACTIVE",
                    "Tournament: STARTING SOON",
                    "Objectives:",
                    "- Survive 5 minutes",
                    "- Defeat 50 enemies", 
                    "- Collect 10 power-ups",
                    "Current rank: ROOKIE",
                    "Next rank: APPRENTICE",
                    "Tips:",
                    "- Watch your health",
                    "- Manage abilities carefully",
                    "- Use cover strategically",
                    "- Team up with others",
                    "Good luck, operator!",
                    "======================"
                }
                
                displayer.ScrollingText:createList(player_id, "system_messages", 10, 90, 100, 80, {
                    texts = system_messages,
                    scroll_speed = 15,
                    entry_delay = 1.0,
                    font = "THICK",
                    scale = 0.6,
                    backdrop = {
                        x = 5, y = 85, width = 110, height = 90,
                        padding_x = 4,
                        padding_y = 4
                    },
                    destroy_when_finished = false
                })
                
                -- Show notification that messages started
                displayer.Text:createTextBox(player_id, "messages_started", 
                    "System messages activated! Check left panel.", 
                    150, 80, 80, 30, "THICK", 0.8, 100, nil, 35)
                    
                print("Scrolling list created for player " .. player_id)
            end
        end
        
        if data.waiting_for_start and not data.session_started then
            -- Check if 3 seconds have passed since join
            if current_time - data.join_time >= 3.0 then
                data.session_started = true
                data.countdown_running = true
                data.waiting_for_start = false
                displayer.Text:createTextBox(player_id, "start_msg", 
                    "Mission started! Defeat enemies before time runs out!", 
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

-- Scrolling Text List usage examples
Net:on("create_credits", function(event)
    local player_id = event.player_id
    
    local credits = {
        "PRODUCED BY",
        "YOUR STUDIO NAME",
        "",
        "DIRECTOR",
        "Lead Developer",
        "",
        "PROGRAMMING",
        "Senior Programmer",
        "Gameplay Programmer",
        "UI Programmer",
        "",
        "ART",
        "Lead Artist",
        "Character Artist",
        "Environment Artist",
        "",
        "MUSIC & SOUND",
        "Composer",
        "Sound Designer",
        "",
        "SPECIAL THANKS",
        "All Our Playtesters",
        "The Community",
        "",
        "THANK YOU FOR PLAYING!"
    }
    
    displayer.ScrollingText:createList(player_id, "credits", 60, 160, 120, 120, {
        texts = credits,
        scroll_speed = 20,
        entry_delay = 0.5,
        font = "BATTLE",
        scale = 0.8,
        backdrop = {
            x = 55, y = 155, width = 130, height = 130,
            padding_x = 10,
            padding_y = 10
        },
        destroy_when_finished = true
    })
end)

Net:on("create_tutorial_steps", function(event)
    local player_id = event.player_id
    
    local tutorial_steps = {
        "Step 1: Move with WASD",
        "Step 2: Jump with SPACE",
        "Step 3: Attack with MOUSE CLICK",
        "Step 4: Use abilities with 1-4",
        "Step 5: Collect power-ups",
        "Step 6: Avoid red enemies",
        "Step 7: Complete objectives",
        "Step 8: Survive as long as possible!"
    }
    
    displayer.ScrollingText:createList(player_id, "tutorial", 20, 40, 100, 80, {
        texts = tutorial_steps,
        scroll_speed = 25,
        entry_delay = 2.0,
        font = "THICK",
        scale = 0.7,
        backdrop = {
            x = 15, y = 35, width = 110, height = 90,
            padding_x = 8,
            padding_y = 6
        },
        destroy_when_finished = true
    })
end)

Net:on("add_news_item", function(event)
    local player_id = event.player_id
    local news_text = event.text or "New event occurred!"
    
    displayer.ScrollingText:addText(player_id, "news_feed", news_text)
    
    displayer.Text:createTextBox(player_id, "news_added", 
        "News item added to feed!", 
        150, 160, 80, 30, "THICK", 0.8, 100, nil, 40)
end)

Net:on("update_leaderboard", function(event)
    local player_id = event.player_id
    
    local leaderboard = {
        "=== LEADERBOARD ===",
        "1. Operator_42 - 15,000",
        "2. NetRunner - 12,500", 
        "3. CyberNinja - 11,200",
        "4. DataStorm - 10,800",
        "5. ByteMaster - 9,750",
        "6. CodeWarrior - 8,900",
        "7. PixelPioneer - 7,600",
        "8. BinaryHero - 6,800",
        "==================="
    }
    
    displayer.ScrollingText:createList(player_id, "leaderboard", 100, 160, 120, 120, {
        texts = leaderboard,
        scroll_speed = 18,
        entry_delay = 0.3,
        font = "BATTLE",
        scale = 0.7,
        backdrop = {
            x = 95, y = 155, width = 130, height = 130,
            padding_x = 8,
            padding_y = 8
        },
        destroy_when_finished = true
    })
end)

Net:on("control_scroll", function(event)
    local player_id = event.player_id
    local action = event.action
    
    if action == "pause" then
        displayer.ScrollingText:pause(player_id, "news_feed")
        displayer.Text:createTextBox(player_id, "scroll_paused", 
            "News feed paused", 150, 80, 80, 30, "THICK", 0.8, 100, nil, 40)
    elseif action == "resume" then
        displayer.ScrollingText:resume(player_id, "news_feed")
        displayer.Text:createTextBox(player_id, "scroll_resumed", 
            "News feed resumed", 150, 80, 80, 30, "THICK", 0.8, 100, nil, 40)
    elseif action == "faster" then
        displayer.ScrollingText:setSpeed(player_id, "news_feed", 30)
        displayer.Text:createTextBox(player_id, "scroll_faster", 
            "Scroll speed increased", 150, 80, 80, 30, "THICK", 0.8, 100, nil, 40)
    elseif action == "slower" then
        displayer.ScrollingText:setSpeed(player_id, "news_feed", 10)
        displayer.Text:createTextBox(player_id, "scroll_slower", 
            "Scroll speed decreased", 150, 80, 80, 30, "THICK", 0.8, 100, nil, 40)
    end
end)

Net:on("check_scroll_state", function(event)
    local player_id = event.player_id
    local list_id = event.list_id or "news_feed"
    
    local state = displayer.ScrollingText:getState(player_id, list_id)
    if state then
        displayer.Text:createTextBox(player_id, "scroll_state", 
            "State: " .. state.state .. ", Entries: " .. state.total_entries, 
            150, 100, 80, 30, "THICK", 0.8, 100, nil, 40)
    end
end)

print("Enhanced Displayer example with delayed scrolling list loaded and ready!")