Tournament System Documentation
Overview
The tournament system is a comprehensive 8-player single-elimination tournament framework that supports PvP, PvE, and NPC battles. It features a dynamic bracket UI, automated battle sequencing, and real-time tournament progression.

File Structure
1. main.lua
Primary tournament controller and event handler

Core Functions
Tournament Flow Functions:

run_tournament_battles(tournament_id) - Main tournament battle sequencer

start_battle(player1_id, player2_id, tournament_id, match_index) - Individual battle starter

show_tournament_board(player_id, tournament) - Displays bracket UI to players

Player Management:

has_real_players(tournament) - Checks if tournament has active human players

get_new_host(tournament) - Assigns new host when current host is eliminated

is_tournament_completed(tournament) - Determines if tournament reached final round

UI Management:

setup_board_bg_elements(player_id, info) - Sets up tournament board background

add_participant_mugshot(player_id, number, texture, x, y) - Adds player mugshots to board

cleanup_ui(player_id, area, name, song) - Cleans up UI after tournament display

Board Initialization:

initialize_tournament_participants(participants, backfill) - Creates 8-player tournament roster

store_tournament_board_data(tournament_id, bg_info, participants) - Stores board state for later display

start_and_show_tourney(pid, bg_info, tourney) - Initial tournament board display

Event Handlers
object_interaction: Handles tournament board interactions

countdown_ended: Manages tournament countdown completion

battle_results: Processes battle outcomes

player_disconnect: Handles player disconnections during tournaments

Key Variables to Modify
lua
local duration = 10  -- Countdown timer duration
local frames_to_remove = ui_data.frame_names  -- UI elements to clean up
2. tournament-state.lua
Tournament data management and state tracking

Core Functions
Tournament Lifecycle:

create_tournament(board_id, area_id, host_player_id) - Creates new tournament instance

start_tournament(tournament_id) - Begins tournament battles

advance_to_next_round(tournament_id) - Progresses to next tournament round

cleanup_tournament(tournament_id) - Cleans up completed tournament

Battle Management:

generate_matches(participants) - Creates match pairings for current round

record_battle_result(tournament_id, match_index, winner, loser) - Records battle outcomes

handle_player_disqualification(tournament_id, player_id) - Handles DCs/runners

Player Tracking:

add_participant(tournament_id, participant) - Adds player/NPC to tournament

remove_player_from_tournament(player_id) - Removes player from tracking

is_player_in_tournament(player_id) - Checks if player is in active tournament

Data Structure
lua
local tournament = {
    tournament_id = number,
    board_id = string,
    area_id = string,
    host_player_id = string,
    status = "WAITING_FOR_PLAYERS"|"IN_PROGRESS"|"ROUND_COMPLETE"|"COMPLETED",
    participants = table,
    current_round = number,
    matches = table,
    winners = table,
    board_data = table -- Stores UI information
}
3. tournament-utils.lua
Utility functions for tournament operations

Core Functions
Player Control:

freeze_all_tournament_players(tournament_id, TournamentState) - Freezes all human players

unfreeze_players(player_ids) - Unfreezes specific players

freeze_players(player_ids) - Freezes specific players

UI Management:

show_round_ui(player_id, round_number) - Shows round start message

remove_round_ui(player_id) - Cleans up round UI

notify_waiting_for_matches(tournament_id, TournamentState) - Notifies players of wait status

Battle Processing:

process_battle_results(event, tournament_id, match_index, TournamentState) - Determines winners/losers

ask_host_about_next_round(tournament_id, TournamentState) - Prompts host for round continuation

Board Configuration:

get_board_background_and_grid(object, TiledUtils, constants) - Gets board visual settings

Battle Result Logic
Player Wins: Enemy health reaches 0 or all enemies defeated

Player Loses: Player health reaches 0 or enemies survive

Player Runs: Automatic disqualification

Disconnection: Automatic disqualification

4. emitters.lua
Event emission and async battle management

Core Components
Event Emitters:

tourney_emitter - Tournament battle events

tournament_ui_emitter - UI customization events

change_area_emitter - Player area change events

Key Functions:

start_tourney_battle(player1_id, player2_id, tournament_id, match_index) - Starts tournament battle

simulate_npc_battle(npc1_id, npc2_id, tournament_id, match_index) - Simulates NPC vs NPC battles

handle_battle_result(event) - Processes completed battles

UI Customization:

set_ui_position(element_name, x, y, z) - Changes UI element position

set_ui_animation(element_name, animation_state) - Changes UI element animation

5. constants.lua
Visual and path constants for tournament UI

Key Constants
Board Backgrounds:

lua
bracket_background_path = {
    blue_bn4 = { gradient_texture, grid_texture },
    green_bn4 = { gradient_texture, grid_texture },
    red_orange_bn4 = { gradient_texture, grid_texture }
    -- Add new backgrounds here
}
UI Element Paths:

bracket_bm_bn4, bracket_rs_bn4 - Bracket texture paths

