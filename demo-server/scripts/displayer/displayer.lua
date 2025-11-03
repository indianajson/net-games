-- Displayer API - Unified Interface for Timer and Text Display Systems
-- Version 1.1 - With Comprehensive Nil Checks
-- Usage: local Displayer = require("scripts/displayer/displayer")

local Displayer = {}
Displayer.__index = Displayer

-- Internal subsystem references
local TimerSystem = nil
local TimerDisplaySystem = nil
local TextDisplaySystem = nil
local FontSystem = nil
function Displayer:init()
    -- Load all subsystems with error handling
    local success, err = pcall(function()
        TimerSystem = require("scripts/displayer/timer-system")
        TimerDisplaySystem = require("scripts/displayer/timer-display")
        TextDisplaySystem = require("scripts/displayer/text-display")
        FontSystem = require("scripts/displayer/font-system")
        ScrollingTextListSystem = require("scripts/displayer/scrolling-text-list") -- ADD THIS LINE
        
        -- Initialize subsystems
        if TimerSystem and TimerSystem.init then TimerSystem:init() end
        if TimerDisplaySystem and TimerDisplaySystem.init then TimerDisplaySystem:init() end
        if TextDisplaySystem and TextDisplaySystem.init then TextDisplaySystem:init() end
        if FontSystem and FontSystem.init then FontSystem:init() end
        if ScrollingTextListSystem and ScrollingTextListSystem.init then ScrollingTextListSystem:init() end -- ADD THIS LINE
    end)

    if not success then
        print("Error initializing Displayer API: " .. tostring(err))
        return nil
    end
    
    print("Displayer API initialized successfully!")
    return self
end

-- Timer System API
Displayer.Timer = {}

-- Global Timers
function Displayer.Timer:createGlobalTimer(timer_id, duration, callback, loop)
    if not TimerSystem or not TimerSystem.createGlobalTimer then return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    duration = duration or 0
    return TimerSystem:createGlobalTimer(timer_id, duration, callback, loop or false)
end

function Displayer.Timer:createGlobalCountdown(countdown_id, duration, callback, loop)
    if not TimerSystem or not TimerSystem.createGlobalCountdown then return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    duration = duration or 0
    return TimerSystem:createGlobalCountdown(countdown_id, duration, callback, loop or false)
end

function Displayer.Timer:pauseGlobalTimer(timer_id)
    if not TimerSystem or not TimerSystem.pauseGlobalTimer then return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    return TimerSystem:pauseGlobalTimer(timer_id)
end

function Displayer.Timer:resumeGlobalTimer(timer_id)
    if not TimerSystem or not TimerSystem.resumeGlobalTimer then return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    return TimerSystem:resumeGlobalTimer(timer_id)
end

function Displayer.Timer:pauseGlobalCountdown(countdown_id)
    if not TimerSystem or not TimerSystem.pauseGlobalCountdown then return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    return TimerSystem:pauseGlobalCountdown(countdown_id)
end

function Displayer.Timer:resumeGlobalCountdown(countdown_id)
    if not TimerSystem or not TimerSystem.resumeGlobalCountdown then return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    return TimerSystem:resumeGlobalCountdown(countdown_id)
end

function Displayer.Timer:removeGlobalTimer(timer_id)
    if not TimerSystem or not TimerSystem.removeGlobalTimer then return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    return TimerSystem:removeGlobalTimer(timer_id)
end

function Displayer.Timer:removeGlobalCountdown(countdown_id)
    if not TimerSystem or not TimerSystem.removeGlobalCountdown then return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    return TimerSystem:removeGlobalCountdown(countdown_id)
end

function Displayer.Timer:getGlobalTimer(timer_id)
    if not TimerSystem or not TimerSystem.getGlobalTimer then return 0 end
    if not timer_id then print("Error: timer_id is required") return 0 end
    return TimerSystem:getGlobalTimer(timer_id) or 0
end

function Displayer.Timer:getGlobalCountdown(countdown_id)
    if not TimerSystem or not TimerSystem.getGlobalCountdown then return 0 end
    if not countdown_id then print("Error: countdown_id is required") return 0 end
    return TimerSystem:getGlobalCountdown(countdown_id) or 0
end

