-- ui_expanding_panel.lua
-- A generic expanding panel system with 9-slice scaling, text, and animations

local UIExpandingPanel = {}
UIExpandingPanel.__index = UIExpandingPanel

-- =====================================================
-- MATH UTILITIES
-- =====================================================
local function ceil_div(a, b)
    return math.floor((a + b - 1) / b)
end

local function snap_to_pixel(value)
    return math.floor(value + 0.5)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- =====================================================
-- SPRITE BATCH MANAGER
-- =====================================================
local SpriteBatch = {}
SpriteBatch.__index = SpriteBatch

function SpriteBatch:new(player_id, prefix)
    local o = setmetatable({}, self)
    o.player_id = player_id
    o.prefix = prefix or "panel"
    o.sprites = {}
    return o
end

function SpriteBatch:allocate_slice(name, texture_path)
    local sprite_id = self.prefix .. "_" .. name
    if not self.sprites[sprite_id] then
        Net.player_alloc_sprite(self.player_id, sprite_id, { texture_path = texture_path })
        self.sprites[sprite_id] = true
    end
    return sprite_id
end

function SpriteBatch:draw_slice(sprite_id, params)
    Net.player_draw_sprite(self.player_id, sprite_id, params)
end

function SpriteBatch:erase_slice(draw_id)
    Net.player_erase_sprite(self.player_id, draw_id)
end

function SpriteBatch:dispose()
    for sprite_id in pairs(self.sprites) do
        Net.player_erase_sprite(self.player_id, sprite_id)
    end
    self.sprites = {}
end

-- =====================================================
-- NINE-SLICE PANEL CLASS
-- =====================================================
function UIExpandingPanel:new(options)
    options = options or {}
    local o = setmetatable({}, self)
    
    -- Core configuration
    o.config = {
        -- Assets
        textures = {
            left = options.left_texture or "/server/assets/net-games/displayer/textbox_bn6_nameplate_left.png",
            middle = options.middle_texture or "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle.png",
            right = options.right_texture or "/server/assets/net-games/displayer/textbox_bn6_nameplate_right.png",
            
            -- Optional overlay textures
            left_overlay = options.left_overlay,
            middle_overlay = options.middle_overlay,
            right_overlay = options.right_overlay,
        },
        
        -- Slicing dimensions (pixels at scale=1)
        slice_widths = {
            left = options.left_width or 5,
            middle = options.middle_width or 3,
            right = options.right_width or 5,
        },
        height = options.height or 13,
        
        -- Animation
        animation = {
            unfold_duration = options.unfold_duration or 0.14,
            close_duration = options.close_duration or 0.12,
            bob_amplitude = options.bob_amplitude or 3,
            bob_speed = options.bob_speed or 1.0,
        },
        
        -- Layout
        padding = options.padding or 4,
        max_slices = options.max_slices or 60,
    }
    
    o.instances = {}
    o.sprite_batches = {}
    
    return o
end

-- =====================================================
-- INSTANCE MANAGEMENT
-- =====================================================
function UIExpandingPanel:create_instance(instance_id, player_id, content)
    -- Ensure assets for this player
    self:ensure_assets_loaded(player_id, instance_id)
    
    -- Create instance state
    local instance = {
        id = instance_id,
        player_id = player_id,
        content = content or {},
        state = {
            visible = true,
            animation = "unfolding",
            progress = 0,
            bobbing = content.bobbing or false,
            bob_time = 0,
        },
        render_data = nil,
        text_id = instance_id .. "_text",
    }
    
    -- Calculate initial render data
    self:update_render_data(instance)
    
    self.instances[instance_id] = instance
    return instance
end

function UIExpandingPanel:ensure_assets_loaded(player_id, instance_id)
    local batch = self.sprite_batches[instance_id]
    if batch then return batch end
    
    batch = SpriteBatch:new(player_id, instance_id)
    
    -- Allocate base slices
    batch:allocate_slice("left", self.config.textures.left)
    batch:allocate_slice("right", self.config.textures.right)
    for i = 0, self.config.max_slices - 1 do
        batch:allocate_slice("mid" .. i, self.config.textures.middle)
    end
    
    -- Allocate overlay slices if provided
    if self.config.textures.left_overlay then
        batch:allocate_slice("left_overlay", self.config.textures.left_overlay)
    end
    if self.config.textures.right_overlay then
        batch:allocate_slice("right_overlay", self.config.textures.right_overlay)
    end
    if self.config.textures.middle_overlay then
        for i = 0, self.config.max_slices - 1 do
            batch:allocate_slice("mid_overlay" .. i, self.config.textures.middle_overlay)
        end
    end
    
    self.sprite_batches[instance_id] = batch
    return batch
end

