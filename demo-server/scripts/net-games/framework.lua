--[[
* ---------------------------------------------------------- *
           Net Games (framework) - Version 0.06
	     https://github.com/indianajson/net-games/   
* ---------------------------------------------------------- *

]]--

local Displayer = require("scripts/net-games/displayer/displayer") --module by D3str0y3d to handle text, timers, countdowns using v2.1

if not Displayer:init() or not Displayer:isValid() then
    print("Failed to initialize Displayer API")
    return false
end


local frame = {} --holds the framework functions and returns them to whatever script is calling them
local frozen = {} --tracks which players are currently frozen
local last_position_cache = {}
local stasis_cache = {} --tracks stasis positions for each area on the server
local cursor_cache = {} --tracks cursors currently spawned for player
local avatar_cache = {} --tracks the original player avatar for each player
local ui_cache = {} --tracks ui elements currently spawned for player 
local map_elements = {} --tracks map elements currently spawned for player 
local ui_update = {} --contains data on any actively sliding/moving UI elements 
local online_players = {} --contains a table of all online players for excluding elements
local cursor_tick = 0 --keeps cursor from being moved too quickly 

-- HELPER FUNCTIONS
-- A variety of simple functions used for repetitive calculations and adjustments


Net:on("player_join", function(event)
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_compressed.png")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_gradient.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_thick.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_battle.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_compressed.animation")

end)

--purpose: checks if a string follows a valid X,Y,Z pattern
local function validateCords(str)
    -- Remove all spaces from the string
    str = str:gsub("%s+", "")
    -- Check for exactly two commas
    local commaCount = 0
    for i = 1, #str do
        if str:sub(i, i) == "," then
            commaCount = commaCount + 1
        end
    end
    if commaCount ~= 2 then
        return false
    end
    -- Check we have exactly 3 parts
    local parts = {}
    for part in str:gmatch("([^,]+)") do
        table.insert(parts, part)
    end
    if #parts ~= 3 then
        return false
    end
    -- Check each part is a whole number with no decimals
    for _, part in ipairs(parts) do
        if not part:match("^%d+$") then
            return false
        end
    end
    -- Check the format is exactly "number,number,number" (no extra characters)
    if not str:match("^%d+,%d+,%d+$") then
        return false
    end

    return true
end

--purpose: converts Net.get_bot_direction() from name to initials used by animations
local function simple_direction(direction) 
    if direction == "Up Left" then
        return "UL"
    elseif direction == "Up Right" then
        return "UR"
    elseif direction == "Down Left" then
        return "DL"
    elseif direction == "Down Right" then
        return "DR"
    elseif direction == "Up" then
        return "U"
    elseif direction == "Down" then
        return "D"
    elseif direction == "Left" then
        return "L"
    elseif direction == "Right" then
        return "R"
    end
end 


--purpose: Shorthand for async
local function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end

--purpose: Shorthand for await
local function await(v) return Async.await(v) end

local function table_has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

--purpose: excludes bot for everyone except provided player_id
local function exclude_except_for(player_id,bot_id)
    for i,p_id in next,online_players do 
        if p_id ~= player_id then
            Net.exclude_actor_for_player(p_id, bot_id)
        end 
    end 
end 

-- PLAYER FUNCTIONS
-- Functons used to interact with the player and the framework 

--purpose: freezes players movement while preserving access to inputs 
--usage: call to initiate stationary mini-game or UI interactions
function frame.freeze_player(player_id)
    return async(function ()
        local area_id = last_position_cache[player_id]["area"]
        if frozen[player_id] == nil then
            return
        elseif frozen[player_id] == true then
            print("[games] Player already frozen. Freeze failed!")
            return
        elseif stasis_cache[area_id] == nil then
            print("[games] "..area_id..".tmx didn't have a Stasis value. Freeze failed!")
            return
        end 

        Net.lock_player_input(player_id)
        local position = Net.get_player_position(player_id)
        local avatar = Net.get_player_avatar(player_id)
        local direction = Net.get_player_direction(player_id)
        local empty_texture = "/server/assets/net-games/empty.png"
        local empty_animation = "/server/assets/net-games/empty.animation"
        avatar_cache[player_id]["texture"] = avatar.texture_path
        avatar_cache[player_id]["animation"] = avatar.animation_path
        -- create stunt double
        Net.create_bot(player_id.."-double", { area_id=area_id, warp_in=false, texture_path=avatar.texture_path, animation_path=avatar.animation_path, x=position.x, y=position.y, z=position.z, direction=direction, solid=true})
        -- hide player
        Net.set_player_avatar(player_id, empty_texture, empty_animation)

        frozen[player_id] = true 
        Net.track_with_player_camera(player_id,player_id.."-double")

        --teleport to stasis
        Net.teleport_player(player_id, false, stasis_cache[area_id]["x"]+.5, stasis_cache[area_id]["y"]+.5, stasis_cache[area_id]["z"])
        local direction = simple_direction(Net.get_player_direction(player_id))
        local keyframes = {{properties={{property="Animation",value="IDLE_"..direction}},duration=0}}
        Net.animate_bot(player_id.."-double", "IDLE_"..direction, true)
        Net.animate_bot_properties(player_id.."-double", keyframes)

        --this updates last player position to stasis so a movement isn't triggered on teleport
        if not last_position_cache[player_id] then 
            last_position_cache[player_id] = {}
        end
        last_position_cache[player_id]["x"] = tonumber(stasis_cache[area_id]["x"]+.5)
        last_position_cache[player_id]["y"] = tonumber(stasis_cache[area_id]["y"]+.5)
        last_position_cache[player_id]["z"] = tonumber(stasis_cache[area_id]["z"])
        --enable movement in stasis
        Net.unlock_player_input(player_id)
        print(player_id.." is in-stasis.")
    end)