function Displayer.Timer:getAllGlobalTimers()
    if not TimerSystem or not TimerSystem.getAllGlobalTimers then return {} end
    return TimerSystem:getAllGlobalTimers() or {}
end

function Displayer.Timer:getAllGlobalCountdowns()
    if not TimerSystem or not TimerSystem.getAllGlobalCountdowns then return {} end
    return TimerSystem:getAllGlobalCountdowns() or {}
end

function Displayer.Timer:clearAllGlobalTimers()
    if not TimerSystem or not TimerSystem.clearAllGlobalTimers then return nil end
    return TimerSystem:clearAllGlobalTimers()
end

function Displayer.Timer:clearAllGlobalCountdowns()
    if not TimerSystem or not TimerSystem.clearAllGlobalCountdowns then return nil end
    return TimerSystem:clearAllGlobalCountdowns()
end

-- Player Timers
function Displayer.Timer:createPlayerTimer(player_id, timer_id, duration, callback, loop)
    if not TimerSystem or not TimerSystem.createPlayerTimer then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    duration = duration or 0
    return TimerSystem:createPlayerTimer(player_id, timer_id, duration, callback, loop or false)
end

function Displayer.Timer:createPlayerCountdown(player_id, countdown_id, duration, callback, loop)
    if not TimerSystem or not TimerSystem.createPlayerCountdown then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    duration = duration or 0
    return TimerSystem:createPlayerCountdown(player_id, countdown_id, duration, callback, loop or false)
end

-- Timer Display API
Displayer.TimerDisplay = {}

-- Player Timer Displays
function Displayer.TimerDisplay:createPlayerTimerDisplay(player_id, timer_id, x, y, config_name)
    if not TimerDisplaySystem or not TimerDisplaySystem.createPlayerTimerDisplay then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    x = x or 0
    y = y or 0
    return TimerDisplaySystem:createPlayerTimerDisplay(player_id, timer_id, x, y, config_name or "default")
end

function Displayer.TimerDisplay:createPlayerCountdownDisplay(player_id, countdown_id, x, y, config_name)
    if not TimerDisplaySystem or not TimerDisplaySystem.createPlayerCountdownDisplay then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    x = x or 0
    y = y or 0
    return TimerDisplaySystem:createPlayerCountdownDisplay(player_id, countdown_id, x, y, config_name or "default")
end

function Displayer.TimerDisplay:updatePlayerTimerDisplay(player_id, timer_id, value)
    if not TimerDisplaySystem or not TimerDisplaySystem.updatePlayerTimerDisplay then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    value = value or 0
    return TimerDisplaySystem:updatePlayerTimerDisplay(player_id, timer_id, value)
end

function Displayer.TimerDisplay:updatePlayerCountdownDisplay(player_id, countdown_id, value)
    if not TimerDisplaySystem or not TimerDisplaySystem.updatePlayerCountdownDisplay then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    value = value or 0
    return TimerDisplaySystem:updatePlayerCountdownDisplay(player_id, countdown_id, value)
end

function Displayer.TimerDisplay:removePlayerDisplay(player_id, display_id)
    if not TimerDisplaySystem or not TimerDisplaySystem.removePlayerDisplay then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not display_id then print("Error: display_id is required") return nil end
    return TimerDisplaySystem:removePlayerDisplay(player_id, display_id)
end

function Displayer.TimerDisplay:setDisplayPosition(player_id, display_id, x, y)
    if not TimerDisplaySystem or not TimerDisplaySystem.setDisplayPosition then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not display_id then print("Error: display_id is required") return nil end
    x = x or 0
    y = y or 0
    return TimerDisplaySystem:setDisplayPosition(player_id, display_id, x, y)
end

-- Global Timer Displays
function Displayer.TimerDisplay:createGlobalTimerDisplay(timer_id, x, y, config_name)
    if not TimerDisplaySystem or not TimerDisplaySystem.createGlobalTimerDisplay then return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    x = x or 0
    y = y or 0
    return TimerDisplaySystem:createGlobalTimerDisplay(timer_id, x, y, config_name or "default")
end

function Displayer.TimerDisplay:createGlobalCountdownDisplay(countdown_id, x, y, config_name)
    if not TimerDisplaySystem or not TimerDisplaySystem.createGlobalCountdownDisplay then return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    x = x or 0
    y = y or 0
    return TimerDisplaySystem:createGlobalCountdownDisplay(countdown_id, x, y, config_name or "default")
