Basic Setup for External Scripts
lua
-- External script using the Displayer API
local Displayer = require("scripts/displayer/displayer")

-- Initialize the system (only need to do this once)
if not Displayer:init() then
    print("Failed to initialize Displayer API")
    return
end

print("Displayer API ready for use!")
Complete Usage Example
Here's a comprehensive example of how external scripts would use your API:

lua
-- External Game Script - Tournament Manager
local Displayer = require("scripts/displayer/displayer")

-- Initialize
if not Displayer:init() then
    print("Failed to initialize Displayer API")
    return
end

local tournament_data = {}

-- Player join handler
Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Quick setup with common UI elements
    Displayer:quickSetup(player_id, {
        show_global_timer = true,
        show_player_timers = true
    })
    
    -- Create tournament-specific displays
    Displayer.Text.drawText(player_id, "TOURNAMENT STATUS", 120, 30, "THICK", 0.8, 100)
    Displayer.Text.drawMarqueeText(player_id, "tournament_news", 
        "Welcome to the Tournament! Round 1 starting soon...", 
        40, "THICK", 1.0, 100, "slow", {
            x = 10, y = 35, width = 220, height = 15,
            padding_x = 8, padding_y = 2
        })
    
    -- Initialize player tournament data
    tournament_data[player_id] = {
        score = 0,
        round = 1,
        matches_played = 0
    }
    
    -- Show welcome message
    Displayer.Text.createTextBox(player_id, "welcome_msg", 
        "Welcome to the Tournament!\n\nRound 1 begins in 30 seconds.\nGet ready to compete!", 
        60, 150, 120, 60, "THICK", 0.9, 100, {
            x = 55, y = 145, width = 130, height = 70,
            padding_x = 8, padding_y = 6
        }, 25)
end)

-- Player disconnect handler
Net:on("player_disconnect", function(event)
    local player_id = event.player_id
    tournament_data[player_id] = nil
end)

-- Tournament commands
Net:on("start_tournament", function(event)
    local player_id = event.player_id
    
    -- Create tournament countdown (30 minutes)
    Displayer.Timer.createGlobalCountdown("tournament_timer", 1800, 
        function(_, countdown_id, value)
            if value <= 0 then
                -- Tournament ended
                Displayer.Text.createTextBox(player_id, "tournament_end", 
                    "Tournament Complete!\n\nThanks for playing!", 
                    60, 150, 120, 50, "THICK", 0.9, 100, nil, 30)
            end
        end, 
        false
    )
    
    -- Create display for tournament timer
    Displayer.TimerDisplay.createGlobalCountdownDisplay("tournament_timer", 120, 20, "large")
    
    Displayer.Text.createTextBox(player_id, "tournament_start", 
        "Tournament Started!\n30 minutes remaining.", 
        60, 80, 120, 40, "THICK", 0.8, 100, nil, 30)
end)

Net:on("update_score", function(event)
    local player_id = event.player_id
    local points = event.points or 1
    
    if tournament_data[player_id] then
        tournament_data[player_id].score = tournament_data[player_id].score + points
        
        -- Update score display
        local score_text = "SCORE: " .. tournament_data[player_id].score
        Displayer.Text.drawText(player_id, score_text, 180, 60, "BATTLE", 1.2, 100)
        
        -- Show points popup
        Displayer.Text.createTextBox(player_id, "points_popup", 
            "+" .. points .. " points!", 
            160, 100, 60, 25, "THICK", 0.8, 100, nil, 40)
    end
end)

Net:on("show_leaderboard", function(event)
    local player_id = event.player_id
    
    -- Create scrolling leaderboard
    local leaderboard_entries = {
        "=== LEADERBOARD ===",
        "1. Player1 - 1500 pts",
        "2. Player2 - 1420 pts", 
        "3. Player3 - 1380 pts",
        "4. You - " .. (tournament_data[player_id] and tournament_data[player_id].score or 0) .. " pts",
        "5. Player5 - 1100 pts",
        "==================="
    }
    
    Displayer.ScrollingText.createList(player_id, "leaderboard", 140, 80, 100, 120, {
        texts = leaderboard_entries,
        scroll_speed = 20,
        entry_delay = 1.5,
        font = "THICK",
        scale = 0.9,
        z_order = 100,
        loop = true,
        backdrop = {
            x = 135, y = 75, width = 110, height = 130,
            padding_x = 8,
            padding_y = 8
        }
    })
end)

