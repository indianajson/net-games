--[[
* ---------------------------------------------------------- *
           Net Games (framework) - Version 0.08
	     https://github.com/indianajson/net-games/   
* ---------------------------------------------------------- *

]]--

local Displayer = require("scripts/net-games/displayer/displayer") --module by D3str0y3d to handle text, timers, countdowns using v2.1
local AnimationEngine = require("scripts/net-games/animation-engine/animation-engine") -- Animation engine for sprite animations
local AnimationSequences = require("scripts/net-games/animation-engine/animation-sequences") -- Pre-built animation sequences

if not Displayer:init() or not Displayer:isValid() then
    print("Failed to initialize Displayer API")
    return false
end

local frame = {} --holds the framework functions and returns them to whatever script is calling them
local last_position_cache = {} --legacy cache that only tracks player's area now
local button_states = {} --cache of latest button states from player
local tracking_state = {} --tracks if a player's button state has remained 2 for more than x seconds
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

--purpose: checks if a string follows a valid x,Y,Z pattern
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

-- Helper function to normalize color tables
local function normalize_color(color)
    if not color then return nil end
    
    if type(color) == "table" then
        -- Check if it's a table with r,g,b,a keys
        if color.r or color[1] then
            return {
                r = color.r or color[1] or 255,
                g = color.g or color[2] or 255,
                b = color.b or color[3] or 255,
                a = color.a or color[4] or 255
            }
        end
    end
    return nil
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
        ox = 0,
        oy = 0,
        ro = 0,
        opacity = 255,
        a = 255,
        r = 255,
        g = 255,
        b = 255,
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

function frame.add_map_element(name,player_id,texture,animation,animation_state,x,y,z,exclude)
    
    --spawn map object
    
local area_id =
  (last_position_cache[player_id] and last_position_cache[player_id]["area"])
  or Net.get_player_area(player_id)

    Net.create_bot(player_id.."-map-"..name, { area_id=area_id, warp_in=false, texture_path=texture, animation_path=animation, animation=animation_state,x=x, y=y, z=z, solid=false})

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

function frame.move_map_element(name,player_id,x,y,z)
local area_id =
  (last_position_cache[player_id] and last_position_cache[player_id]["area"])
  or Net.get_player_area(player_id)

Net.transfer_bot(player_id.."-map-"..name, area_id, false, x, y, z)

end

--purpose: removes UI element from screen
function frame.remove_map_element(name,player_id)
    if Net.is_bot(player_id.."-map-"..name) then 
        map_elements[player_id][name] = nil
        Net.remove_bot(player_id.."-map-"..name,false)
    end
end

-- UI ANIMATION FUNCTIONS USING PRE-BUILT SEQUENCES
-- Functions that apply pre-built animation sequences from animation-sequences.lua to UI elements


-- purpose: Apply set animation to UI element (with flip and rotation)
function frame.set_ui_element(sprite_id, player_id, start_x, start_y, start_scale, start_ro,
                             end_x, end_y, end_scale, end_ro, options)
    return frame.apply_ui_effect(sprite_id, player_id, "set", {
        start_x = start_x,
        start_y = start_y,
        start_scale = start_scale,
        start_ro = start_ro,
        end_x = end_x,
        end_y = end_y,
        end_scale = end_scale,
        end_ro = end_ro,
        options = options
    })
end

-- purpose: Apply position change animation (rotate and reveal)
function frame.position_change_ui_element(sprite_id, player_id, start_ro, end_ro, options)
    return frame.apply_ui_effect(sprite_id, player_id, "position_change", {
        start_ro = start_ro,
        end_ro = end_ro,
        options = options
    })
end

-- purpose: Apply attack animation (recoil then lunge)
function frame.attack_ui_element(sprite_id, player_id, recoil_offset, lunge_offset, options)
    return frame.apply_ui_effect(sprite_id, player_id, "attack", {
        recoil_offset = recoil_offset,
        lunge_offset = lunge_offset,
        options = options
    })
end

