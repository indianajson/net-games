# Tournament System API Documentation

## Overview
The tournament system allows players to participate in 8-player single-elimination tournaments with support for PvP, PvE, and NPC vs NPC battles.

## Core Components

### TournamentState
Manages tournament state and progression.

**Functions:**
- `create_tournament(board_id, area_id, host_player_id)` - Creates a new tournament
- `add_participant(tournament_id, participant)` - Adds player/NPC to tournament
- `start_tournament(tournament_id)` - Starts the tournament
- `record_battle_result(tournament_id, match_index, winner, loser)` - Records battle outcome
- `get_current_round_winners(tournament_id)` - Returns winners of current round
- `advance_to_next_round(tournament_id)` - Advances to next tournament round
- `handle_player_disqualification(tournament_id, player_id)` - Handles player DC/run

### TournamentUtils
Utility functions for tournament operations.

**Functions:**
- `freeze_all_tournament_players(tournament_id, TournamentState)` - Freezes all players
- `unfreeze_players(player_ids)` - Unfreezes specific players
- `show_round_ui(player_id, round_number)` - Shows round display UI
- `remove_round_ui(player_id)` - Removes round UI
- `process_battle_results(event, tournament_id, match_index, TournamentState)` - Processes battle results
- `ask_host_about_next_round(tournament_id, TournamentState)` - Asks host about next round

### TourneyEmitters
Event emitters for tournament system.

**Emitters:**
- `tourney_emitter` - Tournament battle events
- `tournament_ui_emitter` - UI customization events

## Event Flow

### Tournament Creation
1. Player interacts with Tournament Board object
2. System checks if player can join/create tournament
3. Tournament is created with host player
4. Participants are added (players + NPC backfill if needed)

### Battle Sequencing
1. All players are frozen at round start
2. Player battles start first (PvP/PvE)
3. Players are unfrozen right before their battle
4. Players are unfrozen after their battle completes
5. NPC vs NPC battles are simulated sequentially
6. Round UI shows current round number

### Round Progression
1. After all battles complete, host is asked about next round
2. If host agrees, winners advance to next round
3. Tournament continues until one winner remains
4. If host declines, tournament ends

### Disconnection Handling
- Disconnected players are automatically disqualified
- Their opponent advances to next round
- Running from battle counts as disqualification

## Battle Result Processing

The system handles various battle outcomes:

- **Player Wins**: Enemy health reaches 0
- **Player Loses**: Player health reaches 0 or enemies survive
- **Player Runs**: `event.ran = true` - automatic disqualification
- **Disconnection**: Player leaves during tournament

## UI Customization

Use `TourneyEmitters.tournament_ui_emitter` to customize UI:

```lua
-- Change UI element position
TourneyEmitters.set_ui_position("element_name", x, y, z)

-- Change UI element animation
TourneyEmitters.set_ui_animation("element_name", "animation_state")