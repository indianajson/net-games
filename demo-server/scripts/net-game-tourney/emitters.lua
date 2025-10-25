local change_area_emitter = Net.EventEmitter.new()
local tourney_emitter     = Net.EventEmitter.new()


local Tourney = {
    player_history      = {},
    online_players      = {},
    offline_players     = {},
    matchups_in_battle  = {},
}

Net:on("player_transfer_area", function(event)
    local player_current_area = Net.get_player_area(event.player_id)
    Tourney.set_player_area(event.player_id, player_current_area)
end)

Net:on("player_join", function(event)
    local player_secret = Net.get_player_secret(event.player_id)
    local player_current_area = Net.get_player_area(event.player_id)
    Tourney.set_player_area(event.player_id, player_current_area)
    if Tourney.player_history[player_secret] == nil then
    Tourney.player_history[player_secret] = {player_id = event.player_id, current_area = player_current_area}
    print("[PLAYER JOIN] Player secret added to player history, this is the players secret : ".. player_secret .. "Player history is now : " ..tostring(Tourney.player_history))
    end
    print("[PLAYER JOIN] Online players is now : " ..tostring(Tourney.online_players))
    print("[PLAYER JOIN] Offline players is now : " ..tostring(Tourney.offline_players))
    
end)

Net:on("player_disconnect", function(event)
    local player_secret = Net.get_player_secret(event.player_id)
    Tourney.online_players[player_secret] = nil
    Tourney.offline_players[player_secret] = {last_player_id = event.player_id, current_area = "NONE"}
    
    print("[PLAYER DISCONNECT] Online players is now : " ..tostring(Tourney.online_players))
    print("[PLAYER DISCONNECT] Offline players is now : " ..tostring(Tourney.offline_players))
end)

change_area_emitter:on("player_changed_area", function(event)
    print("[PLAYER CHANGED AREA] Player " .. event.player_id .. "'s " .. "Current area is now " .. event.current_area)
end)

tourney_emitter:on("in_tourney_battle", function(event)
    print("[IN TOURNEY BATTLE] started a tournament fight, here is the Participant's that are in battle at the moment..." .. tostring(event) .. "Do note not all Participants will be human players, so make sure to handle this properly based on if its a human or a bot!")
end)

tourney_emitter:on("leave_tourney_battle", function(event)
    print("[LEAVE TOURNEY BATTLE] tourney fight just ended here are the Participants... " .. tostring(event) .. "Do note not all Participants will be human players, so make sure to handle this properly based on if its a human or a bot!")
end)

function Tourney.end_tourney_battle(player1_id, player2_id)
    print(player1_id, player2_id)
end
 
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

function Tourney.start_tourney_battle(player1_id, player2_id)
    print(player1_id)
    print(player2_id)
    Tourney.matchups_in_battle[#Tourney.matchups_in_battle+1] = {player1_id = player1_id, player2_id = player2_id, results = {}}
    print(Tourney.matchups_in_battle)
    tourney_emitter:emit("in_tourney_battle", {matchup_id = #Tourney.matchups_in_battle, matchup = Tourney.matchups_in_battle[#Tourney.matchups_in_battle]})
end

return Tourney