function UIExpandingPanel:update_render_data(instance)
    local config = self.config
    local content = instance.content
    local scale = content.scale or 2.0
    
    -- Calculate text dimensions if text is provided
    local text_width = 0
    if content.text and instance.font_system then
        local font = content.font or "TINY_BLACK"
        local text_scale = content.text_scale or scale
        text_width = instance.font_system:getTextWidth(content.text, font, text_scale)
    end
    
    -- Calculate required width
    local padding_px = (content.padding or config.padding) * scale
    local inner_needed = math.max(1, text_width + padding_px * 2)
    
    -- Calculate number of middle slices needed
    local middle_slice_width = config.slice_widths.middle * scale
    local middle_slices_needed = math.min(
        config.max_slices,
        math.max(1, ceil_div(inner_needed, middle_slice_width))
    )
    
    -- Calculate total width
    local total_width = (config.slice_widths.left + config.slice_widths.right) * scale
                      + (middle_slices_needed * middle_slice_width)
    
    -- Calculate position
    local x, y = content.x or 0, content.y or 0
    if content.anchor_to then
        local anchor = content.anchor_to
        local anchor_x, anchor_y = anchor.x or 0, anchor.y or 0
        local anchor_width = anchor.width or 0
        
        local gap_x = (content.gap_x or 0) * scale
        local gap_y = (content.gap_y or 0) * scale
        
        if content.anchor == "above" then
            y = anchor_y - (config.height * scale) - gap_y
            
            if content.align == "center" then
                x = anchor_x + (anchor_width - total_width) / 2
            elseif content.align == "right" then
                x = anchor_x + anchor_width - total_width - gap_x
            else
                x = anchor_x + gap_x
            end
        elseif content.anchor == "below" then
            y = anchor_y + (anchor.height or 0) + gap_y
            
            if content.align == "center" then
                x = anchor_x + (anchor_width - total_width) / 2
            elseif content.align == "right" then
                x = anchor_x + anchor_width - total_width - gap_x
            else
                x = anchor_x + gap_x
            end
        elseif content.anchor == "left" then
            x = anchor_x - total_width - gap_x
            y = anchor_y + gap_y
        elseif content.anchor == "right" then
            x = anchor_x + anchor_width + gap_x
            y = anchor_y + gap_y
        end
    end
    
    -- Round to pixel grid
    x = snap_to_pixel(x)
    y = snap_to_pixel(y)
    
    -- Store render data
    instance.render_data = {
        x = x,
        y = y,
        base_y = y,
        total_width = total_width,
        middle_slices_needed = middle_slices_needed,
        middle_slice_width = middle_slice_width,
        scale = scale,
        text_x = x + (config.slice_widths.left * scale) + padding_px,
        text_y = y + (3 * scale) + 2,
        text_scale = content.text_scale or scale,
        font = content.font or "TINY_BLACK",
        z = content.z or 100,
        overlay_tint = content.overlay_tint,
    }
end

-- =====================================================
-- ANIMATION AND RENDERING
-- =====================================================
function UIExpandingPanel:update(instance_id, dt)
    local instance = self.instances[instance_id]
    if not instance or not instance.state.visible then return false end
    
    dt = math.min(dt or 0, 1/30)
    local state = instance.state
    
    -- Update animation
    if state.animation == "unfolding" then
        state.progress = state.progress + dt / self.config.animation.unfold_duration
        if state.progress >= 1 then
            state.progress = 1
            state.animation = "idle"
        end
    elseif state.animation == "closing" then
        state.progress = state.progress + dt / self.config.animation.close_duration
        if state.progress >= 1 then
            state.visible = false
            return false -- Signal for cleanup
        end
    end
    
    -- Update bobbing
    if state.bobbing and state.animation == "idle" then
        state.bob_time = state.bob_time + dt * self.config.animation.bob_speed
        local bob_offset = math.sin(state.bob_time) * self.config.animation.bob_amplitude * instance.render_data.scale
        instance.render_data.y = snap_to_pixel(instance.render_data.base_y + bob_offset)
    else
        instance.render_data.y = instance.render_data.base_y
    end
    
    -- Render
    self:render_instance(instance)
    
    return true
end

function UIExpandingPanel:render_instance(instance)
    local batch = self.sprite_batches[instance.id]
    if not batch then return end
    
    local config = self.config
    local render = instance.render_data
    local state = instance.state
    
    -- Calculate visible slices based on animation progress
    local visible_slices = math.floor(render.middle_slices_needed * state.progress + 0.0001)
    
    -- Calculate positions
    local left_x = render.x
    local middle_x = left_x + (config.slice_widths.left * render.scale)
    local right_x = middle_x + (visible_slices * render.middle_slice_width)
    
    -- Draw slices
    self:draw_slice(batch, "left", left_x, render.y, render.z)
    self:draw_slice(batch, "right", right_x, render.y, render.z)
    
    for i = 0, visible_slices - 1 do
        local x = middle_x + (i * render.middle_slice_width)
        self:draw_slice(batch, "mid" .. i, x, render.y, render.z)
    end
    
    -- Clean up unused middle slices
    for i = visible_slices, config.max_slices - 1 do
        batch:erase_slice(instance.id .. "_M" .. i)
        batch:erase_slice(instance.id .. "_FM" .. i)
    end
    
    -- Draw text if fully visible and not closing
    if state.animation == "idle" and state.progress >= 1 and instance.content.text and instance.font_system then
        instance.font_system:drawTextWithId(
            instance.player_id,
            instance.content.text,
            render.text_x,
            render.text_y,
            render.font,
            render.text_scale,
            render.z + 2,
            instance.text_id
        )
    else
        -- Erase text during animation
        if instance.font_system then
            instance.font_system:eraseTextDisplay(instance.player_id, instance.text_id)
        end
    end
