--[[
* ---------------------------------------------------------- *
           Net Games (framework) - Version 0.07
	     https://github.com/indianajson/net-games/   
* ---------------------------------------------------------- *

]]--

local Displayer = require("scripts/net-games/displayer/displayer") --module by D3str0y3d to handle text, timers, countdowns using v2.1

if not Displayer:init() or not Displayer:isValid() then
    print("Failed to initialize Displayer API")
    return false
end

local frame = {} --holds the framework functions and returns them to whatever script is calling them
local last_position_cache = {} --legacy cache that only tracks player's area now
local button_states = {} --cache of latest button states from player
local tracking_state = {} --tracks if a player's button state has remained 2 for more than X seconds
local cosmetic_cache = {} --tracks cosmetics for player
local cursor_cache = {} --tracks cursors currently spawned for player
local avatar_cache = {} --tracks the original player avatar for each player
local ui_cache = {} --tracks ui elements currently spawned for player
local map_elements = {} --tracks map elements currently spawned for player
local ui_update = {} --contains data on any actively sliding/moving UI elements
local online_players = {} --contains a table of all online players for excluding elements
local cursor_tick = 0 --keeps cursor from being moved too quickly

-- HELPER FUNCTIONS
-- A variety of simple functions used for repetitive calculations and adjustments

--purpose: helper function for fixOffsets
local function round_fraction(value, denominator)
    local int_part = math.floor(value)
    local decimal = value - int_part
    local n = math.floor(decimal * denominator + 0.5)
    return int_part, n / denominator
end

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

--purpose: converts h/v offsets to x/y offsets for UIs
local function convertOffsets(horizontalOffset,verticalOffset,Z)
    local xoffset = ((2 * -verticalOffset + horizontalOffset) / 64)+(Z/2)
    local yoffset = ((2 * -verticalOffset - horizontalOffset) / 64)+(Z/2)
    return xoffset,yoffset
end 

--purpose: adjusts offsets for UIs so they do not jitter
local function fixOffsets(a, b)
    -- Step 1: Round both decimals to nearest fraction of 32
    local a_int, a_dec = round_fraction(a, 32)
    local b_int, b_dec = round_fraction(b, 32)

    -- Step 2: Adjust the difference between decimal parts
    local diff = math.abs(a_dec - b_dec)
    if diff < 1 then
        -- Round diff to nearest fraction of 16
        local diff_adj = math.floor(diff * 16 + 0.5) / 16
        -- Set b_dec so the difference is now diff_adj, preserving the original ordering
        if a_dec >= b_dec then
            b_dec = a_dec - diff_adj
        else
            b_dec = a_dec + diff_adj
        end
        -- Clamp b_dec to [0, 1)
        if b_dec < 0 then b_dec = 0 end
        if b_dec >= 1 then b_dec = 1 - (1/32) end -- avoid rolling over
    end

    local a_final = a_int + a_dec
    local b_final = b_int + b_dec
    return a_final, b_final
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

-- ASSET PROVISION
-- Some of these assets don't load properly unless provided to player when they join
Net:on("player_join", function(event)
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_compressed.png")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_wide.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_gradient.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_thick.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_battle.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_thin.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_tiny.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_compressed.animation")
    Net.provide_asset_for_player(event.player_id, "/server/assets/net-games/fonts_dark_compressed.png")

end)

-- Try a handful of possible EO/Net APIs to move a player without hard-crashing
local function try_move_player(player_id, area_id, x, y, z)
  -- 1) transfer_player(player_id, area_id, x, y, z)
  local ok = pcall(function()
    if Net.transfer_player then
      Net.transfer_player(player_id, area_id, x, y, z)
    end
  end)
  if ok and Net.transfer_player then return true end

  -- 2) transfer_player(player_id, area_id, warp_in, x, y, z) (some forks use warp_in bool)
  ok = pcall(function()
    if Net.transfer_player then
      Net.transfer_player(player_id, area_id, false, x, y, z)
    end
  end)
  if ok and Net.transfer_player then return true end

  -- 3) move_player(player_id, x, y, z)
  ok = pcall(function()
    if Net.move_player then
      Net.move_player(player_id, x, y, z)
    end
  end)
  if ok and Net.move_player then return true end

  -- 4) set_player_position(player_id, x, y, z)
  ok = pcall(function()
    if Net.set_player_position then
      Net.set_player_position(player_id, x, y, z)
    end
  end)
  if ok and Net.set_player_position then return true end

  return false
end