end

--purpose: releases player from freeze at the end of mini-game or non-standard UI interactions 
--usage: call to end a mini-games or non-standard UI interactions
function frame.unfreeze_player(player_id)
    if frozen[player_id] == nil then
        return
    elseif Net.is_bot(player_id.."-double") and frozen[player_id] == true then
        Net.lock_player_input(player_id)
        local position = Net.get_bot_position(player_id.."-double") 
        local direction = Net.get_bot_direction(player_id.."-double")
        Net.teleport_player(player_id, false, position.x, position.y, position.z, direction)
        --this updates last player position to stasis so a movement isn't triggered on teleport
        if not last_position_cache[player_id] then 
            last_position_cache[player_id] = {}
        end
        last_position_cache[player_id]["x"] = tonumber(position.x)
        last_position_cache[player_id]["y"] = tonumber(position.y)
        last_position_cache[player_id]["z"] = tonumber(position.z)
        frozen[player_id] = false 
        Net.set_player_avatar(player_id,avatar_cache[player_id]["texture"],avatar_cache[player_id]["animation"])
        Net.remove_bot(player_id.."-double")
        Net.unlock_player_camera(player_id)
        Net.unlock_player_input(player_id)
    else
        print("[games] You can't unfreeze a player who was never frozen, who do you think you are, Chipotle?")
    end
end

--purpose: moves a frozen player from current location to specific cordinates without animation.
function frame.move_frozen_player(player_id,X,Y,Z)
    return async(function ()
    local area_id = last_position_cache[player_id]["area"]
    Net.transfer_bot(player_id.."-double", area_id, false, X, Y, Z)
    end)
end

