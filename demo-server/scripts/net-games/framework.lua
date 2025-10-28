--[[
* ---------------------------------------------------------- *
      Net Games (framework) by Indiana - Version 0.04
	     https://github.com/indianajson/net-games/   
* ---------------------------------------------------------- *
]]--

--[[

ROAD MAP
    - Add detach_camera() for liberation mission style pan-able camera
    - Move originY on animations to keep double on same z for visuals 

]]--

local frame = {} 
local movement_queue = {}
frozen = {}
local last_position_cache = {}
stasis_cache = {}
cursor_cache = {}
text_cache = {}
countdown_cache = {}
timer_cache = {}
avatar_cache = {}
framework_active = {}
local player_stopped = {}
ui_elements = {}
map_elements = {}
local ui_update = {}
local countdown_update = {}
local timer_update = {}
local track_player = {}
local online_players = {}
local tick_gap = 4
local tick_gap2 = 6
local previous_tick = 0
local previous_tick2 = 0

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


--purpose: converts h/v offsets to x/y offsets for UIs
--status: add code to shift offsets so that 0,0 is upper left (not center)
local function convertOffsets(horizontalOffset,verticalOffset,Z)
    -- 0,0 used to be centered under player's feet, but we're moving it to upper left with this specific offset
    local horizontalOffset = horizontalOffset - 120
    local verticalOffset = 80 - verticalOffset
    local xoffset = 50 + (Z/2) + ((2 * -verticalOffset + horizontalOffset) / 64)
    local yoffset = 50 + (Z/2) + ((2 * -verticalOffset - horizontalOffset) / 64)
    return xoffset,yoffset
end 

--purpose: change originY in animations for stunt double so we can put them far enough away to not be interacted with by the player despite being on the same Z
function adjustOriginy(fileContent)
    local result = {}
    
    for line in fileContent:gmatch("[^\r\n]+") do
        
        if line:find('originy="') then
            print(line)
            local startPos = line:find('originy="') + 9
            local endPos = line:find('"', startPos)
            
            if startPos and endPos then
                local numStr = line:sub(startPos, endPos - 1)
                local num = tonumber(numStr)
                
                if num then
                    local newLine = line:sub(1, startPos - 1) .. 
                                   tostring(num + 40) .. 
                                   line:sub(endPos)
                    table.insert(result, newLine)
                    print(newLine)
                else
                    table.insert(result, line)
                end
            else
                table.insert(result, line)
            end
        else
            table.insert(result, line)
        end
    end
    
    return table.concat(result, "\n")
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

--purpose: converts Net.get_bot_direction() from name to initials used by animations
local function simple_direction(direction) 
    if direction == "Up Left" then
        return "UL"
    elseif direction == "Up Right" then
        return "UL"
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

-- PLAYER FUNCTIONS
-- Functons used to interact with the player and the net-games framework 

--purpose: configures the stunt double bot used by all functions. 
--usage: must be activated for player before using any other framework function
function frame.activate_framework(player_id)
    local activate = false
    if framework_active[player_id] == nil then 
        activate = true 
    elseif framework_active[player_id] == false then
        activate = true 
    end 

    if activate == true then 
        local position = Net.get_player_position(player_id)
        local area_id = Net.get_player_area(player_id)
        local avatar = Net.get_player_avatar(player_id)
        local direction = Net.get_player_direction(player_id)
        local empty_texture = "/server/assets/net-games/empty.png"
        local empty_animation = "/server/assets/net-games/empty.animation"
        -- cache the player's avatar
        avatar_cache[player_id]["texture"] = avatar.texture_path
        avatar_cache[player_id]["animation"] = avatar.animation_path
        -- adjust originY in animation file
        -- disabled as not currently working
        --local fixedOrigin = adjustOriginy(Net.read_asset(avatar.animation_path))
        --local fixedOrigin = Net.read_asset(avatar.animation_path)
        --Net.update_asset(avatar.animation_path.."-fixed", fixedOrigin)
        avatar_cache[player_id]["animation-fixed"] = avatar.animation_path
        -- create stunt double
        Net.create_bot(player_id.."-double", { area_id=area_id, warp_in=false, texture_path=avatar.texture_path, animation_path=avatar.animation_path, x=position.x+0.001+.5, y=position.y+0.001+.5, z=position.z+1, direction=direction, solid=true})
        -- hide player
        Net.set_player_avatar(player_id, empty_texture, empty_animation)
        -- create camera holder
        Net.create_bot(player_id.."-camera", { area_id=area_id, warp_in=false, texture_path=empty_texture, animation_path=empty_animation, x=position.x+.5, y=position.y+.5, z=position.z+1, direction=direction, solid=false})
        -- track camera to "camera" bot
        Net.track_with_player_camera(player_id, player_id.."-camera")
        framework_active[player_id] = true
    else
        print("[games] Player "..player_id.." is already in the framework.")
    end
end

--purpose: removes the stunt double bot used by the framework. 
--usage: run when you're done using the framework for that player (to save server resources) 
--status: Re-test bot removal code
function frame.deactivate_framework(player_id)
    return async(function ()
    if framework_active[player_id] ~= nil then if framework_active[player_id] == true then 
        Net.lock_player_input(player_id)
        framework_active[player_id] = false
        local position = Net.get_bot_position(player_id.."-double") 
        local direction = Net.get_bot_direction(player_id.."-double")
        Net.teleport_player(player_id, false, position.x+0.001-.5, position.y+0.001-.5, position.z-1, direction)
        --this updates last player position to stasis so a movement isn't triggered on teleport
        if not last_position_cache[player_id] then 
            last_position_cache[player_id] = {}
        end
        last_position_cache[player_id]["x"] = tonumber(position.x+0.001-.5)
        last_position_cache[player_id]["y"] = tonumber(position.y+0.001-.5)
        last_position_cache[player_id]["z"] = tonumber(position.z-1)

        Net.set_player_avatar(player_id, avatar_cache[player_id]["texture"], avatar_cache[player_id]["animation"])
        movement_queue[player_id] = nil
        Net.remove_bot(player_id.."-double")
        Net.remove_bot(player_id.."-camera")

        --remove UIs
        if ui_elements[player_id] ~= nil then
            for name,element in next,ui_elements[player_id] do
                Net.remove_bot(element["id"])
            end
            ui_elements[player_id] = nil
            ui_update[player_id] = nil
        end

        --remove text
        if text_cache[player_id] ~= nil then for i,label in next,text_cache[player_id] do
            for i,letter in next,label["letters"] do 
                Net.remove_bot(player_id.."-text-"..label["name"].."-"..tostring(i))
            end
        end 
            text_cache[player_id] = nil
        end

        --remove countdowns
        if countdown_cache[player_id] ~= nil then 
            local clockpositions = {"m1","m2","d","s1","s2"}
            for i,clockposition in next,clockpositions do 
                Net.remove_bot(player_id.."-countdown-"..clockposition)
            end
            countdown_cache[player_id] = nil
            countdown_update[player_id] = nil
        end

        --remove timers
        if timer_cache[player_id] ~= nil then 
            local clockpositions = {"m1","m2","d","s1","s2"}
            for i,clockposition in next,clockpositions do 
                Net.remove_bot(player_id.."-timer-"..clockposition)
            end
            timer_cache[player_id] = nil
            timer_update[player_id] = nil
        end

        Net.unlock_player_camera(player_id)
        Net.track_with_player_camera(player_id,player_id)
        Net.unlock_player_input(player_id)
        frozen[player_id] = false
        framework_active[player_id] = false

    else 
        print("[games] Deactivate failed, player is not within the framework.")
    end
    end
    end)
end

--purpose: freezes players movement while preserving access to inputs 
--usage: call to initiate stationary mini-game or UI interactions
function frame.freeze_player(player_id)
    return async(function ()
    if frozen[player_id] ~= nil then
        if frozen[player_id] ~= true then
            Net.lock_player_input(player_id)
            --get necessary data from player
            local area_id = last_position_cache[player_id]["area"]
            if stasis_cache[area_id] == nil then
                print("[games] "..area_id..".tmx didn't have a Stasis value. Freeze failed!")
                return
            end 
            frozen[player_id] = true 

            --teleport to stasis
            Net.teleport_player(player_id, false, stasis_cache[area_id]["x"]+.5, stasis_cache[area_id]["y"]+.5, stasis_cache[area_id]["z"])

            local keyframes = {{properties={{property="Animation",value="IDLE_"..last_position_cache[player_id]["d"]}},duration=0}}
            Net.animate_bot(player_id.."-double", "IDLE_"..last_position_cache[player_id]["d"], true)
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
        end 
    end 
    end)
end

--purpose: set the stunt double's avatar to another texture/animation
function frame.set_player_avatar(player_id,texture,animation)
    Net.set_bot_avatar(player_id.."-double", texture, animation)
end 

--purpose: changes stunt double back to player's default avatar
function frame.reset_player_avatar(player_id)
    Net.set_bot_avatar(player_id.."-double", avatar_cache[player_id]["texture"], avatar_cache[player_id]["animation-fixed"])
end 

--purpose: releases player from freeze at the end of mini-game or non-standard UI interactions 
--usage: call to end a mini-games or non-standard UI interactions
function frame.unfreeze_player(player_id)
    if frozen[player_id] ~= nil then
        if Net.is_bot(player_id.."-double") and frozen[player_id] == true then
            Net.lock_player_input(player_id)
            local position = Net.get_bot_position(player_id.."-double") 
            local direction = Net.get_bot_direction(player_id.."-double")
            Net.teleport_player(player_id, false, position.x+0.001-.5, position.y+0.001-.5, position.z-1, direction)
            --this updates last player position to stasis so a movement isn't triggered on teleport
            if not last_position_cache[player_id] then 
                last_position_cache[player_id] = {}
            end
            last_position_cache[player_id]["x"] = tonumber(position.x+0.001-.5)
            last_position_cache[player_id]["y"] = tonumber(position.y+0.001-.5)
            last_position_cache[player_id]["z"] = tonumber(position.z-1)
            frozen[player_id] = false 
            Net.unlock_player_input(player_id)
        else 
            print("[games] You have to freeze the player before you thaw the player, did you even read the recipe?")
        end
    else
        print("[games] You can't unfreeze a player who was never frozen, who do you think you are, Chipotle?")
    end
end

--purpose: moves a frozen player from current location to specific cordinates without animation.
function frame.move_frozen_player(player_id,X,Y,Z)
    return async(function ()
    local area_id = last_position_cache[player_id]["area"]
    Net.transfer_bot(player_id.."-double", area_id, false, X+.5, Y+.5, Z+1)
    end)
end