end

function UIExpandingPanel:draw_slice(batch, slice_name, x, y, z)
    local config = self.config
    local render = self.instances[batch.prefix] and self.instances[batch.prefix].render_data
    
    -- Draw base slice
    local draw_id = batch.prefix .. "_" .. slice_name:gsub("mid", "M"):gsub("left", "L"):gsub("right", "R")
    batch:draw_slice(slice_name, {
        id = draw_id,
        x = x, y = y, z = z,
        sx = render.scale, sy = render.scale,
        color_mode = 0,
    })
    
    -- Draw overlay if available and tint is specified
    local overlay_name = slice_name .. "_overlay"
    if config.textures[slice_name .. "_overlay"] and render.overlay_tint then
        local overlay_draw_id = draw_id .. "_F"
        local tint = render.overlay_tint
        
        batch:draw_slice(overlay_name, {
            id = overlay_draw_id,
            x = x, y = y, z = z + 1,
            sx = render.scale, sy = render.scale,
            r = tint.r or 255,
            g = tint.g or 255,
            b = tint.b or 255,
            a = tint.a or 255,
            color_mode = tint.color_mode or 2,
        })
    end
end

-- =====================================================
-- PUBLIC API
-- =====================================================
function UIExpandingPanel:update_all(dt)
    for instance_id, instance in pairs(self.instances) do
        if not self:update(instance_id, dt) then
            -- Instance is done, clean it up
            self:remove_instance(instance_id)
        end
    end
end

function UIExpandingPanel:remove_instance(instance_id)
    local instance = self.instances[instance_id]
    if not instance then return end
    
    -- Erase text
    if instance.font_system then
        instance.font_system:eraseTextDisplay(instance.player_id, instance.text_id)
    end
    
    -- Dispose sprite batch
    local batch = self.sprite_batches[instance_id]
    if batch then
        batch:dispose()
        self.sprite_batches[instance_id] = nil
    end
    
    -- Remove instance
    self.instances[instance_id] = nil
end

function UIExpandingPanel:set_font_system(instance_id, font_system)
    local instance = self.instances[instance_id]
    if instance then
        instance.font_system = font_system
    end
end

function UIExpandingPanel:update_content(instance_id, new_content)
    local instance = self.instances[instance_id]
    if not instance then return end
    
    -- Merge new content
    for k, v in pairs(new_content) do
        instance.content[k] = v
    end
    
    -- Recalculate render data
    self:update_render_data(instance)
end

function UIExpandingPanel:begin_close(instance_id, close_duration)
    local instance = self.instances[instance_id]
    if not instance then return end
    
    instance.state.animation = "closing"
    instance.state.progress = 0
    
    if close_duration then
        self.config.animation.close_duration = close_duration
    end
end

-- =====================================================
-- FACTORY FUNCTION
-- =====================================================
function UIExpandingPanel.create_preset(preset_name)
    local presets = {
        -- BN6-style nameplate preset
        bn6_nameplate = function()
            return UIExpandingPanel:new({
                left_texture = "/server/assets/net-games/displayer/textbox_bn6_nameplate_left.png",
                middle_texture = "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle.png",
                right_texture = "/server/assets/net-games/displayer/textbox_bn6_nameplate_right.png",
                left_overlay = "/server/assets/net-games/displayer/textbox_bn6_nameplate_left_frame_gray.png",
                middle_overlay = "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle_frame_gray.png",
                right_overlay = "/server/assets/net-games/displayer/textbox_bn6_nameplate_right_frame_gray.png",
                left_width = 5,
                middle_width = 3,
                right_width = 5,
                height = 13,
                unfold_duration = 0.14,
                close_duration = 0.12,
                bob_amplitude = 3,
                padding = 4,
                max_slices = 60,
            })
        end,
        
        -- Simple panel preset (no overlay)
        simple_panel = function()
            return UIExpandingPanel:new({
                left_width = 10,
                middle_width = 5,
                right_width = 10,
                height = 20,
                unfold_duration = 0.2,
                close_duration = 0.15,
                padding = 8,
                max_slices = 100,
            })
        end,
        
        -- Health bar preset
        health_bar = function()
            return UIExpandingPanel:new({
                left_texture = "/server/assets/net-games/displayer/textbox_bn6_nameplate_left.png",
                middle_texture = "/server/assets/net-games/displayer/textbox_bn6_nameplate_middle.png",
                right_texture = "/server/assets/net-games/displayer/textbox_bn6_nameplate_right.png",
                left_width = 4,
                middle_width = 2,
                right_width = 4,
                height = 8,
                unfold_duration = 0.1,
                close_duration = 0.1,
                padding = 2,
                max_slices = 200,
            })
        end,
    }
    
    return presets[preset_name] or function()
        return UIExpandingPanel:new()
    end
end

return UIExpandingPanel