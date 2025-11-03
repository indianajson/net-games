Displayer API - Comprehensive Documentation
Overview
The Displayer API is a powerful, unified system for creating rich UI elements in your game. It provides a complete suite of tools for displaying timers, text, and interactive UI elements with a consistent, professional appearance. Built with modularity and ease of use in mind, it handles everything from simple text displays to complex, timed UI sequences.

High-Level Features
🎯 Core Capabilities
Multiple Timer Types: Global timers, player-specific timers, countdowns, and looping timers

Rich Text Display: Static text, scrolling marquees, and typewriter-style text boxes

Flexible Positioning: Pixel-perfect positioning with automatic layout management

Visual Consistency: Built-in font system with multiple font styles and sizes

Backdrop System: Automatic background panels with customizable padding

🛡️ Robust Architecture
Error Handling: Comprehensive nil checks and safe defaults

Memory Management: Automatic cleanup on player disconnect

Performance Optimized: Efficient update cycles and sprite management

Modular Design: Independent systems that work seamlessly together

🎨 Visual Features
Multiple Font Styles: THICK, GRADIENT, and BATTLE fonts with consistent spacing

Text Effects: Typewriter effect, word wrapping, pagination, and smooth scrolling

UI Layout Tools: Non-overlapping element positioning and backdrop constraints

Z-Order Management: Proper layering of UI elements

Quick Start Guide
Basic Setup
lua
-- Initialize the API
local Displayer = require("scripts/displayer/displayer")
local displayer = Displayer:init()

-- Simple player setup
Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Hide default HUD and set up basic UI
    displayer:hidePlayerHUD(player_id)
    
    -- Create a simple timer display
    displayer.TimerDisplay:createPlayerTimerDisplay(player_id, "play_time", 120, 80, "default")
    
    -- Show welcome message
    displayer.Text:createTextBox(player_id, "welcome", 
        "Welcome to the game! Enjoy your adventure.", 
        20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
end)
Core Systems Deep Dive
1. Timer System
The timer system provides both global (server-wide) and player-specific timers with callbacks and automatic updates.

Global Timers
lua
-- Create a global session timer that counts up
displayer.Timer:createGlobalTimer("session_timer", 0, function(timer_id, elapsed)
    -- This callback runs every time the timer updates
    print("Session running for: " .. elapsed .. " seconds")
end, true) -- true = loop forever

-- Create a global countdown for game events
displayer.Timer:createGlobalCountdown("game_start", 60, function(timer_id, remaining)
    if remaining <= 0 then
        print("Game starting!")
    elseif remaining == 30 then
        print("30 seconds remaining!")
    end
end)

-- Control global timers
displayer.Timer:pauseGlobalTimer("session_timer")
displayer.Timer:resumeGlobalTimer("session_timer")
displayer.Timer:removeGlobalTimer("session_timer")
Player-Specific Timers
lua
Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Player ability cooldown
    displayer.Timer:createPlayerCountdown(player_id, "ability_cooldown", 5, 
        function(p_id, timer_id, remaining)
            if remaining <= 0 then
                displayer.Text:createTextBox(p_id, "ability_ready", 
                    "Ability ready!", 50, 80, 140, 40, "THICK", 1.0, 100, nil, 40)
            end
        end)
    
    -- Player respawn timer
    displayer.Timer:createPlayerCountdown(player_id, "respawn_timer", 10,
        function(p_id, timer_id, remaining)
            if remaining <= 0 then
                -- Respawn player logic here
            end
        end)
end)
2. Timer Display System
Visual representation of timers with multiple display styles and configurations.

Display Configurations
lua
-- Available styles: "default", "large", "gradient", "small"

-- Player timer displays
displayer.TimerDisplay:createPlayerTimerDisplay(player_id, "play_time", 120, 80, "default")
displayer.TimerDisplay:createPlayerCountdownDisplay(player_id, "ability_cd", 120, 100, "small")

-- Global timer displays (visible to all players)
displayer.TimerDisplay:createGlobalTimerDisplay("session_timer", 10, 10, "large")
displayer.TimerDisplay:createGlobalCountdownDisplay("event_start", 10, 30, "gradient")

-- Update timer values (usually in tick event)
displayer.TimerDisplay:updatePlayerTimerDisplay(player_id, "play_time", current_time)
displayer.TimerDisplay:updateGlobalTimerDisplay("session_timer", session_time)
3. Text Display System
Comprehensive text rendering with multiple display modes and effects.

Static Text
lua
-- Simple static text
local text_id = displayer.Text:drawText(player_id, "SCORE: 1000", 180, 10, "BATTLE", 1.2, 100)