--purpose: moves a frozen player from current location to specific cordinates with walking animation. 
--status: RE-TEST
function frame.walk_frozen_player(player_id,X,Y,Z,duration,wait)
    return async(function ()
        local position = Net.get_bot_position(player_id.."-double") 
        local keyframes = {{properties={{property="X",ease="Linear",value=position.x},{property="Y",ease="Linear",value=position.y},{property="Z",ease="Linear",value=position.z}},duration=0}}
        keyframes[#keyframes+1] = {properties={{property="X",ease="Linear",value=X+.5},{property="Y",ease="Linear",value=Y+.5},{property="Z",ease="Linear",value=Z+1}},duration=duration}
        Net.move_bot(player_id.."-double",X+.5,Y+.5,Z+1)
        --Net.animate_bot_properties(player_id.."-double", keyframes)
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

--purpose: returns bot_id of player's frozen avatar
--usage: useful for complex animation control over frozen avatars
function frame.get_frozen_player_id(player_id)
    if frozen[player_id] ~= nil then
        if Net.is_bot(player_id.."-double") and frozen[player_id] == true then
            return player_id.."-double"
        else 
            print("[games] Don't become a bouncer... You can't ID a non-frozen player.")
        end
    else
        print("[games] Did you just try to ID a player who was never frozen? Sigh.")
    end

end

-- CAMERA FUNCTIONS

--purpose: moves camera instantly to specific cordinates without animation.
--status: TEST IF TEXT, COUNT DOWN, and TIMER MOVES WITH CAMERA
function frame.set_camera_position(player_id,X,Y,Z)
    track_player[player_id] = false
    --move camera and UIs for player.

    --can we simple transfer bots with the camera tracking them and then use the UI xoffset and yoffsets?
    local area_id = last_position_cache[player_id]["area"]
    Net.transfer_bot(player_id.."-camera", area_id, false, X+.5, Y+.5, Z+1)

    if ui_elements[player_id] ~= nil then for name,element in next,ui_elements[player_id] do
        local newx = X + element["xoffset"]
        local newy = Y + element["yoffset"]
        Net.transfer_bot(player_id.."-ui-"..element["name"], area_id, false, newx, newy, element["z"])
    end
    end
        --UNTESTED: not sure if elements below move properly 

    --update text position
    if text_cache[player_id] ~= nil then for i,label in next,text_cache[player_id] do
        for i,letter in next,label["letters"] do 
            local newx = X + letter["xoffset"]
            local newy = Y + letter["yoffset"]
            Net.transfer_bot(player_id.."-text-"..label["name"].."-"..tostring(i), area_id, false, newx, newy, label["z"])
        end
    end 
    end

    --update countdown position
    if countdown_cache[player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            local newx = X + countdown_cache[player_id][clockposition.."_xoffset"]
            local newy = Y + countdown_cache[player_id][clockposition.."_xoffset"]
            Net.transfer_bot(player_id.."-countdown-"..clockposition,area_id,false,newx, newy,countdown_cache[player_id]["z"])
        end
    end

    --update timer position
    if timer_cache[player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            local newx = X + timer_cache[player_id][clockposition.."_xoffset"]
            local newy = Y + timer_cache[player_id][clockposition.."_xoffset"]
            Net.transfer_bot(player_id.."-timer-"..clockposition,area_id,false,newx, newy,timer_cache[player_id]["z"])
        end
    end

end

--purpose: track camera to stunt double
--status: TEST IF TEXT, COUNT DOWN, and TIMER RESET WITH CAMERA
function frame.reset_camera_position(player_id)
    --move camera to stunt double
    track_player[player_id] = true
    local area_id = last_position_cache[player_id]["area"]
    local position = Net.get_bot_position(player_id.."-double") 
    Net.transfer_bot(player_id.."-camera", area_id, false, position.x, position.y, position.z)
    --move UIs to stunt double
    if ui_elements[player_id] ~= nil then for name,element in next,ui_elements[player_id] do
        local newx = position.x + element["xoffset"]
        local newy = position.y + element["yoffset"]
        Net.transfer_bot(player_id.."-ui-"..element["name"], area_id, false, newx, newy, element["z"])
    end
    end

    --UNTESTED: not sure if elements below move properly 

    --update text
    if text_cache[player_id] ~= nil then for i,label in next,text_cache[player_id] do
        for i,letter in next,label["letters"] do 
            local newx = position.x + letter["xoffset"]
            local newy = position.y + letter["yoffset"]
            Net.transfer_bot(player_id.."-text-"..label["name"].."-"..tostring(i), area_id, false, newx, newy, label["z"])
        end
    end 
    end

    --update countdown position
    if countdown_cache[player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            local newx = position.x + countdown_cache[player_id][clockposition.."_xoffset"]
            local newy = position.y + countdown_cache[player_id][clockposition.."_xoffset"]
            Net.transfer_bot(player_id.."-countdown-"..clockposition,area_id,false,newx, newy,countdown_cache[player_id]["z"])
        end
    end

    --update timer position
    if timer_cache[player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            local newx = position.x + timer_cache[player_id][clockposition.."_xoffset"]
            local newy = position.y + timer_cache[player_id][clockposition.."_xoffset"]
            Net.transfer_bot(player_id.."-timer-"..clockposition,area_id,false,newx, newy,timer_cache[player_id]["z"])
        end
    end


end


--purpose: Linear slide camera to specific cordinates over duration. 
--status: TEST
function frame.slide_camera(player_id,x,y,duration)
--needs to move both camera and UIs using a linear animation
    track_player[player_id] = false
    --move camera and UIs for player.

    local area_id = last_position_cache[player_id]["area"]

    --move camera 
    local old_position = Net.get_bot_position(player_id.."-camera") 
    local keyframes = {{properties={{property="X",ease="Linear",value=old_position.x},{property="Y",ease="Linear",value=old_position.y}},duration=0}}
    keyframes[#keyframes+1] = {properties={{property="X",ease="Linear",value=x+.5},{property="Y",ease="Linear",value=y+.5}},duration=.1}
    Net.move_bot(player_id.."-camera",x,y,old_position.z)
    Net.animate_bot_properties(player_id.."-camera", keyframes)

    --move all active UI elements to track with camera
    if ui_elements[player_id] ~= nil then for name,element in next,ui_elements[player_id] do
        local old_position = Net.get_bot_position(player_id.."-ui-"..name)
        local newx = x + element["xoffset"]
        local newy = y + element["yoffset"]
        local keyframes = {{properties={{property="Animation",value=element["state"]},{property="X",ease="Linear",value=old_position.x},{property="Y",ease="Linear",value=old_position.y}},duration=0}}
        keyframes[#keyframes+1] = {properties={{property="Animation",value=element["state"]},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
        keyframes[#keyframes+1] = {properties={{property="Animation",value=element["state"]}},duration=0}
        Net.move_bot(player_id.."-ui-"..element["name"],newx,newy,element["z"])
        Net.animate_bot(player_id.."-ui-"..element["name"], element["state"], true)
        Net.animate_bot_properties(player_id.."-ui-"..element["name"], keyframes)
    end 
    end 
    --move all text elements to track with camera
    if text_cache[player_id] ~= nil then for i,label in next,text_cache[player_id] do
        for i,letter in next,label["letters"] do 
            local newposition = Net.get_bot_position(player_id.."-text-"..label["name"].."-"..tostring(i))
            local newx = x + letter["xoffset"]
            local newy = y + letter["yoffset"]
            local keyframes = {{properties={{property="Animation",value=letter["name"]},{property="X",ease="Linear",value=newposition.x},{property="Y",ease="Linear",value=newposition.y}},duration=0}}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=letter["name"]},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=letter["name"]}},duration=0}
            Net.move_bot(player_id.."-text-"..label["name"].."-"..tostring(i),newx,newy,label["z"]+100)
            Net.animate_bot(player_id.."-text-"..label["name"].."-"..tostring(i), letter["name"], true)
            Net.animate_bot_properties(player_id.."-text-"..label["name"].."-"..tostring(i), keyframes)
        end
    end 
    end
    
    --move all countdown elements to track with camera
    if countdown_cache[player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            local newposition = Net.get_bot_position(player_id.."-countdown-"..tostring(clockposition))
            local newx = x + countdown_cache[player_id][clockposition.."_xoffset"]
            local newy = y + countdown_cache[player_id][clockposition.."_yoffset"]
            local state = ""
            if clockposition == "d" then 
                state = "THICK_:"
            else 
                state = "THICK_"..countdown_cache[player_id][clockposition]
            end 
            local keyframes = {{properties={{property="Animation",value=state},{property="X",ease="Linear",value=newposition.x},{property="Y",ease="Linear",value=newposition.y}},duration=0}}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=state},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=state}},duration=0}
            Net.move_bot(player_id.."-countdown-"..clockposition,newx,newy,countdown_cache[player_id]["z"]+100)
            Net.animate_bot(player_id.."-countdown-"..clockposition, state, true)
            Net.animate_bot_properties(player_id.."-countdown-"..clockposition, keyframes)
        end
    end

    if timer_cache[player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            local newposition = Net.get_bot_position(player_id.."-timer-"..tostring(clockposition))
            local newx = x + timer_cache[player_id][clockposition.."_xoffset"]
            local newy = y + timer_cache[player_id][clockposition.."_yoffset"]
            local state = ""
            if clockposition == "d" then 
                state = "THICK_:"
            else 
                state = "THICK_"..timer_cache[player_id][clockposition]
            end 
            local keyframes = {{properties={{property="Animation",value=state},{property="X",ease="Linear",value=newposition.x},{property="Y",ease="Linear",value=newposition.y}},duration=0}}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=state},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=state}},duration=0}
            Net.move_bot(player_id.."-timer-"..clockposition,newx,newy,timer_cache[player_id]["z"]+100)
            Net.animate_bot(player_id.."-timer-"..clockposition, state, true)
            Net.animate_bot_properties(player_id.."-timer-"..clockposition, keyframes)
        end
    end




end
--purpose: Allows player to pan camera with D-Pad without player's avatar following and allows moving out of bounds (like liberation mission camera)
--status: WILL REQUIRE SPECIAL HANDLING FOR SMOOTH MOVEMENT
function frame.detach_camera(player_id)
    print("This function is not ready yet. Sorry.")
    frame.freeze_player(player_id)
    track_player[player_id] = false
end


-- MAP FUNCTIONS
-- Functions to add, animate, and remove objects based on map position (for mini-game elements on map, especially those visible to other players)

function frame.add_map_element(name,player_id,texture,animation,animation_state,X,Y,Z,exclude)
    
    --SPRITE NOTES
       --Your .animation file must have all of the standard animation states, but no frame data for them,
       --else your elements will flicker between your selected animation_state and the default run/walk for that direction.
       --See the /assets/net-games/text_cursor.animation if this doesn't make sense.

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
    map_elements[player_id][name]["Z"] = Z
    map_elements[player_id][name]["X"] = X
    map_elements[player_id][name]["Y"] = Y
end

function frame.change_map_element(name,player_id,animation_state,loop)
    if Net.is_bot(player_id.."-map-"..name) then
        Net.Net.animate_bot(player_id.."-map-"..name, animation_state,loop)

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
function frame.add_ui_element(name,player_id,texture,animation,animation_state,horizontalOffset,verticalOffset,Z,ScaleX, ScaleY)
    
    --SPRITE NOTES
       --Your .animation file must have all of the standard animation states, but no frame data for them,
       --else your UI will flicker between your selected animation_state and the default run/walk for that direction.
       --See the /assets/net-games/text_cursor.animation if this doesn't make sense.

    --POSITIONING NOTES 
       --Z is relative to UI not player Z for visual stacking purposes, which means 0 is base UI,
       --and 1 is above the main UI, and -1 is below the main UI, for element stacking. 
       --verticalOffset and horizontalOffset are relative to center of camera (not map)
       --camera size = 240 wide x 160 tall thus:
          --top left = 0,0
          --top middle = 120,0
          --top right = 240,0
          --middle = 120,80
          --bottom left = 0,160
          --bottom middle = 120,160
          --bottom right = 240,160

    --get position of camera 
    local cam_position = Net.get_bot_position(player_id.."-camera")
    local area_id = last_position_cache[player_id]["area"]
    local scaleX = 1.0
    local scaleY = 1.0
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
    --convert h/v offsets to x/y offsets
    local xoffset,yoffset = convertOffsets(horizontalOffset,verticalOffset,Z)
    local xoffset,yoffset = fixOffsets(xoffset,yoffset)
    --prep spawn point for UI
    local x = cam_position.x + xoffset
    local y = cam_position.y + yoffset
    local z = 100 + Z
    Net.create_bot(player_id.."-ui-"..name, { area_id=area_id, warp_in=false, texture_path=texture, animation_path=animation, animation=animation_state,x=x-.5, y=y-.5, z=z, solid=false})

    exclude_except_for(player_id,player_id.."-ui-"..name)

    local keyframes = {{properties={{property="Animation",value=animation_state}, {property="ScaleX",value=tonumber(scaleX)}, {property="ScaleY",value=tonumber(scaleY)}},duration=0}}
    Net.animate_bot(player_id.."-ui-"..name, animation_state, true)
    Net.animate_bot_properties(player_id.."-ui-"..name, keyframes)

    --includes UI element in UI cache for player so we can track to the camera bot 
    if ui_elements[player_id] == nil then
        ui_elements[player_id] = {}
    end 
    ui_elements[player_id][name] = {}
    ui_elements[player_id][name]["name"] = name
    ui_elements[player_id][name]["state"] = animation_state
    ui_elements[player_id][name]["id"] = player_id.."-ui-"..name    
    ui_elements[player_id][name]["z"] = z
    ui_elements[player_id][name]["xoffset"] = xoffset
    ui_elements[player_id][name]["yoffset"] = yoffset
