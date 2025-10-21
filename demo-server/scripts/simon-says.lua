--[[
* ---------------------------------------------------------- *
             CyberSimon Says (minigame) by Indiana
	 https://github.com/indianajson/net-games/simon-says/
* ---------------------------------------------------------- *
]]--

--[[ REQUIRED VARIABLES AND DEFAULTS ]]--
local games = require("scripts/net-games/framework")
games.start_framework()

local simon_cache = {}
local simon_players = {}
local simon_optional_properties = {"NPC","NPC Mug","Time","Limit"}
local defaults = {
    time_limit = 60,
    default_npc = "/server/assets/simon-says/normal-navi-bn4_green",
    default_npc_mug = "/server/assets/simon-says/normal-navi-bn4_green-mug",
    total_answers = 60
}

--Shorthand for async
function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end

--Shorthand for await
function await(v) return Async.await(v) end

local function removeValue(array, valueToRemove)
    for i, v in ipairs(array) do
        if v == valueToRemove then
            table.remove(array, i)
            return -- Optional: if you only want to remove the first occurrence
        end
    end
end

--[[ SERVER LOGIC ]]--
--[[ Code for making it easy to spawn game NPCs ]]--

--purpose: runs on boot to handle spawning CyberSimon Says NPCs
local function spawn_simon()
    --check each area for object with the class "Simon Says"
    local areas = Net.list_areas()
    for i, area_id in next, areas do
        area_id = tostring(area_id)
        if not simon_cache[area_id] then
            simon_cache[area_id] = {}
        --Loop over all objects in area, spawning NPCs for each simon says object.
        local objects = Net.list_objects(area_id)
            for i, object_id in next, objects do    
                local object = Net.get_object_by_id(area_id, object_id)
                object_id = tostring(object_id)
                if object.type == "Simon Says" then
                    local simon_id = object.name..'-simon-'..area_id
                    simon_cache[area_id][simon_id] = object
                    local object = simon_cache[area_id][simon_id]
                    Net.remove_object(area_id, object_id)
                    print('[simonsays] Found \''..object.name..'\' playing Simon Says in '..area_id..'.tmx')

                    for i, prop_name in pairs(simon_optional_properties) do
                        if not object.custom_properties[prop_name] then
                            print('   '..prop_name..' not set (default was used)')
                        else
                        print('   '..prop_name..' = '..object.custom_properties[prop_name])
                        end
                    end 

                    -- set variables for custom game values 
                    if not object.custom_properties["NPC"] then
                        object.custom_properties["NPC Animation"] = defaults["default_npc"]..".animation"
                        object.custom_properties["NPC Texture"] = defaults["default_npc"]..".png"
                    else 
                        object.custom_properties["NPC Animation"] = object.custom_properties["NPC"]..".animation"
                        object.custom_properties["NPC Texture"] = object.custom_properties["NPC"]..".png"
                    end
                    if not object.custom_properties["NPC Mug"] then
                        object.custom_properties["NPC Mug Animation"] = defaults["default_npc_mug"]..".animation"
                        object.custom_properties["NPC Mug Texture"] = defaults["default_npc_mug"]..".png"
                    else 
                        object.custom_properties["NPC MugAnimation"] = object.custom_properties["NPC Mug"]..".animation"
                        object.custom_properties["NPC Mug Texture"] = object.custom_properties["NPC Mug"]..".png"
                    end

                    if not object.custom_properties["Time"] then
                        object.custom_properties["Time"] = defaults["time_limit"]
                    end
                    if not object.custom_properties["Limit"] then
                        object.custom_properties["Limit"] = defaults["total_answers"]
                    end

                    --spawn an NPC (default to green generic navi unless a "NPC" string is provided)
                    local simon = Net.create_bot(simon_id,{name="", area_id=area_id, texture_path=object.custom_properties["NPC Texture"], animation_path=object.custom_properties["NPC Animation"], animation="IDLE_DR", x=object.x, y=object.y, z=object.z, solid=true,warp_in=false })

                end
            end
        end
    end

end 

spawn_simon()

--purpose: handles clean up on log out
Net:on("player_disconnect", function(event)
    if simon_players[event.player_id] then 
        local area_id = Net.get_player_area(event.player_id)
        local actor_id = simon_players[event.player_id]["actor"]
        simon_cache[area_id][actor_id]['occupied'] = false
        simon_players[event.player_id] = nil
    end 
end)

--[[ GAME LOGIC ]]--
--[[ The actual code that runs the game ]]--