default_bracket_anim_path_bn4 - Bracket animation path

champion_topper_bn4, champion_topper_bn45 - Champion banner paths

crown_texture_path, crown_anim_path - Crown element paths

Adding New Backgrounds
Add new background folder to /server/assets/tourney/tourney-board-elements/

Add entry to bracket_background_path table

Ensure gradient.png and grid.png exist in folder

6. npc-paths.lua
NPC character definitions and mugshot paths

Structure
lua
local NPC_LIST = {
    [1] = {
        player_id = "/server/assets/tourney/npc-navis-testing/airman/airman1.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis-testing/airman/mug.png",
            mug_animation = "/server/assets/tourney/mug.anim"
        }
    }
    -- Add new NPCs here
}
Adding New NPCs
Create NPC folder in /server/assets/tourney/npc-navis-testing/

Add ZIP file with NPC battle data

Add mug.png for tournament display

Add entry to NPC_LIST with unique index

7. mug-pos.lua
Mugshot positioning for tournament bracket

Position Tiers
lua
local POSITIONS = {
    top_tier = {      -- Semi-finals (2 positions)
        [1] = { x = 64, y = 48 },
        [2] = { x = 176, y = 48 }
    },
    middle_tier = {   -- Quarter-finals (4 positions)
        [1] = { x = 34, y = 80 },
        [2] = { x = 94, y = 80 },
        -- ...
    },
    bottom_tier = {   -- Initial round (8 positions)
        [1] = { x = 8, y = 132 },
        [2] = { x = 34, y = 132 },
        -- ...
    }
}
Customizing Positions
Modify coordinates to adjust mugshot placement

Ensure positions match bracket visual design

Test different screen resolutions

8. tiled-utils.lua
Tiled map property validation utilities

Core Function
check_custom_prop_validity(object_props, custom_prop_name, empty_string_is_valid) - Validates Tiled object properties

Tournament Flow
1. Tournament Creation
Player interacts with Tournament Board object

System checks if player can join/create tournament

Tournament created with host player

Participants added (players + NPC backfill if needed)

Board data stored for later display

2. Battle Sequencing
All players receive round start notification

Player battles start first (PvP/PvE)

Players unfrozen right before their battle

NPC vs NPC battles simulated sequentially

Battle results processed and winners determined

3. Round Progression
After all battles complete, board shown (round 1 only)

System checks if any real players remain

If no real players, tournament ends immediately

Otherwise, host asked about next round

Winners advance to next round

Tournament continues until one winner remains

4. Tournament Completion
After 3 rounds, tournament automatically completes

Winner announced to all players

All players removed from tournament tracking

Tournament data cleaned up

Customization Guide
Adding New Board Backgrounds
Create new folder in tourney-board-elements/

Add gradient.png and grid.png

Update constants.lua:

lua
bracket_background_path = {
    my_new_bg = {
        gradient_texture = ui_element_paths.."my-new-bg/gradient.png",
        grid_texture = ui_element_paths.."my-new-bg/grid.png",
    }
}
Adding New NPCs
Create NPC folder with battle data ZIP

Add mug.png for display

Update npc-paths.lua:

lua
[20] = {
    player_id = npc_path .. "newnpc/newnpc1.zip",
    player_mugshot = {
        mug_texture = npc_path .. "newnpc/mug.png",
        mug_animation = default_mug_anim,
    },
}
Modifying Tournament Rules
Round Count: Modify is_tournament_completed() in main.lua

Player Count: Change backfill logic in initialize_tournament_participants()

Battle Timing: Adjust sleep durations in run_tournament_battles()

UI Customization
Positions: Modify coordinates in mug-pos.lua

Animations: Change animation paths in constants.lua

Elements: Add/remove UI elements in setup_board_bg_elements()

Event System
Key Events
tourney_emitter: Battle start/completion events

tournament_ui_emitter: UI position/animation changes

change_area_emitter: Player area transitions

Custom Event Listeners
lua
TourneyEmitters.tourney_emitter:on("battle_completed", function(event)
    -- Custom battle completion logic
end)
Troubleshooting
Common Issues
Players Stuck in Tournament

Check player_tournaments table in tournament-state.lua

Ensure cleanup_tournament() is called on completion

Battle Results Not Processing

Verify process_battle_results() logic

Check battle event structure matches expectations

UI Elements Not Displaying

Confirm asset paths in constants.lua

Check UI element names match between setup and cleanup

NPC Battles Not Completing

Ensure NPC ZIP files are valid battle data

Check simulate_npc_battle() function

Debugging
Enable debug prints throughout system

Check server console for tournament flow messages

Verify all async/await patterns are properly implemented

Performance Considerations
Memory Management

Tournaments automatically clean up after completion

Player tracking removed when players leave

UI Optimization

UI elements properly cleaned up after display

Staggered board displays prevent performance spikes

Battle Sequencing

Player battles prioritized over NPC battles

Proper delays between battles prevent server overload