-- purpose: Apply slide-in animation
function frame.slide_in_ui_element(sprite_id, player_id, start_x, start_y, end_x, end_y, options)
    return frame.apply_ui_effect(sprite_id, player_id, "slide_in", {
        start_x = start_x,
        start_y = start_y,
        end_x = end_x,
        end_y = end_y,
        options = options
    })
end

---------------------------------------------
-- TESTED AND WORKING PRE-BUILT ANIMATIONS --
---------------------------------------------


-- Purpose: Apply Bob to a UI element with proper implementation --
function frame.bob_ui_element(sprite_id, player_id, distance, duration, easing, loop, ping_pong)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    local start_y = element.y or 0
    distance = distance or 3
    duration = duration or 1.0
    easing = easing or "smoothstep"
    loop = loop or true
    ping_pong = ping_pong or true
    
    -- Create a proxy object that the AnimationEngine can work with
    local proxy = {
        y = start_y,
        setPosition = function(self, x, y)
            element.y = y
            frame.update_ui_element(sprite_id, player_id, {y = y})
        end
    }
    
    -- Use AnimationEngine directly for bob animation
    local anim_id = AnimationEngine.animate(
        {y = start_y},
        {y = start_y - distance},
        duration,
        {
            easing = easing,
            on_update = function(values)
                element.y = values.y
                frame.update_ui_element(sprite_id, player_id, {x= values.x, y = values.y})
            end,
            loop = loop,
            ping_pong = ping_pong
        }
    )
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Pulse the scale of a UI element (scale up and down)
function frame.pulse_scale_ui_element(sprite_id, player_id, min_scale, max_scale, pulse_duration, easing, loops, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    local current_scale = element.sx or 2.0
    min_scale = min_scale or current_scale * 0.9
    max_scale = max_scale or current_scale * 1.1
    pulse_duration = pulse_duration or 0.5
    
    local anim_id = AnimationEngine.animate(
        {scale = min_scale},
        {scale = max_scale},
        pulse_duration / 2,
        {
            easing = easing or "ease_in_out",
            on_update = function(values)
                local update_props = {sx = values.scale, sy = values.scale}
                frame.update_ui_element(sprite_id, player_id, update_props)
            end,
            on_complete = on_complete,
            loop = loops or 1,
            ping_pong = true
        }
    )
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Apply color pulse from current color to a UI element (go from original color to target_color)
function frame.color_pulse_from_current(sprite_id, player_id, target_color)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    -- Use current color as start
    local element = ui_cache[player_id][sprite_id]
    local current_color = {
        r = element.r or 255,
        g = element.g or 255,
        b = element.b or 255,
        a = element.a or 255
    }
    
    return frame.color_pulse_scale_ui_element(sprite_id, player_id, current_color, target_color)
end

-- purpose: Apply summon animation to UI element (flies with arc)
function frame.summon_ui_element(sprite_id, player_id, start_x, start_y, start_scale, 
                                end_x, end_y, end_scale, duration, arc_height, peak_scale_mul, wobble_deg, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    -- Get animation parameters from options or use defaults
    local duration = duration or 0.25
    local arc_height = arc_height or 24
    local peak_scale_mul = peak_scale_mul or 1.35
    local wobble_deg = wobble_deg or 5
    local easing = easing or "ease_in_out"
    local on_complete = on_complete
    
    -- Set initial position and scale
    frame.update_ui_element(sprite_id, player_id, {
        x = start_x,
        y = start_y,
        sx = start_scale,
        sy = start_scale
    })
    
    -- Calculate control point for the quadratic bezier (arc)
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    local anim_id = nil
    -- Use AnimationEngine.animate with a custom on_update for the arc movement
    anim_id = AnimationEngine.animate(
        {progress = 0},
        {progress = 1},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local t = values.progress
                
                -- Calculate bezier position
                local u = 1 - t
                local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
                local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
                
                -- Calculate scale with pulse
                local base_scale = start_scale + (end_scale - start_scale) * t
                local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
                local current_scale = base_scale * pulse
                
                -- Calculate rotation wobble
                local rotation = 0
                if wobble_deg ~= 0 then
                    rotation = math.sin(math.pi * 2 * t) * wobble_deg * (1 - t)
                end
                
                -- Update the UI element
                frame.update_ui_element(sprite_id, player_id, {
                    x = x,
                    y = y,
                    sx = current_scale,
                    sy = current_scale,
                    ro = rotation
                })
            end,
            on_complete = function(values, interrupted)
                -- Ensure we end at the target position and scale
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, {
                        x = end_x,
                        y = end_y,
                        sx = end_scale,
                        sy = end_scale,
                        ro = 0
                    })
                end
                
                -- Call user callback if provided
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                -- Clean up animation tracking
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end
        }
    )
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end


