-- generic_nameplate.lua
-- A reusable nameplate system with configurable visuals and animations

local GenericNameplate = {}
GenericNameplate.__index = GenericNameplate

-- =====================================================
-- MATH UTILITIES
-- =====================================================
local function ceil_div(a, b)
    return math.floor((a + b - 1) / b)
end

local function clamp(value, min, max)
    return math.min(math.max(value, min), max)
end

-- =====================================================
-- CONFIGURABLE DEFAULTS
-- =====================================================
local DEFAULT_CONFIG = {
    -- Visual assets
    textures = {
        left = "/server/assets/net-games/displayer/textbox_bn6_nameplate_left.png",
        middle = "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle.png",
        right = "/server/assets/net-games/displayer/textbox_bn6_nameplate_right.png",
        left_frame = "/server/assets/net-games/displayer/textbox_bn6_nameplate_left_frame_gray.png",
        middle_frame = "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle_frame_gray.png",
        right_frame = "/server/assets/net-games/displayer/textbox_bn6_nameplate_right_frame_gray.png",
    },
    
    -- Sizing (at scale=1)
    slice_widths = { left = 5, middle = 3, right = 5 },
    height = 13,
    
    -- Animation defaults
    unfold_duration = 0.14,
    close_duration = 0.12,
    bob_amplitude = 3,
    bob_speed = 1.0,
    
    -- Layout defaults
    padding = 4,
    gap_x = 6,
    gap_y = 4,
    
    -- Rendering
    z_offset = 3,
    default_scale = 2.0,
    max_middle_slices = 60,
    
    -- Text
    default_font = "TINY_BLACK",
    
    -- Debug
    debug = false,
}

-- =====================================================
-- ANIMATION SYSTEM
-- =====================================================
local AnimationSystem = {
    UNFOLD = "unfold",
    CLOSE = "close",
    BOBBING = "bobbing",
    STATIC = "static",
}

local function update_animation(state, dt, animation_type, config)
    dt = math.min(dt or 0, 1/30)
    
    if animation_type == AnimationSystem.UNFOLD then
        state.progress = state.progress + dt / config.duration
        state.progress = clamp(state.progress, 0, 1)
        return state.progress >= 1
        
    elseif animation_type == AnimationSystem.CLOSE then
        state.progress = state.progress + dt / config.duration
        state.progress = clamp(state.progress, 0, 1)
        return state.progress >= 1
        
    elseif animation_type == AnimationSystem.BOBBING then
        state.time = (state.time or 0) + dt * config.speed
        return math.sin(state.time) * config.amplitude
    end
    
    return nil
end

-- =====================================================
-- SPRITE MANAGEMENT
-- =====================================================
local SpriteManager = {}

function SpriteManager:new(prefix)
    local o = setmetatable({}, self)
    o.prefix = prefix or "namplate"
    o.sprites = {}
    return o
end

function SpriteManager:allocate_sprites(player_id, sprite_ids, texture_path)
    for _, sprite_id in ipairs(sprite_ids) do
        if not self.sprites[sprite_id] then
            Net.player_alloc_sprite(player_id, sprite_id, { texture_path = texture_path })
            self.sprites[sprite_id] = true
        end
    end
end

function SpriteManager:draw_sprites(player_id, sprite_data)
    for _, data in ipairs(sprite_data) do
        Net.player_draw_sprite(player_id, data.sprite_id, data.params)
    end
end

function SpriteManager:erase_sprites(player_id, sprite_ids)
    for _, sprite_id in ipairs(sprite_ids) do
        Net.player_erase_sprite(player_id, sprite_id)
        self.sprites[sprite_id] = nil
    end
end

