-- text-layout.lua
-- Unified text layout engine
TextLayout = {}
TextLayout.__index = TextLayout

function TextLayout:init(character_renderer)
    self.character_renderer = character_renderer
    return self
end

-- Parse markup into operations
function TextLayout:parseMarkup(text)
    local ops = {}
    text = tostring(text or "")
    
    local i = 1
    while i <= #text do
        local ch = text:sub(i, i)
        
        if ch == "{" then
            local close = text:find("}", i + 1, true)
            if close then
                local tag = text:sub(i + 1, close - 1)
                
                -- {p_0.2} pauses
                local p = tag:match("^p_(%d+%.?%d*)$")
                if p then
                    table.insert(ops, { type = "pause", seconds = tonumber(p) or 0 })
                    i = close + 1
                elseif tag == "end_line" then
                    table.insert(ops, { type = "newline" })
                    i = close + 1
                elseif tag == "end_page" then
                    table.insert(ops, { type = "newpage" })
                    i = close + 1
                else
                    -- Unknown tag => treat literally "{...}"
                    for j = i, close do
                        table.insert(ops, { type = "char", ch = text:sub(j, j) })
                    end
                    i = close + 1
                end
            else
                -- No closing brace; treat as literal
                table.insert(ops, { type = "char", ch = ch })
                i = i + 1
            end
        else
            table.insert(ops, { type = "char", ch = ch })
            i = i + 1
        end
    end
    
    return ops
end

-- Normalize text (same as FontSystem)
local function normalize_text(text)
    if not text or text == "" then return text end

    text = text:gsub("\r", "")
    text = text:gsub("\239\187\191", "") -- UTF-8 BOM
    text = text:gsub("\194\160", " ")    -- NBSP

    -- UTF-8 smart punctuation
    text = text:gsub("’", "'"):gsub("‘", "'")
    text = text:gsub("“", '"'):gsub("”", '"')
    text = text:gsub("–", "-"):gsub("—", "-")
    text = text:gsub("…", "...")

    -- CP1252 smart punctuation bytes (Windows-1252)
    local b = string.char
    text = text:gsub(b(0x91), "'"):gsub(b(0x92), "'")
    text = text:gsub(b(0x93), '"'):gsub(b(0x94), '"')
    text = text:gsub(b(0x96), "-"):gsub(b(0x97), "-")
    text = text:gsub(b(0x85), "...")

    return text
end

-- Layout text with basic options
function TextLayout:layoutText(player_id, text, options)
    -- options: { x, y, font, scale, z, spacing, max_width, max_height, alignment, wrap }
    options = options or {}
    local font = options.font or "THICK"
    local scale = options.scale or 2.0
    local spacing = (options.spacing or 1) * scale
    local max_width = options.max_width
    local max_height = options.max_height
    local wrap = options.wrap ~= false  -- Default to true
    
    -- Normalize text
    text = normalize_text(text)
    
    -- Parse markup if needed
    local ops = options.parse_markup and self:parseMarkup(text) or nil
    
    local layout = {
        player_id = player_id,
        text = text,
        ops = ops,
        options = options,
        characters = {},  -- List of character IDs
        lines = {},       -- Line information for wrapped text
        width = 0,
        height = 0,
        char_positions = {}  -- Map char_id to position info
    }
    
    if wrap and (max_width or max_height) then
        return self:layoutWrappedText(layout)
    else
        return self:layoutSingleLine(layout)
    end
end

