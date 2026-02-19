local function test()
local expect = require("scripts/test-runner/expect")
local saveGame = require("scripts/persistence/save-game")
local Utility = require("scripts/utils/utility")

local TestEmitter = Utility.EventEmitter.new()

local player_saves = {}

local function emitSaveFilesMade(player_id, save_number)
    TestEmitter:emit("Save File Made", {player_id = player_id, save_number = save_number})
end

TestEmitter:on("Save File Made", function (event)
    local player_id = event.player_id
    local save_num = event.save_number
    print(player_id)
    print(save_num)
end)

Net:on("player_join", function(event)
    local pid = event.player_id
    if not player_saves[pid] then
        player_saves[pid] = {}
    end
    local save1 = saveGame(event.player_id, 1)
    local result = expect(save1).toBe({1234})
    print(result)
    emitSaveFilesMade(event.player_id, 1)
    local save2 = saveGame(event.player_id, 2)
    emitSaveFilesMade(event.player_id, 2)
    local save3 = saveGame(event.player_id, 3)
    emitSaveFilesMade(event.player_id, 3)
    
    table.insert(player_saves[pid], save1)
    table.insert(player_saves[pid], save2)
    table.insert(player_saves[pid], save3)
end)

end

return test