--purpose: handles selecing a new button for Simon to say
local function simon_says_press(player_id)
    return async(function ()
        local actor_id = simon_players[player_id]["actor"]
        local area_id = simon_players[player_id]["area"]
        local simon = simon_cache[area_id][actor_id]
        games.remove_map_element("indicator",player_id)
        await(Async.sleep(.1))
        math.randomseed(os.time())
        local possibilities = {"A","LS","D","L","R","U"}
        removeValue(possibilities,simon_players[player_id]["current"])
        local table_size = #possibilities
        local random_index = math.random(1, table_size)
        simon_players[player_id]["current"] = possibilities[random_index]
        simon_players[player_id]["active"] = true
        games.add_map_element("indicator",player_id,"/server/assets/simon-says/indicators.png","/server/assets/simon-says/indicators.animation",possibilities[random_index],simon.x-.1,simon.y-.9,simon.z+2)
        Net.unlock_player_input(player_id)

    end)
end 

--purpose: Handles initial interaction with the Simon Says and starts the game if the player choses to play
local function greet_simon(actor_id,player_id)
    return async(function ()
    local area_id = Net.get_player_area(player_id)
    --lock interaction with bot (if not in game "tell them to wait")
    if simon_cache[area_id][actor_id]['occupied'] ~= nil then 
       if simon_cache[area_id][actor_id]['occupied'] == true then
        local simon = simon_cache[area_id][actor_id]
        Net.message_player(player_id, "CyberSimon Says... give me a minute to finish this game.", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 
        return false
        end 
    end 

    simon_cache[area_id][actor_id]['occupied'] = true

    local simon = simon_cache[area_id][actor_id]
    
    local decision = await(Async.question_player(player_id, "Hey, you! Wanna play a little game?", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]))

    --yes (play the game)
    if decision == 1 then
        Net.lock_player_input(player_id)
        if not simon_players[player_id] then
            simon_players[player_id] = {} 
        end 
        simon_players[player_id]["actor"] = actor_id
        simon_players[player_id]["area"] = area_id
        --await(games.walk_frozen_player(player_id,simon.x+.5,simon.y,simon.z,1,true))
        --games.animate_frozen_player(player_id,"IDLE_UL")
        Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=255}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))
        games.activate_framework(player_id)
        games.freeze_player(player_id)
        games.add_ui_element("board",player_id,"/server/assets/simon-says/board.png","/server/assets/simon-says/board.animation","UI",3,20,-1)
        await(games.move_frozen_player(player_id,simon.x+.5,simon.y,simon.z))
        await(games.animate_frozen_player(player_id,"IDLE_UL"))
        games.spawn_countdown(player_id,24,34,0,simon.custom_properties["Time"])
        games.write_text("simon_says_answers",player_id,"THICK","","00",35,67,1)
        Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=0}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
        await(Async.sleep(.75))
        Net.unlock_player_input(player_id)
        Net.message_player(player_id, "Now it's time for... \"CyberSimon Says\"! Yeahh! Whoo! Whoo!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 
        Net.message_player(player_id, "All you have to do is push the button that I tell you to!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 
        Net.message_player(player_id, "The time limit is... ".. simon.custom_properties["Time"] .." seconds!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 


        Net.message_player(player_id, "You win if you can press the correct button ".. simon.custom_properties["Limit"] .." times!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 
        await(Async.message_player(player_id, "Good luck!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]))

        await(Async.sleep(1))
        Net.play_sound_for_player(player_id, "/server/assets/simon-says/count.ogg")
        await(Async.sleep(1))
        Net.play_sound_for_player(player_id, "/server/assets/simon-says/count.ogg")
        await(Async.sleep(1))
        Net.play_sound_for_player(player_id, "/server/assets/simon-says/count.ogg")
        await(Async.sleep(1))
        Net.play_sound_for_player(player_id, "/server/assets/simon-says/game_start.ogg")
        games.add_map_element("chat",player_id,"/server/assets/simon-says/chat.png","/server/assets/simon-says/chat.animation","UI",simon.x-.8,simon.y-1.1,simon.z)

        games.start_countdown(player_id)
        simon_players[player_id]["score"] = 0
        games.add_map_element("indicator",player_id,"/server/assets/simon-says/indicators.png","/server/assets/simon-says/indicators.animation","IDLE_UL",100,100,simon.z+2)
        await(Async.sleep(.05))
        simon_says_press(player_id)

    --no (end the conversation)
    elseif decision == 0 then 
        simon_cache[area_id][actor_id]['occupied'] = false
        Net.message_player(player_id, "Aw, c'mon. Are you sure? Oh well.", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 
    else 
        print("We didn't get an answer before we processed the code.")
    end     
    end)


end

--purpose: checks if player speaks to Simon Says NPC
Net:on("actor_interaction", function(event)
    if event.button == 0 then 
        if string.find(event.actor_id, "-simon-") then
            greet_simon(event.actor_id,event.player_id)
        end
    end
end)

--purpose: checks any button press from any player, if tbe player is playing Simon Says it then checks if their answer is correct. 
Net:on("button_press", function(event)  
    return async(function ()  
    if simon_players[event.player_id] ~= nil then
    if simon_players[event.player_id]["active"] == true then 
        Net.lock_player_input(event.player_id)
        if event.button == simon_players[event.player_id]["current"] then 
            simon_players[event.player_id]["active"] = false
            Net.play_sound_for_player(event.player_id, "/server/assets/simon-says/correct.ogg")
            simon_players[event.player_id]["score"] = simon_players[event.player_id]["score"] + 1            
            await(games.erase_text("simon_says_answers",event.player_id))
            if simon_players[event.player_id]["score"] < 10 then
                games.write_text("simon_says_answers",event.player_id,"THICK","","0"..tostring(simon_players[event.player_id]["score"]),35,67,1)
            else
                games.write_text("simon_says_answers",event.player_id,"THICK","",simon_players[event.player_id]["score"],35,67,1)
            end 
            local area_id = Net.get_player_area(event.player_id)
            local actor_id = simon_players[event.player_id]["actor"]
            local simon = simon_cache[area_id][actor_id]

            --limit has not been reached, loop again
            if simon_players[event.player_id]["score"] < tonumber(simon.custom_properties["Limit"]) then
                await(Async.sleep(.05))
                simon_says_press(event.player_id)

            --limit has been reached, end game as winner
            elseif simon_players[event.player_id]["score"] >= tonumber(simon.custom_properties["Limit"]) then
                Net.unlock_player_input(event.player_id)

                games.pause_countdown(event.player_id)
                Net.play_sound_for_player(event.player_id, "/server/assets/simon-says/succeed.ogg")
                simon_players[event.player_id]["active"] = false
                await(Async.message_player(event.player_id, "Wonderful!! Congratulations!!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]))
                Net.fade_player_camera(event.player_id, {r=0,g=0,b=0,a=255}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
                await(Async.sleep(.75))
                games.remove_ui_element("board",event.player_id)
                games.remove_map_element("chat",event.player_id)
                games.remove_map_element("indicator",event.player_id)
                games.remove_countdown(event.player_id)
                await(games.erase_text("simon_says_answers",event.player_id))
                games.deactivate_framework(event.player_id)
                Net.fade_player_camera(event.player_id, {r=0,g=0,b=0,a=0}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
                await(Async.sleep(.75))

                Net.message_player(event.player_id, "Perfect! Clap-clap-clap!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 
                Net.message_player(event.player_id, "Thanks for playing!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]) 
                area_id = Net.get_player_area(event.player_id)
                actor_id = simon_players[event.player_id]["actor"]
                simon_cache[area_id][actor_id]['occupied'] = false
                simon_players[event.player_id] = nil
            end 

        else 
            if simon_players[event.player_id] ~= nil then 
                simon_players[event.player_id]["active"] = false
                Net.play_sound_for_player(event.player_id, "/server/assets/simon-says/wrong_answer.ogg")
                --shake display on chat bubble
                local actor_id = simon_players[event.player_id]["actor"]
                local area_id = simon_players[event.player_id]["area"]
                local simon = simon_cache[area_id][actor_id]

                games.move_map_element("indicator",event.player_id,simon.x-.125,simon.y-.875,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.1,simon.y-.9,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.075,simon.y-.95,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.1,simon.y-.9,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.125,simon.y-.875,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.1,simon.y-.9,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.075,simon.y-.95,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.1,simon.y-.9,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.125,simon.y-.875,simon.z+2)
                await(Async.sleep(.1))
                games.move_map_element("indicator",event.player_id,simon.x-.1,simon.y-.9,simon.z+2)
                await(Async.sleep(.1))
                simon_says_press(event.player_id)
            end 
        end 
    end 
    end 
end)
end)

Net:on("countdown_ended", function(event)
    return async(function ()
    simon_players[event.player_id]["active"] = false
    --time limit reached, end game as loser
    local area_id = Net.get_player_area(event.player_id)
    local actor_id = simon_players[event.player_id]["actor"]
    simon_cache[area_id][actor_id]['occupied'] = false
    simon_players[event.player_id] = nil
    local simon = simon_cache[area_id][actor_id]
    Net.play_sound_for_player(event.player_id, "/server/assets/simon-says/time_up.ogg")
    await(Async.message_player(event.player_id, "Too bad!! And you were so close, too. Please play again soon!", simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]))
    Net.fade_player_camera(event.player_id, {r=0,g=0,b=0,a=255}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
    await(Async.sleep(.75))
    games.remove_map_element("indicator",event.player_id)
    games.remove_ui_element("board",event.player_id)
    games.remove_map_element("chat",event.player_id)
    games.erase_text("simon_says_answers",event.player_id)
    games.remove_countdown(event.player_id)

    games.deactivate_framework(event.player_id)
    Net.fade_player_camera(event.player_id, {r=0,g=0,b=0,a=0}, .5) -- color = { r: 0-255, g: 0-255, b: 0-255, a?: 0-255 }
    await(Async.sleep(.75))
    end)
end)