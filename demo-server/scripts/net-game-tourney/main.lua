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

games.start_framework()

local tourney_boards = {}
local online_players = {}

local default_mug_anim = constants.default_mug_anim
local frames_to_remove = ui_data.frame_names
local ui_data_pos = ui_data.unmoving_ui_pos
local board_pos = ui_data_pos.bg
local grid_pos = ui_data_pos.grid
local bracket_pos = ui_data_pos.bracket
local title_banner_pos = ui_data_pos.title_banner


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
        result[(i + 1)/2] = {
            player1_id = tbl[i],
            player2_id = tbl[i + 1]
        }
    end
    
    return result
end

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
            player_id = pid, 
            player_mugshot = { 
                mug_texture = player_mugshot.texture_path, 
                mug_animation = default_mug_anim
            } 
    }
    local index = math.max(#tourney_boards[p_area][obj_id]["active_tournaments"], 1)
    table.insert(tourney_boards[p_area][obj_id]["active_tournaments"], index, party)
end

local function join_or_create_party(player_id, object_id)
    local player_area = ""
    player_area = Net.get_player_area(player_id)
    --tourney_boards[]
    if (#tourney_boards[player_area][object_id].active_tournaments < 1) then
        print("No active parties.")
        start_party(player_id, player_area, object_id)
    end

    print("Active tournament exists")
    
    for i, party in next, tourney_boards[player_area][object_id].active_tournaments do
        if #tourney_boards[player_area][object_id].active_tournaments[i] < 8 and not TableUtils.Contains(party, player_id) then
            local mug_texture = ""
            mug_texture = Net.get_player_mugshot(player_id).texture_path
            print(tourney_boards[player_area][object_id].active_tournaments[i])
            tourney_boards[player_area][object_id].active_tournaments[i] = {player_id = player_id, player_mugshot = {mug_animation = default_mug_anim, mug_texture=mug_texture} }
            print("Added player with player_id : " .. player_id .. " to tournament party")
            break
        else
        print("player in party, but needs to fill")
        end
    end
end

-- Should await whichever instance of a fight and return a winner, other than in the case of NPC VS NPC
-- TODO: 
--      - Add NPC weights to determine who wins with a roll of the dice between 2 NPCS. 
--      - Add parameters to modify battle specifics for other cases. 
--          - Aka NPC vs Player1, NPC vs Player2, Player1 vs Player2.

local function start_battle(player1_id, player2_id)
        if string.find(player1_id, ".zip") and string.find(player2_id, ".zip") then
            print("THIS IS TWO NPCS fighting! DONT WORRY BOUT IT FOR RIGHT NOW")
        end

        if string.find(player2_id, ".zip") then
            print("player1 vs NPC")
            Net.initiate_encounter(player1_id, player2_id)
        else if string.find(player1_id, ".zip") then
            print("Player2 vs NPC")
            Net.initiate_encounter(player2_id, player1_id)
        else
            print("Player vs Player")
            Net.initalize_pvp(player1_id, player2_id)
        end
    end
end

--Shorthand for async
function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end

--Shorthand for await
function await(v) return Async.await(v) end


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
                print(k)
                print(id)
                board_props[k]["active_tournaments"] = {}        
                end
                board_with_props[j] = board_props
            end
        end

        for k, option in next, board_with_props do
            tourney_boards[k] = option
        end
    end
    print(tourney_boards)
    
end

gather_boards()

local function add_participant_mugshot(player_id, participant_number, mug_texture_path, x, y)
    games.add_ui_element("MUG_FRAME_" .. participant_number, player_id, "/server/assets/tourney/mini-mug-frame.png",
        "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", x, y, 2)

    games.add_ui_element("MUG_" .. participant_number, player_id, mug_texture_path,
        "/server/assets/tourney/mug.anim",
        "UI", x, y, 1, .50, .50)
end

local function initialize_tournament_participants(participants, backfill)
    local cleaned_up = {}
    local final_participants = {}
    local should_backfill = true
    for i, p in next, participants do
        table.insert(cleaned_up, p)
    end
    print(cleaned_up)

    if backfill then
        should_backfill = backfill
    end

    final_participants = cleaned_up
    if should_backfill then
        if (#final_participants < 8) then
            print("needs to fill")
            local need_to_fill = 8 - #final_participants
            local random_npc_filler = TableUtils.SelectRandomItemsFromTableClamped(npc_paths, need_to_fill)
            for i, filler_npc in next, random_npc_filler do
                table.insert(final_participants, filler_npc)
            end
        end
    end
    return TableUtils.SelectRandomItemsFromTableClamped(final_participants, 8)
end

local function cleanup_ui(player_id, player_area, original_map_name, original_map_song)
        for i, element in next, frames_to_remove do
            games.remove_ui_element(element, player_id)
        end
        Net.set_area_custom_property(player_area, "Name", original_map_name)
        Net.set_area_custom_property(player_area, "Song", original_map_song)
end

-- handles setting up the background UI elements (Gradients, Grids, Torueny Tree, Title Banner, Tournament Title etc, if they are provided from the selection we will try to default (not currently implemented just is one BG, Grid, And Bracket Config.))
local function setup_board_bg_elements(player_id, board_bg_element_info)
        games.add_ui_element("BOARD BG", player_id, board_bg_element_info.gradient_texture, constants.default_background_anim_path_bn4, "BG", board_pos.x, board_pos.y, board_pos.z)

        games.add_ui_element("BOARD GRID", player_id, board_bg_element_info.grid_texture, constants.default_grid_anim_path_bn4,"UI", grid_pos.x, grid_pos.y, grid_pos.z)

        games.add_ui_element("TOURNEY TREE", player_id, constants.bracket_bm_bn4, constants.default_bracket_anim_path_bn4, "UI", bracket_pos.x, bracket_pos.y, bracket_pos.z)
        
        games.add_ui_element("TITLE BANNER", player_id, "/server/assets/tourney/title-banner.png",
            "/server/assets/tourney/title-banner.anim", "RED", title_banner_pos.x, title_banner_pos.y, title_banner_pos.z)
        --games.add_ui_element("CROWN_1", player_id, "/server/assets/tourney/crown.png",
        --    "/server/assets/tourney/crown.anim", "IDLE", -56, 31, 0)
        --games.add_ui_element("CROWN_2", player_id, "/server/assets/tourney/crown.png",
        --    "/server/assets/tourney/crown.anim", "IDLE", 55, 31, 0)
end

local function cleanup_tourney()

end

-- REQUIRED: pid: string,
local function start_and_show_tourney(pid, board_bg_element_info, tourney)
    return async(function()
        -- Setup
        local player_id = pid
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_custom_property(player_area, "Name")
        Net.set_area_custom_property(player_area, "Name", "            ")
        local original_map_song = Net.get_area_custom_property(player_area, "Song")
        Net.set_area_custom_property(player_area, "Song", "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")
        -- Net.toggle_player_hud(player_id)
        games.activate_framework(player_id)
        games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))
        
        setup_board_bg_elements(player_id,board_bg_element_info)
        for i, p in next, tourney do
            add_participant_mugshot(pid, i, p["player_mugshot"]["mug_texture"], mug_pos.bottom_tier[i].x, mug_pos.bottom_tier[i].y)
        end
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        --start_battle(player_id, npc_paths[1].player_id)
        await(Async.sleep(12.5))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 255 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(0.5))
        cleanup_ui(player_id, player_area, original_map_name, original_map_song)
        await(Async.sleep(0.1))
        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        -- Net.toggle_player_hud(player_id)
        games.unfreeze_player(player_id)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
    end)
