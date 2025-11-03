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
    
    -- Create a simple scrolling list
    displayer.ScrollingList:createList(player_id, "main_menu", {
        "Start Game",
        "Options",
        "Credits",
        "Exit"
    }, 80, 60, 120, 80, "THICK", 1.0, 100, {
        x = 75, y = 55, width = 130, height = 90,
        padding_x = 8, padding_y = 4
    })
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

5. Scrolling List System
The scrolling list system provides flexible, interactive lists for menus, inventories, and selection interfaces. Lists support both vertical and horizontal layouts with smooth scrolling and selection callbacks.

Basic List Creation
lua
-- Simple vertical list
displayer.ScrollingList:createList(player_id, "weapon_select", {
    "Sword",
    "Bow",
    "Staff",
    "Dagger",
    "Axe",
    "Wand"
}, 100, 50, 100, 120, "THICK", 1.0, 100, {
    x = 95, y = 45, width = 110, height = 130,
    padding_x = 6, padding_y = 4
})

-- Horizontal list for quick actions
displayer.ScrollingList:createList(player_id, "quick_actions", {
    "Attack", "Defend", "Item", "Flee"
}, 20, 160, 200, 25, "THICK", 0.9, 100, nil, "horizontal")

-- List with custom selection handler
displayer.ScrollingList:createList(player_id, "game_modes", {
    "Story Mode",
    "Survival",
    "Time Attack",
    "Multiplayer"
}, 60, 80, 140, 80, "BATTLE", 1.0, 100, {
    x = 55, y = 75, width = 150, height = 90,
    padding_x = 8, padding_y = 4
}, "vertical", function(player_id, list_id, selected_index, selected_item)
    print("Player " .. player_id .. " selected: " .. selected_item)
    
    -- Show confirmation or transition to selected mode
    displayer.Text:createTextBox(player_id, "mode_selected",
        "Selected: " .. selected_item, 60, 170, 140, 30, "THICK", 0.9, 100, nil, 30)
end)
Advanced List Features
lua
-- List with custom item formatting
displayer.ScrollingList:createList(player_id, "inventory", {
    "Health Potion x3",
    "Mana Potion x2", 
    "Iron Sword",
    "Leather Armor",
    "Magic Ring",
    "Scroll of Fire"
}, 40, 40, 160, 100, "THICK", 0.9, 100, {
    x = 35, y = 35, width = 170, height = 110,
    padding_x = 6, padding_y = 3
}, "vertical", function(player_id, list_id, index, item)
    -- Use the item
    displayer.Text:createTextBox(player_id, "item_used",
        "Used: " .. item, 40, 150, 160, 25, "THICK", 0.9, 100, nil, 35)
end, {
    visible_items = 4,  -- Show 4 items at once
    scroll_speed = 1,   -- Items to scroll per input
    wrap_around = true  -- Wrap from last to first item
})

-- Dynamic list with item data
local player_abilities = {
    { name = "Fireball", cost = 10, cooldown = 5 },
    { name = "Ice Shard", cost = 8, cooldown = 3 },
    { name = "Lightning", cost = 15, cooldown = 8 },
    { name = "Heal", cost = 12, cooldown = 10 }
}

displayer.ScrollingList:createList(player_id, "abilities", 
    player_abilities, 140, 60, 80, 80, "THICK", 0.8, 100, {
        x = 135, y = 55, width = 90, height = 90,
        padding_x = 4, padding_y = 2
    }, "vertical", function(player_id, list_id, index, ability_data)
        -- Cast the selected ability
        displayer.Text:createTextBox(player_id, "ability_cast",
            "Casting " .. ability_data.name .. "! (" .. ability_data.cost .. " MP)",
            140, 150, 80, 25, "THICK", 0.8, 100, nil, 40)
    end, nil, function(item_data)
        -- Custom formatter for ability items
        return item_data.name .. " (" .. item_data.cost .. " MP)"
    end
)
List Management and Control
lua
-- Update list items dynamically
displayer.ScrollingList:updateListItems(player_id, "inventory", {
    "Health Potion x2",  -- Updated quantity
    "Mana Potion x1",
    "Iron Sword",
    "Steel Armor",      -- Upgraded item
    "Magic Ring",
    "Scroll of Ice"     -- Changed item
})