end

function Displayer.TimerDisplay:updateGlobalTimerDisplay(timer_id, value)
    if not TimerDisplaySystem or not TimerDisplaySystem.updateGlobalTimerDisplay then return nil end
    if not timer_id then print("Error: timer_id is required") return nil end
    value = value or 0
    return TimerDisplaySystem:updateGlobalTimerDisplay(timer_id, value)
end

function Displayer.TimerDisplay:updateGlobalCountdownDisplay(countdown_id, value)
    if not TimerDisplaySystem or not TimerDisplaySystem.updateGlobalCountdownDisplay then return nil end
    if not countdown_id then print("Error: countdown_id is required") return nil end
    value = value or 0
    return TimerDisplaySystem:updateGlobalCountdownDisplay(countdown_id, value)
end

function Displayer.TimerDisplay:removeGlobalDisplay(display_id)
    if not TimerDisplaySystem or not TimerDisplaySystem.removeGlobalDisplay then return nil end
    if not display_id then print("Error: display_id is required") return nil end
    return TimerDisplaySystem:removeGlobalDisplay(display_id)
end

function Displayer.TimerDisplay:setGlobalDisplayPosition(display_id, x, y)
    if not TimerDisplaySystem or not TimerDisplaySystem.setGlobalDisplayPosition then return nil end
    if not display_id then print("Error: display_id is required") return nil end
    x = x or 0
    y = y or 0
    return TimerDisplaySystem:setGlobalDisplayPosition(display_id, x, y)
end

-- Text Display API
Displayer.Text = {}

-- Static Text
function Displayer.Text:drawText(player_id, text, x, y, font_name, scale, z_order)
    if not TextDisplaySystem or not TextDisplaySystem.drawText then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text then print("Error: text is required") return nil end
    x = x or 0
    y = y or 0
    return TextDisplaySystem:drawText(player_id, text, x, y, font_name or "THICK", scale or 1.0, z_order or 100)
end

function Displayer.Text:updateText(player_id, text_id, new_text)
    if not TextDisplaySystem or not TextDisplaySystem.updateText then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text_id then print("Error: text_id is required") return nil end
    if not new_text then print("Error: new_text is required") return nil end
    return TextDisplaySystem:updateText(player_id, text_id, new_text)
end

function Displayer.Text:removeText(player_id, text_id)
    if not TextDisplaySystem or not TextDisplaySystem.removeText then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text_id then print("Error: text_id is required") return nil end
    return TextDisplaySystem:removeText(player_id, text_id)
end

function Displayer.Text:setTextPosition(player_id, text_id, x, y)
    if not TextDisplaySystem or not TextDisplaySystem.setTextPosition then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text_id then print("Error: text_id is required") return nil end
    x = x or 0
    y = y or 0
    return TextDisplaySystem:setTextPosition(player_id, text_id, x, y)
end

-- Marquee Text
function Displayer.Text:drawMarqueeText(player_id, marquee_id, text, y, font_name, scale, z_order, speed, backdrop)
    if not TextDisplaySystem or not TextDisplaySystem.drawMarqueeText then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not marquee_id then print("Error: marquee_id is required") return nil end
    if not text then print("Error: text is required") return nil end
    y = y or 0
    return TextDisplaySystem:drawMarqueeText(
        player_id, 
        marquee_id, 
        text, 
        y, 
        font_name or "THICK", 
        scale or 1.0, 
        z_order or 100, 
        speed or "medium", 
        backdrop
    )
end

function Displayer.Text:setMarqueeSpeed(player_id, text_id, speed)
    if not TextDisplaySystem or not TextDisplaySystem.setMarqueeSpeed then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text_id then print("Error: text_id is required") return nil end
    return TextDisplaySystem:setMarqueeSpeed(player_id, text_id, speed)
end

-- Text Boxes
function Displayer.Text:createTextBox(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed)
    if not TextDisplaySystem or not TextDisplaySystem.createTextBox then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not box_id then print("Error: box_id is required") return nil end
    if not text then print("Error: text is required") return nil end
    x = x or 0
    y = y or 0
    width = width or 200
    height = height or 100
    return TextDisplaySystem:createTextBox(
        player_id,
        box_id,
        text,
        x,
        y,
        width,
        height,
        font_name or "THICK",
        scale or 1.0,
        z_order or 100,
        backdrop_config,
        speed or 30
    )
