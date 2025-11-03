-- Font System for Timer Display (Following example_sprites pattern)
FontSystem = {}
FontSystem.__index = FontSystem

function FontSystem:init()
    self.font_sprites = {
        THICK = {
            texture_path = "/server/assets/net-games/fonts_compressed.png",
            anim_path = "/server/assets/net-games/fonts_compressed.animation",
            anim_state = "THICK_0" -- Default state
        },
        GRADIENT = {
            texture_path = "/server/assets/net-games/fonts_compressed.png", 
            anim_path = "/server/assets/net-games/fonts_compressed.animation",
            anim_state = "GRADIENT_0"
        },
        BATTLE = {
            texture_path = "/server/assets/net-games/fonts_compressed.png",
            anim_path = "/server/assets/net-games/fonts_compressed.animation", 
            anim_state = "BATTLE_0"
        }
    }
    
    -- Character width data for consistent spacing - FIXED: Now includes all common characters
    self.char_widths = {
        THICK = {
            ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6, ["4"] = 6, ["5"] = 6,
            ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6, [":"] = 6, ["."] = 6,
            ["-"] = 6, [" "] = 6, ["A"] = 6, ["B"] = 6, ["C"] = 6, ["D"] = 6,
            ["E"] = 6, ["F"] = 6, ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6,
            ["K"] = 6, ["L"] = 6, ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6,
            ["Q"] = 6, ["R"] = 6, ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6,
            ["W"] = 6, ["X"] = 6, ["Y"] = 6, ["Z"] = 6, ["a"] = 6, ["b"] = 6,
            ["c"] = 6, ["d"] = 6, ["e"] = 6, ["f"] = 6, ["g"] = 6, ["h"] = 6,
            ["i"] = 6, ["j"] = 6, ["k"] = 6, ["l"] = 6, ["m"] = 6, ["n"] = 6,
            ["o"] = 6, ["p"] = 6, ["q"] = 6, ["r"] = 6, ["s"] = 6, ["t"] = 6,
            ["u"] = 6, ["v"] = 6, ["w"] = 6, ["x"] = 6, ["y"] = 6, ["z"] = 6,
            ["!"] = 6, ["@"] = 6, ["#"] = 6, ["$"] = 6, ["%"] = 6, ["^"] = 6,
            ["&"] = 6, ["*"] = 6, ["("] = 6, [")"] = 6, ["_"] = 6, ["+"] = 6,
            ["="] = 6, ["["] = 6, ["]"] = 6, ["{"] = 6, ["}"] = 6, ["|"] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, [","] = 6, ["?"] = 6
        },
        GRADIENT = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [":"] = 7, [" "] = 7,
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, ["a"] = 7, ["b"] = 7, ["c"] = 7, ["d"] = 7,
            ["e"] = 7, ["f"] = 7, ["g"] = 7, ["h"] = 7, ["i"] = 7, ["j"] = 7,
            ["k"] = 7, ["l"] = 7, ["m"] = 7, ["n"] = 7, ["o"] = 7, ["p"] = 7,
            ["q"] = 7, ["r"] = 7, ["s"] = 7, ["t"] = 7, ["u"] = 7, ["v"] = 7,
            ["w"] = 7, ["x"] = 7, ["y"] = 7, ["z"] = 7, ["!"] = 7, ["@"] = 7,
            ["#"] = 7, ["$"] = 7, ["%"] = 7, ["^"] = 7, ["&"] = 7, ["*"] = 7,
            ["("] = 7, [")"] = 7, ["_"] = 7, ["+"] = 7, ["="] = 7, ["["] = 7,
            ["]"] = 7, ["{"] = 7, ["}"] = 7, ["|"] = 7, ["\\"] = 7, ["/"] = 7,
            ["<"] = 7, [">"] = 7, [","] = 7, ["?"] = 7
        },
        BATTLE = {
            ["0"] = 8, ["1"] = 8, ["2"] = 8, ["3"] = 8, ["4"] = 8, ["5"] = 8,
            ["6"] = 8, ["7"] = 8, ["8"] = 8, ["9"] = 8, [":"] = 8, [" "] = 8,
            ["A"] = 8, ["B"] = 8, ["C"] = 8, ["D"] = 8, ["E"] = 8, ["F"] = 8,
            ["G"] = 8, ["H"] = 8, ["I"] = 8, ["J"] = 8, ["K"] = 8, ["L"] = 8,
            ["M"] = 8, ["N"] = 8, ["O"] = 8, ["P"] = 8, ["Q"] = 8, ["R"] = 8,
            ["S"] = 8, ["T"] = 8, ["U"] = 8, ["V"] = 8, ["W"] = 8, ["X"] = 8,
            ["Y"] = 8, ["Z"] = 8, ["a"] = 8, ["b"] = 8, ["c"] = 8, ["d"] = 8,
            ["e"] = 8, ["f"] = 8, ["g"] = 8, ["h"] = 8, ["i"] = 8, ["j"] = 8,
            ["k"] = 8, ["l"] = 8, ["m"] = 8, ["n"] = 8, ["o"] = 8, ["p"] = 8,
            ["q"] = 8, ["r"] = 8, ["s"] = 8, ["t"] = 8, ["u"] = 8, ["v"] = 8,
            ["w"] = 8, ["x"] = 8, ["y"] = 8, ["z"] = 8, ["!"] = 8, ["@"] = 8,
            ["#"] = 8, ["$"] = 8, ["%"] = 8, ["^"] = 8, ["&"] = 8, ["*"] = 8,
            ["("] = 8, [")"] = 8, ["_"] = 8, ["+"] = 8, ["="] = 8, ["["] = 8,
            ["]"] = 8, ["{"] = 8, ["}"] = 8, ["|"] = 8, ["\\"] = 8, ["/"] = 8,
            ["<"] = 8, [">"] = 8, [","] = 8, ["?"] = 8
        }
    }
    
    self.player_fonts = {}
    
    Net:on("player_join", function(event)
        self:setupPlayerFonts(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerFonts(event.player_id)
    end)
    
    return self
end

function FontSystem:setupPlayerFonts(player_id)
    self.player_fonts[player_id] = {
        active_displays = {},
        next_obj_id = 1
    }
    
    -- Provide assets and allocate sprites for each font type
    for font_name, sprite_data in pairs(self.font_sprites) do
        Net.provide_asset_for_player(player_id, sprite_data.texture_path)
        if sprite_data.anim_path then
            Net.provide_asset_for_player(player_id, sprite_data.anim_path)
        end
        
        Net.player_alloc_sprite(player_id, font_name, sprite_data)
    end
end

function FontSystem:cleanupPlayerFonts(player_id)
    local player_data = self.player_fonts[player_id]
    if player_data then
        -- Erase all active displays
        for display_id, display in pairs(player_data.active_displays) do
            self:eraseTextDisplay(player_id, display_id)
        end
        
        -- Deallocate all font sprites
        for font_name, _ in pairs(self.font_sprites) do
            Net.player_dealloc_sprite(player_id, font_name)
        end
        
        self.player_fonts[player_id] = nil
    end
end

function FontSystem:drawText(player_id, text, x, y, font_name, scale, z_order)
    font_name = font_name or "THICK"
    scale = scale or 1.0
    z_order = z_order or 100
    
    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end
    
    local display_id = "text_" .. player_data.next_obj_id
    player_data.next_obj_id = player_data.next_obj_id + 1
    
    local display_data = {
        font = font_name,
        x = x,
        y = y,
        scale = scale,
        z_order = z_order,
        character_objects = {},
        text = text
    }
    
    local current_x = x
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    
    -- FIXED: Calculate spacing that scales properly to preserve monospace
    local base_spacing = 1  -- Base spacing at scale 1.0
    local scaled_spacing = base_spacing * scale
    
    for i = 1, #text do
        local char = text:sub(i, i)
        -- Use a default width if character not found
        local char_width = char_widths[char] or char_widths["A"] or 6
        local scaled_width = char_width * scale
        
        local obj_id = display_id .. "_" .. i
        
        Net.player_draw_sprite(
            player_id,
            font_name,
            {
                id = obj_id,
                x = current_x,
                y = y,
                z = z_order,
                sx = scale,
                sy = scale,
                anim_state = font_name .. "_" .. char
            }
        )
        
        table.insert(display_data.character_objects, {
            obj_id = obj_id,
            width = scaled_width
        })
        
        -- FIXED: Use scaled spacing to preserve monospace at different scales
        current_x = current_x + scaled_width + scaled_spacing
    end
    
    player_data.active_displays[display_id] = display_data
    return display_id
end

function FontSystem:eraseTextDisplay(player_id, display_id)
    local player_data = self.player_fonts[player_id]
    if player_data then
        local display = player_data.active_displays[display_id]
        if display then
            for _, char_data in ipairs(display.character_objects) do
                Net.player_erase_sprite(player_id, char_data.obj_id)
            end
            player_data.active_displays[display_id] = nil
        end
    end
end

function FontSystem:getTextWidth(text, font_name, scale)
    font_name = font_name or "THICK"
    scale = scale or 1.0
    
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local total_width = 0
    
    -- FIXED: Calculate spacing that scales properly
    local base_spacing = 1  -- Base spacing at scale 1.0
    local scaled_spacing = base_spacing * scale
    
    for i = 1, #text do
        local char = text:sub(i, i)
        local char_width = char_widths[char] or char_widths["A"] or 6
        total_width = total_width + (char_width * scale) + scaled_spacing
    end
    
    -- Remove trailing spacing
    if #text > 0 then
        total_width = total_width - scaled_spacing
    end
    
    return total_width
end

local fontSystem = setmetatable({}, FontSystem)
fontSystem:init()

return fontSystem