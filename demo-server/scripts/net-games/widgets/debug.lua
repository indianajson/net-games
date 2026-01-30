-- widgets/widget-debug.lua
-- Debug utilities for the widget system

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')
local SpriteDimensionCache = require('scripts/net-games/widgets/sprite-dimension-cache')

local WidgetDebug = {}

function WidgetDebug.printWidgetTree(widget, level)
    level = level or 0
    local indent = string.rep("  ", level)
    
    print(indent .. "┌─ " .. widget.id .. " (" .. (widget.widget_type or "Widget") .. ")")
    print(indent .. "│  Position: (" .. widget.x .. ", " .. widget.y .. ")")
    print(indent .. "│  Size: " .. widget.width .. "x" .. widget.height)
    print(indent .. "│  Children: " .. #widget.children)
    print(indent .. "│  Sprites: " .. utils.table_count(widget.sprite_objects))
    print(indent .. "│  Animating: " .. tostring(widget:is_animating()))
    print(indent .. "│  Layout Animation: " .. tostring(widget._layout_animation_active))
    print(indent .. "│  Layout Animation Type: " .. (widget._layout_animation_type or "none"))
    print(indent .. "│  Dirty: " .. tostring(widget.state.dirty))
    print(indent .. "│  Visible: " .. tostring(widget.state.visible))
    
    if #widget.children > 0 then
        print(indent .. "│  Child details:")
        for i, child in ipairs(widget.children) do
            if child.type == "sprite" then
                print(indent .. "│    " .. i .. ": Sprite [" .. (child.sprite_id or "unknown") .. "]")
                print(indent .. "│        texture: " .. (child.texture_path or "none"))
                print(indent .. "│        anim: " .. (child.anim_path or "none"))
                print(indent .. "│        state: " .. (child.anim_state or "none"))
                print(indent .. "│        layout: " .. (child.layout_width or "auto") .. "x" .. (child.layout_height or "auto"))
                local sprite = widget:get_sprite(child.sprite_id)
                if sprite then
                    print(indent .. "│        template: " .. sprite.template_id)
                    print(indent .. "│        widget animated: " .. tostring(sprite:is_widget_animated()))
                end
            elseif child.widget then
                print(indent .. "│    " .. i .. ": Widget [" .. child.widget.id .. "]")
                WidgetDebug.printWidgetTree(child.widget, level + 2)
            else
                print(indent .. "│    " .. i .. ": Unknown child type")
            end
        end
    end
    
    -- Print sprite groups
    if utils.table_count(widget.sprite_groups) > 0 then
        print(indent .. "│  Sprite Groups:")
        for group_name, sprite_ids in pairs(widget.sprite_groups) do
            print(indent .. "│    - " .. group_name .. ": " .. #sprite_ids .. " sprites")
        end
    end
    
    -- Print child widgets
    local widget_count = utils.table_count(widget._child_widgets)
    if widget_count > 0 then
        print(indent .. "│  Child Widgets: " .. widget_count)
        for _, child_widget in pairs(widget._child_widgets) do
            WidgetDebug.printWidgetTree(child_widget, level + 2)
        end
    end
    
    print(indent .. "└─")
end

function WidgetDebug.enableDebug(level)
    if level then
        LOGGING.set_debug_level(level)
    else
        LOGGING.enable_debug()
    end
    print("[Widgets] Debug enabled at level: " .. LOGGING.get_debug_level())
end

function WidgetDebug.disableDebug()
    LOGGING.disable_debug()
    print("[Widgets] Debug disabled")
end

function WidgetDebug.getStats()
    local stats = {
        dimension_cache_entries = SpriteDimensionCache.stats(),
        widget_cache_entries = 0,
        widget_types = {
            row = "Row",
            column = "Column",
            grid = "Grid",
            container = "Container",
            expanded = "Expanded"
        },
        animation_engine_loaded = false,
        animation_sequences_loaded = false,
        debug_mode = LOGGING.is_debug_enabled() and ("ENABLED (" .. LOGGING.get_debug_level() .. ")") or "DISABLED"
    }
    
    -- Get animation module status
    local AnimationEngine, AnimationSequences, AnimationEnums = utils.load_animation_modules()
    stats.animation_engine_loaded = AnimationEngine ~= nil
    stats.animation_sequences_loaded = AnimationSequences ~= nil
    
    -- Get widget cache stats
    local WidgetCache = require('scripts/net-games/widgets/cache')
    stats.widget_cache_entries = WidgetCache.stats()
    
    print("[Widgets Debug Stats]")
    print("  Dimension cache entries:", stats.dimension_cache_entries)
    print("  Widget cache entries:", stats.widget_cache_entries)
    print("  AnimationEngine loaded:", stats.animation_engine_loaded)
    print("  AnimationSequences loaded:", stats.animation_sequences_loaded)
    print("  Debug mode:", stats.debug_mode)
    
    return stats
end

return WidgetDebug