-- Add single item to list
displayer.ScrollingList:addListItem(player_id, "inventory", "Golden Key")

-- Remove item by index
displayer.ScrollingList:removeListItem(player_id, "inventory", 3) -- Remove 3rd item

-- Get current selection
local selected_index, selected_item = displayer.ScrollingList:getSelection(player_id, "main_menu")

-- Programmatically change selection
displayer.ScrollingList:setSelection(player_id, "weapon_select", 2) -- Select 2nd item

-- Show/hide lists
displayer.ScrollingList:showList(player_id, "main_menu")
displayer.ScrollingList:hideList(player_id, "inventory")

-- Remove list completely
displayer.ScrollingList:removeList(player_id, "quick_actions")
List Styling and Appearance
lua
-- List with custom colors and selection indicator
displayer.ScrollingList:createList(player_id, "settings", {
    "Music: ON",
    "SFX: ON", 
    "Fullscreen: OFF",
    "Difficulty: Normal"
}, 50, 70, 150, 80, "GRADIENT", 1.0, 100, {
    x = 45, y = 65, width = 160, height = 90,
    padding_x = 8, padding_y = 4,
    color = {r = 0, g = 100, b = 200},  -- Blue backdrop
    alpha = 200
}, "vertical", function(player_id, list_id, index, item)
    -- Toggle settings
    local new_items = displayer.ScrollingList:getListItems(player_id, "settings")
    if index == 1 then
        new_items[1] = "Music: " .. (string.find(item, "ON") and "OFF" or "ON")
    elseif index == 2 then
        new_items[2] = "SFX: " .. (string.find(item, "ON") and "OFF" or "ON")
    end
    displayer.ScrollingList:updateListItems(player_id, "settings", new_items)
end, {
    selection_color = {r = 255, g = 255, b = 0},  -- Yellow selection
    selection_alpha = 150,
    selection_indicator = "▶"  -- Custom indicator
})

-- Multi-column list for inventories
displayer.ScrollingList:createList(player_id, "large_inventory", {
    "Sword", "Shield", "Potion", "Key",
    "Armor", "Ring", "Scroll", "Gem",
    "Bow", "Arrow", "Food", "Coin"
}, 20, 40, 200, 120, "THICK", 0.8, 100, {
    x = 15, y = 35, width = 210, height = 130,
    padding_x = 6, padding_y = 4
}, "vertical", function(player_id, list_id, index, item)
    displayer.Text:createTextBox(player_id, "item_info",
        "Selected: " .. item, 60, 170, 120, 25, "THICK", 0.9, 100, nil, 35)
end, {
    columns = 3,        -- 3-column layout
    column_width = 60,  -- Width per column
    visible_rows = 4    -- Show 4 rows at once
})
Advanced Usage Examples
Complete Game UI with Scrolling Lists
lua
local Displayer = require("scripts/displayer/displayer")
local displayer = Displayer:init()

-- Game state
local game_state = {
    current_screen = "main_menu",
    players = {}
}

-- Main menu system
function showMainMenu(player_id)
    displayer.ScrollingList:createList(player_id, "main_menu", {
        "New Game",
        "Load Game",
        "Multiplayer",
        "Options",
        "Credits",
        "Exit"
    }, 80, 60, 120, 120, "BATTLE", 1.2, 100, {
        x = 75, y = 55, width = 130, height = 130,
        padding_x = 8, padding_y = 6
    }, "vertical", function(player_id, list_id, index, item)
        handleMainMenuSelection(player_id, index, item)
    end, {
        selection_color = {r = 255, g = 200, b = 0},
        selection_alpha = 120
    })
    
    -- Title
    displayer.Text:drawText(player_id, "ADVENTURE QUEST", 40, 20, "BATTLE", 1.5, 99)
