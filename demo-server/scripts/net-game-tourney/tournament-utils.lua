local TournamentUtils = {}
local games = require("scripts/net-games/framework")

-- Freeze all human players in a tournament
function TournamentUtils.freeze_all_tournament_players(tournament_id, TournamentState)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return end
    
    for _, participant in ipairs(tournament.participants) do
        if not string.find(participant.player_id, ".zip") then
            Net.lock_player_input(participant.player_id)
            print("[tourney] Frozen player: " .. participant.player_id)
        end
    end
end

-- Unfreeze specific players
function TournamentUtils.unfreeze_players(player_ids)
    for _, player_id in ipairs(player_ids) do
        if not string.find(player_id, ".zip") then
            Net.unlock_player_input(player_id)
            print("[tourney] Unfrozen player: " .. player_id)
        end
    end
end

-- Freeze specific players
function TournamentUtils.freeze_players(player_ids)
    for _, player_id in ipairs(player_ids) do
        if not string.find(player_id, ".zip") then
            Net.lock_player_input(player_id)
            print("[tourney] Frozen player: " .. player_id)
        end
    end
end

-- Process battle results and determine winner/loser with proper NPC battle detection
function TournamentUtils.process_battle_results(event, tournament_id, match_index, TournamentState)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return nil, nil end
    
    local match = tournament.matches[match_index]
    if not match then return nil, nil end
    
    local player1_id = match.player1.player_id
    local player2_id = match.player2.player_id
    
    -- Check if player ran away
    if event.ran then
        -- The player who ran is the loser
        if event.player_id == player1_id then
            return match.player2, match.player1  -- winner, loser
        else
            return match.player1, match.player2  -- winner, loser
        end
    end
    
    -- Check if this is a player vs NPC battle
    local is_player1_npc = string.find(player1_id, ".zip")
    local is_player2_npc = string.find(player2_id, ".zip")
    
    -- For player vs NPC battles, check if player survived and enemies are empty/nil
    if (is_player1_npc and not is_player2_npc and event.player_id == player2_id) or
       (is_player2_npc and not is_player1_npc and event.player_id == player1_id) then
        -- Player vs NPC battle
        if event.health > 0 and (event.enemies == nil or #event.enemies == 0) then
            -- Player won against NPC
            if event.player_id == player1_id then
                return match.player1, match.player2  -- winner, loser
            else
                return match.player2, match.player1  -- winner, loser
            end
        else
            -- Player lost to NPC
            if event.player_id == player1_id then
                return match.player2, match.player1  -- winner, loser
            else
                return match.player1, match.player2  -- winner, loser
            end
        end
    end
    
    -- For PvP battles, use the standard logic
    -- Check battle results
    if event.enemies and #event.enemies > 0 then
        -- There are enemies, check if any survived
        local enemy_survived = false
        for _, enemy in ipairs(event.enemies) do
            if enemy.health > 0 then
                enemy_survived = true
                break
            end
        end
        
        if enemy_survived then
            -- Enemies survived, player lost
            if event.player_id == player1_id then
                return match.player2, match.player1  -- winner, loser
            else
                return match.player1, match.player2  -- winner, loser
            end
        else
            -- All enemies defeated, player won
            if event.player_id == player1_id then
                return match.player1, match.player2  -- winner, loser
            else
                return match.player2, match.player1  -- winner, loser
            end
        end
    else
        -- No enemy data but player didn't run - check health to determine winner
        if event.health > 0 then
            -- Player survived, they won
            if event.player_id == player1_id then
                return match.player1, match.player2  -- winner, loser
            else
                return match.player2, match.player1  -- winner, loser
            end
        else
            -- Player died, they lost
            if event.player_id == player1_id then
                return match.player2, match.player1  -- winner, loser
            else
                return match.player1, match.player2  -- winner, loser
            end
        end
    end
end

-- Ask host if they want to start next round (with host elimination check)
function TournamentUtils.ask_host_about_next_round(tournament_id, TournamentState)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament or not tournament.host_player_id then 
            print("[tourney] No tournament or host found")
            return false 
        end
        
        local current_host = tournament.host_player_id
        
        -- Check if current host is still connected and is a real player
        if not Net.is_player(current_host) or string.find(current_host, ".zip") then
            print("[tourney] Host not available or is NPC, auto-advancing to next round")
            return true
        end
        
        Net.message_player(current_host, "Round " .. tournament.current_round .. " completed!")
        await(Async.sleep(0.1)) -- Wait for message to be read
        
        -- Only ask about next round if tournament isn't completed (after 3 rounds)
        if tournament.current_round >= 3 then
            print("[tourney] Tournament completed after 3 rounds, not asking host")
            return true
        end
        
        local result = await(Async.question_player(current_host, "Start next round?"))
        
        -- DEBUG: Print the actual result from the question
        print("[tourney] Host " .. current_host .. " responded: " .. tostring(result))
        
        -- FIXED: Correct response logic - 0 = Yes, 1 = No
        if result == 1 then
            return true  -- Host wants to continue
        else
            return false -- Host wants to end tournament
        end
    end)
end

-- Get board background and grid information
function TournamentUtils.get_board_background_and_grid(object, TiledUtils, constants)
    if not TiledUtils.check_custom_prop_validity(object.custom_properties, "Board Background") then return end
    local bg = object.custom_properties["Board Background"]
    local p = constants.bracket_background_path
    return p[bg] or p.red_orange_bn4
end

