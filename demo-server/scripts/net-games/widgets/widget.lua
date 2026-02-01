-- widgets.lua (main module)
-- Flutter-inspired widget system for net-games framework
-- Main module file that exports everything

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print

-- Cache for animation modules to avoid loading every tick
local _animation_modules_loaded = false
local _AnimationEngine, _AnimationSequences, _AnimationEnums

-- Load all widget modules
local Widget = require('scripts/net-games/widgets/base-widget')
local Row = require('scripts/net-games/widgets/row')
local Column = require('scripts/net-games/widgets/column')
local Grid = require('scripts/net-games/widgets/grid')
local Container = require('scripts/net-games/widgets/container')
local Expanded = require('scripts/net-games/widgets/expanded')
local Align = require('scripts/net-games/widgets/align')
local ListView = require('scripts/net-games/widgets/listview')  -- Added ListView widget

local SpriteObject = require('scripts/net-games/widgets/sprite-object')
local WidgetCache = require('scripts/net-games/widgets/cache')
local utils = require('scripts/net-games/widgets/utils')

-- Load other modules
local WidgetBuilder = require('scripts/net-games/widgets/builder')
local SelectionManager = require('scripts/net-games/widgets/selection-manager')
local WidgetAnimations = require('scripts/net-games/widgets/animations')
local WidgetEvents = require('scripts/net-games/widgets/events')
local WidgetDebug = require('scripts/net-games/widgets/debug')

-- Function to load animation modules once and cache them
local function load_animation_modules_once()
    if not _animation_modules_loaded then
        debug_print("INFO", "Loading animation modules...")
        _AnimationEngine, _AnimationSequences, _AnimationEnums = utils.load_animation_modules()
        _animation_modules_loaded = true
        debug_print("INFO", "Animation modules loaded and cached")
    end
    return _AnimationEngine, _AnimationSequences, _AnimationEnums
end

-- Update all widgets with cached animation modules
local function update_all_widgets(dt)
    debug_print("VERBOSE", "WidgetSystem.tick: Updating all widgets with dt=%f", dt)
    
    -- Get cached animation modules
    local AnimationEngine = _AnimationEngine
    
    if AnimationEngine then
        AnimationEngine.tick(dt)
    end
    
    local updated_count = 0
    local total_widgets = 0
    
    -- Update all widgets for all players
    for player_id, widgets in pairs(WidgetCache._cache) do
        for widget_id, widget in pairs(widgets) do
            total_widgets = total_widgets + 1
            if widget:update(dt) then
                updated_count = updated_count + 1
            end
        end
    end
    
    if updated_count > 0 then
        debug_print("DETAILED", "WidgetSystem.tick: Updated %d/%d widgets", updated_count, total_widgets)
    end
    
    return updated_count
end

-- Initialize the widget system
local function initialize_widget_system()
    debug_print("INFO", "Initializing widget system...")
    
    -- Preload animation modules
    load_animation_modules_once()
    
    -- Set up tick event handler if Net is available
    if Net and Net.on then
        Net:on("tick", function(event)
            local dt = event.delta_time
            update_all_widgets(dt)
        end)
        debug_print("INFO", "Tick event handler registered")
    else
        debug_print("WARN", "Net module not available, tick event handler not registered")
    end
    
    -- Initialize widget events
    WidgetEvents.initialize()
    
    debug_print("INFO", "Widget system initialized successfully with screen: %dx%d (scale: %f)",
               utils.SCREEN_WIDTH, utils.SCREEN_HEIGHT, utils.SCREEN_SCALE)
    return true
end

-- Check if animation modules are loaded
local function are_animation_modules_loaded()
    return _animation_modules_loaded and _AnimationEngine ~= nil
end

-- Screen helper functions
local function createCenteredWidget(widget_type, id, player_id, width, height)
    local widget
    if widget_type == "Row" then
        widget = Row.new(id, player_id)
    elseif widget_type == "Column" then
        widget = Column.new(id, player_id)
    elseif widget_type == "Grid" then
        widget = Grid.new(id, player_id)
    elseif widget_type == "Container" then
        widget = Container.new(id, player_id)
    elseif widget_type == "Expanded" then
        widget = Expanded.new(id, player_id)
    elseif widget_type == "Align" then
        widget = Align.new(id, player_id)
    elseif widget_type == "ListView" then  -- Added ListView widget
        widget = ListView.new(id, player_id)
    else
        widget = Widget.new(id, player_id)
    end
    
    if width and height then
        widget:setSize(width, height)
    end
    
    widget:centerOnScreen()
    widget:setScreenConstraints(true)
    
    return widget
end