-- Add backdrop for better visibility
displayer.Text:addBackdrop(player_id, text_id, {
    x = 175, y = 5, width = 60, height = 20,
    padding_x = 4, padding_y = 2
})

-- Update text dynamically
displayer.Text:updateText(player_id, text_id, "SCORE: 1500")

-- Move text
displayer.Text:setTextPosition(player_id, text_id, 200, 15)
Marquee Text (Scrolling)
lua
-- Simple marquee without backdrop
displayer.Text:drawMarqueeText(player_id, "news", 
    "Breaking news: New update available!", 
    30, "THICK", 1.0, 100, "medium")

-- Marquee with backdrop (text constrained to backdrop area)
displayer.Text:drawMarqueeText(player_id, "news_ticker", 
    "Welcome to the game! This text scrolls within the defined boundaries.",
    30, "THICK", 1.0, 100, "slow", {
        x = 10, y = 25, width = 220, height = 15,
        padding_x = 8, padding_y = 2
    })

-- Control marquee speed
displayer.Text:setMarqueeSpeed(player_id, "news_ticker", "fast")
Text Boxes (MegaMan Battle Network Style)
lua
-- Basic text box with typewriter effect
displayer.Text:createTextBox(player_id, "dialogue",
    "Hello, operator! Welcome to the digital world. Your mission begins now.",
    20, 140, 200, 50, "THICK", 1.0, 100, {
        x = 15, y = 135, width = 210, height = 60,
        padding_x = 8, padding_y = 6
    }, 25) -- 25 characters per second

-- Multi-page story
local story_text = "In the year 210X, cyber space has become our reality. " ..
                  "As a net operator, you've been chosen to defend the digital frontier. " ..
                  "Your mission: survive the endless waves of viral enemies and corrupted data. " ..
                  "Use your abilities wisely and remember: timing is everything!"

displayer.Text:createTextBox(player_id, "story", story_text,
    20, 50, 200, 80, "THICK", 1.0, 100, {
        x = 15, y = 45, width = 210, height = 90,
        padding_x = 8, padding_y = 6
    }, 20)

-- Control text boxes
displayer.Text:advanceTextBox(player_id, "dialogue") -- Skip to next page/complete
local completed = displayer.Text:isTextBoxCompleted(player_id, "story")
displayer.Text:removeTextBox(player_id, "dialogue")
4. Font System
Advanced font rendering with consistent character spacing and multiple styles.

lua
-- Direct font usage (for advanced scenarios)
local text_id = displayer.Font:drawText(player_id, "Custom Text", 50, 50, "BATTLE", 1.5, 100)

-- Get text width for layout calculations
local width = displayer.Font:getTextWidth("Hello World", "THICK", 1.0)

-- Clean up
displayer.Font:eraseTextDisplay(player_id, text_id)
Advanced Usage Examples
Complete Game UI Setup
lua
local Displayer = require("scripts/displayer/displayer")
local displayer = Displayer:init()

-- Game state
local game_state = {
    session_started = false,
    players_ready = {},
    game_phase = "lobby"
}

-- Global game timer
displayer.Timer:createGlobalTimer("game_session", 0, nil, true)
displayer.TimerDisplay:createGlobalTimerDisplay("game_session", 10, 10, "large")

-- Player join with comprehensive UI
Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Hide default HUD
    displayer:hidePlayerHUD(player_id)
    
    -- UI Layout
    -- Top: Global info (timer, news)
    -- Left: Player status (timers, stats)
    -- Right: Game events (notifications, messages)
    -- Bottom: Story/dialogue
    
    -- Global elements
    displayer.Text:drawMarqueeText(player_id, "news", 
        "Tournament Arena - New challenger approaching!", 
        30, "THICK", 1.0, 100, "slow", {
            x = 10, y = 25, width = 220, height = 15,
            padding_x = 8, padding_y = 2
        })
    
    -- Player status (left side)
    displayer.TimerDisplay:createPlayerTimerDisplay(player_id, "play_time", 10, 80, "default")
    displayer.TimerDisplay:createPlayerCountdownDisplay(player_id, "respawn", 10, 100, "small")
    displayer.TimerDisplay:createPlayerCountdownDisplay(player_id, "ability_1", 10, 120, "gradient")
    
    displayer.Text:drawText(player_id, "PLAY TIME", 12, 65, "THICK", 0.8, 100)
    displayer.Text:drawText(player_id, "RESPAWN", 12, 85, "THICK", 0.8, 100)
    displayer.Text:drawText(player_id, "ABILITY", 12, 105, "THICK", 0.8, 100)
    
    -- Welcome message (bottom)
    displayer.Text:createTextBox(player_id, "welcome",
        "Welcome to the Tournament Arena! Prepare for battle against other net operators. " ..
        "Use your abilities wisely and watch your timers. Good luck!",
        20, 140, 200, 50, "THICK", 1.0, 100, {
            x = 15, y = 135, width = 210, height = 60,
            padding_x = 8, padding_y = 6
        }, 25)
    
    -- Start player timers after brief delay
    game_state.players_ready[player_id] = {
        join_time = os.clock(),
        play_time = 0,
        waiting_for_start = true
    }