-- Try common APIs to animate the player
local function try_animate_player(player_id, anim_state)
  -- 1) animate_player_properties(player_id, keyframes)
  local ok = pcall(function()
    if Net.animate_player_properties then
      local keyframes = {
        { properties = { { property = "Animation", value = anim_state } }, duration = 0 }
      }
      Net.animate_player_properties(player_id, keyframes)
    end
  end)
  if ok and Net.animate_player_properties then return true end

  -- 2) set_player_animation(player_id, anim_state)
  ok = pcall(function()
    if Net.set_player_animation then
      Net.set_player_animation(player_id, anim_state)
    end
  end)
  if ok and Net.set_player_animation then return true end

  return false
end


-- Move the frozen player (Simon Says uses this after fading to black)
function frame.move_frozen_player(player_id, x, y, z)
  return async(function()
    local area_id = Net.get_player_area(player_id)
    try_move_player(player_id, area_id, x, y, z)
    await(Async.sleep(0)) -- yields nicely for callers doing await(...)
  end)
end

-- Animate the frozen player
function frame.animate_frozen_player(player_id, anim_state)
  return async(function()
    try_animate_player(player_id, anim_state)
    await(Async.sleep(0))
  end)
end



-- PLAYER FUNCTIONS
-- Functons used to interact with the player and the framework 

--purpose: show a texture as a cosmetic on a player's avatar
function frame.set_cosmetic(cosmetic_id,player_id,texture,animation,state,x,y,visible,player_xoffset,player_yoffset)
    return async(function ()
    --safety checks
    if cosmetic_id == nil or animation == nil or state == nil or player_id == nil or texture == nil or x == nil or y == nil then
        print("[games] One or more required arguments is missing for set_cosmetic()")
        return
    end
    local visibility = true
    if visible == false then
        visibility = false
    end 
    if not cosmetic_cache[player_id] then 
        cosmetic_cache[player_id] = {}
    end
    if cosmetic_cache[player_id][cosmetic_id] then
        print("[games] Player already has cosmetic named '"..cosmetic_id.."'.")
        return 
    end 
    
    --draw sprite on player
    Net.provide_asset_for_player(player_id, texture)
    Net.provide_asset_for_player(player_id, animation)
    Net.player_alloc_sprite(player_id, cosmetic_id, {texture_path = texture, anim_path = animation, anim_state = state})
    local p_xoffset = 0
    local p_yoffset = 0

    if player_xoffset then 
        p_xoffset = player_xoffset
    end 
    if player_yoffset then 
        p_yoffset = player_yoffset
    end 

    Net.player_draw_sprite(player_id, cosmetic_id,
    {
        id = cosmetic_id .. "_obj",
        x = (x+120+p_xoffset)*2, 
        y = (y+80+p_yoffset)*2,
        sx = 2,
        sy = 2,
        anim_state = state
    })

    --spawn bot on player 
    if not last_position_cache[player_id] then
        last_position_cache[player_id] = {}
    end 
local area_id =
  last_position_cache[player_id]["area"]
  or Net.get_player_area(player_id)

    local position = Net.get_player_position(player_id)
    local xoffset,yoffset = convertOffsets(x*-1,y*-1,position.z+3)
    local xoffset,yoffset = fixOffsets(xoffset,yoffset)

    --add cosmetic to cache 
    cosmetic_cache[player_id][cosmetic_id] = {id=cosmetic_id,texture=texture,x=xoffset,y=yoffset,visibility=visibility,animation=animation,state=state,spritex=(x+120+p_xoffset)*2,spritey=(y+80+p_yoffset)*2}

    Net.create_bot(cosmetic_id.."_"..player_id, { area_id=area_id, warp_in=false, texture_path=texture, animation_path=animation, animation=state, x=position.x+xoffset, y=position.y+yoffset, z=position.z+3, solid=false})
    --hide bot from player (since we show it the cosmetic with a sprite)
    Net.exclude_actor_for_player(player_id,cosmetic_id.."_"..player_id)

    end)
end 

--purpose: remove a player's existing cosmetic
function frame.remove_cosmetic(cosmetic_id,player_id)
    if not cosmetic_cache[player_id] then 
        print("[games] Player has no cosmetics.")
        return
    end
    if not cosmetic_cache[player_id][cosmetic_id] then
        print("[games] Player has no cosmetic '"..cosmetic_id.."'.")
        return
    end 

    Net.remove_bot(cosmetic_id.."_"..player_id,false)
    Net.player_erase_sprite(player_id,cosmetic_id.."_obj")
    cosmetic_cache[player_id][cosmetic_id] = nil

end

-- MAP FUNCTIONS
-- Functions to add, animate, and remove objects based on map position (for mini-game elements on map, especially those visible to other players)

