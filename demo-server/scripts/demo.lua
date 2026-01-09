
--[[
* ---------------------------------------------------------- *
          Net Games Demo by Indiana - Version 0.06
	      https://github.com/indianajson/net-games 
* ---------------------------------------------------------- *
]]--

--the below line is required to access net-games functions
local games = require("scripts/net-games/framework")
local NetHelpers = require("scripts/net-games/helpers/net-helpers")
NetHelpers.patch_net()

NetHelpers.safe_require("scripts/net-games/dialogue/startup")

-------------------------------------------
-- DEMO CODE FOR NPC THAT LITTERALLY JUST TALK (WOW) --
-------------------------------------------

require("scripts/net-games/npcs/prog_banner_dialogue")
require("scripts/net-games/npcs/prog_basic_dialogue")
require("scripts/net-games/npcs/prog_basic_freedraw")
require("scripts/net-games/npcs/prog_dramatic_dialogue")
require("scripts/net-games/npcs/prog_dyed_dialogue")
require("scripts/net-games/npcs/prog_prompt_dialogue")
require("scripts/net-games/npcs/prog_basic_nameplate")
require("scripts/net-games/npcs/prog_talk_dialogue")
require("scripts/net-games/npcs/prog_talk_colors")
require("scripts/net-games/npcs/prog_vert_prompt")
require("scripts/net-games/npcs/prog_vert_prompt_2")
require("scripts/net-games/npcs/prog_vert_prompt_sapphire")
require("scripts/net-games/npcs/prog_vert_prompt_pink")
require("scripts/net-games/npcs/prog_vert_prompt_lime")
require("scripts/net-games/npcs/prog_vert_prompt_charcoal_grey")
require("scripts/net-games/npcs/prog_vert_prompt_red")
require("scripts/net-games/npcs/prog_vert_prompt_emerald")
require("scripts/net-games/npcs/prog_shop")
-------------------------------------------
-- DEMO CODE FOR NPC THAT GIVES COSMETIC --
-------------------------------------------

Net.create_bot("cosmo", { area_id="default", warp_in=false, texture_path="/server/assets/demo/roll.png", animation_path="/server/assets/demo/roll.animation", x=25.5, y=18.5, z=0, solid=true})

local cosmo = {}

Net:on("actor_interaction", function(event)
    local cosmetic_id = "confetti"
    if event.actor_id == "cosmo" and event.button == 0 and (cosmo[event.player_id] ~= true) then
        local texture_path = "/server/assets/demo/shock.png"
        local animation_path = "/server/assets/demo/shock.animation"
        games.set_cosmetic(cosmetic_id, event.player_id, texture_path, animation_path, "cosmetic", 2, -40, true,-2)
        cosmo[event.player_id] = true
        Net.message_player(event.player_id, "Cosmetic enabled. So shiny!")
    elseif event.actor_id == "cosmo" and event.button == 0 and cosmo[event.player_id] == true then
        cosmo[event.player_id] = false
        games.remove_cosmetic(cosmetic_id, event.player_id)

        Net.message_player(event.player_id, "Cosmetic removed!")
    end
end)



----------------------------------------------------------
-- DEMO CODE FOR BASIC MARQUEE EXAMPLE [IN DEVELOPMENT] --
----------------------------------------------------------

local marquee_active = {}

Net.create_bot("marquee_demo", { 
    area_id="default", 
    warp_in=false, 
    texture_path="/server/assets/demo/cyber_bat.png", 
    animation_path="/server/assets/demo/cyber_bat.animation", 
    x=24, y=21, z=0, 
    solid=true
})

local backdrop_config = {
    x = 0,          -- Just set backdrop position
    y = 130,        -- Text will be automatically centered
    width = 240,    -- Width of the backdrop we currently are using
    height = 30,    -- Backdrop height (text will be centered within this)
    loops = 1,      -- (int : optional) Set loops to how many times you would like it to show before removing or using a custom `on_finish` function to be called when the loops for marquee text have completed.
                    --      - If nil or 0 is provided it will default to infinite be on screen until it is manually removed by the programmer.
--  EXTRA OPTIONAL FIELDS NOT LISTED ABOVE
--  on_finish     = (function : optional) some_x_function() end 
--      - If none is provided it will remove marquee text and its backdrop.
--  keep_backdrop = (bool : optional) true or false
--      - If none is provided then this will default to false.
}

Net:on("actor_interaction", function(event)
    if event.actor_id == "marquee_demo" and event.button == 0 and (marquee_active[event.player_id] ~= true) then
        -- Create a marquee with backdrop
        games.draw_marquee_text("demo_marquee", event.player_id, "Welcome to the Net Games Demo! This is a scrolling marquee text!", 15, "THICK", 2.0, 100, "medium", backdrop_config)
        marquee_active[event.player_id] = true
        Net.message_player(event.player_id, "Marquee text activated! Watch it scroll across the screen.")
    elseif event.actor_id == "marquee_demo" and event.button == 0 and marquee_active[event.player_id] == true then
        marquee_active[event.player_id] = false
        Net.message_player(event.player_id, "Marquee text was removed!")
        games.remove_text("demo_marquee", event.player_id)
    end
end)

Net:on("player_join", function(event)
    marquee_active[event.player_id] = false
end)