--purpose: moves a frozen player from current location to specific cordinates with walking animation. 
--status: RE-TEST
function frame.walk_frozen_player(player_id,X,Y,Z,duration,wait)
    return async(function ()
        local position = Net.get_bot_position(player_id.."-double") 
        local keyframes = {{properties={{property="X",ease="Linear",value=position.x},{property="Y",ease="Linear",value=position.y},{property="Z",ease="Linear",value=position.z}},duration=0}}
        keyframes[#keyframes+1] = {properties={{property="X",ease="Linear",value=X},{property="Y",ease="Linear",value=Y},{property="Z",ease="Linear",value=Z}},duration=duration}
        Net.move_bot(player_id.."-double",X,Y,Z)
        Net.animate_bot_properties(player_id.."-double", keyframes)
        if wait == true then 
            await(Async.sleep(duration+.5))
        end
    end)
end

--purpose: animates a frozen player using a specific animation. 
function frame.animate_frozen_player(player_id,animation_state)
    return async(function ()
    local keyframes = {{properties={{property="Animation",value=animation_state}},duration=1}}
    Net.animate_bot_properties(player_id.."-double", keyframes)
    end)
end

-- MAP FUNCTIONS
-- Functions to add, animate, and remove objects based on map position (for mini-game elements on map, especially those visible to other players)

function frame.add_map_element(name,player_id,texture,animation,animation_state,X,Y,Z,exclude)
    
    --spawn map object
    local area_id = last_position_cache[player_id]["area"]
    Net.create_bot(player_id.."-map-"..name, { area_id=area_id, warp_in=false, texture_path=texture, animation_path=animation, animation=animation_state,x=X, y=Y, z=Z, solid=false})

    if exclude == true then
        exclude_except_for(player_id,player_id.."-map-"..name)
    end 
    
    Net.animate_bot(player_id.."-map-"..name, animation_state, true)

    --includes map element in map_elements cache for player so we can track updates and removal  
    if map_elements[player_id] == nil then
        map_elements[player_id] = {}
    end 
    map_elements[player_id][name] = {}
    map_elements[player_id][name]["name"] = name
    map_elements[player_id][name]["state"] = animation_state
    map_elements[player_id][name]["id"] = player_id.."-ui-"..name    
end

function frame.change_map_element(name,player_id,animation_state,loop)
    if Net.is_bot(player_id.."-map-"..name) then
        Net.animate_bot(player_id.."-map-"..name, animation_state,loop)

    else
        print("[games] Come on, "..name.." isn't a map element for that player!")
    end 
end

function frame.move_map_element(name,player_id,X,Y,Z)
    local area_id = last_position_cache[player_id]["area"]
    Net.transfer_bot(player_id.."-map-"..name, area_id, false, X, Y, Z)
end

--purpose: removes UI element from screen
function frame.remove_map_element(name,player_id)
    if Net.is_bot(player_id.."-map-"..name) then 
        map_elements[player_id][name] = nil
        Net.remove_bot(player_id.."-map-"..name)
    end
end

-- UI FUNCTIONS
-- Functions to add, animate, and remove sprites based on camera's view (not map position)

--purpose: places a UI element on screen... that's it. Yes, it's complicated. No, I won't explain it. Blame Jams!
function frame.add_ui_element(sprite_id,player_id,texture_path,animation_path,animation_state,X,Y,Z,ScaleX,ScaleY)

    local scaleX = 2.0
    local scaleY = 2.0
    if ScaleX ~= nil then
        if ScaleX >= 0.0 then
            scaleX = ScaleX
        end
    end
      if ScaleY ~= nil then
        if ScaleY >= 0.0 then
            scaleY = ScaleY
        end
    end
    if not animation_path then animation_path = "" end
    if not animation_state then animation_state = "" end

    if ui_cache[player_id] == nil then
        ui_cache[player_id] = {}
    end 
    --check if sprite already allocated
    local new_sprite_id = sprite_id
    local already_allocated = false
    for sprite_id, sprite_data in next, ui_cache[player_id] do
        if sprite_data["texture_path"] == texture_path then 
            already_allocated = true
            new_sprite_id = sprite_data["sprite_id"]
            print("Using existing sprite.")
        end
    end 
    
    if already_allocated == false then 
        print("Creating new sprite.")
        if animation_path ~= "" then
            Net.provide_asset_for_player(player_id, animation_path)
        end
        Net.provide_asset_for_player(player_id, texture_path)
        Net.player_alloc_sprite(player_id, new_sprite_id, {texture_path = texture_path, anim_path = animation_path, anim_state = animation_state})
    end
    Net.player_draw_sprite(player_id, new_sprite_id,
        {
            id = sprite_id .. "_obj",
            x = X*2, 
            y = Y*2, 
            sx = scaleX,
            sy = scaleY,
            anim_state = animation_state
        }
    )

    if ui_cache[player_id] == nil then
        ui_cache[player_id] = {}
    end 
    --includes UI element in UI cache for player so we can track sprites
    ui_cache[player_id][sprite_id] = {texture_path=texture_path, sprite_id=sprite_id, x=X,y=Y,z=Z,scaleX=scaleX,scaleY=scaleY,rotation=0,animation_state=animation_state,opacity=255}
end

--purpose: allows you to update any property of a sprite element 
function frame.update_ui_element(sprite_id,player_id,properties)
    --write logic to only update elements that need to be updated. 
    local sprite_data = {id = sprite_id .. "_obj"}
    if properties["x"] then 
        sprite_data["x"] = properties["x"]
        ui_cache[player_id][sprite_id]["x"] = properties["x"]
    end 
    if properties["y"] then 
        sprite_data["y"] = properties["y"]
        ui_cache[player_id][sprite_id]["y"] = properties["y"]
    end 
    if properties["z"] then 
        sprite_data["z"] = properties["z"]
        ui_cache[player_id][sprite_id]["z"] = properties["z"]
    end 
    if properties["ox"] then 
        sprite_data["ox"] = properties["ox"]
        ui_cache[player_id][sprite_id]["ox"] = properties["ox"]
    end 
    if properties["oy"] then 
        sprite_data["oy"] = properties["oy"]
        ui_cache[player_id][sprite_id]["oy"] = properties["oy"]
    end 
    if properties["scale"] then 
        sprite_data["sx"] = properties["scale"]
        ui_cache[player_id][sprite_id]["scaleX"] = properties["scale"]
        sprite_data["sy"] = properties["scale"]
        ui_cache[player_id][sprite_id]["scaleY"] = properties["scale"]
    end 
    if properties["rotation"] then 
        sprite_data["ro"] = properties["ro"]
        ui_cache[player_id][sprite_id]["rotation"] = properties["rotation"]
    end 
    if properties["opacity"] then 
        sprite_data["opacity"] = properties["opacity"]
        ui_cache[player_id][sprite_id]["opacity"] = properties["opacity"]
    end 
    if properties["animation_state"] then 
        sprite_data["anim_state"] = properties["animation_state"]
        ui_cache[player_id][sprite_id]["animation_state"] = properties["animation_state"]
    end 
    Net.player_draw_sprite(player_id, sprite_id,sprite_data)
end

--purpose: change the animation state of existing UI element
function frame.set_ui_animation(sprite_id,player_id,animation_state)
    
    Net.player_draw_sprite(player_id, ui_cache[player_id][sprite_id]["sprite_id"],
    {
        id = sprite_id .. "_obj",
        anim_state = animation_state    
    }
    )
end

--purpose: move existing UI element
function frame.move_ui_element(sprite_id,player_id,X,Y,Z)
    Net.player_draw_sprite(player_id, ui_cache[player_id][sprite_id]["sprite_id"],
    {
        id = sprite_id .. "_obj",
        x = X*2,
        y = Y*2,
        z = Z    
    }
    )
end

function frame.update_ui_position(sprite_id, player_id, X, Y, Z)
    if ui_cache[player_id] and ui_cache[player_id][sprite_id] then
        local element = ui_cache[player_id][sprite_id]
        Net.player_draw_sprite(player_id, element.sprite_id,
            {
                id = sprite_id .. "_obj",
                x = X*2,
                y = Y*2,
                z = Z or element.z,
                sx = element.scaleX,
                sy = element.scaleY,
                anim_state = element.animation_state
            }
        )
        -- Update cache
        element.x = X
        element.y = Y
        element.z = Z or element.z
    end
end

--purpose: slide an existing UI element across the screen over a specified duration
function frame.slide_ui_element(sprite_id,player_id,X,Y,duration)
    print("slide_ui_element() is not yet supported.")
    --local element = ui_cache[player_id][sprite_id]
    return 
    --add move to ui_update table
end

--purpose: make camera pannable freely with arrows but without player following. 
function frame.detach_camera(player_id)
    print("detach_camera() is not yet supported.")
    return 
end

--purpose: removes UI element from screen
function frame.remove_ui_element(sprite_id,player_id)
    Net.player_erase_sprite(player_id, sprite_id .. "_obj")
end

-- TEXT FUNCTIONS
function frame.draw_text(text_id,player_id,text,x,y,z,font,scale)
    Displayer.Text.drawText(player_id, text_id, text, tonumber(x)*2, tonumber(y)*2, z, font, scale)
end

function frame.update_text(text_id,player_id,text)
    Displayer.Text.updateText(player_id, text_id, tostring(text))
end

function frame.remove_text(text_id,player_id)
    Displayer.Text.removeText(player_id, text_id)
end

-- ADD MARQUEE TEXT FUNCTION
function frame.draw_marquee_text(marquee_id, player_id, text, y, font, scale, z_order, speed, backdrop)
    Displayer.Text.drawMarqueeText(player_id, marquee_id, text, y, font, scale, z_order, speed, backdrop)
end

function frame.set_marquee_position(player_id, marquee_id, x, y)
    Displayer.Text.setMarqueePosition(player_id, marquee_id, x, y)
end

function frame.set_marquee_speed(player_id, marquee_id, speed)
    Displayer.Text.setMarqueeSpeed(player_id, marquee_id, speed)
end

-- TIMER FUNCTIONS

function frame.spawn_timer(timer_id,player_id,X,Y,duration,loop)
    loop = loop or false
    Displayer.Timer.createPlayerTimer(
        player_id, 
        timer_id, 
        duration, 
        function(_, timer_id, value)
        end,
        loop)
    Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, timer_id, X*2, Y*2, "default")
