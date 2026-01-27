-- holoshine.lua
-- Holographic overlay effect module for Net Games framework
-- Uses pre-set color cycles for holographic effect

local HoloShine = {}

local games = require("scripts/net-games/framework")
local AnimationEngine = require("scripts/net-games/animation-engine/animation-engine")
-- Pre-set holographic color cycles
-- Each cycle is a table of RGB values for the wave effect
HoloShine.HOLOSHINE_COLORS = {
    -- Blue-purple holographic palette
    {
        {r = 100, g = 50, b = 200},   -- Deep purple
        {r = 120, g = 80, b = 220},   -- Light purple
        {r = 80, g = 100, b = 240},   -- Blue
        {r = 100, g = 120, b = 255},  -- Light blue
        {r = 120, g = 100, b = 220},  -- Purple
        {r = 100, g = 80, b = 200},   -- Back to deep purple
    },
    -- Rainbow holographic palette
    {
        {r = 255, g = 0, b = 100},    -- Pink
        {r = 255, g = 100, b = 0},    -- Orange
        {r = 200, g = 200, b = 0},    -- Yellow
        {r = 0, g = 255, b = 100},    -- Green
        {r = 0, g = 200, b = 255},    -- Cyan
        {r = 100, g = 0, b = 255},    -- Blue
        {r = 200, g = 0, b = 200},    -- Magenta
    },
    -- Neon holographic palette
    {
        {r = 0, g = 255, b = 200},    -- Cyan
        {r = 0, g = 200, b = 255},    -- Blue cyan
        {r = 100, g = 0, b = 255},    -- Blue
        {r = 200, g = 0, b = 255},    -- Purple
        {r = 255, g = 0, b = 200},    -- Magenta
        {r = 255, g = 100, b = 0},    -- Orange
    }
}

-- Global animation state to manage all holoshine effects
HoloShine.holoshine_animations = {}

-- Function to get color from cycle with position-based offset
HoloShine.getCycleColor = function (cycle_index, position_offset, phase_offset)
    local cycle = HoloShine.HOLOSHINE_COLORS[cycle_index] or HoloShine.HOLOSHINE_COLORS[1]
    local total_colors = #cycle
    
    -- Calculate color index with offset based on position and phase
    local index = ((position_offset + phase_offset) % total_colors) + 1
    return cycle[index]
end

-- Create holographic overlay with tiled sprites
HoloShine.create_holoshine_overlay = function (player_id, x, y, width, height, tile_size, color_cycle)
    tile_size = tile_size or 64  -- Default tile size 64x64 pixels
    color_cycle = color_cycle or 1  -- Default to first color cycle
    
    -- Calculate grid dimensions
    local grid_width = math.ceil(width / tile_size)
    local grid_height = math.ceil(height / tile_size)
    
    local overlay_tiles = {
        tiles = {},
        player_id = player_id,
        grid_width = grid_width,
        grid_height = grid_height,
        color_cycle = color_cycle,
        animation_id = nil,
        phase = 0,
        active = false
    }
    
    -- Create grid of tiles
    for gy = 1, grid_height do
        for gx = 1, grid_width do
            -- Calculate tile position
            local tile_x = x + ((gx - 1) * tile_size)
            local tile_y = y + ((gy - 1) * tile_size)
            
            -- Create unique sprite ID with player prefix
            local sprite_id = "holoshine_" .. player_id .. "_tile_" .. gx .. "_" .. gy
            
            -- Add UI element with empty_white texture (4x4 pixel)
            games.add_ui_element(
                sprite_id,
                player_id,
                "/server/assets/net-games/empty_white.png",
                "",  -- No animation
                "",  -- No animation state
                tile_x,
                tile_y,
                999,  -- High z-index to be on top
                2,  -- Scale: 4x4 * 2 = 8, then * scale for tile_size
                2
            )
            
            -- Calculate position offset for color variation
            local position_offset = (gx + gy) % 6  -- Creates diagonal pattern
            
            -- Get initial color from cycle
            local color = HoloShine.getCycleColor(color_cycle, position_offset, 0)
            
            -- Apply initial color with transparency
            games.update_ui_element(sprite_id, player_id, {
                r = color.r,
                g = color.g,
                b = color.b,
                a = 128,  -- 50% opacity
                color_mode = 1,
                sx = 2,  -- Ensure proper scale
                sy = 2
            })
            
            -- Store tile reference
            overlay_tiles.tiles[#overlay_tiles.tiles + 1] = {
                id = sprite_id,
                x = tile_x,
                y = tile_y,
                gx = gx,
                gy = gy,
                position_offset = position_offset,
                current_color = color
            }
        end
    end
    
    -- Store overlay in global state
    local overlay_key = player_id .. "_holoshine"
    HoloShine.holoshine_animations[overlay_key] = overlay_tiles
    
    return overlay_tiles
end

-- Update all tiles in an overlay with new colors
local function updateHoloshineColors(overlay, phase)
    if not overlay or not overlay.tiles or not overlay.active then
        return
    end
    
    for _, tile in ipairs(overlay.tiles) do
        -- Calculate new color based on position and current phase
        local color = HoloShine.getCycleColor(overlay.color_cycle, tile.position_offset, phase)
        
        -- Update only if color changed
        if color.r ~= tile.current_color.r or 
           color.g ~= tile.current_color.g or 
           color.b ~= tile.current_color.b then
            
            games.update_ui_element(tile.id, overlay.player_id, {
                r = color.r,
                g = color.g,
                b = color.b,
                a = 128
            })
            
            tile.current_color = color
        end
    end
end

