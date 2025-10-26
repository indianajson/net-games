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

local tourney_table = require("scripts/net-game-tourney/table-templates/tournament-table")

-- TESTING TEMPLATING FOR TABLES --
--local table_test = tourney_table
--table_test = tourney_table.modify_value(table_test, "area_id", "TEST")
--print(table_test)
--table_test = tourney_table.modify_values(table_test,
--    { area_id = "TEST", participants = { "Test", "Test", "Test", "Test", "Test", "Test", } })
--print(table_test)
-----------------------------------

games.start_framework()


local tourney_boards = {}
local players_waiting = {}

local default_mug_anim = constants.default_mug_anim
local frames_to_remove = ui_data.frame_names
local ui_data_pos = ui_data.unmoving_ui_pos
local board_pos = ui_data_pos.bg
local grid_pos = ui_data_pos.grid
local bracket_pos = ui_data_pos.bracket
local title_banner_pos = ui_data_pos.title_banner
local champion_topper_pos = ui_data_pos.champion_topper_bn4

local duration = 10

--purpose: Find the index of a value in a table
--usage: Called to locate specific values within tables like participant lists
local function find_in_table(t, v1)
    for i, v2 in pairs(t) do
        if v1 == v2 then
            return i
        end
    end
    return nil
end

-- returns a table in pairs for participants.
-- index 1, 2, 3, 4 ... match ups
--
-- player1_id first participant in pair,
-- player2_id second participant in pair.
local function setup_matches(tbl)
    local result = {}
    local n = #tbl

    -- Loop through odd-numbered indices
    for i = 1, n - 1, 2 do
        -- Create a table for each pair
        result[(i + 1) / 2] = {
            player1_id = tbl[i],
            player2_id = tbl[i + 1]
        }
    end

    return result
end

--purpose: Create a new tournament party for a player
--usage: Called when a player starts a new tournament session
local function start_party(player_id, player_area, object_id)
    local player_mugshot = ''
    local pid = ""
    local p_area = ""
    local obj_id = ""
    local party = {}

    obj_id = object_id
    p_area = player_area
    pid = player_id
    player_mugshot = Net.get_player_mugshot(pid)

    party = {
        player_id      = pid,
        player_mugshot = {
            mug_texture   = player_mugshot.texture_path,
            mug_animation = default_mug_anim
        },
        player_spot = 1
    }
    local index = math.max(#tourney_boards[p_area][obj_id]["active_tournaments"], 1)
    table.insert(tourney_boards[p_area][obj_id]["active_tournaments"], index, party)
end

--purpose: Add player to existing tournament or create new one
--usage: Called when player interacts with tournament board to join tournament
local function join_or_create_party(player_id, object_id)
    local player_area = ""

    player_area = Net.get_player_area(player_id)

    local found_a_tournament = false
    for i, party in next, tourney_boards[player_area][object_id].active_tournaments do
        if #tourney_boards[player_area][object_id].active_tournaments[i] < 8 then
          --  print("[tourney] Active tournament exists.")
            --existing tournament needs players, add player to this tournament
            local mug_texture = ""
            mug_texture = Net.get_player_mugshot(player_id).texture_path
            print(tourney_boards[player_area][object_id].active_tournaments[i])
            tourney_boards[player_area][object_id].active_tournaments[i] = { player_id = player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug_texture }, player_spot = i }
            --print("Added player with player_id : " .. player_id .. " to tournament party")
            found_a_tournament = true
            break
        end
    end
    if found_a_tournament == false then
       -- print("[tourney] No active tournament, creating a new one.")
        --no tournament was found so create a new tournament
        start_party(player_id, player_area, object_id)
    end
end

-- Should await whichever instance of a fight and return a winner, other than in the case of NPC VS NPC
-- TODO:
--      - Add NPC weights to determine who wins with a roll of the dice between 2 NPCS.
--      - Add parameters to modify battle specifics for other cases.
--          - Aka NPC vs Player1, NPC vs Player2, Player1 vs Player2.


--Shorthand for async
function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end

--Shorthand for await
function await(v) return Async.await(v) end

