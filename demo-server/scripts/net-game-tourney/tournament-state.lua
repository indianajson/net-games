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
        -- ADD: Enhanced position tracking for display
        participant_positions = {}, -- Track current position for each participant
        round_positions = { {}, {}, {} }, -- Store positions after each round
        current_state_positions = {} -- Track the current display state
    }
    
    active_tournaments[tournament_id] = tournament
    return tournament_id
end

function TournamentState.add_participant(tournament_id, participant)
    local tournament = active_tournaments[tournament_id]
    if not tournament or #tournament.participants >= 8 then
        return false
    end
    
    -- Check if player is already in a tournament
    if participant.player_id and player_tournaments[participant.player_id] then
        return false
    end
    
    table.insert(tournament.participants, participant)
    if participant.player_id then
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
    
    print("[TournamentState] Battle recorded: " .. winner_participant.player_id .. " defeated " .. loser_participant.player_id)
    
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
                return true
            end
        end
    end
    
    return false
end

function TournamentState.cleanup_tournament(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return end
    
    -- Remove players from tracking
    for _, participant in ipairs(tournament.participants) do
        if participant.player_id then
            player_tournaments[participant.player_id] = nil
        end
    end
    
    active_tournaments[tournament_id] = nil
end

-- NEW: Remove a specific player from tournament tracking
function TournamentState.remove_player_from_tournament(player_id)
    player_tournaments[player_id] = nil
end

-- ADD: Function to store round positions based on pairings
function TournamentState.store_round_positions(tournament_id, round_number, positions_data)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    if not tournament.round_positions then
        tournament.round_positions = {}
    end
    
    tournament.round_positions[round_number] = positions_data
    tournament.participant_positions = positions_data
    
    return true
end

-- ADD: Function to store current state positions
function TournamentState.store_current_state_positions(tournament_id, positions_data)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return false end
    
    tournament.current_state_positions = positions_data
    return true
end

-- ADD: Function to get current state positions
function TournamentState.get_current_state_positions(tournament_id)
    local tournament = active_tournaments[tournament_id]
    if not tournament then return nil end
    
    return tournament.current_state_positions
end

function TournamentState.get_tournament(tournament_id)
    return active_tournaments[tournament_id]
end

function TournamentState.is_player_in_tournament(player_id)
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

return TournamentState