end

--purpose: change the animation state of existing UI element
function frame.change_ui_element(name,player_id,animation_state,loop)
    -- if we force animation immediately jitter occurs while moving
    -- instead we queue visual change and see if a player_move occurs 
    -- within six ticks, if not then we adjust animation state via on:tick. 
    if Net.is_bot(player_id.."-ui-"..name) then
        ui_elements[player_id][name]["state"] = animation_state
        if ui_update[player_id] == nil then
            ui_update[player_id] = {}
        end
        --adds update to the queue table (ui_update) and
        --appends previous tick so a full loop occurs for tick_gap2
        table.insert(ui_update[player_id], name.."|"..previous_tick2)
    else
        print("[games] Come on, "..name.." isn't a UI element for that player!")
    end 
end

--purpose: move existing UI element
function frame.move_ui_element(name,player_id,horizontalOffset,verticalOffset,Z)
    local cam_position = Net.get_bot_position(player_id.."-camera")
    local area_id = last_position_cache[player_id]["area"]
    local xoffset,yoffset = convertOffsets(horizontalOffset,verticalOffset,Z)
    local xoffset,yoffset = fixOffsets(xoffset,yoffset)
    local x = cam_position.x + xoffset
    local y = cam_position.y + yoffset
    local z = 100 + Z
    ui_elements[player_id][name]["xoffset"] = xoffset
    ui_elements[player_id][name]["yoffset"] = yoffset
    Net.transfer_bot(player_id.."-ui-"..name, area_id, false, x-.5, y-.5, z)
end

--purpose: slide an existing UI element across the screen over a specified duration
--STATUS: TEST
function frame.slide_ui_element(name,player_id,horizontalOffset,verticalOffset,duration)
    local cam_position = Net.get_bot_position(player_id.."-camera")
    local area_id = last_position_cache[player_id]["area"]
    local element = ui_elements[player_id][name]
    local xoffset,yoffset = convertOffsets(horizontalOffset,verticalOffset,cam_position.z-1)
    local xoffset,yoffset = fixOffsets(xoffset,yoffset)
    local x = cam_position.x + xoffset
    local y = cam_position.y + yoffset
    ui_elements[player_id][name]["xoffset"] = xoffset
    ui_elements[player_id][name]["yoffset"] = yoffset
    local old_position = Net.get_bot_position(player_id.."-ui-"..name)

    local keyframes = {{properties={{property="Animation",value=element["state"]},{property="X",ease="Linear",value=old_position.x},{property="Y",ease="Linear",value=old_position.y}},duration=0}}
    keyframes[#keyframes+1] = {properties={{property="Animation",value=element["state"]},{property="X",ease="Linear",value=x-.5},{property="Y",ease="Linear",value=y-.5}},duration=duration}
    keyframes[#keyframes+1] = {properties={{property="Animation",value=element["state"]}},duration=0}
    Net.move_bot(player_id.."-ui-"..element["name"],x,y,element["z"])
    Net.animate_bot(player_id.."-ui-"..element["name"], element["state"], true)
    Net.animate_bot_properties(player_id.."-ui-"..element["name"], keyframes)

end

--purpose: removes UI element from screen
function frame.remove_ui_element(name,player_id)
    if Net.is_bot(player_id.."-ui-"..name) then 
        ui_elements[player_id][name] = nil
        Net.remove_bot(player_id.."-ui-"..name)
    end
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
    local texture = options["texture"]
    local animation = options["animation"]
    local area_id = last_position_cache[player_id]["area"]
    if cursor_cache[player_id] ~= nil then if next(cursor_cache[player_id]) ~= nil then if cursor_cache[player_id] ~= {} then
        --print(cursor_cache[player_id])
        print("[games] You already got a cursor for that user, remove it first.") 
        return 
    end 
    end
    end 
    --add cursor to cache 
    cursor_cache[player_id] = {}
    cursor_cache[player_id] = options
    cursor_cache[player_id]["name"] = cursor_id
    local xoffset = 0
    local yoffset = 0
    for i,selection in next,cursor_cache[player_id]["selections"] do 
        --convert v/h to x/y offsets
        xoffset,yoffset = convertOffsets(selection["h"],selection["v"],tonumber(selection["z"]))
        xoffset,yoffset = fixOffsets(xoffset,yoffset)
        --add to cursor_cache
        cursor_cache[player_id]["selections"][i]["xoffset"] = xoffset
        cursor_cache[player_id]["selections"][i]["yoffset"] = yoffset
    end 
    local position = Net.get_bot_position(player_id.."-camera")
    --create bot and set initial cursor arrow in position cursor_cache[player_id]["selections"][1]
    local selection = cursor_cache[player_id]["selections"][1]
    Net.create_bot(player_id.."-cursor-"..cursor_id, { area_id=area_id, warp_in=false, texture_path=selection["texture"], animation_path=selection["animation"],animation=selection["state"], x=position.x+selection["xoffset"]-.5, y=position.y+selection["yoffset"]-.5, z=tonumber(selection["z"]+100), solid=false})
    exclude_except_for(player_id,player_id.."-cursor-"..cursor_id)
    --this tracks the index of the current selection
    cursor_cache[player_id]["current"] = 1
    --tracks timed lockout to avoid multiple accidental button presses 
    cursor_cache[player_id]["locked"] = false

end)
end

--purpose: removes a cursor and clears cursor_cache for player
function frame.remove_cursor(cursor_id,player_id)
    cursor_cache[player_id] = nil
    Net.remove_bot(player_id.."-cursor-"..cursor_id)
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
            if ((event.button == "D" or event.button == "U") and direction=="vertical") or
            ((event.button == "L" or event.button == "R") and direction=="horizontal") or
            (event.button == "LS" and direction=="shoulder") then
                Net:emit("cursor_move", {player_id = event.player_id, cursor = cursor["name"], selection = cursor["current"], button = event.button})
            --if A button emit selection
            elseif event.button == "A" then
                Net:emit("cursor_selection", {player_id = event.player_id,cursor = cursor["name"],selection = cursor_cache[event.player_id]["selections"][cursor["current"]]})
            end

            cursor_cache[event.player_id]["lock-tick"] = previous_tick2
            cursor_cache[event.player_id]["locked"] = true
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
    local area_id = last_position_cache[player_id]["area"]
    local position = Net.get_bot_position(event.player_id.."-camera")
    local selection = cursor_cache[event.player_id]["selections"][cursor_cache[event.player_id]["current"]]
    Net.transfer_bot(event.player_id.."-cursor-"..cursor_cache[event.player_id]["name"], area_id,false,position.x+selection["xoffset"],position.y+selection["yoffset"],selection["z"]+100)
    Net.animate_bot(event.player_id.."-cursor-"..cursor_cache[event.player_id]["name"], selection["state"], true)
    Net:emit("cursor_hover", {player_id = event.player_id,cursor = cursor_cache[event.player_id]["name"],selection = selection})

end)

-- TEXT FUNCTIONS
-- Display text on screen