--purpose: Start a battle between two participants (player vs player, player vs NPC, or NPC vs NPC)
--usage: Called during tournament progression to handle individual matches
local function start_battle(player1_id, player2_id)
    return async(function()
        if string.find(player1_id, ".zip") and string.find(player2_id, ".zip") then
            print("THIS IS TWO NPCS fighting! DONT WORRY BOUT IT FOR RIGHT NOW")
            return
        end
        if string.find(player2_id, ".zip") then
          --  print("Player vs NPC")
            Net.lock_player_input(player1_id)
            TourneyEmitters.start_tourney_battle(player1_id, player2_id)
            Net.initiate_encounter(player1_id, player2_id)
            Net.unlock_player_input(player1_id)
        end
        if string.find(player1_id, ".zip") then
         --   print("NPC vs Player")
            Net.lock_player_input(player2_id)
            TourneyEmitters.start_tourney_battle(player1_id, player2_id)
            Net.initiate_encounter(player2_id, player1_id)
            Net.unlock_player_input(player2_id)
        end
        if not string.find(player1_id, ".zip") and not string.find(player2_id, ".zip") then
         --   print("Player vs Player")
            Net.lock_player_input(player1_id)
            Net.lock_player_input(player2_id)
            TourneyEmitters.start_tourney_battle(player1_id, player2_id)
            Net.initalize_pvp(player1_id, player2_id)
            Net.unlock_player_input(player1_id)
            Net.unlock_player_input(player2_id)
        end
    end)
end

--purpose: Extract and sanitize board properties from area objects
--usage: Called during board initialization to process tournament board configuration
local function get_board_properties(boards_in, area_id)
    if area_id == nil then
        return
    end

    local sanitized_board = {}
    for i, value in next, boards_in do
        sanitized_board = {
            area_id = i,
            boards = {},
        }
        for j, detail in next, value do
            for k, prop in next, detail do
                if k == "custom_properties" then
                    sanitized_board.boards[detail.id] = prop
                end
            end
        end
    end
    return sanitized_board
end

