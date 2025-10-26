local debug = require("scripts/debug-utils")
local tourney_table = require("scripts/net-game-tourney/table-templates/tournament-table")

local change_area_emitter = Net.EventEmitter.new()
local tourney_emitter     = Net.EventEmitter.new()
local tourney_state       = Net.EventEmitter.new()

local Tourney = {
    player_history      = {},
    online_players      = {},
    offline_players     = {},
    tournaments         = {},
}

Net:on("player_transfer_area", function(event)
    local player_current_area = Net.get_player_area(event.player_id)
    Tourney.set_player_area(event.player_id, player_current_area)
end)

Net:on("player_join", function(event)
    local player_secret = Net.get_player_secret(event.player_id)
    local player_current_area = Net.get_player_area(event.player_id)
    Tourney.set_player_area(event.player_id, player_current_area)
    --debug.dprint("PLAYER JOIN", "Online players is now : " ..tostring(Tourney.online_players))
    --debug.dprint("PLAYER JOIN", "Offline players is now : " ..tostring(Tourney.offline_players))

    if Tourney.player_history[player_secret] == nil then
        Tourney.player_history[player_secret] = {player_id = event.player_id, current_area = player_current_area}
        --print("[PLAYER JOIN] Player secret added to player history, this is the players secret : ".. player_secret .. "Player history is now : " ..tostring(Tourney.player_history))
    end   
end)

Net:on("player_disconnect", function(event)
    local player_secret = Net.get_player_secret(event.player_id)
    Tourney.online_players[player_secret] = nil
    Tourney.offline_players[player_secret] = {last_player_id = event.player_id, current_area = "NONE"}
    
    --print("[PLAYER DISCONNECT] Online players is now : " ..tostring(Tourney.online_players))
    --print("[PLAYER DISCONNECT] Offline players is now : " ..tostring(Tourney.offline_players))
end)

change_area_emitter:on("player_changed_area", function(event)
    --print("[PLAYER CHANGED AREA] Player " .. event.player_id .. "'s " .. "Current area is now " .. event.current_area)
end)

function Tourney.set_player_area(player_id, player_current_area)
    local player_current_area = Net.get_player_area(player_id)
    local player_secret = Net.get_player_secret(player_id)
    if Tourney.online_players[player_secret] == nil then
        Tourney.online_players[player_secret] = { player_id = player_id, current_area = player_current_area }
        change_area_emitter:emit("player_changed_area", { player_id = player_id, current_area = player_current_area })
    end
    if Tourney.online_players[player_secret]["current_area"] ~= nil then
        if Tourney.online_players[player_secret].current_area ~= player_current_area then
        Tourney.online_players[player_secret] = { player_id = player_id, current_area = player_current_area }
        change_area_emitter:emit("player_changed_area", { player_id = player_id, current_area = player_current_area })
        end
    end
end

