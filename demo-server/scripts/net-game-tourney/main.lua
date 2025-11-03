-- TODOS AND NOTES:
-- There are 15 positions for the tournament board to worry about placing player/NPC mugshots. The tiers go (8 positions, 4 positions, 2 positions, 1 position)
-- We should allow people to pass in a tournament name to be printed to the screen centered within the title banner/or graphic for name provided
-- Figure out a good way to handle the moving of mugshots, in Particular identify the best way to handle the glowing moving bar that follows behind the mugshots.
--   - Current thinking grab a copy of each unique "elbow" and setup the animation on each and we can set which one to start animating/change to solid color on next re-open of the tourney board.
local TableUtils = require("scripts/table-utils")
local games = require("scripts/net-games/framework")

local constants = require("scripts/net-game-tourney/constants")
local npc_paths = require("scripts/net-game-tourney/npc-paths")
local mug_pos = require("scripts/net-game-tourney/mug-pos")
local ui_data = require("scripts/net-game-tourney/ui-data")
local TiledUtils = require("scripts/net-game-tourney/tiled-utils")
local TourneyEmitters = require("scripts/net-game-tourney/emitters")
local tourney_table = require("scripts/net-game-tourney/table-templates/tournament-template")
local TournamentState = require("scripts/net-game-tourney/tournament-state")
local TournamentUtils = require("scripts/net-game-tourney/tournament-utils")

games.start_framework()

local tourney_boards = {}
local player_interaction_locks = {} -- prevent duplicate prompts
local active_countdowns = {} -- Track active countdowns to fix the timer issue

local default_mug_anim = constants.default_mug_anim
local frames_to_remove = ui_data.frame_names
local ui_data_pos = ui_data.unmoving_ui_pos

local board_pos = ui_data_pos.bg
local grid_pos = ui_data_pos.grid
local bracket_pos = ui_data_pos.bracket
local title_banner_pos = ui_data_pos.title_banner
local champion_topper_pos = ui_data_pos.champion_topper_bn4
local crown1_pos = ui_data_pos.crown1
local crown2_pos = ui_data_pos.crown2
local duration = 10

-- NPC weight lookup table
local NPC_WEIGHTS = {
    ["airman/airman1.zip"] = 50,
    ["blastman/blastman1.zip"] = 60,
    ["burnerman/burnerman1.zip"] = 55,
    ["colonel/colonel1.zip"] = 70,
    ["circusman/circusman1.zip"] = 45,
    ["cutman/cutman1.zip"] = 40,
    ["elementman/elementman1.zip"] = 65,
    ["fireman/fireman1.zip"] = 58,
    ["gbeast-megaman/gbeast-megaman1.zip"] = 80,
    ["gutsman/gutsman1.zip"] = 62,
    ["hatman/hatman1.zip"] = 48,
    ["iceman/iceman1.zip"] = 52,
    ["jammingman/jammingman1.zip"] = 47,
    ["protoman/protoman1.zip"] = 75,
    ["quickman/quickman1.zip"] = 68,
    ["roll/roll1.zip"] = 42,
    ["shadowman/shadowman1.zip"] = 72,
    ["starman/starman1.zip"] = 54,
    ["woodman/woodman1.zip"] = 56
}

---------------------------------------------------------------------
-- Core Tournament Functions
---------------------------------------------------------------------

function async(p) local co = coroutine.create(p) return Async.promisify(co) end
function await(v) return Async.await(v) end

-- Add missing helper functions
local function start_party(player_id, player_area, object_id)
    local player_mugshot = Net.get_player_mugshot(player_id)
    local party = {
        player_id = player_id,
        player_mugshot = { mug_texture = player_mugshot.texture_path, mug_animation = default_mug_anim }
    }
    table.insert(tourney_boards[player_area][object_id]["active_tournaments"], party)
end

local function join_or_create_party(player_id, object_id, should_wait_backfill)
    local player_area = Net.get_player_area(player_id)
    if should_wait_backfill then return end

    local found = false
    for i, party in next, tourney_boards[player_area][object_id].active_tournaments do
        if #tourney_boards[player_area][object_id].active_tournaments[i] < 8 then
            local mug = Net.get_player_mugshot(player_id).texture_path
            tourney_boards[player_area][object_id].active_tournaments[i] =
                { player_id = player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug } }
            found = true
            break
        end
    end
    if not found then start_party(player_id, player_area, object_id) end
end

-- Check if tournament has any real players left
local function has_real_players(tournament)
    for _, participant in ipairs(tournament.participants) do
        if not string.find(participant.player_id, ".zip") then
            return true
        end
    end
    return false
end

-- Get new host from remaining real players
local function get_new_host(tournament)
    for _, participant in ipairs(tournament.participants) do
        if not string.find(participant.player_id, ".zip") then
            return participant.player_id
        end
    end
    return nil
end

local function quit_party(player_area, object_id)
    -- local found = false
    for i, party in next, tourney_boards[player_area][object_id]["active_tournaments"] do
        print(party)
    end
    --if not found then start_party(player_id, player_area, object_id) end
end

-- Check if tournament is completed (3 rounds have passed)
local function is_tournament_completed(tournament)
    return tournament.current_round >= 3 and #tournament.winners == 1
end

