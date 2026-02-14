--[[
    Main Initialization for Pure Sprite Widget Framework
    Sets up the framework and Net event handlers
]]

-- Import all framework modules
local SpriteManager = require("scripts/widgets/sprite-manager")
local AnimationManager = require("scripts/widgets/animation-manager")
local WidgetClasses = require("scripts/widgets/widget-base")
local WidgetFramework = require("scripts/widgets/widget-framework")

-- Export widget classes for external use
SpriteWidget = WidgetClasses.SpriteWidget
TextSpriteWidget = WidgetClasses.TextSpriteWidget
ContainerWidget = WidgetClasses.ContainerWidget

-- Global framework instance
local PureSpriteFramework = {
    instance = nil,
    initialized = false
}

-- Initialize the framework
function PureSpriteFramework.initialize()
    if PureSpriteFramework.initialized then
        return true, "Already initialized"
    end
    
    print("[PureSpriteFramework] Initializing...")
    
    -- Create managers
    local sprite_manager = SpriteManager.new()
    local animation_manager = AnimationManager.new()
    
    -- Create framework instance
    local framework = WidgetFramework.new()
    local success, error = framework:initialize(sprite_manager, animation_manager)
    
    if not success then
        print("[PureSpriteFramework] Initialization failed: " .. tostring(error))
        return false, error
    end
    
    PureSpriteFramework.instance = framework
    PureSpriteFramework.initialized = true
    
    -- Set up Net event handlers
    PureSpriteFramework:_setupEventHandlers()
    
    print("[PureSpriteFramework] Initialization complete")
    return true
end

-- Set up Net event handlers
function PureSpriteFramework:_setupEventHandlers()
    -- Player join event
    Net.on_player_join(function(player_id)
        print("[PureSpriteFramework] Player joined: " .. tostring(player_id))
        -- Player structures will be initialized on first widget creation
    end)
    
    -- Player leave event
    Net.on_player_leave(function(player_id)
        print("[PureSpriteFramework] Player left: " .. tostring(player_id))
        
        if PureSpriteFramework.instance then
            PureSpriteFramework.instance:cleanupPlayer(player_id)
        end
    end)
    
    -- Tick event for animation updates
    Net.on_tick(function()
        if PureSpriteFramework.instance and PureSpriteFramework.initialized then
            PureSpriteFramework.instance:update()
        end
    end)
    
    -- Input event handling (tap)
    Net.on_player_tap(function(player_id, x, y)
        if PureSpriteFramework.instance and PureSpriteFramework.initialized then
            -- Process tap event
            PureSpriteFramework.instance:processTapEvent(player_id, x, y)
            
            -- Process hover events
            PureSpriteFramework.instance:processHoverEvent(player_id, x, y)
        end
    end)
    
    -- Player move event for continuous hover detection
    Net.on_player_move(function(player_id, x, y)
        if PureSpriteFramework.instance and PureSpriteFramework.initialized then
            PureSpriteFramework.instance:processHoverEvent(player_id, x, y)
        end
    end)
    
    print("[PureSpriteFramework] Event handlers registered")
end

-- Get the framework instance
function PureSpriteFramework.getInstance()
    if not PureSpriteFramework.initialized then
        local success, error = PureSpriteFramework.initialize()
        if not success then
            return nil, error
        end
    end
    
    return PureSpriteFramework.instance
end

-- Convenience methods for common operations

-- Create a simple button widget
function PureSpriteFramework.createButton(player_id, button_id, properties, click_handler)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return nil, "Framework not initialized"
    end
    
    -- Create button widget
    local button, error = instance:createWidget(
        player_id,
        button_id,
        "sprite",
        properties
    )
    
    if not button then
        return nil, error
    end
    
    -- Build the button
    instance:buildWidget(player_id, button_id)
    
    -- Register click handler if provided
    if click_handler then
        instance:registerWidgetEvent(
            player_id,
            button_id,
            instance.EVENT_TYPES.TAP,
            click_handler
        )
    end
    
    return button
end

-- Create a text label
function PureSpriteFramework.createLabel(player_id, label_id, text, properties, parent_id)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return nil, "Framework not initialized"
    end
    
    -- Ensure text property is set
    properties = properties or {}
    properties.text = text or properties.text or ""
    
    -- Create text widget
    local label, error = instance:createWidget(
        player_id,
        label_id,
        "text_sprite",
        properties,
        parent_id
    )
    
    if not label then
        return nil, error
    end
    
    -- Build the label
    instance:buildWidget(player_id, label_id)
    
    return label
end

