TOURNAMENT STATE MODULE
=======================

PURPOSE:
Manages the state and lifecycle of tournament instances, including participant tracking,
round progression, match results, and position history.

KEY DATA STRUCTURES:
- active_tournaments: Table storing all active tournament instances
- player_tournaments: Maps player_id -> tournament_id for quick lookup

TOURNAMENT OBJECT STRUCTURE:
{
  tournament_id: number,
  board_id: number,
  area_id: string,
  host_player_id: string,
  status: "WAITING_FOR_PLAYERS" | "IN_PROGRESS" | "ROUND_COMPLETE" | "COMPLETED",
  participants: table[],
  current_round: number,
  matches: table[],
  winners: table[],
  round_results: table[3], -- Results for rounds 1-3
  losers: table[3], -- Losers for rounds 1-3
  board_data: table, -- Background info and mugshots
  participant_positions: table, -- Current positions for display
  round_positions: table[3], -- Historical positions per round
  current_state_positions: table -- Current display state positions
}

MATCH OBJECT STRUCTURE:
{
  player1: participant,
  player2: participant,
  completed: boolean,
  winner: participant,
  loser: participant
}

CORE FUNCTIONS:

1. create_tournament(board_id, area_id, host_player_id)
   - Creates new tournament instance
   - Returns tournament_id

2. add_participant(tournament_id, participant)
   - Adds player/NPC to tournament
   - Prevents duplicates and max 8 participants

3. start_tournament(tournament_id)
   - Transitions from WAITING_FOR_PLAYERS to IN_PROGRESS
   - Generates initial match pairings

4. generate_matches(participants)
   - Creates match pairings from participant list
   - Handles odd numbers gracefully

5. record_battle_result(tournament_id, match_index, winner, loser)
   - Records match outcome
   - Updates winners/losers lists
   - Checks round completion

6. advance_to_next_round(tournament_id)
   - Moves winners to next round
   - Generates new matches
   - Handles tournament completion

7. handle_player_disqualification(tournament_id, player_id)
   - Automatically awards win to opponent
   - Marks match as disqualified

POSITION TRACKING FUNCTIONS:
- store_round_positions(): Saves positions after each round
- store_current_state_positions(): Tracks current display state
- get_current_state_positions(): Retrieves current positions

UTILITY FUNCTIONS:
- get_tournament(): Retrieve tournament by ID
- is_player_in_tournament(): Check player tournament status
- get_tournament_by_player(): Find tournament via player
- cleanup_tournament(): Clean up completed tournaments