--purpose: Scan all areas and collect tournament board objects
--usage: Called at script startup to initialize all tournament boards on the server
local function gather_boards()
    local board = {}
    local board_with_props = {}
    local areas = {}
    local board_props = {}

    areas = Net.list_areas()

    for i, area_id in next, areas do
        local get_boards = TableUtils.GetAllTiledObjOfXType(area_id, "Tournament Board")
        if (#get_boards > 0) then
            board[area_id] = get_boards
        end
        --print(tourney_boards)
    end


    for j, board_obj in next, board do
        if #board_obj > 0 then
            local props_result = get_board_properties(board, j)
            if (props_result ~= nil) then
                --print(props_result)
                board_props = props_result.boards
                for k, id in next, board_props do
                    --print(k)
                    --print(id)
                    board_props[k]["active_tournaments"] = {}
                end
                board_with_props[j] = board_props
            end
        end

        for k, option in next, board_with_props do
            tourney_boards[k] = option
        end
    end

    for area, board in next, tourney_boards do
        for key, option in next, board do
           -- print("[tourney] Found " .. option["Tournament Board Title"] .. " in " .. area)
        end
    end
    --print(tourney_boards)
end

gather_boards()

--purpose: Add participant mugshot to tournament UI
--usage: Called during tournament display setup to position player/NPC portraits
local function add_participant_mugshot(player_id, participant_number, mug_texture_path, x, y)
    games.add_ui_element("MUG_FRAME_" .. participant_number, player_id, "/server/assets/tourney/mini-mug-frame.png",
        "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", x, y, 2)

    games.add_ui_element("MUG_" .. participant_number, player_id, mug_texture_path,
        "/server/assets/tourney/mug.anim",
        "UI", x, y, 1, .50, .50)
end

--purpose: Prepare tournament participants list with optional NPC backfilling
--usage: Called when starting tournament to ensure exactly 8 participants
local function initialize_tournament_participants(participants, backfill)
    local cleaned_up = {}
    local final_participants = {}
    local should_backfill = false
    --print("[INITIALIZE PARTICIPANTS]", participants)
    for i, p in next, participants do
        table.insert(cleaned_up, p)
    end
   -- print(cleaned_up)

    if backfill ~= nil then
        should_backfill = backfill
    end

    final_participants = cleaned_up
    if should_backfill then
        if (#final_participants < 8) then
            --print("needs to fill")
            local need_to_fill = 8 - #final_participants
            local random_npc_filler = TableUtils.SelectRandomItemsFromTableClamped(npc_paths, need_to_fill)
            for i, filler_npc in next, random_npc_filler do
                table.insert(final_participants, filler_npc)
            end
        end
    end
    return TableUtils.SelectRandomItemsFromTableClamped(final_participants, 8)
end

--purpose: Clean up tournament UI elements and restore original area settings
--usage: Called when tournament ends to reset player's display
local function cleanup_ui(player_id, player_area, original_map_name, original_map_song)
    for i, element in next, frames_to_remove do
        games.remove_ui_element(element, player_id)
    end
    Net.set_area_custom_property(player_area, "Name", original_map_name)
    Net.set_area_custom_property(player_area, "Song", original_map_song)
end

-- handles setting up the background UI elements (Gradients, Grids, Torueny Tree, Title Banner, Tournament Title etc, if they are provided from the selection we will try to default (not currently implemented just is one BG, Grid, And Bracket Config.))
--usage: Called at tournament start to create visual tournament bracket UI
local function setup_board_bg_elements(player_id, board_bg_element_info)
    games.add_ui_element("BOARD BG", player_id, board_bg_element_info.gradient_texture,
        constants.default_background_anim_path_bn4, "BG", board_pos.x, board_pos.y, board_pos.z)

    games.add_ui_element("BOARD GRID", player_id, board_bg_element_info.grid_texture,
        constants.default_grid_anim_path_bn4, "UI", grid_pos.x, grid_pos.y, grid_pos.z)

    games.add_ui_element("BRACKET", player_id, constants.bracket_bm_bn4, constants.default_bracket_anim_path_bn4,
        "UI", bracket_pos.x, bracket_pos.y, bracket_pos.z)

    games.add_ui_element("CHAMPION TOPPER", player_id, constants.champion_topper_bn4, constants.champion_topper_bn4_anim,
        "UI", champion_topper_pos.x, champion_topper_pos.y, champion_topper_pos.z)

    games.add_ui_element("TITLE BANNER", player_id, "/server/assets/tourney/title-banner.png",
        "/server/assets/tourney/title-banner.anim", "RED", title_banner_pos.x, title_banner_pos.y, title_banner_pos.z)

    games.add_ui_element("CROWN_1", player_id, "/server/assets/tourney/crown.png",
        "/server/assets/tourney/crown.anim", "IDLE", 64, 48, 0)

    games.add_ui_element("CROWN_2", player_id, "/server/assets/tourney/crown.png",
        "/server/assets/tourney/crown.anim", "IDLE", 176, 48, 0)
end

--usage: Called when tournament completes to reset state
local function cleanup_tourney()

end

--purpose: Main tournament display and flow controller
--usage: Called to start the full tournament sequence for a player
--REQUIRED: pid: string,
local function start_and_show_tourney(pid, board_bg_element_info, tourney, board_id, start_round_1)
    return async(function()
        -- Setup
        --print(tourney)
        local should_start_round_1 = false
        if start_round_1 ~= nil then
            should_start_round_1 = start_round_1
        end
        local player_id = pid
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_custom_property(player_area, "Name")
        Net.set_area_custom_property(player_area, "Name", "            ")
        local original_map_song = Net.get_area_custom_property(player_area, "Song")
        Net.set_area_custom_property(player_area, "Song", "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")
        -- Net.toggle_player_hud(player_id)
        games.activate_framework(player_id)
        --games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))

        setup_board_bg_elements(player_id, board_bg_element_info)
        for i, p in next, tourney do
            add_participant_mugshot(pid, i, p["player_mugshot"]["mug_texture"], mug_pos.bottom_tier[i].x,
                mug_pos.bottom_tier[i].y)
        end
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(12.5))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))
        cleanup_ui(player_id, player_area, original_map_name, original_map_song)
        -- Net.toggle_player_hud(player_id)
        local final = {}
        for i, p in next, tourney do
            final[i] = tourney[i]
            final[i]["player_spot"] = i 
            --print("[OH SHIT FINAL I]",final[i]["player_spot"])
        end
        local copy = setup_matches(final) 
        --print("[COPY IS]: ", copy)
        local init_matches = {}
                for i, match in next, copy do
                    init_matches[i] = copy[i]
                    --print("[INIT MATCH]",match)
                    --start_battle(match["player1_id"]["player_id"], match["player2_id"]["player_id"])
                    --TourneyEmitters.start_tourney_battle(match["player1_id"], match["player2_id"])
                    --print()
                end
        TourneyEmitters.start_tourney_state_initial(tourney, pid, player_area, board_id, init_matches, should_start_round_1)
        if should_start_round_1 == true then
            for i, j in next, init_matches do
             --   print("[ABSOLUTELY LOOK HERE THIS IS THE TRUE NEWEST]: ",i, j)
             print("[TOURNEY CHECK]", tostring(tourney))
                --print(init_matches[i]["player1_id"],init_matches[i]["player2_id"])
            start_battle(init_matches[i]["player1_id"]["player_id"],init_matches[i]["player2_id"]["player_id"])
            end
        end
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))
        --games.unfreeze_player(player_id)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
        return tourney
    end)
