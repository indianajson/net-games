local TournamentState = {}
local active_tournaments = {}
local player_tournaments = {} -- Tracks which tournament each player is in

function TournamentState.create_tournament(board_id, area_id, host_player_id)
    local tournament_id = #active_tournaments + 1
    local tournament = {
        tournament_id = tournament_id,
        board_id = board_id,
        area_id = area_id,
        host_player_id = host_player_id,
        status = "WAITING_FOR_PLAYERS",
        participants = {},
        current_round = 0,
        matches = {},
        winners = {},
        round_results = { {}, {}, {} },
        losers = { {}, {}, {} }, -- Track losers per round
        board_data = nil, -- Will store board background info and mugshots
        -- Enhanced position tracking for display
        participant_positions = {}, -- Track current position for each participant
        round_positions = { {}, {}, {} }, -- Store positions after each round
        current_state_positions = {}, -- Track the current display state
        -- NPC predetermined results storage specific to this tournament
        npc_predetermined_results = {}, -- Store NPC battle results per match for this tournament only
        
        -- NEW: Enhanced tracking for all participants
        all_participants = {}, -- Track ALL original participants with their elimination status
        eliminated_participants = {}, -- Track when each participant was eliminated
        round_eliminations = { {}, {}, {} }, -- Track eliminations per round
        participant_states = {}, -- Track current state (position, eliminated, etc.) for each participant
    }
    
    active_tournaments[tournament_id] = tournament
    return tournament_id
end

function TournamentState.add_participant(tournament_id, participant)
    local tournament = active_tournaments[tournament_id]
    if not tournament or #tournament.participants >= 8 then
        return false
    end
    
    -- Check if player is already in a tournament (only for real players, not NPCs)
    if participant.player_id and not string.find(participant.player_id, ".zip") and player_tournaments[participant.player_id] then
        return false
    end
    
    table.insert(tournament.participants, participant)
    -- Only track real players in player_tournaments, not NPCs
    if participant.player_id and not string.find(participant.player_id, ".zip") then
        player_tournaments[participant.player_id] = tournament_id
    end
    
    return true
end

