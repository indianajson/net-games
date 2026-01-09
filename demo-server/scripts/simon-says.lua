--[[
* ---------------------------------------------------------- *
             CyberSimon Says (minigame) by Indiana
     (patched: lock/unlock input only, virtual_input gameplay)
* ---------------------------------------------------------- *
]]--

local games = require("scripts/net-games/framework")

local simon_cache = {}
local simon_players = {}
local simon_optional_properties = { "NPC", "NPC Mug", "Time", "Limit" }

local defaults = {
  time_limit = 60,
  default_npc = "/server/assets/simon-says/normal-navi-bn4_green",
  default_npc_mug = "/server/assets/simon-says/normal-navi-bn4_green-mug",
  total_answers = 60
}

-- Shorthand for async/await
local function async(p)
  local co = coroutine.create(p)
  return Async.promisify(co)
end
local function await(v) return Async.await(v) end

local function removeValue(array, valueToRemove)
  for i, v in ipairs(array) do
    if v == valueToRemove then
      table.remove(array, i)
      return
    end
  end
end

--=====================================================
-- Input/Indicator mapping (virtual_input -> indicator anim state)
--=====================================================
local INPUT_CHOICES = { "Interact", "Shoulder L", "Move Down", "Move Left", "Move Right", "Move Up" }

local INDICATOR_STATE = {
  ["Interact"]   = "A",
  ["Confirm"]    = "A",
  ["Shoulder L"] = "LS",
  ["Move Down"]  = "D",
  ["Move Left"]  = "L",
  ["Move Right"] = "R",
  ["Move Up"]    = "U",
}

local function is_simon_button(name)
  return name == "Interact" or name == "Confirm" or name == "Shoulder L"
      or name == "Move Up" or name == "Move Down" or name == "Move Left" or name == "Move Right"
end

--=====================================================
-- SPAWN SIMON NPCS
--=====================================================
local function spawn_simon()
  local areas = Net.list_areas()
  for _, area_id in next, areas do
    area_id = tostring(area_id)
    simon_cache[area_id] = simon_cache[area_id] or {}

    local objects = Net.list_objects(area_id)
    for _, object_id in next, objects do
      local object = Net.get_object_by_id(area_id, object_id)
      object_id = tostring(object_id)

      if object.type == "Simon Says" then
        local simon_id = object.name .. "-simon-" .. area_id
        simon_cache[area_id][simon_id] = object
        local simon_obj = simon_cache[area_id][simon_id]

        Net.remove_object(area_id, object_id)
        print("[simonsays] Found '" .. simon_obj.name .. "' playing Simon Says in " .. area_id .. ".tmx")

        for _, prop_name in pairs(simon_optional_properties) do
          if not simon_obj.custom_properties[prop_name] then
            print("   " .. prop_name .. " not set (default was used)")
          else
            print("   " .. prop_name .. " = " .. tostring(simon_obj.custom_properties[prop_name]))
          end
        end

        if not simon_obj.custom_properties["NPC"] then
          simon_obj.custom_properties["NPC Animation"] = defaults.default_npc .. ".animation"
          simon_obj.custom_properties["NPC Texture"]   = defaults.default_npc .. ".png"
        else
          simon_obj.custom_properties["NPC Animation"] = simon_obj.custom_properties["NPC"] .. ".animation"
          simon_obj.custom_properties["NPC Texture"]   = simon_obj.custom_properties["NPC"] .. ".png"
        end

        if not simon_obj.custom_properties["NPC Mug"] then
          simon_obj.custom_properties["NPC Mug Animation"] = defaults.default_npc_mug .. ".animation"
          simon_obj.custom_properties["NPC Mug Texture"]   = defaults.default_npc_mug .. ".png"
        else
          simon_obj.custom_properties["NPC Mug Animation"] = simon_obj.custom_properties["NPC Mug"] .. ".animation"
          simon_obj.custom_properties["NPC Mug Texture"]   = simon_obj.custom_properties["NPC Mug"] .. ".png"
        end

        if not simon_obj.custom_properties["Time"] then
          simon_obj.custom_properties["Time"] = defaults.time_limit
        end
        if not simon_obj.custom_properties["Limit"] then
          simon_obj.custom_properties["Limit"] = defaults.total_answers
        end

        Net.create_bot(simon_id, {
          name="",
          area_id=area_id,
          texture_path=simon_obj.custom_properties["NPC Texture"],
          animation_path=simon_obj.custom_properties["NPC Animation"],
          animation="IDLE_DR",
          x=simon_obj.x, y=simon_obj.y, z=simon_obj.z,
          solid=true,
          warp_in=false
        })
      end
    end
  end
end

spawn_simon()