end

--purpose: Determine which background and grid assets to use based on board configuration
--usage: Called when setting up tournament display to get visual theme from board properties
local function get_board_background_and_grid(object)
    if TiledUtils.check_custom_prop_validity(object.custom_properties, "Board Background") then
        if object.custom_properties["Board Background"] == "blue_bn4" then
            return constants.bracket_background_path.blue_bn4
        end
        if object.custom_properties["Board Background"] == "green_bn4" then
            return constants.bracket_background_path.green_bn4
        end
        if object.custom_properties["Board Background"] == "pink_yellow_bn4" then
            return constants.bracket_background_path.pink_yellow_bn4
        end
        if object.custom_properties["Board Background"] == "lemon_lime_bn4" then
            return constants.bracket_background_path.lemon_lime_bn4
        end
        if object.custom_properties["Board Background"] == "green_blue_white_bn4" then
            return constants.bracket_background_path.green_blue_white_bn4
        end
        if object.custom_properties["Board Background"] == "red_orange_bn4" then
            return constants.bracket_background_path.red_orange_bn4
        end
        print("Please only enter pre-defined BGs and grids for now! Will default to red_orange_bn4's setup")
        return constants.bracket_background_path.red_orange_bn4
    end
end

Net:on("countdown_ended", function(event)
    return async(function()
        if players_waiting[event.player_id] == nil then
            --stops logic from running unless player is setting up a tournament
            return
        end
        local player_area = Net.get_player_area(event.player_id)
        local entry = players_waiting[event.player_id]
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
            local tournament_participants = initialize_tournament_participants(
                tourney_boards[player_area][entry["tourney_board"]].active_tournaments, true)
            local tournament_setup = nil
            local board_id = entry["tourney_board"]
            
            for i, player in next, tourney_boards[player_area][entry["tourney_board"]].active_tournaments do
                start_and_show_tourney(player["player_id"], board_background_setup_info,
                    tournament_participants, board_id, true)
            end
            await(Async.sleep(13.85))
            --games.activate_framework(event.player_id)
        --    print("moving on")
            Net.lock_player_input(event.player_id)
            
        end

        if result == 1 then
          --  print("[tourney] Player requested to wait for more players.")
            games.spawn_countdown(event.player_id, 100, 20, 10, duration)
            games.start_countdown(event.player_id)

            players_waiting[event.player_id] = {
                waiting = true,
                tourney_board = entry["tourney_board"]
            }
        end
    end)
end)