---------------------------------------------
-- TESTED AND WORKING PRE-BUILT ANIMATIONS --
---------------------------------------------

-- purpose: Apply complex summon animation (all effects)
function frame.complex_summon_ui_element(sprite_id, player_id, start_x, start_y, start_scale,
                                        end_x, end_y, end_scale, arc_duration, wobble_duration, settle_duration, arc_height, peak_scale_mul, wobble_deg, easing, on_complete, on_update_step1, on_update_step2, on_update_step3)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    -- Get animation parameters from options or use defaults
    local arc_duration = arc_duration or 0.25
    local wobble_duration = wobble_duration or 0.1
    local settle_duration = settle_duration or 0.05
    local arc_height = arc_height or 40
    local peak_scale_mul = peak_scale_mul or 1.35
    local wobble_deg = wobble_deg or 10
    local easing = easing or "ease_in_out"
    local on_complete = on_complete
    local on_update_step1 = on_update_step1
    local on_update_step2 = on_update_step2
    local on_update_step3 = on_update_step3
    
    -- Set initial position and scale
    frame.update_ui_element(sprite_id, player_id, {
        x = start_x,
        y = start_y,
        sx = start_scale,
        sy = start_scale,
        ro = 0
    })
    
    -- Calculate control point for the quadratic bezier (arc)
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    
    -- Create a sequence for the complex summon (arc -> wobble -> settle)
    local sequence_steps = {}
    
    -- Step 1: Arc movement with scale pulse
    table.insert(sequence_steps, {
        type = "animate",
        duration = arc_duration,
        easing = easing,
        on_update = function(values, t, phase)
            -- Calculate bezier position for arc
            local u = 1 - t
            local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
            local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
            
            -- Calculate scale with pulse
            local base_scale = start_scale + (end_scale - start_scale) * t
            local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
            local current_scale = base_scale * pulse
            
            -- Update the UI element
            frame.update_ui_element(sprite_id, player_id, {
                x = x,
                y = y,
                sx = current_scale,
                sy = current_scale,
                ro = 0
            })
            
            if on_update_step1 then
                on_update_step1({x = x, y = y, scale = current_scale, progress = t})
            end
        end
    })
    
    -- Step 2: Rotation wobble (if wobble_deg is specified)
    if wobble_deg and wobble_deg > 0 then
        table.insert(sequence_steps, {
            type = "animate",
            duration = wobble_duration,
            easing = "elastic_out",
            on_update = function(values, t, phase)
                -- Calculate decaying wobble rotation
                local wobble = math.sin(t * math.pi * 4) * wobble_deg * (1 - t)
                
                -- Update only rotation, keep position and scale from previous step
                frame.update_ui_element(sprite_id, player_id, {
                    ro = wobble
                })
                
                if on_update_step2 then
                    on_update_step2({rotation = wobble, progress = t})
                end
            end
        })
    end
    
    -- Step 3: Final settle
    table.insert(sequence_steps, {
        type = "animate",
        duration = settle_duration,
        easing = "bounce_out",
        on_update = function(values, t, phase)
            -- Final scale adjustment (slight overshoot and settle)
            local settle_scale = end_scale * (1 - 0.05 * (1 - t))
            
            -- Update scale and reset rotation
            frame.update_ui_element(sprite_id, player_id, {
                sx = settle_scale,
                sy = settle_scale,
                ro = 0
            })
            
            if on_update_step3 then
                on_update_step3({scale = settle_scale, progress = t})
            end
        end,
        on_complete = function(values, interrupted)
            -- Ensure we end at the exact target position and scale
            if not interrupted then
                frame.update_ui_element(sprite_id, player_id, {
                    x = end_x,
                    y = end_y,
                    sx = end_scale,
                    sy = end_scale,
                    ro = 0
                })
            end
            
            -- Call user callback if provided
            if on_complete then
                on_complete(values, interrupted)
            end
        end
    })
    
    local seq_id = nil
    -- Create and start the sequence
    seq_id = AnimationEngine.create_sequence(sequence_steps, {
        id = "complex_summon_" .. sprite_id .. "_" .. player_id .. "_" .. math.random(1000, 9999),
        on_complete = function()
            -- Clean up sequence tracking
            if element.animations and seq_id then
                element.animations[seq_id] = nil
            end
        end
    })
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[seq_id] = true
    
    -- Start the sequence
    AnimationEngine.start_sequence(seq_id)
    
    return seq_id