end 

function frame.resume_timer(timer_id,player_id)
    Displayer.Timer.resumePlayerTimer(player_id, timer_id)
end

function frame.pause_timer(timer_id,player_id)
    Displayer.Timer.pausePlayerTimer(player_id, timer_id)
end

function frame.remove_timer(timer_id,player_id)
    Displayer.Timer.removePlayerTimer(player_id, timer_id)
end 

function frame.update_timer(timer_id,player_id,duration)
    Displayer.Timer.updatePlayerTimer(player_id, timer_id, duration)
end 

-- COUNTDOWN FUNCTIONS

function frame.spawn_countdown(countdown_id,player_id,X,Y,duration,loop)
    loop = loop or false
    Displayer.Timer.createPlayerCountdown(
        player_id, 
        countdown_id, 
        duration, 
        function(_, countdown_id, value)
            if value <= 0 then
                Net:emit("countdown_ended", {player_id = player_id, countdown_id=countdown_id})
            end
        end,
        loop)
    Displayer.TimerDisplay.createPlayerCountdownDisplay(player_id, countdown_id, X*2, Y*2, "default")
end 

function frame.resume_countdown(countdown_id,player_id)
    Displayer.Timer.resumePlayerCountdown(player_id, countdown_id)
end

function frame.pause_countdown(countdown_id,player_id)
    Displayer.Timer.pausePlayerCountdown(player_id, countdown_id)