end

function Displayer.Text:advanceTextBox(player_id, box_id)
    if not TextDisplaySystem or not TextDisplaySystem.advanceTextBox then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not box_id then print("Error: box_id is required") return nil end
    return TextDisplaySystem:advanceTextBox(player_id, box_id)
end

function Displayer.Text:removeTextBox(player_id, box_id)
    if not TextDisplaySystem or not TextDisplaySystem.removeTextBox then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not box_id then print("Error: box_id is required") return nil end
    return TextDisplaySystem:removeTextBox(player_id, box_id)
end

function Displayer.Text:isTextBoxCompleted(player_id, box_id)
    if not TextDisplaySystem or not TextDisplaySystem.isTextBoxCompleted then return false end
    if not player_id then print("Error: player_id is required") return false end
    if not box_id then print("Error: box_id is required") return false end
    return TextDisplaySystem:isTextBoxCompleted(player_id, box_id) or false
end

function Displayer.Text:setTextBoxPosition(player_id, box_id, x, y)
    if not TextDisplaySystem or not TextDisplaySystem.setTextBoxPosition then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not box_id then print("Error: box_id is required") return nil end
    x = x or 0
    y = y or 0
    return TextDisplaySystem:setTextBoxPosition(player_id, box_id, x, y)
end

-- Backdrop Management
function Displayer.Text:addBackdrop(player_id, text_id, backdrop_config)
    if not TextDisplaySystem or not TextDisplaySystem.addBackdrop then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text_id then print("Error: text_id is required") return nil end
    if not backdrop_config then print("Error: backdrop_config is required") return nil end
    return TextDisplaySystem:addBackdrop(player_id, text_id, backdrop_config)
end

function Displayer.Text:removeBackdrop(player_id, text_id)
    if not TextDisplaySystem or not TextDisplaySystem.removeBackdrop then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text_id then print("Error: text_id is required") return nil end
    return TextDisplaySystem:removeBackdrop(player_id, text_id)
end

-- Font System API (for advanced use)
Displayer.Font = {}

function Displayer.Font:drawTextWithId(player_id, text, x, y, font_name, scale, z_order, display_id)
    if not FontSystem or not FontSystem.drawTextWithId then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text then print("Error: text is required") return nil end
    if not display_id then print("Error: display_id is required") return nil end
    x = x or 0
    y = y or 0
    return FontSystem:drawTextWithId(player_id, text, x, y, font_name or "THICK", scale or 1.0, z_order or 100, display_id)
end

function Displayer.Font:drawText(player_id, text, x, y, font_name, scale, z_order)
    if not FontSystem or not FontSystem.drawText then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not text then print("Error: text is required") return nil end
    x = x or 0
    y = y or 0
    return FontSystem:drawText(player_id, text, x, y, font_name or "THICK", scale or 1.0, z_order or 100)
end

function Displayer.Font:eraseTextDisplay(player_id, display_id)
    if not FontSystem or not FontSystem.eraseTextDisplay then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not display_id then print("Error: display_id is required") return nil end
    return FontSystem:eraseTextDisplay(player_id, display_id)
end

function Displayer.Font:getTextWidth(text, font_name, scale)
    if not FontSystem or not FontSystem.getTextWidth then return 0 end
    if not text then print("Error: text is required") return 0 end
    return FontSystem:getTextWidth(text, font_name or "THICK", scale or 1.0) or 0
end

-- Utility Functions
function Displayer:getScreenDimensions()
    if not TextDisplaySystem or not TextDisplaySystem.getScreenDimensions then return 240, 160 end
    return TextDisplaySystem:getScreenDimensions()
end

function Displayer:formatTime(seconds, is_countdown)
    seconds = seconds or 0
    if is_countdown then
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%02d:%02d", mins, secs)
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%02d:%02d:%02d", hours, mins, secs)
    end
end

-- Convenience function to hide default HUD
function Displayer:hidePlayerHUD(player_id)
    if not player_id then print("Error: player_id is required") return end
    if Net and Net.toggle_player_hud then
        Net.toggle_player_hud(player_id)
    end