-- Module exports
return {
    -- Base classes
    Widget = Widget,
    Row = Row,
    Column = Column,
    Grid = Grid,
    Container = Container,
    Expanded = Expanded,
    Align = Align,
    ListView = ListView,  -- Added ListView widget
    
    -- Managers
    SelectionManager = SelectionManager,
    
    -- Builders
    Builder = WidgetBuilder,
    
    -- Animations
    Animations = WidgetAnimations,
    
    -- Events
    Events = WidgetEvents,
    
    -- Widget cache
    WidgetCache = WidgetCache,
    
    -- Sprite Object class
    SpriteObject = SpriteObject,
    
    -- Debug utilities
    Debug = WidgetDebug,
    
    -- Log management
    Log = {
        set_level = LOGGING.set_debug_level,
        get_level = LOGGING.get_debug_level,
        enable = LOGGING.enable_debug,
        disable = LOGGING.disable_debug,
        is_enabled = LOGGING.is_debug_enabled
    },
    
    -- Screen configuration
    Screen = {
        WIDTH = utils.SCREEN_WIDTH,
        HEIGHT = utils.SCREEN_HEIGHT,
        SCALE = utils.SCREEN_SCALE,
        SCALED_WIDTH = utils.SCREEN_SCALED_WIDTH,
        SCALED_HEIGHT = utils.SCREEN_SCALED_HEIGHT,
        
        normalizeX = utils.normalize_x,
        normalizeY = utils.normalize_y,
        scaleX = utils.scale_x,
        scaleY = utils.scale_y,
        getCenter = utils.get_screen_center,
        getScaledCenter = utils.get_scaled_screen_center,
        isWithinScreen = utils.is_within_screen,
        constrainToScreen = utils.constrain_to_screen
    },
    
    -- Utility functions
    createRow = function(id, player_id) return Row.new(id, player_id) end,
    createColumn = function(id, player_id) return Column.new(id, player_id) end,
    createGrid = function(id, player_id) return Grid.new(id, player_id) end,
    createContainer = function(id, player_id) return Container.new(id, player_id) end,
    createExpanded = function(id, player_id) return Expanded.new(id, player_id) end,
    createAlign = function(id, player_id) return Align.new(id, player_id) end,
    createListView = function(id, player_id) return ListView.new(id, player_id) end,  -- Added ListView creation
    
    -- Screen-centered widget creation
    createCenteredRow = function(id, player_id, width, height) 
        return createCenteredWidget("Row", id, player_id, width, height) 
    end,
    createCenteredColumn = function(id, player_id, width, height) 
        return createCenteredWidget("Column", id, player_id, width, height) 
    end,
    createCenteredGrid = function(id, player_id, width, height) 
        return createCenteredWidget("Grid", id, player_id, width, height) 
    end,
    createCenteredContainer = function(id, player_id, width, height) 
        return createCenteredWidget("Container", id, player_id, width, height) 
    end,
    createCenteredAlign = function(id, player_id, width, height) 
        return createCenteredWidget("Align", id, player_id, width, height) 
    end,
    createCenteredListView = function(id, player_id, width, height) 
        return createCenteredWidget("ListView", id, player_id, width, height) 
    end,
    
    -- Cache functions
    getWidget = function(widget_id, player_id)
        return WidgetCache.get(widget_id, player_id)
    end,
    
    getPlayerWidgets = function(player_id)
        return WidgetCache.get_all(player_id)
    end,
    
    clearPlayerWidgets = function(player_id)
        return WidgetCache.clear_player(player_id)
    end,
    
    printCacheStats = function()
        return WidgetCache.stats()
    end,
    
    -- Animation control
    loadAnimationModules = load_animation_modules_once,
    areAnimationModulesLoaded = are_animation_modules_loaded,
    getAnimationEngine = function() return _AnimationEngine end,
    getAnimationSequences = function() return _AnimationSequences end,
    getAnimationEnums = function() return _AnimationEnums end,
    
    stopAllAnimations = function(widget)
        if widget then
            widget:stop_all_animations()
        else
            -- Stop animations on all widgets
            for player_id, widgets in pairs(WidgetCache._cache) do
                for _, widget in pairs(widgets) do
                    widget:stop_all_animations()
                end
            end
        end
    end,
    
    -- Quick creation
    quickMenu = WidgetBuilder.createMenu,
    quickInventory = WidgetBuilder.createInventoryGrid,
    quickHUD = WidgetBuilder.createHUD,
    
    -- Debug control
    enableDebug = WidgetDebug.enableDebug,
    disableDebug = WidgetDebug.disableDebug,
    printWidgetTree = WidgetDebug.printWidgetTree,
    getStats = WidgetDebug.getStats,
    
    -- Widget system management
    init = initialize_widget_system,
    updateAllWidgets = update_all_widgets,
    
    -- Animation system management
    updateAnimationEngine = function(dt)
        local AnimationEngine = _AnimationEngine
        if AnimationEngine then
            AnimationEngine.tick(dt)
            return true
        end
        return false
    end,
    
    -- Helper functions
    generateUniqueId = utils.generate_unique_id,
    
    -- System status
    isInitialized = function()
        return _animation_modules_loaded
    end,
    
    -- Clean shutdown
    shutdown = function()
        debug_print("INFO", "Shutting down widget system...")
        
        -- Stop all animations
        for player_id, widgets in pairs(WidgetCache._cache) do
            for _, widget in pairs(widgets) do
                widget:stop_all_animations()
            end
        end
        
        -- Clear all widgets
        for player_id, _ in pairs(WidgetCache._cache) do
            WidgetCache.clear_player(player_id)
        end
        
        -- Clear animation modules cache
        _AnimationEngine = nil
        _AnimationSequences = nil
        _AnimationEnums = nil
        _animation_modules_loaded = false
        
        debug_print("INFO", "Widget system shut down")
        return true
    end
}