end

function handleMainMenuSelection(player_id, index, item)
    if index == 1 then -- New Game
        showCharacterSelection(player_id)
    elseif index == 2 then -- Load Game
        showLoadGameMenu(player_id)
    elseif index == 3 then -- Multiplayer
        showMultiplayerMenu(player_id)
    elseif index == 4 then -- Options
        showOptionsMenu(player_id)
    elseif index == 5 then -- Credits
        showCredits(player_id)
    elseif index == 6 then -- Exit
        -- Handle exit
    end
end

function showCharacterSelection(player_id)
    -- Clear main menu
    displayer.ScrollingList:removeList(player_id, "main_menu")
    
    local characters = {
        "Knight - Strong and durable",
        "Archer - Ranged specialist", 
        "Mage - Powerful spells",
        "Rogue - Stealth and speed"
    }
    
    displayer.ScrollingList:createList(player_id, "character_select", characters, 
        30, 50, 180, 100, "THICK", 1.0, 100, {
            x = 25, y = 45, width = 190, height = 110,
            padding_x = 8, padding_y = 4
        }, "vertical", function(player_id, list_id, index, item)
            -- Show character details
            local descriptions = {
                "STR: 15 | DEX: 8 | INT: 5",
                "STR: 7 | DEX: 16 | INT: 9", 
                "STR: 4 | DEX: 10 | INT: 18",
                "STR: 9 | DEX: 17 | INT: 6"
            }
            
            displayer.Text:createTextBox(player_id, "char_details",
                descriptions[index], 30, 160, 180, 40, "THICK", 0.9, 100, {
                    x = 25, y = 155, width = 190, height = 50,
                    padding_x = 6, padding_y = 4
                }, 30)
                
            -- Confirm selection button
            if not displayer.ScrollingList:listExists(player_id, "confirm_select") then
                displayer.ScrollingList:createList(player_id, "confirm_select", 
                    {"Select Character"}, 70, 210, 100, 25, "THICK", 1.0, 100, nil, 
                    "horizontal", function(player_id, list_id, index, item)
                        startGame(player_id, index) -- index is character class
                    end)
            end
        end)
        
    -- Back button
    displayer.ScrollingList:createList(player_id, "back_button", 
        {"Back"}, 10, 210, 50, 25, "THICK", 0.9, 100, nil, 
        "horizontal", function(player_id, list_id, index, item)
            displayer.ScrollingList:removeList(player_id, "character_select")
            displayer.ScrollingList:removeList(player_id, "confirm_select")
            displayer.ScrollingList:removeList(player_id, "back_button")
            displayer.Text:removeTextBox(player_id, "char_details")
            showMainMenu(player_id)
        end)
end

-- Player join with full UI
Net:on("player_join", function(event)
    local player_id = event.player_id
    
    -- Hide default HUD
    displayer:hidePlayerHUD(player_id)
    
    -- Initialize player state
    game_state.players[player_id] = {
        in_game = false,
        current_menu = "main_menu"
    }
    
    -- Show main menu
    showMainMenu(player_id)
end)

