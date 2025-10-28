MAIN TOURNAMENT MODULE
======================

PURPOSE:
Orchestrates the entire tournament system - handles player interactions, battle sequencing,
UI management, and tournament lifecycle.

ARCHITECTURE OVERVIEW:

1. INITIALIZATION
   - Loads all required modules
   - Scans maps for tournament boards
   - Sets up event handlers

2. PLAYER INTERACTION FLOW:
   Object Interaction -> Tournament Creation -> Board Display -> Battle Sequence -> Results

3. BATTLE SEQUENCE:
   Current State Display -> NPC Battles -> Player Battles -> Results Animation -> Next Round

KEY SYSTEMS:

TOURNAMENT CREATION:
- create_consistent_tournament(): Ensures participant order integrity
- initialize_tournament_participants(): Mixes players and NPCs
- Supports both single-player and multiplayer modes

BOARD DISPLAY SYSTEM:
- show_tournament_stage(): Basic board display with fade transitions
- show_tournament_results_with_animation(): Enhanced display with mugshot movements
- setup_board_bg_elements(): Renders static board elements
- add_participant_mugshot(): Places participant mugshots

BATTLE MANAGEMENT:
- start_battle(): Handles PvP, PvE, and NPC vs NPC scenarios
- run_tournament_battles(): Coordinates entire battle sequence
- NPC vs NPC battles resolved instantly with weighted randomness

ANIMATION SYSTEM:
- Two-phase display: Current state -> Animated transitions
- Individual mugshot movement with pauses between each
- Seamless board experience (no closing between states)
- Proper timing for visual clarity
- FIXED: Enhanced winner detection for rounds 2 and 3

ENHANCED WINNER DETECTION:
- Checks both current round winners AND participants who advanced from previous rounds
- More robust position change detection
- Proper handling of tournament bracket progression
- Better logging for debugging

EVENT HANDLERS:

object_interaction:
- Tournament board interaction entry point
- Handles tournament creation and joining
- Manages player queues and countdowns

countdown_ended: 
- Processes queue timeout decisions
- Handles backfill vs wait choices

battle_results:
- Processes battle outcomes
- Updates tournament state
- Triggers round completion checks

player_disconnect:
- Handles player abandonment
- Manages host reassignment
- Processes disqualifications

TOURNAMENT LIFECYCLE:
1. WAITING_FOR_PLAYERS: Gathering participants
2. IN_PROGRESS: Battles running
3. ROUND_COMPLETE: Results displayed
4. COMPLETED: Tournament finished

PERFORMANCE FEATURES:
- Framework activation/deactivation to manage resources
- Async/await pattern for non-blocking operations
- Proper cleanup of UI elements and tournament state
- Input locking during critical operations

POSITIONING FIXES:
- Round 2: Winners properly move to upper positions, losers stay in round1 spots
- Round 3: Champion moves to top, runner-up stays in final position
- All rounds maintain proper bracket visual relationships