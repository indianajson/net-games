local debug = require("scripts/debug-utils")
local change_area_emitter = Net.EventEmitter.new()
local tourney_emitter     = Net.EventEmitter.new()

local Tourney = {
    player_history     = {},
    online_players     = {},
    offline_players    = {},
    matchups_in_battle = {},
    tournaments        = {},
}

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

Net:on("player_disconnect", function(event)
    local secret = Net.get_player_secret(event.player_id)
    Tourney.online_players[secret] = nil
    Tourney.offline_players[secret] = { last_player_id = event.player_id, current_area = "NONE" }
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


-- Countdown utility function
local function show_countdown(player_id, duration)
    return async(function()
        -- spawn countdown graphics
        games.spawn_countdown(player_id, 100, 20, 10, duration)
        games.start_countdown(player_id)

        -- wait for countdown duration
        await(Async.sleep(duration))

        -- automatically remove countdown graphics
        games.remove_ui_element("COUNTDOWN_BG", player_id)
        games.remove_ui_element("COUNTDOWN_NUM", player_id)

        -- trigger countdown ended event
        Net.trigger("countdown_ended", { player_id = player_id })
    end)
end

-- Function to handle joining or starting a tournament
local function join_or_start_tournament(event)
    local player_id = event.player_id
    local object_id = event.object_id
    local duration = 10 -- countdown duration
    local single = event.single

    if single == 0 then
        join_or_create_party(player_id, object_id, false)
    else
        join_or_create_party(player_id, object_id, true)
    end

    games.start_framework()
    games.activate_framework(player_id)
    Net.lock_player_input(player_id)

    -- mark player as waiting before countdown starts
    players_waiting[player_id] = { waiting = true, tourney_board = object_id }

    -- run countdown
    await(show_countdown(player_id, duration))
end

-- Countdown ended callback
Net:on("countdown_ended", function(event)
    return async(function()
        if players_waiting[event.player_id] == nil then
            return -- stops logic if player isn't setting up a tournament
        end

        local player_area = Net.get_player_area(event.player_id)
        local entry = players_waiting[event.player_id]
        local object = Net.get_object_by_id(player_area, entry["tourney_board"])

        -- Remove countdown graphics (safety removal)
        games.remove_ui_element("COUNTDOWN_BG", event.player_id)
        games.remove_ui_element("COUNTDOWN_NUM", event.player_id)

        local board_info = tourney_boards[player_area][entry["tourney_board"]]

        Net.message_player(event.player_id,
            "There is currently " ..
            #board_info.active_tournaments .. "/8 in your tournament queue. What would you like to do?")

        local result = await(Async.quiz_player(event.player_id, "Backfill", "Wait"))

        if result == 0 then
            -- Player requested backfill
            local board_background_setup_info = get_board_background_and_grid(object)
            local tournament_participants = initialize_tournament_participants(
                board_info.active_tournaments, true)
            local board_id = entry["tourney_board"]

            -- Start all active tournaments
            for _, player in next, board_info.active_tournaments do
                start_and_show_tourney(player["player_id"], board_background_setup_info,
                    tournament_participants, board_id, true)
            end

            -- Once all tournaments are initialized, activate framework
            await(Async.sleep(13.85))
            games.activate_framework(event.player_id)
            Net.lock_player_input(event.player_id)
        elseif result == 1 then
            -- Player requested to wait, restart countdown
            await(show_countdown(event.player_id, 10))
        end
    end)
end)


-- Example event hook for when a player interacts to start/join a tournament
Net:on("tourney_interact", function(event)
    return async(function()
        await(join_or_start_tournament(event))
    end)
end)

return Tourney