end

-- Quick setup for common use cases
function Displayer:setupPlayerDefaultUI(player_id, options)
    if not player_id then print("Error: player_id is required") return end
    
    options = options or {}
    
    -- Hide default HUD
    self:hidePlayerHUD(player_id)
    
    -- Create default timer displays if positions provided
    if options.timer_position then
        self.TimerDisplay:createPlayerTimerDisplay(player_id, "player_timer", 
            options.timer_position.x or 120, options.timer_position.y or 100, 
            options.timer_style or "default")
    end
    
    if options.countdown_position then
        self.TimerDisplay:createPlayerCountdownDisplay(player_id, "player_countdown", 
            options.countdown_position.x or 120, options.countdown_position.y or 120, 
            options.countdown_style or "default")
    end
    
    -- Create welcome message if text provided
    if options.welcome_text then
        self.Text:createTextBox(player_id, "welcome", options.welcome_text, 
            options.textbox_x or 20, options.textbox_y or 140,
            options.textbox_width or 200, options.textbox_height or 50,
            "THICK", 1.0, 100, options.backdrop_config, options.text_speed or 25)
    end
end

-- Scrolling Text List System API
Displayer.ScrollingText = {}

function Displayer.ScrollingText:createList(player_id, list_id, x, y, width, height, config)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.createScrollingList then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not list_id then print("Error: list_id is required") return nil end
    x = x or 0
    y = y or 0
    width = width or 200
    height = height or 100
    config = config or {}
    return ScrollingTextListSystem:createScrollingList(player_id, list_id, x, y, width, height, config)
end

function Displayer.ScrollingText:addText(player_id, list_id, text)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.addTextToList then return false end
    if not player_id then print("Error: player_id is required") return false end
    if not list_id then print("Error: list_id is required") return false end
    if not text then print("Error: text is required") return false end
    return ScrollingTextListSystem:addTextToList(player_id, list_id, text)
end

function Displayer.ScrollingText:setTexts(player_id, list_id, texts)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.setListTexts then return false end
    if not player_id then print("Error: player_id is required") return false end
    if not list_id then print("Error: list_id is required") return false end
    texts = texts or {}
    return ScrollingTextListSystem:setListTexts(player_id, list_id, texts)
end

function Displayer.ScrollingText:getState(player_id, list_id)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.getListState then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not list_id then print("Error: list_id is required") return nil end
    return ScrollingTextListSystem:getListState(player_id, list_id)
end

function Displayer.ScrollingText:pause(player_id, list_id)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.pauseList then return false end
    if not player_id then print("Error: player_id is required") return false end
    if not list_id then print("Error: list_id is required") return false end
    return ScrollingTextListSystem:pauseList(player_id, list_id)
end

function Displayer.ScrollingText:resume(player_id, list_id)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.resumeList then return false end
    if not player_id then print("Error: player_id is required") return false end
    if not list_id then print("Error: list_id is required") return false end
    return ScrollingTextListSystem:resumeList(player_id, list_id)
end

function Displayer.ScrollingText:setSpeed(player_id, list_id, speed)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.setListSpeed then return false end
    if not player_id then print("Error: player_id is required") return false end
    if not list_id then print("Error: list_id is required") return false end
    speed = speed or 30
    return ScrollingTextListSystem:setListSpeed(player_id, list_id, speed)
end

function Displayer.ScrollingText:removeList(player_id, list_id)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.removeScrollingList then return nil end
    if not player_id then print("Error: player_id is required") return nil end
    if not list_id then print("Error: list_id is required") return nil end
    return ScrollingTextListSystem:removeScrollingList(player_id, list_id)
end

function Displayer.ScrollingText:setPosition(player_id, list_id, x, y)
    if not ScrollingTextListSystem or not ScrollingTextListSystem.setListPosition then return false end
    if not player_id then print("Error: player_id is required") return false end
    if not list_id then print("Error: list_id is required") return false end
    x = x or 0
    y = y or 0
    return ScrollingTextListSystem:setListPosition(player_id, list_id, x, y)
end

-- Export the API
local displayerInstance = setmetatable({}, Displayer)
return displayerInstance