Net:on("object_interaction", function(event)
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type ~= "Tournament Board" and object.class ~= "Tournament Board" then
        --print("No match found, No work to do.")
        return
    end
    local board_background_setup_info = get_board_background_and_grid(object)

  --  print("[tourney] Player opened a tournament board.")
    async(function()
        --check if a board tournament is available on this board
        local board_tournament = tourney_boards[player_area][event.object_id].active_tournaments
        if #board_tournament < 8 and #board_tournament >= 1 then
            local manager = Net.get_player_name(board_tournament[1]["player_id"])
            local result = await(Async.question_player(event.player_id,
                "Would you like to join " .. manager .. "'s tournament?"))
            if result == 0 then
                --no, ask about single player mode
                local single_player_result = await(Async.question_player(event.player_id, "Single Player?"))
                if single_player_result == 1 then
                   -- print("[tourney] Player requested single player tournament.")
                    join_or_create_party(event.player_id, event.object_id)
                    local mug_texture = ""
                    mug_texture = Net.get_player_mugshot(event.player_id).texture_path

                    await(start_and_show_tourney(event.player_id, board_background_setup_info,
                        initialize_tournament_participants(
                            { { player_id = event.player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug_texture } } },
                            true),event.object_id, false))
                    
                    end
            elseif result == 1 then
                --yes, join open tournament
              --  print("[tourney] Active tournament exists.")
                local mug_texture = ""
                local mug_texture = Net.get_player_mugshot(event.player_id).texture_path
                local position = #board_tournament + 1
            tourney_boards[player_area][event.object_id].active_tournaments[position] = {
               player_spot = #tourney_boards[player_area][event.object_id].active_tournaments + 1,
               player_id = event.player_id,
               player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug_texture }
            }
            -- print("[tourney] Added player with player_id : " .. event.player_id .. " to " ..
              --      manager .. "'s tournament.")
                end
            else
            --if no open tournament then allow player to start one!
            local result = await(Async.question_player(event.player_id, "Would you like to start a tournament?"))

            if result == 0 then
                --print("PLAYER SAID NO! DO YOU EVEN READ THESE PRINTS DEAR PROGRAMMER?")
            elseif result == 1 then
                --print("[tourney] Player requested a tournament to be started.")
                local single_player_result = await(Async.question_player(event.player_id, "Single Player?"))

                if single_player_result == 0 then
                   -- print("[tourney] Player requested a multi-player tournament.")

                    join_or_create_party(event.player_id, event.object_id)
                    games.start_framework()
                    games.activate_framework(event.player_id)
                    Net.lock_player_input(event.player_id)

                    games.spawn_countdown(event.player_id, 100, 20, 10, duration)
                    games.start_countdown(event.player_id)

                    players_waiting[event.player_id] = {
                        waiting = true,
                        tourney_board = event.object_id
                    }
                elseif single_player_result == 1 then
                    --print("[tourney] Player requested single player tournament.")
                    join_or_create_party(event.player_id, event.object_id)
                    local mug_texture = ""
                    mug_texture = Net.get_player_mugshot(event.player_id).texture_path

                    await(start_and_show_tourney(event.player_id, board_background_setup_info,
                        initialize_tournament_participants(
                            { { player_id = event.player_id, player_mugshot = { mug_animation = default_mug_anim, mug_texture = mug_texture } } },
                            true), event.object_id, true))
                 
                        --await(start_battle(match["player1_id"]["player_id"], match["player2_id"]["player_id"]))
                end
            end
        end
    end)
end)

