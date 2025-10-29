local TournamentUtils = {}
local games = require("scripts/net-games/framework")
local TournamentState = require("scripts/net-game-tourney/tournament-state")

function async(p) local co = coroutine.create(p) return Async.promisify(co) end
function await(v) return Async.await(v) end

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

function TournamentUtils.ask_host_about_next_round(tournament_id, TournamentState)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then 
            print("[tourney] No tournament found")
            return true  -- Auto-advance if tournament doesn't exist
        end
        
        -- Check if there are any real players left to be host
        local has_real_players = false
        for _, participant in ipairs(tournament.participants) do
            if not string.find(participant.player_id, ".zip") and Net.is_player(participant.player_id) then
                has_real_players = true
                break
            end
        end
        
        if not has_real_players then
            print("[tourney] No real players left, auto-advancing to next round")
            return true
        end
        
        if not tournament.host_player_id then 
            print("[tourney] No host found, auto-advancing to next round")
            return true 
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

-- Helper function to find participant index
function TournamentUtils.find_participant_index(tournament, player_id)
    for i, participant in ipairs(tournament.all_participants) do
        if participant.player_id == player_id then
            return i
        end
    end
    return nil
end

-- FIXED: Enhanced positioning logic with proper tracking for ALL participants (winners AND losers)
function TournamentUtils.calculate_round_positions(tournament, round_number)
    local mug_pos = require("scripts/net-game-tourney/mug-pos")
    local positions = {}
    
    -- Initialize all positions with initial positions
    for i = 1, #tournament.all_participants do
        if mug_pos.initial[i] then
            positions[i] = mug_pos.initial[i]
        end
    end
    
    if round_number == 1 then
        -- Round 1: Move winners to round1 positions, losers stay in initial positions
        local matches = tournament.matches or {}
        
        for match_index, match in ipairs(matches) do
            if match.completed then
                local winner_index = TournamentUtils.find_participant_index(tournament, match.winner.player_id)
                local loser_index = TournamentUtils.find_participant_index(tournament, match.loser.player_id)
                
                -- Move winner to round1 winner position
                if winner_index and mug_pos.round1_winners[match_index] then
                    positions[winner_index] = mug_pos.round1_winners[match_index]
                    print(string.format("[tourney] Round 1: Moved winner %s to position (%d,%d)", 
                          match.winner.player_id, positions[winner_index].x, positions[winner_index].y))
                end
                
                -- Loser stays in initial position (already set)
                if loser_index then
                    print(string.format("[tourney] Round 1: Loser %s remains in initial position (%d,%d)", 
                          match.loser.player_id, positions[loser_index].x, positions[loser_index].y))
                end
            end
        end
        
  
