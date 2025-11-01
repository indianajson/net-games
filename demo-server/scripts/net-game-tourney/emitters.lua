local debug = require("scripts/debug-utils")
local TournamentState = require("scripts/net-game-tourney/tournament-state")
local TourneyUtils = require("scripts/net-game-tourney/tournament-utils")

local change_area_emitter = Net.EventEmitter.new()
local tourney_emitter = Net.EventEmitter.new()
local tournament_ui_emitter = Net.EventEmitter.new()

function async(p) local co = coroutine.create(p) return Async.promisify(co) end
function await(v) return Async.await(v) end

local Tourney = {
    player_history = {},
    online_players = {},
    offline_players = {},
    matchups_in_battle = {},
    tournaments = {},
    players_waiting = {},
    active_tournaments = {},
    
    -- Expose the event emitters
    change_area_emitter = change_area_emitter,
    tourney_emitter = tourney_emitter,
    tournament_ui_emitter = tournament_ui_emitter
}

-- UI Position and Animation Management
Tourney.ui_positions = {}
Tourney.ui_animations = {}

function Tourney.set_ui_position(element_name, x, y, z)
    Tourney.ui_positions[element_name] = {x = x, y = y, z = z or 0}
    tournament_ui_emitter:emit("ui_position_changed", {element = element_name, position = Tourney.ui_positions[element_name]})
end

function Tourney.set_ui_animation(element_name, animation_state)
    Tourney.ui_animations[element_name] = animation_state
    tournament_ui_emitter:emit("ui_animation_changed", {element = element_name, animation = animation_state})
end

--function Tourney.closed_tourney_board(tournament_id)
--    tournament_ui_emitter:emit("closed_tourney_board", {tournament_id = tournament_id})
--end

-- Enhanced battle result handling
function Tourney.handle_battle_result(event)
    local battle_data = event
    local matchup_id = nil
    
    -- Find which matchup this battle belongs to
    for id, matchup in ipairs(Tourney.matchups_in_battle) do
        if matchup.player1_id == battle_data.player_id or matchup.player2_id == battle_data.player_id then
            matchup_id = id
            matchup.results = battle_data
            break
        end
    end
    
    if matchup_id then
        tourney_emitter:emit("battle_completed", {
            matchup_id = matchup_id,
            matchup = Tourney.matchups_in_battle[matchup_id],
            battle_data = battle_data
        })
        
        -- Remove from active battles
        Tourney.matchups_in_battle[matchup_id] = nil
    end
end

-- Enhanced tournament battle starter with NPC support
function Tourney.start_tourney_battle(player1_id, player2_id, tournament_id, match_index)
    -- Prevent duplicate battles
    for _, m in ipairs(Tourney.matchups_in_battle) do
        if (m.player1_id == player1_id and m.player2_id == player2_id) or
           (m.player1_id == player2_id and m.player2_id == player1_id) then
            print("[Tourney] Duplicate battle detected, skipping.")
            return
        end
    end

    local id = #Tourney.matchups_in_battle + 1
    Tourney.matchups_in_battle[id] = {
        player1_id = player1_id,
        player2_id = player2_id,
        tournament_id = tournament_id,
        match_index = match_index,
        results = {}
    }
    
    tourney_emitter:emit("in_tourney_battle", {
        matchup_id = id,
        matchup = Tourney.matchups_in_battle[id]
    })
    
    return id
end

-- NPC vs NPC battle simulation - now properly records results
function Tourney.simulate_npc_battle(npc1_id, npc2_id, tournament_id, match_index)
    return async(function()
        -- Simulate battle duration (no timeout for player battles)
        await(Async.sleep(math.random(3, 8)))
        
        -- Simple random winner selection (can be enhanced with NPC stats)
        local winner_id = math.random(1, 2) == 1 and npc1_id or npc2_id
        local loser_id = winner_id == npc1_id and npc2_id or npc1_id
        
        local battle_result = {
            player_id = winner_id,
            health = math.random(50, 100),
            score = math.random(1000, 5000),
            time = math.random(30, 180),
            ran = false,
            emotion = math.random(1, 5),
            turns = math.random(5, 20),
            enemies = {}
        }
        
        -- Get tournament and match info to record the result
        local tournament = TournamentState.get_tournament(tournament_id)
        if tournament and tournament.matches and tournament.matches[match_index] then
            local match = tournament.matches[match_index]
            local winner = match.player1.player_id == winner_id and match.player1 or match.player2
            local loser = match.player1.player_id == loser_id and match.player1 or match.player2
            
            -- Record the battle result directly in tournament state
            TournamentState.record_battle_result(tournament_id, match_index, winner, loser)
            print("[Tourney] NPC battle result recorded: " .. winner_id .. " defeated " .. loser_id)
        end
        
        tourney_emitter:emit("battle_completed", {
            matchup_id = "npc_sim_" .. tournament_id .. "_" .. match_index,
            matchup = {player1_id = npc1_id, player2_id = npc2_id},
            battle_data = battle_result,
            tournament_id = tournament_id,
            match_index = match_index
        })
        
        return battle_result
    end)
end

-- Existing functions remain but with enhanced error handling
function Tourney.remove_player_from_all_tables(pid, tbl)
    tbl = tbl or Tourney
    for k, v in pairs(tbl) do
        if k ~= "player_history" and k ~= "offline_players" and k ~= "active_tournaments" then
            if type(v) == "table" then
                Tourney.remove_player_from_all_tables(pid, v)
            elseif v == pid then
                tbl[k] = nil
            end
        end
    end
end

function Tourney.set_player_area(pid, area)
    local secret = Net.get_player_secret(pid)
    if not Tourney.player_history[secret] then
        Tourney.player_history[secret] = { player_id = pid, current_area = area }
    end
    Tourney.player_history[secret].current_area = area
    change_area_emitter:emit("player_changed_area", { player_id = pid, current_area = area })
end

-- Event handlers for UI customization
tournament_ui_emitter:on("ui_position_changed", function(event)
    print("[Tournament UI] Position changed for " .. event.element .. ": " .. 
          tostring(event.position.x) .. "," .. tostring(event.position.y) .. "," .. tostring(event.position.z))
end)

tournament_ui_emitter:on("ui_animation_changed", function(event)
    print("[Tournament UI] Animation changed for " .. event.element .. ": " .. event.animation)
end)

--tournament_ui_emitter:on("closed_tourney_board", function(event)
--    local tourney_id = event.tournament_id
--    local tournament = TournamentState.get_tournament(tourney_id)
--    local state = tournament.state
--    local start_next_round = TourneyUtils.ask_host_about_next_round(event.tournament_id, state)
--    
--    print(event)
--end)

-- Existing event handlers remain...
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
    Tourney.remove_player_from_all_tables(event.player_id)
end)

return Tourney