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
    
    -- Character width data for consistent spacing
    self.char_widths = {
        THICK = {
            ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6, ["4"] = 6, ["5"] = 6,
            ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6, [":"] = 6, ["."] = 6,
            ["-"] = 6, [" "] = 6
        },
        GRADIENT = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [":"] = 7, [" "] = 7
        },
        BATTLE = {
            ["0"] = 8, ["1"] = 8, ["2"] = 8, ["3"] = 8, ["4"] = 8, ["5"] = 8,
            ["6"] = 8, ["7"] = 8, ["8"] = 8, ["9"] = 8, [":"] = 8, [" "] = 8
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
    
    for i = 1, #text do
        local char = text:sub(i, i)
        local char_width = char_widths[char] or char_widths[" "]
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
        
        -- Consistent spacing: character width + 1 pixel
        current_x = current_x + scaled_width + 1
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
    
    for i = 1, #text do
        local char = text:sub(i, i)
        local char_width = char_widths[char] or char_widths[" "]
        total_width = total_width + (char_width * scale) + 1
    end
    
    if #text > 0 then
        total_width = total_width - 1
    end
    
    return total_width
end

local fontSystem = setmetatable({}, FontSystem)
fontSystem:init()

return fontSystem