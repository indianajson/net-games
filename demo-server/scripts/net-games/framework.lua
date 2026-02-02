--[[
* ---------------------------------------------------------- *
           Net Games (framework) - Version 0.09
         https://github.com/indianajson/net-games/   
* ---------------------------------------------------------- *
]]--

-- ===========================================================
-- DEPENDENCIES
-- ===========================================================
local Displayer = require("scripts/net-games/displayer/displayer")
local AnimationEngine = require("scripts/net-games/animation-engine/animation-engine")

-- ===========================================================
-- INITIALIZATION
-- ===========================================================
if not Displayer:init() or not Displayer:isValid() then
    print("Failed to initialize Displayer API")
    return false
end

-- ===========================================================
-- CACHE MANAGEMENT
-- ===========================================================
local frame = {}
local last_position_cache = {}
local button_states = {}
local tracking_state = {}
local cosmetic_cache = {}
local avatar_cache = {}
local ui_cache = {}
local map_elements = {}
local ui_update = {}
local online_players = {}
local text_view_cache = {}    -- NEW: Cache for text view objects
local timer_display_cache = {} -- NEW: Cache for timer display configurations

-- ===========================================================
-- HELPER FUNCTIONS
-- ===========================================================

-- Purpose: Helper function for fixOffsets
local function round_fraction(value, denominator)
    local int_part = math.floor(value)
    local decimal = value - int_part
    local n = math.floor(decimal * denominator + 0.5)
    return int_part, n / denominator
end

-- Purpose: Converts h/v offsets to x/y offsets for UIs
local function convertOffsets(horizontalOffset, verticalOffset, Z)
    local xoffset = ((2 * -verticalOffset + horizontalOffset) / 64) + (Z / 2)
    local yoffset = ((2 * -verticalOffset - horizontalOffset) / 64) + (Z / 2)
    return xoffset, yoffset
end

-- Purpose: Adjusts offsets for UIs so they do not jitter
local function fixOffsets(a, b)
    local a_int, a_dec = round_fraction(a, 32)
    local b_int, b_dec = round_fraction(b, 32)
    
    local diff = math.abs(a_dec - b_dec)
    if diff < 1 then
        local diff_adj = math.floor(diff * 16 + 0.5) / 16
        if a_dec >= b_dec then
            b_dec = a_dec - diff_adj
        else
            b_dec = a_dec + diff_adj
        end
        
        if b_dec < 0 then b_dec = 0 end
        if b_dec >= 1 then b_dec = 1 - (1/32) end
    end
    
    return a_int + a_dec, b_int + b_dec
end

-- Purpose: Normalize color tables
local function normalize_color(color)
    if not color then return nil end
    
    if type(color) == "table" then
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

-- Purpose: Shorthand for async
local function async(p)
    local co = coroutine.create(p)
    return Async.promisify(co)
end

-- Purpose: Shorthand for await
local function await(v) 
    return Async.await(v) 
end

-- Purpose: Check if table has value
local function table_has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- Purpose: Exclude bot for everyone except provided player_id
local function exclude_except_for(player_id, bot_id)
    for i, p_id in next, online_players do 
        if p_id ~= player_id then
            Net.exclude_actor_for_player(p_id, bot_id)
        end 
    end 
end

-- ===========================================================
-- ASSET PROVISION
-- ===========================================================
Net:on("player_join", function(event)
    local assets = {
        "/server/assets/net-games/fonts_compressed.png",
        "/server/assets/net-games/fonts_wide.animation",
        "/server/assets/net-games/fonts_gradient.animation",
        "/server/assets/net-games/fonts_thick.animation",
        "/server/assets/net-games/fonts_battle.animation",
        "/server/assets/net-games/fonts_thin.animation",
        "/server/assets/net-games/fonts_tiny.animation",
        "/server/assets/net-games/fonts_compressed.animation",
        "/server/assets/net-games/fonts_dark_compressed.png"
    }
    
    for _, asset in ipairs(assets) do
        Net.provide_asset_for_player(event.player_id, asset)
    end
end)

-- ===========================================================
-- PLAYER MOVEMENT FUNCTIONS
-- ===========================================================

-- Try a handful of possible EO/Net APIs to move a player without hard-crashing
local function try_move_player(player_id, area_id, x, y, z)
    -- Method 1: transfer_player(player_id, area_id, x, y, z)
    local ok = pcall(function()
        if Net.transfer_player then
            Net.transfer_player(player_id, area_id, x, y, z)
        end
    end)
    if ok and Net.transfer_player then return true end
    
    -- Method 2: transfer_player with warp_in parameter
    ok = pcall(function()
        if Net.transfer_player then
            Net.transfer_player(player_id, area_id, false, x, y, z)
        end
    end)
    if ok and Net.transfer_player then return true end
    
    -- Method 3: move_player
    ok = pcall(function()
        if Net.move_player then
            Net.move_player(player_id, x, y, z)
        end
    end)
    if ok and Net.move_player then return true end
    
    -- Method 4: set_player_position
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
    -- Method 1: animate_player_properties
    local ok = pcall(function()
        if Net.animate_player_properties then
            local keyframes = {{
                properties = {{property = "Animation", value = anim_state}},
                duration = 0
            }}
            Net.animate_player_properties(player_id, keyframes)
        end
    end)
    if ok and Net.animate_player_properties then return true end
    
    -- Method 2: set_player_animation
    ok = pcall(function()
        if Net.set_player_animation then
            Net.set_player_animation(player_id, anim_state)
        end
    end)
    if ok and Net.set_player_animation then return true end
    
    return false
end

-- Move the frozen player
function frame.move_frozen_player(player_id, x, y, z)
    return async(function()
        local area_id = Net.get_player_area(player_id)
        try_move_player(player_id, area_id, x, y, z)
        await(Async.sleep(0))
    end)
end

-- Animate the frozen player
function frame.animate_frozen_player(player_id, anim_state)
    return async(function()
        try_animate_player(player_id, anim_state)
        await(Async.sleep(0))
    end)
end

-- ===========================================================
-- COSMETIC FUNCTIONS
-- ===========================================================