-- Store tournament board data for later use
local function store_tournament_board_data(tournament_id, board_background_info, participants)
    local tournament = TournamentState.get_tournament(tournament_id)
    if tournament then
        tournament.board_data = {
            background_info = board_background_info,
            participants = participants,
            stored_mugshots = {}
        }
        
        -- Store mugshot data for all participants
        for i, participant in ipairs(participants) do
            tournament.board_data.stored_mugshots[i] = {
                player_id = participant.player_id,
                mug_texture = participant.player_mugshot.mug_texture,
                position = mug_pos.initial[i] or {x = 0, y = 0, z = 3}
            }
        end
        
        -- Initialize current state positions
        local initial_positions = {}
        for i = 1, #participants do
            if mug_pos.initial[i] then
                initial_positions[i] = mug_pos.initial[i]
            end
        end
        TournamentState.store_current_state_positions(tournament_id, initial_positions)
        
        print(string.format("[tourney] Stored board data for tournament %d with %d participants", tournament_id, #participants))
    end
end

-- Get NPC weight for battle calculations
local function get_npc_weight(npc_id)
    -- Extract NPC name from path
    for name, weight in pairs(NPC_WEIGHTS) do
        if string.find(npc_id, name) then
            return weight
        end
    end
    
    -- Default weight if not found
    return 50
end

-- Enhanced function to add participant mugshot with proper ID tracking and z-coordinate
local function add_participant_mugshot(player_id, mugshot_id, mug_texture_path, x, y, z)
    local z_pos = z or 2  -- Default to 2 if z is not provided
    games.add_ui_element("MUG_FRAME_" .. mugshot_id, player_id,
        "/server/assets/tourney/tourney-board-elements/mini-mug-frame.png", "/server/assets/tourney/tourney-board-elements/mini-mug-frame.anim", "ACTIVE", x, y, z_pos + 1)  -- Frame above mugshot
    games.add_ui_element("MUG_" .. mugshot_id, player_id, mug_texture_path,
        default_mug_anim, "UI", x, y, z_pos, .50, .50)
end

-- Enhanced function to remove specific participant mugshot
local function remove_participant_mugshot(player_id, mugshot_id)
    games.remove_ui_element("MUG_FRAME_" .. mugshot_id, player_id)
    games.remove_ui_element("MUG_" .. mugshot_id, player_id)
end

local function setup_board_bg_elements(player_id, info)
    games.add_ui_element("BOARD BG", player_id, info.gradient_texture,
        constants.default_background_anim_path_bn4, "BG", board_pos.x, board_pos.y, board_pos.z)
    games.add_ui_element("BOARD GRID", player_id, info.grid_texture,
        constants.default_grid_anim_path_bn4, "UI", grid_pos.x, grid_pos.y, grid_pos.z)
    games.add_ui_element("TOURNEY TREE", player_id, constants.bracket_bm_bn4,
        constants.default_bracket_anim_path_bn4, "UI", bracket_pos.x, bracket_pos.y, bracket_pos.z)
    games.add_ui_element("CHAMPION TOPPER", player_id, constants.champion_topper_bn4,
        constants.champion_topper_bn4_anim, "UI", champion_topper_pos.x, champion_topper_pos.y, champion_topper_pos.z)
    games.add_ui_element("TITLE BANNER", player_id, "/server/assets/tourney/title-banner.png",
        "/server/assets/tourney/title-banner.anim", "RED", title_banner_pos.x, title_banner_pos.y, title_banner_pos.z)
    games.add_ui_element("CROWN_1", player_id, constants.crown_texture_path,
        constants.crown_anim_path, "INACTIVE", crown1_pos.x, crown1_pos.y, crown1_pos.z)
    games.add_ui_element("CROWN_2", player_id, constants.crown_texture_path,
        constants.crown_anim_path, "INACTIVE", crown2_pos.x, crown2_pos.y, crown2_pos.z)
end

local function cleanup_ui(player_id, player_area, name, song)
    for _, element in next, frames_to_remove do games.remove_ui_element(element, player_id) end
    Net.set_area_name(player_area, name)
    Net.set_song(player_area, song)
end

-- NEW: Function to clear parties and waiting queues for a tournament
local function cleanup_tournament_parties(tournament_id)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return end
    
    print("[tourney] Cleaning up parties for tournament " .. tournament_id)
    
    -- Clear from all area boards
    for area_id, boards in pairs(tourney_boards) do
        for object_id, board_data in pairs(boards) do
            if board_data.active_tournaments then
                local before_count = #board_data.active_tournaments
                board_data.active_tournaments = {}
                if before_count > 0 then
                    print(string.format("[tourney] Cleared %d parties from board %s in area %s", 
                          before_count, object_id, area_id))
                end
            end
        end
    end
    
    -- Clear players from waiting queues
    local waiting_cleared = 0
    for player_id, waiting_data in pairs(TourneyEmitters.players_waiting) do
        if waiting_data and waiting_data.tourney_board then
            TourneyEmitters.players_waiting[player_id] = nil
            waiting_cleared = waiting_cleared + 1
            
            -- Also cleanup any active countdowns
            if active_countdowns[player_id] then
                games.deactivate_framework(player_id)
                active_countdowns[player_id] = nil
            end
        end
    end
    
    if waiting_cleared > 0 then
        print("[tourney] Cleared " .. waiting_cleared .. " players from waiting queues")
    end
end

-- NEW: Function to clear specific board parties
local function clear_board_parties(area_id, object_id)
    if tourney_boards[area_id] and tourney_boards[area_id][object_id] then
        local before_count = #tourney_boards[area_id][object_id].active_tournaments
        tourney_boards[area_id][object_id].active_tournaments = {}
        
        if before_count > 0 then
            print(string.format("[tourney] Cleared %d parties from board %s in area %s", 
                  before_count, object_id, area_id))
        end
    end
end

-- FIXED: Enhanced function for seamless board transitions with consistent participant shuffling
local function show_tournament_results_with_animation(player_id, tournament, round_number)
    return async(function()
        if not tournament or not tournament.board_data then
            print("[tourney] No board data stored for tournament")
            return
        end
        Net.toggle_player_hud(player_id)
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_name(player_area)
        Net.set_area_name(player_area, "            ")
        local original_map_song = Net.get_song(player_area)
        Net.set_song(player_area, "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")

        games.activate_framework(player_id)
        games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        
        -- Setup board background once (keep it open throughout)
        setup_board_bg_elements(player_id, tournament.board_data.background_info)
        
        -- PHASE 1: Show current state positions
        local current_positions = TournamentState.get_current_state_positions(tournament.tournament_id) or {}
        
        -- If no current positions, use initial positions
        if not current_positions or next(current_positions) == nil then
            current_positions = {}
            for i = 1, #tournament.board_data.stored_mugshots do
                if mug_pos.initial[i] then
                    current_positions[i] = mug_pos.initial[i]
                end
            end
        end
        
        -- Display all participants in their current positions
        for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
            if current_positions[i] then
                local pos = current_positions[i]
                add_participant_mugshot(player_id, i, mugshot_data.mug_texture, pos.x, pos.y, pos.z)
            end
        end
        
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        await(Async.sleep(0.3))
        
        print("[tourney] Showing CURRENT STATE for round " .. round_number)
        
        -- Let players see the current state
        await(Async.sleep(1.5))
        
        -- PHASE 2: Calculate new positions and animate transitions
        local new_positions = TournamentUtils.calculate_round_positions(tournament, round_number)
        
        if new_positions and next(new_positions) ~= nil then
            print("[tourney] Animating transitions to new positions")
            
            -- FIXED: Enhanced winner detection for all rounds with proper round 3 champion handling
            local winners_to_move = {}
            for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
                local current_pos = current_positions[i]
                local new_pos = new_positions[i]
                
                -- Check if this participant's position changed
                if current_pos and new_pos and 
                   (current_pos.x ~= new_pos.x or current_pos.y ~= new_pos.y) then
                    
                    -- More robust winner detection
                    local is_winner = false
                    
                    if round_number == 1 then
                        -- For round 1, check if they won their match
                        for _, match in ipairs(tournament.matches) do
                            if match.completed and match.winner and match.winner.player_id == mugshot_data.player_id then
                                is_winner = true
                                break
                            end
                        end
                    elseif round_number == 2 then
                        -- For round 2, check if they are in the winners list
                        for _, winner in ipairs(tournament.winners) do
                            if winner.player_id == mugshot_data.player_id then
                                is_winner = true
                                break
                            end
                        end
                    elseif round_number == 3 then
                        -- FIXED: For round 3, only the champion should move
                        for _, match in ipairs(tournament.matches) do
                            if match.completed and match.winner and match.winner.player_id == mugshot_data.player_id then
                                is_winner = true
                                print("[tourney] Champion detected: " .. mugshot_data.player_id)
                                break
                            end
                        end
                    end
                    
                    if is_winner then
                        table.insert(winners_to_move, {
                            index = i,
                            mugshot_data = mugshot_data,
                            from_pos = current_pos,
                            to_pos = new_pos
                        })
                        print(string.format("[tourney] Will move participant %d from (%d,%d) to (%d,%d) - round %d winner", 
                              i, current_pos.x, current_pos.y, new_pos.x, new_pos.y, round_number))
                    end
                end
            end
            
            -- Animate winners moving one by one
            for _, move_data in ipairs(winners_to_move) do
                print(string.format("[tourney] Moving winner mugshot %d", move_data.index))
                
                -- Remove from old position and add to new position
                remove_participant_mugshot(player_id, move_data.index)
                add_participant_mugshot(player_id, move_data.index, 
                    move_data.mugshot_data.mug_texture, 
                    move_data.to_pos.x, move_data.to_pos.y, move_data.to_pos.z)
                
                -- Brief pause between each movement
                await(Async.sleep(0.6))
            end
            
            -- Store the new positions as current state
            TournamentState.store_current_state_positions(tournament.tournament_id, new_positions)
            TournamentState.store_round_positions(tournament.tournament_id, round_number, new_positions)
            
            print("[tourney] Finished animating transitions")
            
            -- Final pause to let players see the updated board
            await(Async.sleep(1.5))
        else
            -- No position changes needed, just show for longer
            await(Async.sleep(2.0))
        end
        
        Net.toggle_player_hud(player_id)
        -- Clean up (only after everything is complete)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        cleanup_ui(player_id, player_area, original_map_name, original_map_song)
        await(Async.sleep(0.1))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
        return true
    end)
end

-- FIXED: Enhanced tournament board display with consistent participant shuffling
local function show_tournament_stage(player_id, tournament, stage_type, is_current_state)
    return async(function()
        if not tournament or not tournament.board_data then
            print("[tourney] No board data stored for tournament")
            return
        end
        
        Net.toggle_player_hud(player_id)
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_name(player_area)
        Net.set_area_name(player_area, "            ")
        local original_map_song = Net.get_song(player_area)
        Net.set_song(player_area, "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")

        games.activate_framework(player_id)
        games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        
        -- Setup board background
        setup_board_bg_elements(player_id, tournament.board_data.background_info)
        
        -- Get positions based on stage type and actual pairings
        local display_positions = {}
        
        if is_current_state then
            -- Show current state (positions from end of previous round)
            display_positions = TournamentState.get_current_state_positions(tournament.tournament_id) or {}
            print("[tourney] Showing CURRENT STATE for round " .. tournament.current_round)
        else
            -- Show updated state (new positions based on current round results)
            if stage_type == "initial" then
                -- Use initial positions
                for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
                    if mug_pos.initial[i] then
                        display_positions[i] = mug_pos.initial[i]
                    end
                end
                
            elseif stage_type == "round1_results" then
                -- Calculate positions based on round 1 pairings
                display_positions = TournamentUtils.calculate_round_positions(tournament, 1)
                
            elseif stage_type == "round2_results" then
                -- Calculate positions based on round 2 pairings
                display_positions = TournamentUtils.calculate_round_positions(tournament, 2)
                
            elseif stage_type == "champion" then
                -- Calculate positions for champion display
                display_positions = TournamentUtils.calculate_round_positions(tournament, 3)
            end
            print("[tourney] Showing UPDATED STATE for " .. stage_type)
        end
        
        -- Show ALL participants in their calculated positions
        for i, mugshot_data in ipairs(tournament.board_data.stored_mugshots) do
            if display_positions[i] then
                local pos = display_positions[i]
                add_participant_mugshot(player_id, i, mugshot_data.mug_texture, pos.x, pos.y, pos.z)
            elseif mug_pos.initial[i] then
                -- Fallback to initial position for any missing participants
                local pos = mug_pos.initial[i]
                add_participant_mugshot(player_id, i, mugshot_data.mug_texture, pos.x, pos.y, pos.z)
            end
        end
        
        -- STORE positions if this is an updated state (not current state display)
        if not is_current_state and stage_type ~= "initial" then
            local round_number = nil
            if stage_type == "round1_results" then round_number = 1
            elseif stage_type == "round2_results" then round_number = 2
            elseif stage_type == "champion" then round_number = 3 end
            
            if round_number then
                TournamentState.store_round_positions(tournament.tournament_id, round_number, display_positions)
                TournamentState.store_current_state_positions(tournament.tournament_id, display_positions)
                print("[tourney] Stored pairing-based positions for " .. stage_type)
            end
        elseif is_current_state then
            print("[tourney] Displayed current state, no storage needed")
        end
        
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        await(Async.sleep(12.5)) -- Show positions
        
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, 0.3)
        await(Async.sleep(0.3))
        cleanup_ui(player_id, player_area, original_map_name, original_map_song)
        Net.toggle_player_hud(player_id)
        await(Async.sleep(0.1))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, 0.3)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
    end)
