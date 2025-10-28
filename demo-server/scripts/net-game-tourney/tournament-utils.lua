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

-- ADD: Calculate positions based on actual match pairings
function TournamentUtils.calculate_round_positions(tournament, round_number)
    local mug_pos = require("scripts/net-game-tourney/mug-pos")
    local positions = {}
    
    if round_number == 1 then
        -- Round 1: Pair initial positions 1-2, 3-4, 5-6, 7-8
        local matches = tournament.matches or {}
        
        for match_index, match in ipairs(matches) do
            local winner = match.winner
            local loser = match.loser
            
            if winner and loser then
                -- Find original positions of winner and loser
                local winner_initial_pos = nil
                local loser_initial_pos = nil
                
                for i, participant in ipairs(tournament.participants) do
                    if participant.player_id == winner.player_id then
                        winner_initial_pos = i
                    elseif participant.player_id == loser.player_id then
                        loser_initial_pos = i
                    end
                end
                
                -- Assign winner to round1_winners position based on match pairing
                if winner_initial_pos and mug_pos.round1_winners[match_index] then
                    positions[winner_initial_pos] = mug_pos.round1_winners[match_index]
                end
                
                -- Loser stays in initial position
                if loser_initial_pos and mug_pos.initial[loser_initial_pos] then
                    positions[loser_initial_pos] = mug_pos.initial[loser_initial_pos]
                end
            end
        end
        
        -- Fill in any missing positions (for participants not in completed matches)
        for i, participant in ipairs(tournament.participants) do
            if not positions[i] and mug_pos.initial[i] then
                positions[i] = mug_pos.initial[i]
            end
        end
        
    elseif round_number == 2 then
        -- Round 2: Pair round1_winners positions 1-2, 3-4
        local round1_results = tournament.round_results[1] or {}
        local current_matches = tournament.matches or {}
        
        -- First, place all round1 winners in their round1 positions
        for _, round1_result in ipairs(round1_results) do
            local winner = round1_result.winner
            local match_index = round1_result.match
            
            if winner and match_index then
                local winner_initial_pos = nil
                for i, participant in ipairs(tournament.participants) do
                    if participant.player_id == winner.player_id then
                        winner_initial_pos = i
                        break
                    end
                end
                
                if winner_initial_pos and mug_pos.round1_winners[match_index] then
                    positions[winner_initial_pos] = mug_pos.round1_winners[match_index]
                end
            end
        end
        
        -- Then update round2 winners to their new positions
        for match_index, match in ipairs(current_matches) do
            local winner = match.winner
            local loser = match.loser
            
            if winner and loser then
                -- Find which round1 position this winner came from
                local winner_round1_match = nil
                for _, round1_result in ipairs(round1_results) do
                    if round1_result.winner and round1_result.winner.player_id == winner.player_id then
                        winner_round1_match = round1_result.match
                        break
                    end
                end
                
                -- Assign winner to round2_winners position based on match pairing
                if winner_round1_match and mug_pos.round2_winners[match_index] then
                    local winner_initial_pos = nil
                    for i, participant in ipairs(tournament.participants) do
                        if participant.player_id == winner.player_id then
                            winner_initial_pos = i
                            break
                        end
                    end
                    
                    if winner_initial_pos then
                        positions[winner_initial_pos] = mug_pos.round2_winners[match_index]
                    end
                end
                
                -- Loser stays in round1 position
                local loser_initial_pos = nil
                for i, participant in ipairs(tournament.participants) do
                    if participant.player_id == loser.player_id then
                        loser_initial_pos = i
                        break
                    end
                end
                
                if loser_initial_pos then
                    -- Keep loser in their round1 position
                    for _, round1_result in ipairs(round1_results) do
                        if round1_result.winner and round1_result.winner.player_id == loser.player_id then
                            if mug_pos.round1_winners[round1_result.match] then
                                positions[loser_initial_pos] = mug_pos.round1_winners[round1_result.match]
                            end
                            break
                        end
                    end
                end
            end
        end
        
    elseif round_number == 3 then
        -- Champion round
        local champion = tournament.winners[1]
        local round2_results = tournament.round_results[2] or {}
        local round1_results = tournament.round_results[1] or {}
        
        if champion then
            -- Place champion
            local champion_initial_pos = nil
            for i, participant in ipairs(tournament.participants) do
                if participant.player_id == champion.player_id then
                    champion_initial_pos = i
                    break
                end
            end
            
            if champion_initial_pos then
                positions[champion_initial_pos] = mug_pos.champion[1]
            end
            
            -- Place runner-up (loser in final match)
            local final_match = tournament.matches and tournament.matches[1]
            if final_match and final_match.loser then
                local runner_up_initial_pos = nil
                for i, participant in ipairs(tournament.participants) do
                    if participant.player_id == final_match.loser.player_id then
                        runner_up_initial_pos = i
                        break
                    end
                end
                
                if runner_up_initial_pos and mug_pos.round2_winners[2] then
                    positions[runner_up_initial_pos] = mug_pos.round2_winners[2]
                end
            end
            
            -- Place semi-finalists (losers in round 2)
            for _, round2_result in ipairs(round2_results) do
                local loser = round2_result.loser
                if loser and loser.player_id ~= (final_match and final_match.loser and final_match.loser.player_id) then
                    local semi_finalist_initial_pos = nil
                    for i, participant in ipairs(tournament.participants) do
                        if participant.player_id == loser.player_id then
                            semi_finalist_initial_pos = i
                            break
                        end
                    end
                    
                    if semi_finalist_initial_pos then
                        -- Find which round1 position they came from to determine placement
                        for _, round1_result in ipairs(round1_results) do
                            if round1_result.winner and round1_result.winner.player_id == loser.player_id then
                                if round1_result.match <= 2 then
                                    positions[semi_finalist_initial_pos] = mug_pos.round1_winners[1] or mug_pos.round1_winners[2]
                                else
                                    positions[semi_finalist_initial_pos] = mug_pos.round1_winners[3] or mug_pos.round1_winners[4]
                                end
                                break
                            end
                        end
                    end
                end
            end
            
            -- Place quarter-finalists (losers in round 1)
            for _, round1_result in ipairs(round1_results) do
                local loser = round1_result.loser
                if loser then
                    local quarter_finalist_initial_pos = nil
                    for i, participant in ipairs(tournament.participants) do
                        if participant.player_id == loser.player_id then
                            quarter_finalist_initial_pos = i
                            break
                        end
                    end
                    
                    if quarter_finalist_initial_pos and mug_pos.initial[quarter_finalist_initial_pos] then
                        positions[quarter_finalist_initial_pos] = mug_pos.initial[quarter_finalist_initial_pos]
                    end
                end
            end
        end
    end
    
    return positions
end

return TournamentUtils