end

function frame.remove_countdown(countdown_id,player_id)
    Displayer.Timer.removePlayerCountdown(player_id, countdown_id)
end 

function frame.update_countdown(countdown_id,player_id,duration)
    Displayer.Timer.updatePlayerCountdown(player_id, countdown_id, duration)
end 

-- CURSOR FUNCTIONS
-- Create selectors with customizable arrows or icons and respond to cursor movements in realtime. 

--purpose: spawns a cursor that shifts between options based on a table of information provided
function frame.spawn_cursor(cursor_id,player_id,options) 
    return async(function ()
    --player is forcibly frozen
    if frozen[player_id] == nil then 
        await(frame.freeze_player(player_id))
    elseif frozen[player_id] == false then
        await(frame.freeze_player(player_id))
    end 
    --setup variables from provided options
    local area_id = last_position_cache[player_id]["area"]
    if cursor_cache[player_id] ~= nil then if next(cursor_cache[player_id]) ~= nil then if cursor_cache[player_id] ~= {} then
        print("[games] You already got a cursor for that user, remove it first.") 
        return 
    end end end 
    --add cursor to cache 
    cursor_cache[player_id] = {}
    cursor_cache[player_id] = options
    cursor_cache[player_id]["name"] = cursor_id
    --create bot and set initial cursor arrow in position cursor_cache[player_id]["selections"][1]
    local selection = cursor_cache[player_id]["selections"][1]

    --print(options)
    if animation_path ~= "" then
        Net.provide_asset_for_player(player_id, options["animation"])
    end
    Net.provide_asset_for_player(player_id, options["texture"])
    Net.player_alloc_sprite(player_id, cursor_id, {texture_path = options["texture"], anim_path = options["animation"], anim_state = selection["state"]})
    Net.player_draw_sprite(player_id, cursor_id,
        {
            id = cursor_id .. "_obj",
            x = selection["x"]*2, 
            y = selection["y"]*2, 
            z = selection["z"],
            sx=2,
            sy=2,
            anim_state = selection["state"]
        }
    )

    if cursor_cache[player_id]["sprites"] == nil then
        cursor_cache[player_id]["sprites"] = {}
    end 

    --this tracks the index of the current selection
    cursor_cache[player_id]["current"] = 1
    --tracks timed lockout to avoid multiple accidental button presses 
    cursor_cache[player_id]["locked"] = false

end)
end

--purpose: removes a cursor and clears cursor_cache for player
function frame.remove_cursor(cursor_id,player_id)
    cursor_cache[player_id] = nil
    Net.player_erase_sprite(player_id, cursor_id .. "_obj")
    frame.unfreeze_player(player_id)
end

--purpose: logic to check if cursor is active and emit corresponding events
Net:on("button_press", function(event)
    return async(function ()
    if cursor_cache[event.player_id] ~= nil then
        if cursor_cache[event.player_id]["locked"] == false then
            local cursor = cursor_cache[event.player_id]
            local direction = cursor["movement"]
            --print(event.button)
            --if directional button emit move
            cursor_cache[event.player_id]["lock-tick"] = cursor_tick
            cursor_cache[event.player_id]["locked"] = true

            if ((event.button == "D" or event.button == "U") and direction=="vertical") or
            ((event.button == "L" or event.button == "R") and direction=="horizontal") or
            (event.button == "LS" and direction=="shoulder") then
                Net:emit("cursor_move", {player_id = event.player_id, cursor = cursor["name"], selection = cursor["current"], button = event.button})
            --if A button emit selection
            elseif event.button == "A" then
                Net:emit("cursor_selection", {player_id = event.player_id,cursor = cursor["name"],selection = cursor_cache[event.player_id]["selections"][cursor["current"]]["name"]})
            end

        end 
    end
    end)
end)