end

local function show_board_to_all_players(tournament, show_function, stage_type, is_current_state, round_number)

        -- Show board to all real players sequentially, including those who were eliminated
        for _, participant in ipairs(tournament.participants) do
            if not string.find(participant.player_id, ".zip") and Net.is_player(participant.player_id) then
                if show_function == show_tournament_results_with_animation then
                    show_function(participant.player_id, tournament, round_number)
                else
                    show_function(participant.player_id, tournament, stage_type, is_current_state)
                end
            end
        end
end

-- FIXED: Enhanced battle starter with proper NPC predetermined result handling
local function start_battle(player1_id, player2_id, tournament_id, match_index)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then 
            print("[tourney] Tournament not found for battle")
            return nil 
        end
        
        local current_round = tournament.current_round
        local is_player1_npc = string.find(player1_id, ".zip")
        local is_player2_npc = string.find(player2_id, ".zip")
        
        TourneyEmitters.start_tourney_battle(player1_id, player2_id, tournament_id, match_index)
        
        -- Ensure players are unfrozen and framework is deactivated before battle
        local players_to_cleanup = {}
        if not is_player1_npc and Net.is_player(player1_id) then 
            games.deactivate_framework(player1_id)
            table.insert(players_to_cleanup, player1_id)
        end
        if not is_player2_npc and Net.is_player(player2_id) then 
            games.deactivate_framework(player2_id)
            table.insert(players_to_cleanup, player2_id)
        end
        
        if is_player1_npc and is_player2_npc then
            -- NPC vs NPC - instant resolution with weighted random
            print(string.format("[tourney] Starting NPC vs NPC battle for tournament %d, round %d, match %d: %s vs %s", 
                  tournament_id, current_round, match_index, player1_id, player2_id))
            
            -- FIXED: Use round-specific storage for NPC results
            local predetermined_result = TournamentState.get_npc_predetermined_result(tournament_id, match_index)
            
            local winner_id, loser_id
            
            -- FIXED: Only use predetermined result if it's for the current round and same players
            if predetermined_result and 
               predetermined_result.player1_id == player1_id and 
               predetermined_result.player2_id == player2_id and
               predetermined_result.round == current_round then
                -- Use predetermined result for consistency across all players
                winner_id = predetermined_result.winner_id
                loser_id = predetermined_result.loser_id
                print(string.format("[tourney] Using predetermined NPC result for round %d: %s defeated %s", 
                      current_round, winner_id, loser_id))
            else
                -- Determine result with weighted random and store it for consistency
                local npc1_weight = get_npc_weight(player1_id)
                local npc2_weight = get_npc_weight(player2_id)
                local total_weight = npc1_weight + npc2_weight
                local random_val = math.random(1, total_weight)
                
                if random_val <= npc1_weight then
                    winner_id = player1_id
                    loser_id = player2_id
                else
                    winner_id = player2_id
                    loser_id = player1_id
                end
                
                -- FIXED: Store the result with round and player info
                TournamentState.store_npc_predetermined_result(tournament_id, match_index, {
                    winner_id = winner_id,
                    loser_id = loser_id,
                    player1_id = player1_id,
                    player2_id = player2_id,
                    round = current_round,
                    weights = {npc1_weight, npc2_weight}
                })
                
                print(string.format("[tourney] New NPC battle result for round %d: %s defeated %s (weights: %d vs %d)", 
                      current_round, winner_id, loser_id, npc1_weight, npc2_weight))
            end
            
            -- Get tournament and match info to record the result
            if tournament and tournament.matches and tournament.matches[match_index] then
                local match = tournament.matches[match_index]
                local winner = match.player1.player_id == winner_id and match.player1 or match.player2
                local loser = match.player1.player_id == loser_id and match.player1 or match.player2
                
                -- FIXED: Add small delay to simulate battle and ensure proper synchronization
                await(Async.sleep(1.0))
                
                -- Record the battle result directly in tournament state
                TournamentState.record_battle_result(tournament_id, match_index, winner, loser)
                
                -- Emit battle completed event
                TourneyEmitters.tourney_emitter:emit("battle_completed", {
                    matchup = {player1_id = player1_id, player2_id = player2_id},
                    tournament_id = tournament_id,
                    match_index = match_index,
                    round = current_round
                })
                
                print(string.format("[tourney] NPC battle recorded for round %d, match %d", current_round, match_index))
            end
            
            return {player_id = winner_id, health = 100, ran = false}
        elseif is_player1_npc and Net.is_player(player2_id) then
            -- Player vs NPC - notify the player
            Net.lock_player_input(player2_id)
            local result = await(Async.initiate_encounter(player2_id, player1_id))
            Net.unlock_player_input(player2_id)
            return result
        elseif is_player2_npc and Net.is_player(player1_id) then
            -- Player vs NPC - notify the player
            Net.lock_player_input(player1_id)
            local result = await(Async.initiate_encounter(player1_id, player2_id))
            Net.unlock_player_input(player1_id)
            return result
        elseif Net.is_player(player1_id) and Net.is_player(player2_id) then
            -- PvP - notify both players
            Net.lock_player_input(player1_id)
            Net.lock_player_input(player2_id)
            local result = await(Async.initiate_pvp(player1_id, player2_id))
            Net.unlock_player_input(player1_id)
            Net.unlock_player_input(player2_id)
            return result
        else
            -- One or both players disconnected, handle accordingly
            print("[tourney] One or both players disconnected, cannot start battle")
            return nil
        end
        
        -- Re-activate framework for players after battle if needed
        for _, player_id in ipairs(players_to_cleanup) do
            if Net.is_player(player_id) then
                games.activate_framework(player_id)
                games.freeze_player(player_id)
            end
        end
    end)
