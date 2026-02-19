local saveGame = require("scripts/persistence/save-game")

local player_saves = {}

Net:on("player_join", function(event)
saveGame(event.player_id, 1)
saveGame(event.player_id, 2)
saveGame(event.player_id, 3)
end)