Net:on("player_disconnect", function(event)
    marquee_active[event.player_id] = false
end)

--------------------------------------------------------------
-- DEMO CODE FOR THE BAT NPC THAT SPAWNS THE ORDER POINT UI --
--------------------------------------------------------------

local bat_active = {} 

Net.create_bot("bat", { area_id="default", warp_in=false, texture_path="/server/assets/demo/cyber_bat.png", animation_path="/server/assets/demo/cyber_bat.animation", x=26, y=21, z=0, solid=true})

Net:on("virtual_input", function(event)
    if bat_active[event.player_id] == true then 
        for i,button in next,event.events do 
            if button.name == "Shoulder R" and button.state == 1 then 
                if points > 0 then
                    points = points - 1 
                    games.set_ui_animation("points",event.player_id,tostring(points.."POINT"),true)
                else
                    points = 8
                    games.set_ui_animation("points",event.player_id,tostring(points.."POINT"),true)
                end
            elseif button.name == "Shoulder L" and button.state == 1 then
                if points < 8 then
                    points = points + 1 
                    games.set_ui_animation("points",event.player_id,tostring(points.."POINT"),true)
                else
                    points = 0
                    games.set_ui_animation("points",event.player_id,tostring(points.."POINT"),true)
                end
            elseif button.name == "Move Down" or button.name == "Move Left" or button.name == "Move Right" or button.name == "Move Up" and button.state == 1 then
                games.remove_ui_element("points",event.player_id)
                bat_active[event.player_id] = false
                Net.unlock_player_input(event.player_id)
            end 
        end 
    end 
end)

Net:on("actor_interaction", function (event)

    if event.actor_id == "bat" and event.button == 0 and bat_active[event.player_id] == false then
        points = 8
        Net.message_player(event.player_id, "Press Left Shoulder to incfease and Right Shoulder to decrease. Press any arrow key to stop.","","") 
        Net.lock_player_input(event.player_id)
        games.add_ui_element("points",event.player_id,"/server/assets/demo/order_points.png","/server/assets/demo/order_points.animation","8POINT",161,2,0)
        bat_active[event.player_id] = true
    end 
end)

Net:on("player_join", function(event)
    bat_active[event.player_id] = false
end)

Net:on("player_disconnect", function(event)
    bat_active[event.player_id] = false
end)

----------------------------------------------------------------------
-- DEMO CODE FOR THE NPC THAT SPAWNS A CURSOR TO CHANGE IT'S AVATAR --
----------------------------------------------------------------------

local points = 8

Net.create_bot("changer", { area_id="default", warp_in=false, texture_path="/server/assets/demo/protoman-bn5.png", animation_path="/server/assets/demo/protoman-bn5.animation", animation="IDLE_DL", x=26, y=19.5, z=0, solid=true})

Net:on("cursor_selection", function(event)
    if event.cursor == "navi_changer" then
        print("Player ".. event.player_id .." used cursor "..event.cursor.." to select "..event.selection)
        games.remove_text("roll_label",event.player_id)
        games.remove_text("megaman_label",event.player_id)
        games.remove_text("protoman_label",event.player_id)
        games.remove_cursor("navi_changer",event.player_id)
        Net.unlock_player_input(event.player_id)

        local texture = ""
        local animation = ""
        if event.selection == "protoman" then
            texture = "/server/assets/demo/protoman-bn5.png"
            animation = "/server/assets/demo/protoman-bn5.animation"
        elseif event.selection == "roll" then
            texture = "/server/assets/demo/roll.png"
            animation = "/server/assets/demo/roll.animation"
        elseif event.selection == "megaman" then
            texture = "/server/assets/demo/megaman.png"
            animation = "/server/assets/demo/megaman.animation"    
        end 
        Net.provide_asset_for_player(event.player_id, texture)
        Net.provide_asset_for_player(event.player_id, animation)

        Net.set_bot_avatar("changer",texture,animation)
        local keyframes = {{properties={{property="Animation",value="IDLE_DL"}},duration=0}}
        Net.animate_bot_properties("changer", keyframes)

    end
end)

Net:on("actor_interaction", function (event)

    if event.actor_id == "changer" and event.button == 0 then

        local green_cursor_texture = "/server/assets/net-games/text_cursor.png"
        local green_cursor_anim = "/server/assets/net-games/text_cursor.animation"
        cursor_options = {
            texture=green_cursor_texture,
            animation=green_cursor_anim,
            movement = "vertical", 
            selections = {
                { x=35,y=45,z=0,name='roll',state="CURSOR_RIGHT" },
                { x=35,y=65,z=0,name='megaman',state="CURSOR_RIGHT" },
                { x=35,y=85,z=0,name='protoman',state="CURSOR_RIGHT" }
            }
        }

        games.spawn_cursor("navi_changer",event.player_id,cursor_options)
        games.draw_text("roll_label",event.player_id,"<Roll_EXE>",40,40,100,"BATTLE")
        games.draw_text("megaman_label",event.player_id,"Megaman_EXE",40,60,100,"BATTLE")
        games.draw_text("protoman_label",event.player_id,"<PROTOMAN_EXE>",40,80,100,"BATTLE")

    end 
end)