end

-- NEW: Function to start all battles without waiting for completion
local function start_all_battles(tournament_id)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return end
        
        -- Start all battles - they will be handled by the battle_results event
        for i, match in ipairs(tournament.matches) do
            local player1_id = match.player1.player_id
            local player2_id = match.player2.player_id
            local is_npc_battle = string.find(player1_id, ".zip") and string.find(player2_id, ".zip")
            
            if not is_npc_battle then
                -- Close any open text boxes for human players before battle
                if not string.find(player1_id, ".zip") then
                    Net.close_bbs(player1_id)
                end
                if not string.find(player2_id, ".zip") then
                    Net.close_bbs(player2_id)
                end
                
                -- Start the battle - results will be handled by Net:on("battle_results")
                print("[tourney] Starting player battle: " .. player1_id .. " vs " .. player2_id)
                start_battle(player1_id, player2_id, tournament_id, i)
                
                -- Small delay to prevent overwhelming the server
                await(Async.sleep(0.5))
            end
        end
        
        print("[tourney] All battles started for round " .. tournament.current_round)
    end)
end

-- NEW: Enhanced battle waiting function that never forces player battles
local function wait_for_all_battles_complete(tournament_id)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return true end
        
        print("[tourney] Waiting for all battles to complete naturally...")
        
        while true do
            local all_completed = true
            local completed_count = 0
            local player_battles_remaining = 0
            
            for i, match in ipairs(tournament.matches) do
                if match.completed then
                    completed_count = completed_count + 1
                else
                    all_completed = false
                    
                    -- Check if this is a player battle (at least one real player)
                    local is_player1_human = not string.find(match.player1.player_id, ".zip")
                    local is_player2_human = not string.find(match.player2.player_id, ".zip")
                    
                    if is_player1_human or is_player2_human then
                        player_battles_remaining = player_battles_remaining + 1
                        print(string.format("[tourney] Player battle pending: %s vs %s", 
                              match.player1.player_id, match.player2.player_id))
                    else
                        -- NPC vs NPC battle - we can process these immediately
                        print(string.format("[tourney] NPC battle pending: %s vs %s", 
                              match.player1.player_id, match.player2.player_id))
                    end
                end
            end
            
            if all_completed then
                print(string.format("[tourney] All %d battles completed successfully", completed_count))
                return true
            end
            
            -- Only force NPC-vs-NPC battles, never player battles
            if player_battles_remaining == 0 then
                -- All remaining battles are NPC-vs-NPC, we can force them
                print("[tourney] All player battles completed, forcing remaining NPC battles")
                for i, match in ipairs(tournament.matches) do
                    if not match.completed then
                        local is_npc_battle = string.find(match.player1.player_id, ".zip") and 
                                             string.find(match.player2.player_id, ".zip")
                        if is_npc_battle then
                            -- Force NPC battle result
                            local npc1_weight = get_npc_weight(match.player1.player_id)
                            local npc2_weight = get_npc_weight(match.player2.player_id)
                            local winner, loser
                            
                            if math.random(1, npc1_weight + npc2_weight) <= npc1_weight then
                                winner = match.player1
                                loser = match.player2
                            else
                                winner = match.player2
                                loser = match.player1
                            end
                            
                            match.completed = true
                            match.winner = winner
                            match.loser = loser
                            TournamentState.record_battle_result(tournament_id, i, winner, loser)
                            print(string.format("[tourney] Forced NPC battle result: %s defeated %s", 
                                  winner.player_id, loser.player_id))
                        end
                    end
                end
            else
                print(string.format("[tourney] Waiting for battles: %d/%d completed, %d player battles remaining", 
                      completed_count, #tournament.matches, player_battles_remaining))
                
                -- Wait longer for player battles
                await(Async.sleep(5.0)) -- Increased from 2.0 to 5.0 seconds
            end
            
            -- Refresh tournament data
            tournament = TournamentState.get_tournament(tournament_id)
            if not tournament then break end
        end
        
        return true
    end)
end

-- NEW: Function to get battle progress details
local function get_battle_progress(tournament_id)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return {} end
    
    local progress = {
        total_matches = #tournament.matches,
        completed_matches = 0,
        player_battles = 0,
        npc_battles = 0,
        pending_player_battles = 0,
        pending_npc_battles = 0
    }
    
    for _, match in ipairs(tournament.matches) do
        local is_player1_human = not string.find(match.player1.player_id, ".zip")
        local is_player2_human = not string.find(match.player2.player_id, ".zip")
        local is_player_battle = is_player1_human or is_player2_human
        
        if match.completed then
            progress.completed_matches = progress.completed_matches + 1
        else
            if is_player_battle then
                progress.pending_player_battles = progress.pending_player_battles + 1
            else
                progress.pending_npc_battles = progress.pending_npc_battles + 1
            end
        end
        
        if is_player_battle then
            progress.player_battles = progress.player_battles + 1
        else
            progress.npc_battles = progress.npc_battles + 1
        end
    end
    
    return progress
end

-- NEW: Protected battle starter that ensures players are ready
local function start_battle_with_protection(player1_id, player2_id, tournament_id, match_index)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return nil end
        
        local is_player1_human = not string.find(player1_id, ".zip")
        local is_player2_human = not string.find(player2_id, ".zip")
        
        -- For player battles, ensure both players are ready and connected
        if is_player1_human or is_player2_human then
            if is_player1_human and not Net.is_player(player1_id) then
                print("[tourney] Player 1 disconnected, cannot start battle")
                return nil
            end
            if is_player2_human and not Net.is_player(player2_id) then
                print("[tourney] Player 2 disconnected, cannot start battle")
                return nil
            end
            
            print(string.format("[tourney] Starting protected player battle: %s vs %s", player1_id, player2_id))
        end
        
        return await(start_battle(player1_id, player2_id, tournament_id, match_index))
    end)
end