end)

-- Game event system
Net:on("player_used_ability", function(event)
    local player_id = event.player_id
    local ability = event.ability
    
    -- Show ability notification
    displayer.Text:createTextBox(player_id, "ability_used",
        ability .. " activated! Cooldown started.",
        150, 80, 80, 30, "THICK", 0.9, 100, {
            x = 145, y = 75, width = 90, height = 40,
            padding_x = 4, padding_y = 4
        }, 40)
    
    -- Start cooldown timer
    displayer.Timer:createPlayerCountdown(player_id, ability .. "_cooldown", 5,
        function(p_id, timer_id, remaining)
            if remaining <= 0 then
                displayer.Text:createTextBox(p_id, "ability_ready",
                    ability .. " ready!", 150, 120, 80, 30, "THICK", 0.9, 100, nil, 40)
            end
        end)
end)

-- Real-time updates
Net:on("tick", function(event)
    local delta = event.delta_time or 0
    
    -- Update global session timer
    if game_state.session_started then
        game_state.session_time = (game_state.session_time or 0) + delta
        displayer.TimerDisplay:updateGlobalTimerDisplay("game_session", game_state.session_time)
    end
    
    -- Update player timers and handle delayed starts
    for player_id, data in pairs(game_state.players_ready) do
        if data.waiting_for_start and os.clock() - data.join_time >= 3.0 then
            data.waiting_for_start = false
            data.play_time = 0
            displayer.Text:createTextBox(player_id, "game_start",
                "Mission started! Defeat enemies and survive!", 
                150, 60, 80, 40, "THICK", 0.9, 100, nil, 35)
        end
        
        if not data.waiting_for_start then
            data.play_time = data.play_time + delta
            displayer.TimerDisplay:updatePlayerTimerDisplay(player_id, "play_time", data.play_time)
        end
    end
end)
Interactive Tutorial System
lua
-- Advanced tutorial system using text boxes and timers
function createTutorialSystem(player_id)
    local tutorial = {
        current_step = 1,
        steps = {
            {
                message = "Welcome to the training simulation. Use WASD to move around.",
                duration = 5,
                callback = function() 
                    displayer.Text:createTextBox(player_id, "tutorial_move", 
                        "Great! Now try moving to the marked area.", 
                        20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
                end
            },
            {
                message = "Press SPACE to jump over obstacles.",
                duration = 5,
                callback = function()
                    displayer.Text:createTextBox(player_id, "tutorial_jump",
                        "Excellent! Jumping will help you avoid enemies.",
                        20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
                end
            },
            {
                message = "Click to use your basic attack. Aim with the mouse!",
                duration = 6,
                callback = function()
                    displayer.Text:createTextBox(player_id, "tutorial_attack",
                        "Perfect! Combat is essential for survival.",
                        20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
                end
            }
        }
    }
    
    function showNextTutorialStep()
        if tutorial.current_step <= #tutorial.steps then
            local step = tutorial.steps[tutorial.current_step]
            
            -- Show tutorial message
            displayer.Text:createTextBox(player_id, "tutorial_step", 
                step.message, 20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
            
            -- Set up automatic advancement
            displayer.Timer:createPlayerTimer(player_id, "tutorial_advance", step.duration,
                function(p_id, timer_id, elapsed)
                    if step.callback then
                        step.callback()
                    end
                    tutorial.current_step = tutorial.current_step + 1
                    showNextTutorialStep()
                end)
                
            tutorial.current_step = tutorial.current_step + 1
        else
            -- Tutorial complete
            displayer.Text:createTextBox(player_id, "tutorial_complete",
                "Tutorial complete! You're ready for the real battle. Good luck!",
                20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
        end
    end
    
    -- Start the tutorial
    showNextTutorialStep()
end
Extending the API
Creating Custom Display Types
lua
-- Example: Health bar system built on top of Displayer API
local HealthBar = {}
HealthBar.__index = HealthBar

function HealthBar:init()
    self.displayers = {}
    return self
end

function HealthBar:createHealthBar(player_id, bar_id, x, y, width, height, max_health)
    local displayer = require("scripts/displayer/displayer")
    
    -- Create backdrop for health bar
    displayer.Text:drawText(player_id, "", x, y, "THICK", 1.0, 100)
    displayer.Text:addBackdrop(player_id, bar_id .. "_bg", {
        x = x, y = y, width = width, height = height,
        padding_x = 2, padding_y = 2
    })
    
    -- Store health bar data
    self.displayers[player_id] = self.displayers[player_id] or {}
    self.displayers[player_id][bar_id] = {
        x = x, y = y, width = width, height = height,
        max_health = max_health, current_health = max_health
    }
    
    self:updateHealthBar(player_id, bar_id, max_health)
end

function HealthBar:updateHealthBar(player_id, bar_id, current_health)
    local bar_data = self.displayers[player_id] and self.displayers[player_id][bar_id]
    if not bar_data then return end
    
    bar_data.current_health = current_health
    local health_percent = current_health / bar_data.max_health
    local bar_width = math.floor(bar_data.width * health_percent)
    
    -- Update health bar display (using backdrop as visual element)
    -- Implementation depends on specific visual requirements
end

local healthBarSystem = setmetatable({}, HealthBar)
healthBarSystem:init()
Adding New Font Styles
lua
-- Extend the font system by modifying font-system.lua
-- Add new font entries to the font_sprites table:

self.font_sprites = {
    THICK = { ... }, -- Existing
    GRADIENT = { ... }, -- Existing  
    BATTLE = { ... }, -- Existing
    CUSTOM = {
        texture_path = "/server/assets/custom/font.png",
        anim_path = "/server/assets/custom/font.animation",
        anim_state = "CUSTOM_0"
    }
}

-- Add character width data:
self.char_widths.CUSTOM = {
    ["A"] = 7, ["B"] = 7, -- Define all character widths
    -- ... etc
}
Best Practices
1. Memory Management
lua
-- Always clean up on player disconnect
Net:on("player_disconnect", function(event)
    local player_id = event.player_id
    -- Remove all player-specific displays
    for timer_id, _ in pairs(player_timers[player_id] or {}) do
        displayer.TimerDisplay:removePlayerDisplay(player_id, timer_id)
    end
    player_timers[player_id] = nil
end)
2. Performance Optimization
lua
-- Batch updates in tick event
Net:on("tick", function(event)
    local delta = event.delta_time or 0
    
    -- Update only what's necessary
    if game_state.needs_update then
        for player_id, data in pairs(player_data) do
            if data.visible then
                displayer.TimerDisplay:updatePlayerTimerDisplay(player_id, "timer", data.value)
            end
        end
        game_state.needs_update = false
    end
end)
3. Error Prevention
lua
-- Use the built-in error handling
local success, result = pcall(function()
    return displayer.Text:createTextBox(player_id, "msg", text, x, y, w, h, font, scale, z, backdrop, speed)
end)

if not success then
    print("Error creating text box: " .. tostring(result))
end
Common Patterns
1. State-Driven UI
lua
function updatePlayerUI(player_id, game_state)
    -- Show different UI based on game state
    if game_state == "lobby" then
        displayer.Text:createTextBox(player_id, "status", "Waiting for players...", 20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
    elseif game_state == "playing" then
        displayer.Text:createTextBox(player_id, "status", "Mission in progress!", 20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
    elseif game_state == "completed" then
        displayer.Text:createTextBox(player_id, "status", "Mission complete!", 20, 140, 200, 50, "THICK", 1.0, 100, nil, 25)
    end
end
2. Progressive Disclosure
lua
-- Show information progressively as players need it
function showHint(player_id, hint_type)
    local hints = {
        movement = "Tip: Use WASD to move around the arena",
        combat = "Tip: Click to attack, aim with mouse",
        abilities = "Tip: Press 1-4 to use special abilities",
        objectives = "Tip: Complete objectives to earn points"
    }
    
    if hints[hint_type] and not shown_hints[player_id][hint_type] then
        displayer.Text:createTextBox(player_id, "hint_" .. hint_type, 
            hints[hint_type], 150, 160, 80, 30, "THICK", 0.8, 100, nil, 35)
        shown_hints[player_id][hint_type] = true
    end
end
Conclusion
The Displayer API provides a comprehensive foundation for building rich, interactive UI systems. Its modular design allows for both simple implementations and complex, custom extensions. Whether you're building a simple timer display or a full-featured game UI with tutorials, notifications, and interactive elements, the Displayer API provides the tools you need with robust error handling and performance optimization.

Key strengths:

Unified API: Single interface for all display needs

Extensible Architecture: Easy to add new display types and features

Production Ready: Comprehensive error handling and memory management

Performance Focused: Efficient updates and resource management

Developer Friendly: Clear documentation and consistent patterns

This system can serve as the foundation for virtually any UI requirement in your game, from simple HUD elements to complex interactive systems.

