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
    
    -- Text box settings
    self.text_box_settings = {
        default_speed = 30, -- Characters per second
        line_height = 12,   -- Increased from 10 to 12 for better spacing
        char_spacing = 1,   -- Consistent with font system
    }
    
    Net:on("player_join", function(event)
        self:setupPlayerTextDisplays(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerTextDisplays(event.player_id)
    end)
    
    -- Update marquees and text boxes every tick
    Net:on("tick", function(event)
        self:updateMarquees(event.delta_time)
        self:updateTextBoxes(event.delta_time)
    end)
    
    return self
end

function TextDisplay:setupPlayerTextDisplays(player_id)
    self.player_texts[player_id] = {
        active_texts = {},
        next_obj_id = 1,
        allocated_backdrop = false,
        active_text_boxes = {}
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
        
        -- Remove all active text boxes
        for box_id, box_data in pairs(player_data.active_text_boxes) do
            self:removeTextBox(player_id, box_id)
        end
        
        -- Deallocate backdrop sprite
        if player_data.allocated_backdrop then
            Net.player_dealloc_sprite(player_id, self.backdrop_sprite.sprite_id)
        end
        
        self.player_texts[player_id] = nil
    end
end

-- MegaMan Battle Network Style Text Box System
function TextDisplay:createTextBox(player_id, box_id, text, x, y, width, height, font_name, scale, z_order, backdrop_config, speed)
    font_name = font_name or "THICK"
    scale = scale or 1.0
    z_order = z_order or 100
    speed = speed or self.text_box_settings.default_speed
    
    local player_data = self.player_texts[player_id]
    if not player_data then return nil end
    
    -- Use backdrop config if provided, otherwise create default
    local actual_backdrop_config = backdrop_config or {
        x = x, y = y, width = width, height = height,
        padding_x = 8, padding_y = 6
    }
    
    -- Calculate text bounds within the box - ALWAYS use the backdrop config for positioning
    local padding_x = actual_backdrop_config.padding_x or 8
    local padding_y = actual_backdrop_config.padding_y or 6
    local inner_x = actual_backdrop_config.x + padding_x
    local inner_y = actual_backdrop_config.y + padding_y
    local inner_width = actual_backdrop_config.width - (padding_x * 2)
    local inner_height = actual_backdrop_config.height - (padding_y * 2)
    
    -- Process text into pages with word wrapping
    local pages = self:wrapTextToPages(text, font_name, scale, inner_width, inner_height)
    
    -- Calculate character delay based on speed (characters per second)
    local char_delay = 1.0 / speed
    
    local text_box_data = {
        type = "text_box",
        box_id = box_id,
        x = actual_backdrop_config.x, -- Use backdrop x as reference
        y = actual_backdrop_config.y, -- Use backdrop y as reference
        width = actual_backdrop_config.width,
        height = actual_backdrop_config.height,
        inner_x = inner_x,
        inner_y = inner_y,
        inner_width = inner_width,
        inner_height = inner_height,
        font = font_name,
        scale = scale,
        z_order = z_order,
        speed = speed,
        char_delay = char_delay,
        pages = pages,
        current_page = 1,
        current_line = 1,
        current_char = 0,
        timer = 0,
        display_lines = {},
        backdrop = actual_backdrop_config, -- Store the actual backdrop config
        backdrop_id = nil,
        state = "printing", -- printing, waiting, completed
        wait_timer = 0,
        padding_x = padding_x,
        padding_y = padding_y
    }
    
    -- Draw backdrop
    self:drawTextBoxBackdrop(player_id, box_id, text_box_data)
    
    player_data.active_text_boxes[box_id] = text_box_data
    return box_id
end

-- Separate backdrop drawing function for text boxes to maintain consistency
function TextDisplay:drawTextBoxBackdrop(player_id, box_id, box_data)
    -- Remove old backdrop if it exists
    if box_data.backdrop_id then
        Net.player_erase_sprite(player_id, box_data.backdrop_id)
    end
    
    local backdrop_id = box_id .. "_backdrop"
    
    Net.player_draw_sprite(
        player_id,
        self.backdrop_sprite.sprite_id,
        {
            id = backdrop_id,
            x = box_data.x, -- Use box_data.x (which is backdrop x)
            y = box_data.y, -- Use box_data.y (which is backdrop y)
            z = box_data.z_order - 1, -- Behind the text
            sx = box_data.width,
            sy = box_data.height
        }
    )
    
    box_data.backdrop_id = backdrop_id
    box_data.backdrop_width = box_data.width
    box_data.backdrop_height = box_data.height
end
-- In the wrapTextToPages function, update the character spacing calculation:
function TextDisplay:wrapTextToPages(text, font_name, scale, max_width, max_height)
    local char_widths = self.font_system.char_widths[font_name] or self.font_system.char_widths.THICK
    -- FIXED: Use a default character for width calculation
    local default_char_width = char_widths["A"] or char_widths["0"] or 6
    local char_width = default_char_width * scale
    
    -- FIXED: Scale the character spacing properly
    local base_spacing = self.text_box_settings.char_spacing or 1
    local scaled_spacing = base_spacing * scale
    
    local line_height = self.text_box_settings.line_height * scale
    
    -- Calculate maximum characters per line and lines per page
    local chars_per_pixel = (char_width + scaled_spacing)
    local max_chars_per_line = math.floor(max_width / chars_per_pixel)
    local max_lines_per_page = math.floor(max_height / line_height)
    
    local pages = {}
    local current_page = {}
    local current_line = ""
    local current_line_chars = 0
    
    -- Split text into words
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end
    
    -- Add spaces between words (we'll handle them manually)
    local word_index = 1
    while word_index <= #words do
        local word = words[word_index]
        local word_length = #word
        
        -- Check if word fits on current line (with space if not first word)
        local space_needed = (current_line_chars > 0) and 1 or 0
        local total_chars = current_line_chars + space_needed + word_length
        
        if total_chars <= max_chars_per_line then
            -- Word fits, add it to current line
            if current_line_chars > 0 then
                current_line = current_line .. " " .. word
                current_line_chars = current_line_chars + 1 + word_length
            else
                current_line = word
                current_line_chars = word_length
            end
            word_index = word_index + 1
        else
            -- Word doesn't fit
            if current_line_chars > 0 then
                -- Start new line with current word
                table.insert(current_page, current_line)
                if #current_page >= max_lines_per_page then
                    table.insert(pages, current_page)
                    current_page = {}
                end
                current_line = ""
                current_line_chars = 0
            else
                -- Word is too long for a single line, break it
                local chars_to_take = max_chars_per_line
                local part = word:sub(1, chars_to_take)
                table.insert(current_page, part)
                if #current_page >= max_lines_per_page then
                    table.insert(pages, current_page)
                    current_page = {}
                end
                
                -- Update word with remaining characters
                words[word_index] = word:sub(chars_to_take + 1)
                if #words[word_index] == 0 then
                    word_index = word_index + 1
                end
                current_line = ""
                current_line_chars = 0
            end
        end
    end
    
    -- Add the last line if it exists
    if current_line_chars > 0 then
        table.insert(current_page, current_line)
    end
    
    -- Add the last page if it exists
    if #current_page > 0 then
        table.insert(pages, current_page)
    end
    
    return pages
end

function TextDisplay:updateTextBoxes(delta)
    for player_id, player_data in pairs(self.player_texts) do
        for box_id, box_data in pairs(player_data.active_text_boxes) do
            if box_data.state == "printing" then
                self:updateTextBoxPrinting(player_id, box_id, box_data, delta)
            elseif box_data.state == "waiting" then
                self:updateTextBoxWaiting(player_id, box_id, box_data, delta)
            end
        end
    end
end

function TextDisplay:updateTextBoxPrinting(player_id, box_id, box_data, delta)
    box_data.timer = box_data.timer + delta
    
    local current_page = box_data.pages[box_data.current_page]
    if not current_page then
        box_data.state = "completed"
        return
    end
    
    local current_line_text = current_page[box_data.current_line]
    if not current_line_text then
        -- Move to next page or complete
        box_data.current_page = box_data.current_page + 1
        if box_data.current_page > #box_data.pages then
            box_data.state = "completed"
        else
            box_data.current_line = 1
            box_data.current_char = 0
            self:clearTextBoxDisplay(player_id, box_id, box_data)
        end
        return
    end
    
    local chars_to_add = math.floor(box_data.timer / box_data.char_delay)
    if chars_to_add > 0 then
        box_data.timer = box_data.timer - (chars_to_add * box_data.char_delay)
        
        for i = 1, chars_to_add do
            box_data.current_char = box_data.current_char + 1
            
            if box_data.current_char > #current_line_text then
                -- Move to next line
                box_data.current_line = box_data.current_line + 1
                box_data.current_char = 0
                
                -- Check if we've exceeded the current page
                if box_data.current_line > #current_page then
                    box_data.state = "waiting"
                    box_data.wait_timer = 0
                    break
                end
            else
                -- Add the next character
                self:drawTextBoxCharacter(player_id, box_id, box_data)
            end
        end
    end
end

function TextDisplay:updateTextBoxWaiting(player_id, box_id, box_data, delta)
    box_data.wait_timer = box_data.wait_timer + delta
    
    -- Wait for 2 seconds before advancing to next page
    if box_data.wait_timer >= 2.0 then
        box_data.current_page = box_data.current_page + 1
        if box_data.current_page > #box_data.pages then
            box_data.state = "completed"
        else
            box_data.current_line = 1
            box_data.current_char = 0
            box_data.state = "printing"
            self:clearTextBoxDisplay(player_id, box_id, box_data)
        end
    end
end

function TextDisplay:drawTextBoxCharacter(player_id, box_id, box_data)
    local current_page = box_data.pages[box_data.current_page]
    local current_line_text = current_page[box_data.current_line]
    local char = current_line_text:sub(box_data.current_char, box_data.current_char)
    
    -- Calculate position for this character - ALWAYS use the inner coordinates from box_data
    local line_y = box_data.inner_y + ((box_data.current_line - 1) * self.text_box_settings.line_height * box_data.scale)
    
    -- Calculate character widths with proper scaling
    local char_widths = self.font_system.char_widths[box_data.font] or self.font_system.char_widths.THICK
    local default_char_width = char_widths["A"] or char_widths["0"] or 6
    local char_width = default_char_width * box_data.scale
    
    -- FIXED: Scale the character spacing properly
    local base_spacing = self.text_box_settings.char_spacing or 1
    local scaled_spacing = base_spacing * box_data.scale
    
    -- Calculate X position based on character index with consistent scaled spacing
    local current_x = box_data.inner_x + (box_data.current_char - 1) * (char_width + scaled_spacing)
    
    local char_obj_id = box_id .. "_line_" .. box_data.current_line .. "_char_" .. box_data.current_char
    
    Net.player_draw_sprite(
        player_id,
        box_data.font,
        {
            id = char_obj_id,
            x = current_x,
            y = line_y,
            z = box_data.z_order,
            sx = box_data.scale,
            sy = box_data.scale,
            anim_state = box_data.font .. "_" .. char
        }
    )
    
    -- Store reference to this character object
    if not box_data.display_lines[box_data.current_line] then
        box_data.display_lines[box_data.current_line] = {}
    end
    box_data.display_lines[box_data.current_line][box_data.current_char] = char_obj_id
end

function TextDisplay:clearTextBoxDisplay(player_id, box_id, box_data)
    -- Remove all character objects
    for line_num, line_chars in pairs(box_data.display_lines) do
        for char_num, obj_id in pairs(line_chars) do
            Net.player_erase_sprite(player_id, obj_id)
        end
    end
    box_data.display_lines = {}
end

function TextDisplay:removeTextBox(player_id, box_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        local box_data = player_data.active_text_boxes[box_id]
        if box_data then
            -- Remove backdrop
            if box_data.backdrop_id then
                Net.player_erase_sprite(player_id, box_data.backdrop_id)
            end
            
            -- Remove all character objects
            self:clearTextBoxDisplay(player_id, box_id, box_data)
            
            player_data.active_text_boxes[box_id] = nil
        end
    end
end

function TextDisplay:advanceTextBox(player_id, box_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        local box_data = player_data.active_text_boxes[box_id]
        if box_data then
            if box_data.state == "waiting" then
                -- Immediately advance to next page
                box_data.current_page = box_data.current_page + 1
                if box_data.current_page > #box_data.pages then
                    box_data.state = "completed"
                else
                    box_data.current_line = 1
                    box_data.current_char = 0
                    box_data.state = "printing"
                    self:clearTextBoxDisplay(player_id, box_id, box_data)
                end
            elseif box_data.state == "printing" then
                -- Instantly complete current page
                local current_page = box_data.pages[box_data.current_page]
                if current_page then
                    -- Draw all remaining characters in current page instantly
                    for line = box_data.current_line, #current_page do
                        local line_text = current_page[line]
                        local start_char = (line == box_data.current_line) and box_data.current_char + 1 or 1
                        
                        for char_pos = start_char, #line_text do
                            box_data.current_line = line
                            box_data.current_char = char_pos
                            self:drawTextBoxCharacter(player_id, box_id, box_data)
                        end
                    end
                    
                    box_data.state = "waiting"
                    box_data.wait_timer = 0
                end
            end
        end
    end
end

-- NEW FUNCTION: Set text box position (moves both backdrop and text together)
function TextDisplay:setTextBoxPosition(player_id, box_id, x, y)
    local player_data = self.player_texts[player_id]
    if player_data then
        local box_data = player_data.active_text_boxes[box_id]
        if box_data then
            -- Update the main position
            box_data.x = x
            box_data.y = y
            
            -- Update backdrop config position
            if box_data.backdrop then
                box_data.backdrop.x = x
                box_data.backdrop.y = y
            end
            
            -- Recalculate inner coordinates based on new position
            box_data.inner_x = x + box_data.padding_x
            box_data.inner_y = y + box_data.padding_y
            
            -- Redraw backdrop at new position
            self:drawTextBoxBackdrop(player_id, box_id, box_data)
            
            -- Clear and redraw all text at new positions
            self:clearTextBoxDisplay(player_id, box_id, box_data)
            
            -- Redraw all characters that should be visible
            if box_data.state == "printing" or box_data.state == "waiting" then
                local current_page = box_data.pages[box_data.current_page]
                if current_page then
                    for line = 1, box_data.current_line do
                        local line_text = current_page[line]
                        if line_text then
                            local max_char = (line == box_data.current_line) and box_data.current_char or #line_text
                            for char_pos = 1, max_char do
                                -- Temporarily set current line/char for drawing
                                local temp_line = box_data.current_line
                                local temp_char = box_data.current_char
                                box_data.current_line = line
                                box_data.current_char = char_pos
                                self:drawTextBoxCharacter(player_id, box_id, box_data)
                                box_data.current_line = temp_line
                                box_data.current_char = temp_char
                            end
                        end
                    end
                end
            end
        end
    end
end

function TextDisplay:isTextBoxCompleted(player_id, box_id)
    local player_data = self.player_texts[player_id]
    if player_data then
        local box_data = player_data.active_text_boxes[box_id]
        return box_data and box_data.state == "completed"
    end
    return true
end

-- [Rest of the existing functions for marquee and static text remain unchanged]
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
        individual_chars = {} -- Store individual character data for wrapping
    }
    
    -- Pre-calculate character positions for proper marquee behavior
    self:setupMarqueeCharacters(marquee_data)
    
    -- Draw backdrop if specified
    if backdrop then
        self:drawBackdrop(player_id, marquee_id, marquee_data, backdrop)
    end
    
    -- Draw initial marquee text
    self:drawMarqueeCharacters(player_id, marquee_id, marquee_data)
    
    player_data.active_texts[marquee_id] = marquee_data
    return marquee_id
end
function TextDisplay:setupMarqueeCharacters(marquee_data)
    local font_name = marquee_data.font
    local char_widths = self.font_system.char_widths[font_name] or self.font_system.char_widths.THICK
    local default_char_width = char_widths["A"] or char_widths["0"] or 6
    local scale = marquee_data.scale
    
    -- FIXED: Scale spacing properly
    local base_spacing = 1
    local scaled_spacing = base_spacing * scale
    local advance = (default_char_width + scaled_spacing) * scale

    marquee_data.individual_chars = {}

    -- Total text width calculation with proper scaling
    local n = #marquee_data.text
    marquee_data.total_text_width = (n * default_char_width * scale) + (math.max(0, n - 1) * scaled_spacing)

    -- Setup individual character data with relative positions
    local relative_x = 0
    for i = 1, n do
        local char = marquee_data.text:sub(i, i)
        local char_width = default_char_width * scale
        
        table.insert(marquee_data.individual_chars, {
            char = char,
            width = char_width,
            relative_x = relative_x,
            obj_id = nil,
            anim_state = font_name .. "_" .. char
        })
        
        relative_x = relative_x + char_width + scaled_spacing
    end
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
        -- Calculate absolute position
        local char_x = marquee_data.current_x + char_data.relative_x
        
        -- Check if character is visible within bounds
        if char_x + char_data.width >= marquee_data.bounds_left and 
           char_x <= marquee_data.bounds_right then
            
            local char_obj_id = marquee_id .. "_char_" .. i
            
            Net.player_draw_sprite(
                player_id,
                marquee_data.font,  -- Use font name as sprite ID
                {
                    id = char_obj_id,
                    x = char_x,
                    y = marquee_data.y,
                    z = marquee_data.z_order,
                    sx = marquee_data.scale,
                    sy = marquee_data.scale,
                    anim_state = char_data.anim_state
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
    -- Calculate movement for the entire text
    local movement = text_data.speed * delta
    
    -- Update the text position
    text_data.current_x = text_data.current_x - movement
    
    -- Check if the entire text has moved completely out of bounds
    if text_data.current_x + text_data.total_text_width < text_data.bounds_left then
        -- Reset to start at the right side again
        text_data.current_x = text_data.bounds_right
    end
    
    -- Redraw characters at new positions
    self:drawMarqueeCharacters(player_id, text_id, text_data)
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
                self:setupMarqueeCharacters(text_data)
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
                self:setupMarqueeCharacters(text_data)
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
                self:setupMarqueeCharacters(text_data)
            end
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