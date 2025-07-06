

--[[
* ---------------------------------------------------------- *
          Net Games Demo by Indiana - Version 0.01
	      https://github.com/indianajson/net-games 
* ---------------------------------------------------------- *
]]--

--the below lines are required to start and access the framework
local games = require("scripts/net-games/framework")
games.start_framework()

--the rest is demo code for the demo server
local points = 8
local active = false 

Net:on("player_disconnect", function(event)
active = false
end)
games.Game:on("button_press", function(event)

    --print("Player ".. event.player_id .." pressed: "..event.button)
    if event.button == "LS" then
        if active == false then
            games.activate_framework(event.player_id)
            games.add_ui_element("points",event.player_id,"/server/assets/demo/order_points.png","/server/assets/demo/order_points.animation","8POINT",40,60,0)
            local green_cursor_texture = "/server/assets/net-games/text_cursor.png"
            local green_cursor_anim = "/server/assets/net-games/text_cursor.animation"
            navi_cursor = {
                movement = "horizontal", 
                selections = {
                    { v=30,h=-30,z=0,name='protoman',texture=green_cursor_texture,animation=green_cursor_anim,state="CURSOR_DOWN"  },
                    { v=30,h=0,z=0,name='megaman',texture=green_cursor_texture,animation=green_cursor_anim,state="CURSOR_DOWN"  },
                    { v=30,h=30,z=0,name='roll',texture=green_cursor_texture,animation=green_cursor_anim,state="CURSOR_DOWN" }
                }
            }
            games.spawn_countdown(event.player_id,0,0,0,10)
            games.start_countdown(event.player_id)
            games.spawn_timer(event.player_id,0,20,0)
            games.start_timer(event.player_id)
            active = true
        else
            if points > 0 then
                points = points - 1 
            else 
                points = 8
            end
            if points == 11 then
                --print("spawn")
                --games.freeze_player(event.player_id)

                --games.spawn_cursor("navi_select",event.player_id,navi_cursor)

                --games.freeze_player(event.player_id)
                --games.pause_countdown(event.player_id)
                --erase_text("navi_label",event.player_id)
                --move_ui_element('points',event.player_id,20,40,0)
            end
            if points == 10 then 
                --games.unfreeze_player(event.player_id)

            end 
            if points == 9 then
            end 
            if points == 3 then
            end 

            if points <= 8 then
                games.change_ui_element("points",event.player_id,tostring(points.."POINT"),true)
            end 
            --deactivate_framework(event.player_id)
        end 
    end
end)

games.Game:on("cursor_selection", function(event)
    print("Player ".. event.player_id .." used cursor "..event.cursor.." to select "..event.selection["name"])
    games.write_text("navi_label",event.player_id,"THICK","black",event.selection["name"],0,-10,0)
    games.remove_cursor("navi_select",event.player_id)
end)

games.Game:on("cursor_hover", function(event)
   print("Player ".. event.player_id .."used cursor "..event.cursor.." to hover over "..event.selection["name"])
end)

games.Game:on("button_press", function(event)
    --print("Player ".. event.player_id .." pressed: "..event.button)
end)

games.Game:on("countdown_ended", function(event)
    print("Countdown for player "..event.player_id.." finished.")
end)
