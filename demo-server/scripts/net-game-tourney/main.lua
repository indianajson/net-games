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

games.start_framework()

local tourney_boards = {}
local online_players = {}
local active_tournaments = {}
local mob_path = "/server/assets/tourney/npc-navis/"
local default_mug_anim = "/server/assets/tourney/mug.anim"

local frames_to_remove = {
    "MUG_FRAME_" .. 1, "MUG_FRAME_" .. 2, "MUG_FRAME_" .. 3,
    "MUG_FRAME_" .. 4, "MUG_FRAME_" .. 5, "MUG_FRAME_" .. 6,
    "MUG_FRAME_" .. 7, "MUG_FRAME_" .. 8,
    "MUG_" .. 1, "MUG_" .. 2, "MUG_" .. 3,
    "MUG_" .. 4, "MUG_" .. 5, "MUG_" .. 6,
    "MUG_" .. 7, "MUG_" .. 8, "BOARD BG",
    "TOURNEY TREE", "TITLE BANNER",
    --"CROWN_1", "CROWN_2",
}

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
    player_mugshot = Net.get_player_mugshot(player_id)
    local party = {}
    party = {
            player_id = player_id, 
            player_mugshot = { 
                mug_texture = player_mugshot.texture_path, 
                mug_animation = default_mug_anim
            } 
    }
    table.insert(tourney_boards[player_area][object_id].active_tournaments, party)
end

local function join_or_create_party(player_id, object_id)
    local player_area = ""
    player_area = Net.get_player_area(player_id)
    --tourney_boards[]    
    if (#tourney_boards[player_area][object_id].active_tournaments < 1) then
        print("No active parties.")
        start_party(player_id, player_area, object_id)
        return
    end
    print("Active tournament exists")
    for i, party in next, tourney_boards[player_area][object_id].active_tournaments do
        if #tourney_boards[player_area][object_id].active_tournaments[i] < 8 and not TableUtils.Contains(party, player_id) then
            local mug_texture = ''
            local mug = Net.get_player_mugshot(player_id)
            mug_texture = mug.texture_path
            print(tourney_boards[player_area][object_id].active_tournaments[i])
            tourney_boards[player_area][object_id].active_tournaments[i] = {player_id = player_id, player_mugshot = {mug_animation = default_mug_anim, mug_texture=mug_texture} }
            print("Added player with player_id : " .. player_id .. " to tournament party")
            return
        else
        print("player in party, but needs to fill")
        end
    end
end

local function start_battle(player1_id, player2_id)
    if string.find(player2_id, ".zip") then
        Net.initiate_encounter(player1_id, player2_id)
    else
        Net.initalize_pvp(player1_id, player2_id)
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

    areas = Net.list_areas()

    for i, area_id in next, areas do
        local get_boards = TableUtils.GetAllTiledObjOfXType(area_id, "Tournament Board") 
        if (#get_boards >0) then
            board[area_id] = get_boards
        end
        --print(tourney_boards)
    end


    for j, board_obj in next, board do
        local board_props = {}
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

local function cleanup_tourney()

end

-- REQUIRED: pid: string,
local function start_tourney(pid, tourney)
    return async(function()
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

        local ui_data_pos = ui_data.unmoving_ui_pos
        local board_pos = ui_data_pos.bg
        local bracket_pos = ui_data_pos.bracket
        local title_banner_pos = ui_data_pos.title_banner

        games.add_ui_element("BOARD BG", player_id, constants.bracket_background_path.yellow_bn45,
            constants.bracket_background_anim_path, "BG", board_pos.x, board_pos.y, board_pos.z)
        games.add_ui_element("TOURNEY TREE", player_id, "/server/assets/tourney/tourney-tree.png",
            "/server/assets/tourney/tourney-tree.anim", "BLANK_TREE", bracket_pos.x, bracket_pos.y, bracket_pos.z)
        games.add_ui_element("TITLE BANNER", player_id, "/server/assets/tourney/title-banner.png",
            "/server/assets/tourney/title-banner.anim", "RED", title_banner_pos.x, title_banner_pos.y, title_banner_pos.z)
        --games.add_ui_element("CROWN_1", player_id, "/server/assets/tourney/crown.png",
        --    "/server/assets/tourney/crown.anim", "IDLE", -56, 31, 0)
        --games.add_ui_element("CROWN_2", player_id, "/server/assets/tourney/crown.png",
        --    "/server/assets/tourney/crown.anim", "IDLE", 55, 31, 0)

        for i, p in next, tourney do
            add_participant_mugshot(pid, i, p["player_mugshot"]["mug_texture"], mug_pos.bottom_tier[i].x, mug_pos.bottom_tier[i].y)
        end

        Net.fade_player_camera(player_id, { r = 0, g = 0, b = 0, a = 0 }, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        --start_battle(player_id, npc_paths[1].player_id)
        await(Async.sleep(10))
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


Net:on("object_interaction", function(event)
    local tournament = {}
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type ~= "Tournament Board" and object.class ~= "Tournament Board" then
        print("No match found, No work to do.")
        return
    end
    print("Object match")
    join_or_create_party(event.player_id, event.object_id)
    start_tourney(event.player_id, initialize_tournament_participants(tourney_boards[player_area][event.object_id].active_tournaments))
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