-- Input handling for list navigation
Net:on("player_input", function(event)
    local player_id = event.player_id
    local input = event.input
    
    if input == "up" then
        displayer.ScrollingList:navigate(player_id, nil, -1) -- Navigate up
    elseif input == "down" then
        displayer.ScrollingList:navigate(player_id, nil, 1)  -- Navigate down
    elseif input == "action" then
        displayer.ScrollingList:selectCurrent(player_id, nil) -- Select current item
    elseif input == "back" then
        -- Handle back navigation based on current screen
        handleBackButton(player_id)
    end
end)
Dynamic Inventory System
lua
-- Advanced inventory with categories and filtering
function createInventorySystem(player_id)
    local inventory = {
        weapons = {
            "Iron Sword",
            "Steel Axe", 
            "Magic Staff",
            "Long Bow"
        },
        armor = {
            "Leather Helm",
            "Chainmail Chest",
            "Plate Leggings",
            "Magic Robe"
        },
        consumables = {
            "Health Potion x5",
            "Mana Potion x3",
            "Antidote x2",
            "Strength Elixir"
        },
        quest_items = {
            "Ancient Key",
            "Dragon Scale",
            "Mysterious Map"
        }
    }
    
    local current_category = "weapons"
    
    function showInventoryCategories()
        displayer.ScrollingList:createList(player_id, "inv_categories", {
            "Weapons",
            "Armor",
            "Consumables", 
            "Quest Items"
        }, 20, 40, 80, 100, "THICK", 1.0, 100, {
            x = 15, y = 35, width = 90, height = 110,
            padding_x = 6, padding_y = 4
        }, "vertical", function(player_id, list_id, index, item)
            local categories = {"weapons", "armor", "consumables", "quest_items"}
            current_category = categories[index]
            showInventoryItems(current_category)
        end, {
            selection_color = {r = 0, g = 150, b = 255}
        })
    end
    
    function showInventoryItems(category)
        -- Remove existing items list if any
        if displayer.ScrollingList:listExists(player_id, "inv_items") then
            displayer.ScrollingList:removeList(player_id, "inv_items")
        end
        
        local items = inventory[category] or {}
        displayer.ScrollingList:createList(player_id, "inv_items", items,
            110, 40, 120, 100, "THICK", 0.9, 100, {
                x = 105, y = 35, width = 130, height = 110,
                padding_x = 6, padding_y = 4
            }, "vertical", function(player_id, list_id, index, item)
                showItemDetails(category, index, item)
            end)
            
        -- Item actions
        displayer.ScrollingList:createList(player_id, "item_actions", {
            "Use", "Equip", "Drop", "Info"
        }, 110, 150, 120, 25, "THICK", 0.8, 100, nil, "horizontal",
        function(player_id, list_id, index, action)
            local selected_index = displayer.ScrollingList:getSelection(player_id, "inv_items")
            if selected_index then
                local selected_item = inventory[current_category][selected_index]
                handleItemAction(action, selected_item, selected_index)
            end
        end)
    end
    
    function showItemDetails(category, index, item)
        local details = "Item: " .. item .. "\nCategory: " .. category
        displayer.Text:createTextBox(player_id, "item_details",
            details, 20, 150, 80, 50, "THICK", 0.8, 100, {
                x = 15, y = 145, width = 90, height = 60,
                padding_x = 4, padding_y = 3
            }, 40)
    end
    
    function handleItemAction(action, item, index)
        if action == "Use" then
            useItem(item, index)
        elseif action == "Equip" then
            equipItem(item)
        elseif action == "Drop" then
            dropItem(item, index)
        elseif action == "Info" then
            showItemInfo(item)
        end
    end
    
    function useItem(item, index)
        displayer.Text:createTextBox(player_id, "action_feedback",
            "Used: " .. item, 80, 180, 80, 25, "THICK", 0.9, 100, nil, 35)
        
        -- Remove from inventory if consumable
        if string.find(item, "Potion") or string.find(item, "Elixir") then
            table.remove(inventory[current_category], index)
            showInventoryItems(current_category)
        end
    end
    
    -- Initialize inventory
    showInventoryCategories()
end

