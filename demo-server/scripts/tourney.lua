-- TODOS AND NOTES:
-- There are 15 positions for the tournament board to worry about placing player/NPC mugshots. The tiers go (8 positions, 4 positions, 2 positions, 1 position)
-- We should allow people to pass in a tournament name to be printed to the screen centered within the title banner/or graphic for name provided
-- Figure out a good way to handle the moving of mugshots, in Particular identify the best way to handle the glowing moving bar that follows behind the mugshots.
--   - Current thinking grab a copy of each unique "elbow" and setup the animation on each and we can set which one to start animating/change to solid color on next re-open of the tourney board.
local TableUtils = require("scripts/table-utils")
local games = require("scripts/net-games/framework")
games.start_framework()

local tourney_boards = {}
local online_players = {}
local active_tournaments = {}
local mob_path = "/server/assets/tourney/npc-navis/"

local npc_paths = {
    Bass = {
        encounter = "/server/assets/tourney/npc-navis/bass/bass1.zip",
        mug_texture = "/server/assets/tourney/npc-navis/bass/mug.png",
        mug_animation = "/server/assets/tourney/mug.anim",
    }
}

-- top down positions, this is including interprolation positions as well as resting locations
local mug_movement_map = {
    position23 = {
        mugshot_frame_pos = {
            x = -112,
            y = -48,
            z = 1
        },
        mugshot_position = {

        },
    },
    position24 = {
        mugshot_frame_pos = {
            x = -86,
            y = -48,
            z = 1
        }
    },
}

--Shorthand for async
function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end

--Shorthand for await
function await(v) return Async.await(v) end

local function gather_boards()
    local areas = Net.list_areas()
    for i, area_id in next, areas do
        local boards = TableUtils.GetAllTiledObjOfXType(area_id, "Tournament Board")
        if (#boards > 0) then
            tourney_boards[area_id] = boards
        end
    end
    print(tourney_boards)
end

gather_boards()


local function initialize_tourney()
end


function test_add_mugshot(player_id)
    games.add_ui_element("MUG_FRAME1", player_id, "/server/assets/tourney/mini-mug-frame.png",
        "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", -112, -48, 2)

    games.add_ui_element("MUG_1", player_id, online_players[player_id]["player_mugshot"]["texture_path"],
        "/server/assets/tourney/mug.anim",
        "MUG", 0, 0, 1)

    Net.animate_bot_properties(tostring(player_id) .. "_ui_" .. "MUG_1",
        { properties = { ScaleX = 0.5 }, duration = 0 })
    -- -110, -50, 1
end

-- REQUIRED: player_id: string,
-- OPTIONAL: single_player: bool,
local function start_tourney(pid, single_player)
    return async(function()
        local player_id = pid
        local player_area = Net.get_player_area(player_id)
        local original_map_name = Net.get_area_custom_property(player_area, "Name")
        Net.set_area_custom_property(player_area, "Name", "            ")
        games.activate_framework(player_id)
        Net.lock_player_input(player_id)
        --Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=255}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))
        games.freeze_player(player_id)
        games.add_ui_element("BOARD BG", player_id, "/server/assets/tourney/orange-bg.png",
            "/server/assets/tourney/bg.animation", "BG", -120, 80, -1)
        games.add_ui_element("TOURNEY TREE", player_id, "/server/assets/tourney/tourney-tree.png",
            "/server/assets/tourney/tourney-tree.anim", "BLANK_TREE", -120, 80, 0)
        games.add_ui_element("TITLE BANNER", player_id, "/server/assets/tourney/title-banner.png",
            "/server/assets/tourney/title-banner.anim", "RED", -120, 80, 0)

        test_add_mugshot(player_id)

        games.add_ui_element("MUG FRAME2", player_id, "/server/assets/tourney/mini-mug-frame.png",
            "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", -86, -48, 2)
        games.add_ui_element("MUG_2", player_id, npc_paths.Bass.mug_texture, npc_paths.Bass.mug_animation, "MUG", -84,
            -50, 1)


        games.add_ui_element("MUG FRAME3", player_id, "/server/assets/tourney/mini-mug-frame.png",
            "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", -56, -48, 2)
        games.add_ui_element("MUG FRAME4", player_id, "/server/assets/tourney/mini-mug-frame.png",
            "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", -30, -48, 2)
        games.add_ui_element("MUG FRAME5", player_id, "/server/assets/tourney/mini-mug-frame.png",
            "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", 8, -48, 2)
        games.add_ui_element("MUG FRAME6", player_id, "/server/assets/tourney/mini-mug-frame.png",
            "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", 34, -48, 2)
        games.add_ui_element("MUG FRAME7", player_id, "/server/assets/tourney/mini-mug-frame.png",
            "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", 64, -48, 2)
        games.add_ui_element("MUG FRAME8", player_id, "/server/assets/tourney/mini-mug-frame.png",
            "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", 90, -48, 2)


        --Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=0}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(3))
        Net.unlock_player_input(player_id)
    end)
end


local function determine_player_or_mob()

end

Net:on("object_interaction", function(event)
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type == "Tournament Board" then
        print("Type match")
        start_tourney(event.player_id, true)
    end
    if object.class == "Tournament Board" then
        print("Object match")
        start_tourney(event.player_id, true)
    end
end)

Net:on("player_connect", function(event)
    online_players[event.player_id] = {
        player_mugshot = Net.get_player_mugshot(event.player_id)
    }
    Net.provide_asset_for_player(event.player_id, "/server/assets/tourney/mug.anim")
    print(online_players)
end)

Net:on("player_disconnect", function(event)
    online_players[event.player_id] = nil
    print("Removed player with player_id: " .. event.player_id .. "from online_players")
    print("current online players lists: " .. tostring(online_players))
end)
