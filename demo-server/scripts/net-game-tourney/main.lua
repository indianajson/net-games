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
local duration = 10

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

-- Enhanced battle starter with proper framework management
local function start_battle(player1_id, player2_id, tournament_id, match_index)
    return async(function()
        local is_player1_npc = string.find(player1_id, ".zip")
        local is_player2_npc = string.find(player2_id, ".zip")
        
        TourneyEmitters.start_tourney_battle(player1_id, player2_id, tournament_id, match_index)
        
        -- Ensure players are unfrozen and framework is deactivated before battle
        local players_to_cleanup = {}
        if not is_player1_npc then 
            games.deactivate_framework(player1_id)
            games.unfreeze_player(player1_id)
            table.insert(players_to_cleanup, player1_id)
        end
        if not is_player2_npc then 
            games.deactivate_framework(player2_id)
            games.unfreeze_player(player2_id)
            table.insert(players_to_cleanup, player2_id)
        end
        
        await(Async.sleep(0.5)) -- Brief pause to ensure cleanup
        
        if is_player1_npc and is_player2_npc then
            -- NPC vs NPC - simulate battle (no notifications to players)
            print("[tourney] Starting NPC vs NPC battle")
            await(TourneyEmitters.simulate_npc_battle(player1_id, player2_id, tournament_id, match_index))
        elseif is_player1_npc then
            -- Player vs NPC - notify the player
            Net.message_player(player2_id, "Starting battle against NPC opponent!")
            Net.lock_player_input(player2_id)
            local result = await(Async.initiate_encounter(player2_id, player1_id))
            Net.unlock_player_input(player2_id)
            return result
        elseif is_player2_npc then
            -- Player vs NPC - notify the player
            Net.message_player(player1_id, "Starting battle against NPC opponent!")
            Net.lock_player_input(player1_id)
            local result = await(Async.initiate_encounter(player1_id, player2_id))
            Net.unlock_player_input(player1_id)
            return result
        else
            -- PvP - notify both players
            Net.message_player(player1_id, "Starting PvP battle!")
            Net.message_player(player2_id, "Starting PvP battle!")
            Net.lock_player_input(player1_id)
            Net.lock_player_input(player2_id)
            local result = await(Async.initiate_pvp(player1_id, player2_id))
            Net.unlock_player_input(player1_id)
            Net.unlock_player_input(player2_id)
            return result
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

local function run_tournament_battles(tournament_id)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return end
        
        print("[tourney] Starting tournament battles for round " .. tournament.current_round)
        
        -- Show round message (not UI) for all players
        for _, participant in ipairs(tournament.participants) do
            if not string.find(participant.player_id, ".zip") then
                TournamentUtils.show_round_ui(participant.player_id, tournament.current_round)
            end
        end
        
        -- Don't freeze all players at start - let them move around
        TournamentUtils.notify_waiting_for_matches(tournament_id, TournamentState)
        
        -- First, start all player battles first (PvP and PvE)
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
                await(Async.sleep(0.2)) -- Brief pause to ensure text boxes close
                
                -- Start the battle (players will be unfrozen in start_battle)
                print("[tourney] Starting player battle: " .. player1_id .. " vs " .. player2_id)
                await(start_battle(player1_id, player2_id, tournament_id, i))
                
                -- Players remain unfrozen after battle to move around
                
                -- Brief pause between matches
                if i < #tournament.matches then
                    await(Async.sleep(1))
                end
            end
        end
        
        -- Then, simulate all NPC vs NPC battles sequentially (no notifications)
        for i, match in ipairs(tournament.matches) do
            local player1_id = match.player1.player_id
            local player2_id = match.player2.player_id
            local is_npc_battle = string.find(player1_id, ".zip") and string.find(player2_id, ".zip")
            
            if is_npc_battle then
                -- No announcements for NPC vs NPC battles
                -- Start the NPC battle simulation
                print("[tourney] Starting NPC battle simulation: " .. player1_id .. " vs " .. player2_id)
                await(start_battle(player1_id, player2_id, tournament_id, i))
                
                -- Brief pause between NPC matches
                if i < #tournament.matches then
                    await(Async.sleep(1))
                end
            end
        end
        
        print("[tourney] Finished all battles for round " .. tournament.current_round)
        
        -- Wait a moment to ensure all battle results are processed
        await(Async.sleep(2))
        
        -- Check if all matches are completed, if not, manually complete NPC battles
        local all_matches_completed = true
        for i, match in ipairs(tournament.matches) do
            if not match.completed then
                all_matches_completed = false
                -- If this is an NPC vs NPC battle that didn't complete, manually complete it
                if string.find(match.player1.player_id, ".zip") and string.find(match.player2.player_id, ".zip") then
                    print("[tourney] Manually completing NPC vs NPC match: " .. match.player1.player_id .. " vs " .. match.player2.player_id)
                    -- Randomly pick a winner for NPC vs NPC
                    local winner = math.random(1, 2) == 1 and match.player1 or match.player2
                    local loser = winner == match.player1 and match.player2 or match.player1
                    
                    TournamentState.record_battle_result(tournament_id, i, winner, loser)
                    print("[tourney] NPC match completed: " .. winner.player_id .. " defeated " .. loser.player_id)
                end
            end
        end
        
        -- Check if tournament still has real players
        if not has_real_players(tournament) then
            print("[tourney] No real players left, ending tournament")
            
            -- Clean up all players
            for _, participant in ipairs(tournament.participants) do
                if not string.find(participant.player_id, ".zip") then
                    games.deactivate_framework(participant.player_id)
                    games.unfreeze_player(participant.player_id)
                end
            end
            
            TournamentState.cleanup_tournament(tournament_id)
            return
        end
        
        -- Check if current host is still in tournament and is a real player
        local current_host = tournament.host_player_id
        local host_still_in_tournament = false
        
        -- Check if host is still in the current participants (winners of this round)
        for _, participant in ipairs(tournament.participants) do
            if participant.player_id == current_host then
                host_still_in_tournament = true
                break
            end
        end
        
        -- If host is eliminated or disconnected, assign new host from remaining real players
        if not host_still_in_tournament or not Net.is_player(current_host) or string.find(current_host, ".zip") then
            local new_host = get_new_host(tournament)
            if new_host then
                tournament.host_player_id = new_host
                print("[tourney] Host eliminated or disconnected. New host: " .. new_host)
                Net.message_player(new_host, "You are now the tournament host!")
                current_host = new_host
            else
                print("[tourney] No real players left to be host, ending tournament")
                TournamentState.cleanup_tournament(tournament_id)
                return
            end
        end
        
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
                            end
                        end
                    end
                    
                    -- Clean up all players
                    for _, participant in ipairs(tournament.participants) do
                        if not string.find(participant.player_id, ".zip") then
                            games.deactivate_framework(participant.player_id)
                            games.unfreeze_player(participant.player_id)
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
                    games.unfreeze_player(participant.player_id)
                end
            end
            
            TournamentState.cleanup_tournament(tournament_id)
        end
    end)