-- FIXED: Enhanced positioning logic with proper round 3 champion movement
function TournamentUtils.calculate_round_positions(tournament, round_number)
    local mug_pos = require("scripts/net-game-tourney/mug-pos")
    local positions = {}
    
    -- Helper function to find initial index of participant
    local function find_initial_index(participant)
        for i, p in ipairs(tournament.participants) do
            if p.player_id == participant.player_id then
                return i
            end
        end
        return nil
    end
    
    if round_number == 1 then
        -- Round 1: 4 winners move up, 4 losers stay at bottom
        local matches = tournament.matches or {}
        
        -- Start with all participants in initial positions
        for i = 1, #tournament.participants do
            if mug_pos.initial[i] then
                positions[i] = mug_pos.initial[i]
            end
        end
        
        -- Move winners to their new positions
        for match_index, match in ipairs(matches) do
            if match.completed and match.winner then
                local winner_index = find_initial_index(match.winner)
                
                if winner_index and mug_pos.round1_winners[match_index] then
                    positions[winner_index] = mug_pos.round1_winners[match_index]
                end
                -- Losers stay in their initial positions (already set above)
            end
        end
        
    elseif round_number == 2 then
        -- Round 2: 2 winners move up, 2 losers stay in round1 positions, 4 round1 losers stay at bottom
        local current_matches = tournament.matches or {}
        local round1_results = tournament.round_results[1] or {}
        
        -- First, place all round1 losers in initial positions
        for _, round1_result in ipairs(round1_results) do
            local loser = round1_result.loser
            if loser then
                local loser_index = find_initial_index(loser)
                if loser_index and mug_pos.initial[loser_index] then
                    positions[loser_index] = mug_pos.initial[loser_index]
                end
            end
        end
        
        -- Place round1 winners in their round1 positions
        for _, round1_result in ipairs(round1_results) do
            local winner = round1_result.winner
            local match_index = round1_result.match
            
            if winner and match_index then
                local winner_index = find_initial_index(winner)
                if winner_index and mug_pos.round1_winners[match_index] then
                    positions[winner_index] = mug_pos.round1_winners[match_index]
                end
            end
        end
        
        -- Now update for round 2 results
        for match_index, match in ipairs(current_matches) do
            if match.completed then
                local winner_index = find_initial_index(match.winner)
                local loser_index = find_initial_index(match.loser)
                
                -- Round 2 winners move to round2 positions
                if winner_index and mug_pos.round2_winners[match_index] then
                    positions[winner_index] = mug_pos.round2_winners[match_index]
                end
                
                -- Round 2 losers stay in their round1 positions (already set above)
            end
        end
        
    elseif round_number == 3 then
        -- FIXED: Round 3 - Only the champion moves to the top position
        -- All other participants (runner-up, semi-finalists, quarter-finalists) stay in their current positions
        
        local current_matches = tournament.matches or {}
        local round1_results = tournament.round_results[1] or {}
        local round2_results = tournament.round_results[2] or {}
        
        -- Start with all participants in their current positions (from round 2)
        -- First get the current state positions
        local current_positions = TournamentState.get_current_state_positions(tournament.tournament_id) or {}
        
        -- If no current positions, build from round results
        if not current_positions or next(current_positions) == nil then
            current_positions = {}
            
            -- Place round1 losers in initial positions
            for _, round1_result in ipairs(round1_results) do
                local loser = round1_result.loser
                if loser then
                    local loser_index = find_initial_index(loser)
                    if loser_index and mug_pos.initial[loser_index] then
                        current_positions[loser_index] = mug_pos.initial[loser_index]
                    end
                end
            end
            
            -- Place round1 winners who lost in round2 in round1 positions
            for _, round2_result in ipairs(round2_results) do
                local loser = round2_result.loser
                if loser then
                    -- Find which round1 match this participant won
                    for _, round1_result in ipairs(round1_results) do
                        if round1_result.winner and round1_result.winner.player_id == loser.player_id then
                            local loser_index = find_initial_index(loser)
                            if loser_index and mug_pos.round1_winners[round1_result.match] then
                                current_positions[loser_index] = mug_pos.round1_winners[round1_result.match]
                            end
                            break
                        end
                    end
                end
            end
            
            -- Place round2 winners in round2 positions
            for _, round2_result in ipairs(round2_results) do
                local winner = round2_result.winner
                local match_index = round2_result.match
                
                if winner then
                    local winner_index = find_initial_index(winner)
                    if winner_index and mug_pos.round2_winners[match_index] then
                        current_positions[winner_index] = mug_pos.round2_winners[match_index]
                    end
                end
            end
        end
        
        -- Copy current positions as starting point
        for i, pos in pairs(current_positions) do
            positions[i] = pos
        end
        
        -- FIXED: Only move the champion to the top position
        for _, match in ipairs(current_matches) do
            if match.completed then
                local champion_index = find_initial_index(match.winner)
                
                -- Champion moves to top position
                if champion_index and mug_pos.champion[1] then
                    positions[champion_index] = mug_pos.champion[1]
                    print("[tourney] Moving champion " .. match.winner.player_id .. " to top position")
                end
                
                -- Runner-up stays in their round2 position (no change)
                local runner_up_index = find_initial_index(match.loser)
                if runner_up_index then
                    print("[tourney] Runner-up " .. match.loser.player_id .. " stays in position")
                end
            end
        end
    end
    
    -- Fill any missing positions with initial positions as fallback
    for i = 1, #tournament.participants do
        if not positions[i] and mug_pos.initial[i] then
            positions[i] = mug_pos.initial[i]
        end
    end
    
    return positions
end

return TournamentUtils