-- Usage in game
Net:on("player_join", function(event)
    local player_id = event.player_id
    createInventorySystem(player_id)
end)
Interactive Dialogue System with Choices
lua
function createDialogueSystem(player_id)
    local dialogue_tree = {
        {
            speaker = "Guard",
            message = "Halt! Who goes there?",
            choices = {
                { text = "I'm a friendly traveler", next = 1 },
                { text = "None of your business!", next = 2 },
                { text = "I seek the ancient treasure", next = 3 }
            }
        },
        {
            speaker = "Guard", 
            message = "Well met, traveler. You may pass.",
            choices = {
                { text = "Thank you, I'll be on my way", next = 4 },
                { text = "Actually, I need directions", next = 5 }
            }
        },
        {
            speaker = "Guard",
            message = "That's no way to speak to the city guard! Move along!",
            choices = {
                { text = "Sorry, I didn't mean it", next = 1 },
                { text = "Make me!", next = 6 }
            }
        }
        -- ... more dialogue nodes
    }
    
    local current_node = 1
    
    function showDialogue(node_index)
        local node = dialogue_tree[node_index]
        if not node then return end
        
        -- Display speaker and message
        displayer.Text:createTextBox(player_id, "dialogue_speaker",
            node.speaker, 20, 40, 200, 20, "BATTLE", 1.1, 100, nil, 30)
            
        displayer.Text:createTextBox(player_id, "dialogue_message",
            node.message, 20, 65, 200, 50, "THICK", 1.0, 100, {
                x = 15, y = 60, width = 210, height = 60,
                padding_x = 8, padding_y = 6
            }, 25)
        
        -- Display choices as scrolling list
        local choice_texts = {}
        for i, choice in ipairs(node.choices) do
            table.insert(choice_texts, choice.text)
        end
        
        displayer.ScrollingList:createList(player_id, "dialogue_choices", 
            choice_texts, 20, 120, 200, 60, "THICK", 0.9, 100, {
                x = 15, y = 115, width = 210, height = 70,
                padding_x = 8, padding_y = 4
            }, "vertical", function(player_id, list_id, index, choice)
                local next_node = node.choices[index].next
                displayer.ScrollingList:removeList(player_id, "dialogue_choices")
                displayer.Text:removeTextBox(player_id, "dialogue_speaker")
                displayer.Text:removeTextBox(player_id, "dialogue_message")
                showDialogue(next_node)
            end, {
                selection_color = {r = 255, g = 255, b = 100},
                selection_alpha = 180
            })
    end
    
    -- Start the dialogue
    showDialogue(current_node)
end
Best Practices for Scrolling Lists
1. Memory Management with Lists
lua
-- Clean up lists on player disconnect
Net:on("player_disconnect", function(event)
    local player_id = event.player_id
    
    -- Remove all player lists
    displayer.ScrollingList:removeAllPlayerLists(player_id)
    
    -- Alternative: Remove specific lists
    local lists_to_remove = {"main_menu", "inventory", "dialogue_choices"}
    for _, list_id in ipairs(lists_to_remove) do
        if displayer.ScrollingList:listExists(player_id, list_id) then
            displayer.ScrollingList:removeList(player_id, list_id)
        end
    end
end)
2. Performance Optimization
lua
-- Batch list updates
Net:on("tick", function(event)
    local delta = event.delta_time or 0
    
    -- Only update visible lists
    for player_id, player_data in pairs(game_state.players) do
        if player_data.inventory_open then
            -- Update inventory list if items changed
            if player_data.inventory_dirty then
                updateInventoryList(player_id)
                player_data.inventory_dirty = false
            end
        end
    end
end)

-- Use list visibility toggling instead of create/remove for frequently used lists
function toggleInventory(player_id)
    local player_data = game_state.players[player_id]
    if displayer.ScrollingList:listExists(player_id, "inventory") then
        if displayer.ScrollingList:isListVisible(player_id, "inventory") then
            displayer.ScrollingList:hideList(player_id, "inventory")
        else
            displayer.ScrollingList:showList(player_id, "inventory")
        end
    else
        createInventorySystem(player_id)
    end
end
3. Error Prevention with Lists
lua
-- Safe list operations
function safeListCreate(player_id, list_id, items, x, y, width, height, font, scale, z, backdrop, layout, callback, config, formatter)
    local success, result = pcall(function()
        return displayer.ScrollingList:createList(player_id, list_id, items, x, y, width, height, font, scale, z, backdrop, layout, callback, config, formatter)
    end)
    
    if not success then
        print("Error creating list " .. list_id .. ": " .. tostring(result))
        return false
    end
    return true
end