local function font_width(letter)

    local widths = {
    ["SMALL_A"] = 5,
    ["SMALL_B"] = 5,
    ["SMALL_C"] = 4,
    ["SMALL_D"] = 5,
    ["SMALL_E"] = 5,
    ["SMALL_F"] = 5,
    ["SMALL_G"] = 5,
    ["SMALL_H"] = 5,
    ["SMALL_I"] = 3,
    ["SMALL_J"] = 5,
    ["SMALL_K"] = 4,
    ["SMALL_L"] = 5,
    ["SMALL_M"] = 5,
    ["SMALL_N"] = 4,
    ["SMALL_O"] = 5,
    ["SMALL_P"] = 5,
    ["SMALL_Q"] = 5,
    ["SMALL_R"] = 5,
    ["SMALL_S"] = 5,
    ["SMALL_T"] = 5,
    ["SMALL_U"] = 5,
    ["SMALL_V"] = 5,
    ["SMALL_W"] = 5,
    ["SMALL_X"] = 5,
    ["SMALL_Y"] = 5,
    ["SMALL_Z"] = 5,
    ["SMALL_LOWER_A"] = 4,
    ["SMALL_LOWER_B"] = 4,
    ["SMALL_LOWER_C"] = 4,
    ["SMALL_LOWER_D"] = 4,
    ["SMALL_LOWER_E"] = 4,
    ["SMALL_LOWER_F"] = 3,
    ["SMALL_LOWER_G"] = 4,
    ["SMALL_LOWER_H"] = 4,
    ["SMALL_LOWER_I"] = 5,
    ["SMALL_LOWER_J"] = 5,
    ["SMALL_LOWER_K"] = 4,
    ["SMALL_LOWER_L"] = 5,
    ["SMALL_LOWER_M"] = 5,
    ["SMALL_LOWER_N"] = 4,
    ["SMALL_LOWER_O"] = 4,
    ["SMALL_LOWER_P"] = 4,
    ["SMALL_LOWER_Q"] = 4,
    ["SMALL_LOWER_R"] = 4,
    ["SMALL_LOWER_S"] = 4,
    ["SMALL_LOWER_T"] = 4,
    ["SMALL_LOWER_U"] = 4,
    ["SMALL_LOWER_V"] = 4,
    ["SMALL_LOWER_W"] = 5,
    ["SMALL_LOWER_X"] = 4,
    ["SMALL_LOWER_Y"] = 4,
    ["SMALL_LOWER_Z"] = 4,
    ["SMALL_0"] = 4,
    ["SMALL_1"] = 2,
    ["SMALL_2"] = 5,
    ["SMALL_3"] = 4,
    ["SMALL_4"] = 4,
    ["SMALL_5"] = 4,
    ["SMALL_6"] = 4,
    ["SMALL_7"] = 4,
    ["SMALL_8"] = 4,
    ["SMALL_9"] = 4,
    ["SMALL_("] = 3,
    ["SMALL_)"] = 3,
    ["SMALL__"] = 4,
    ["SMALL_-"] = 3,
    ["SMALL_+"] = 3,
    ["SMALL_="] = 4,
    ["SMALL_\\"] = 5,
    ["SMALL_/"] = 5,
    ["SMALL_<"] = 3,
    ["SMALL_>"] = 3,
    ["SMALL_?"] = 3,
    ["SMALL_,"] = 4,
    ["SMALL_."] = 3,
    ["SMALL_!"] = 3,
    ["SMALL_@"] = 7,
    ["SMALL_#"] = 5,
    ["SMALL_$"] = 4,
    ["SMALL_%"] = 5,
    ["SMALL_^"] = 3,
    ["SMALL_&"] = 4,
    ["SMALL_*"] = 5,
    ["SMALL_'"] = 2,
    ["SMALL_QUOTE"] = 5,
    ["SMALL_:"] = 2,
    ["SMALL_;"] = 2,
    ["THICK_A"] = 6,
    ["THICK_B"] = 6,
    ["THICK_C"] = 6,
    ["THICK_D"] = 6,
    ["THICK_E"] = 6,
    ["THICK_F"] = 6,
    ["THICK_G"] = 6,
    ["THICK_H"] = 6,
    ["THICK_I"] = 6,
    ["THICK_J"] = 6,
    ["THICK_K"] = 6,
    ["THICK_L"] = 6,
    ["THICK_M"] = 6,
    ["THICK_N"] = 6,
    ["THICK_O"] = 6,
    ["THICK_P"] = 6,
    ["THICK_Q"] = 6,
    ["THICK_R"] = 6,
    ["THICK_S"] = 6,
    ["THICK_T"] = 6,
    ["THICK_U"] = 6,
    ["THICK_V"] = 6,
    ["THICK_W"] = 6,
    ["THICK_X"] = 6,
    ["THICK_Y"] = 6,
    ["THICK_Z"] = 6,
    ["THICK_LOWER_A"] = 6,
    ["THICK_LOWER_B"] = 6,
    ["THICK_LOWER_C"] = 6,
    ["THICK_LOWER_D"] = 6,
    ["THICK_LOWER_E"] = 6,
    ["THICK_LOWER_F"] = 6,
    ["THICK_LOWER_G"] = 6,
    ["THICK_LOWER_H"] = 6,
    ["THICK_LOWER_I"] = 6,
    ["THICK_LOWER_K"] = 6,
    ["THICK_LOWER_J"] = 6,
    ["THICK_LOWER_L"] = 6,
    ["THICK_LOWER_M"] = 6,
    ["THICK_LOWER_N"] = 6,
    ["THICK_LOWER_O"] = 6,
    ["THICK_LOWER_P"] = 6,
    ["THICK_LOWER_Q"] = 6,
    ["THICK_LOWER_R"] = 6,
    ["THICK_LOWER_S"] = 6,
    ["THICK_LOWER_T"] = 6,
    ["THICK_LOWER_U"] = 6,
    ["THICK_LOWER_V"] = 6,
    ["THICK_LOWER_W"] = 6,
    ["THICK_LOWER_X"] = 6,
    ["THICK_LOWER_Y"] = 6,
    ["THICK_LOWER_Z"] = 6,
    ["THICK_0"] = 6,
    ["THICK_1"] = 6,
    ["THICK_2"] = 6,
    ["THICK_3"] = 6,
    ["THICK_4"] = 6,
    ["THICK_5"] = 6,
    ["THICK_6"] = 6,
    ["THICK_7"] = 6,
    ["THICK_8"] = 6,
    ["THICK_9"] = 6,
    ["THICK_("] = 6,
    ["THICK_)"] = 6,
    ["THICK__"] = 6,
    ["THICK_-"] = 6,
    ["THICK_+"] = 6,
    ["THICK_="] = 6,
    ["THICK_\\"] = 6,
    ["THICK_/"] = 6,
    ["THICK_<"] = 6,
    ["THICK_>"] = 6,
    ["THICK_?"] = 6,
    ["THICK_,"] = 6,
    ["THICK_."] = 6,
    ["THICK_!"] = 6,
    ["THICK_@"] = 6,
    ["THICK_#"] = 7,
    ["THICK_$"] = 7,
    ["THICK_%"] = 7,
    ["THICK_^"] = 6,
    ["THICK_&"] = 7,
    ["THICK_*"] = 7,
    ["THICK_'"] = 6,
    ["THICK_QUOTE"] = 6,
    ["THICK_:"] = 6,
    ["THICK_;"] = 6,
    ["TINY_A"] = 5,
    ["TINY_B"] = 5,
    ["TINY_C"] = 5,
    ["TINY_D"] = 5,
    ["TINY_E"] = 5,
    ["TINY_F"] = 5,
    ["TINY_G"] = 5,
    ["TINY_H"] = 5,
    ["TINY_I"] = 5,
    ["TINY_J"] = 5,
    ["TINY_K"] = 5,
    ["TINY_L"] = 5,
    ["TINY_M"] = 5,
    ["TINY_N"] = 5,
    ["TINY_O"] = 5,
    ["TINY_P"] = 5,
    ["TINY_Q"] = 5,
    ["TINY_R"] = 5,
    ["TINY_S"] = 5,
    ["TINY_T"] = 5,
    ["TINY_U"] = 5,
    ["TINY_V"] = 5,
    ["TINY_W"] = 5,
    ["TINY_X"] = 5,
    ["TINY_Y"] = 5,
    ["TINY_Z"] = 5,
    ["TINY_LOWER_A"] = 5,
    ["TINY_LOWER_B"] = 5,
    ["TINY_LOWER_C"] = 5,
    ["TINY_LOWER_D"] = 5,
    ["TINY_LOWER_E"] = 5,
    ["TINY_LOWER_F"] = 5,
    ["TINY_LOWER_G"] = 5,
    ["TINY_LOWER_H"] = 5,
    ["TINY_LOWER_I"] = 5,
    ["TINY_LOWER_J"] = 5,
    ["TINY_LOWER_K"] = 5,
    ["TINY_LOWER_L"] = 5,
    ["TINY_LOWER_M"] = 5,
    ["TINY_LOWER_N"] = 5,
    ["TINY_LOWER_O"] = 5,
    ["TINY_LOWER_P"] = 5,
    ["TINY_LOWER_Q"] = 5,
    ["TINY_LOWER_R"] = 5,
    ["TINY_LOWER_S"] = 5,
    ["TINY_LOWER_T"] = 5,
    ["TINY_LOWER_U"] = 5,
    ["TINY_LOWER_V"] = 5,
    ["TINY_LOWER_W"] = 5,
    ["TINY_LOWER_X"] = 5,
    ["TINY_LOWER_Y"] = 5,
    ["TINY_LOWER_Z"] = 5,
    ["TINY_0"] = 5,
    ["TINY_1"] = 5,
    ["TINY_2"] = 5,
    ["TINY_3"] = 5,
    ["TINY_4"] = 5,
    ["TINY_5"] = 5,
    ["TINY_6"] = 5,
    ["TINY_7"] = 5,
    ["TINY_8"] = 5,
    ["TINY_9"] = 5,
    ["TINY_("] = 5,
    ["TINY_)"] = 5,
    ["TINY__"] = 5,
    ["TINY_-"] = 5,
    ["TINY_+"] = 5,
    ["TINY_="] = 5,
    ["TINY_\\"] = 5,
    ["TINY_/"] = 5,
    ["TINY_<"] = 5,
    ["TINY_>"] = 5,
    ["TINY_?"] = 5,
    ["TINY_,"] = 5,
    ["TINY_."] = 5,
    ["TINY_!"] = 5,
    ["TINY_@"] = 5,
    ["TINY_#"] = 5,
    ["TINY_$"] = 5,
    ["TINY_%"] = 5,
    ["TINY_^"] = 5,
    ["TINY_&"] = 5,
    ["TINY_*"] = 5,
    ["TINY_'"] = 5,
    ["TINY_QUOTE"] = 5,
    ["TINY_:"] = 5,
    ["TINY_;"] = 5,
    ["WIDE_A"] = 7,
    ["WIDE_B"] = 6,
    ["WIDE_C"] = 6,
    ["WIDE_D"] = 6,
    ["WIDE_E"] = 6,
    ["WIDE_F"] = 6,
    ["WIDE_G"] = 6,
    ["WIDE_H"] = 6,
    ["WIDE_I"] = 6,
    ["WIDE_J"] = 6,
    ["WIDE_K"] = 6,
    ["WIDE_L"] = 6,
    ["WIDE_M"] = 6,
    ["WIDE_N"] = 6,
    ["WIDE_O"] = 6,
    ["WIDE_P"] = 6,
    ["WIDE_Q"] = 7,
    ["WIDE_R"] = 6,
    ["WIDE_S"] = 6,
    ["WIDE_T"] = 6,
    ["WIDE_U"] = 6,
    ["WIDE_V"] = 6,
    ["WIDE_W"] = 6,
    ["WIDE_X"] = 6,
    ["WIDE_Y"] = 6,
    ["WIDE_Z"] = 6,
    ["WIDE_0"] = 6,
    ["WIDE_1"] = 6,
    ["WIDE_2"] = 6,
    ["WIDE_3"] = 6,
    ["WIDE_4"] = 6,
    ["WIDE_5"] = 6,
    ["WIDE_6"] = 6,
    ["WIDE_7"] = 6,
    ["WIDE_8"] = 6,
    ["WIDE_9"] = 6,
    ["WIDE_("] = 6,
    ["WIDE_)"] = 6,
    ["WIDE__"] = 6,
    ["WIDE_-"] = 6,
    ["WIDE_+"] = 6,
    ["WIDE_="] = 6,
    ["WIDE_\\"] = 6,
    ["WIDE_/"] = 6,
    ["WIDE_<"] = 6,
    ["WIDE_>"] = 6,
    ["WIDE_?"] = 6,
    ["WIDE_,"] = 6,
    ["WIDE_."] = 6,
    ["WIDE_!"] = 6,
    ["WIDE_@"] = 7,
    ["WIDE_#"] = 6,
    ["WIDE_$"] = 6,
    ["WIDE_%"] = 6,
    ["WIDE_^"] = 6,
    ["WIDE_&"] = 6,
    ["WIDE_*"] = 6,
    ["WIDE_'"] = 6,
    ["WIDE_QUOTE"] = 6,
    ["WIDE_:"] = 6,
    ["WIDE_;"] = 6,
    ["THIN_A"] = 7,
    ["THIN_B"] = 7,
    ["THIN_C"] = 7,
    ["THIN_D"] = 7,
    ["THIN_E"] = 7,
    ["THIN_F"] = 7,
    ["THIN_G"] = 7,
    ["THIN_H"] = 7,
    ["THIN_I"] = 7,
    ["THIN_J"] = 7,
    ["THIN_K"] = 7,
    ["THIN_L"] = 7,
    ["THIN_M"] = 7,
    ["THIN_N"] = 7,
    ["THIN_O"] = 7,
    ["THIN_P"] = 7,
    ["THIN_Q"] = 7,
    ["THIN_R"] = 7,
    ["THIN_S"] = 7,
    ["THIN_T"] = 7,
    ["THIN_U"] = 7,
    ["THIN_V"] = 7,
    ["THIN_W"] = 7,
    ["THIN_X"] = 7,
    ["THIN_Y"] = 7,
    ["THIN_Z"] = 7,
    ["THIN_:"] = 5,
    ["THIN_&"] = 7,
    ["THIN_'"] = 6,
    ["THIN_="] = 7,
    ["THIN_0"] = 7,
    ["THIN_1"] = 7,
    ["THIN_2"] = 7,
    ["THIN_3"] = 7,
    ["THIN_4"] = 7,
    ["THIN_5"] = 7,
    ["THIN_6"] = 7,
    ["THIN_7"] = 7,
    ["THIN_8"] = 7,
    ["THIN_9"] = 7,
    ["THIN_LOWER_A"] = 7,
    ["THIN_LOWER_B"] = 7,
    ["THIN_LOWER_C"] = 7,
    ["THIN_LOWER_D"] = 7,
    ["THIN_LOWER_E"] = 7,
    ["THIN_LOWER_F"] = 6,
    ["THIN_LOWER_G"] = 7,
    ["THIN_LOWER_H"] = 7,
    ["THIN_LOWER_I"] = 4,
    ["THIN_LOWER_J"] = 7,
    ["THIN_LOWER_K"] = 7,
    ["THIN_LOWER_L"] = 4,
    ["THIN_LOWER_M"] = 7,
    ["THIN_LOWER_N"] = 7,
    ["THIN_LOWER_O"] = 7,
    ["THIN_LOWER_P"] = 7,
    ["THIN_LOWER_Q"] = 7,
    ["THIN_LOWER_R"] = 6,
    ["THIN_LOWER_S"] = 7,
    ["THIN_LOWER_T"] = 7,
    ["THIN_LOWER_U"] = 7,
    ["THIN_LOWER_V"] = 7,
    ["THIN_LOWER_W"] = 7,
    ["THIN_LOWER_X"] = 7,
    ["THIN_LOWER_Y"] = 7,
    ["THIN_LOWER_Z"] = 7,
    ["THIN_-"] = 7,
    ["THIN_!"] = 4,
    ["THIN_/"] = 7,
    ["THIN_."] = 5,
    ["THIN_?"] = 7,
    ["THIN_,"] = 5,
    ["GRADIENT_TALL_0"] = 7,
    ["GRADIENT_TALL_1"] = 7,
    ["GRADIENT_TALL_2"] = 7,
    ["GRADIENT_TALL_3"] = 7,
    ["GRADIENT_TALL_4"] = 7,
    ["GRADIENT_TALL_5"] = 7,
    ["GRADIENT_TALL_6"] = 7,
    ["GRADIENT_TALL_7"] = 7,
    ["GRADIENT_TALL_8"] = 7,
    ["GRADIENT_TALL_9"] = 7,
    ["GRADIENT_TALL_S"] = 7,
    ["GRADIENT_TALL_:"] = 7,
    ["GRADIENT_0"] = 7,
    ["GRADIENT_1"] = 7,
    ["GRADIENT_2"] = 7,
    ["GRADIENT_3"] = 7,
    ["GRADIENT_4"] = 7,
    ["GRADIENT_5"] = 7,
    ["GRADIENT_6"] = 7,
    ["GRADIENT_7"] = 7,
    ["GRADIENT_8"] = 7,
    ["GRADIENT_9"] = 7,
    ["GRADIENT_GOLD_0"] = 7,
    ["GRADIENT_GOLD_1"] = 7,
    ["GRADIENT_GOLD_2"] = 7,
    ["GRADIENT_GOLD_3"] = 7,
    ["GRADIENT_GOLD_4"] = 7,
    ["GRADIENT_GOLD_5"] = 7,
    ["GRADIENT_GOLD_6"] = 7,
    ["GRADIENT_GOLD_7"] = 7,
    ["GRADIENT_GOLD_8"] = 7,
    ["GRADIENT_GOLD_9"] = 7,
    ["GRADIENT_GREEN_0"] = 7,
    ["GRADIENT_GREEN_1"] = 7,
    ["GRADIENT_GREEN_2"] = 7,
    ["GRADIENT_GREEN_3"] = 7,
    ["GRADIENT_GREEN_4"] = 7,
    ["GRADIENT_GREEN_5"] = 7,
    ["GRADIENT_GREEN_6"] = 7,
    ["GRADIENT_GREEN_7"] = 7,
    ["GRADIENT_GREEN_8"] = 7,
    ["GRADIENT_GREEN_9"] = 7,
    ["GRADIENT_ORANGE_0"] = 7,
    ["GRADIENT_ORANGE_1"] = 7,
    ["GRADIENT_ORANGE_2"] = 7,
    ["GRADIENT_ORANGE_3"] = 7,
    ["GRADIENT_ORANGE_4"] = 7,
    ["GRADIENT_ORANGE_5"] = 7,
    ["GRADIENT_ORANGE_6"] = 7,
    ["GRADIENT_ORANGE_7"] = 7,
    ["GRADIENT_ORANGE_8"] = 7,
    ["GRADIENT_ORANGE_9"] = 7,
    ["GRADIENT_ORANGE_+"] = 7,
    ["THICK_SP"] = 6,
    ["THICK_EX"] = 6,
    ["THICK_NM"] = 6,
    ["THIN_QUOTE"] = 7,
    ["THIN__"] = 7,
    ["THIN_$"] = 7,
    ["THIN_("] = 7,
    ["THIN_)"] = 7,
    ["THIN_["] = 7,
    ["THIN_]"] = 7,
    ["THIN_*"] = 7,
    ["THIN_~"] = 7,
    ["THIN_`"] = 7,
    ["THIN_^"] = 7,
    ["THIN_+"] = 7,
    ["THIN_#"] = 7,
    ["THIN_%"] = 7,
    ["THIN_@"] = 7,
    ["THIN_<"] = 7,
    ["THIN_>"] = 7,
    ["THIN_{"] = 7,
    ["THIN_}"] = 7,
    ["THIN_;"] = 5,
    ["BATTLE_A"] = 8,
    ["BATTLE_B"] = 8,
    ["BATTLE_C"] = 8,
    ["BATTLE_D"] = 8,
    ["BATTLE_E"] = 8,
    ["BATTLE_F"] = 8,
    ["BATTLE_G"] = 8,
    ["BATTLE_H"] = 8,
    ["BATTLE_I"] = 8,
    ["BATTLE_J"] = 8,
    ["BATTLE_K"] = 8,
    ["BATTLE_L"] = 8,
    ["BATTLE_M"] = 8,
    ["BATTLE_N"] = 8,
    ["BATTLE_O"] = 8,
    ["BATTLE_P"] = 8,
    ["BATTLE_Q"] = 8,
    ["BATTLE_R"] = 8,
    ["BATTLE_S"] = 8,
    ["BATTLE_T"] = 8,
    ["BATTLE_U"] = 8,
    ["BATTLE_V"] = 8,
    ["BATTLE_W"] = 8,
    ["BATTLE_X"] = 8,
    ["BATTLE_Y"] = 8,
    ["BATTLE_Z"] = 8,
    ["BATTLE__"] = 8,
    ["BATTLE_<"] = 8,
    ["BATTLE_>"] = 8,
    ["BATTLE_!"] = 8,
    ["BATTLE_0"] = 8,
    ["BATTLE_1"] = 8,
    ["BATTLE_2"] = 8,
    ["BATTLE_3"] = 8,
    ["BATTLE_4"] = 8,
    ["BATTLE_5"] = 8,
    ["BATTLE_6"] = 8,
    ["BATTLE_7"] = 8,
    ["BATTLE_8"] = 8,
    ["BATTLE_9"] = 8,
    ["BATTLE_ "] = 8,
    ["WIDE_ "] = 6,
    ["THIN_ "] = 6,
    ["SMALL_ "] = 6,
    ["THICK_ "] = 6,
    ["TINY_ "] = 5,
    ["THIN_LOWER_ "] = 6,
    ["SMALL_LOWER_ "] = 6,
    ["THICK_LOWER_ "] = 6,
    ["TINY_LOWER_ "] = 5,
    ["GRADIENT_ "] = 7,
    ["GRADIENT_TALL_ "] = 7,
    ["GRADIENT_GOLD_ "] = 7,
    ["GRADIENT_GREEN_ "] = 7,
    ["GRADIENT_ORANGE_ "] = 7,
    }

    if widths[letter] then
        return widths[letter]
    else 
        print(letter.." is not a valid letter. Do not pass go. Do not collect $200.")
        return false
    end
