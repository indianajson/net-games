TOURNAMENT UTILITIES MODULE
===========================

PURPOSE:
Contains business logic for tournament operations including battle processing,
player management, and position calculations.

PLAYER MANAGEMENT FUNCTIONS:

1. freeze_all_tournament_players(tournament_id, TournamentState)
   - Locks input for all human players in tournament
   - Prevents movement during board display

2. unfreeze_players(player_ids)
   - Restores input for specific players
   - Used after battles or board closures

3. freeze_players(player_ids)
   - Locks input for specific players
   - Used before battles

BATTLE PROCESSING:

4. process_battle_results(event, tournament_id, match_index, TournamentState)
   - Analyzes battle results to determine winner/loser
   - Handles special cases: player runaways, NPC battles
   - Different logic for PvP vs PvE encounters
   - Returns winner_participant, loser_participant

5. ask_host_about_next_round(tournament_id, TournamentState)
   - Prompts tournament host to continue or end
   - Handles host disconnection/elimination edge cases
   - Returns boolean decision

VISUAL POSITIONING:

6. calculate_round_positions(tournament, round_number)
   - FIXED: Enhanced positioning logic for all rounds
   - Round 1: Winners move to round1_winners, losers stay in initial
   - Round 2: Winners move to round2_winners, losers stay in round1 positions
   - Round 3: Champion moves to top, runner-up stays in final position
   - Maintains proper bracket relationships throughout
   - Uses initial participant indices for consistent tracking

BOARD MANAGEMENT:

7. get_board_background_and_grid(object, TiledUtils, constants)
   - Extracts board visual theme from Tiled object properties
   - Falls back to default theme if unspecified

NPC BATTLE HANDLING:
- Properly detects NPC vs NPC and NPC vs Player scenarios
- Uses weighted random system for NPC outcomes
- Ensures consistent results across all viewers

ROUND TRANSITIONS:
- Manages host reassignment when original host is eliminated
- Handles tournament completion detection
- Coordinates with TournamentState for round advancement

POSITIONING ENHANCEMENTS:
- Helper function find_initial_index() tracks participants consistently
- Round 2 properly reconstructs round 1 positions before updating
- Round 3 reconstructs entire bracket history
- Champion and runner-up positioning follows tournament bracket logic