-- Cleanup on disconnect (release occupancy + stop any half-running session)
Net:on("player_disconnect", function(event)
  local pid = event.player_id
  local p = simon_players[pid]
  if not p then return end

  local area_id = p.area or Net.get_player_area(pid)
  local actor_id = p.actor
  if simon_cache[area_id] and simon_cache[area_id][actor_id] then
    simon_cache[area_id][actor_id].occupied = false
  end

  simon_players[pid] = nil
end)

--=====================================================
-- GAME LOGIC
--=====================================================
local function simon_says_press(player_id)
  return async(function()
    local p = simon_players[player_id]
    if not p then return end

    local simon = simon_cache[p.area] and simon_cache[p.area][p.actor]
    if not simon then return end

    games.remove_map_element("indicator", player_id)
    await(Async.sleep(0.1))

    math.randomseed(os.time())

    local possibilities = {}
    for _, v in ipairs(INPUT_CHOICES) do possibilities[#possibilities+1] = v end
    removeValue(possibilities, p.current)

    local random_index = math.random(1, #possibilities)
    p.current = possibilities[random_index]
    p.active = true

    local indicator_state = INDICATOR_STATE[p.current] or "A"

    games.add_map_element(
      "indicator",
      player_id,
      "/server/assets/simon-says/indicators.png",
      "/server/assets/simon-says/indicators.animation",
      indicator_state,
      simon.x - 0.1,
      simon.y - 0.9,
      simon.z + 2
    )

    -- IMPORTANT: do NOT unlock input here. Game is played via virtual_input while locked.
  end)
end

local function end_game_cleanup(player_id, reason, simon)
  return async(function()
    -- stop prompt loop
    local p = simon_players[player_id]
    if p then p.active = false end

    Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=255}, 0.5)
    await(Async.sleep(0.75))

    games.remove_ui_element("board", player_id)
    games.remove_map_element("chat", player_id)
    games.remove_map_element("indicator", player_id)
    games.remove_countdown("simon_says", player_id)
    games.remove_text("simon_says_answers", player_id)

    Net.toggle_player_hud(player_id)

    Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=0}, 0.5)
    await(Async.sleep(0.75))

    if simon then simon.occupied = false end
    simon_players[player_id] = nil

    Net.unlock_player_input(player_id)
  end)
end