-- Stop holographic animation
local function stop_holoshine_animation(overlay)
    if not overlay or not overlay.active then
        return false
    end
    
    if overlay.animation_id then
        AnimationEngine.stop_sequence(overlay.animation_id)
        overlay.animation_id = nil
    end
    
    overlay.active = false
    overlay.phase = 0
    return true
end

-- Start holographic animation using AnimationEngine sequence
local function start_holoshine_animation(overlay, speed)
    speed = speed or 1.0  -- Default speed
    
    if not overlay or overlay.active then
        return false
    end
    
    -- Stop any existing animation
    stop_holoshine_animation(overlay)
    
    local overlay_key = overlay.player_id .. "_holoshine"
    
    -- Create animation sequence using AnimationEngine
    local sequence_steps = {
        {
            type = "animate",
            duration = 6.0 / speed,  -- Complete cycle duration
            easing = "linear",
            on_update = function(values, t, phase)
                -- Calculate phase from 0 to 6 (one full color cycle)
                local phase = t * 6
                overlay.phase = phase
                updateHoloshineColors(overlay, phase)
            end,
            loop = true,
            ping_pong = false
        }
    }
    
    -- Create and start sequence
    local seq_id = AnimationEngine.create_animation_sequence(sequence_steps, {
        id = "holoshine_anim_" .. overlay.player_id,
        on_complete = function()
            -- Reset phase on complete (though loop should prevent this)
            overlay.phase = 0
        end
    })
    
    if seq_id then
        overlay.animation_id = seq_id
        overlay.active = true
        AnimationEngine.start_sequence(seq_id)
        
        -- Store reference
        HoloShine.holoshine_animations[overlay_key] = overlay
        return true
    end
    
    return false
end


-- Pause holographic animation
local function pause_holoshine_animation(overlay)
    if not overlay or not overlay.active or not overlay.animation_id then
        return false
    end
    
    AnimationEngine.pause_sequence(overlay.animation_id)
    return true
end

-- Resume holographic animation
local function resume_holoshine_animation(overlay)
    if not overlay or not overlay.animation_id then
        return false
    end
    
    AnimationEngine.resume_sequence(overlay.animation_id)
    overlay.active = true
    return true
end

-- Change color cycle for overlay
local function change_holoshine_colors(overlay, cycle_index)
    if not overlay then
        return false
    end
    
    cycle_index = cycle_index or 1
    if cycle_index < 1 or cycle_index > #HoloShine.HOLOSHINE_COLORS then
        cycle_index = 1
    end
    
    overlay.color_cycle = cycle_index
    
    -- Update colors immediately
    updateHoloshineColors(overlay, overlay.phase)
    return true
end

-- Remove holographic overlay and cleanup
local function remove_holoshine_overlay(overlay)
    if not overlay then
        return false
    end
    
    -- Stop animation
    stop_holoshine_animation(overlay)
    
    -- Remove all tiles
    for _, tile in ipairs(overlay.tiles) do
        games.remove_ui_element(tile.id, overlay.player_id)
    end
    
    -- Clear from global state
    local overlay_key = overlay.player_id .. "_holoshine"
    HoloShine.holoshine_animations[overlay_key] = nil
    
    return true
end

-- Create animated holoshine effect with wave pattern
local function create_animated_holoshine(player_id, x, y, width, height, options)
    options = options or {}
    local tile_size = options.tile_size or 4
    local color_cycle = options.color_cycle or 1
    local auto_start = options.auto_start ~= false
    
    -- Create overlay
    local overlay = HoloShine.create_holoshine_overlay(
        player_id, x, y, width, height, tile_size, color_cycle
    )
    
    -- Start animation if requested
    if auto_start then
        start_holoshine_animation(overlay, options.speed or 1.0)
    end
    
    return overlay
end

-- Get active holoshine overlay for player
local function get_holoshine_overlay(player_id)
    local overlay_key = player_id .. "_holoshine"
    return HoloShine.holoshine_animations[overlay_key]
end

-- Update function for manual animation control (call from tick event)
local function update_holoshine_tick(delta_time)
    for _, overlay in pairs(HoloShine.holoshine_animations) do
        if overlay.active and overlay.animation_id then
            -- AnimationEngine handles updates automatically
            -- This function is for manual updates if needed
        end
    end
end

-- Example usage with proper event integration
local function example_holoshine_usage(player_id)
    -- Create animated holoshine covering entire screen
    local overlay = create_animated_holoshine(
        player_id,
        0, 0,  -- x, y
        640, 480,  -- width, height
        {
            tile_size = 64,
            color_cycle = 1,
            speed = 1.0,
            auto_start = true
        }
    )
    
    -- Example: Change colors after 5 seconds
    Net:once("tick", function(event)
        if event.tick_count == 300 then  -- ~5 seconds at 60fps
            change_holoshine_colors(overlay, 2)  -- Switch to rainbow palette
        end
    end)
    
    return overlay
end

-- Module exports
return {
    -- Core functions
    create_holoshine_overlay = HoloShine.create_holoshine_overlay,
    create_animated_holoshine = create_animated_holoshine,
    
    -- Animation control
    start_holoshine_animation = start_holoshine_animation,
    stop_holoshine_animation = stop_holoshine_animation,
    pause_holoshine_animation = pause_holoshine_animation,
    resume_holoshine_animation = resume_holoshine_animation,
    change_holoshine_colors = change_holoshine_colors,
    
    -- Management
    remove_holoshine_overlay = remove_holoshine_overlay,
    get_holoshine_overlay = get_holoshine_overlay,
    
    -- Utility
    update_holoshine_tick = update_holoshine_tick,
    example_holoshine_usage = example_holoshine_usage,
    
    -- Constants
    HOLOSHINE_COLORS = HoloShine.HOLOSHINE_COLORS
}