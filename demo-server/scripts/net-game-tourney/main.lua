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

games.start_framework()

local tourney_boards = {}
local player_interaction_locks = {} -- prevent duplicate prompts

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
-- helpers
---------------------------------------------------------------------
local function find_in_table(t, v1)
    for i, v2 in pairs(t) do if v1 == v2 then return i end end
end

local function setup_matches(tbl)
    local result = {}
    for i = 1, #tbl - 1, 2 do
        result[(i + 1) / 2] = { player1_id = tbl[i], player2_id = tbl[i + 1] }
    end
    return result
end

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

function async(p) local co = coroutine.create(p) return Async.promisify(co) end
function await(v) return Async.await(v) end

local function start_battle(player1_id, player2_id)
    return async(function()
        if string.find(player1_id, ".zip") and string.find(player2_id, ".zip") then return end
        if string.find(player2_id, ".zip") then
            Net.lock_player_input(player1_id)
            TourneyEmitters.start_tourney_battle(player1_id, player2_id)
            Net.initiate_encounter(player1_id, player2_id)
            Net.unlock_player_input(player1_id)
        elseif string.find(player1_id, ".zip") then
            Net.lock_player_input(player2_id)
            TourneyEmitters.start_tourney_battle(player1_id, player2_id)
            Net.initiate_encounter(player2_id, player1_id)
            Net.unlock_player_input(player2_id)
        else
            Net.lock_player_input(player1_id)
            Net.lock_player_input(player2_id)
            TourneyEmitters.start_tourney_battle(player1_id, player2_id)
            Net.initalize_pvp(player1_id, player2_id)
            Net.unlock_player_input(player1_id)
            Net.unlock_player_input(player2_id)
        end
    end)
end

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
    Net.set_area_custom_property(player_area, "Name", name)
    Net.set_area_custom_property(player_area, "Song", song)
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
        local original_map_name = Net.get_area_custom_property(player_area, "Name")
        Net.set_area_custom_property(player_area, "Name", "            ")
        local original_map_song = Net.get_area_custom_property(player_area, "Song")
        Net.set_area_custom_property(player_area, "Song",
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

local function get_board_background_and_grid(object)
    if not TiledUtils.check_custom_prop_validity(object.custom_properties, "Board Background") then return end
    local bg = object.custom_properties["Board Background"]
    local p = constants.bracket_background_path
    return p[bg] or p.red_orange_bn4
end

---------------------------------------------------------------------
-- interaction lock + logic
---------------------------------------------------------------------
Net:on("object_interaction", function(event)
    local player_id = event.player_id
    local player_area = Net.get_player_area(player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type ~= "Tournament Board" and object.class ~= "Tournament Board" then return end

    if player_interaction_locks[player_id] then
        print("[tourney] Ignoring duplicate interaction for " .. player_id)
        return
    end
    player_interaction_locks[player_id] = true

    local board_background_setup_info = get_board_background_and_grid(object)
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
                            local m = setup_matches(tsetup)
                            for _, match in next, m do
                                await(start_battle(match.player1_id.player_id, match.player2_id.player_id))
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
                        games.start_framework()
                        games.activate_framework(event.player_id)
                        Net.lock_player_input(event.player_id)
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
                            local m = setup_matches(tsetup)
                            for _, match in next, m do
                                await(start_battle(match.player1_id.player_id, match.player2_id.player_id))
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
            --stops logic from running unless player is setting up a tournament
            return
        end 
        local matchups = {}
        local player_area = Net.get_player_area(event.player_id)
        local entry = TourneyEmitters.players_waiting[event.player_id]
        print(player_area)
        print(entry["tourney_board"])
        local object = Net.get_object_by_id(player_area, entry["tourney_board"])
        games.remove_countdown(event.player_id)
        local board_info = tourney_boards[player_area][entry["tourney_board"]]
        print(board_info)
        Net.message_player(event.player_id,
            "There is currently " ..
            #board_info.active_tournaments .. "/8 in your tournament queue. What would you like to do?")
        local result = await(Async.quiz_player(event.player_id, "Backfill", "Wait"))
        if result == 0 then
            local board_background_setup_info = get_board_background_and_grid(object)
            print("[tourney] Player requested a backfill")
            print(board_background_setup_info)
            local tournament_participants = initialize_tournament_participants(tourney_boards[player_area][entry["tourney_board"]].active_tournaments, true)
            local tournament_setup = nil
            for i,player in next,tourney_boards[player_area][entry["tourney_board"]].active_tournaments do
                tournament_setup = start_and_show_tourney(player["player_id"], board_background_setup_info,tournament_participants)
            end 
            await(Async.sleep(13.85))
            games.activate_framework(event.player_id)
            print("moving on")
            Net.lock_player_input(event.player_id)
            print(tournament_setup)
            if tournament_setup ~= nil then
                matchups = setup_matches(tournament_participants)
                for i, matches in next, matchups do
                    local match = matchups[i]
                    print("matches:")
                    print(match)
                    start_battle(match["player1_id"]["player_id"], match["player2_id"]["player_id"])
                    TourneyEmitters.start_tourney_battle(match["player1_id"], match["player2_id"])
                    print(result)
                end
            end
        end

        if result == 1 then
            print("[tourney] Player requested to wait for more players.")
            games.spawn_countdown(event.player_id, 100, 20, 10, duration)
            games.start_countdown(event.player_id)

            TourneyEmitters.players_waiting[event.player_id] = {
                waiting = true,
                tourney_board = entry["tourney_board"]
            }
        end
    end)
end)

Net:on("battle_results", function(event)
    print(event.player_id, event.health, event.time, event.ran, event.emotion, event.turns, event.enemies)
end)