function frame.add_map_element(name,player_id,texture,animation,animation_state,X,Y,Z,exclude)
    
    --spawn map object
    
local area_id =
  (last_position_cache[player_id] and last_position_cache[player_id]["area"])
  or Net.get_player_area(player_id)

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
local area_id =
  (last_position_cache[player_id] and last_position_cache[player_id]["area"])
  or Net.get_player_area(player_id)

Net.transfer_bot(player_id.."-map-"..name, area_id, false, X, Y, Z)

end

--purpose: removes UI element from screen
function frame.remove_map_element(name,player_id)
    if Net.is_bot(player_id.."-map-"..name) then 
        map_elements[player_id][name] = nil
        Net.remove_bot(player_id.."-map-"..name,false)
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
            --print("Using existing sprite.")
        end
    end 
    
    if already_allocated == false then 
        --print("Creating new sprite.")
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

    Net.lock_player_input(player_id)
    --setup variables from provided options
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
end

--purpose: handles cursor movement logic
--usage: for framework only, use the Game:on("cursor_hover") to respond to cursor movements.
Net:on("cursor_move", function(event)
    local last_selection = cursor_cache[event.player_id]["current"]
    if event.button == "Move Left" or event.button == "Shoulder L" or event.button == "Move Up" then
        if last_selection == 1 then
            cursor_cache[event.player_id]["current"] = #cursor_cache[event.player_id]["selections"]
        else 
            cursor_cache[event.player_id]["current"] = last_selection - 1
        end 
    elseif event.button == "Move Right" or event.button == "Move Down" or event.button == "Shoulder R" then
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

-- NON-CODER EVENTS
-- The events in this section are framework management; "no touchie, no touch"! 

--Event handlers for framework to function
Net:on("player_join", function(event)
    
    table.insert(online_players, event.player_id)
    --reset all caches on join
    ui_cache[event.player_id] = {}
    cursor_cache[event.player_id] = {}
    avatar_cache[event.player_id] = {}

    --hide player exclusive cosmetics
    if next(cosmetic_cache) ~= nil then
        for player_id,cosmetics in next,cosmetic_cache do
            for cosmetic_id,cosmetic_data in next, cosmetics do 
                if cosmetic_data["visibility"] == false then
                    Net.exclude_actor_for_player(event.player_id, cosmetic_id.."_"..player_id)
                end
            end
        end 
    end 


end)

Net:on("player_disconnect", function(event)

    --clear all caches on disconnect
    cursor_cache[event.player_id] = nil
    avatar_cache[event.player_id] = nil
    ui_cache[event.player_id] = nil
    ui_update[event.player_id] = nil

    if Net.is_bot(event.player_id.."-double") then
        Net.remove_bot(event.player_id.."-double",false)
    end 
    if Net.is_bot(event.player_id.."-camera") then
        Net.remove_bot(event.player_id.."-camera",false)
    end 
    for i,player in next,online_players do 
        if player == event.player_id then
            online_players[i] = nil
        end
    end 

    --remove cosmetics
    if next(cosmetic_cache) ~= nil then
        for player_id,cosmetics in next,cosmetic_cache do
            if player_id == event.player_id then
                for cosmetic_id,cosmetic_data in next, cosmetics do 
                    Net.remove_bot(cosmetic_id.."_"..player_id,false)
                    cosmetic_cache[player_id] = nil 
                end
            end 
        end 
    end 


end)

local tick_gap = 6

Net:on("tick", function(event)

    --manages emitting state = 4 if player is using a button to scroll
    for player_id,buttons in next,button_states do
        if not tracking_state[player_id] then
            tracking_state[player_id] = {}
        end
        for name,state in next,buttons do
            if not tracking_state[player_id][name] then 
                tracking_state[player_id][name] = {}
                tracking_state[player_id][name]["tracked"] = 0
            end 
            if state == 2 then
                if tracking_state[player_id][name]["tracked"] == 0 then
                    tracking_state[player_id][name]["elapsed"] = 0
                    tracking_state[player_id][name]["tracked"] = 1
                else
                    tracking_state[player_id][name]["elapsed"] = event.delta_time + tracking_state[player_id][name]["elapsed"]
                end 
                if tracking_state[player_id][name]["elapsed"] > .3 and tracking_state[player_id][name]["tracked"] == 1 then
                    tracking_state[player_id][name]["elapsed"] = 0
                    Net:emit("virtual_input",{player_id = player_id,events={{state=4,name=name}}})
                    tracking_state[player_id][name]["tracked"] = 2
                elseif tracking_state[player_id][name]["elapsed"] > .1 and tracking_state[player_id][name]["tracked"] == 2 then
                    tracking_state[player_id][name]["elapsed"] = 0
                    Net:emit("virtual_input",{player_id = player_id,events={{state=4,name=name}}})
                end 
            else 
                tracking_state[player_id][name]["tracked"] = 0
                tracking_state[player_id][name]["elapsed"] = 0
            end 
        end
    end        

end)

--purpose: logic to check if cursor is active and emit corresponding events
Net:on("virtual_input", function(event)

    --move this code to check button presses every tick 
    if cursor_cache[event.player_id] ~= nil then
        local cursor = cursor_cache[event.player_id]
        local direction = cursor["movement"]
        for i,button in next,event.events do
            if ((button.name == "Move Down" or button.name == "Move Up") and direction=="vertical" and (button.state==1 or button.state==4)) or
            ((button.name == "Move Left" or button.name == "Move Right") and direction=="horizontal" and (button.state==1 or button.state==4)) or
            ((button.name == "Shoulder L" or button.name == "Shoulder R") and direction=="shoulder" and (button.state==1 or button.state==4)) then
                Net:emit("cursor_move", {player_id = event.player_id, cursor = cursor["name"], selection = cursor["current"], button = button.name})
            --if A button emit selection
            elseif (button.name == "Interact" or button.name == "Confirm") and button.state==1 then
                -- Some systems set cursor_cache without selections (or clear selections during transitions).
                -- Guard so dialogue/other virtual_input users can't crash menu selection logic.
                local cc = cursor_cache[event.player_id]
                local selections = cc and cc.selections
                local idx = cc and cc.current

                if selections and idx and selections[idx] and selections[idx].name then
                    Net:emit("cursor_selection", {
                        player_id = event.player_id,
                        cursor = cc.name,
                        selection = selections[idx].name
                    })
                else
                    -- Optional debug (leave off if you don't want spam)
                    -- print("[framework] cursor_selection ignored (missing selections/current)")
                end
            end

        end
    end
end)

Net:on("player_move", function(event)

    --update cosmetic position
    if cosmetic_cache[event.player_id] ~= nil then
        for cosmetic_id,cosmetic_data in next,cosmetic_cache[event.player_id] do
            local bot_position = Net.get_bot_position(cosmetic_id.."_"..event.player_id)
            --local xoffset,yoffset = convertOffsets(cosmetic_data["x"]*-1,cosmetic_data["y"]*-1,event.z+3)
            --local xoffset,yoffset = fixOffsets(xoffset,yoffset)
            local keyframes = {{properties={{property="Animation",value=cosmetic_data["state"]},{property="X",ease="Linear",value=bot_position.x},{property="Y",ease="Linear",value=bot_position.y},{property="Z",ease="Linear",value=bot_position.z}},duration=0}}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=cosmetic_data["state"]},{property="X",ease="Linear",value=event.x + cosmetic_data["x"]},{property="Y",ease="Linear",value=event.y + cosmetic_data["y"]},{property="Z",ease="Linear",value=event.z+3}},duration=.1}
            Net.move_bot(cosmetic_id.."_"..event.player_id,event.x+cosmetic_data["x"],event.y+cosmetic_data["y"],event.z+3)
            Net.animate_bot_properties(cosmetic_id.."_"..event.player_id, keyframes)
            Net.animate_bot(cosmetic_id.."_"..event.player_id,cosmetic_data["state"],true)
        end
    end
end)

Net:on("player_area_transfer", function(event)
    --update cache position
    if not last_position_cache[event.player_id] then
        last_position_cache[event.player_id] = {}
    end

    last_position_cache[event.player_id]["area"] = Net.get_player_area(event.player_id)
    --transfer cosmetics
    if next(cosmetic_cache) ~= nil then
        for player_id,cosmetics in next,cosmetic_cache do
            if player_id == event.player_id then
                for cosmetic_id,cosmetic_data in next, cosmetics do 
                    Net.transfer_bot(cosmetic_id.."_"..player_id,last_position_cache[event.player_id]["area"],false)
                end
            end 
        end 
    end 
end)

Net:on("virtual_input", function(event) 
    --pass inputs to cache
    if not button_states[event.player_id] then
        button_states[event.player_id] = {}
    end 
    for i,button in next,event.events do
        button_states[event.player_id][button.name] = button.state
    end

end)

-- Whatcha doin'? If you're here you must be a coder, or at least interesting in coding.
-- You should help out on the Discord. There's only a few of us that can actually code. 
-- Seriously, stop reading this and come help! For real. Please. I'm begging you. 

return frame