-- Text Display System with Marquee and Optional Backdrop Support
TextDisplay = {}
TextDisplay.__index = TextDisplay

function TextDisplay:init()
    self.player_texts = {}
    self.font_system = require("scripts/displayer/font-system")
    
    -- Marquee speed definitions (pixels per second)
    self.marquee_speeds = {
        slow = 30,    -- 30 pixels per second
        medium = 60,  -- 60 pixels per second  
        quick = 120   -- 120 pixels per second
    }
    
    -- Screen dimensions
    self.screen_width = 240
    self.screen_height = 160
    
    -- Backdrop sprite definition
    self.backdrop_sprite = {
        sprite_id = 5000,
        texture_path = "/server/assets/displayer/marquee-backdrop.png", -- 1x1 white pixel
        anim_path = nil
    }
    
    -- Marquee wrapping gap (pixels of blank space when text wraps)
    self.marquee_wrap_gap = 40
    
    Net:on("player_join", function(event)
        self:setupPlayerTextDisplays(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerTextDisplays(event.player_id)
    end)
    
    -- Update marquees every tick
    Net:on("tick", function(event)
        self:updateMarquees(event.delta_time)
    end)
    
    return self
end

function TextDisplay:setupPlayerTextDisplays(player_id)
    self.player_texts[player_id] = {
        active_texts = {},
        next_obj_id = 1,
        allocated_backdrop = false
    }
    
    -- Allocate backdrop sprite for this player
    Net.provide_asset_for_player(player_id, self.backdrop_sprite.texture_path)
    Net.player_alloc_sprite(player_id, self.backdrop_sprite.sprite_id, {
        texture_path = self.backdrop_sprite.texture_path
    })
    self.player_texts[player_id].allocated_backdrop = true
end

function TextDisplay:cleanupPlayerTextDisplays(player_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        -- Remove all active texts
        for text_id, text_data in pairs(player_data.active_texts) do
            self:removeText(player_id, text_id)
        end
        
        -- Deallocate backdrop sprite
        if player_data.allocated_backdrop then
            Net.player_dealloc_sprite(player_id, self.backdrop_sprite.sprite_id)
        end
        
        self.player_texts[player_id] = nil
    end
end

function TextDisplay:drawText(player_id, text, x, y, font_name, scale, z_order)
    font_name = font_name or "THICK"
    scale = scale or 1.0
    z_order = z_order or 100
    
    local player_data = self.player_texts[player_id]
    if not player_data then return nil end
    
    local text_id = "text_" .. player_data.next_obj_id
    player_data.next_obj_id = player_data.next_obj_id + 1
    
    local text_data = {
        type = "static",
        text = text,
        x = x,
        y = y,
        font = font_name,
        scale = scale,
        z_order = z_order,
        display_id = nil,
        character_objects = {}
    }
    
    -- Draw the text
    text_data.display_id = self.font_system:drawText(player_id, text, x, y, font_name, scale, z_order)
    
    player_data.active_texts[text_id] = text_data
    return text_id
end

function TextDisplay:drawMarqueeText(player_id, marquee_id, text, y, font_name, scale, z_order, speed, backdrop)
    font_name = font_name or "THICK"
    scale = scale or 1.0
    z_order = z_order or 100
    speed = speed or "medium"
    
    local player_data = self.player_texts[player_id]
    if not player_data then return nil end
    
    local text_width = self.font_system:getTextWidth(text, font_name, scale)
    local speed_value = self.marquee_speeds[speed] or self.marquee_speeds.medium
    
    -- Calculate marquee bounds based on backdrop if provided
    local bounds_left, bounds_right, bounds_width
    local start_x
    
    if backdrop then
        local padding_x = backdrop.padding_x or 4
        bounds_left = backdrop.x + padding_x
        bounds_right = backdrop.x + backdrop.width - padding_x
        bounds_width = bounds_right - bounds_left
        start_x = bounds_right -- Start at right edge of backdrop bounds
    else
        bounds_left = 0
        bounds_right = self.screen_width
        bounds_width = self.screen_width
        start_x = self.screen_width -- Start off-screen right
    end
    
    local marquee_data = {
        type = "marquee",
        text = text,
        y = y,
        font = font_name,
        scale = scale,
        z_order = z_order,
        speed = speed_value,
        current_x = start_x,
        text_width = text_width,
        display_id = nil,
        backdrop = backdrop or nil,
        bounds_left = bounds_left,
        bounds_right = bounds_right,
        bounds_width = bounds_width,
        character_objects = {},
        individual_chars = {}, -- Store individual character data for wrapping
        wrap_gap = self.marquee_wrap_gap, -- Store the wrap gap for this marquee
        last_wrap_time = 0, -- Track when we last wrapped to prevent rapid wrapping
        wrap_cooldown = 0.5 -- Minimum time between wraps (seconds)
    }
    
    -- Pre-calculate character positions for individual wrapping
    self:setupIndividualCharacters(marquee_data)
    
    -- Draw backdrop if specified
    if backdrop then
        self:drawBackdrop(player_id, marquee_id, marquee_data, backdrop)
    end
    
    -- Draw initial marquee text with individual character tracking
    self:drawMarqueeCharacters(player_id, marquee_id, marquee_data)
    
    player_data.active_texts[marquee_id] = marquee_data
    return marquee_id
end

function TextDisplay:setupIndividualCharacters(marquee_data)
    local font_name = marquee_data.font
    local char_widths = self.font_system.char_widths[font_name] or self.font_system.char_widths.THICK
    local current_x = marquee_data.current_x
    
    marquee_data.individual_chars = {}
    
    for i = 1, #marquee_data.text do
        local char = marquee_data.text:sub(i, i)
        local char_width = (char_widths[char] or char_widths[" "]) * marquee_data.scale
        
        table.insert(marquee_data.individual_chars, {
            char = char,
            width = char_width,
            original_x = current_x,
            current_x = current_x,
            obj_id = nil,
            anim_state = font_name .. "_" .. char,  -- Build animation state name
            index = i  -- Store original position for consistent spacing
        })
        
        current_x = current_x + char_width + 1 -- Add consistent spacing
    end
    
    -- Store total text width for proper wrapping
    marquee_data.total_text_width = current_x - marquee_data.current_x - 1
end

function TextDisplay:drawMarqueeCharacters(player_id, marquee_id, marquee_data)
    -- Clear existing character objects
    for _, char_data in ipairs(marquee_data.individual_chars) do
        if char_data.obj_id then
            Net.player_erase_sprite(player_id, char_data.obj_id)
        end
    end
    
    -- Draw each character that's within bounds
    for i, char_data in ipairs(marquee_data.individual_chars) do
        -- Check if character is visible within bounds
        if char_data.current_x + char_data.width >= marquee_data.bounds_left and 
           char_data.current_x <= marquee_data.bounds_right then
            
            local char_obj_id = marquee_id .. "_char_" .. i
            
            Net.player_draw_sprite(
                player_id,
                marquee_data.font,  -- Use font name as sprite ID
                {
                    id = char_obj_id,
                    x = char_data.current_x,
                    y = marquee_data.y,
                    z = marquee_data.z_order,
                    sx = marquee_data.scale,
                    sy = marquee_data.scale,
                    anim_state = char_data.anim_state  -- Use the pre-built animation state
                }
            )
            
            char_data.obj_id = char_obj_id
        elseif char_data.obj_id then
            -- Character is out of bounds, remove it
            Net.player_erase_sprite(player_id, char_data.obj_id)
            char_data.obj_id = nil
        end
    end
end

function TextDisplay:drawBackdrop(player_id, text_id, text_data, backdrop)
    local padding_x = backdrop.padding_x or 4
    local padding_y = backdrop.padding_y or 2
    
    -- Use exact backdrop dimensions provided
    local backdrop_width = backdrop.width
    local backdrop_height = backdrop.height
    local backdrop_x = backdrop.x
    local backdrop_y = backdrop.y
    
    local backdrop_id = text_id .. "_backdrop"
    
    Net.player_draw_sprite(
        player_id,
        self.backdrop_sprite.sprite_id,
        {
            id = backdrop_id,
            x = backdrop_x,
            y = backdrop_y,
            z = text_data.z_order - 1, -- Behind the text
            sx = backdrop_width,
            sy = backdrop_height
        }
    )
    
    text_data.backdrop_id = backdrop_id
    text_data.backdrop_width = backdrop_width
    text_data.backdrop_height = backdrop_height
    text_data.backdrop_padding_x = padding_x
    text_data.backdrop_padding_y = padding_y
end

function TextDisplay:updateMarquees(delta)
    for player_id, player_data in pairs(self.player_texts) do
        for text_id, text_data in pairs(player_data.active_texts) do
            if text_data.type == "marquee" then
                self:updateMarquee(player_id, text_id, text_data, delta)
            end
        end
    end
end

function TextDisplay:updateMarquee(player_id, text_id, text_data, delta)
    -- Update wrap cooldown
    text_data.last_wrap_time = text_data.last_wrap_time + delta
    
    -- Calculate movement for all characters
    local movement = text_data.speed * delta
    
    -- Track if entire text needs to wrap
    local needs_wrap = false
    local leftmost_char = nil
    
    -- Find the leftmost character to check if entire text has left the screen
    for _, char_data in ipairs(text_data.individual_chars) do
        if not leftmost_char or char_data.current_x < leftmost_char.current_x then
            leftmost_char = char_data
        end
    end
    
    -- Check if the entire text has moved past the left boundary
    if leftmost_char and leftmost_char.current_x + text_data.total_text_width < text_data.bounds_left then
        needs_wrap = true
    end
    
    -- Update each character's position
    for _, char_data in ipairs(text_data.individual_chars) do
        char_data.current_x = char_data.current_x - movement
    end
    
    -- Handle text wrapping if needed and cooldown has passed
    if needs_wrap and text_data.last_wrap_time >= text_data.wrap_cooldown then
        self:wrapMarqueeText(text_data)
        text_data.last_wrap_time = 0
    end
    
    -- Redraw characters at new positions
    self:drawMarqueeCharacters(player_id, text_id, text_data)
end

function TextDisplay:wrapMarqueeText(text_data)
    -- Find the rightmost character position
    local rightmost_x = -9999
    for _, char_data in ipairs(text_data.individual_chars) do
        if char_data.current_x > rightmost_x then
            rightmost_x = char_data.current_x
        end
    end
    
    -- Wrap the entire text as a unit to maintain monospacing
    local wrap_position = rightmost_x + text_data.wrap_gap
    
    -- Calculate the offset needed to move the entire text
    local leftmost_x = 9999
    for _, char_data in ipairs(text_data.individual_chars) do
        if char_data.current_x < leftmost_x then
            leftmost_x = char_data.current_x
        end
    end
    
    local offset = wrap_position - leftmost_x
    
    -- Move all characters by the same offset to maintain relative positions
    for _, char_data in ipairs(text_data.individual_chars) do
        char_data.current_x = char_data.current_x + offset
    end
end

function TextDisplay:removeText(player_id, text_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        local text_data = player_data.active_texts[text_id]
        if text_data then
            -- Remove text display
            if text_data.type == "marquee" then
                -- Remove individual characters
                for _, char_data in ipairs(text_data.individual_chars) do
                    if char_data.obj_id then
                        Net.player_erase_sprite(player_id, char_data.obj_id)
                    end
                end
            else
                if text_data.display_id then
                    self.font_system:eraseTextDisplay(player_id, text_data.display_id)
                end
            end
            
            -- Remove backdrop if it exists
            if text_data.backdrop_id then
                Net.player_erase_sprite(player_id, text_data.backdrop_id)
            end
            
            player_data.active_texts[text_id] = nil
        end
    end
end

function TextDisplay:updateText(player_id, text_id, new_text)
    local player_data = self.player_texts[player_id]
    if player_data then
        local text_data = player_data.active_texts[text_id]
        if text_data then
            -- Remove old display
            if text_data.type == "marquee" then
                -- Remove individual characters
                for _, char_data in ipairs(text_data.individual_chars) do
                    if char_data.obj_id then
                        Net.player_erase_sprite(player_id, char_data.obj_id)
                    end
                end
            else
                if text_data.display_id then
                    self.font_system:eraseTextDisplay(player_id, text_data.display_id)
                end
            end
            
            if text_data.backdrop_id then
                Net.player_erase_sprite(player_id, text_data.backdrop_id)
            end
            
            -- Update text
            text_data.text = new_text
            
            -- Recalculate for marquees
            if text_data.type == "marquee" then
                text_data.text_width = self.font_system:getTextWidth(new_text, text_data.font, text_data.scale)
                
                -- Recalculate bounds based on new text width
                if text_data.backdrop then
                    local padding_x = text_data.backdrop.padding_x or 4
                    text_data.bounds_left = text_data.backdrop.x + padding_x
                    text_data.bounds_right = text_data.backdrop.x + text_data.backdrop.width - padding_x
                    text_data.bounds_width = text_data.bounds_right - text_data.bounds_left
                end
                
                -- Reset character positions
                self:setupIndividualCharacters(text_data)
            end
            
            -- Redraw backdrop if it exists
            if text_data.backdrop then
                self:drawBackdrop(player_id, text_id, text_data, text_data.backdrop)
            end
            
            -- Redraw text
            if text_data.type == "marquee" then
                self:drawMarqueeCharacters(player_id, text_id, text_data)
            else
                text_data.display_id = self.font_system:drawText(
                    player_id,
                    new_text,
                    text_data.x,
                    text_data.y,
                    text_data.font,
                    text_data.scale,
                    text_data.z_order
                )
            end
        end
    end
end

function TextDisplay:setMarqueeSpeed(player_id, text_id, speed)
    local player_data = self.player_texts[player_id]
    if player_data then
        local text_data = player_data.active_texts[text_id]
        if text_data and text_data.type == "marquee" then
            text_data.speed = self.marquee_speeds[speed] or self.marquee_speeds.medium
        end
    end
end

function TextDisplay:setTextPosition(player_id, text_id, x, y)
    local player_data = self.player_texts[player_id]
    if player_data then
        local text_data = player_data.active_texts[text_id]
        if text_data and text_data.type == "static" then
            -- Remove old display
            if text_data.display_id then
                self.font_system:eraseTextDisplay(player_id, text_data.display_id)
            end
            
            if text_data.backdrop_id then
                Net.player_erase_sprite(player_id, text_data.backdrop_id)
            end
            
            -- Update position
            text_data.x = x
            text_data.y = y
            
            -- Redraw backdrop if it exists
            if text_data.backdrop then
                self:drawBackdrop(player_id, text_id, text_data, text_data.backdrop)
            end
            
            -- Redraw text
            text_data.display_id = self.font_system:drawText(
                player_id,
                text_data.text,
                x,
                y,
                text_data.font,
                text_data.scale,
                text_data.z_order
            )
        end
    end
end

function TextDisplay:addBackdrop(player_id, text_id, backdrop_config)
    local player_data = self.player_texts[player_id]
    if player_data then
        local text_data = player_data.active_texts[text_id]
        if text_data then
            text_data.backdrop = backdrop_config
            
            -- Remove old backdrop if it exists
            if text_data.backdrop_id then
                Net.player_erase_sprite(player_id, text_data.backdrop_id)
            end
            
            -- Draw new backdrop
            self:drawBackdrop(player_id, text_id, text_data, backdrop_config)
            
            -- For marquees, update bounds
            if text_data.type == "marquee" then
                local padding_x = backdrop_config.padding_x or 4
                text_data.bounds_left = backdrop_config.x + padding_x
                text_data.bounds_right = backdrop_config.x + backdrop_config.width - padding_x
                text_data.bounds_width = text_data.bounds_right - text_data.bounds_left
                
                -- Reset character positions
                self:setupIndividualCharacters(text_data)
            end
        end
    end
end

function TextDisplay:removeBackdrop(player_id, text_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        local text_data = player_data.active_texts[text_id]
        if text_data and text_data.backdrop_id then
            Net.player_erase_sprite(player_id, text_data.backdrop_id)
            text_data.backdrop = nil
            text_data.backdrop_id = nil
            
            -- For marquees, reset to full screen bounds
            if text_data.type == "marquee" then
                text_data.bounds_left = 0
                text_data.bounds_right = self.screen_width
                text_data.bounds_width = self.screen_width
                
                -- Reset character positions
                self:setupIndividualCharacters(text_data)
            end
        end
    end
end

-- Set marquee wrap gap (can be called to adjust the gap for specific marquees)
function TextDisplay:setMarqueeWrapGap(player_id, text_id, gap_pixels)
    local player_data = self.player_texts[player_id]
    if player_data then
        local text_data = player_data.active_texts[text_id]
        if text_data and text_data.type == "marquee" then
            text_data.wrap_gap = gap_pixels or self.marquee_wrap_gap
        end
    end
end

-- Utility functions
function TextDisplay:getTextWidth(text, font_name, scale)
    return self.font_system:getTextWidth(text, font_name, scale)
end

function TextDisplay:getScreenDimensions()
    return self.screen_width, self.screen_height
end

-- Initialize the text display system
local textDisplaySystem = setmetatable({}, TextDisplay)
textDisplaySystem:init()

return textDisplaySystem