end

local function get_board_background_and_grid(object)
    if TiledUtils.check_custom_prop_validity(object.custom_properties, "Board Background") then 
        if object.custom_properties["Board Background"] == "blue_bn4" then
            return constants.bracket_background_path.blue_bn4
        else if object.custom_properties["Board Background"] == "green_bn4" then
           return constants.bracket_background_path.green_bn4
        else if object.custom_properties["Board Background"] == "pink_yellow_bn4" then
            return constants.bracket_background_path.pink_yellow_bn4
        else if object.custom_properties["Board Background"] == "lemon_lime_bn4" then
            return constants.bracket_background_path.lemon_lime_bn4
        else if object.custom_properties["Board Background"] == "green_blue_white_bn4" then
            return constants.bracket_background_path.green_blue_white_bn4
        else if object.custom_properties["Board Background"] == "red_orange_bn4" then
            return constants.bracket_background_path.red_orange_bn4
        end
        print("Please only enter pre-defined BGs and grids for now! Will default to red_orange_bn4's setup")
        return constants.bracket_background_path.red_orange_bn4
    end
    end
    end
    end
    end
    else 
        print("No BG was chosen will default to red_orange_bn4's setup")
        return constants.bracket_background_path.red_orange_bn4
        end
end

Net:on("object_interaction", function(event)
    local tournament = {}
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type ~= "Tournament Board" and object.class ~= "Tournament Board" then
        print("No match found, No work to do.")
        return
    end
    local board_background_setup_info = get_board_background_and_grid(object)
    
    print("Object match")
    join_or_create_party(event.player_id, event.object_id)
    start_and_show_tourney(event.player_id, board_background_setup_info, initialize_tournament_participants(tourney_boards[player_area][event.object_id].active_tournaments))
end)

Net:on("player_connect", function(event)
    local player_mug = Net.get_player_mugshot(event.player_id)
    Net.provide_asset_for_player(event.player_id, "/server/assets/tourney/mug.anim")
    online_players = { player_id = event.player_id, mugshot_texture = { mugshot_texture = player_mug.texture_path, mug_animation = "/server/assets/tourney/mug.anim" } }
end)

Net:on("avatar_change", function(event)
    print("changed avatar")
    local player_mug = Net.get_player_mugshot(event.player_id)
    online_players = { player_id = event.player_id, mugshot_texture = { mugshot_texture = player_mug.texture_path, mug_animation = "/server/assets/tourney/mug.anim" } }
end)

Net:on("player_disconnect", function(event)
    online_players[event.player_id] = nil
    print("Removed player with player_id: " .. event.player_id .. "from online_players")
    print("current online players lists: " .. tostring(online_players))
end)
