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
local available_players = {}
local active_tournaments = {}
local mob_path = "/server/assets/tourney/npc-navis/"
local default_mug_anim = "/server/assets/tourney/mug.anim"

local frames_to_remove = {
    "MUG_FRAME_"..1, "MUG_FRAME_"..2, "MUG_FRAME_"..3, 
    "MUG_FRAME_"..4, "MUG_FRAME_"..5, "MUG_FRAME_"..6, 
    "MUG_FRAME_"..7, "MUG_FRAME_"..8,
    "MUG_"..1, "MUG_"..2, "MUG_"..3, 
    "MUG_"..4, "MUG_"..5, "MUG_"..6, 
    "MUG_"..7, "MUG_"..8, "BOARD BG", 
    "TOURNEY TREE", "TITLE BANNER", 
    --"CROWN_1", "CROWN_2",
}

local npc_paths = {
    [1] = {
        player_id = "/server/assets/tourney/npc-navis/bass/bass1.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis/bass/mug.png",
            mug_animation = default_mug_anim,
        },
    },
    [2] = {
        player_id = "/server/assets/tourney/npc-navis/blastman/blastman1.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis/blastman/mug.png",
            mug_animation = default_mug_anim,
        },
    },
    [3] = {
        player_id = "/server/assets/tourney/npc-navis/burnerman/burnerman1.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis/burnerman/mug.png",
            mug_animation = default_mug_anim,
        },
    },
    [4] = {
        player_id = "/server/assets/tourney/npc-navis/circusman/circusman.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis/circusman/mug.png",
            mug_animation = default_mug_anim,
        },
    },
    [5] = {
        player_id = "/server/assets/tourney/npc-navis/elementman/elementman1.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis/elementman/mug.png",
            mug_animation = default_mug_anim,
        },
    },
    [6] = {
        player_id = "/server/assets/tourney/npc-navis/hatman/hatman.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis/hatman/mug.png",
            mug_animation = default_mug_anim,
        },
    },
    [7] = {
        player_id = "/server/assets/tourney/npc-navis/iceman/iceman.zip",
        player_mugshot = {
            mug_texture = "/server/assets/tourney/npc-navis/iceman/mug.png",
            mug_animation = default_mug_anim,
        },
    }
}

local function find_in_table(t, v1)
    for i, v2 in pairs(t) do
        if v1 == v2 then
            return i
        end
    end
    return nil
end


local function start_party(player_id)
    local player_mugshot = Net.get_player_mugshot(player_id)
    local party = {participants = {
        [player_id] = {player_id = player_id, player_mugshot = {mug_texture = player_mugshot.texture_path, mug_animation = default_mug_anim }}
    }}
    table.insert(active_tournaments, party)
end