function TournamentState.start_tournament(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament or #tournament.participants < 2 then
        return false
    end
    
    tournament.status = "IN_PROGRESS"
    tournament.current_round = 1
    tournament.matches = TournamentState.generate_matches(tournament.participants)
    
    return true
end

function TournamentState.generate_matches(participants)
    local matches = {}
    for i = 1, #participants - 1, 2 do
        table.insert(matches, {
            player1 = participants[i],
            player2 = participants[i + 1],
            completed = false,
            winner = nil,
            loser = nil
        })
    end
    return matches
end

function TournamentState.record_battle_result(tournament_id, match_index, winner_participant, loser_participant)
    local tournament = active_tournaments[tournament_id]
    if not tournament or match_index > #tournament.matches then
        print("[TournamentState] Invalid tournament or match index")
        return false
    end
    
    local match = tournament.matches[match_index]
    match.completed = true
    match.winner = winner_participant
    match.loser = loser_participant
    
    -- Record in round results with pairing information
    table.insert(tournament.round_results[tournament.current_round], {
        match = match_index,
        winner = winner_participant,
        loser = loser_participant,
        player1 = match.player1,  -- Store the original pairing
        player2 = match.player2   -- Store the original pairing
    })
    
    -- Add to winners list if not already there
    local already_in_winners = false
    for _, winner in ipairs(tournament.winners) do
        if winner.player_id == winner_participant.player_id then
            already_in_winners = true
            break
        end
    end
    
    if not already_in_winners then
        table.insert(tournament.winners, winner_participant)
    end
    
    -- Record loser if exists
    if loser_participant then
        table.insert(tournament.losers[tournament.current_round], loser_participant)
    end
    
    -- NEW: Mark participants in state tracking
    TournamentState.mark_participant_winner(tournament_id, winner_participant.player_id, tournament.current_round)
    TournamentState.mark_participant_eliminated(tournament_id, loser_participant.player_id, tournament.current_round)
    
    print(string.format("[TournamentState] Battle recorded: %s defeated %s in round %d", 
          winner_participant.player_id, loser_participant.player_id, tournament.current_round))
    
    -- Check if round is complete
    local round_complete = true
    for _, m in ipairs(tournament.matches) do
        if not m.completed then
            round_complete = false
            break
        end
    end
    
    if round_complete then
        tournament.status = "ROUND_COMPLETE"
        print("[TournamentState] Round " .. tournament.current_round .. " completed")
    end
    
    return round_complete
end

function TournamentState.get_current_round_winners(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return {} end
    
    local winners = {}
    for _, match in ipairs(tournament.matches) do
        if match.completed and match.winner then
            table.insert(winners, match.winner)
        end
    end
    return winners
end

function TournamentState.advance_to_next_round(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then 
        print("[TournamentState] No tournament found with ID: " .. tostring(tournament_id))
        return false 
    end
    
    -- Check if round is complete
    local round_complete = true
    for _, match in ipairs(tournament.matches) do
        if not match.completed then
            round_complete = false
            break
        end
    end
    
    if not round_complete then
        print("[TournamentState] Round not complete, cannot advance")
        return false
    end
    
    if #tournament.winners == 1 then
        tournament.status = "COMPLETED"
        print("[TournamentState] Tournament completed with winner: " .. tournament.winners[1].player_id)
        -- Don't cleanup immediately, let main.lua handle it
    else
        tournament.current_round = tournament.current_round + 1
        tournament.participants = tournament.winners
        tournament.winners = {}
        tournament.matches = TournamentState.generate_matches(tournament.participants)
        tournament.status = "IN_PROGRESS"
        print("[TournamentState] Advanced to round " .. tournament.current_round)
    end
    
    return true
end

function TournamentState.handle_player_disqualification(tournament_id, player_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    -- Find the match containing this player
    for match_index, match in ipairs(tournament.matches) do
        if not match.completed then
            if match.player1.player_id == player_id then
                -- Player 1 disqualified, player 2 wins
                match.completed = true
                match.winner = match.player2
                match.loser = match.player1
                
                table.insert(tournament.round_results[tournament.current_round], {
                    match = match_index,
                    winner = match.player2,
                    loser = match.player1,
                    disqualified = true
                })
                
                table.insert(tournament.winners, match.player2)
                table.insert(tournament.losers[tournament.current_round], match.player1)
                
                -- NEW: Mark participants in state tracking
                TournamentState.mark_participant_winner(tournament_id, match.player2.player_id, tournament.current_round)
                TournamentState.mark_participant_eliminated(tournament_id, match.player1.player_id, tournament.current_round)
                
                return true
                
            elseif match.player2.player_id == player_id then
                -- Player 2 disqualified, player 1 wins
                match.completed = true
                match.winner = match.player1
                match.loser = match.player2
                
                table.insert(tournament.round_results[tournament.current_round], {
                    match = match_index,
                    winner = match.player1,
                    loser = match.player2,
                    disqualified = true
                })
                
                table.insert(tournament.winners, match.player1)
                table.insert(tournament.losers[tournament.current_round], match.player2)
                
                -- NEW: Mark participants in state tracking
                TournamentState.mark_participant_winner(tournament_id, match.player1.player_id, tournament.current_round)
                TournamentState.mark_participant_eliminated(tournament_id, match.player2.player_id, tournament.current_round)
                
                return true
            end
        end
    end
    
    return false
end

function TournamentState.cleanup_tournament(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then 
        print("[TournamentState] Tournament " .. tournament_id .. " not found for cleanup")
        return 
    end
    
    print("[TournamentState] Cleaning up tournament " .. tournament_id)
    
    -- Remove players from tracking (only real players, not NPCs)
    local removed_count = 0
    for _, participant in ipairs(tournament.participants) do
        if participant.player_id and not string.find(participant.player_id, ".zip") then
            player_tournaments[participant.player_id] = nil
            removed_count = removed_count + 1
            print("[TournamentState] Removed player from tracking: " .. participant.player_id)
        end
    end
    
    active_tournaments[tournament_id] = nil
    print("[TournamentState] Tournament " .. tournament_id .. " removed. Cleaned up " .. removed_count .. " players")
end

-- Remove a specific player from tournament tracking (only real players)
function TournamentState.remove_player_from_tournament(player_id)
    if not string.find(player_id, ".zip") then
        local had_tournament = player_tournaments[player_id] ~= nil
        player_tournaments[player_id] = nil
        if had_tournament then
            print("[TournamentState] Removed player " .. player_id .. " from tournament tracking")
        end
        return had_tournament
    end
    return false
end

-- Function to store round positions based on pairings
function TournamentState.store_round_positions(tournament_id, round_number, positions_data)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    if not tournament.round_positions then
        tournament.round_positions = {}
    end
    
    tournament.round_positions[round_number] = positions_data
    tournament.participant_positions = positions_data
    
    print(string.format("[TournamentState] Stored round %d positions for tournament %d", round_number, tournament_id))
    return true
end

-- Function to store current state positions
function TournamentState.store_current_state_positions(tournament_id, positions_data)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    tournament.current_state_positions = positions_data
    print(string.format("[TournamentState] Stored current state positions for tournament %d", tournament_id))
    return true
end

-- Function to get current state positions
function TournamentState.get_current_state_positions(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return nil end
    
    return tournament.current_state_positions
end

function TournamentState.store_npc_predetermined_result(tournament_id, match_index, result_data)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    if not tournament.npc_predetermined_results then
        tournament.npc_predetermined_results = {}
    end
    
    tournament.npc_predetermined_results[match_index] = result_data
    print(string.format("[TournamentState] Stored NPC predetermined result for tournament %d, match %d, round %d: %s defeated %s", 
          tournament_id, match_index, result_data.round or 0, result_data.winner_id, result_data.loser_id))
    return true
end

-- Function to get NPC predetermined results for a specific tournament
function TournamentState.get_npc_predetermined_result(tournament_id, match_index)
    local tournament = active_tournaments[tournament_id]
    if not tournament or not tournament.npc_predetermined_results then
        return nil
    end
    
    local result = tournament.npc_predetermined_results[match_index]
    if result then
        print(string.format("[TournamentState] Retrieved NPC predetermined result for tournament %d, match %d: %s defeated %s", 
              tournament_id, match_index, result.winner_id, result.loser_id))
    end
    
    return result
end

-- Initialize participant states at tournament start
function TournamentState.initialize_participant_states(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    tournament.all_participants = {}
    tournament.participant_states = {}
    tournament.eliminated_participants = {}
    
    -- Copy all participants and initialize their states
    for i, participant in ipairs(tournament.participants) do
        tournament.all_participants[i] = {
            player_id = participant.player_id,
            player_mugshot = participant.player_mugshot,
            initial_index = i
        }
        
        tournament.participant_states[i] = {
            player_id = participant.player_id,
            eliminated = false,
            eliminated_round = nil,
            current_position = i, -- Track position index
            is_winner = false
        }
    end
    
    print(string.format("[TournamentState] Initialized participant states for %d participants", #tournament.participants))
    return true
end

-- Mark participant as eliminated in a specific round
function TournamentState.mark_participant_eliminated(tournament_id, participant_id, round_number)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    for i, state in ipairs(tournament.participant_states) do
        if state.player_id == participant_id and not state.eliminated then
            state.eliminated = true
            state.eliminated_round = round_number
            
            -- Add to eliminated participants list if not already there
            local already_tracked = false
            for _, eliminated in ipairs(tournament.eliminated_participants) do
                if eliminated.player_id == participant_id then
                    already_tracked = true
                    break
                end
            end
            
            if not already_tracked then
                table.insert(tournament.eliminated_participants, {
                    player_id = participant_id,
                    eliminated_round = round_number,
                    participant_index = i
                })
            end
            
            -- Add to round eliminations
            table.insert(tournament.round_eliminations[round_number], {
                player_id = participant_id,
                participant_index = i
            })
            
            print(string.format("[TournamentState] Marked %s as eliminated in round %d", participant_id, round_number))
            return true
        end
    end
    
    return false
end

-- Mark participant as winner
function TournamentState.mark_participant_winner(tournament_id, participant_id, round_number)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    for i, state in ipairs(tournament.participant_states) do
        if state.player_id == participant_id then
            state.is_winner = true
            state.won_round = round_number
            print(string.format("[TournamentState] Marked %s as winner in round %d", participant_id, round_number))
            return true
        end
    end
    
    return false
end

-- Get all active (non-eliminated) participants for a round
function TournamentState.get_active_participants_for_round(tournament_id, round_number)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return {} end
    
    local active = {}
    for i, state in ipairs(tournament.participant_states) do
        if not state.eliminated or (state.eliminated and state.eliminated_round > round_number) then
            table.insert(active, tournament.all_participants[i])
        end
    end
    
    return active
end

-- Get participant state
function TournamentState.get_participant_state(tournament_id, participant_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return nil end
    
    for _, state in ipairs(tournament.participant_states) do
        if state.player_id == participant_id then
            return state
        end
    end
    
    return nil
end

-- Get all participants with their states
function TournamentState.get_all_participants_with_states(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return {} end
    
    local result = {}
    for i, participant in ipairs(tournament.all_participants) do
        result[i] = {
            participant = participant,
            state = tournament.participant_states[i]
        }
    end
    
    return result
end

-- NEW: Force cleanup function for orphaned players
function TournamentState.force_cleanup_player(player_id)
    if not string.find(player_id, ".zip") then
        player_tournaments[player_id] = nil
        print("[TournamentState] Force cleaned up player: " .. player_id)
        return true
    end
    return false
end

-- NEW: Get all tournaments for cleanup purposes
function TournamentState.get_all_tournaments()
    return active_tournaments
end

function TournamentState.get_tournament(tournament_id)
    return active_tournaments[tournament_id]
end

function TournamentState.is_player_in_tournament(player_id)
    -- Only check for real players, NPCs can be in multiple tournaments
    if string.find(player_id, ".zip") then
        return false -- NPCs are not restricted to one tournament
    end
    return player_tournaments[player_id] ~= nil
end

function TournamentState.get_tournament_by_player(player_id)
    local tournament_id = player_tournaments[player_id]
    if tournament_id then
        return active_tournaments[tournament_id]
    end
    return nil
end

function TournamentState.get_tournament_id_by_player(player_id)
    return player_tournaments[player_id]
end

function TournamentState.debug_tournament_state(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then
        print("[TournamentState] Tournament " .. tournament_id .. " not found")
        return
    end
    
    print(string.format("[TournamentState] Debug Tournament %d:", tournament_id))
    print("  Status: " .. tournament.status)
    print("  Current Round: " .. tournament.current_round)
    print("  Participants: " .. #tournament.participants)
    print("  Winners: " .. #tournament.winners)
    
    for round_num = 1, 3 do
        local round_results = tournament.round_results[round_num] or {}
        print(string.format("  Round %d Results: %d", round_num, #round_results))
        
        for i, result in ipairs(round_results) do
            print(string.format("    Result %d: %s defeated %s (match %d)", 
                  i, result.winner.player_id, result.loser.player_id, result.match))
        end
    end
    
    print("  Current Matches: " .. #tournament.matches)
    for i, match in ipairs(tournament.matches) do
        print(string.format("    Match %d: %s vs %s - completed: %s", 
              i, match.player1.player_id, match.player2.player_id, tostring(match.completed)))
    end
end



return TournamentState