-- Layout single line of text (no wrapping)
function TextLayout:layoutSingleLine(layout)
    local options = layout.options
    local font = options.font or "THICK"
    local scale = options.scale or 2.0
    local spacing = (options.spacing or 1) * scale
    local current_x = options.x or 0
    local current_y = options.y or 0
    
    local char_ids = {}
    local max_x = current_x
    
    -- Process operations or raw text
    local text_to_process = layout.ops or {{type = "raw", text = layout.text}}
    
    for _, item in ipairs(text_to_process) do
        if item.type == "char" then
            local char = item.ch
            if char == " " then
                -- Advance for spaces
                local space_width = self.character_renderer.font_system:getCharacterWidth(font, " ", scale)
                current_x = current_x + space_width + spacing
            else
                -- Create character sprite
                local anim_state = self.character_renderer.font_system:getCharacterState(font, char)
                if anim_state then
                    local char_id = self.character_renderer:generateCharId("char")
                    
                    self.character_renderer:createCharacter(layout.player_id, {
                        id = char_id,
                        x = current_x,
                        y = current_y,
                        z = options.z or 100,
                        font = font,
                        scale = scale,
                        anim_state = anim_state,
                        tint = options.tint,
                        opacity = options.opacity
                    })
                    
                    table.insert(char_ids, char_id)
                    
                    -- Store position info
                    layout.char_positions[char_id] = {
                        line = 1,
                        position = #char_ids,
                        x = current_x,
                        y = current_y
                    }
                    
                    -- Advance position
                    local char_width = self.character_renderer.font_system:getCharacterWidth(font, char, scale)
                    current_x = current_x + char_width + spacing
                    max_x = math.max(max_x, current_x - spacing)
                end
            end
        elseif item.type == "pause" then
            -- Store pause marker
            table.insert(char_ids, { type = "pause", seconds = item.seconds })
        end
    end
    
    layout.characters = char_ids
    layout.width = max_x - (options.x or 0)
    layout.height = self.character_renderer.font_system:getLineHeight(font, scale)
    
    -- Add line info
    layout.lines[1] = {
        start_char = 1,
        end_char = #char_ids,
        y = current_y,
        height = layout.height
    }
    
    return layout
end