-- =====================================================
-- GENERIC NAMEPLATE CLASS
-- =====================================================
function GenericNameplate:new(font_system, custom_config)
    local o = setmetatable({}, self)
    
    -- Merge custom config with defaults
    o.config = {}
    for k, v in pairs(DEFAULT_CONFIG) do
        o.config[k] = custom_config and custom_config[k] or v
    end
    if custom_config then
        for k, v in pairs(custom_config) do
            o.config[k] = v
        end
    end
    
    o.font_system = font_system
    o.sprite_manager = SpriteManager:new(o.config.sprite_prefix)
    
    return o
end

function GenericNameplate:calculate_dimensions(text, config_overrides)
    local config = self.config
    local scale = config_overrides.scale or config.default_scale
    
    -- Calculate text width
    local font = config_overrides.font or config.default_font
    local text_scale = config_overrides.text_scale or scale
    local text_width = self.font_system:getTextWidth(text, font, text_scale)
    
    -- Calculate padding
    local pad_px = (config_overrides.padding or config.padding) * scale
    
    -- Calculate required slices
    local inner_needed = math.max(1, math.floor(text_width + pad_px * 2))
    local mid_w = config.slice_widths.middle * scale
    local mids_target = clamp(
        ceil_div(inner_needed, mid_w),
        1,
        config.max_middle_slices
    )
    
    -- Calculate total width
    local total_width = 
        (config.slice_widths.left + config.slice_widths.right) * scale + 
        (mids_target * mid_w)
    
    return {
        text_width = text_width,
        total_width = total_width,
        middle_slices = mids_target,
        middle_width = mid_w,
        height = config.height * scale,
        scale = scale,
        text_scale = text_scale,
    }
end

function GenericNameplate:calculate_position(parent_x, parent_y, parent_width, dims, anchor_config)
    local config = self.config
    local scale = dims.scale
    
    local gap_x = (anchor_config.gap_x or config.gap_x) * scale
    local gap_y = (anchor_config.gap_y or config.gap_y) * scale
    local anchor = anchor_config.anchor or "above_left"
    local align = anchor_config.align or "left"
    
    local x, y
    
    if anchor == "above" then
        -- Above the parent element
        if align == "center" then
            x = parent_x + (parent_width - dims.total_width) / 2
        elseif align == "right" then
            x = parent_x + parent_width - dims.total_width - gap_x
        else -- left
            x = parent_x + gap_x
        end
        y = parent_y - dims.height - gap_y
    else
        -- Legacy: above-left outside
        x = parent_x - dims.total_width - gap_x
        y = parent_y - dims.height - gap_y
    end
    
    -- Apply absolute offsets if provided
    if anchor_config.offset_x then
        x = x + anchor_config.offset_x
    end
    if anchor_config.offset_y then
        y = y + anchor_config.offset_y
    end
    
    -- Round to pixel grid
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)
    
    local center_x = x + (dims.total_width / 2)
    
    return {
        x = x,
        y = y,
        base_y = y,
        center_x = center_x,
        text_x = x + (config.slice_widths.left * scale) + 
                 ((anchor_config.padding or config.padding) * scale),
        text_y = y + (3 * scale) + 2,
    }
end

function GenericNameplate:create_plate(player_id, plate_id, text, parent_info, style_config)
    -- Ensure assets are loaded
    self:ensure_assets_loaded(player_id)
    
    -- Calculate dimensions
    local dims = self:calculate_dimensions(text, style_config)
    
    -- Calculate position
    local pos = self:calculate_position(
        parent_info.x, parent_info.y, parent_info.width,
        dims, style_config.anchor or {}
    )
    
    -- Create plate state
    local plate = {
        id = plate_id,
        player_id = player_id,
        text = text,
        dimensions = dims,
        position = pos,
        style = {
            font = style_config.font or self.config.default_font,
            text_scale = style_config.text_scale or dims.text_scale,
            frame_tint = style_config.frame_tint,
            z_order = (parent_info.z_order or 100) + self.config.z_offset,
        },
        animation = {
            state = "unfolding",
            progress = 0,
            bobbing = style_config.bobbing or true,
            bob_time = 0,
        },
        visible = true,
        sprites = {},
    }
    
    -- Store reference
    self.plates = self.plates or {}
    self.plates[plate_id] = plate
    
    return plate