end

---------------------------------------------------------------------
-- UI and Board Management Functions
---------------------------------------------------------------------

local function add_participant_mugshot(player_id, participant_number, mug_texture_path, x, y)
    games.add_ui_element("MUG_FRAME_" .. participant_number, player_id,
        "/server/assets/tourney/mini-mug-frame.png", "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", x, y, 2)
    games.add_ui_element("MUG_" .. participant_number, player_id, mug_texture_path,
        "/server/assets/tourney/mug.anim", "UI", x, y, 1, .50, .50)
end

local function initialize_tournament_participants(participants, backfill)
    local final = {}
    for _, p in next, participants do table.insert(final, p) end
    if backfill and #final < 8 then
        local fill = TableUtils.SelectRandomItemsFromTableClamped(npc_paths, 8 - #final)
        for _, f in next, fill do table.insert(final, f) end
    end
    return TableUtils.SelectRandomItemsFromTableClamped(final, 8)
end

local function cleanup_ui(player_id, player_area, name, song)
    for _, element in next, frames_to_remove do games.remove_ui_element(element, player_id) end
    Net.set_area_name(player_area, name)
    Net.set_song(player_area, song)
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
    games.add_ui_element("CROWN_1", player_id, "/server/assets/tourney/crown.png",
        "/server/assets/tourney/crown.anim", "IDLE", 64, 48, 0)
    games.add_ui_element("CROWN_2", player_id, "/server/assets/tourney/crown.png",
        "/server/assets/tourney/crown.anim", "IDLE", 176, 48, 0)
end

local function start_and_show_tourney(pid, board_bg_element_info, tourney)
    return async(function()
        local player_id = pid
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_name(player_area)
        Net.set_area_name(player_area, "            ")
        local original_map_song = Net.get_song(player_area)
        Net.set_song(player_area,
            "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")

        games.activate_framework(player_id)
        games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, .5)
        await(Async.sleep(.75))
        setup_board_bg_elements(player_id, board_bg_element_info)
        for i, p in next, tourney do
            add_participant_mugshot(pid, i, p.player_mugshot.mug_texture,
                mug_pos.bottom_tier[i].x, mug_pos.bottom_tier[i].y)
        end
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, .5)
        await(Async.sleep(12.5))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, .5)
        await(Async.sleep(0.5))
        cleanup_ui(player_id, player_area, original_map_name, original_map_song)
        await(Async.sleep(0.1))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, .5)
        games.unfreeze_player(player_id)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
        return tourney
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