-- Check list existence before operations
function updatePlayerList(player_id, list_id, new_items)
    if displayer.ScrollingList:listExists(player_id, list_id) then
        displayer.ScrollingList:updateListItems(player_id, list_id, new_items)
    else
        print("List " .. list_id .. " doesn't exist for player " .. player_id)
    end
end
Common Patterns with Scrolling Lists
1. State-Driven Menu System
lua
function updateMenuSystem(player_id, game_state)
    -- Clear existing menus
    displayer.ScrollingList:removeAllPlayerLists(player_id)
    
    if game_state.menu == "main" then
        showMainMenu(player_id)
    elseif game_state.menu == "pause" then
        showPauseMenu(player_id)
    elseif game_state.menu == "inventory" then
        showInventoryMenu(player_id)
    elseif game_state.menu == "settings" then
        showSettingsMenu(player_id)
    end
end

function showPauseMenu(player_id)
    displayer.ScrollingList:createList(player_id, "pause_menu", {
        "Resume Game",
        "Save Game",
        "Load Game",
        "Options",
        "Exit to Menu",
        "Quit Game"
    }, 80, 60, 120, 120, "THICK", 1.0, 100, {
        x = 75, y = 55, width = 130, height = 130,
        padding_x = 8, padding_y = 6
    }, "vertical", function(player_id, list_id, index, item)
        if index == 1 then
            resumeGame(player_id)
        elseif index == 2 then
            saveGame(player_id)
        elseif index == 6 then
            quitGame(player_id)
        end
    end)
end
2. Progressive List Complexity
lua
-- Simple list for early game
function showBasicInventory(player_id)
    displayer.ScrollingList:createList(player_id, "basic_inv", {
        "Sword",
        "Potion",
        "Key"
    }, 100, 80, 80, 60, "THICK", 1.0, 100, nil, "vertical",
    function(player_id, list_id, index, item)
        useBasicItem(player_id, item)
    end)
end

-- Advanced list for later game
function showAdvancedInventory(player_id)
    local categorized_items = {
        "Weapons (5)",
        "Armor (3)",
        "Consumables (8)", 
        "Materials (12)",
        "Keys (2)",
        "Quest Items (4)"
    }
    
    displayer.ScrollingList:createList(player_id, "advanced_inv", 
        categorized_items, 40, 50, 160, 120, "THICK", 0.9, 100, {
            x = 35, y = 45, width = 170, height = 130,
            padding_x = 6, padding_y = 4
        }, "vertical", function(player_id, list_id, index, category)
            showCategoryItems(player_id, category)
        end, {
            columns = 2,
            visible_items = 6
        })
end
Conclusion
The Displayer API now provides a comprehensive foundation for building rich, interactive UI systems with the addition of the powerful Scrolling List system. This new capability enables:

Dynamic Menus: Create complex menu systems with nested navigation

Interactive Inventories: Build sophisticated inventory management interfaces

Dialogue Systems: Implement branching dialogue trees with player choices

Data Display: Present large datasets in scrollable, selectable formats

Key Strengths Enhanced:
Unified API: Single interface for all display needs including lists

Extensible Architecture: Easy to create custom list types and behaviors

Production Ready: Robust error handling and memory management for lists

Performance Focused: Efficient list rendering and update mechanisms

Developer Friendly: Intuitive list creation and management patterns

The Scrolling List system integrates seamlessly with existing timer, text, and font systems, providing a complete UI toolkit for virtually any game interface requirement.

Conclusion
The Displayer API provides a comprehensive foundation for building rich, interactive UI systems. Its modular design allows for both simple implementations and complex, custom extensions. Whether you're building a simple timer display or a full-featured game UI with tutorials, notifications, and interactive elements, the Displayer API provides the tools you need with robust error handling and performance optimization.

Key strengths:

Unified API: Single interface for all display needs

Extensible Architecture: Easy to add new display types and features

Production Ready: Comprehensive error handling and memory management

Performance Focused: Efficient updates and resource management

Developer Friendly: Clear documentation and consistent patterns

This system can serve as the foundation for virtually any UI requirement in your game, from simple HUD elements to complex interactive systems.