elseif round_number == 2 then
    -- FIXED: Round 2 - Only move winners to round2 positions, leave losers in round1 positions
    local round2_results = tournament.round_results[2] or {}
    local round1_results = tournament.round_results[1] or {}
    
    -- First, ensure ALL round1 losers are in initial positions
    for _, result in ipairs(round1_results) do
        if result.loser then
            local loser_index = TournamentUtils.find_participant_index(tournament, result.loser.player_id)
            if loser_index and mug_pos.initial[loser_index] then
                positions[loser_index] = mug_pos.initial[loser_index]
                print(string.format("[tourney] Round 2: Round 1 loser %s in initial position", result.loser.player_id))
            end
        end
    end
    
    -- Place ALL round1 winners in round1 positions initially
    for _, result in ipairs(round1_results) do
        if result.winner then
            local winner_index = TournamentUtils.find_participant_index(tournament, result.winner.player_id)
            local match_index = result.match
            
            if winner_index and mug_pos.round1_winners[match_index] then
                positions[winner_index] = mug_pos.round1_winners[match_index]
                print(string.format("[tourney] Round 2: Round 1 winner %s in round1 position (%d,%d)", 
                      result.winner.player_id, positions[winner_index].x, positions[winner_index].y))
            end
        end
    end
    
    -- FIXED: Process BOTH Round 2 matches properly
    print(string.format("[tourney] Processing %d Round 2 results", #round2_results))
    for _, result in ipairs(round2_results) do
        local winner_index = TournamentUtils.find_participant_index(tournament, result.winner.player_id)
        local loser_index = TournamentUtils.find_participant_index(tournament, result.loser.player_id)
        local match_index = result.match
        
        -- FIXED: Only move the winner to round2 position
        if winner_index and mug_pos.round2_winners[match_index] then
            positions[winner_index] = mug_pos.round2_winners[match_index]
            print(string.format("[tourney] Round 2: Moved winner %s to round2 position (%d,%d) for match %d", 
                  result.winner.player_id, positions[winner_index].x, positions[winner_index].y, match_index))
        else
            print(string.format("[tourney] Round 2: Could not move winner %s - index: %s, position: %s", 
                  result.winner.player_id, tostring(winner_index), tostring(mug_pos.round2_winners[match_index])))
        end
        
        -- FIXED: Loser stays in their round1 position (no change)
        if loser_index then
            print(string.format("[tourney] Round 2: Loser %s remains in round1 position (%d,%d)", 
                  result.loser.player_id, positions[loser_index].x, positions[loser_index].y))
        end
    end
        
    elseif round_number == 3 then
        -- Round 3: Move champion to top position, runner-up stays in round2 position, others remain where they are
        local current_matches = tournament.matches or {}
        local round1_results = tournament.round_results[1] or {}
        local round2_results = tournament.round_results[2] or {}
        
        -- Start with current positions
        local current_positions = TournamentState.get_current_state_positions(tournament.tournament_id) or {}
        for i, pos in pairs(current_positions) do
            positions[i] = pos
        end
        
        -- If no current positions, build from scratch
        if not current_positions or next(current_positions) == nil then
            print("[tourney] Building round 3 positions from scratch")
            
            -- Place round1 losers in initial positions
            for _, result in ipairs(round1_results) do
                if result.loser then
                    local loser_index = TournamentUtils.find_participant_index(tournament, result.loser.player_id)
                    if loser_index and mug_pos.initial[loser_index] then
                        positions[loser_index] = mug_pos.initial[loser_index]
                    end
                end
            end
            
            -- Place round2 losers in round1 positions
            for _, result in ipairs(round2_results) do
                if result.loser then
                    local loser_index = TournamentUtils.find_participant_index(tournament, result.loser.player_id)
                    -- Find which round1 match they won to get their round1 position
                    for _, round1_result in ipairs(round1_results) do
                        if round1_result.winner and round1_result.winner.player_id == result.loser.player_id then
                            if loser_index and mug_pos.round1_winners[round1_result.match] then
                                positions[loser_index] = mug_pos.round1_winners[round1_result.match]
                            end
                            break
                        end
                    end
                end
            end
            
            -- Place round2 winners in round2 positions
            for _, result in ipairs(round2_results) do
                if result.winner then
                    local winner_index = TournamentUtils.find_participant_index(tournament, result.winner.player_id)
                    if winner_index and mug_pos.round2_winners[result.match] then
                        positions[winner_index] = mug_pos.round2_winners[result.match]
                    end
                end
            end
        end
        
        -- Now handle round 3 results
        for _, match in ipairs(current_matches) do
            if match.completed then
                local champion_index = TournamentUtils.find_participant_index(tournament, match.winner.player_id)
                local runner_up_index = TournamentUtils.find_participant_index(tournament, match.loser.player_id)
                
                -- Move champion to top position
                if champion_index and mug_pos.champion[1] then
                    positions[champion_index] = mug_pos.champion[1]
                    print(string.format("[tourney] Round 3: Moved champion %s to top position (%d,%d)", 
                          match.winner.player_id, positions[champion_index].x, positions[champion_index].y))
                end
                
                -- Runner-up stays in round2 position (no change)
                if runner_up_index then
                    print(string.format("[tourney] Round 3: Runner-up %s remains in round2 position (%d,%d)", 
                          match.loser.player_id, positions[runner_up_index].x, positions[runner_up_index].y))
                end
            end
        end
    end
    
    -- Fill any missing positions
    for i = 1, #tournament.all_participants do
        if not positions[i] and mug_pos.initial[i] then
            positions[i] = mug_pos.initial[i]
            print(string.format("[tourney] Filled missing position for participant %d with initial position", i))
        end
    end
    
    -- DEBUG: Print all final positions
    print(string.format("[tourney] Final positions for round %d:", round_number))
    for i, pos in pairs(positions) do
        local participant = tournament.all_participants[i]
        if participant then
            local state = TournamentState.get_participant_state(tournament.tournament_id, participant.player_id)
            local status = "active"
            if state and state.eliminated then
                status = "eliminated round " .. tostring(state.eliminated_round)
            end
            print(string.format("  %s (%s): (%d,%d,%d) - %s", 
                  participant.player_id, i, pos.x, pos.y, pos.z, status))
        end
    end
    
    return positions
end

return TournamentUtils