---------------------------------------------------------------------
-- Event Handlers
---------------------------------------------------------------------

Net:on("object_interaction", function(event)
    local player_id = event.player_id
    local player_area = Net.get_player_area(player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type ~= "Tournament Board" and object.class ~= "Tournament Board" then return end

    -- Check if player is already in a tournament
    if TournamentState.is_player_in_tournament(player_id) then
        Net.message_player(player_id, "You are already in a tournament!")
        return
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
                local result = await(Async.question_player(event.player_id,
                    "Would you like to join " .. manager .. "'s tournament?"))
                if result == 0 then
                    local single = await(Async.question_player(event.player_id, "Single Player?"))
                    if single == 1 then
                        local mug = Net.get_player_mugshot(player_id).texture_path
                        local tsetup = await(start_and_show_tourney(event.player_id, board_background_setup_info,
                            initialize_tournament_participants(
                                { { player_id = event.player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug } } }, true)))
                        if tsetup then
                            -- Create tournament and start battles
                            local tournament_id = TournamentState.create_tournament(event.object_id, player_area, event.player_id)
                            for _, participant in ipairs(tsetup) do
                                TournamentState.add_participant(tournament_id, participant)
                            end
                            
                            if TournamentState.start_tournament(tournament_id) then
                                -- Run battles with proper sequencing
                                await(run_tournament_battles(tournament_id))
                            end
                        end
                    end
                elseif result == 1 then
                    local mug = Net.get_player_mugshot(event.player_id).texture_path
                    local pos = #board_tournament + 1
                    tourney_boards[player_area][event.object_id].active_tournaments[pos] =
                        { player_id = event.player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug } }
                end
            else
                local result = await(Async.question_player(event.player_id, "Would you like to start a tournament?"))
                if result == 1 then
                    local single = await(Async.question_player(event.player_id, "Single Player?"))
                    if single == 0 then
                        join_or_create_party(event.player_id, event.object_id, false)
                        
                        -- Clean up framework before starting countdown to prevent conflicts
                        games.deactivate_framework(event.player_id)
                        games.unfreeze_player(event.player_id)
                        await(Async.sleep(0.1))
                        
                        games.activate_framework(event.player_id)
                        Net.lock_player_input(event.player_id)
                        
                        -- Track this countdown
                        active_countdowns[event.player_id] = true
                        games.spawn_countdown(event.player_id, 100, 20, 10, duration)
                        games.start_countdown(event.player_id)
                        
                        TourneyEmitters.players_waiting[event.player_id] = { waiting = true, tourney_board = event.object_id }
                    elseif single == 1 then
                        join_or_create_party(event.player_id, event.object_id, true)
                        local mug = Net.get_player_mugshot(event.player_id).texture_path
                        local tsetup = await(start_and_show_tourney(event.player_id, board_background_setup_info,
                            initialize_tournament_participants(
                                { { player_id = event.player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug } } }, true)))
                        if tsetup then
                            -- Create tournament and start battles
                            local tournament_id = TournamentState.create_tournament(event.object_id, player_area, event.player_id)
                            for _, participant in ipairs(tsetup) do
                                TournamentState.add_participant(tournament_id, participant)
                            end
                            
                            if TournamentState.start_tournament(tournament_id) then
                                -- Run battles with proper sequencing
                                await(run_tournament_battles(tournament_id))
                            end
                        end
                    end
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
            -- Remove countdown if it exists
            if active_countdowns[event.player_id] then
                games.remove_countdown(event.player_id)
                games.deactivate_framework(event.player_id)
                games.unfreeze_player(event.player_id)
                active_countdowns[event.player_id] = nil
            end
            return
        end 
        
        local player_area = Net.get_player_area(event.player_id)
        local entry = TourneyEmitters.players_waiting[event.player_id]
        
        -- Always remove the countdown and clean up framework when it ends
        games.remove_countdown(event.player_id)
        games.deactivate_framework(event.player_id)
        games.unfreeze_player(event.player_id)
        active_countdowns[event.player_id] = nil
        
        local board_info = tourney_boards[player_area][entry.tourney_board]
        
        Net.message_player(event.player_id,
            "There is currently " .. #board_info.active_tournaments .. "/8 in your tournament queue. What would you like to do?")
        
        local result = await(Async.quiz_player(event.player_id, "Backfill", "Wait"))
        
        if result == 0 then -- Backfill
            local object = Net.get_object_by_id(player_area, entry.tourney_board)
            local board_background_setup_info = TournamentUtils.get_board_background_and_grid(object, TiledUtils, constants)
            
            local tournament_participants = initialize_tournament_participants(
                tourney_boards[player_area][entry.tourney_board].active_tournaments, true)
            
            -- Create tournament and start first round
            local tournament_id = TournamentState.create_tournament(entry.tourney_board, player_area, event.player_id)
            
            for _, participant in ipairs(tournament_participants) do
                TournamentState.add_participant(tournament_id, participant)
            end
            
            if TournamentState.start_tournament(tournament_id) then
                local tournament = TournamentState.get_tournament(tournament_id)
                
                -- Show tournament UI to all human players
                for _, player_data in ipairs(tourney_boards[player_area][entry.tourney_board].active_tournaments) do
                    if not string.find(player_data.player_id, ".zip") then
                        await(start_and_show_tourney(player_data.player_id, board_background_setup_info, tournament_participants))
                    end
                end
                
                await(Async.sleep(13.85))
                
                -- Run battles with proper sequencing
                await(run_tournament_battles(tournament_id))
            end
            
        elseif result == 1 then -- Wait
            print("[tourney] Player requested to wait for more players.")
            
            -- Clean up framework before restarting countdown
            games.deactivate_framework(event.player_id)
            games.unfreeze_player(event.player_id)
            await(Async.sleep(0.1))
            
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
        end
        
        TourneyEmitters.players_waiting[event.player_id] = nil
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
        games.remove_countdown(event.player_id)
        games.deactivate_framework(event.player_id)
        games.unfreeze_player(event.player_id)
        active_countdowns[event.player_id] = nil
    end
    
    -- Remove round UI
    TournamentUtils.remove_round_ui(event.player_id)
end)

-- UI customization event handlers
TourneyEmitters.tournament_ui_emitter:on("ui_position_changed", function(event)
    print("[Tournament UI] Position changed for " .. event.element .. ": " .. 
          tostring(event.position.x) .. "," .. tostring(event.position.y) .. "," .. tostring(event.position.z))
end)

TourneyEmitters.tournament_ui_emitter:on("ui_animation_changed", function(event)
    print("[Tournament UI] Animation changed for " .. event.element .. ": " .. event.animation)
end)

print("[tourney] Tournament system initialized and ready")