Net:on("round_complete", function(event)
    local player_id = event.player_id
    
    if tournament_data[player_id] then
        tournament_data[player_id].round = tournament_data[player_id].round + 1
        tournament_data[player_id].matches_played = 0
        
        -- Show round completion message
        Displayer.Text.createTextBox(player_id, "round_complete", 
            "Round " .. (tournament_data[player_id].round - 1) .. " Complete!\n\nAdvancing to Round " .. tournament_data[player_id].round, 
            60, 150, 120, 50, "THICK", 0.9, 100, {
                x = 55, y = 145, width = 130, height = 60,
                padding_x = 6, padding_y = 6
            }, 30)
            
        -- Update round display
        Displayer.Text.drawText(player_id, "ROUND: " .. tournament_data[player_id].round, 180, 40, "BATTLE", 1.0, 100)
    end
end)

-- Cleanup command
Net:on("cleanup_ui", function(event)
    local player_id = event.player_id
    
    -- Remove specific displays
    Displayer.ScrollingText.removeList(player_id, "leaderboard")
    Displayer.TimerDisplay.removeGlobalDisplay("tournament_timer")
    Displayer.Text.removeText(player_id, "news_ticker")
    
    Displayer.Text.createTextBox(player_id, "cleanup_msg", 
        "UI cleaned up!", 
        60, 180, 80, 25, "THICK", 0.8, 100, nil, 40)
end)

print("Tournament Manager loaded with Displayer API!")
API Reference for External Users
Initialization
lua
local Displayer = require("scripts/displayer/displayer")
Displayer:init()  -- Returns true if successful
Main Sub-APIs Available:
Displayer.Timer - Timer management

lua
Displayer.Timer.createGlobalTimer(timer_id, duration, callback, loop)
Displayer.Timer.createGlobalCountdown(countdown_id, duration, callback, loop)
Displayer.Timer.createPlayerTimer(player_id, timer_id, duration, callback, loop)
Displayer.Timer.createPlayerCountdown(player_id, countdown_id, duration, callback, loop)
Displayer.TimerDisplay - Timer visualization

lua
Displayer.TimerDisplay.createGlobalTimerDisplay(timer_id, x, y, config_name)
Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, timer_id, x, y, config_name)
Displayer.TimerDisplay.updateGlobalTimerDisplay(timer_id, value)
Displayer.Text - Text rendering

lua
Displayer.Text.drawText(player_id, text, x, y, font_name, scale, z_order)
Displayer.Text.drawMarqueeText(player_id, marquee_id, text, y, font_name, scale, z_order, speed, backdrop)
Displayer.Text.createTextBox(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed)
Displayer.Text.updateText(player_id, text_id, new_text)
Displayer.ScrollingText - Scrolling lists

lua
Displayer.ScrollingText.createList(player_id, list_id, x, y, width, height, config)
Displayer.ScrollingText.addText(player_id, list_id, text)
Displayer.ScrollingText.removeList(player_id, list_id)
Displayer.Font - Advanced font operations

lua
Displayer.Font.drawTextWithId(player_id, text, x, y, font_name, scale, z_order, display_id)
Displayer.Font.getTextWidth(text, font_name, scale)
Utility Functions
lua
Displayer:hidePlayerHUD(player_id)
Displayer:getScreenDimensions()  -- Returns width, height
Displayer:formatTime(seconds, is_countdown)  -- Format time for display
Displayer:quickSetup(player_id, options)  -- Quick UI setup
Configuration Options for quickSetup:
lua
Displayer:quickSetup(player_id, {
    show_global_timer = true,      -- Show global timer at top
    show_player_timers = true,     -- Show player-specific timers
    -- Additional options can be added as needed
})
File Structure Expectations
External users would need this file structure:

text
/scripts/
  /displayer/
    displayer.lua          # Main API
    timer-system.lua       # (internal)
    timer-display.lua      # (internal)
    text-display.lua       # (internal)
    font-system.lua        # (internal)
    scrolling-text-list.lua # (internal)
  /their-game/
    their-script.lua       # Their script using the API
Key Benefits for External Users:
Simple Setup - Just require and initialize

Comprehensive - All display functionality in one API

Player Management - Automatically handles player join/leave

Error Handling - Built-in error checking and reporting

Consistent - Same API used internally and externally

Modular - Use only the parts you need

External scripts can now easily create rich UIs with timers, text displays, scrolling lists, and more without needing to understand the internal implementation!