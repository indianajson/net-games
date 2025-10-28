EVENT EMITTERS MODULE
=====================

PURPOSE:
Manages event-driven communication between tournament components and provides
NPC battle simulation capabilities.

EVENT EMITTERS:

1. change_area_emitter
   - Tracks player area transfers
   - Emits: "player_changed_area"

2. tourney_emitter  
   - Core tournament events
   - Emits: "in_tourney_battle", "battle_completed"

3. tournament_ui_emitter
   - UI customization events
   - Emits: "ui_position_changed", "ui_animation_changed"

DATA TRACKING:

player_history:
- Tracks player movement and session history
- Keyed by player secret for persistence

online_players / offline_players:
- Player presence tracking
- Handles connection state changes

matchups_in_battle:
- Active battle tracking
- Prevents duplicate battles

players_waiting:
- Queue management for tournament creation
- Tracks countdown states

UI MANAGEMENT:

set_ui_position(element_name, x, y, z):
- Programmatic UI element positioning
- Emits "ui_position_changed" event

set_ui_animation(element_name, animation_state):
- Dynamic animation control
- Emits "ui_animation_changed" event

BATTLE COORDINATION:

start_tourney_battle(player1_id, player2_id, tournament_id, match_index):
- Registers battle matchup
- Prevents duplicate battles
- Emits "in_tourney_battle" event

handle_battle_result(event):
- Processes battle completion
- Finds relevant matchup
- Emits "battle_completed" event

NPC BATTLE SIMULATION:

simulate_npc_battle(npc1_id, npc2_id, tournament_id, match_index):
- Simulates NPC vs NPC battles asynchronously
- Uses weighted random outcomes
- Automatically records results in tournament state
- Realistic timing (3-8 second duration)

PLAYER MANAGEMENT:

remove_player_from_all_tables(pid, tbl):
- Comprehensive player cleanup
- Recursively removes player references

set_player_area(pid, area):
- Tracks player location changes
- Maintains player history

EVENT INTEGRATION:
- player_transfer_area: Updates player tracking
- player_join: Initializes player session
- player_disconnect: Cleans up player data

USAGE PATTERN:
1. Components emit events for state changes
2. Other components listen for relevant events
3. NPC battles simulated when no players involved
4. UI updates triggered through emitter events