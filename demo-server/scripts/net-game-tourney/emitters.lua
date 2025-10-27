local debug = require("scripts/debug-utils")
local change_area_emitter = Net.EventEmitter.new()
local tourney_emitter     = Net.EventEmitter.new()

local Tourney = {
    player_history     = {},
    online_players     = {},
    offline_players    = {},
    matchups_in_battle = {},
    tournaments        = {},
    players_waiting    = {}
}

-- Recursively remove a player ID from all tables (except player_history and offline_players)
function Tourney.remove_player_from_all_tables(pid, tbl)
    tbl = tbl or Tourney
    for k, v in pairs(tbl) do
        if k ~= "player_history" and k ~= "offline_players" then
            if type(v) == "table" then
                Tourney.remove_player_from_all_tables(pid, v)
            elseif v == pid then
                tbl[k] = nil
            end
        end
    end
end

Net:on("player_transfer_area", function(event)
    local area = Net.get_player_area(event.player_id)
    Tourney.set_player_area(event.player_id, area)
end)

Net:on("player_join", function(event)
    local secret = Net.get_player_secret(event.player_id)
    local area = Net.get_player_area(event.player_id)
    Tourney.set_player_area(event.player_id, area)
    if not Tourney.player_history[secret] then
        Tourney.player_history[secret] = { player_id = event.player_id, current_area = area }
    end
end)

-- Updated disconnect handler to remove player ID from all nested tables
Net:on("player_disconnect", function(event)
    local secret = Net.get_player_secret(event.player_id)
    Tourney.online_players[secret] = nil
    Tourney.offline_players[secret] = { last_player_id = event.player_id, current_area = "NONE" }

    -- Remove player_id from all other nested tables
    Tourney.remove_player_from_all_tables(event.player_id)
end)

change_area_emitter:on("player_changed_area", function(event)
    print("[PLAYER CHANGED AREA] " .. event.player_id .. " now in " .. event.current_area)
end)

tourney_emitter:on("in_tourney_battle", function(event)
    print("[IN TOURNEY BATTLE] matchup started: " .. tostring(event.matchup_id))
end)

tourney_emitter:on("leave_tourney_battle", function(event)
    print("[LEAVE TOURNEY BATTLE] matchup ended: " .. tostring(event.matchup_id))
end)

function Tourney.set_player_area(pid, area)
    local secret = Net.get_player_secret(pid)
    if not Tourney.player_history[secret] then
        Tourney.player_history[secret] = { player_id = pid, current_area = area }
    end
    Tourney.player_history[secret].current_area = area
    change_area_emitter:emit("player_changed_area", { player_id = pid, current_area = area })
end

-- ✅ Prevent duplicate “in_tourney_battle” events
function Tourney.start_tourney_battle(player1_id, player2_id)
    for _, m in ipairs(Tourney.matchups_in_battle) do
        if (m.player1_id == player1_id and m.player2_id == player2_id)
        or  (m.player1_id == player2_id and m.player2_id == player1_id) then
            print("[Tourney] Duplicate battle detected, skipping emit.")
            return
        end
    end

    local id = #Tourney.matchups_in_battle + 1
    Tourney.matchups_in_battle[id] = { player1_id = player1_id, player2_id = player2_id, results = {} }
    tourney_emitter:emit("in_tourney_battle", { matchup_id = id, matchup = Tourney.matchups_in_battle[id] })
end

return Tourney