end

function GenericNameplate:ensure_assets_loaded(player_id)
    if self.assets_loaded then return end
    
    local config = self.config
    
    -- Load base textures
    Net.provide_asset_for_player(player_id, config.textures.left)
    Net.provide_asset_for_player(player_id, config.textures.middle)
    Net.provide_asset_for_player(player_id, config.textures.right)
    
    -- Load frame textures if available
    if config.textures.left_frame then
        Net.provide_asset_for_player(player_id, config.textures.left_frame)
    end
    if config.textures.middle_frame then
        Net.provide_asset_for_player(player_id, config.textures.middle_frame)
    end
    if config.textures.right_frame then
        Net.provide_asset_for_player(player_id, config.textures.right_frame)
    end
    
    self.assets_loaded = true
end

function GenericNameplate:update_plate(plate, dt)
    if not plate.visible then return end
    
    local config = self.config
    
    -- Update animation
    if plate.animation.state == "unfolding" then
        plate.animation.progress = plate.animation.progress + dt / config.unfold_duration
        if plate.animation.progress >= 1 then
            plate.animation.state = "idle"
            plate.animation.progress = 1
        end
    elseif plate.animation.state == "closing" then
        plate.animation.progress = plate.animation.progress + dt / config.close_duration
        if plate.animation.progress >= 1 then
            plate.visible = false
            return false -- Signal for cleanup
        end
    end
    
    -- Update bobbing
    if plate.animation.bobbing and plate.animation.state == "idle" then
        plate.animation.bob_time = plate.animation.bob_time + dt * config.bob_speed
        local bob_offset = math.sin(plate.animation.bob_time) * config.bob_amplitude * config.default_scale
        plate.position.current_y = plate.position.base_y + math.floor(bob_offset + 0.5)
    else
        plate.position.current_y = plate.position.base_y
    end
    
    -- Calculate current visible slices
    local visible_slices = math.floor(
        plate.dimensions.middle_slices * plate.animation.progress + 0.0001
    )
    
    -- Render plate
    self:render_plate(plate, visible_slices)
    
    -- Render text if fully unfolded and not closing
    if plate.animation.state == "idle" and plate.animation.progress >= 1 then
        self:render_text(plate)
    end
    
    return true
end

function GenericNameplate:render_plate(plate, visible_slices)
    local config = self.config
    local scale = plate.dimensions.scale
    local z = plate.style.z_order
    
    -- Calculate positions
    local left_x = plate.position.x
    local mid_x = left_x + (config.slice_widths.left * scale)
    local right_x = mid_x + (visible_slices * plate.dimensions.middle_width)
    
    -- Draw left slice
    self:draw_slice(plate, "left", left_x, plate.position.current_y, z, scale)
    
    -- Draw middle slices
    for i = 0, visible_slices - 1 do
        local x = mid_x + (i * plate.dimensions.middle_width)
        self:draw_slice(plate, "middle_" .. i, x, plate.position.current_y, z, scale)
    end
    
    -- Draw right slice
    self:draw_slice(plate, "right", right_x, plate.position.current_y, z, scale)
    
    -- Clean up unused slices
    for i = visible_slices, config.max_middle_slices - 1 do
        self:erase_slice(plate, "middle_" .. i)
    end
end

