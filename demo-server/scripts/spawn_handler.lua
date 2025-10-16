local alternative_spawn = true

local maps = {
    default = "default",
    tourney = "tourney",
}

local should_spawn_player_to = "tourney"

Net:on("player_connect", function(event)
    for i, map_name in next, maps do
        if (map_name == should_spawn_player_to) then
        local spawn_point = Net.get_object_by_name(map_name, "Player Spawn")
        Net.transfer_player(event.player_id, map_name, false, spawn_point.x, spawn_point.y, spawn_point.z, "Up Right")
        print("Setting alternate spawn for player. If you wish to change the default spawn area please either set `alternative_spawn` to false to make it spawn the player from the `Home Warp` -OR- change the name provided to `should_spawn_player_to` to the area_id of the desired spawn point. Must have an object named `Player Spawn` on the destined map for this to work properly.")
        end
    end
    print("Got through connect")
end)