Net:on("battle_results", function(event)
    local enemy_info = {}
    print(event.e)
    if #event["enemies"] > 0 then
       for i, j in next, event.enemies do
        print(i)
        print(j)
       end 
    end
    local players_in_tourney_round_if_it_exists = TourneyEmitters.check_if_they_exist(event.player_id, event.enemies.id, event.ran, event.health, event.enemies.health)
    local winner_info = {}
    local loser_info = {}

    if players_in_tourney_round_if_it_exists ~= nil then
        local tourney_id = players_in_tourney_round_if_it_exists.tournament_id
        local match_id = players_in_tourney_round_if_it_exists.match_id
        local status = players_in_tourney_round_if_it_exists.status
        local participants = players_in_tourney_round_if_it_exists.participant_pairs
        if event.ran ~= true then
            print(event.ran)
            if event["enemies"]["id"] == nil then
                print(event.player_id)
                print("A PLAYER WIN VS NPC OPPONENET SINCE THEY DID NOT RUN AND THE PLAYER2_ID IS NIL, Below is their PAIR")
                print(participants)
                TourneyEmitters.set_round_results(players_in_tourney_round_if_it_exists.tournament_id, TourneyEmitters.tournaments[players_in_tourney_round_if_it_exists.tournament_id][players_in_tourney_round_if_it_exists.status.."_matches"].matchups)
            end
                --if participants["player1_id"]["player_id"], player1_id) or string.find(participants["player2_id"]["player_id"], player1_id) then
                --    local second_check = TourneyEmitters.tournaments[tonumber(players_in_tourney_round_if_it_exists.tournament_id)][players_in_tourney_round_if_it_exists.status.."_matches"]["matchups"][match_id]
                --    print("CHECK CHECK")
                --    print(tostring(second_check)) 
                --end
                --winner_info = participants["player1_id"]
                --loser_info = participants["player2_id"]
            --TourneyEmitters.set_round_results(players_in_tourney_round_if_it_exists.tournament_id, players_in_tourney_round_if_it_exists.status, players_in_tourney_round_if_it_exists.match_id, winner_info , loser_info )
            --if string.find(participants["player1_id"]["player_id"], player1_id) then
            --    print("Found it")
            --end
        --print("Got back needed data")
        --TourneyEmitters.set_round_results(players_in_tourney_round_if_it_exists.tournament_id, players_in_tourney_round_if_it_exists.status, players_in_tourney_round_if_it_exists.match_id)
            end
        end
    --for tourney_index, tournament in next, TourneyEmitters.tournaments do
    --    for p_index, participants in next, TourneyEmitters.tournaments[tourney_index] do
    --        print("[PINDEX IS]",p_index)
    --        print("[THESE ARE THE PARTICIPANTS]", participants)
    --    end
    --end
    --local check = TableUtils.deepSearch(TourneyEmitters.tournaments, "tournament_id", )
    --    print(check)
    --     TourneyEmitters.set_round_results(1, TourneyEmitters.tournaments[1].round_1_matches, {winners = {player2_id}, losers = {match["player2_id"]}})
    --end
    
    --local player2_id = event.enemies.id
    --for i, tournament in next, TourneyEmitters.tournaments do
    --    for j, p in tournament.participants do
    --        if player2_id == nil then
    --        --print("A Player WON vs NPC Opponnet since they did not run, and the player2_id is nil")
    --        if p.round_1_matches[j]["player1_id"] == player1_id or p.round_1_matches[j]["player2_id"] == player1_id then  
    --            --print("i is: ", i, "match is: ", p.round_1_matches[j])
    --            TourneyEmitters.set_round_results(1, p.round_1_matches[i], {winners = {player1_id}, losers = {p.round_1_matches[j]["player2_id"]}})
    --            break
    --        end
    --    end
    --    if p.round_1_matches[j]["player1_id"] == player2_id or p.round_1_matches[j]["player2_id"] == player2_id then
    --   -- print("Player 2 exists so either a player or an NPC won this fight.")
    --        if string.find(p.round_1_matches[j]["player1_id"], tostring(player2_id)) then
    --           -- print("Player 2 is actually player1_id in our matchup")
    --          --  print("i is: ", i, "match is: ", p.round_1_matches[j])
    --            break
    --        end
    --        if string.find(p.round_1_matches[j]["player2_id"], tostring(player2_id)) then
    --         --   print("Player 2 is player2_id in our matchup")
--pr--int("i is: ", i, "match is: ", p.round_1_matches[j])
    --            break
    --            end
    --        end
    --    end
    --end
    --    local player2_health = event.enemies
       -- print("[PRINTING RESULTS OF FIGHT] :",player1_id, player2_id)
    end)