function GenericNameplate:draw_slice(plate, slice_type, x, y, z, scale)
    local config = self.config
    local sprite_id = plate.id .. "_" .. slice_type
    
    -- Base slice
    local texture = config.textures[slice_type:gsub("_%d+", "")]
    if texture then
        Net.player_draw_sprite(plate.player_id, texture, {
            id = sprite_id,
            x = x, y = y, z = z,
            sx = scale, sy = scale,
            color_mode = 0,
        })
    end
    
    -- Frame overlay with tint
    if plate.style.frame_tint and config.textures[slice_type:gsub("_%d+", "") .. "_frame"] then
        local frame_sprite_id = sprite_id .. "_frame"
        local tint = plate.style.frame_tint
        
        Net.player_draw_sprite(plate.player_id, config.textures[slice_type .. "_frame"], {
            id = frame_sprite_id,
            x = x, y = y, z = z + 1,
            sx = scale, sy = scale,
            r = tint.r or 255,
            g = tint.g or 255,
            b = tint.b or 255,
            a = tint.a or 255,
            color_mode = tint.color_mode or 2,
        })
    end
end

function GenericNameplate:erase_slice(plate, slice_type)
    local sprite_id = plate.id .. "_" .. slice_type
    Net.player_erase_sprite(plate.player_id, sprite_id)
    Net.player_erase_sprite(plate.player_id, sprite_id .. "_frame")
end

function GenericNameplate:render_text(plate)
    self.font_system:drawTextWithId(
        plate.player_id,
        plate.text,
        plate.position.text_x,
        plate.position.text_y,
        plate.style.font,
        plate.style.text_scale,
        plate.style.z_order + 2,
        plate.id .. "_text"
    )
end

function GenericNameplate:remove_plate(plate_id)
    local plate = self.plates and self.plates[plate_id]
    if not plate then return end
    
    -- Start closing animation
    plate.animation.state = "closing"
    plate.animation.progress = 0
    
    -- Schedule removal
    self.scheduled_removals = self.scheduled_removals or {}
    self.scheduled_removals[plate_id] = true
end

function GenericNameplate:cleanup_completed()
    if not self.scheduled_removals then return end
    
    for plate_id, _ in pairs(self.scheduled_removals) do
        local plate = self.plates[plate_id]
        if plate and not plate.visible then
            -- Clean up text
            Net.player_erase_sprite(plate.player_id, plate.id .. "_text")
            
            -- Remove plate
            self.plates[plate_id] = nil
            self.scheduled_removals[plate_id] = nil
        end
    end
end

function GenericNameplate:update_all(dt)
    if not self.plates then return end
    
    for plate_id, plate in pairs(self.plates) do
        self:update_plate(plate, dt)
    end
    
    self:cleanup_completed()
end

-- =====================================================
-- FACTORY FUNCTION FOR EASY CREATION
-- =====================================================
function GenericNameplate.create(config_overrides)
    -- This is a factory that can be used when you don't have a font system yet
    return function(font_system)
        return GenericNameplate:new(font_system, config_overrides)
    end
end

-- =====================================================
-- EXAMPLE USAGE
-- =====================================================
--[[
-- Example 1: Basic usage
local NameplateFactory = require("generic_nameplate")
local nameplate = NameplateFactory(fontSystem)

-- Create a nameplate
local parent_info = {
    x = 100, y = 200, width = 300, z_order = 50
}

local style = {
    font = "TINY_BLACK",
    text_scale = 2.0,
    frame_tint = { r = 255, g = 200, b = 100, a = 255, color_mode = 2 },
    anchor = { anchor = "above", align = "center", gap_x = 10, gap_y = 5 },
    bobbing = true,
}

local plate = nameplate:create_plate(player_id, "player1_name", "Player One", parent_info, style)

-- In your game loop
nameplate:update_all(dt)

-- When done
nameplate:remove_plate("player1_name")

-- Example 2: Custom configuration
local customConfig = {
    textures = {
        left = "/assets/ui/nameplates/fancy_left.png",
        middle = "/assets/ui/nameplates/fancy_middle.png",
        right = "/assets/ui/nameplates/fancy_right.png",
    },
    slice_widths = { left = 10, middle = 5, right = 10 },
    height = 20,
    unfold_duration = 0.2,
    bob_amplitude = 5,
}

local FancyNameplateFactory = GenericNameplate.create(customConfig)
local fancyNameplate = FancyNameplateFactory(fontSystem)
]]

return GenericNameplate