-- NEW: Function to verify tournament state before showing results
local function verify_tournament_state(tournament_id, round_number)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then
        print("[tourney] Tournament not found for verification")
        return false
    end
    
    print(string.format("[tourney] Verifying tournament state for round %d", round_number))
    
    -- Check round results
    local round_results = tournament.round_results[round_number] or {}
    print(string.format("[tourney] Round %d has %d results", round_number, #round_results))
    
    -- Check matches
    print(string.format("[tourney] Tournament has %d matches in round %d", #tournament.matches, tournament.current_round))
    
    for i, match in ipairs(tournament.matches) do
        print(string.format("[tourney] Match %d: %s vs %s - completed: %s", 
              i, match.player1.player_id, match.player2.player_id, tostring(match.completed)))
        if match.completed then
            print(string.format("[tourney]   Winner: %s, Loser: %s", 
                  match.winner.player_id, match.loser.player_id))
        local tourney = TournamentState.get_tournament(tournament_id)
        end
    end
    
    -- Check winners
    print(string.format("[tourney] Tournament has %d winners", #tournament.winners))
    for i, winner in ipairs(tournament.winners) do
        print(string.format("[tourney] Winner %d: %s", i, winner.player_id))
    end
    
    return true
end

-- FIXED: Enhanced tournament battles with proper synchronization and NPC handling
local function run_tournament_battles(tournament_id)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return end
        
        print("[tourney] Starting tournament battles for round " .. tournament.current_round)
        
        -- FIRST: Show current state of the board before any battles to all players
        if tournament.current_round == 1 then
            print("[tourney] Showing initial tournament board to all players")
            show_board_to_all_players(tournament, show_tournament_stage, "initial", false)
            await(Async.sleep(2.0)) -- Additional pause after all boards are shown
        else
            -- For subsequent rounds, show the CURRENT STATE (positions from previous round)
            print("[tourney] Showing CURRENT STATE before round " .. tournament.current_round .. " battles to all players")
            show_board_to_all_players(tournament, show_tournament_stage, "current_state", true)
            await(Async.sleep(2.0)) -- Additional pause after all boards are shown
        end
        
        -- FIXED: Process NPC battles sequentially with proper delays
        local npc_battles_started = 0
        for i, match in ipairs(tournament.matches) do
            local player1_id = match.player1.player_id
            local player2_id = match.player2.player_id
            local is_npc_battle = string.find(player1_id, ".zip") and string.find(player2_id, ".zip")
            
            if is_npc_battle then
                npc_battles_started = npc_battles_started + 1
                print(string.format("[tourney] Starting NPC vs NPC battle %d/%d: %s vs %s", 
                      npc_battles_started, #tournament.matches, player1_id, player2_id))
                await(start_battle(player1_id, player2_id, tournament_id, i))
                -- FIXED: Add delay between NPC battles to ensure proper sequencing
                if npc_battles_started < #tournament.matches then
                    await(Async.sleep(1.0))
                end
            end
        end
        
        -- Then, start all player battles - results will be handled by Net:on("battle_results")
        if npc_battles_started < #tournament.matches then
            await(start_all_battles(tournament_id))
        end
        
        print("[tourney] All battles started for round " .. tournament.current_round)
        
        -- FIXED: Use enhanced waiting with verification
        local battles_completed = await(wait_for_all_battles_complete(tournament_id))
        
        if not battles_completed then
            print("[tourney] WARNING: Not all battles completed properly, but proceeding anyway")
            -- Force completion of any remaining matches
            for i, match in ipairs(tournament.matches) do
                if not match.completed then
                    print("[tourney] Forcing completion of match " .. i)
                    -- For NPC battles, determine winner by weight
                    if string.find(match.player1.player_id, ".zip") and string.find(match.player2.player_id, ".zip") then
                        local npc1_weight = get_npc_weight(match.player1.player_id)
                        local npc2_weight = get_npc_weight(match.player2.player_id)
                        local winner, loser
                        
                        if math.random(1, npc1_weight + npc2_weight) <= npc1_weight then
                            winner = match.player1
                            loser = match.player2
                        else
                            winner = match.player2
                            loser = match.player1
                        end
                        
                        match.completed = true
                        match.winner = winner
                        match.loser = loser
                        TournamentState.record_battle_result(tournament_id, i, winner, loser)
                        print(string.format("[tourney] Forced NPC battle result: %s defeated %s", winner.player_id, loser.player_id))
                    else
                        -- PLAYER BATTLES ARE NEVER FORCED - they must complete naturally
                        print(string.format("[tourney] NOT forcing player battle: %s vs %s - waiting for natural completion", 
                              match.player1.player_id, match.player2.player_id))
                              print("[tourney] Round " .. tournament.current_round .. " winners:")
                        for i, winner in ipairs(tournament.winners) do
                        print(string.format("  Winner %d: %s", i, winner.player_id))
                        end
                        -- Do not force player battles - they will complete naturally
                    end
                end
            end
        end
        
        print("[tourney] All battles completed for round " .. tournament.current_round)
        
        -- FIXED: Add additional delay to ensure all battle results are processed
        await(Async.sleep(1.0))
        
        -- FIXED: Verify tournament state before showing results
        verify_tournament_state(tournament_id, tournament.current_round)
        
        -- Show appropriate results board after the round is complete
        local results_stage = nil
        if tournament.current_round == 1 then
            results_stage = "round1_results"
        elseif tournament.current_round == 2 then
            results_stage = "round2_results" 
        elseif tournament.current_round == 3 then
            results_stage = "champion"
        end
        
        if results_stage then
            print("[tourney] Showing tournament UPDATED STATE with animations: " .. results_stage)
            
            local round_number = nil
            if results_stage == "round1_results" then round_number = 1
            elseif results_stage == "round2_results" then round_number = 2
            elseif results_stage == "champion" then round_number = 3 end
            
            -- Use the new animation function for seamless transitions
            show_board_to_all_players(tournament, show_tournament_results_with_animation, nil, nil, round_number)
            await(Async.sleep(5.0)) -- Additional pause after all boards are shown
        end

        local current_real_players = {}
        for _, winner in ipairs(tournament.winners) do
            if not string.find(winner.player_id, ".zip") and Net.is_player(winner.player_id) then
                table.insert(current_real_players, winner)
            end
        end

        -- FIXED: Don't end tournament if no real players remain - let NPCs finish and show results
        -- Instead, check if we should continue with NPC-only tournament
        if #current_real_players == 0 then
            print("[tourney] No real players left after round " .. tournament.current_round .. ", continuing with NPCs")
            
            -- Check if tournament is completed (after 3 rounds)
            if is_tournament_completed(tournament) then
                print("[tourney] Tournament completed with NPCs only! Winner: " .. tournament.winners[1].player_id)
                
                -- Announce winner to any real players who might still be watching (spectators)
                local winner = tournament.winners[1]
                local winner_name = winner.player_id
                if not string.find(winner.player_id, ".zip") and Net.is_player(winner.player_id) then
                    winner_name = Net.get_player_name(winner.player_id) or winner.player_id
                else
                    -- Extract NPC name for display
                    local npc_name = string.match(winner.player_id, "([^/]+)/[^/]+$") or winner.player_id
                    winner_name = npc_name
                end
                
                -- Show final results to all original participants who are still connected
                for _, participant in ipairs(tournament.participants) do
                    if not string.find(participant.player_id, ".zip") and Net.is_player(participant.player_id) then
                        Net.message_player(participant.player_id, "Tournament completed! Winner: " .. winner_name)
                        await(Async.sleep(0.1)) -- Small delay between messages
                    end
                end
                
                -- Clean up all players and remove tournament
                for _, participant in ipairs(tournament.participants) do
                    if not string.find(participant.player_id, ".zip") and Net.is_player(participant.player_id) then
                        games.deactivate_framework(participant.player_id)
                        TournamentState.remove_player_from_tournament(participant.player_id)
                    end
                end
                 cleanup_tournament_parties(tournament_id)
    
        TournamentState.cleanup_tournament(tournament_id)
            print("[tourney] Tournament " .. tournament_id .. " completed with NPC winner")
            return
            end
        end

        -- Check if tournament is completed (after 3 rounds)
        if is_tournament_completed(tournament) then
            print("[tourney] Tournament completed! Winner: " .. tournament.winners[1].player_id)
            
            -- Announce winner to all players AFTER the final board has closed
            local winner = tournament.winners[1]
            local winner_name = winner.player_id
            if not string.find(winner.player_id, ".zip") and Net.is_player(winner.player_id) then
                winner_name = Net.get_player_name(winner.player_id) or winner.player_id
            else
                -- Extract NPC name for display
                local npc_name = string.match(winner.player_id, "([^/]+)/[^/]+$") or winner.player_id
                winner_name = npc_name
            end
            
            -- Show final results to all original participants who are still connected
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") and Net.is_player(participant.player_id) then
                    Net.message_player(participant.player_id, "Tournament completed! Winner: " .. winner_name)
                    await(Async.sleep(0.1)) -- Small delay between messages
                end
            end
            
            -- FIXED: Clean up ALL real players from tournament tracking, regardless of when they were eliminated
            print("[tourney] Cleaning up all real players from tournament " .. tournament_id)
            local players_cleaned_up = {}
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    if Net.is_player(participant.player_id) then
                        games.deactivate_framework(participant.player_id)
                        Net.message_player(participant.player_id, "The tournament has ended. You are now free to join other tournaments.")
                    end
                    -- Remove from tournament tracking even if player is disconnected
                    TournamentState.remove_player_from_tournament(participant.player_id)
                    table.insert(players_cleaned_up, participant.player_id)
                end
            end
            
            print("[tourney] Cleaned up " .. #players_cleaned_up .. " players: " .. table.concat(players_cleaned_up, ", "))
            
        -- NEW: Clean up parties and waiting queues
         cleanup_tournament_parties(tournament_id)

         -- NEW: Force cleanup of the tournament regardless of NPC win
         TournamentState.cleanup_tournament(tournament_id)
         print("[tourney] Tournament " .. tournament_id .. " completely removed after completion (NPC winner)")
        end

        await(Async.sleep(2.0))
        -- Ask host if they want to start next round
        local start_next_round = await(TournamentUtils.ask_host_about_next_round(tournament_id, TournamentState))
        
        -- DEBUG: Print the host's decision
        print("[tourney] Host decision for next round: " .. tostring(start_next_round))
        
        if start_next_round then
            -- Advance to next round
            if TournamentState.advance_to_next_round(tournament_id) then
                local tournament = TournamentState.get_tournament(tournament_id)
                if tournament and tournament.status == "COMPLETED" then
                    -- Tournament is complete
                    print("[tourney] Tournament completed!")
                    
                    -- Announce winner
                    local winner = tournament.winners[1]
                    if winner then
                        local winner_name = winner.player_id
                        if not string.find(winner.player_id, ".zip") then
                            winner_name = Net.get_player_name(winner.player_id) or winner.player_id
                        end
                        
                        for _, participant in ipairs(tournament.participants) do
                            if not string.find(participant.player_id, ".zip") then
                                Net.message_player(participant.player_id, "Tournament completed! Winner: " .. winner_name)
                                await(Async.sleep(0.1)) -- Small delay between messages
                            end
                        end
                    end
                    
                    -- Clean up all players
                    for _, participant in ipairs(tournament.participants) do
                        if not string.find(participant.player_id, ".zip") then
                            games.deactivate_framework(participant.player_id)
                            -- Remove player from tournament tracking
                            TournamentState.remove_player_from_tournament(participant.player_id)
                        end
                    end
                else
                    -- Start next round
                    print("[tourney] Starting next round...")
                    await(run_tournament_battles(tournament_id))
                end
            else
                print("[tourney] Failed to advance to next round - checking tournament state")
                -- Debug: Check why advancement failed
                local tournament = TournamentState.get_tournament(tournament_id)
                if tournament then
                    print("[tourney] Tournament status: " .. (tournament.status or "nil"))
                    print("[tourney] Current round: " .. tournament.current_round)
                    print("[tourney] Winners count: " .. #tournament.winners)
                    print("[tourney] Matches count: " .. #tournament.matches)
                    
                    -- Check if all matches are completed
                    local all_matches_completed = true
                    for _, match in ipairs(tournament.matches) do
                        if not match.completed then
                            all_matches_completed = false
                            print("[tourney] Match not completed: " .. match.player1.player_id .. " vs " .. match.player2.player_id)
                            break
                        end
                    end
                    
                    -- Force advancement if we have winners but some matches didn't complete properly
                    if #tournament.winners > 0 then
                        print("[tourney] Attempting forced advancement with existing winners")
                        tournament.current_round = tournament.current_round + 1
                        tournament.participants = tournament.winners
                        tournament.winners = {}
                        tournament.matches = TournamentState.generate_matches(tournament.participants)
                        tournament.status = "IN_PROGRESS"
                        
                        -- Start next round
                        print("[tourney] Starting next round after forced advancement...")
                        await(run_tournament_battles(tournament_id))
                    else
                        print("[tourney] Cannot force advancement, ending tournament")
                        TournamentState.cleanup_tournament(tournament_id)
                    end
                else
                    print("[tourney] Tournament not found, ending")
                end
            end
        else
    -- Host chose not to continue, end tournament
    print("[tourney] Host chose to end tournament after round " .. tournament.current_round)
    
    -- Clean up all players
    for _, participant in ipairs(tournament.participants) do
        if not string.find(participant.player_id, ".zip") then
            games.deactivate_framework(participant.player_id)
            -- Remove player from tournament tracking
            TournamentState.remove_player_from_tournament(participant.player_id)
        end
    end
    
    -- NEW: Clean up parties
    cleanup_tournament_parties(tournament_id)
    
    TournamentState.cleanup_tournament(tournament_id)
    end
end)
end

---------------------------------------------------------------------
-- UI and Board Management Functions
---------------------------------------------------------------------

-- FIXED: Modified to shuffle participants ONLY ONCE when tournament is created
local function initialize_tournament_participants(participants, backfill, tournament_type, preserve_order)
    local final = {}
    
    -- Always preserve the original human player order for consistency if requested
    if preserve_order then
        -- Use the participants in the order they were provided (for consistent multiplayer tournaments)
        for _, p in next, participants do 
            local participant_copy = {
                player_id = p.player_id,
                player_mugshot = {
                    mug_texture = p.player_mugshot.mug_texture,
                    mug_animation = p.player_mugshot.mug_animation
                }
            }
            table.insert(final, participant_copy)
        end
    else
        -- For single player or when order doesn't matter, create copies
        for _, p in next, participants do 
            local participant_copy = {
                player_id = p.player_id,
                player_mugshot = {
                    mug_texture = p.player_mugshot.mug_texture,
                    mug_animation = p.player_mugshot.mug_animation
                }
            }
            table.insert(final, participant_copy)
        end
    end
    
    if backfill and #final < 8 then
        local fill = TableUtils.SelectRandomItemsFromTableClamped(npc_paths, 8 - #final)
        for _, f in next, fill do 
            -- Create deep copies of NPC data to avoid shared references
            local npc_copy = {
                player_id = f.player_id,
                player_mugshot = {
                    mug_texture = f.player_mugshot.mug_texture,
                    mug_animation = f.player_mugshot.mug_animation
                }
            }
            table.insert(final, npc_copy)
        end
    end
    
    -- FIXED: Only shuffle if we have 8 participants AND we're not preserving order for multiplayer
    if #final >= 8 and not preserve_order then
        final = TableUtils.shuffle(final)
        print("[tourney] Shuffled participants for single player tournament")
    elseif preserve_order then
        print("[tourney] Preserving participant order for multiplayer tournament consistency")
    end
    
    -- Ensure we have exactly 8 participants
    return TableUtils.SelectRandomItemsFromTableClamped(final, 8)
end

-- FIXED: Enhanced function to ensure participant consistency with single randomization
local function create_consistent_tournament(player_id, object_id, area_id, board_background_setup_info, is_single_player)
    return async(function()
        local tournament_participants
        
        if is_single_player then
            local mug = Net.get_player_mugshot(player_id).texture_path
            tournament_participants = initialize_tournament_participants(
                { { player_id = player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug } } }, 
                true,  -- backfill
                "single",  -- single player tournament type
                false  -- DO shuffle for single player
            )
        else
            -- For multiplayer, use the existing queue and DO NOT shuffle to preserve PvP integrity
            local board_tournament = tourney_boards[area_id][object_id].active_tournaments
            tournament_participants = initialize_tournament_participants(
                board_tournament, 
                true,  -- backfill  
                "multiplayer",  -- multiplayer tournament type
                true  -- PRESERVE order for multiplayer consistency
            )
        end
        
        -- Create tournament
        local tournament_id = TournamentState.create_tournament(object_id, area_id, player_id)
        
        -- Store the initial participant order in tournament state for consistency
        local tournament = TournamentState.get_tournament(tournament_id)
        tournament.initial_participant_order = {}
        for i, participant in ipairs(tournament_participants) do
            tournament.initial_participant_order[i] = {
                player_id = participant.player_id,
                initial_index = i
            }
        end
        
        -- Add participants in the consistent order (whether shuffled or preserved)
        for _, participant in ipairs(tournament_participants) do
            TournamentState.add_participant(tournament_id, participant)
        end
        
        -- NEW: Initialize participant states
        TournamentState.initialize_participant_states(tournament_id)
        
        -- Store board data with the consistent participant order
        store_tournament_board_data(tournament_id, board_background_setup_info, tournament_participants)
        
        -- DEBUG: Print the final participant order for verification
        print("[tourney] Final tournament participant order:")
        for i, participant in ipairs(tournament_participants) do
            local player_type = string.find(participant.player_id, ".zip") and "NPC" or "Player"
            print(string.format("  Position %d: %s (%s)", i, participant.player_id, player_type))
        end
        
        if TournamentState.start_tournament(tournament_id) then
            return tournament_id, tournament_participants
        end
        
        return nil, nil
    end)
end
---------------------------------------------------------------------
-- Board Initialization
---------------------------------------------------------------------

local function get_board_properties(boards_in, area_id)
    if not area_id then return end
    local sanitized_board = {}
    for i, value in next, boards_in do
        sanitized_board = { area_id = i, boards = {} }
        for _, detail in next, value do
            if detail.custom_properties then
                sanitized_board.boards[detail.id] = detail.custom_properties
            end
        end
    end
    return sanitized_board
end

local function gather_boards()
    for _, area_id in next, Net.list_areas() do
        local boards = TableUtils.GetAllTiledObjOfXType(area_id, "Tournament Board")
        if #boards > 0 then
            local props_result = get_board_properties({ [area_id] = boards }, area_id)
            if props_result then
                tourney_boards[area_id] = props_result.boards
                for _, b in pairs(props_result.boards) do b.active_tournaments = {} end
            end
        end
    end
end
gather_boards()

-- NEW: Function to cleanup orphaned parties (parties that don't have active tournaments)
local function cleanup_orphaned_parties()
    local parties_cleared = 0
    local waiting_cleared = 0
    
    -- Clear all board parties (they should be recreated as needed)
    for area_id, boards in pairs(tourney_boards) do
        for object_id, board_data in pairs(boards) do
            if board_data.active_tournaments and #board_data.active_tournaments > 0 then
                local had_parties = #board_data.active_tournaments
                board_data.active_tournaments = {}
                parties_cleared = parties_cleared + had_parties
            end
        end
    end
    
    -- Clear waiting players
    for player_id, waiting_data in pairs(TourneyEmitters.players_waiting) do
        if waiting_data then
            TourneyEmitters.players_waiting[player_id] = nil
            waiting_cleared = waiting_cleared + 1
            
            -- Cleanup any active countdowns
            if active_countdowns[player_id] then
                games.deactivate_framework(player_id)
                active_countdowns[player_id] = nil
            end
        end
    end
    
    if parties_cleared > 0 or waiting_cleared > 0 then
        print(string.format("[tourney] Cleanup: Cleared %d orphaned parties and %d waiting players", 
              parties_cleared, waiting_cleared))
    end
end


---------------------------------------------------------------------
-- Event Handlers
---------------------------------------------------------------------
Net:on("object_interaction", function(event)
    local player_id = event.player_id
    local player_area = Net.get_player_area(player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type ~= "Tournament Board" and object.class ~= "Tournament Board" then return end

    -- FIXED: Enhanced check - verify the tournament actually exists
    if TournamentState.is_player_in_tournament(player_id) then
        local tournament_id = TournamentState.get_tournament_id_by_player(player_id)
        local tournament = TournamentState.get_tournament(tournament_id)
        
        if not tournament then
            -- Tournament doesn't exist but player is still tracked - clean up
            print("[tourney] Cleaning up orphaned player " .. player_id .. " from non-existent tournament")
            TournamentState.remove_player_from_tournament(player_id)
        else
            Net.message_player(player_id, "You are already in a tournament!")
            return
        end
    end

    if player_interaction_locks[player_id] then
        print("[tourney] Ignoring duplicate interaction for " .. player_id)
        return
    end
    player_interaction_locks[player_id] = true

    local board_background_setup_info = TournamentUtils.get_board_background_and_grid(object, TiledUtils, constants)
    async(function()
        local cleanup = function() player_interaction_locks[player_id] = nil end
        local success, err = pcall(function()
            local board_tournament = tourney_boards[player_area][event.object_id].active_tournaments
            if #board_tournament < 8 and #board_tournament >= 1 then
                local manager = Net.get_player_name(board_tournament[1].player_id)
                await(Async.message_player(event.player_id, "Would you like to join " .. manager .. "'s tournament?"))
                local result = await(Async.quiz_player(event.player_id,
                    "Join", "Start New", "Quit"))
                if result == 0 then
                  local mug = Net.get_player_mugshot(event.player_id).texture_path
                    local pos = #board_tournament + 1
                    tourney_boards[player_area][event.object_id].active_tournaments[pos] =
                        { player_id = event.player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug } }
                elseif result == 1 then
                   await(Async.message_player(event.player_id, "Would you like to start a tournament?"))
                    local new_result = await(Async.quiz_player(event.player_id, "Multi-player", "Single Player", "Quit" ))
                    if new_result == 0 then
                        join_or_create_party(event.player_id, event.object_id, false)
                        -- Clean up framework before starting countdown to prevent conflicts
                        games.activate_framework(event.player_id)
                        Net.lock_player_input(event.player_id)
                        -- Track this countdown
                        active_countdowns[event.player_id] = true
                        games.spawn_countdown(event.player_id, 100, 20, 10, duration)
                        games.start_countdown(event.player_id)
                        TourneyEmitters.players_waiting[event.player_id] = { waiting = true, tourney_board = event.object_id }
                    elseif new_result == 1 then
                        local tournament_id, participants = await(create_consistent_tournament(
                                event.player_id, event.object_id, player_area, board_background_setup_info, true
                            ))
                        if tournament_id then
                            -- REMOVED: No longer show initial board here - it will be shown in run_tournament_battles
                            -- Run battles directly
                            await(run_tournament_battles(tournament_id))
                        end    
                    else  
                        print("Player chose to quit")
                        end
                    end
            else
                    await(Async.message_player(event.player_id, "Would you like to start a tournament?"))
                    local new_result = await(Async.quiz_player(event.player_id, "Multi-player", "Single Player", "Quit" ))
                    if new_result == 0 then
                        join_or_create_party(event.player_id, event.object_id, false)
                        -- Clean up framework before starting countdown to prevent conflicts
                        games.activate_framework(event.player_id)
                        Net.lock_player_input(event.player_id)
                        -- Track this countdown
                        active_countdowns[event.player_id] = true
                        games.spawn_countdown(event.player_id, 100, 20, 10, duration)
                        games.start_countdown(event.player_id)
                        TourneyEmitters.players_waiting[event.player_id] = { waiting = true, tourney_board = event.object_id }
                    elseif new_result == 1 then
                        local tournament_id, participants = await(create_consistent_tournament(
                                event.player_id, event.object_id, player_area, board_background_setup_info, true
                            ))

                        if tournament_id then
                            -- REMOVED: No longer show initial board here - it will be shown in run_tournament_battles
                            -- Run battles directly
                            await(run_tournament_battles(tournament_id))
                        end    
                    else 
                        print("Player chose to quit")
                    end
                end
        end)
        cleanup()
        if not success then print("[tourney ERROR] " .. tostring(err)) end
    end)
end)

Net:on("countdown_ended", function(event)
    return async(function()
        if TourneyEmitters.players_waiting[event.player_id] == nil then
            print("nil")
            -- Remove countdown if it exists
            if active_countdowns[event.player_id] then
                games.deactivate_framework(event.player_id)
                active_countdowns[event.player_id] = nil
            end
            return
        end 
        
        local player_area = Net.get_player_area(event.player_id)
        local entry = TourneyEmitters.players_waiting[event.player_id]
        
        -- Always remove the countdown and clean up framework when it ends
        games.deactivate_framework(event.player_id)
        active_countdowns[event.player_id] = nil
        
        local board_info = tourney_boards[player_area][entry.tourney_board]
        print(board_info)
        Net.message_player(event.player_id,
            "There is currently " .. #board_info.active_tournaments .. "/8 in your tournament queue. What would you like to do?")
        
        local result = await(Async.quiz_player(event.player_id, "Backfill", "Wait", "Quit"))
        
        if result == 0 then -- Backfill
            local object = Net.get_object_by_id(player_area, entry.tourney_board)
            local board_background_setup_info = TournamentUtils.get_board_background_and_grid(object, TiledUtils, constants)
            
            -- FIXED: Use consistent tournament creation with shuffling
            local tournament_id, tournament_participants = await(create_consistent_tournament(
                event.player_id, entry.tourney_board, player_area, board_background_setup_info, false
            ))
            
            if tournament_id then
                -- REMOVED: No longer show initial board to each player - it will be shown in run_tournament_battles
                -- Run battles directly
                await(run_tournament_battles(tournament_id))
            end
            
        elseif result == 1 then -- Wait
            print("[tourney] Player requested to wait for more players.")
            
            -- Restart countdown with fresh framework
            games.activate_framework(event.player_id)
            Net.lock_player_input(event.player_id)
            
            active_countdowns[event.player_id] = true
            games.spawn_countdown(event.player_id, 100, 20, 10, duration)
            games.start_countdown(event.player_id)
            
            TourneyEmitters.players_waiting[event.player_id] = {
                waiting = true,
                tourney_board = entry.tourney_board
            }
        elseif result == 2 then
            board_info.active_tournaments = {}
            return
        end
    end)
end)


-- Enhanced battle results handler with disqualification support and proper NPC battle detection
Net:on("battle_results", function(event)
    print("[tourney] Battle results received:", event.player_id, event.health, event.time, event.ran)
    
    -- Find which tournament this player is in
    local tournament_id = TournamentState.get_tournament_id_by_player(event.player_id)
    if not tournament_id then
        print("[tourney] Player not in any tournament: " .. event.player_id)
        return
    end
    
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return end
    
    -- Find the match this player was in
    local match_index = nil
    for i, match in ipairs(tournament.matches) do
        if not match.completed and (match.player1.player_id == event.player_id or match.player2.player_id == event.player_id) then
            match_index = i
            break
        end
    end
    
    if not match_index then
        print("[tourney] No active match found for player: " .. event.player_id)
        return
    end
    
    -- Process battle results to determine winner and loser
    local winner, loser = TournamentUtils.process_battle_results(event, tournament_id, match_index, TournamentState)
    
    if winner and loser then
        -- Record the battle result
        TournamentState.record_battle_result(tournament_id, match_index, winner, loser)
        
        print("[tourney] Battle completed: " .. winner.player_id .. " defeated " .. loser.player_id)
        
        -- Handle player running (disqualification)
        if event.ran then
            print("[tourney] Player ran from battle: " .. event.player_id)
            -- The loser is already set above, no additional action needed
        end
        
        TourneyEmitters.handle_battle_result(event)
    else
        print("[tourney] Could not determine battle winner/loser")
    end
end)

-- Enhanced battle completion handler
TourneyEmitters.tourney_emitter:on("battle_completed", function(event)
    return async(function()
        local matchup = event.matchup
        local battle_data = event.battle_data
        local tournament_id = event.tournament_id
        local match_index = event.match_index
        
        if tournament_id and match_index then
            local tournament = TournamentState.get_tournament(tournament_id)
            if tournament then
                -- Check if round is complete
                local round_complete = true
                for _, match in ipairs(tournament.matches) do
                    if not match.completed then
                        round_complete = false
                        break
                    end
                end
                
                if round_complete then
                    tournament.status = "ROUND_COMPLETE"
                    print("[tourney] Round " .. tournament.current_round .. " completed")
                    
                    -- The next round will be started by run_tournament_battles after host confirmation
                end
            end
        end
    end)
end)



-- NEW: Function to periodically check for and clean up stuck tournaments
local function cleanup_stuck_tournaments()
    print("[tourney] Running stuck tournament cleanup check...")
    local tournaments_cleaned = 0
    
    for tournament_id, tournament in pairs(TournamentState.get_all_tournaments() or {}) do
        -- Check if tournament should be completed but isn't cleaned up
        if tournament.status == "COMPLETED" or (tournament.current_round >= 3 and #tournament.winners == 1) then
            print("[tourney] Cleaning up stuck completed tournament: " .. tournament_id)
            
            -- Clean up any remaining real players
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    TournamentState.remove_player_from_tournament(participant.player_id)
                end
            end
            
            -- NEW: Clean up parties
            cleanup_tournament_parties(tournament_id)
            
            TournamentState.cleanup_tournament(tournament_id)
            tournaments_cleaned = tournaments_cleaned + 1
        end
    end
    
    -- NEW: Also cleanup orphaned parties (parties without active tournaments)
    cleanup_orphaned_parties()
    
    if tournaments_cleaned > 0 then
        print("[tourney] Cleaned up " .. tournaments_cleaned .. " stuck tournaments")
    end
end

-- Run cleanup every 5 minutes
Net:on("on_tick", function(event)
    local timer = 0
    timer = timer + event.delta
    if timer % (60 * 5) == 0 then -- Every 5 minutes
        cleanup_stuck_tournaments()
        timer = 0
    end
end)

-- Enhanced player disconnect handler with disqualification and host reassignment
Net:on("player_disconnect", function(event)
    -- Remove player from any active tournaments and handle disqualification
    local tournament_id = TournamentState.get_tournament_id_by_player(event.player_id)
    if tournament_id then
        print("[tourney] Player disconnected during tournament: " .. event.player_id)
        TournamentState.handle_player_disqualification(tournament_id, event.player_id)
        
        -- Check if disconnected player was host and reassign if possible
        local tournament = TournamentState.get_tournament(tournament_id)
        if tournament and tournament.host_player_id == event.player_id then
            local new_host = get_new_host(tournament)
            if new_host then
                tournament.host_player_id = new_host
                print("[tourney] Host disconnected. New host: " .. new_host)
                Net.message_player(new_host, "You are now the tournament host!")
            else
                print("[tourney] No real players left, ending tournament due to host disconnect")
                TournamentState.cleanup_tournament(tournament_id)
            end
        end
    end
    
    -- Remove from waiting lists
    TourneyEmitters.players_waiting[event.player_id] = nil
    
    -- Remove any active countdown and clean up framework
    if active_countdowns[event.player_id] then
        active_countdowns[event.player_id] = nil
    end
end)

-- UI customization event handlers
TourneyEmitters.tournament_ui_emitter:on("ui_position_changed", function(event)
    print("[Tournament UI] Position changed for " .. event.element .. ": " .. 
          tostring(event.position.x) .. "," .. tostring(event.position.y) .. "," .. tostring(event.position.z))
end)

TourneyEmitters.tournament_ui_emitter:on("ui_animation_changed", function(event)
    print("[Tournament UI] Animation changed for " .. event.element .. ": " .. event.animation)
end)