--purpose: handles cursor movement logic
--usage: for framework only, use the Game:on("cursor_hover") to respond to cursor movements.
Net:on("cursor_move", function(event)
    local last_selection = cursor_cache[event.player_id]["current"]
    if event.button == "L" or event.button == "LS" or event.button == "U" then
        if last_selection == 1 then
            cursor_cache[event.player_id]["current"] = #cursor_cache[event.player_id]["selections"]
        else 
            cursor_cache[event.player_id]["current"] = last_selection - 1
        end 
    elseif event.button == "R" or event.button == "D" then
        if last_selection == #cursor_cache[event.player_id]["selections"] then
            cursor_cache[event.player_id]["current"] = 1
        else 
            cursor_cache[event.player_id]["current"] = last_selection + 1
        end 
    end 

    local selection = cursor_cache[event.player_id]["selections"][cursor_cache[event.player_id]["current"]]

    Net.player_draw_sprite(event.player_id, event.cursor, {id=event.cursor.."_obj", x=selection["x"]*2, y=selection["y"]*2})

    Net:emit("cursor_hover", {player_id = event.player_id,cursor = cursor_cache[event.player_id]["name"],selection = selection["name"]})

end)

-- NON-CODER FUNCTIONS
-- The functions in this section are framework management only, you shouldn't call these in your code. 

--purpose: sets the stasis chamber location used during freeze_player() 
--usage: automatically called on server boot and creates a stasis tile high on every map 
local function set_stasis()
	local areas = Net.list_areas()
    for i, area_id in next, areas do
        local area_id = tostring(area_id)
        if Net.get_area_custom_property(area_id, "Stasis") ~= nil then
            local cords = Net.get_area_custom_property(area_id, "Stasis")
            if validateCords(cords) == true then
                stasis_cache[area_id] = {}
                local parts = {}
                local prop = Net.get_area_custom_property(area_id, "Stasis")
                for part in prop:gmatch("([^,]+)") do
                    table.insert(parts, part)
                end
                stasis_cache[area_id]["x"] = parts[1]
                stasis_cache[area_id]["y"] = parts[2]
                stasis_cache[area_id]["z"] = parts[3]
                --print ("[games] Stasis for "..area_id.." set to "..prop)
            else
                print ("[games] Stasis for "..area_id.." not set, cords were malformed.")
            end
        end 
	end
end

--purpose: splits a string based on a delimiter
--usage: used at various points to seperate values
local function splitter(inputstr, sep)
    if sep == nil then
        sep = '%s'
    else
        sep = sep:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
    end
    
    local t = {}
    for str in (inputstr..sep):gmatch("(.-)"..sep) do
        table.insert(t, str)
    end
    return t
end

--purpose: converts button presses from tile_interaction into names
--usage: runs automatically when tile interaction detected
local function process_button_press(player_id,button)
    --converts number to letter 
    if button == 0 then
        button = "A" --Interact
    elseif button == 1 then
        button = "LS" --Left Shoulder 
    end 

    Net:emit("button_press", {player_id = player_id, button = button})
end 