-- Layout text with word wrapping
function TextLayout:layoutWrappedText(layout)
    local options = layout.options
    local font = options.font or "THICK"
    local scale = options.scale or 2.0
    local spacing = (options.spacing or 1) * scale
    local max_width = options.max_width or 240
    local max_height = options.max_height or 160
    local line_height = self.character_renderer.font_system:getLineHeight(font, scale)
    
    local start_x = options.x or 0
    local start_y = options.y or 0
    
    -- Tokenize text into words
    local words = {}
    local word = ""
    
    for i = 1, #layout.text do
        local ch = layout.text:sub(i, i)
        if ch == " " or ch == "\n" then
            if #word > 0 then
                table.insert(words, { type = "word", text = word })
                word = ""
            end
            if ch == "\n" then
                table.insert(words, { type = "newline" })
            else
                table.insert(words, { type = "space" })
            end
        else
            word = word .. ch
        end
    end
    
    if #word > 0 then
        table.insert(words, { type = "word", text = word })
    end
    
    -- Wrap text
    local lines = {}
    local current_line = { words = {}, width = 0 }
    local current_y = start_y
    local char_ids = {}
    local char_index = 1
    
    for _, word_item in ipairs(words) do
        if word_item.type == "newline" then
            -- Force new line
            if #current_line.words > 0 then
                table.insert(lines, current_line)
                current_line = { words = {}, width = 0 }
                current_y = current_y + line_height
            end
        else
            local word_width = 0
            local word_chars = {}
            
            if word_item.type == "word" then
                -- Calculate word width
                for i = 1, #word_item.text do
                    local ch = word_item.text:sub(i, i)
                    word_width = word_width + self.character_renderer.font_system:getCharacterWidth(font, ch, scale)
                    if i < #word_item.text then
                        word_width = word_width + spacing
                    end
                    table.insert(word_chars, ch)
                end
            elseif word_item.type == "space" then
                word_width = self.character_renderer.font_system:getCharacterWidth(font, " ", scale)
                table.insert(word_chars, " ")
            end
            
            -- Check if word fits on current line
            if current_line.width + (current_line.width > 0 and spacing or 0) + word_width <= max_width then
                -- Add word to current line
                table.insert(current_line.words, {
                    type = word_item.type,
                    text = word_item.text,
                    chars = word_chars,
                    width = word_width
                })
                current_line.width = current_line.width + (current_line.width > 0 and spacing or 0) + word_width
            else
                -- Start new line
                if #current_line.words > 0 then
                    table.insert(lines, current_line)
                    current_line = { words = {}, width = 0 }
                    current_y = current_y + line_height
                end
                
                -- Handle word that's too long for a single line
                if word_width > max_width then
                    -- Split long word
                    local remaining_chars = word_chars
                    while #remaining_chars > 0 do
                        local line_chars = {}
                        local line_width = 0
                        
                        for i = 1, #remaining_chars do
                            local ch = remaining_chars[i]
                            local char_width = self.character_renderer.font_system:getCharacterWidth(font, ch, scale)
                            if line_width + (line_width > 0 and spacing or 0) + char_width <= max_width then
                                table.insert(line_chars, ch)
                                line_width = line_width + (line_width > 0 and spacing or 0) + char_width
                            else
                                break
                            end
                        end
                        
                        -- Add partial word as a line
                        table.insert(lines, {
                            words = {{
                                type = "word",
                                text = table.concat(line_chars),
                                chars = line_chars,
                                width = line_width
                            }},
                            width = line_width
                        })
                        
                        -- Remove processed characters
                        for i = 1, #line_chars do
                            table.remove(remaining_chars, 1)
                        end
                        
                        if #remaining_chars > 0 then
                            current_y = current_y + line_height
                        end
                    end
                    
                    current_line = { words = {}, width = 0 }
                else
                    -- Word fits on new line
                    table.insert(current_line.words, {
                        type = word_item.type,
                        text = word_item.text,
                        chars = word_chars,
                        width = word_width
                    })
                    current_line.width = word_width
                end
            end
        end
    end
    
    -- Add last line if it has content
    if #current_line.words > 0 then
        table.insert(lines, current_line)
    end
    
    -- Create character sprites for each line
    current_y = start_y
    local max_line_width = 0
    
    for line_index, line in ipairs(lines) do
        local current_x = start_x
        
        -- Apply alignment
        if options.alignment == "center" then
            current_x = start_x + (max_width - line.width) / 2
        elseif options.alignment == "right" then
            current_x = start_x + max_width - line.width
        end
        
        for _, word_item in ipairs(line.words) do
            for char_index_in_word, char in ipairs(word_item.chars) do
                if char == " " then
                    -- Advance for spaces
                    local space_width = self.character_renderer.font_system:getCharacterWidth(font, " ", scale)
                    current_x = current_x + space_width + spacing
                else
                    -- Create character sprite
                    local anim_state = self.character_renderer.font_system:getCharacterState(font, char)
                    if anim_state then
                        local char_id = self.character_renderer:generateCharId("char")
                        
                        self.character_renderer:createCharacter(layout.player_id, {
                            id = char_id,
                            x = current_x,
                            y = current_y,
                            z = options.z or 100,
                            font = font,
                            scale = scale,
                            anim_state = anim_state,
                            tint = options.tint,
                            opacity = options.opacity,
                            visible = options.visible ~= false
                        })
                        
                        table.insert(char_ids, char_id)
                        
                        -- Store position info
                        layout.char_positions[char_id] = {
                            line = line_index,
                            position = #char_ids,
                            x = current_x,
                            y = current_y
                        }
                        
                        -- Advance position
                        local char_width = self.character_renderer.font_system:getCharacterWidth(font, char, scale)
                        current_x = current_x + char_width + spacing
                    end
                end
            end
        end
        
        max_line_width = math.max(max_line_width, line.width)
        current_y = current_y + line_height
        
        -- Store line info
        layout.lines[line_index] = {
            start_char = (#char_ids - #line.words * 10) + 1,  -- Approximate
            end_char = #char_ids,
            y = current_y - line_height,
            height = line_height,
            width = line.width
        }
        
        -- Check height limit
        if max_height and (current_y - start_y) > max_height then
            break
        end
    end
    
    layout.characters = char_ids
    layout.width = max_line_width
    layout.height = current_y - start_y
    
    return layout
end

-- Calculate text dimensions without creating sprites
function TextLayout:calculateDimensions(text, options)
    local temp_layout = {
        text = text,
        options = options or {}
    }
    
    local wrapped_layout = self:layoutWrappedText(temp_layout)
    
    return {
        width = wrapped_layout.width,
        height = wrapped_layout.height,
        line_count = #wrapped_layout.lines
    }
end

-- Initialize singleton
local textLayout = setmetatable({}, TextLayout)
return textLayout