end
-- purpose: Apply fade animation to UI element
function frame.fade_ui_element_to(sprite_id, player_id, target_opacity, duration, easing, on_complete, loop, ping_pong, easing_back)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    loop = loop or false
    ping_pong = ping_pong or false
    easing_back = easing_back or easing
    
    -- Get current opacity
    local current_opacity = element.opacity or 255
    target_opacity = math.max(0, math.min(255, target_opacity or 0))
    
    -- Use AnimationEngine for fade animation
    local anim_id = AnimationEngine.animate(
        {opacity = current_opacity},
        {opacity = target_opacity},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {opacity = math.floor(values.opacity)})
            end,
            on_complete = function(values, interrupted)
                -- Ensure final opacity is set
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, {opacity = target_opacity})
                end
                
                -- Call user callback if provided
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                -- Clean up animation tracking
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = loop,
            ping_pong = ping_pong,
            max_cycles = type(loop) == "number" and loop or nil
        }
    )
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- purpose: Apply tint animation (color change) to UI element
function frame.tint_ui_element_to(sprite_id, player_id, r, g, b, duration, easing, on_complete, loop, ping_pong, easing_back)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    duration = duration or 0.25
    easing = easing or "ease_in_out"
    loop = loop or false
    ping_pong = ping_pong or false
    easing_back = easing_back or easing
    
    -- Get current color
    local current_r = element.r or 255
    local current_g = element.g or 255
    local current_b = element.b or 255
    
    -- Clamp target values
    r = math.max(0, math.min(255, r or 255))
    g = math.max(0, math.min(255, g or 255))
    b = math.max(0, math.min(255, b or 255))
    
    -- Use AnimationEngine for tint animation
    local anim_id = AnimationEngine.animate(
        {r = current_r, g = current_g, b = current_b},
        {r = r, g = g, b = b},
        duration,
        {
            easing = easing,
            easing_back = easing_back,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    r = math.floor(values.r),
                    g = math.floor(values.g),
                    b = math.floor(values.b)
                })
            end,
            on_complete = function(values, interrupted)
                -- Ensure final color is set
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, {
                        r = r,
                        g = g,
                        b = b
                    })
                end
                
                -- Call user callback if provided
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                -- Clean up animation tracking
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = loop,
            ping_pong = ping_pong,
            max_cycles = type(loop) == "number" and loop or nil
        }
    )
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- purpose: Apply menu cursor animation (bob + pulse) to UI element
function frame.menu_cursor_ui_element(sprite_id, player_id, bob_distance, pulse_scale, bob_duration, pulse_duration, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    bob_distance = bob_distance or 2
    pulse_scale = pulse_scale or 1.1
    bob_duration = bob_duration or 0.8
    pulse_duration = pulse_duration or (bob_duration * 1.5)
    
    local start_y = element.y or 0
    local start_scale = element.sx or 2.0
    
    -- Start bob animation
    local bob_id = AnimationEngine.animate(
        {y = start_y},
        {y = start_y - bob_distance},
        bob_duration,
        {
            easing = "smoothstep",
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {y = values.y})
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    -- Start pulse animation
    local pulse_id = AnimationEngine.animate(
        {scale = 1.0},
        {scale = pulse_scale},
        pulse_duration,
        {
            easing = "ease_in_out",
            on_update = function(values)
                local scale = start_scale * values.scale
                frame.update_ui_element(sprite_id, player_id, {
                    sx = scale,
                    sy = scale
                })
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    -- Track animations
    if not element.animations then
        element.animations = {}
    end
    element.animations[bob_id] = true
    element.animations[pulse_id] = true
    
    -- Return animation IDs for potential control
    return {
        bob = bob_id,
        pulse = pulse_id,
        stop = function()
            AnimationEngine.stop_animation(bob_id)
            AnimationEngine.stop_animation(pulse_id)
            if element.animations then
                element.animations[bob_id] = nil
                element.animations[pulse_id] = nil
            end
            if on_complete then
                on_complete()
            end
        end
    }
end

-- purpose: Apply card highlight animation (lift + glow) to UI element
function frame.highlight_card_ui_element(sprite_id, player_id, lift_amount, glow_alpha, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    lift_amount = lift_amount or 5
    glow_alpha = glow_alpha or 100
    duration = duration or 0.15
    easing = easing or "ease_out"
    
    local start_y = element.y or 0
    local start_alpha = element.opacity or 255
    local anim_id = nil
    -- Use AnimationEngine for highlight animation
    anim_id = AnimationEngine.animate(
        {y = start_y, alpha = start_alpha},
        {y = start_y - lift_amount, alpha = glow_alpha},
        duration,
        {
            easing = easing,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    y = values.y,
                    opacity = math.floor(values.alpha)
                })
            end,
            on_complete = function(values, interrupted)
                -- Clean up animation tracking
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
                
                -- Call user callback if provided
                if on_complete and not interrupted then
                    on_complete()
                end
            end
        }
    )
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- purpose: Apply instant transition (no animation)
function frame.set_ui_element_instant(sprite_id, player_id, properties)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    -- Update cache with new properties
    for key, value in pairs(properties) do
        if element[key] ~= nil then
            element[key] = value
        end
    end
    
    -- Update UI element immediately
    frame.update_ui_element(sprite_id, player_id, properties)
end

-- purpose: Reset UI element to its initial state
function frame.reset_ui_element(sprite_id, player_id, initial_values)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return
    end
    
    -- Stop any active animations first
    frame.stop_ui_animation(sprite_id, player_id)
    
    -- Use instant set to reset values
    local element = ui_cache[player_id][sprite_id]
    local reset_props = initial_values or {
        x = element.x or 0,
        y = element.y or 0,
        sx = element.sx or 2.0,
        sy = element.sy or 2.0,
        ro = element.ro or 0,
        opacity = element.opacity or 255,
        r = element.r or 255,
        g = element.g or 255,
        b = element.b or 255,
        animation_state = element.animation_state or ""
    }
    
    frame.set_ui_element_instant(sprite_id, player_id, reset_props)
end


-- NEW FUNCTION: Apply color pulse animation to UI element
function frame.color_pulse_ui_element(sprite_id, player_id, start_color, target_color)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    -- Normalize colors
    start_color = normalize_color(start_color)
    target_color = normalize_color(target_color)
    
    -- If start_color is not provided, use current color from element
    if not start_color then
        start_color = {
            r = element.r or 255,
            g = element.g or 255,
            b = element.b or 255,
            a = element.a or 255
        }
    end
    
    -- Create a proxy object for the UI element
    local proxy = {
        r = element.r or 255,
        g = element.g or 255,
        b = element.b or 255,
        a = element.a or 255,
        
        setColor = function(self, r, g, b)
            element.r = r
            element.g = g
            element.b = b
            frame.update_ui_element(sprite_id, player_id, {r = r, g = g, b = b})
        end,
        
        setAlpha = function(self, alpha)
            element.opacity = alpha
            frame.update_ui_element(sprite_id, player_id, {a = alpha})
        end
    }
    
    -- Use AnimationSequences.color_pulse
    local anim_id = AnimationSequences.color_pulse(proxy, start_color, target_color)
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end


-- NEW FUNCTION: Simple color pulse with RGB values
function frame.color_pulse_rgb(sprite_id, player_id, start_r, start_g, start_b, start_a, 
                               target_r, target_g, target_b, target_a)
    local start_color = {
        r = start_r or 255,
        g = start_g or 255,
        b = start_b or 255,
        a = start_a or 255
    }
    
    local target_color = {
        r = target_r or 255,
        g = target_g or 255,
        b = target_b or 255,
        a = target_a or start_color.a
    }
    
    return frame.color_pulse_ui_element(sprite_id, player_id, start_color, target_color)
end

-- NEW FUNCTION: Check if a UI element has active animations
function frame.has_active_animations(sprite_id, player_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    local element = ui_cache[player_id][sprite_id]
    return element.animations and next(element.animations) ~= nil
end


-- NEW FUNCTION: Check if a specific animation is running on a UI element
function frame.is_animation_running(sprite_id, player_id, anim_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    local element = ui_cache[player_id][sprite_id]
    return element.animations and element.animations[anim_id] == true
end

-- NEW FUNCTION: Pause all animations for a UI element
function frame.pause_ui_animations(sprite_id, player_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    -- Note: The current AnimationEngine doesn't have pause functionality
    -- You would need to add this to AnimationEngine first
    print("[games] Pause functionality not yet implemented in AnimationEngine")
    return false
end

-- NEW FUNCTION: Resume all animations for a UI element
function frame.resume_ui_animations(sprite_id, player_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    -- Note: The current AnimationEngine doesn't have pause/resume functionality
    print("[games] Resume functionality not yet implemented in AnimationEngine")
    return false
end

-- NEW FUNCTION: Get UI element properties
function frame.get_ui_element_properties(sprite_id, player_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    return {
        x = element.x,
        y = element.y,
        z = element.z,
        sx = element.sx,
        sy = element.sy,
        ro = element.ro,
        opacity = element.opacity,
        a = element.a,
        r = element.r,
        g = element.g,
        b = element.b,
        color_mode = element.color_mode,
        animation_state = element.animation_state,
        has_animations = element.animations and next(element.animations) ~= nil
    }
end

--purpose: places a UI element on screen... that's it. Yes, it's complicated. No, I won't explain it. Blame Jams!
function frame.add_ui_element(sprite_id,player_id,texture_path,animation_path,animation_state,x,y,z,sx,sy)

    local sx = 2.0
    local sy = 2.0
    if sx ~= nil then
        if sx >= 0.0 then
            sx = sx
        end
    end
      if sy ~= nil then
        if sy >= 0.0 then
            sy = sy
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
            x = x*2 or 0, 
            y = y*2 or 0,
            z = z*2 or 0, 
            sx = sx,
            sy = sy,
            ro= 0,
            ox = 0,
            oy = 0,
            a = 255,
            r = 255,
            g = 255,
            b = 255,
            color_mode = 0,
            animation_state=animation_state,
            opacity=255,
        }
    )

    if ui_cache[player_id] == nil then
        ui_cache[player_id] = {}
    end 
    --includes UI element in UI cache for player so we can track sprites
    ui_cache[player_id][sprite_id] = {
        texture_path=texture_path, 
        sprite_id=new_sprite_id, 
        x=x, y=y, z=z or 0,
        sx=sx, sy=sy, 
        ro=0,
        ox = 0,
        oy = 0,
        a = 255,
        r = 255,
        g = 255,
        b = 255,
        color_mode = 0,
        animation_state=animation_state,
        opacity=255,
        animations = {} -- Track active animations for this element
    }
end

--purpose: allows you to update any property of a sprite element 
function frame.update_ui_element(sprite_id,player_id,properties)
    --write logic to only update elements that need to be updated. 
    local sprite_data = {id = sprite_id .. "_obj"}
    
    -- Update cache and prepare sprite data
    if properties["x"] then 
        sprite_data["x"] = properties["x"] * 2
        ui_cache[player_id][sprite_id]["x"] = properties["x"]
    end 
    if properties["y"] then 
        sprite_data["y"] = properties["y"] * 2
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
        ui_cache[player_id][sprite_id]["sx"] = properties["scale"]
        sprite_data["sy"] = properties["scale"]
        ui_cache[player_id][sprite_id]["sy"] = properties["scale"]
    end 
    if properties["sx"] then 
        sprite_data["sx"] = properties["sx"]
        ui_cache[player_id][sprite_id]["sx"] = properties["sx"]
    end 
    if properties["sy"] then 
        sprite_data["sy"] = properties["sy"]
        ui_cache[player_id][sprite_id]["sy"] = properties["sy"]
    end 
    if properties["ro"] then 
        sprite_data["ro"] = properties["ro"]
        ui_cache[player_id][sprite_id]["ro"] = properties["ro"]
    end 
    if properties["opacity"] then 
        sprite_data["opacity"] = properties["opacity"]
        ui_cache[player_id][sprite_id]["opacity"] = properties["opacity"]
    end 
    if properties["a"] then 
        sprite_data["a"] = properties["a"]
        ui_cache[player_id][sprite_id]["a"] = properties["a"]
    end 
    if properties["r"] then 
        sprite_data["r"] = properties["r"]
        ui_cache[player_id][sprite_id]["r"] = properties["r"]
    end 
    if properties["g"] then 
        sprite_data["g"] = properties["g"]
        ui_cache[player_id][sprite_id]["g"] = properties["g"]
    end 
    if properties["b"] then 
        sprite_data["b"] = properties["b"]
        ui_cache[player_id][sprite_id]["b"] = properties["b"]
    end 
    if properties["color_mode"] then 
        sprite_data["color_mode"] = properties["color_mode"]
        ui_cache[player_id][sprite_id]["color_mode"] = properties["color_mode"]
    end 
    if properties["animation_state"] then 
        sprite_data["animation_state"] = properties["animation_state"]
        ui_cache[player_id][sprite_id]["animation_state"] = properties["animation_state"]
    end 
    
    Net.player_draw_sprite(player_id, ui_cache[player_id][sprite_id]["sprite_id"], sprite_data)
end

-- purpose: Apply shake animation to UI element (screen shake effect)
function frame.shake_ui_element(sprite_id, player_id, intensity, duration, frequency, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    intensity = intensity or 5
    duration = duration or 0.5
    frequency = frequency or 15
    
    -- Create a proxy object for AnimationSequences.shake
    local proxy = frame.get_ui_element_proxy(sprite_id, player_id)
    if not proxy then return nil end
    
    -- Create an object that matches what AnimationSequences.shake expects
    local shake_object = {
        x = proxy.x,
        y = proxy.y,
        rotation = 0,
        setPosition = function(self, x, y)
            proxy:setPosition(x, y)
        end,
        setRotation = function(self, rotation)
            proxy:setRo(rotation)
        end
    }
    local seq_id = nil    
    -- Call AnimationSequences.shake with proper parameters
    seq_id = AnimationSequences.shake(shake_object, {
        intensity = intensity,
        duration = duration,
        frequency = frequency,
        on_complete = function()
            -- Clean up
            if element.animations then
                element.animations[seq_id] = nil
            end
            
            if on_complete then
                on_complete()
            end
        end,
        on_update = function (value)
            print(value)
            shake_object:setPosition(value.x, value.y)
            shake_object:setRotation(value.ro)
        end
    })
    
    -- Track animation
    if not element.animations then
        element.animations = {}
    end
    element.animations[seq_id] = true
    
    return seq_id
end

-- UPDATED FUNCTION: Stop UI element animation
function frame.stop_ui_animation(sprite_id, player_id, anim_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    if anim_id then
        -- Try to stop as animation first
        local success = AnimationEngine.stop_animation(anim_id)
        if not success then
            -- Try to stop as sequence
            success = AnimationEngine.stop_sequence(anim_id)
        end
        
        if success and element.animations then
            element.animations[anim_id] = nil
        end
        return success
    else
        -- Stop all animations for this element
        if element.animations then
            for id, _ in pairs(element.animations) do
                -- Try both animation and sequence stop methods
                AnimationEngine.stop_animation(id)
                AnimationEngine.stop_sequence(id)
            end
            element.animations = {}
        end
        return true
    end
end

-- NEW FUNCTION: Start UI animation sequence
function frame.start_ui_sequence(sprite_id, player_id, seq_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    return AnimationEngine.start_sequence(seq_id)
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

--purpose: move existing UI element (immediate)
function frame.move_ui_element(sprite_id,player_id,x,y,z)
    Net.player_draw_sprite(player_id, ui_cache[player_id][sprite_id]["sprite_id"],
    {
        id = sprite_id .. "_obj",
        x = x*2,
        y = y*2,
        z = z*2    
    }
    )
end

-- UPDATED FUNCTION: slide_ui_element now supports full AnimationEngine features
function frame.slide_ui_element(sprite_id, player_id, x, y, duration, easing, on_complete, loop, ping_pong, easing_back)
    -- Use the new animation system
    local target_props = {x = x, y = y}
    return frame.animate_ui_element(sprite_id, player_id, target_props, duration or 1.0, 
                                    easing or "ease_in_out", on_complete, loop, ping_pong, easing_back)
end

function frame.update_ui_position(sprite_id, player_id, x, Y, Z)
    if ui_cache[player_id] and ui_cache[player_id][sprite_id] then
        local element = ui_cache[player_id][sprite_id]
        Net.player_draw_sprite(player_id, element.sprite_id,
            {
                id = sprite_id .. "_obj",
                x = x*2,
                y = Y*2,
                z = Z or element.z,
                sx = element.sx,
                sy = element.sy,
                anim_state = element.animation_state
            }
        )
        -- Update cache
        element.x = x
        element.y = Y
        element.z = Z or element.z
    end
end


--purpose: make camera pannable freely with arrows but without player following. 
function frame.detach_camera(player_id)
    print("detach_camera() is not yet supported.")
    return 
end

--purpose: removes UI element from screen
function frame.remove_ui_element(sprite_id,player_id)
    -- Stop all animations for this element
    frame.stop_ui_animation(sprite_id, player_id)
    
    Net.player_erase_sprite(player_id, sprite_id .. "_obj")
    if ui_cache[player_id] then
        ui_cache[player_id][sprite_id] = nil
    end
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

function frame.spawn_timer(timer_id,player_id,x,y,duration,loop)
    loop = loop or false
    Displayer.Timer.createPlayerTimer(
        player_id, 
        timer_id, 
        duration, 
        function(_, timer_id, value)
        end,
        loop)
    Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, timer_id, x*2, y*2, "default")
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

function frame.spawn_countdown(countdown_id,player_id,x,y,duration,loop)
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
    Displayer.TimerDisplay.createPlayerCountdownDisplay(player_id, countdown_id, x*2, y*2, "default")
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
    
    -- Clean up any active animations for this player
    AnimationEngine.clear_all() -- This will clear all animations, sequences, and callbacks

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

    -- Update the AnimationEngine
    AnimationEngine.tick(event.delta_time)
    
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
            local keyframes = {{properties={{property="Animation",value=cosmetic_data["state"]},{property="x",ease="Linear",value=bot_position.x},{property="Y",ease="Linear",value=bot_position.y},{property="Z",ease="Linear",value=bot_position.z}},duration=0}}
            keyframes[#keyframes+1] = {properties={{property="Animation",value=cosmetic_data["state"]},{property="x",ease="Linear",value=event.x + cosmetic_data["x"]},{property="Y",ease="Linear",value=event.y + cosmetic_data["y"]},{property="Z",ease="Linear",value=event.z+3}},duration=.1}
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