--purpose: checks player movements as they happen and returns the direction, speed, and whether they are the same as last reported
--usage: called automatically by Net:on("player_move")
local function analyze_player_movement(player_id,x,y,z) --was process_movement_event
    local direction = ""
    local speed = ""
    local direction_match = false
    local speed_match = false

    if not last_position_cache[player_id] then 
        last_position_cache[player_id] = {}
        last_position_cache[player_id]["area"] = Net.get_player_area(player_id) 
        last_position_cache[player_id]["x"] = tonumber(x)
        last_position_cache[player_id]["y"] = tonumber(y)
        last_position_cache[player_id]["z"] = tonumber(z)
        last_position_cache[player_id]["d"] = ""
        last_position_cache[player_id]["pd"] = ""
        last_position_cache[player_id]["s"] = ""
        last_position_cache[player_id]["ps"] = ""
        return
    end
    local area_id = last_position_cache[player_id]["area"]
    local position = stasis_cache[area_id]

    --running
    if (last_position_cache[player_id]["x"] - x) > 0.3 and (last_position_cache[player_id]["y"] - y) > 0.3 then
        speed = "run"
        direction = "U"
    elseif (last_position_cache[player_id]["x"] - x) > 0.3 and (last_position_cache[player_id]["y"] - y) == 0 then
        speed = "run"
        direction = "UL"
    elseif (last_position_cache[player_id]["x"] - x) == 0 and (last_position_cache[player_id]["y"] - y) > 0.3 then
        speed = "run"
        direction = "UR"
    elseif (x - last_position_cache[player_id]["x"]) == 0 and (y - last_position_cache[player_id]["y"]) > 0.3 then
        speed = "run"
        direction = "DL"
    elseif (x - last_position_cache[player_id]["x"]) > 0.3 and (y - last_position_cache[player_id]["y"]) == 0 then
        speed = "run"
        direction = "DR"
    elseif (x - last_position_cache[player_id]["x"]) > 0.3 and (y - last_position_cache[player_id]["y"]) > 0.3 then
        speed = "run"
        direction = "D"
    elseif (x - last_position_cache[player_id]["x"]) > 0.19 and (y - last_position_cache[player_id]["y"]) < -0.19 then
        speed = "run"
        direction = "R"
    elseif (x - last_position_cache[player_id]["x"]) < -0.19 and (y - last_position_cache[player_id]["y"]) > 0.19 then
        speed = "run"
        direction = "L"

    --walking
    elseif (last_position_cache[player_id]["x"] - x) > .01 and (last_position_cache[player_id]["y"] - y) > .01 then
        speed = "walk"
        direction = "U"
    elseif (last_position_cache[player_id]["x"] - x) > .01 and (last_position_cache[player_id]["y"] - y) == 0 then
        speed = "walk"
        direction = "UL"
    elseif (last_position_cache[player_id]["x"] - x) == 0 and (last_position_cache[player_id]["y"] - y) > .01 then
        speed = "walk"
        direction = "UR"
    elseif (x - last_position_cache[player_id]["x"]) == 0 and (y - last_position_cache[player_id]["y"]) > .01 then
        speed = "walk"
        direction = "DL"
    elseif (x - last_position_cache[player_id]["x"]) > .01 and (y - last_position_cache[player_id]["y"]) == 0 then
        speed = "walk"
        direction = "DR"
        
    elseif (x - last_position_cache[player_id]["x"]) > .01 and (y - last_position_cache[player_id]["y"]) > .01 then
        speed = "walk"
        direction = "D"
    elseif (x - last_position_cache[player_id]["x"]) > .01 and (y - last_position_cache[player_id]["y"]) < -.01 then
        speed = "walk"
        direction = "R"
    elseif (x - last_position_cache[player_id]["x"]) < -.01 and (y - last_position_cache[player_id]["y"]) > .01 then
        speed = "walk"
        direction = "L"
    else
        speed = "walk"
        direction="none"
    end 

    --direction reported by Net.get_player_direction() is delayed so we use this instead.
    last_position_cache[player_id]["x"] = tonumber(x)
    last_position_cache[player_id]["y"] = tonumber(y)
    last_position_cache[player_id]["z"] = tonumber(z)
    --log previous direction for tracking
    if last_position_cache[player_id]["d"] ~= "" then
        if last_position_cache[player_id]["pd"] ~= "" then
            if last_position_cache[player_id]["pd"] == last_position_cache[player_id]["d"] then 
                --same direction from last event
                direction_match = true
            else 
                --different direction from last event
                direction_match = false
            end 
        end 
        last_position_cache[player_id]["pd"] = last_position_cache[player_id]["d"]
    end 
    --set current direction
    if direction == none then 
        last_position_cache[player_id]["d"] = last_position_cache[player_id]["d"]
    else
        last_position_cache[player_id]["d"] = direction
    end 
    --log previous speed for tracking
    if last_position_cache[player_id]["s"] ~= "" then
        if last_position_cache[player_id]["ps"] ~= "" then
            if last_position_cache[player_id]["ps"] == last_position_cache[player_id]["s"] then 
                --same speed from last event
                speed_match = true
            else 
                --different speed from last event
                speed_match = false
            end 
        end 
        last_position_cache[player_id]["ps"] = last_position_cache[player_id]["s"]
    end 
    --set current speed
    last_position_cache[player_id]["s"] = speed

    if direction ~= "" then
            Net:emit("button_press", {player_id = player_id, button = direction})
    end
    local same = false
    if speed_match == true and direction_match == true then
        same = true
    end

    return {speed = last_position_cache[player_id]["s"], direction = last_position_cache[player_id]["d"], same = same}
end 

local function update_stasis(player_id)
    return async(function ()
        --reset player position if they are in stasis
        if frozen[player_id] then if frozen[player_id] == true then
            local area_id = Net.get_player_area(player_id) 
            local position = stasis_cache[area_id]
            --if player frozen, move back to center of stasis. 
            last_position_cache[player_id]["x"] = tonumber(position.x+.5)
            last_position_cache[player_id]["y"] = tonumber(position.y+.5)
            last_position_cache[player_id]["z"] = tonumber(position.z)
            Net.teleport_player(player_id, false, position.x+.5, position.y+.5, position.z)
        end end 
    end)
end 

