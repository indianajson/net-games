local TableUtils = require("scripts/table-utils")
local games = require("scripts/net-games/framework")
games.start_framework()

local tourney_boards = {}
local online_players = {}
local active_tournaments = {}

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


Net:on("player_connect", function (event)
    if not(TableUtils.Contains(online_players,event.player_id)) then
    table.insert(online_players, event.player_id)
    end
end)

local function start_tourney(player_id)
    return async(function ()
    games.activate_framework(player_id)
    Net.lock_player_input(player_id)
    Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=255}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
    await(Async.sleep(.75))
    games.freeze_player(player_id)
    games.add_ui_element("BOARD BG",player_id,"/server/assets/tourney/orange-bg.png","/server/assets/tourney/bg.animation","BG",-120,80, -1)
    games.add_ui_element("TOURNEY TREE",player_id,"/server/assets/tourney/tourney-tree.png","/server/assets/tourney/tourney-tree.anim","BLANK_TREE",-120,80, 0)
    games.add_ui_element("TITLE BANNER",player_id,"/server/assets/tourney/tourney-tree.png","/server/assets/tourney/tourney-tree.anim","BLANK_TREE",-120,80, 0)
    Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=0}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
    await(Async.sleep(.75))
    Net.unlock_player_input(player_id)
    end)
end

Net:on("object_interaction", function(event)
    local player_area = Net.get_player_area(event.player_id)
    local object = Net.get_object_by_id(player_area, event.object_id)
    if object.type == "Tournament Board" then
        print("Type match")   
        start_tourney(event.player_id)
    end  
    if object.class == "Tournament Board" then
        print("Object match")       
        start_tourney(event.player_id)
    end
end)