-- Create a container with layout
function PureSpriteFramework.createContainer(player_id, container_id, properties, parent_id)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return nil, "Framework not initialized"
    end
    
    -- Create container widget
    local container, error = instance:createWidget(
        player_id,
        container_id,
        "container",
        properties,
        parent_id
    )
    
    if not container then
        return nil, error
    end
    
    -- Build the container
    instance:buildWidget(player_id, container_id)
    
    return container
end

-- Add widget to container
function PureSpriteFramework.addToContainer(player_id, widget_id, container_id)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return false, "Framework not initialized"
    end
    
    local container = instance:getWidget(player_id, container_id)
    local widget = instance:getWidget(player_id, widget_id)
    
    if not container then
        return false, "Container not found"
    end
    
    if not widget then
        return false, "Widget not found"
    end
    
    -- Add widget to container
    return container:addChild(widget)
end

-- Animate widget color pulse
function PureSpriteFramework.animateColorPulse(player_id, widget_id, start_color, end_color, options)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return nil, "Framework not initialized"
    end
    
    return instance:colorPulseWidget(widget_id, player_id, start_color, end_color, options)
end

-- Animate widget scale pulse
function PureSpriteFramework.animateScalePulse(player_id, widget_id, min_scale, max_scale, options)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return nil, "Framework not initialized"
    end
    
    return instance:pulseScaleWidget(widget_id, player_id, min_scale, max_scale, options)
end

-- Animate widget slide
function PureSpriteFramework.animateSlide(player_id, widget_id, target_x, target_y, options)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return nil, "Framework not initialized"
    end
    
    return instance:slideWidget(widget_id, player_id, target_x, target_y, options)
end

-- Clean up player UI
function PureSpriteFramework.cleanupPlayer(player_id)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return false, "Framework not initialized"
    end
    
    instance:cleanupPlayer(player_id)
    return true
end

-- Update all widgets (call this regularly if not using Net tick)
function PureSpriteFramework.update()
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return 0, "Framework not initialized"
    end
    
    return instance:update()
end

-- Example usage function
function PureSpriteFramework.exampleHUD(player_id)
    local instance = PureSpriteFramework.getInstance()
    if not instance then
        return false, "Framework not initialized"
    end
    
    print("[PureSpriteFramework] Creating example HUD for player: " .. tostring(player_id))
    
    -- Create health bar container
    local health_bar = PureSpriteFramework.createContainer(player_id, "health_bar", {
        x = 50,
        y = 50,
        width = 200,
        height = 30,
        layout = "horizontal",
        background = "/server/assets/net-games/ui/health_bg.png"
    })
    
    -- Create health fill
    local health_fill = PureSpriteFramework.createWidget(
        player_id,
        "health_fill",
        "sprite",
        {
            texture = "/server/assets/net-games/ui/health_fill.png",
            width = 180,
            height = 20,
            color = {r = 0, g = 255, b = 0, a = 255}
        },
        "health_bar"
    )
    
    -- Create health text
    PureSpriteFramework.createLabel(player_id, "health_text", "100/100", {
        x = 260,
        y = 50,
        font = "BATTLE",
        font_scale = 1.5,
        color = {r = 255, g = 255, b = 255, a = 255}
    })
    
    -- Create score display
    PureSpriteFramework.createLabel(player_id, "score_display", "Score: 0", {
        x = 50,
        y = 100,
        font = "THICK",
        font_scale = 2.0,
        color = {r = 255, g = 255, b = 0, a = 255}
    })
    
    -- Create action button
    local action_button = PureSpriteFramework.createButton(player_id, "action_button", {
        x = 300,
        y = 300,
        texture = "/server/assets/net-games/ui/button.png",
        width = 64,
        height = 64
    }, function(widget, event)
        print("Action button clicked!")
        
        -- Animate button press
        PureSpriteFramework.animateScalePulse(player_id, "action_button", 0.9, 1.1, {
            duration = 0.2,
            loop = false
        })
    end)
    
    -- Add hover effect to button
    instance:registerWidgetEvent(player_id, "action_button", "hover_enter", function(widget, event)
        PureSpriteFramework.animateColorPulse(player_id, "action_button", 
            {r = 255, g = 255, b = 255, a = 255},
            {r = 200, g = 200, b = 255, a = 255},
            {duration = 0.3, loop = true, ping_pong = true}
        )
    end)
    
    instance:registerWidgetEvent(player_id, "action_button", "hover_leave", function(widget, event)
        instance:stopWidgetAnimations("action_button", player_id, true)
        widget:setColor(255, 255, 255, 255)
    end)
    
    return true
end

-- Initialize on require
PureSpriteFramework.initialize()

-- Return the framework for external use
return PureSpriteFramework