-- NON-CODER EVENTS
-- The events in this section are framework management; "no touchie, no touch"! 

--Event handlers for framework to function
Net:on("player_join", function(event)
    
    table.insert(online_players, event.player_id)
    --reset all caches on join
    frozen[event.player_id] = false
    cursor_cache[event.player_id] = {}
    avatar_cache[event.player_id] = {}

    --exclude all existing UI, cursors elements from new player
    if next(ui_cache) ~= nil then
        for player_id,ui in next,ui_cache do
            for name,element in next,ui do
                Net.exclude_actor_for_player(event.player_id, player_id.."-ui-"..element["name"])
            end 
        end
    end
    if next(cursor_cache) ~= nil then
        for player_id,cursor in next,cursor_cache do
            if next(cursor) ~= nil then
                --print(cursor)
                Net.exclude_actor_for_player(event.player_id, player_id.."-cursor-"..cursor["name"])
            end 
        end 
    end 

end)

Net:on("actor_interaction", function(event)
    --emits event on A and L Shoulder press.
    process_button_press(event.player_id,event.button)
end)

Net:on("tile_interaction", function(event)
    --emits event on A and L Shoulder press.
    process_button_press(event.player_id,event.button)
end)

Net:on("player_disconnect", function(event)

    --clear all caches on disconnect
    frozen[event.player_id] = nil
    --ADD: loop for cursor to clear bots
    if cursor_cache[event.player_id] ~= nil then
        cursor_cache[event.player_id] = {}
    end
    avatar_cache[event.player_id] = {}
    if Net.is_bot(event.player_id.."-double") then
        Net.remove_bot(event.player_id.."-double")
    end 
    if Net.is_bot(event.player_id.."-camera") then
        Net.remove_bot(event.player_id.."-camera")
    end 
    for i,player in next,online_players do 
        if player == event.player_id then
            online_players[i] = nil
        end
    end 

    --remove UIs
    if ui_cache[event.player_id] ~= nil then 
        for name,element in next,ui_cache[event.player_id] do
            --Net.remove_bot(event.player_id.."-ui-"..element["name"])
        end
        ui_cache[event.player_id] = nil
        ui_update[event.player_id] = nil
    end
    if next(cursor_cache) ~= nil then
        for player_id,cursor in next,cursor_cache do
            if next(cursor) ~= nil then
                --print(cursor)
                --Net.remove_bot(player_id.."-cursor-"..cursor["name"])
            end 
        end 
    end 


end)

local tick_gap = 6

Net:on("tick", function(event)

    --old system for managing animation updates queued for UI elements
    if next(ui_update) ~= nil then
        for player_id,ui in next,ui_update do
            for i,ui in next,ui_update[player_id] do
                local parts = splitter(ui,"|")
                local ui = parts[1]
                local gap = tonumber(parts[2])
                --change this to trigger draw 

                --animation_state = ui_cache[player_id][ui]["state"]
                --local position = Net.get_bot_position(player_id.."-ui-"..ui) 
                --local keyframes = {{properties={{property="Animation",value=animation_state}},duration=0}}
                --Net.animate_bot_properties(player_id.."-ui-"..ui, keyframes)
                ui_update[player_id][i] = nil
            end 
        end
    end

    if next(cursor_cache) ~= nil then
        for player_id,cursor in next,cursor_cache do
            if cursor_cache[player_id]["locked"] == true and cursor_cache[player_id]["lock-tick"] == tick_gap then
                cursor_cache[player_id]["locked"] = false
                cursor_cache[player_id]["lock-tick"] = 20 --out of range so never triggers
            end 
        end
    end

    --tick tracker for cursor updates
    cursor_tick = tick_gap
    tick_gap = tick_gap - 1
    if tick_gap <= 0 then
        tick_gap = 6

    end


end)

Net:on("player_move", function(event)

    --emits event on d-pad press
    analyze_player_movement(event.player_id,event.x,event.y,event.z)
    --moves players back to stasis center if frozen
    update_stasis(event.player_id)

end)


Net:on("player_area_transfer", function(event)
    local pid = event.player_id
    if not pid then return end

    -- Ensure we have a cache entry for this player
    if not last_position_cache[pid] then
        last_position_cache[pid] = {}
    end

    -- Update the cached area to the player's new area
    last_position_cache[pid]["area"] = Net.get_player_area(pid)
end)

-- Whatcha doin'? If you're here you must be a coder, or at least interesting in coding.
-- You should help out on the Discord. There's only a few of us that can actually code. 
-- Seriously, stop reading this and come help! For real. Please. I'm begging you. 

--print("[games] Framework initiated")

set_stasis()

return frame