end 

--purpose: write text on screen based on position
--status: WORKING, spacing issue persists
--test reverse width analysis
function frame.write_text(text_id,player_id,font,color,text,horizontalOffset,verticalOffset,Z)

    local fonts = {"WIDE","BATTLE"} --contains letters and numbers
    local lowers = {"SMALL","THIN","THICK","TINY"} --contains _LOWER varient too
    local numbers = {"GRADIENT","GRADIENT_TALL","GRADIENT_GOLD","GRADIENT_GREEN","GRADIENT_ORANGE"} --numbers only
    local letters = {}
    local first = 1
    if table_has_value(fonts,font) then
        for i in string.gmatch(text, ".") do
            if font_width(font.."_"..string.upper(i)) ~= false then
                letters[#letters+1] = {name=font.."_"..string.upper(i),width=font_width(font.."_"..string.upper(i))}
            else 
                print(font.."_"..string.upper(i).." was skipped, it's not real.")
            end 
        end 
    elseif table_has_value(lowers,font) then
        for i in string.gmatch(text, ".") do
            if i == " " then 
                letters[#letters+1] = {name=font.."_ ",width=font_width(font.."_ ")}
            elseif string.match(i, "%l") then
                if font_width(font.."_LOWER_"..string.upper(i)) ~= false then
                    letters[#letters+1] = {name=font.."_LOWER_"..string.upper(i),width=font_width(font.."_"..string.upper(i))}
                else 
                    print(font.."_LOWER_"..string.upper(i).." was skipped, it's not real.")
                end 
            else 
                if font_width(font.."_"..string.upper(i)) ~= false then
                    letters[#letters+1] = {name=font.."_"..string.upper(i),width=font_width(font.."_"..string.upper(i))}
                else 
                    print(font.."_"..string.upper(i).." was skipped, it's not real.")
                end 
            end
        end
    elseif table_has_value(numbers,font) then
        table.insert(letters,font.."_"..string.upper(i))
        if font_width(font.."_"..string.upper(i)) ~= false then
            letters[#letters+1] = {name=font.."_"..string.upper(i),width=font_width(font.."_"..string.upper(i))}
        else 
            print(font.."_"..string.upper(i).." was skipped, it's not real.")
        end 
    else
        print("[games] Hey! That's not a font.")
    end 

    local position = Net.get_bot_position(player_id.."-camera")
    local i = 1
    if text_cache[player_id] == nil then
        text_cache[player_id] = {}
    end 
    if text_cache[player_id][text_id] == nil then
        text_cache[player_id][text_id] = {}
    end 
    if text_cache[player_id][text_id]["letters"] == nil then
        text_cache[player_id][text_id]["letters"] = {}
    end 
    text_cache[player_id][text_id]["z"] = Z
    text_cache[player_id][text_id]["name"] = text_id
    text_cache[player_id][text_id]["length"] = #letters
    local rolling = 0
    for i,letter in next,letters do
        local xoffset=0
        local yoffset=0
        if text_cache[player_id][text_id]["letters"][i] == nil then
            text_cache[player_id][text_id]["letters"][i] = {}
        end 
        --convert v/h to x/y offsets
        local offset = 0
        --font specific offsets
        if font == "BATTLE" then offset = 0
        elseif font == "WIDE" then offset = 1.3
        elseif font == "THICK" then offset = 1.3
        elseif font == "SMALL" then offset = 1.3
        end
        xoffset,yoffset = convertOffsets(horizontalOffset+rolling+offset,verticalOffset-10,tonumber(Z))
        rolling = rolling + letter["width"]+offset
        xoffset,yoffset = fixOffsets(xoffset,yoffset)
        --print(letter["name"].." (width "..letter["width"].."- ".."x/y offset = "..xoffset..","..yoffset.. "; rolling = "..rolling)
        --add to text_cache
        text_cache[player_id][text_id]["letters"][i]["name"] = letter["name"]
        text_cache[player_id][text_id]["letters"][i]["width"] = letter["width"]
        text_cache[player_id][text_id]["letters"][i]["xoffset"] = xoffset
        text_cache[player_id][text_id]["letters"][i]["yoffset"] = yoffset
        local data = text_cache[player_id][text_id]["letters"][i]

        --create bot for this letter
        local extra = ""
        if color == "black" then
            extra = "_dark"
        end 
        local area_id = last_position_cache[player_id]["area"]
        Net.create_bot(player_id.."-text-"..text_id.."-"..tostring(i), { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts"..extra.."_compressed.png", animation_path="/server/assets/net-games/fonts"..extra.."_compressed.animation",animation=letter["name"], x=position.x+data["xoffset"]-.5, y=position.y+data["yoffset"]-.5, z=tonumber(Z+100), solid=false})
        exclude_except_for(player_id,player_id.."-text-"..text_id.."-"..tostring(i))
        i=i+1

    end
end 

--purpose: remove existing text from screen
function frame.erase_text(text_id,player_id)
return async(function ()
    --remove all bots associated with this text-line
    if text_cache[player_id] ~= nil then for i,label in next,text_cache[player_id] do
        for i,letter in next,label["letters"] do 
            Net.remove_bot(player_id.."-text-"..label["name"].."-"..tostring(i))
        end
    end
    end 
    --clear the cache
    text_cache[player_id][text_id] = nil
end)
end 

-- COUNTDOWN FUNCTIONS
-- Adds a BN-style countdown for specified player

--purpose: helper function
--usage: framework only
local function secondstoMMSS(seconds)
    -- Ensure the input is a non-negative integer
    seconds = math.max(0, math.floor(seconds))
    
    -- Calculate minutes and remaining seconds
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    
    -- Break down into individual digits
    local tenMinutes = math.floor(minutes / 10)
    local oneMinutes = minutes % 10
    
    local tenSeconds = math.floor(remainingSeconds / 10)
    local oneSeconds = remainingSeconds % 10
    
    -- Return the individual digits and formatted string
    return tenMinutes,oneMinutes,tenSeconds,oneSeconds
end


function frame.spawn_countdown(player_id,horizontalOffset,verticalOffset,Z,duration)
    local position = Net.get_bot_position(player_id.."-camera")
    local area_id = last_position_cache[player_id]["area"]
    if countdown_cache[player_id] == nil then countdown_cache[player_id] = {} end
    countdown_cache[player_id]["raw_duration"] = duration --167
    countdown_cache[player_id]["m1"],countdown_cache[player_id]["m2"],countdown_cache[player_id]["s1"], countdown_cache[player_id]["s2"] = secondstoMMSS(duration) -- reformats duration into base-10
    countdown_cache[player_id]["paused"] = true
    countdown_cache[player_id]["fs"] = 0
    countdown_cache[player_id]["z"] = Z
    -- create bots (five of them, sigh)
    local font = "THICK_"
    local width = 7.6 -- numbers and : are 6 wide plus 1.6 spacer
    
    xoffset,yoffset = convertOffsets(horizontalOffset,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    countdown_cache[player_id]["m1_yoffset"] = yoffset
    countdown_cache[player_id]["m1_xoffset"] = xoffset

    Net.create_bot(player_id.."-countdown-m1", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..countdown_cache[player_id]["m1"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-countdown-m1")
    xoffset,yoffset = convertOffsets(horizontalOffset+width,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    countdown_cache[player_id]["m2_yoffset"] = yoffset
    countdown_cache[player_id]["m2_xoffset"] = xoffset

    Net.create_bot(player_id.."-countdown-m2", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..countdown_cache[player_id]["m2"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-countdown-m2")
    xoffset,yoffset = convertOffsets(horizontalOffset+width*2,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    countdown_cache[player_id]["d_yoffset"] = yoffset
    countdown_cache[player_id]["d_xoffset"] = xoffset

    Net.create_bot(player_id.."-countdown-d", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..":", x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-countdown-d")
    xoffset,yoffset = convertOffsets(horizontalOffset+width*3,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    countdown_cache[player_id]["s1_yoffset"] = yoffset
    countdown_cache[player_id]["s1_xoffset"] = xoffset

    Net.create_bot(player_id.."-countdown-s1", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..countdown_cache[player_id]["s1"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-countdown-s1")
    xoffset,yoffset = convertOffsets(horizontalOffset+width*4,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    countdown_cache[player_id]["s2_yoffset"] = yoffset
    countdown_cache[player_id]["s2_xoffset"] = xoffset

    Net.create_bot(player_id.."-countdown-s2", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..countdown_cache[player_id]["s2"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-countdown-s2")
end

function frame.start_countdown(player_id)
    countdown_cache[player_id]["paused"] = false
end

function frame.pause_countdown(player_id)
    if countdown_cache[player_id] ~= nil then
        --stops countdown on:tick event
        countdown_cache[player_id]["paused"] = true
        --return time remaining
        return countdown_cache[player_id]["duration"]
    end 
end

function frame.remove_countdown(player_id)
    if Net.is_bot(player_id.."-countdown-s1") then
        Net.remove_bot(player_id.."-countdown-s1")
        Net.remove_bot(player_id.."-countdown-s2")
        Net.remove_bot(player_id.."-countdown-d")
        Net.remove_bot(player_id.."-countdown-m1")
        Net.remove_bot(player_id.."-countdown-m2")
        countdown_cache[player_id] = nil
        countdown_update[player_id] = nil
    else 
        print("Doesn't look like this player has a countdown active.")
    end
end

--purpose: managements updates to countdown as time passes
--usage: framework only
local function update_countdown(player_id,deltaTime)
    -- Store previous whole values for change detection
    local previous = {
        tenMinutes = countdown_cache[player_id]["m1"],
        oneMinutes = countdown_cache[player_id]["m2"],
        tenSeconds = countdown_cache[player_id]["s1"],
        oneSeconds = countdown_cache[player_id]["s2"]
    }
    
    -- Add delta time to fractional seconds
    countdown_cache[player_id]["fs"] = countdown_cache[player_id]["fs"] + deltaTime
    
    -- Calculate how many whole seconds we've accumulated
    local wholeSecondsPassed = math.floor(countdown_cache[player_id]["fs"])
    
    -- Only proceed if at least one whole second passed
    if wholeSecondsPassed > 0 then
        -- Subtract the whole seconds from our fractional counter
        countdown_cache[player_id]["fs"] = countdown_cache[player_id]["fs"] - wholeSecondsPassed
        
        -- Convert current time to total seconds
        local totalSeconds = 
            (countdown_cache[player_id]["m1"] * 10 + countdown_cache[player_id]["m2"]) * 60 +
            (countdown_cache[player_id]["s1"] * 10 + countdown_cache[player_id]["s2"])
        
        -- Subtract whole seconds that passed
        totalSeconds = math.max(0, totalSeconds - wholeSecondsPassed)
        
        -- Convert back to individual digits
        local minutes = math.floor(totalSeconds / 60)
        local seconds = totalSeconds % 60
        
        countdown_cache[player_id]["m1"] = math.floor(minutes / 10)
        countdown_cache[player_id]["m2"] = minutes % 10
        countdown_cache[player_id]["s1"] = math.floor(seconds / 10)
        countdown_cache[player_id]["s2"] = seconds % 10
        
        -- Change detection for each digit (only if whole numbers changed)
        if countdown_cache[player_id]["s2"] ~= previous.oneSeconds then
            -- Add your display update code here for 1s of seconds
            if countdown_update[player_id] == nil then
                countdown_update[player_id] = {}
            end 
            table.insert(countdown_update[player_id], "s2|"..previous_tick2)
        end
        
        if countdown_cache[player_id]["s1"] ~= previous.tenSeconds then
            if countdown_update[player_id] == nil then
                countdown_update[player_id] = {}
            end 
            table.insert(countdown_update[player_id], "s1|"..previous_tick2)
        end
        
        if countdown_cache[player_id]["m2"] ~= previous.oneMinutes then
            if countdown_update[player_id] == nil then
                countdown_update[player_id] = {}
            end 
            table.insert(countdown_update[player_id], "m2|"..previous_tick2)

        end
        
        if countdown_cache[player_id]["m1"] ~= previous.tenMinutes then
            if countdown_update[player_id] == nil then
                countdown_update[player_id] = {}
            end 
            table.insert(countdown_update[player_id], "m1|"..previous_tick2)

        end

        if countdown_cache[player_id]["m1"] == 0 and countdown_cache[player_id]["m2"] == 0 and countdown_cache[player_id]["s1"] == 0 and countdown_cache[player_id]["s2"] == 0 then
            countdown_cache[player_id]["paused"] = true
            Net:emit("countdown_ended", {player_id = player_id})
        end 
    end
end

-- TIMER FUNCTIONS

--purpose: manages updates to countdown as time passes
--usage: framework only
local function update_timer(player_id,deltaTime)
    -- Store previous whole values for change detection
    local previous = {
        tenMinutes = timer_cache[player_id]["m1"],
        oneMinutes = timer_cache[player_id]["m2"],
        tenSeconds = timer_cache[player_id]["s1"],
        oneSeconds = timer_cache[player_id]["s2"]
    }
    
    -- Add delta time to fractional seconds
    timer_cache[player_id]["fs"] = timer_cache[player_id]["fs"] + deltaTime
    
    -- Calculate how many whole seconds we've accumulated
    local wholeSecondsPassed = math.floor(timer_cache[player_id]["fs"])
    
    -- Only proceed if at least one whole second passed
    if wholeSecondsPassed > 0 then
        -- Subtract the whole seconds from our fractional counter
        timer_cache[player_id]["fs"] = timer_cache[player_id]["fs"] - wholeSecondsPassed
        
        -- Convert current time to total seconds
        local totalSeconds = 
            (timer_cache[player_id]["m1"] * 10 + timer_cache[player_id]["m2"]) * 60 +
            (timer_cache[player_id]["s1"] * 10 + timer_cache[player_id]["s2"])
        
        -- ADD whole seconds that passed (changed from subtract)
        totalSeconds = totalSeconds + wholeSecondsPassed
        
        -- Convert back to individual digits
        local minutes = math.floor(totalSeconds / 60)
        local seconds = totalSeconds % 60
        
        timer_cache[player_id]["m1"] = math.floor(minutes / 10)
        timer_cache[player_id]["m2"] = minutes % 10
        timer_cache[player_id]["s1"] = math.floor(seconds / 10)
        timer_cache[player_id]["s2"] = seconds % 10
        
        -- Change detection for each digit (only if whole numbers changed)
        if timer_cache[player_id]["s2"] ~= previous.oneSeconds then
            if timer_update[player_id] == nil then
                timer_update[player_id] = {}
            end 
            table.insert(timer_update[player_id], "s2|"..previous_tick2)
        end
        
        if timer_cache[player_id]["s1"] ~= previous.tenSeconds then
            if timer_update[player_id] == nil then
                timer_update[player_id] = {}
            end 
            table.insert(timer_update[player_id], "s1|"..previous_tick2)
        end
        
        if timer_cache[player_id]["m2"] ~= previous.oneMinutes then
            if timer_update[player_id] == nil then
                timer_update[player_id] = {}
            end 
            table.insert(timer_update[player_id], "m2|"..previous_tick2)
        end
        
        if timer_cache[player_id]["m1"] ~= previous.tenMinutes then
            if timer_update[player_id] == nil then
                timer_update[player_id] = {}
            end 
            table.insert(timer_update[player_id], "m1|"..previous_tick2)
        end
    end
end

function frame.spawn_timer(player_id,horizontalOffset,verticalOffset,Z)
    local duration = 0
    local position = Net.get_bot_position(player_id.."-camera")
    local area_id = last_position_cache[player_id]["area"]
    if timer_cache[player_id] == nil then timer_cache[player_id] = {} end
    timer_cache[player_id]["raw_duration"] = duration --167
    timer_cache[player_id]["m1"],timer_cache[player_id]["m2"],timer_cache[player_id]["s1"], timer_cache[player_id]["s2"] = secondstoMMSS(duration) -- reformats duration into base-10
    timer_cache[player_id]["paused"] = true
    timer_cache[player_id]["fs"] = 0
    timer_cache[player_id]["z"] = Z
    -- create bots (five of them, sigh)
    local font = "THICK_"
    local width = 7.6 -- numbers and : are 6 plus 1 spacer
    
    xoffset,yoffset = convertOffsets(horizontalOffset,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    timer_cache[player_id]["m1_yoffset"] = yoffset
    timer_cache[player_id]["m1_xoffset"] = xoffset

    Net.create_bot(player_id.."-timer-m1", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..timer_cache[player_id]["m1"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-timer-m1")
    xoffset,yoffset = convertOffsets(horizontalOffset+width,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    timer_cache[player_id]["m2_yoffset"] = yoffset
    timer_cache[player_id]["m2_xoffset"] = xoffset

    Net.create_bot(player_id.."-timer-m2", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..timer_cache[player_id]["m2"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-timer-m2")
    xoffset,yoffset = convertOffsets(horizontalOffset+width*2,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    timer_cache[player_id]["d_yoffset"] = yoffset
    timer_cache[player_id]["d_xoffset"] = xoffset

    Net.create_bot(player_id.."-timer-d", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..":", x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-timer-d")
    xoffset,yoffset = convertOffsets(horizontalOffset+width*3,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    timer_cache[player_id]["s1_yoffset"] = yoffset
    timer_cache[player_id]["s1_xoffset"] = xoffset

    Net.create_bot(player_id.."-timer-s1", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..timer_cache[player_id]["s1"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-timer-s1")
    xoffset,yoffset = convertOffsets(horizontalOffset+width*4,verticalOffset,tonumber(Z))
    xoffset,yoffset = fixOffsets(xoffset,yoffset)
    timer_cache[player_id]["s2_yoffset"] = yoffset
    timer_cache[player_id]["s2_xoffset"] = xoffset

    Net.create_bot(player_id.."-timer-s2", { area_id=area_id, warp_in=false, texture_path="/server/assets/net-games/fonts_compressed.png", animation_path="/server/assets/net-games/fonts_compressed.animation",animation=font..timer_cache[player_id]["s2"], x=position.x+xoffset-.5, y=position.y+yoffset-.5, z=tonumber(Z+100), solid=false})
    exclude_except_for(player_id,player_id.."-timer-s2")
end

function frame.start_timer(player_id)
    timer_cache[player_id]["paused"] = false
end

function frame.pause_timer(player_id)
    --stops countdown on:tick event
    timer_cache[player_id]["paused"] = true
    --return time remaining
    return timer_cache[player_id]["duration"]
end

function frame.remove_timer(player_id)
    if Net.is_bot(player_id.."-timer-s1") then
        Net.remove_bot(player_id.."-timer-s1")
        Net.remove_bot(player_id.."-timer-s2")
        Net.remove_bot(player_id.."-timer-d")
        Net.remove_bot(player_id.."-timer-m1")
        Net.remove_bot(player_id.."-timer-m2")
        timer_cache[player_id] = nil
    else
        print("Player doesn't have an active timer.")
    end 
end

-- NON-CODER FUNCTIONS
-- The functions in this section are framework management only, you shouldn't call these in your code. 

--purpose: sets the stasis chamber location used during freeze_player() 
--usage: automatically called on server boot and creates a stasis tile high on every map 
function frame.set_stasis()
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
                print ("[games] Stasis for "..area_id.." set to "..prop)
            else
                print("[games] Those stasis cords are screwed six ways to Sunday.")
            end
        end 
	end
end

function frame.start_framework()
    print("")
    print("[games] Framework initiated")
    frame.set_stasis()
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
        direction="D"
    end 

    --direction reported by Net.get_player_direction() is delayed so can't be used or visuals get out of sync.
    --direction = simple_direction(Net.get_player_direction(player_id))
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
    last_position_cache[player_id]["d"] = direction
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

local function handle_bot_movement(player_id,x,y,z,direction,speed) --was process_movement
    return async(function ()

    if track_player[player_id] == nil then
        track_player[player_id] = true
    end
    --if player is frameworked
    if framework_active[player_id] ~= nil then if framework_active[player_id] == true then

            --if player frozen
            if frozen[player_id] ~= nil then 
            if frozen[player_id] == true then
                local area_id = Net.get_player_area(player_id) 
                local position = stasis_cache[area_id]
                --if player frozen, move back to center of stasis. 
                last_position_cache[player_id]["x"] = tonumber(position.x+.5)
                last_position_cache[player_id]["y"] = tonumber(position.y+.5)
                last_position_cache[player_id]["z"] = tonumber(position.z)
                Net.teleport_player(player_id, false, position.x+.5, position.y+.5, position.z)

            --if camera is being moved by player but isn't tracked to player's bot (when moving camera w/ UI but not player)
            elseif track_player[player_id] == false then

                --move stunt double 
                local newposition = Net.get_bot_position(player_id.."-camera")
                local stunt_position = Net.get_bot_position(player_id.."-double") 
                local animation = tostring(string.upper(speed.."_"..direction))
                local keyframes = {{properties={{property="Animation",value=animation},{property="X",ease="Linear",value=stunt_position.x},{property="Y",ease="Linear",value=stunt_position.y},{property="Z",ease="Linear",value=stunt_position.z}},duration=0}}
                keyframes[#keyframes+1] = {properties={{property="Animation",value=animation},{property="X",ease="Linear",value=x+.5},{property="Y",ease="Linear",value=y+.5},{property="Z",ease="Linear",value=z+1}},duration=.1}
                Net.move_bot(player_id.."-double",z,z,z+1)
                Net.animate_bot_properties(player_id.."-double", keyframes)
                
                --update UI position
                if ui_elements[player_id] ~= nil then for name,element in next,ui_elements[player_id] do
                    local keyframes = {{properties={{property="Animation",value=element["state"]}},duration=0}}
                    Net.animate_bot(player_id.."-ui-"..element["name"], element["state"], true)
                    Net.animate_bot_properties(player_id.."-ui-"..element["name"], keyframes)
                end 
                end

                --update text position
                if text_cache[player_id] ~= nil then for i,label in next,text_cache[player_id] do
                    for i,letter in next,label["letters"] do 
                        local keyframes = {{properties={{property="Animation",value=letter["name"]}},duration=0}}
                        Net.animate_bot(player_id.."-text-"..label["name"].."-"..tostring(i), letter["name"], true)
                        Net.animate_bot_properties(player_id.."-text-"..label["name"].."-"..tostring(i), keyframes)
                    end
                end 
                end

                --update countdown position
                if countdown_cache[player_id] ~= nil then 
                    local clockpositions = {"m1","m2","d","s1","s2"}
                    for i,clockposition in next,clockpositions do 
                        local state = ""
                        if clockposition == "d" then 
                            state = "THICK_:"
                        else 
                            state = "THICK_"..countdown_cache[player_id][clockposition]
                        end 
                        local keyframes = {{properties={{property="Animation",value=state}},duration=0}}
                        Net.animate_bot(player_id.."-countdown-"..clockposition, state, true)
                        Net.animate_bot_properties(player_id.."-countdown-"..clockposition, keyframes)
                    end
                end

                --update timer position
                if timer_cache[player_id] ~= nil then 
                    local clockpositions = {"m1","m2","d","s1","s2"}
                    for i,clockposition in next,clockpositions do 
                        local state = ""
                        if clockposition == "d" then 
                            state = "THICK_:"
                        else 
                            state = "THICK_"..timer_cache[player_id][clockposition]
                        end 
                        local keyframes = {{properties={{property="Animation",value=state}},duration=0}}
                        Net.animate_bot(player_id.."-timer-"..clockposition, state, true)
                        Net.animate_bot_properties(player_id.."-timer-"..clockposition, keyframes)
                    end
                end

            --if player not frozen (movement logic)
            elseif direction ~= "" then
                
                --player isn't frozen so track camera bot and stunt double to player movement
                local stunt_position = Net.get_bot_position(player_id.."-double") 
                local camera_position = Net.get_bot_position(player_id.."-camera") 
                local animation = tostring(string.upper(speed.."_"..direction))

                local keyframes = {{properties={{property="Animation",value=animation},{property="X",ease="Linear",value=stunt_position.x},{property="Y",ease="Linear",value=stunt_position.y},{property="Z",ease="Linear",value=stunt_position.z}},duration=0}}
                keyframes[#keyframes+1] = {properties={{property="Animation",value=animation},{property="X",ease="Linear",value=x+.5},{property="Y",ease="Linear",value=y+.5},{property="Z",ease="Linear",value=z+1}},duration=.1}

                Net.move_bot(player_id.."-double",x,y,z)
                Net.animate_bot_properties(player_id.."-double", keyframes)
                Net.move_bot(player_id.."-camera",x,y,z)
                Net.animate_bot_properties(player_id.."-camera", keyframes)

                
                --move all active UI elements to track with camera
                if ui_elements[player_id] ~= nil then for name,element in next,ui_elements[player_id] do
                    local old_position = Net.get_bot_position(player_id.."-ui-"..name)
                    local newx = x + element["xoffset"]
                    local newy = y + element["yoffset"]
                    local keyframes = {{properties={{property="Animation",value=element["state"]},{property="X",ease="Linear",value=old_position.x},{property="Y",ease="Linear",value=old_position.y}},duration=0}}
                    keyframes[#keyframes+1] = {properties={{property="Animation",value=element["state"]},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
                    keyframes[#keyframes+1] = {properties={{property="Animation",value=element["state"]}},duration=0}
                    Net.move_bot(player_id.."-ui-"..element["name"],newx,newy,element["z"])
                    Net.animate_bot(player_id.."-ui-"..element["name"], element["state"], true)
                    Net.animate_bot_properties(player_id.."-ui-"..element["name"], keyframes)
                end 
                end 
                --move all text elements to track with camera
                if text_cache[player_id] ~= nil then for i,label in next,text_cache[player_id] do
                    for i,letter in next,label["letters"] do 
                        local newposition = Net.get_bot_position(player_id.."-text-"..label["name"].."-"..tostring(i))
                        local newx = x + letter["xoffset"]
                        local newy = y + letter["yoffset"]
                        local keyframes = {{properties={{property="Animation",value=letter["name"]},{property="X",ease="Linear",value=newposition.x},{property="Y",ease="Linear",value=newposition.y}},duration=0}}
                        keyframes[#keyframes+1] = {properties={{property="Animation",value=letter["name"]},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
                        keyframes[#keyframes+1] = {properties={{property="Animation",value=letter["name"]}},duration=0}
                        Net.move_bot(player_id.."-text-"..label["name"].."-"..tostring(i),newx,newy,label["z"]+100)
                        Net.animate_bot(player_id.."-text-"..label["name"].."-"..tostring(i), letter["name"], true)
                        Net.animate_bot_properties(player_id.."-text-"..label["name"].."-"..tostring(i), keyframes)
                    end
                end 
                end
                
                --move all countdown elements to track with camera
                if countdown_cache[player_id] ~= nil then 
                    local clockpositions = {"m1","m2","d","s1","s2"}
                    for i,clockposition in next,clockpositions do 
                        local newposition = Net.get_bot_position(player_id.."-countdown-"..tostring(clockposition))
                        local newx = x + countdown_cache[player_id][clockposition.."_xoffset"]
                        local newy = y + countdown_cache[player_id][clockposition.."_yoffset"]
                        local state = ""
                        if clockposition == "d" then 
                            state = "THICK_:"
                        else 
                            state = "THICK_"..countdown_cache[player_id][clockposition]
                        end 
                        local keyframes = {{properties={{property="Animation",value=state},{property="X",ease="Linear",value=newposition.x},{property="Y",ease="Linear",value=newposition.y}},duration=0}}
                        keyframes[#keyframes+1] = {properties={{property="Animation",value=state},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
                        keyframes[#keyframes+1] = {properties={{property="Animation",value=state}},duration=0}
                        Net.move_bot(player_id.."-countdown-"..clockposition,newx,newy,countdown_cache[player_id]["z"]+100)
                        Net.animate_bot(player_id.."-countdown-"..clockposition, state, true)
                        Net.animate_bot_properties(player_id.."-countdown-"..clockposition, keyframes)
                    end
                end

                if timer_cache[player_id] ~= nil then 
                    local clockpositions = {"m1","m2","d","s1","s2"}
                    for i,clockposition in next,clockpositions do 
                        local newposition = Net.get_bot_position(player_id.."-timer-"..tostring(clockposition))
                        local newx = x + timer_cache[player_id][clockposition.."_xoffset"]
                        local newy = y + timer_cache[player_id][clockposition.."_yoffset"]
                        local state = ""
                        if clockposition == "d" then 
                            state = "THICK_:"
                        else 
                            state = "THICK_"..timer_cache[player_id][clockposition]
                        end 
                        local keyframes = {{properties={{property="Animation",value=state},{property="X",ease="Linear",value=newposition.x},{property="Y",ease="Linear",value=newposition.y}},duration=0}}
                        keyframes[#keyframes+1] = {properties={{property="Animation",value=state},{property="X",ease="Linear",value=newx},{property="Y",ease="Linear",value=newy}},duration=.1}
                        keyframes[#keyframes+1] = {properties={{property="Animation",value=state}},duration=0}
                        Net.move_bot(player_id.."-timer-"..clockposition,newx,newy,timer_cache[player_id]["z"]+100)
                        Net.animate_bot(player_id.."-timer-"..clockposition, state, true)
                        Net.animate_bot_properties(player_id.."-timer-"..clockposition, keyframes)
                    end
                end
            end
        end
    end
    end
end)
end 

--This function is brought to you by our script sponsor, NordVPN.
--Are you exposing your data to data thieves? Then you need to get
--CyberGhost VPN. Ya, NordVPN is fine and all but CyberGhost is cheaper
--than dirt. Seriously, have you bought a bag of dirt recently?
--It's ridiculous. The stuff covers 1/3 of the planet and they want
--how much for a bag of it?! Next thing they'll start charging for water.

-- NON-CODER EVENTS
-- The events in this section are framework management; "no touchie, no touch"! 

--Event handlers for framework to function
Net:on("player_join", function(event)
    
    table.insert(online_players, event.player_id)
    --reset all caches on join
    frozen[event.player_id] = false
    cursor_cache[event.player_id] = {}
    avatar_cache[event.player_id] = {}
    text_cache[event.player_id] = {}
    framework_active[event.player_id] = false

    --exclude all existing UI, text, countdown, and timer elements from new player
    if next(countdown_cache) ~= nil then
        for player_id,countdown in next,countdown_cache do
            Net.exclude_actor_for_player(event.player_id, player_id.."-countdown-s1")
            Net.exclude_actor_for_player(event.player_id, player_id.."-countdown-s2")
            Net.exclude_actor_for_player(event.player_id, player_id.."-countdown-d")
            Net.exclude_actor_for_player(event.player_id, player_id.."-countdown-m1")
            Net.exclude_actor_for_player(event.player_id, player_id.."-countdown-m2")
        end
    end
    if next(timer_cache) ~= nil then
        for player_id,timer in next,timer_cache do
            Net.exclude_actor_for_player(event.player_id, player_id.."-timer-s1")
            Net.exclude_actor_for_player(event.player_id, player_id.."-timer-s2")
            Net.exclude_actor_for_player(event.player_id, player_id.."-timer-d")
            Net.exclude_actor_for_player(event.player_id, player_id.."-timer-m1")
            Net.exclude_actor_for_player(event.player_id, player_id.."-timer-m2")
        end
    end
    if next(ui_elements) ~= nil then
        for player_id,ui in next,ui_elements do
            for name,element in next,ui do
                Net.exclude_actor_for_player(event.player_id, player_id.."-ui-"..element["name"])
            end 
        end
    end
    if next(text_cache) ~= nil then
        for player_id,text_id in next,text_cache do
            if text_id["letters"] ~= nil then
                for i,letter in next,text_id["letters"] do
                    Net.exclude_actor_for_player(event.player_id, player_id.."-text-"..text_id["name"].."-"..tostring(i))
                end 
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
    framework_active[event.player_id] = nil
    player_stopped[event.player_id] = nil
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
    if ui_elements[event.player_id] ~= nil then 
        for name,element in next,ui_elements[event.player_id] do
            Net.remove_bot(event.player_id.."-ui-"..element["name"])
        end
        ui_elements[event.player_id] = nil
        ui_update[event.player_id] = nil
    end

    --remove text
    if text_cache[event.player_id] ~= nil then for i,label in next,text_cache[event.player_id] do
        for i,letter in next,label["letters"] do 
            Net.remove_bot(event.player_id.."-text-"..label["name"].."-"..tostring(i))
        end
    end 
        text_cache[event.player_id] = nil
    end

    --remove countdowns
    if countdown_cache[event.player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            Net.remove_bot(event.player_id.."-countdown-"..clockposition)
        end
        countdown_cache[event.player_id] = nil
        countdown_update[event.player_id] = nil
    end

    --remove timers
    if timer_cache[event.player_id] ~= nil then 
        local clockpositions = {"m1","m2","d","s1","s2"}
        for i,clockposition in next,clockpositions do 
            Net.remove_bot(event.player_id.."-timer-"..clockposition)
        end
        timer_cache[event.player_id] = nil
        timer_update[event.player_id] = nil
    end


end)

Net:on("tick", function(event)

    if next(movement_queue) ~= nil then
        for player_id,data in next,movement_queue do
            handle_bot_movement(player_id,data["x"],data["y"],data["z"],data["direction"],data["speed"])
            movement_queue[player_id] = nil
        end
    end

    --update each unpaused countdown for each player
    if next(countdown_cache) ~= nil then
        for player_id,countdown in next,countdown_cache do
            if countdown["paused"] == false then
                update_countdown(player_id,event.delta_time)
            end 
        end 
    end 
    --update each unpaused timer for each player
    if next(timer_cache) ~= nil then
        for player_id,timer in next,timer_cache do
            if timer["paused"] == false then
                update_timer(player_id,event.delta_time)
            end 
        end 
    end 
    --manages UI updates if camera hasn't moved recently
    --ignored if player moves within 4 ticks (~0.20 seconds)
    if next(ui_update) ~= nil then
        for player_id,ui in next,ui_update do
            for i,ui in next,ui_update[player_id] do
                local parts = splitter(ui,"|")
                local ui = parts[1]
                local gap = tonumber(parts[2])
                if gap == tick_gap2 then
                    animation_state = ui_elements[player_id][ui]["state"]
                    local position = Net.get_bot_position(player_id.."-ui-"..ui) 
                    local keyframes = {{properties={{property="Animation",value=animation_state}},duration=0}}
                    Net.animate_bot_properties(player_id.."-ui-"..ui, keyframes)
                    ui_update[player_id][i] = nil
                end 
            end 
             end
    end
    --manages countdown updates if camera hasn't moved recently
    --ignored if player moves within 4 ticks (~0.20 seconds)
    if next(countdown_update) ~= nil then
        for player_id,positions in next,countdown_update do 
            for i,position in next,countdown_update[player_id] do
                local parts = splitter(position,"|")
                local clockposition = parts[1]
                local gap = tonumber(parts[2])
                if gap == tick_gap2 then
                    animation_state = "THICK_"..countdown_cache[player_id][clockposition]
                    local keyframes = {{properties={{property="Animation",value=animation_state}},duration=0}}
                    Net.animate_bot_properties(player_id.."-countdown-"..clockposition, keyframes)
                    countdown_update[player_id][clockposition] = nil
                end 
            end 
        end
    end
    --manages timer updates if camera hasn't moved recently
    --ignored if player moves within 4 ticks (~0.20 seconds)
    if next(timer_update) ~= nil then
        for player_id,positions in next,timer_update do 
            for i,position in next,timer_update[player_id] do
                local parts = splitter(position,"|")
                local clockposition = parts[1]
                local gap = tonumber(parts[2])
                if gap == tick_gap2 then
                    animation_state = "THICK_"..timer_cache[player_id][clockposition]
                    local keyframes = {{properties={{property="Animation",value=animation_state}},duration=0}}
                    Net.animate_bot_properties(player_id.."-timer-"..clockposition, keyframes)
                    timer_update[player_id][clockposition] = nil
                end 
            end 
        end
    end
    --tracks if cursor movement is locked (which lasts 4 ticks)
    if next(cursor_cache) ~= nil then
        for player_id,cursor in next,cursor_cache do
            if cursor_cache[player_id]["locked"] == true and cursor_cache[player_id]["lock-tick"] == tick_gap2 then
                cursor_cache[player_id]["locked"] = false
                cursor_cache[player_id]["lock-tick"] = 20 --out of range so never triggers
            end 
        end
    end

    --tick tracker for UI updates
    previous_tick = tick_gap
    tick_gap = tick_gap - 1
    if tick_gap <= 0 then
        tick_gap = 4
    end
     --tick tracker for cursors
    previous_tick2 = tick_gap2
    tick_gap2 = tick_gap2 - 1
    if tick_gap2 <= 0 then
        tick_gap2 = 6
    end

    --tracks if frameworked players stops moving and sets their stunt double to proper idle animation 
    if next(player_stopped) ~= nil then
        for player_id,player_data in next,player_stopped do
            if framework_active[player_id] == true then 
                if player_stopped[player_id] == 0 then
                    local direction = last_position_cache[player_id]["d"]
                    local keyframes = {{properties={{property="Animation",value="IDLE_"..direction}},duration=0}}
                    Net.animate_bot_properties(player_id.."-double", keyframes)
                    Net.animate_bot(player_id.."-double", "IDLE_"..direction, true)
                    Net.move_bot(player_id.."-double",last_position_cache[player_id]["x"]+.5,last_position_cache[player_id]["y"]+.5,last_position_cache[player_id]["z"]+1)

                    --player is stopped (using -1 so it doesn't loop unless player moves again)
                    player_stopped[player_id] = -1
                    --reset player speed and direction (not currentlyu used)
                    last_position_cache[player_id]["d"] = ""
                    last_position_cache[player_id]["s"] = ""
                    last_position_cache[player_id]["pd"] = ""
                    last_position_cache[player_id]["ps"] = ""
                end 
                if player_stopped[player_id] > 0 then
                    player_stopped[player_id] = player_stopped[player_id]-1
                end 
            end 
        end 
    end

end)

Net:on("player_move", function(event)
    --tracks players stopping position and clears ui updates as updates will occur within this function call
    if frozen[event.player_id] ~= nil then
        if frozen[event.player_id] == true then
            player_stopped[event.player_id] = -1
        else
            --player is moving
            ui_update[event.player_id] = nil
            countdown_update[event.player_id] = nil
            timer_update[event.player_id] = nil
            player_stopped[event.player_id] = 3
        end
    else
        --player is moving
        ui_update[event.player_id] = nil
        player_stopped[event.player_id] = 3
    end

    --emits event on d-pad press
    local match = analyze_player_movement(event.player_id,event.x,event.y,event.z)
    if match == nil then
        match = {direction="D",speed="WALK",same=false}
    end  
    local direction = match["direction"]
    local speed = match["speed"]

    --pass movements to movement_queue (in tick) instead of handle_bot_movement()

    if not movement_queue[event.player_id] then 
        movement_queue[event.player_id] = {}
    end 
    movement_queue[event.player_id]["new"] = true
    movement_queue[event.player_id]["player_id"] = event.player_id
    movement_queue[event.player_id]["x"] = event.x
    movement_queue[event.player_id]["y"] = event.y
    movement_queue[event.player_id]["z"] = event.z
    movement_queue[event.player_id]["speed"] = speed
    movement_queue[event.player_id]["direction"] = direction

end)


Net:on("player_area_transfer", function(event)

    last_position_cache[event.player_id]["area"] = Net.get_player_area(player_id)

    --UNTESTED
    if framework_active[player_id] == true then 
        local area_id = Net.get_player_area(event.player_id) 
        local position = Net.get_player_position(event.player_id) 
        Net.transfer_bot(event.player_id.."-camera", area_id, false, position.x, position.y, position.z)
        Net.transfer_bot(event.player_id.."-double", area_id, false, position.x, position.y, position.z)

        --move UIs to stunt double
        if ui_elements[event.player_id] ~= nil then for name,element in next,ui_elements[event.player_id] do
            local newx = position.x + element["xoffset"]
            local newy = position.y + element["yoffset"]
            Net.transfer_bot(event.player_id.."-ui-"..element["name"], area_id, false, newx, newy, element["z"])
        end
        end

        --update text
        if text_cache[event.player_id] ~= nil then for i,label in next,text_cache[event.player_id] do
            for i,letter in next,label["letters"] do 
                local newx = position.x + letter["xoffset"]
                local newy = position.y + letter["yoffset"]
                Net.transfer_bot(event.player_id.."-text-"..label["name"].."-"..tostring(i), area_id, false, newx, newy, label["z"])
            end
        end 
        end

        --update countdown position
        if countdown_cache[event.player_id] ~= nil then 
            local clockpositions = {"m1","m2","d","s1","s2"}
            for i,clockposition in next,clockpositions do 
                local newx = position.x + countdown_cache[event.player_id][clockposition.."_xoffset"]
                local newy = position.y + countdown_cache[event.player_id][clockposition.."_xoffset"]
                Net.transfer_bot(event.player_id.."-countdown-"..clockposition,area_id,false,newx, newy,countdown_cache[event.player_id]["z"])
            end
        end

        --update timer position
        if timer_cache[event.player_id] ~= nil then 
            local clockpositions = {"m1","m2","d","s1","s2"}
            for i,clockposition in next,clockpositions do 
                local newx = position.x + timer_cache[event.player_id][clockposition.."_xoffset"]
                local newy = position.y + timer_cache[event.player_id][clockposition.."_xoffset"]
                Net.transfer_bot(event.player_id.."-timer-"..clockposition,area_id,false,newx, newy,timer_cache[event.player_id]["z"])
            end
        end
    end 
end)

-- Whatcha doin'? If you're here you must be a coder, or at least interesting in coding.
-- You should help out on the Discord. There's only a few of us that can actually code. 
-- Seriously, stop reading this and come help! For real. Please. I'm begging you. 

return frame