-- Purpose: Show a texture as a cosmetic on a player's avatar
function frame.set_cosmetic(cosmetic_id, player_id, texture, animation, state, x, y, visible, player_xoffset, player_yoffset)
    return async(function()
        -- Safety checks
        if not cosmetic_id or not animation or not state or not player_id or not texture or not x or not y then
            print("[games] One or more required arguments is missing for set_cosmetic()")
            return
        end
        
        local visibility = visible ~= false
        if not cosmetic_cache[player_id] then 
            cosmetic_cache[player_id] = {}
        end
        
        if cosmetic_cache[player_id][cosmetic_id] then
            print("[games] Player already has cosmetic named '"..cosmetic_id.."'.")
            return 
        end 
        
        -- Draw sprite on player
        Net.provide_asset_for_player(player_id, texture)
        Net.provide_asset_for_player(player_id, animation)
        Net.player_alloc_sprite(player_id, cosmetic_id, {
            texture_path = texture,
            anim_path = animation,
            anim_state = state
        })
        
        local p_xoffset = player_xoffset or 0
        local p_yoffset = player_yoffset or 0
        
        Net.player_draw_sprite(player_id, cosmetic_id, {
            id = cosmetic_id .. "_obj",
            x = (x + 120 + p_xoffset) * 2,
            y = (y + 80 + p_yoffset) * 2,
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
        
        -- Spawn bot on player
        if not last_position_cache[player_id] then
            last_position_cache[player_id] = {}
        end 
        
        local area_id = last_position_cache[player_id]["area"] or Net.get_player_area(player_id)
        local position = Net.get_player_position(player_id)
        local xoffset, yoffset = convertOffsets(x * -1, y * -1, position.z + 3)
        xoffset, yoffset = fixOffsets(xoffset, yoffset)
        
        -- Add cosmetic to cache
        cosmetic_cache[player_id][cosmetic_id] = {
            id = cosmetic_id,
            texture = texture,
            x = xoffset,
            y = yoffset,
            visibility = visibility,
            animation = animation,
            state = state,
            spritex = (x + 120 + p_xoffset) * 2,
            spritey = (y + 80 + p_yoffset) * 2
        }
        
        Net.create_bot(cosmetic_id .. "_" .. player_id, {
            area_id = area_id,
            warp_in = false,
            texture_path = texture,
            animation_path = animation,
            animation = state,
            x = position.x + xoffset,
            y = position.y + yoffset,
            z = position.z + 3,
            solid = false
        })
        
        -- Hide bot from player (since we show it the cosmetic with a sprite)
        Net.exclude_actor_for_player(player_id, cosmetic_id .. "_" .. player_id)
    end)
end

-- Purpose: Remove a player's existing cosmetic
function frame.remove_cosmetic(cosmetic_id, player_id)
    if not cosmetic_cache[player_id] then 
        print("[games] Player has no cosmetics.")
        return
    end
    
    if not cosmetic_cache[player_id][cosmetic_id] then
        print("[games] Player has no cosmetic '"..cosmetic_id.."'.")
        return
    end 
    
    Net.remove_bot(cosmetic_id .. "_" .. player_id, false)
    Net.player_erase_sprite(player_id, cosmetic_id .. "_obj")
    cosmetic_cache[player_id][cosmetic_id] = nil
end

-- ===========================================================
-- MAP ELEMENT FUNCTIONS
-- ===========================================================

function frame.add_map_element(name, player_id, texture, animation, animation_state, x, y, z, exclude)
    local area_id = (last_position_cache[player_id] and last_position_cache[player_id]["area"]) or Net.get_player_area(player_id)
    local bot_id = player_id .. "-map-" .. name
    
    Net.create_bot(bot_id, {
        area_id = area_id,
        warp_in = false,
        texture_path = texture,
        animation_path = animation,
        animation = animation_state,
        x = x,
        y = y,
        z = z,
        solid = false
    })
    
    if exclude == true then
        exclude_except_for(player_id, bot_id)
    end 
    
    Net.animate_bot(bot_id, animation_state, true)
    
    if map_elements[player_id] == nil then
        map_elements[player_id] = {}
    end 
    
    map_elements[player_id][name] = {
        name = name,
        state = animation_state,
        id = bot_id
    }
end

function frame.change_map_element(name, player_id, animation_state, loop)
    local bot_id = player_id .. "-map-" .. name
    if Net.is_bot(bot_id) then
        Net.animate_bot(bot_id, animation_state, loop)
    else
        print("[games] Come on, "..name.." isn't a map element for that player!")
    end 
end

function frame.move_map_element(name, player_id, x, y, z)
    local area_id = (last_position_cache[player_id] and last_position_cache[player_id]["area"]) or Net.get_player_area(player_id)
    Net.transfer_bot(player_id .. "-map-" .. name, area_id, false, x, y, z)
end

function frame.remove_map_element(name, player_id)
    local bot_id = player_id .. "-map-" .. name
    if Net.is_bot(bot_id) then 
        map_elements[player_id][name] = nil
        Net.remove_bot(bot_id, false)
    end
end

-- ===========================================================
-- UI ELEMENT FUNCTIONS
-- ===========================================================

-- Purpose: Add a UI element to the screen
function frame.add_ui_element(sprite_id, player_id, texture_path, animation_path, animation_state, x, y, z, sx, sy)
    sx = (sx and sx >= 0.0) and sx or 2.0
    sy = (sy and sy >= 0.0) and sy or 2.0
    animation_path = animation_path or ""
    animation_state = animation_state or ""
    
    if not ui_cache[player_id] then
        ui_cache[player_id] = {}
    end 
    
    -- Check if sprite already allocated
    local new_sprite_id = sprite_id
    local already_allocated = false
    
    for existing_id, sprite_data in pairs(ui_cache[player_id]) do
        if sprite_data["texture_path"] == texture_path then 
            already_allocated = true
            new_sprite_id = sprite_data["sprite_id"]
            break
        end
    end 
    
    if not already_allocated then 
        if animation_path ~= "" then
            Net.provide_asset_for_player(player_id, animation_path)
        end
        Net.provide_asset_for_player(player_id, texture_path)
        Net.player_alloc_sprite(player_id, new_sprite_id, {
            texture_path = texture_path,
            anim_path = animation_path,
            anim_state = animation_state
        })
    end
    
    Net.player_draw_sprite(player_id, new_sprite_id, {
        id = sprite_id .. "_obj",
        x = (x or 0) * 2,
        y = (y or 0) * 2,
        z = (z or 0),
        sx = sx,
        sy = sy,
        ro = 0,
        ox = 0,
        oy = 0,
        a = 255,
        r = 255,
        g = 255,
        b = 255,
        color_mode = 0,
        animation_state = animation_state,
        opacity = 255
    })
    
    ui_cache[player_id][sprite_id] = {
        texture_path = texture_path,
        sprite_id = new_sprite_id,
        x = x,
        y = y,
        z = z or 0,
        sx = sx,
        sy = sy,
        ro = 0,
        ox = 0,
        oy = 0,
        a = 255,
        r = 255,
        g = 255,
        b = 255,
        color_mode = 0,
        animation_state = animation_state,
        opacity = 255,
        animations = {},
        has_children = false,
        children = {}
    }
end

-- Purpose: Update any property of a sprite element
function frame.update_ui_element(sprite_id, player_id, properties)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return
    end
    
    local sprite_data = {id = sprite_id .. "_obj"}
    local element = ui_cache[player_id][sprite_id]
    
    local property_mappings = {
        x = function(val) return val * 2 end,
        y = function(val) return val * 2 end,
        z = function(val) return val end,
        ox = function(val) return val end,
        oy = function(val) return val end,
        scale = function(val) 
            element.sx = val
            element.sy = val
            return val, val
        end,
        sx = function(val) return val end,
        sy = function(val) return val end,
        ro = function(val) return val end,
        opacity = function(val) return val end,
        a = function(val) return val end,
        r = function(val) return val end,
        g = function(val) return val end,
        b = function(val) return val end,
        color_mode = function(val) return val end,
        animation_state = function(val) return val end
    }
    
    for prop, transform in pairs(property_mappings) do
        if properties[prop] ~= nil then
            local transformed = transform(properties[prop])
            if prop == "scale" then
                sprite_data.sx = transformed
                sprite_data.sy = transformed
                element.sx = properties[prop]
                element.sy = properties[prop]
            elseif prop == "x" or prop == "y" then
                sprite_data[prop] = transformed
                element[prop] = properties[prop]
            else
                sprite_data[prop] = transformed
                element[prop] = properties[prop]
            end
        end
    end
    
    Net.player_draw_sprite(player_id, element.sprite_id, sprite_data)
end

-- Purpose: Change the animation state of existing UI element
function frame.set_ui_animation(sprite_id, player_id, animation_state)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return
    end
    
    Net.player_draw_sprite(player_id, ui_cache[player_id][sprite_id]["sprite_id"], {
        id = sprite_id .. "_obj",
        anim_state = animation_state
    })
end

-- Purpose: Remove UI element from screen
function frame.remove_ui_element(sprite_id, player_id)
    frame.stop_ui_animation(sprite_id, player_id)
    Net.player_erase_sprite(player_id, sprite_id .. "_obj")
    
    if ui_cache[player_id] then
        ui_cache[player_id][sprite_id] = nil
    end
end

-- Purpose: Get UI element proxy for animation
function frame.get_ui_element_proxy(sprite_id, player_id)
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
        r = element.r,
        g = element.g,
        b = element.b,
        a = element.a,
        
        setPosition = function(self, x, y)
            element.x = x
            element.y = y
            frame.update_ui_element(sprite_id, player_id, {x = x, y = y})
        end,
        
        setScale = function(self, sx, sy)
            element.sx = sx
            element.sy = sy or sx
            frame.update_ui_element(sprite_id, player_id, {sx = sx, sy = sy or sx})
        end,
        
        setRotation = function(self, ro)
            element.ro = ro
            frame.update_ui_element(sprite_id, player_id, {ro = ro})
        end,
        
        setOpacity = function(self, opacity)
            element.opacity = opacity
            frame.update_ui_element(sprite_id, player_id, {opacity = opacity})
        end,
        
        setColor = function(self, r, g, b, a)
            element.r = r or element.r
            element.g = g or element.g
            element.b = b or element.b
            element.a = a or element.a
            frame.update_ui_element(sprite_id, player_id, {r = r, g = g, b = b, a = a})
        end,
        
        setRo = function(self, ro)
            element.ro = ro
            frame.update_ui_element(sprite_id, player_id, {ro = ro})
        end
    }
end

-- ===========================================================
-- UI ANIMATION FUNCTIONS (ADDITIONS)
-- ===========================================================

-- Purpose: Smoothly slide/move a UI element from current position to target position
function frame.slide_ui_element(sprite_id, player_id, target_x, target_y, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.3
    easing = easing or "linear"
    
    -- Get current position
    local current_x = element.x
    local current_y = element.y
    
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        {x = current_x, y = current_y},
        {x = target_x, y = target_y},
        duration,
        {
            easing = easing,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    x = values.x,
                    y = values.y
                })
            end,
            on_complete = function(values, interrupted)
                -- Call user callback if provided
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                -- Clean up animation tracking
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = false        -- One-time animation
        }
    )
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Smoothly slide/move a UI element from specified start to target position
function frame.set_slide_ui_element(sprite_id, player_id, start_x, start_y, target_x, target_y, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Set starting position immediately
    frame.update_ui_element(sprite_id, player_id, {x = start_x, y = start_y})
    
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        {x = start_x, y = start_y},
        {x = target_x, y = target_y},
        duration,
        {
            easing = easing,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    x = values.x,
                    y = values.y
                })
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, {
                        x = target_x,
                        y = target_y
                    })
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = false
        }
    )
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Smoothly move a UI element relative to its current position
function frame.move_ui_element(sprite_id, player_id, offset_x, offset_y, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current position
    local current_x = element.x or 0
    local current_y = element.y or 0
    
    -- Calculate target position
    local target_x = current_x + offset_x
    local target_y = current_y + offset_y
    
    return frame.slide_ui_element(sprite_id, player_id, target_x, target_y, duration, easing, on_complete)
end

-- Purpose: Smoothly scale a UI element (consistent with slide pattern)
function frame.scale_ui_element(sprite_id, player_id, target_scale, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current scale (use sx as reference)
    local current_scale = element.sx or 2.0
    
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        {scale = current_scale},
        {scale = target_scale},
        duration,
        {
            easing = easing,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    sx = values.scale,
                    sy = values.scale
                })
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, {
                        sx = target_scale,
                        sy = target_scale
                    })
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = false
        }
    )
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Smoothly rotate a UI element (consistent with slide pattern)
function frame.rotate_ui_element(sprite_id, player_id, target_rotation, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current rotation
    local current_rotation = element.ro or 0
    
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        {rotation = current_rotation},
        {rotation = target_rotation},
        duration,
        {
            easing = easing,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    ro = values.rotation
                })
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, {
                        ro = target_rotation
                    })
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = false
        }
    )
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Complex animation that combines slide, scale, and rotation
function frame.transform_ui_element(sprite_id, player_id, properties, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current properties
    local current_props = {
        x = element.x or 0,
        y = element.y or 0,
        sx = element.sx or 2.0,
        sy = element.sy or 2.0,
        ro = element.ro or 0,
        opacity = element.opacity or 255
    }
    
    -- Merge with target properties
    local target_props = {}
    for key, value in pairs(current_props) do
        target_props[key] = properties[key] or value
    end
    
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        current_props,
        target_props,
        duration,
        {
            easing = easing,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    x = values.x,
                    y = values.y,
                    sx = values.sx,
                    sy = values.sy,
                    ro = values.ro,
                    opacity = values.opacity
                })
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, target_props)
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = false
        }
    )
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Apply Bob animation to a UI element using AnimationEngine.Sequences.bob
function frame.bob_ui_element(sprite_id, player_id, distance, duration, easing, loop, ping_pong, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    distance = distance or 3
    duration = duration or 1.0
    easing = easing or "smoothstep"
    loop = loop or true
    ping_pong = ping_pong or true
    
    local proxy = frame.get_ui_element_proxy(sprite_id, player_id)
    if not proxy then return nil end
    
    -- Use AnimationEngine.bob (which now uses AnimationEngine.Sequences.bob)
    local anim_id = AnimationEngine.bob(proxy, {
        distance = distance,
        duration = duration,
        easing = easing,
        loop = loop,
        ping_pong = ping_pong,
        on_complete = on_complete
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Pulse the scale of a UI element using AnimationEngine.pulse
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
    
    local proxy = frame.get_ui_element_proxy(sprite_id, player_id)
    if not proxy then return nil end
    
    local anim_id = AnimationEngine.pulse(proxy, {
        scale_from = min_scale,
        scale_to = max_scale,
        duration = pulse_duration,
        easing = easing or "ease_in_out",
        loop = loops or 1,
        ping_pong = true,
        on_complete = on_complete
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Apply color pulse from current color using AnimationEngine.color_pulse
function frame.color_pulse_from_current(sprite_id, player_id, target_color)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    local current_color = {
        r = element.r or 255,
        g = element.g or 255,
        b = element.b or 255,
        a = element.a or 255
    }
    
    return frame.color_pulse_ui_element(sprite_id, player_id, current_color, target_color)
end

-- Purpose: Apply summon animation to UI element using AnimationEngine.summon
function frame.summon_ui_element(sprite_id, player_id, start_x, start_y, start_scale, 
                                end_x, end_y, end_scale, duration, arc_height, peak_scale_mul, wobble_deg, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.25
    arc_height = arc_height or 24
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 5
    easing = easing or "ease_in_out"
    
    frame.update_ui_element(sprite_id, player_id, {
        x = start_x,
        y = start_y,
        sx = start_scale,
        sy = start_scale
    })
    
    local proxy = {
        x = start_x,
        y = start_y,
        scale = start_scale,
        rotation = 0,
        setPosition = function(self, x, y)
            element.x = x
            element.y = y
            frame.update_ui_element(sprite_id, player_id, {x = x, y = y})
        end,
        setScale = function(self, scale)
            element.sx = scale
            element.sy = scale
            frame.update_ui_element(sprite_id, player_id, {sx = scale, sy = scale})
        end,
        setRotation = function(self, rotation)
            element.ro = rotation
            frame.update_ui_element(sprite_id, player_id, {ro = rotation})
        end
    }
    
    local anim_id = AnimationEngine.summon(proxy, start_x, start_y, start_scale, 
                                          end_x, end_y, end_scale, {
        duration = duration,
        arc_height = arc_height,
        peak_scale_mul = peak_scale_mul,
        wobble_deg = wobble_deg,
        easing = easing,
        on_complete = function(values, interrupted)
            if not interrupted then
                frame.update_ui_element(sprite_id, player_id, {
                    x = end_x,
                    y = end_y,
                    sx = end_scale,
                    sy = end_scale,
                    ro = 0
                })
            end
            
            if on_complete then
                on_complete(values, interrupted)
            end
            
            if element.animations and anim_id then
                element.animations[anim_id] = nil
            end
        end
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Apply complex summon animation using AnimationEngine.complex_summon
function frame.complex_summon_ui_element(sprite_id, player_id, start_x, start_y, start_scale,
                                        end_x, end_y, end_scale, arc_duration, wobble_duration, settle_duration, arc_height, peak_scale_mul, wobble_deg, easing, on_complete, on_update_step1, on_update_step2, on_update_step3)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    arc_duration = arc_duration or 0.25
    wobble_duration = wobble_duration or 0.1
    settle_duration = settle_duration or 0.05
    arc_height = arc_height or 40
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 10
    easing = easing or "ease_in_out"
    
    frame.update_ui_element(sprite_id, player_id, {
        x = start_x,
        y = start_y,
        sx = start_scale,
        sy = start_scale,
        ro = 0
    })
    
    local proxy = {
        x = start_x,
        y = start_y,
        scale = start_scale,
        rotation = 0,
        setPosition = function(self, x, y)
            element.x = x
            element.y = y
            frame.update_ui_element(sprite_id, player_id, {x = x, y = y})
        end,
        setScale = function(self, scale)
            element.sx = scale
            element.sy = scale
            frame.update_ui_element(sprite_id, player_id, {sx = scale, sy = scale})
        end,
        setRotation = function(self, rotation)
            element.ro = rotation
            frame.update_ui_element(sprite_id, player_id, {ro = rotation})
        end
    }
    
    local seq_id = AnimationEngine.complex_summon(proxy, start_x, start_y, start_scale, end_x, end_y, end_scale, {
        arc_duration = arc_duration,
        wobble_duration = wobble_duration,
        settle_duration = settle_duration,
        arc_height = arc_height,
        peak_scale_mul = peak_scale_mul,
        wobble_deg = wobble_deg,
        easing = easing,
        on_complete = function(values, interrupted)
            if not interrupted then
                frame.update_ui_element(sprite_id, player_id, {
                    x = end_x,
                    y = end_y,
                    sx = end_scale,
                    sy = end_scale,
                    ro = 0
                })
            end
            
            if on_complete then
                on_complete(values, interrupted)
            end
            
            if element.animations and seq_id then
                element.animations[seq_id] = nil
            end
        end,
        on_update_step1 = on_update_step1,
        on_update_step2 = on_update_step2,
        on_update_step3 = on_update_step3
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[seq_id] = true
    
    return seq_id
end

-- Purpose: Apply fade animation to UI element using AnimationEngine.fade
function frame.set_opacity_ui_element(sprite_id, player_id, target_opacity, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.3
    easing = easing or "ease_in_out"

    local current_opacity = element.opacity or 255
    target_opacity = math.max(0, math.min(255, target_opacity or 0))
    
    local proxy = {
        alpha = current_opacity,
        setAlpha = function(self, alpha)
            element.opacity = alpha
            frame.update_ui_element(sprite_id, player_id, {opacity = alpha})
        end
    }
    
    local anim_id = AnimationEngine.fade(proxy, target_opacity, {
        duration = duration,
        easing = easing,
        on_complete = function(values, interrupted)
            if not interrupted then
                frame.update_ui_element(sprite_id, player_id, {opacity = target_opacity})
            end
            
            if on_complete then
                on_complete(values, interrupted)
            end
            
            if element.animations and anim_id then
                element.animations[anim_id] = nil
            end
        end
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Apply tint animation to UI element
function frame.set_ui_element_color(sprite_id, player_id, r, g, b, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    duration = duration or 0.25
    easing = easing or "ease_in_out"
    
    local current_r = element.r or 255
    local current_g = element.g or 255
    local current_b = element.b or 255
    
    r = math.max(0, math.min(255, r or 255))
    g = math.max(0, math.min(255, g or 255))
    b = math.max(0, math.min(255, b or 255))
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        {r = current_r, g = current_g, b = current_b},
        {r = r, g = g, b = b},
        duration,
        {
            easing = easing,
            on_update = function(values)
                frame.update_ui_element(sprite_id, player_id, {
                    r = math.floor(values.r),
                    g = math.floor(values.g),
                    b = math.floor(values.b)
                })
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    frame.update_ui_element(sprite_id, player_id, {r = r, g = g, b = b})
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                if element.animations and anim_id then
                    element.animations[anim_id] = nil
                end
            end,
            loop = false
        }
    )
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Apply color pulse animation to UI element using AnimationEngine.color_pulse
function frame.color_pulse_ui_element(sprite_id, player_id, start_color, target_color)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    start_color = normalize_color(start_color)
    target_color = normalize_color(target_color)
    
    if not start_color then
        start_color = {
            r = element.r or 255,
            g = element.g or 255,
            b = element.b or 255,
            a = element.a or 255
        }
    end
    
    local proxy = {
        r = element.r or 255,
        g = element.g or 255,
        b = element.b or 255,
        a = element.a or 255,
        setColor = function(self, r, g, b, a)
            element.r = r
            element.g = g
            element.b = b
            element.a = a or element.a
            frame.update_ui_element(sprite_id, player_id, {r = r, g = g, b = b, a = a})
        end,
        setAlpha = function(self, alpha)
            element.a = alpha
            frame.update_ui_element(sprite_id, player_id, {a = alpha})
        end
    }
    
    local anim_id = AnimationEngine.color_pulse(proxy, start_color, target_color, {
        on_complete = function(values, interrupted)
            if element.animations and anim_id then
                element.animations[anim_id] = nil
            end
        end
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Simple color pulse with RGB values
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

-- Purpose: Apply menu cursor animation (bob + pulse) using AnimationEngine.menu_cursor
function frame.menu_cursor_ui_element(sprite_id, player_id, bob_distance, pulse_scale, bob_duration, pulse_duration, orientation, easing, back_easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]

    pulse_scale = pulse_scale or 1.1
    bob_distance = bob_distance or 3
    bob_duration = bob_duration or 0.8
    pulse_duration = pulse_duration or (bob_duration * 1.5)
    easing = easing or "smootherstep"
    back_easing = back_easing or "smootherstep"
    
    local proxy = {
        y = element.y or 0,
        scale = element.sx or 2.0,
        setPosition = function(self, x, y)
            element.y = y
            frame.update_ui_element(sprite_id, player_id, {y = y})
        end,
        setScale = function(self, scale)
            element.sx = scale
            element.sy = scale
            frame.update_ui_element(sprite_id, player_id, {sx = scale, sy = scale})
        end
    }
    
    local cursor_anim = AnimationEngine.menu_cursor(proxy, {
        bob_distance = bob_distance,
        pulse_scale = pulse_scale,
        bob_duration = bob_duration,
        pulse_duration = pulse_duration,
        orientation = orientation,
        easing = easing,
        back_easing = back_easing,
        on_complete = on_complete
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[cursor_anim.bob] = true
    element.animations[cursor_anim.pulse] = true
    
    return {
        bob = cursor_anim.bob,
        pulse = cursor_anim.pulse,
        stop = function()
            cursor_anim.stop()
            if element.animations then
                element.animations[cursor_anim.bob] = nil
                element.animations[cursor_anim.pulse] = nil
            end
        end
    }
end

-- Purpose: Apply shake animation to UI element using AnimationEngine.shake
function frame.shake_ui_element(sprite_id, player_id, intensity, duration, frequency, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    intensity = intensity or 5
    duration = duration or 0.5
    frequency = frequency or 15
    
    local proxy = frame.get_ui_element_proxy(sprite_id, player_id)
    if not proxy then return nil end
    
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
    
    local seq_id = AnimationEngine.shake(shake_object, {
        intensity = intensity,
        duration = duration,
        frequency = frequency,
        on_complete = function()
            if element.animations then
                element.animations[seq_id] = nil
            end
            
            if on_complete then
                on_complete()
            end
        end
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[seq_id] = true
    
    return seq_id
end

-- Purpose: Apply highlight animation using AnimationEngine.highlight
function frame.highlight_ui_element(sprite_id, player_id, lift_amount, glow_alpha, duration, easing, on_complete)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return nil
    end
    
    local element = ui_cache[player_id][sprite_id]
    lift_amount = lift_amount or 5
    glow_alpha = glow_alpha or 100
    duration = duration or 0.15
    easing = easing or "ease_out"
    
    local proxy = {
        y = element.y or 0,
        alpha = element.opacity or 255,
        setPosition = function(self, x, y)
            element.y = y
            frame.update_ui_element(sprite_id, player_id, {y = y})
        end,
        setAlpha = function(self, alpha)
            element.opacity = alpha
            frame.update_ui_element(sprite_id, player_id, {opacity = alpha})
        end
    }
    
    local anim_id = AnimationEngine.highlight(proxy, {
        lift_amount = lift_amount,
        glow_alpha = glow_alpha,
        duration = duration,
        easing = easing,
        on_complete = function(values, interrupted)
            if on_complete then
                on_complete(values, interrupted)
            end
            
            if element.animations and anim_id then
                element.animations[anim_id] = nil
            end
        end
    })
    
    if not element.animations then
        element.animations = {}
    end
    element.animations[anim_id] = true
    
    return anim_id
end

-- Purpose: Apply instant transition (no animation)
function frame.set_ui_element_instant(sprite_id, player_id, properties)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    for key, value in pairs(properties) do
        if element[key] ~= nil then
            element[key] = value
        end
    end
    
    frame.update_ui_element(sprite_id, player_id, properties)
end

-- Purpose: Reset UI element to its initial state using AnimationEngine.Sequences.reset
function frame.reset_ui_element(sprite_id, player_id, initial_values)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        print("[games] UI element not found: " .. sprite_id)
        return
    end
    
    frame.stop_ui_animation(sprite_id, player_id)
    
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
    
    -- Use AnimationEngine.Sequences.reset if available
    if AnimationEngine.Sequences and AnimationEngine.Sequences.reset then
        local proxy = frame.get_ui_element_proxy(sprite_id, player_id)
        if proxy then
            AnimationEngine.Sequences.reset(proxy, reset_props)
        end
    else
        frame.set_ui_element_instant(sprite_id, player_id, reset_props)
    end
end

-- Purpose: Stop UI element animation
function frame.stop_ui_animation(sprite_id, player_id, anim_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    local element = ui_cache[player_id][sprite_id]
    
    if anim_id then
        local success = AnimationEngine.stop_animation(anim_id)
        if not success then
            success = AnimationEngine.stop_sequence(anim_id)
        end
        
        if success and element.animations then
            element.animations[anim_id] = nil
        end
        return success
    else
        if element.animations then
            for id, _ in pairs(element.animations) do
                AnimationEngine.stop_animation(id)
                AnimationEngine.stop_sequence(id)
            end
            element.animations = {}
        end
        return true
    end
end

-- Purpose: Check if a UI element has active animations
function frame.has_active_animations(sprite_id, player_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    local element = ui_cache[player_id][sprite_id]
    return element.animations and next(element.animations) ~= nil
end

-- Purpose: Check if a specific animation is running on a UI element
function frame.is_animation_running(sprite_id, player_id, anim_id)
    if not ui_cache[player_id] or not ui_cache[player_id][sprite_id] then
        return false
    end
    
    local element = ui_cache[player_id][sprite_id]
    if not element.animations then
        return false
    end
    
    -- Check if animation is in our local cache
    if element.animations[anim_id] then
        return true
    end
    
    -- Also check with AnimationEngine if it's running
    return AnimationEngine.is_running(anim_id)
end

-- Purpose: Get UI element properties
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

-- ===========================================================
-- TEXT FUNCTIONS (UPDATED FOR PROPER DISPLAYER API)
-- ===========================================================

-- Purpose: Create static text using Displayer.Text API
function frame.draw_text(player_id, text_id, text, x, y, z_order, font_name, scale, sprite_opts)
    if not player_id or not text then 
        print("[games] Error: player_id and text are required")
        return nil 
    end
    
    -- Convert coordinates if needed (game coords to screen coords)
    local screen_x = x and x * 2 or 0
    local screen_y = y and y * 2 or 0
    
    -- Call Displayer.Text.drawText
    local success = Displayer.Text.drawText(
        player_id,
        text_id or ("text_" .. tostring(math.random(1000, 9999))),
        text,
        screen_x,
        screen_y,
        z_order or 100,
        font_name or "THICK",
        scale or 2.0,
        sprite_opts
    )
    
    -- Cache the text
    if not text_view_cache[player_id] then
        text_view_cache[player_id] = {}
    end
    text_view_cache[player_id][text_id] = {
        type = "static",
        id = text_id
    }
    
    return success
end

-- Purpose: Update existing text
function frame.update_text(text_id, player_id, new_text)
    if not player_id or not text_id or not new_text then 
        print("[games] Error: player_id, text_id and new_text are required")
        return false 
    end
    
    return Displayer.Text.updateText(player_id, text_id, new_text)
end

-- Purpose: Remove text
function frame.remove_text(text_id, player_id)
    if not player_id or not text_id then 
        print("[games] Error: player_id and text_id are required")
        return false 
    end
    
    if text_view_cache[player_id] then
        text_view_cache[player_id][text_id] = nil
    end
    
    return Displayer.Text.removeText(player_id, text_id)
end

-- Purpose: Create marquee (scrolling) text
function frame.draw_marquee_text(player_id, marquee_id, text, y, font_name, scale, z_order, speed, backdrop, sprite_opts)
    if not player_id or not marquee_id or not text then 
        print("[games] Error: player_id, marquee_id and text are required")
        return nil 
    end
    
    -- Convert coordinates if needed (game coords to screen coords)
    local screen_y = y and y * 2 or 0
    
    -- Call Displayer.Text.drawMarqueeText with ALL parameters
    local success = Displayer.Text.drawMarqueeText(
        player_id,
        marquee_id,
        text,
        screen_y,
        font_name or "THICK",
        scale or 2.0,
        z_order or 100,
        speed or "medium",
        backdrop,
        sprite_opts or {}
    )
    
    -- Cache the marquee
    if not text_view_cache[player_id] then
        text_view_cache[player_id] = {}
    end
    text_view_cache[player_id][marquee_id] = {
        type = "marquee",
        id = marquee_id
    }
    
    return success
end

-- Purpose: Set marquee position
function frame.set_marquee_position(player_id, marquee_id, x, y)
    if not player_id or not marquee_id then 
        print("[games] Error: player_id and marquee_id are required")
        return false 
    end
    
    -- Use setTextPosition which works for all text types
    return Displayer.Text.setTextPosition(player_id, marquee_id, (x or 0) * 2, (y or 0) * 2)
end

-- Purpose: Set marquee speed
function frame.set_marquee_speed(player_id, marquee_id, speed)
    if not player_id or not marquee_id then 
        print("[games] Error: player_id and marquee_id are required")
        return false 
    end
    
    return Displayer.Text.setMarqueeSpeed(player_id, marquee_id, speed)
end

-- Purpose: Update marquee sprite options
function frame.update_marquee_sprite_options(player_id, marquee_id, sprite_opts)
    if not player_id or not marquee_id or not sprite_opts then 
        print("[games] Error: player_id, marquee_id and sprite_opts are required")
        return false 
    end
    
    return Displayer.Text.updateMarqueeSpriteOptions(player_id, marquee_id, sprite_opts)
end

-- Purpose: Create textbox with typewriter effect
function frame.draw_textbox(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed, opts)
    if not player_id or not box_id or not text then 
        print("[games] Error: player_id, box_id and text are required")
        return nil 
    end
    
    local screen_x = x and x * 2 or 0
    local screen_y = y and y * 2 or 0
    local screen_width = width and width * 2 or 200
    local screen_height = height and height * 2 or 100
    
    -- Call Displayer.Text.createTextBox
    local success = Displayer.Text.createTextBox(
        player_id,
        box_id,
        text,
        screen_x,
        screen_y,
        screen_width,
        screen_height,
        font_name or "THICK",
        scale or 2.0,
        z_order or 100,
        backdrop_config,
        speed or 30,
        opts
    )
    
    -- Cache the textbox
    if not text_view_cache[player_id] then
        text_view_cache[player_id] = {}
    end
    text_view_cache[player_id][box_id] = {
        type = "textbox",
        id = box_id
    }
    
    return success
end

-- Purpose: Advance textbox to next page
function frame.textbox_next_page(textbox_id, player_id)
    if not player_id or not textbox_id then 
        print("[games] Error: player_id and textbox_id are required")
        return false 
    end
    
    return Displayer.Text.advanceTextBox(player_id, textbox_id)
end

-- Purpose: Skip textbox to end - use resetTextBox with the same text
function frame.textbox_skip_to_end(textbox_id, player_id)
    if not player_id or not textbox_id then 
        print("[games] Error: player_id and textbox_id are required")
        return false 
    end
    
    -- Get current textbox data to get the text
    local data = Displayer.Text.getTextBoxData(player_id, textbox_id)
    if not data or not data.text then
        print("[games] Could not get textbox data for: " .. textbox_id)
        return false
    end
    
    -- Reset the textbox with the same text but immediately show it all
    return Displayer.Text.resetTextBox(
        player_id,
        textbox_id,
        data.text,
        data.x or 0,
        data.y or 0,
        data.width or 200,
        data.height or 100,
        data.font_name or "THICK",
        data.scale or 2.0,
        data.z_order or 100,
        data.backdrop_config,
        0, -- Set speed to 0 for instant display
        data.opts
    )
end

-- Purpose: Set text position
function frame.set_text_position(text_id, player_id, x, y)
    if not player_id or not text_id then 
        print("[games] Error: player_id and text_id are required")
        return false 
    end
    
    return Displayer.Text.setTextPosition(player_id, text_id, (x or 0) * 2, (y or 0) * 2)
end

-- Purpose: Get text view object for advanced control
function frame.get_text_view(text_id, player_id)
    if not text_view_cache[player_id] or not text_view_cache[player_id][text_id] then
        return nil
    end
    
    -- Return a proxy object that maps to Displayer functions
    local cache_entry = text_view_cache[player_id][text_id]
    return {
        id = cache_entry.id,
        type = cache_entry.type,
        updateText = function(text)
            return Displayer.Text.updateText(player_id, text_id, text)
        end,
        setPosition = function(x, y)
            return Displayer.Text.setTextPosition(player_id, text_id, (x or 0) * 2, (y or 0) * 2)
        end,
        remove = function()
            return Displayer.Text.removeText(player_id, text_id)
        end,
        -- Textbox specific methods
        advance = function()
            if cache_entry.type == "textbox" then
                return Displayer.Text.advanceTextBox(player_id, text_id)
            end
            return false
        end,
        getState = function()
            if cache_entry.type == "textbox" then
                return Displayer.Text.getTextBoxState(player_id, text_id)
            end
            return nil
        end,
        isCompleted = function()
            if cache_entry.type == "textbox" then
                return Displayer.Text.isTextBoxCompleted(player_id, text_id)
            end
            return true
        end,
        -- Marquee specific methods
        setSpeed = function(speed)
            if cache_entry.type == "marquee" then
                return Displayer.Text.setMarqueeSpeed(player_id, text_id, speed)
            end
            return false
        end,
        updateSpriteOptions = function(sprite_opts)
            if cache_entry.type == "marquee" then
                return Displayer.Text.updateMarqueeSpriteOptions(player_id, text_id, sprite_opts)
            end
            return false
        end
    }
end

-- ===========================================================
-- TIMER FUNCTIONS (UPDATED WITH OPTIONS SUPPORT)
-- ===========================================================

function frame.spawn_timer(timer_id, player_id, x, y, duration, loop, options)
    loop = loop or false
    options = options or {}
    
    -- Cache timer display configuration
    if not timer_display_cache[player_id] then
        timer_display_cache[player_id] = {}
    end
    
    timer_display_cache[player_id][timer_id] = {
        type = "timer",
        x = x,
        y = y,
        options = options
    }
    
    -- Create timer with callback
    Displayer.Timer.createPlayerTimer(
        player_id, 
        timer_id, 
        duration, 
        function(_, timer_id, value)
            if value <= 0 then
                Net:emit("timer_ended", {player_id = player_id, timer_id = timer_id})
            end
        end,
        loop
    )
    
    -- Create timer display with options
    local config_name = options.config_name or "default"
    Displayer.TimerDisplay.createPlayerTimerDisplay(player_id, timer_id, (x or 0) * 2, (y or 0) * 2, config_name)
    
    return timer_id
end

function frame.resume_timer(timer_id, player_id)
    Displayer.Timer.resumePlayerTimer(player_id, timer_id)
end

function frame.pause_timer(timer_id, player_id)
    Displayer.Timer.pausePlayerTimer(player_id, timer_id)
end

function frame.remove_timer(timer_id, player_id)
    Displayer.Timer.removePlayerTimer(player_id, timer_id)
    Displayer.TimerDisplay.removePlayerDisplay(player_id, timer_id)
    
    if timer_display_cache[player_id] then
        timer_display_cache[player_id][timer_id] = nil
    end
end

function frame.update_timer(timer_id, player_id, duration)
    -- Note: There's no direct update function in displayer.lua for timers
    -- We need to remove and recreate or use a different approach
    print("[games] Timer update not directly supported. Remove and recreate instead.")
    return false
end

-- Purpose: Set timer display position
function frame.set_timer_position(timer_id, player_id, x, y)
    Displayer.TimerDisplay.setDisplayPosition(player_id, timer_id, (x or 0) * 2, (y or 0) * 2)
    
    -- Update cache
    if timer_display_cache[player_id] and timer_display_cache[player_id][timer_id] then
        timer_display_cache[player_id][timer_id].x = x
        timer_display_cache[player_id][timer_id].y = y
    end
end

-- ===========================================================
-- COUNTDOWN FUNCTIONS (UPDATED WITH OPTIONS SUPPORT)
-- ===========================================================

function frame.spawn_countdown(countdown_id, player_id, x, y, duration, loop, options)
    loop = loop or false
    options = options or {}
    
    -- Cache countdown display configuration
    if not timer_display_cache[player_id] then
        timer_display_cache[player_id] = {}
    end
    
    timer_display_cache[player_id][countdown_id] = {
        type = "countdown",
        x = x,
        y = y,
        options = options
    }
    
    -- Create countdown with callback
    Displayer.Timer.createPlayerCountdown(
        player_id, 
        countdown_id, 
        duration, 
        function(_, countdown_id, value)
            if value <= 0 then
                Net:emit("countdown_ended", {player_id = player_id, countdown_id = countdown_id})
            end
        end,
        loop
    )
    
    -- Create countdown display with options
    local config_name = options.config_name or "default"
    Displayer.TimerDisplay.createPlayerCountdownDisplay(player_id, countdown_id, (x or 0) * 2, (y or 0) * 2, config_name)
    
    return countdown_id
end

function frame.resume_countdown(countdown_id, player_id)
    Displayer.Timer.resumePlayerCountdown(player_id, countdown_id)
end

function frame.pause_countdown(countdown_id, player_id)
    Displayer.Timer.pausePlayerCountdown(player_id, countdown_id)
end

function frame.remove_countdown(countdown_id, player_id)
    Displayer.Timer.removePlayerCountdown(player_id, countdown_id)
    Displayer.TimerDisplay.removePlayerDisplay(player_id, countdown_id)
    
    if timer_display_cache[player_id] then
        timer_display_cache[player_id][countdown_id] = nil
    end
end

function frame.update_countdown(countdown_id, player_id, duration)
    -- Note: There's no direct update function in displayer.lua for countdowns
    print("[games] Countdown update not directly supported. Remove and recreate instead.")
    return false
end

-- Purpose: Set countdown display position
function frame.set_countdown_position(countdown_id, player_id, x, y)
    Displayer.TimerDisplay.setDisplayPosition(player_id, countdown_id, (x or 0) * 2, (y or 0) * 2)
    
    -- Update cache
    if timer_display_cache[player_id] and timer_display_cache[player_id][countdown_id] then
        timer_display_cache[player_id][countdown_id].x = x
        timer_display_cache[player_id][countdown_id].y = y
    end
end

-- ===========================================================
-- TEXT UTILITY FUNCTIONS
-- ===========================================================

-- Purpose: Get text width using Displayer.Font API
function frame.get_text_width(text, font_name, scale)
    if not text then
        print("[games] Error: text is required")
        return 0
    end
    
    return Displayer.Font.getTextWidth(text, font_name or "THICK", scale or 2.0)
end

-- Purpose: Calculate text dimensions (width and estimated height)
function frame.calculate_text_dimensions(text, font_name, scale)
    local width = frame.get_text_width(text, font_name, scale)
    -- Estimate height based on font scale
    local height = (scale or 2.0) * 8  -- Rough estimate: 8px per line at scale 1.0
    
    return width, height
end

-- ===========================================================
-- CURSOR FUNCTIONS (UPDATED FOR UI INTEGRATION)
-- ===========================================================

-- Purpose: Spawn a cursor that integrates with UI element system
function frame.spawn_cursor(sprite_id, player_id, options)
        Net.lock_player_input(player_id)
        
        -- Get initial selection
        local initial_selection = options.selections[1]
        
        -- Create cursor as a UI element
        frame.add_ui_element(sprite_id, player_id, 
            options.texture, 
            options.animation or "", 
            initial_selection.state, 
            initial_selection.x, 
            initial_selection.y, 
            initial_selection.z or 0,
            2, 2  -- Default scale
        )
        
        -- Store cursor options in UI element's cursor_options
        if ui_cache[player_id] and ui_cache[player_id][sprite_id] then
            local obj_cache = ui_cache[player_id][sprite_id]
            obj_cache.x = obj_cache.x or 0
            obj_cache.y = obj_cache.y or 0
            obj_cache.z = obj_cache.z or 0
            obj_cache.sx = obj_cache.sx or 2.0
            obj_cache.sy = obj_cache.sy or 2.0
            obj_cache.is_cursor = true
            obj_cache.cursor_options = {
                selections = options.selections,
                movement = options.movement or "vertical",
                current_index = 1,
                locked = false,
                name = sprite_id
            }
        end
end

-- Purpose: Remove a cursor
function frame.remove_cursor(cursor_id, player_id)
    -- Check if this is actually a cursor
    if ui_cache[player_id] and ui_cache[player_id][cursor_id] and ui_cache[player_id][cursor_id]["sprite_id"] then
        frame.remove_ui_element(cursor_id, player_id)
        Net.unlock_player_input(player_id)
    else
        print("[games] No cursor found with ID: " .. cursor_id)
    end
end

-- Purpose: Move cursor to specific selection using AnimationEngine
function frame.move_cursor_to_selection(cursor_id, player_id, selection_name)
    if not ui_cache[player_id] or not ui_cache[player_id][cursor_id] or not ui_cache[player_id][cursor_id]["sprite_id"] then
        return false
    end
    
    local cursor_element = ui_cache[player_id][cursor_id]
    local cursor_options = cursor_element.cursor_options
    local selections = cursor_options.selections
    
    -- Find selection by name
    for i, selection in ipairs(selections) do
        if selection.name == selection_name then
            cursor_options.current_index = i
            
            -- Use AnimationEngine to smoothly move the cursor
            frame.slide_ui_element(cursor_id, player_id, 
                selection.x, 
                selection.y, 
                0.15,  -- duration
                "ease_out_quad",  -- easing
                function()
                    -- Update animation state after movement completes
                    frame.update_ui_element(cursor_id, player_id, {
                        animation_state = selection.state
                    })
                    
                    -- Emit hover event
                    Net:emit("cursor_hover", {
                        player_id = player_id,
                        cursor = cursor_id,
                        selection = selection_name
                    })
                end
            )
            
            return true
        end
    end
    
    return false
end

-- Purpose: Get current cursor selection
function frame.get_current_cursor_selection(cursor_id, player_id)
    if not ui_cache[player_id] or not ui_cache[player_id][cursor_id] or not ui_cache[player_id][cursor_id]["sprite_id"].is_cursor then
        return nil
    end
    
    local cursor_options = ui_cache[player_id][cursor_id]["sprite_id"].cursor_options
    local current_index = cursor_options.current_index
    
    if current_index and cursor_options.selections[current_index] then
        return cursor_options.selections[current_index]
    end
    
    return nil
end

-- Purpose: Lock cursor movement
function frame.lock_cursor(cursor_id, player_id, locked)
    if not ui_cache[player_id] or not ui_cache[player_id][cursor_id] or not ui_cache[player_id][cursor_id].is_cursor then
        return false
    end
    
    local cursor_options = ui_cache[player_id][cursor_id].cursor_options
    cursor_options.locked = locked ~= false
    return true
end

-- Purpose: Check if cursor is locked
function frame.is_cursor_locked(cursor_id, player_id)
    if not ui_cache[player_id] or not ui_cache[player_id][cursor_id] or not ui_cache[player_id][cursor_id].is_cursor then
        return false
    end
    
    local cursor_options = ui_cache[player_id][cursor_id].cursor_options
    return cursor_options.locked or false
end

-- Purpose: Update cursor options
function frame.update_cursor_options(cursor_id, player_id, new_options)
    if not ui_cache[player_id] or not ui_cache[player_id][cursor_id] or not ui_cache[player_id][cursor_id].is_cursor then
        return false
    end
    
    local cursor_options = ui_cache[player_id][cursor_id].cursor_options
    
    -- Merge new options with existing ones
    if new_options.selections then
        cursor_options.selections = new_options.selections
    end
    if new_options.movement then
        cursor_options.movement = new_options.movement
    end
    if new_options.current_index then
        cursor_options.current_index = new_options.current_index
    end
    if new_options.locked ~= nil then
        cursor_options.locked = new_options.locked
    end
    
    return true
end

-- ===========================================================
-- CAMERA FUNCTIONS
-- ===========================================================

function frame.detach_camera(player_id)
    print("detach_camera() is not yet supported.")
    return 
end

-- ===========================================================
-- UTILITY FUNCTIONS
-- ===========================================================

-- Purpose: Split a string based on a delimiter
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

-- ===========================================================
-- EVENT HANDLERS (UPDATED)
-- ===========================================================

-- Player join event
Net:on("player_join", function(event)
    table.insert(online_players, event.player_id)
    
    -- Reset all caches on join
    ui_cache[event.player_id] = {}
    avatar_cache[event.player_id] = {}
    text_view_cache[event.player_id] = {}  -- NEW: Initialize text view cache
    timer_display_cache[event.player_id] = {} -- NEW: Initialize timer display cache
    
    -- Hide player exclusive cosmetics
    for player_id, cosmetics in pairs(cosmetic_cache) do
        for cosmetic_id, cosmetic_data in pairs(cosmetics) do 
            if not cosmetic_data["visibility"] then
                Net.exclude_actor_for_player(event.player_id, cosmetic_id .. "_" .. player_id)
            end
        end
    end
end)

-- Player disconnect event
Net:on("player_disconnect", function(event)
    -- Clear all caches on disconnect
    avatar_cache[event.player_id] = nil
    ui_cache[event.player_id] = nil
    ui_update[event.player_id] = nil
    text_view_cache[event.player_id] = nil  -- NEW: Clear text view cache
    timer_display_cache[event.player_id] = nil -- NEW: Clear timer display cache
    
    -- Clean up any active animations for this player
    AnimationEngine.clear_all()
    
    -- Remove bots
    if Net.is_bot(event.player_id .. "-double") then
        Net.remove_bot(event.player_id .. "-double", false)
    end
    
    if Net.is_bot(event.player_id .. "-camera") then
        Net.remove_bot(event.player_id .. "-camera", false)
    end
    
    -- Remove from online players
    for i, player in ipairs(online_players) do
        if player == event.player_id then
            table.remove(online_players, i)
            break
        end
    end
    
    -- Remove cosmetics
    if cosmetic_cache[event.player_id] then
        for cosmetic_id, _ in pairs(cosmetic_cache[event.player_id]) do
            Net.remove_bot(cosmetic_id .. "_" .. event.player_id, false)
        end
        cosmetic_cache[event.player_id] = nil
    end
end)

-- Tick event
Net:on("tick", function(event)
    AnimationEngine.tick(event.delta_time)
    
    -- Manage emitting state = 4 if player is using a button to scroll
    for player_id, buttons in pairs(button_states) do
        if not tracking_state[player_id] then
            tracking_state[player_id] = {}
        end
        
        for name, state in pairs(buttons) do
            if not tracking_state[player_id][name] then 
                tracking_state[player_id][name] = {tracked = 0, elapsed = 0}
            end 
            
            if state == 2 then
                if tracking_state[player_id][name]["tracked"] == 0 then
                    tracking_state[player_id][name]["elapsed"] = 0
                    tracking_state[player_id][name]["tracked"] = 1
                else
                    tracking_state[player_id][name]["elapsed"] = 
                        tracking_state[player_id][name]["elapsed"] + event.delta_time
                end 
                
                if tracking_state[player_id][name]["elapsed"] > .3 and 
                   tracking_state[player_id][name]["tracked"] == 1 then
                    tracking_state[player_id][name]["elapsed"] = 0
                    Net:emit("virtual_input", {player_id = player_id, events = {{state = 4, name = name}}})
                    tracking_state[player_id][name]["tracked"] = 2
                elseif tracking_state[player_id][name]["elapsed"] > .1 and 
                      tracking_state[player_id][name]["tracked"] == 2 then
                    tracking_state[player_id][name]["elapsed"] = 0
                    Net:emit("virtual_input", {player_id = player_id, events = {{state = 4, name = name}}})
                end 
            else 
                tracking_state[player_id][name]["tracked"] = 0
                tracking_state[player_id][name]["elapsed"] = 0
            end 
        end
    end
end)

-- Virtual input event for cursor handling using UI element system
Net:on("virtual_input", function(event)
    -- Pass inputs to cache
    if not button_states[event.player_id] then
        button_states[event.player_id] = {}
    end 
    
    for _, button in ipairs(event.events) do
        button_states[event.player_id][button.name] = button.state
    end
    
    -- Find cursor for this player
    local cursor_id = nil
    local cursor_element = nil
    local cursor_options = nil
    
    for id, element in pairs(ui_cache[event.player_id] or {}) do
        if element.is_cursor then
            cursor_id = id
            cursor_element = element
            cursor_options = element.cursor_options
            break
        end
    end
    
    if not cursor_id then
        return
    end
    
    -- Check if cursor is locked
    if cursor_options.locked then
        return
    end
    
    local direction = cursor_options.movement or "vertical"
    
    for _, button in ipairs(event.events) do
        -- Cursor movement
        local should_move = false
        local move_direction = nil
        
        if direction == "vertical" then
            if (button.name == "Move Down" and (button.state == 1 or button.state == 4)) then
                should_move = true
                move_direction = "Move Down"
            elseif (button.name == "Move Up" and (button.state == 1 or button.state == 4)) then
                should_move = true
                move_direction = "Move Up"
            end
        elseif direction == "horizontal" then
            if (button.name == "Move Right" and (button.state == 1 or button.state == 4)) then
                should_move = true
                move_direction = "Move Right"
            elseif (button.name == "Move Left" and (button.state == 1 or button.state == 4)) then
                should_move = true
                move_direction = "Move Left"
            end
        elseif direction == "shoulder" then
            if (button.name == "Shoulder R" and (button.state == 1 or button.state == 4)) then
                should_move = true
                move_direction = "Shoulder R"
            elseif (button.name == "Shoulder L" and (button.state == 1 or button.state == 4)) then
                should_move = true
                move_direction = "Shoulder L"
            end
        end
        
        if should_move then
            Net:emit("cursor_move", {
                player_id = event.player_id,
                cursor = cursor_id,
                button = move_direction
            })
        
        -- Cursor selection
        elseif (button.name == "Interact" or button.name == "Confirm") and button.state == 1 then
            local selections = cursor_options.selections
            local idx = cursor_options.current_index or 1
            
            if selections and idx and selections[idx] and selections[idx].name then
                Net:emit("cursor_selection", {
                    player_id = event.player_id,
                    cursor = cursor_id,
                    selection = selections[idx].name
                })
            end
        end
    end
end)

-- Cursor movement logic using UI element system
Net:on("cursor_move", function(event)
    local player_id = event.player_id
    local cursor_found = false
    
    -- Find the cursor for this player
    for cursor_id, element in pairs(ui_cache[player_id] or {}) do
        if element.is_cursor then
            local cursor_options = element.cursor_options
            
            -- Check if cursor is locked
            if cursor_options.locked then
                return
            end
            
            local last_selection = cursor_options.current_index or 1
            local direction = event.button
            local movement = cursor_options.movement or "vertical"
            
            -- Determine movement direction
            local move_forward = false
            local move_backward = false
            
            if movement == "vertical" then
                if direction == "Move Up" or direction == "Shoulder L" then
                    move_backward = true
                elseif direction == "Move Down" or direction == "Shoulder R" then
                    move_forward = true
                end
            elseif movement == "horizontal" then
                if direction == "Move Left" or direction == "Shoulder L" then
                    move_backward = true
                elseif direction == "Move Right" or direction == "Shoulder R" then
                    move_forward = true
                end
            elseif movement == "shoulder" then
                if direction == "Shoulder L" then
                    move_backward = true
                elseif direction == "Shoulder R" then
                    move_forward = true
                end
            end
            
            -- Calculate new selection index
            local selections = cursor_options.selections
            local new_index = last_selection
            
            if move_forward then
                new_index = (last_selection == #selections) and 1 or (last_selection + 1)
            elseif move_backward then
                new_index = (last_selection == 1) and #selections or (last_selection - 1)
            end
            
            cursor_options.current_index = new_index
            local selection = selections[new_index]
            
            -- Animate cursor movement using AnimationEngine
            frame.slide_ui_element(cursor_id, player_id, 
                selection.x, 
                selection.y, 
                0.1,  -- fast movement for responsive feel
                "ease_out_back",  -- slight bounce effect
                function()
                    -- Update animation state after movement
                    frame.update_ui_element(cursor_id, player_id, {
                        x = selection.x, y = selection.y,
                        sx = element.sx,
                        animation_state = selection.state
                    })
                    
                    -- Emit hover event
                    Net:emit("cursor_hover", {
                        player_id = player_id,
                        cursor = cursor_id,
                        selection = selection.name
                    })
                end
            )
            
            cursor_found = true
            break
        end
    end
    
    if not cursor_found then
        print("[games] No cursor found for player " .. player_id)
    end
end)

-- Player move event
Net:on("player_move", function(event)
    -- Update cosmetic position
    if cosmetic_cache[event.player_id] then
        for cosmetic_id, cosmetic_data in pairs(cosmetic_cache[event.player_id]) do
            local bot_id = cosmetic_id .. "_" .. event.player_id
            local bot_position = Net.get_bot_position(bot_id)
            
            Net.move_bot(bot_id, event.x + cosmetic_data["x"], event.y + cosmetic_data["y"], event.z + 3)
            
            local keyframes = {
                {
                    properties = {
                        {property = "Animation", value = cosmetic_data["state"]},
                        {property = "X", ease = "Linear", value = bot_position.x},
                        {property = "Y", ease = "Linear", value = bot_position.y},
                        {property = "Z", ease = "Linear", value = bot_position.z}
                    },
                    duration = 0
                },
                {
                    properties = {
                        {property = "Animation", value = cosmetic_data["state"]},
                        {property = "X", ease = "Linear", value = event.x + cosmetic_data["x"]},
                        {property = "Y", ease = "Linear", value = event.y + cosmetic_data["y"]},
                        {property = "Z", ease = "Linear", value = event.z + 3}
                    },
                    duration = .1
                }
            }
            
            Net.animate_bot_properties(bot_id, keyframes)
            Net.animate_bot(bot_id, cosmetic_data["state"], true)
        end
    end
end)

-- Player area transfer event
Net:on("player_area_transfer", function(event)
    -- Update cache position
    if not last_position_cache[event.player_id] then
        last_position_cache[event.player_id] = {}
    end
    
    last_position_cache[event.player_id]["area"] = Net.get_player_area(event.player_id)
    
    -- Transfer cosmetics
    if cosmetic_cache[event.player_id] then
        for cosmetic_id, _ in pairs(cosmetic_cache[event.player_id]) do
            Net.transfer_bot(cosmetic_id .. "_" .. event.player_id, 
                            last_position_cache[event.player_id]["area"], false)
        end
    end
end)

-- ===========================================================
-- MODULE EXPORT
-- ===========================================================
return frame