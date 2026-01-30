-- widgets/widget-cache.lua
-- Widget caching system for player-specific widgets
local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print
local utils = require('scripts/net-games/widgets/utils')

local WidgetCache = {}
local _widget_cache = {} -- player_id -> widget_id -> widget

function WidgetCache.register(widget)
    if not widget or not widget.id or not widget.player_id then
        debug_print("ERROR", "WidgetCache.register: Invalid widget")
        return false
    end

    if not _widget_cache[widget.player_id] then
        _widget_cache[widget.player_id] = {}
    end

    _widget_cache[widget.player_id][widget.id] = widget
    debug_print("INFO", "WidgetCache.register: %s for player %s", widget.id,
                widget.player_id)
    return true
end

function WidgetCache.unregister(widget_id, player_id)
    if _widget_cache[player_id] then
        local removed = _widget_cache[player_id][widget_id] ~= nil
        _widget_cache[player_id][widget_id] = nil
        if removed then
            debug_print("INFO", "WidgetCache.unregister: %s for player %s",
                        widget_id, player_id)
        end
        return removed
    end
    return false
end

function WidgetCache.get(widget_id, player_id)
    if _widget_cache[player_id] then
        return _widget_cache[player_id][widget_id]
    end
    return nil
end

function WidgetCache.get_all(player_id)
    if _widget_cache[player_id] then
        local widgets = {}
        for id, widget in pairs(_widget_cache[player_id]) do
            table.insert(widgets, widget)
        end
        return widgets
    end
    return {}
end

function WidgetCache.clear_player(player_id)
    if _widget_cache[player_id] then
        local count = 0
        for _ in pairs(_widget_cache[player_id]) do count = count + 1 end
        _widget_cache[player_id] = nil
        debug_print("INFO",
                    "WidgetCache.clear_player: Cleared %d widgets for player %s",
                    count, player_id)
        return count
    end
    return 0
end

function WidgetCache.stats()
    local total = 0
    for player_id, widgets in pairs(_widget_cache) do
        local count = 0
        for _ in pairs(widgets) do count = count + 1 end
        debug_print("INFO", "  Player %s: %d widgets", player_id, count)
        total = total + count
    end
    debug_print("INFO", "WidgetCache total: %d widgets across %d players",
                total, utils.table_count(_widget_cache))
    return total
end

-- Make the internal cache accessible for the main module
WidgetCache._cache = _widget_cache

return WidgetCache