local function join_or_create_party(player_id)
    if (#active_tournaments < 1) then
        print("No active parties.")
        start_party(player_id)
        print("Starting tournament. This is all active tournaments :" .. tostring(active_tournaments))
        return
    end
    print("Active tournament exists")
    for i, party in next, active_tournaments do
        if #(party.participants) < 8 and not TableUtils.Contains(party.participants, player_id) then
            active_tournaments[i].participants[player_id] = {player_id = player_id, player_mugshot = Net.get_player_mugshot(player_id)}
            print("Added player with player_id : ".. player_id.." to tournament party")
            print(active_tournaments)
            break
        end
        start_party(player_id)
    end
end


-- top down positions, this is including interprolation positions as well as resting locations
local bottom_tier = {
    [1] = {
            x = -112,
            y = -48,
    },
    [2] = {
            x = -86,
            y = -48,
    },
    [3] = {
            x = -56,
            y = -48,
    },
    [4] = {
            x = -30,
            y = -48,
    },
    [5] = {
            x = 8,
            y = -48,
    },
    [6] = {
            x = 34,
            y = -48,
    },
    [7] = {
            x = 64,
            y = -48,
    },
    [8] = {
            x = 90,
            y = -48,
    },
}

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

local function add_participant_mugshot(player_id, participant_number, mug_texture_path, x, y)
    games.add_ui_element("MUG_FRAME_"..participant_number, player_id, "/server/assets/tourney/mini-mug-frame.png",
        "/server/assets/tourney/mini-mug-frame.anim", "ACTIVE", x, y, 2)

    games.add_ui_element("MUG_"..participant_number, player_id, mug_texture_path,
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

    if backfill then
        should_backfill = backfill
    end

    final_participants = cleaned_up
    if should_backfill then
        if (#final_participants < 8) then  
            local need_to_fill = 8 - #final_participants 
            local random_npc_filler = TableUtils.SelectRandomItemsFromTableClamped(npc_paths, need_to_fill)
            print(random_npc_filler) 
            for i, filler_npc in next, random_npc_filler do
                table.insert(final_participants, filler_npc)    
            end
            print(final_participants)
        end
    end
    return final_participants
end

-- REQUIRED: player_id: string,
-- OPTIONAL: single_player: bool,
local function start_tourney(pid)
    return async(function()
        local player_id = pid
        local player_area = Net.get_player_area(player_id)

        local original_map_name = Net.get_area_custom_property(player_area, "Name")
        Net.set_area_custom_property(player_area, "Name", "            ")

        local original_map_song = Net.get_area_custom_property(player_area, "Song")
        Net.set_area_custom_property(player_area, "Song", "/server/assets/tourney/music/bbn4_tournament_announcement.ogg")


        games.activate_framework(player_id)
        games.freeze_player(player_id)
        Net.lock_player_input(player_id)
        Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=255}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))

        games.add_ui_element("BOARD BG", player_id, "/server/assets/tourney/bgs/orange-bg.png",
            "/server/assets/tourney/bgs/bg.animation", "BG", -120, 80, -1)
        games.add_ui_element("TOURNEY TREE", player_id, "/server/assets/tourney/tourney-tree.png",
            "/server/assets/tourney/tourney-tree.anim", "BLANK_TREE", -120, 80, 0)
        games.add_ui_element("TITLE BANNER", player_id, "/server/assets/tourney/title-banner.png",
            "/server/assets/tourney/title-banner.anim", "RED", -120, 80, 0)
        --games.add_ui_element("CROWN_1", player_id, "/server/assets/tourney/crown.png",
        --    "/server/assets/tourney/crown.anim", "IDLE", -56, 31, 0)
        --games.add_ui_element("CROWN_2", player_id, "/server/assets/tourney/crown.png",
        --    "/server/assets/tourney/crown.anim", "IDLE", 55, 31, 0)

        for i, p in next, active_tournaments[1].participants do
            print(p)
            add_participant_mugshot(pid, i, p["player_mugshot"]["mug_texture"], bottom_tier[i].x,bottom_tier[i].y)
        end

        Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=0}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        --start_battle(player_id, npc_paths[1].player_id)
        await(Async.sleep(10))
        Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=255}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(0.5))
        for i, element in next, frames_to_remove do
            games.remove_ui_element(element, player_id)
        end
        Net.set_area_custom_property(player_area, "Name", original_map_name)
        Net.set_area_custom_property(player_area, "Song", original_map_song)
        await(Async.sleep(0.1))
        Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=0}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        games.unfreeze_player(player_id)
        Net.unlock_player_input(player_id)
        games.deactivate_framework(player_id)
    end)
end


Net:on("object_interaction", function(event)
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type ~= "Tournament Board" and object.class ~= "Tournament Board" then
        print("No match found, No work to do.")
    return
    end
        print("Object match")
        join_or_create_party(event.player_id)
        local tournament = {}
        tournament = initialize_tournament_participants(active_tournaments[1].participants)
        active_tournaments[1].participants = tournament
        start_tourney(event.player_id)
end)

Net:on("player_connect", function(event)
    local player_mug = Net.get_player_mugshot(event.player_id)
    Net.provide_asset_for_player(event.player_id, "/server/assets/tourney/mug.anim")
    online_players[event.player_id]= {player_id = event.player_id, mugshot_texture = {mugshot_texture = player_mug.texture_path, mug_animation = "/server/assets/tourney/mug.anim"}}
end)

Net:on("player_disconnect", function(event)
    online_players[event.player_id] = nil
    print("Removed player with player_id: " .. event.player_id .. "from online_players")
    print("current online players lists: " .. tostring(online_players))
end)