local function greet_simon(actor_id, player_id)
  return async(function()
    local area_id = Net.get_player_area(player_id)
    local simon = simon_cache[area_id] and simon_cache[area_id][actor_id]
    if not simon then return end

    if simon.occupied == true then
      Net.message_player(
        player_id,
        "CyberSimon Says... give me a minute to finish this game.",
        simon.custom_properties["NPC Mug Texture"],
        simon.custom_properties["NPC Mug Animation"]
      )
      return
    end

    simon.occupied = true

    local decision = await(Async.question_player(
      player_id,
      "Hey, you! Wanna play a little game?",
      simon.custom_properties["NPC Mug Texture"],
      simon.custom_properties["NPC Mug Animation"]
    ))

    if decision ~= 1 then
      simon.occupied = false
      Net.message_player(
        player_id,
        "Aw, c'mon. Are you sure? Oh well.",
        simon.custom_properties["NPC Mug Texture"],
        simon.custom_properties["NPC Mug Animation"]
      )
      return
    end

    -- Setup phase: lock so nothing weird happens while we fade/toggle HUD/UI
    Net.lock_player_input(player_id)

    simon_players[player_id] = simon_players[player_id] or {}
    local p = simon_players[player_id]
    p.actor = actor_id
    p.area = area_id
    p.score = 0
    p.active = false
    p.current = nil
    p["return"] = Net.get_player_position(player_id) -- kept, even though we don't move them

    Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=255}, 0.5)
    await(Async.sleep(0.75))

    Net.toggle_player_hud(player_id)

    games.add_ui_element(
      "board",
      player_id,
      "/server/assets/simon-says/board.png",
      "/server/assets/simon-says/board.animation",
      "UI",
      2, 2, 100
    )

    games.spawn_countdown("simon_says", player_id, 22, 15, simon.custom_properties["Time"] + 1, false)
    await(Async.sleep(0.1))
    games.pause_countdown("simon_says", player_id)

    games.draw_text("simon_says_answers", player_id, "00", 32, 39, 100, "THICK")

    Net.fade_player_camera(player_id, {r=0,g=0,b=0,a=0}, 0.5)
    await(Async.sleep(0.75))

    -- Allow dialogue to advance normally
    Net.unlock_player_input(player_id)

    Net.message_player(player_id, "Now it's time for... \"CyberSimon Says\"! Yeahh! Whoo! Whoo!",
      simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"])
    Net.message_player(player_id, "All you have to do is push the button that I tell you to!",
      simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"])
    Net.message_player(player_id, "The time limit is... " .. tostring(simon.custom_properties["Time"]) .. " seconds!",
      simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"])
    Net.message_player(player_id, "You win if you can press the correct button " .. tostring(simon.custom_properties["Limit"]) .. " times!",
      simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"])
    await(Async.message_player(player_id, "Good luck!",
      simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]))

    await(Async.sleep(1)); Net.play_sound_for_player(player_id, "/server/assets/simon-says/count.ogg")
    await(Async.sleep(1)); Net.play_sound_for_player(player_id, "/server/assets/simon-says/count.ogg")
    await(Async.sleep(1)); Net.play_sound_for_player(player_id, "/server/assets/simon-says/count.ogg")
    await(Async.sleep(1)); Net.play_sound_for_player(player_id, "/server/assets/simon-says/game_start.ogg")

    games.add_map_element(
      "chat",
      player_id,
      "/server/assets/simon-says/chat.png",
      "/server/assets/simon-says/chat.animation",
      "UI",
      simon.x - 0.8,
      simon.y - 1.1,
      simon.z
    )

    -- NOW start the minigame:
    -- lock input so movement stops AND virtual_input events fire
    Net.lock_player_input(player_id)

    games.resume_countdown("simon_says", player_id)

    await(Async.sleep(0.05))
    simon_says_press(player_id)
  end)
end

-- Talk to Simon bot
Net:on("actor_interaction", function(event)
  if event.button == 0 and string.find(event.actor_id, "-simon-") then
    greet_simon(event.actor_id, event.player_id)
  end
end)

-- Main gameplay input: virtual_input ONLY (because we keep the player locked)
Net:on("virtual_input", function(event)
  return async(function()
    local pid = event.player_id
    local p = simon_players[pid]
    if not p or p.active ~= true then return end

    -- Only process one valid press per prompt.
    -- We treat state==1 (pressed) and state==4 (held repeat) as “a press”.
    for _, btn in next, event.events do
      local pressed = (btn.state == 1 or btn.state == 4)
      if pressed and is_simon_button(btn.name) then
        local name = btn.name
        if name == "Confirm" then name = "Interact" end

        -- consume this prompt
        p.active = false

        if name == p.current then
          Net.play_sound_for_player(pid, "/server/assets/simon-says/correct.ogg")
          p.score = (p.score or 0) + 1

          if p.score < 10 then
            games.update_text("simon_says_answers", pid, "0" .. tostring(p.score))
          else
            games.update_text("simon_says_answers", pid, tostring(p.score))
          end

          local simon = simon_cache[p.area] and simon_cache[p.area][p.actor]
          if not simon then return end

          if p.score < tonumber(simon.custom_properties["Limit"]) then
            await(Async.sleep(0.08))
            simon_says_press(pid)
            return
          end

          -- WIN
          games.pause_countdown("simon_says", pid)
          Net.play_sound_for_player(pid, "/server/assets/simon-says/succeed.ogg")

          await(Async.message_player(pid, "Wonderful!! Congratulations!!",
            simon.custom_properties["NPC Mug Texture"], simon.custom_properties["NPC Mug Animation"]))

          await(end_game_cleanup(pid, "win", simon))
          return

        else
          -- WRONG
          Net.play_sound_for_player(pid, "/server/assets/simon-says/wrong_answer.ogg")

          local simon = simon_cache[p.area] and simon_cache[p.area][p.actor]
          if simon then
            local function jiggle(dx, dy)
              games.move_map_element("indicator", pid, simon.x + dx, simon.y + dy, simon.z + 2)
            end
            jiggle(-0.125, -0.875); await(Async.sleep(0.1))
            jiggle(-0.10,  -0.90 ); await(Async.sleep(0.1))
            jiggle(-0.075, -0.95 ); await(Async.sleep(0.1))
            jiggle(-0.10,  -0.90 ); await(Async.sleep(0.1))
          end

          await(Async.sleep(0.08))
          simon_says_press(pid)
          return
        end
      end
    end
  end)
end)

-- Time-out loss
Net:on("countdown_ended", function(event)
  return async(function()
    local pid = event.player_id
    local p = simon_players[pid]
    if not p then return end
    p.active = false

    local simon = simon_cache[p.area] and simon_cache[p.area][p.actor]

    if simon then
      Net.play_sound_for_player(pid, "/server/assets/simon-says/time_up.ogg")
      await(Async.message_player(pid,
        "Too bad!! And you were so close, too. Please play again soon!",
        simon.custom_properties["NPC Mug Texture"],
        simon.custom_properties["NPC Mug Animation"]
      ))
    end

    await(end_game_cleanup(pid, "timeout", simon))
  end)
end)