function Tourney.start_tourney_state_initial(participants, host_id, area_id, board_id, init_matches, started_battles_immediately)
    local copy = tourney_table
    local p_list = {}
    p_list = participants
    local host = ""
    host = host_id
    local initial_matches = {}
    if #init_matches >0 then
        initial_matches = init_matches
    end
    local len = #Tourney.tournaments+1
    local set_to_round_one = false
    if started_battles_immediately ~= nil then 
    set_to_round_one = started_battles_immediately
    end
    local status = "ACTIVE"
    if set_to_round_one then
        status = "round_1"
    end

    local modifiers = {tournament_id = len, area_id = area_id, host_id = host, participants = p_list, board_id = board_id, status = status, round_1_matches = {matchups = initial_matches, winners = {}, losers = {}}}
    copy = tourney_table.modify_values(copy, modifiers)
    --print(Tourney.tournaments[#Tourney.tournaments])
    tourney_state:emit("init_tourney_state", copy)
end

function Tourney.check_if_they_exist(player1_id, player2_id, player_ran, player1_health, player2_health)
    for i, tourney in next, Tourney.tournaments do
        if Tourney.tournaments[i].status == "ACTIVE" then 
            print("Havent started tourney yet, but tourney has been initialized")
            print("Please start round_1 by setting this tournaments status to round_{x} " ,"NOTE: {x} can be = 1, 2, or 3")
            return
        end
        if string.find(Tourney.tournaments[i].status, "round_") then
            local matchups_by_round_status = Tourney.tournaments[i][Tourney.tournaments[i].status.."_matches"]
            for j, match in next, matchups_by_round_status do
                for k, pair in next,match do 
                    if player2_id == nil and player1_id ~= nil and player_ran == true then
                        if pair["player1_id"].player_id == player1_id or pair["player2_id"].player_id == player1_id then
                            if pair["player1_id"].player_id == player1_id then
                                print("[PAIR FOUND IN] :", pair["player1_id"])
                            tourney_state:emit("set_round_results", {losers = {[pair["player1_id"]["player_spot"]] = pair["player1_id"]}, winners = {[pair["player2_id"]["player_spot"]]= pair["player2_id"]}})
                            end
                            if pair["player2_id"].player_id == player1_id then
                                print("[PAIR FOUND IN] :", pair["player2_id"])
                            tourney_state:emit("set_round_results", {losers = {[pair["player2_id"]["player_spot"]]= pair["player2_id"]},winners = {[pair["player1_id"]["player_spot"]]= pair["player1_id"]}})
                            end
                        print("player2_id is nil and player1_id is not and player1_id ran away and they exist in this tournament")
                        end
                    end
                    if player1_id == nil and player2_id ~= nil and (player1_health <= 0 or player1_health == nil) then
                        print("player1_id is nil, while player2_id isnt nil and player health is either not there or is less than or equal to 0 so the player lost to player2_id fair and square")
                        if pair["player1_id"].player_id == player2_id then
                        print("player1_id is nil, while player2_id isnt nil and player health is either not there or is less than or equal to 0 so the player lost to player2_id fair and square")
                        end
                        if pair["player2_id"].player_id == player2_id then
                        print("player1_id is nil, while player2_id isnt nil and player health is either not there or is less than or equal to 0 so the player lost to player2_id fair and square")
                        end
                    end
                    if player1_id ~= nil and player2_id ~= nil then
                        if player1_health <= 0 then
                            if pair["player1_id"].player_id == player1_id then
                            print("Both players ids arent nil")
                            tourney_state:emit("set_round_results", {losers = {[pair["player1_id"]["player_spot"]]= pair["player1_id"]},winners = {[pair["player2_id"]["player_spot"]]= pair["player2_id"]}})    
                            print("Player1_id lost")    
                            end
                            if pair["player2_id"].player_id == player1_id then
                            print("Both players ids arent nil")
                            tourney_state:emit("set_round_results", {losers = {[pair["player2_id"]["player_spot"]]= pair["player2_id"]},winners = {[pair["player1_id"]["player_spot"]]= pair["player1_id"]}})
                            print("Player1_id lost")
                            end
                        else 
                            if pair["player1_id"].player_id == player2_id then
                                tourney_state:emit("set_round_results", {losers = {[pair["player1_id"]["player_spot"]]= pair["player1_id"]},winners = {[pair["player2_id"]["player_spot"]]= pair["player2_id"]}})
                                print("Player2_id lost")
                            end
                            if pair["player2_id"].player_id == player2_id then
                                tourney_state:emit("set_round_results", {losers = {[pair["player2_id"]["player_spot"]]= pair["player2_id"]},winners = {[pair["player1_id"]["player_spot"]]= pair["player1_id"]}})
                                print("Player2_id lost")
                            end
                        end
                    end
                end
            end
        end
    end
            --if Tourney.tournaments[i][Tourney.tournaments[i].status.."_matches"].matchups["player1_id"].player_id == player1_id or Tourney.tournaments[i][Tourney.tournaments[i].status.."_matches"].matchups["player2_id"]["player_id"] == player1_id then
            --        print("Player1_id was found in tournament"..i.."in match_id group"..)
            --        local status = tostring(Tourney.tournaments[i].status.."_matches")
            --        return {participant_pairs = matchups_by_round_status, tournament_id = i, match_id = match_id, status = status, winners = {}, losers = {}}
            --    end
            --if player2_id ~= nil then 
            --        if Tourney.tournaments[i][tostring(Tourney.tournaments[i].status).."_matches"].matchups["player1_id"]["player_id"] == player2_id or Tourney.tournaments[i][Tourney.tournaments[i].status.."_matches"].matchups.matchups["player2_id"]["player_id"] == player2_id then
            --        local status = tostring(Tourney.tournaments[i].status.."_matches")
            --        return {participant_pairs = matchups_by_round_status, tournament_id = i, match_id = match_id, status = status, winners = {}, losers = {}} 
            --        end
           -- end
end

function Tourney.set_round_results(tourney_id, round_name, match_id, winner_info, loser_info)
--print(winner_info)
--print(loser_info)
--for i, n in next, winner_info do
--    print(n)
--end
--    tourney_state:emit("set_round_results",{tourney_id = tourney_id, round_name = round_name, match_id = match_id, winners = {winner_info}, losers =  loser_info})
end

-- TOURNEY STUFF --
tourney_state:on("init_tourney_state", function (event)
    local Tourney_id = event.tournament_id
    --print("[INITIALIZING TOURNEY STATE]"..tostring(event))
    Tourney.tournaments[Tourney_id] = event
    --print(Tourney.tournaments[Tourney_id])
    --print(event)
end)

tourney_state:on("check_if_exists", function(event)
    print(event)
end)

tourney_state:on("set_round_results", function (event)
    print(event)
end)

tourney_emitter:on("in_tourney_battle", function(event)
    --print("[IN TOURNEY BATTLE] started a tournament fight, here is the Participant's that are in battle at the moment..." .. tostring(event) .. "Do note not all Participants will be human players, so make sure to handle this properly based on if its a human or a bot!")
end)

tourney_emitter:on("leave_tourney_battle", function(event)
    --print("[LEAVE TOURNEY BATTLE] tourney fight just ended here are the Participants... " .. tostring(event) .. "Do note not all Participants will be human players, so make sure to handle this properly based on if its a human or a bot!")
end)

function Tourney.end_tourney_battle(player1_id, player2_id)
    --print(player1_id, player2_id)
end
 
function Tourney.start_tourney_battle(player1_id, player2_id, tourney_id)
    --print(player1_id)
    --print(player2_id)
    --print(tourney_id)
    --Tourney.matchups_in_battle[#Tourney.matchups_in_battle+1] = {player1_id = player1_id, player2_id = player2_id, results = {}}
    --print(Tourney.matchups_in_battle)
    --tourney_emitter:emit("in_tourney_battle", {matchup_id = #Tourney.matchups_in_battle, matchup = Tourney.matchups_in_battle[#Tourney.matchups_in_battle]})
end

return Tourney
