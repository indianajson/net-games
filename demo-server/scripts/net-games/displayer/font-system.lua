-- Font System for Timer Display (Following example_sprites pattern)
FontSystem = {}
FontSystem.__index = FontSystem

function FontSystem:init()
    local COMP_TEX  = "/server/assets/net-games/fonts_compressed.png"
    local COMP_ANIM = "/server/assets/net-games/fonts_compressed.animation"
    local DARK_TEX  = "/server/assets/net-games/fonts_dark_compressed.png"
    local DARK_ANIM = "/server/assets/net-games/fonts_dark_compressed.animation"

    self.font_sprites = {
        -- Light
        THICK = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "THICK_0" },
        THIN  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "THIN_0" },
        WIDE  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "WIDE_0" },
        TINY  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "TINY_0" },
        BATTLE= { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "BATTLE_0" },

        GRADIENT        = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_0" },
        GRADIENT_GOLD   = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_GOLD_0" },
        GRADIENT_ORANGE = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_ORANGE_0" },
        GRADIENT_GREEN  = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_GREEN_0" },
        GRADIENT_TALL   = { texture_path = COMP_TEX, anim_path = COMP_ANIM, anim_state = "GRADIENT_TALL_0" },

        -- Dark
        THICK_BLACK = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "THICK_0" },
        THIN_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "THIN_0" },
        WIDE_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "WIDE_0" },
        TINY_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "TINY_0" },
        BATTLE_BLACK= { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "BATTLE_0" },

        GRADIENT_BLACK        = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_0" },
        GRADIENT_GOLD_BLACK   = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_GOLD_0" },
        GRADIENT_ORANGE_BLACK = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_ORANGE_0" },
        GRADIENT_GREEN_BLACK  = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_GREEN_0" },
        GRADIENT_TALL_BLACK   = { texture_path = DARK_TEX, anim_path = DARK_ANIM, anim_state = "GRADIENT_TALL_0" },
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
        GRADIENT_GOLD = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_TALL = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_GREEN = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_ORANGE = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["+"] = 7
        },
        BATTLE = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [" "] = 7,
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, ["!"] = 7, ["_"] = 7, ["<"] = 7, [">"] = 7
        },
        THIN = {
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, [":"] = 5, ["&"] = 7, ["'"] = 6, ["="] = 7,
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["a"] = 7, ["b"] = 7,
            ["c"] = 7, ["d"] = 7, ["e"] = 7, ["f"] = 6, ["g"] = 7, ["h"] = 7,
            ["i"] = 4, ["j"] = 7, ["k"] = 7, ["l"] = 4, ["m"] = 7, ["n"] = 7,
            ["o"] = 7, ["p"] = 7, ["q"] = 7, ["r"] = 6, ["s"] = 7, ["t"] = 7,
            ["u"] = 7, ["v"] = 7, ["w"] = 7, ["x"] = 7, ["y"] = 7, ["z"] = 7,
            ["-"] = 7, ["!"] = 4, ["/"] = 7, ["."] = 5, ["?"] = 7, [","] = 5,
            ['"'] = 7, ["_"] = 7, ["$"] = 7, ["("] = 7, [")"] = 7, ["["] = 7,
            ["]"] = 7, ["*"] = 7, ["~"] = 7, ["`"] = 7, ["^"] = 7, ["+"] = 7,
            ["#"] = 7, ["%"] = 7, ["@"] = 7, ["<"] = 7, [">"] = 7, ["{"] = 7,
            ["}"] = 7, [";"] = 5
            },
        TINY = {
            ["A"] = 5, ["B"] = 5, ["C"] = 5, ["D"] = 5, ["E"] = 5, ["F"] = 5,
            ["G"] = 5, ["H"] = 5, ["I"] = 5, ["J"] = 5, ["K"] = 5, ["L"] = 5,
            ["M"] = 5, ["N"] = 5, ["O"] = 5, ["P"] = 5, ["Q"] = 5, ["R"] = 5,
            ["S"] = 5, ["T"] = 5, ["U"] = 5, ["V"] = 5, ["W"] = 5, ["X"] = 5,
            ["Y"] = 5, ["Z"] = 5, ["a"] = 5, ["b"] = 5, ["c"] = 5, ["d"] = 5,
            ["e"] = 5, ["f"] = 5, ["g"] = 5, ["h"] = 5, ["i"] = 5, ["j"] = 5,
            ["k"] = 5, ["l"] = 5, ["m"] = 5, ["n"] = 5, ["o"] = 5, ["p"] = 5,
            ["q"] = 5, ["r"] = 5, ["s"] = 5, ["t"] = 5, ["u"] = 5, ["v"] = 5,
            ["w"] = 5, ["x"] = 5, ["y"] = 5, ["z"] = 5, ["0"] = 5, ["1"] = 5,
            ["2"] = 5, ["3"] = 5, ["4"] = 5, ["5"] = 5, ["6"] = 5, ["7"] = 5,
            ["8"] = 5, ["9"] = 5, ["("] = 5, [")"] = 5, ["_"] = 5, ["-"] = 5,
            ["+"] = 5, ["="] = 5, ["\\"] = 5, ["/"] = 5, ["<"] = 5, [">"] = 5,
            ["?"] = 5, [","] = 5, ["."] = 5, ["!"] = 5, ["@"] = 5, ["#"] = 5,
            ["$"] = 5, ["%"] = 5, ["^"] = 5, ["&"] = 5, ["*"] = 5, ["'"] = 5,
            ['"'] = 5, [":"] = 5, [";"] = 5, [" "] = 5

        },
        WIDE = {
            ["A"] = 7, ["B"] = 6, ["C"] = 6, ["D"] = 6, ["E"] = 6, ["F"] = 6,
            ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6, ["K"] = 6, ["L"] = 6,
            ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6, ["Q"] = 7, ["R"] = 6,
            ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6, ["W"] = 6, ["X"] = 6,
            ["Y"] = 6, ["Z"] = 6, ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6,
            ["4"] = 6, ["5"] = 6, ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6,
            ["("] = 6, [")"] = 6, ["_"] = 6, ["-"] = 6, ["+"] = 6, ["="] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, ["?"] = 6, [","] = 6,
            ["."] = 6, ["!"] = 6, ["@"] = 7, ["#"] = 6, ["$"] = 6, ["%"] = 6,
            ["^"] = 6, ["&"] = 6, ["*"] = 6, ["'"] = 6, ['"'] = 6, [":"] = 6,
            [";"] = 6
        },
        THICK_BLACK = {
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
        GRADIENT_GOLD_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_TALL_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_GREEN_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7
        },
        GRADIENT_ORANGE_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["+"] = 7
        },
        BATTLE_BLACK = {
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, [" "] = 7,
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, ["!"] = 7, ["_"] = 7, ["<"] = 7, [">"] = 7
        },
        THIN_BLACK = {
            ["A"] = 7, ["B"] = 7, ["C"] = 7, ["D"] = 7, ["E"] = 7, ["F"] = 7,
            ["G"] = 7, ["H"] = 7, ["I"] = 7, ["J"] = 7, ["K"] = 7, ["L"] = 7,
            ["M"] = 7, ["N"] = 7, ["O"] = 7, ["P"] = 7, ["Q"] = 7, ["R"] = 7,
            ["S"] = 7, ["T"] = 7, ["U"] = 7, ["V"] = 7, ["W"] = 7, ["X"] = 7,
            ["Y"] = 7, ["Z"] = 7, [":"] = 5, ["&"] = 7, ["'"] = 6, ["="] = 7,
            ["0"] = 7, ["1"] = 7, ["2"] = 7, ["3"] = 7, ["4"] = 7, ["5"] = 7,
            ["6"] = 7, ["7"] = 7, ["8"] = 7, ["9"] = 7, ["a"] = 7, ["b"] = 7,
            ["c"] = 7, ["d"] = 7, ["e"] = 7, ["f"] = 6, ["g"] = 7, ["h"] = 7,
            ["i"] = 4, ["j"] = 7, ["k"] = 7, ["l"] = 4, ["m"] = 7, ["n"] = 7,
            ["o"] = 7, ["p"] = 7, ["q"] = 7, ["r"] = 6, ["s"] = 7, ["t"] = 7,
            ["u"] = 7, ["v"] = 7, ["w"] = 7, ["x"] = 7, ["y"] = 7, ["z"] = 7,
            ["-"] = 7, ["!"] = 4, ["/"] = 7, ["."] = 5, ["?"] = 7, [","] = 5,
            ['"'] = 7, ["_"] = 7, ["$"] = 7, ["("] = 7, [")"] = 7, ["["] = 7,
            ["]"] = 7, ["*"] = 7, ["~"] = 7, ["`"] = 7, ["^"] = 7, ["+"] = 7,
            ["#"] = 7, ["%"] = 7, ["@"] = 7, ["<"] = 7, [">"] = 7, ["{"] = 7,
            ["}"] = 7, [";"] = 5
            },
        TINY_BLACK = {
            ["A"] = 5, ["B"] = 5, ["C"] = 5, ["D"] = 5, ["E"] = 5, ["F"] = 5,
            ["G"] = 5, ["H"] = 5, ["I"] = 5, ["J"] = 5, ["K"] = 5, ["L"] = 5,
            ["M"] = 5, ["N"] = 5, ["O"] = 5, ["P"] = 5, ["Q"] = 5, ["R"] = 5,
            ["S"] = 5, ["T"] = 5, ["U"] = 5, ["V"] = 5, ["W"] = 5, ["X"] = 5,
            ["Y"] = 5, ["Z"] = 5, ["a"] = 5, ["b"] = 5, ["c"] = 5, ["d"] = 5,
            ["e"] = 5, ["f"] = 5, ["g"] = 5, ["h"] = 5, ["i"] = 5, ["j"] = 5,
            ["k"] = 5, ["l"] = 5, ["m"] = 5, ["n"] = 5, ["o"] = 5, ["p"] = 5,
            ["q"] = 5, ["r"] = 5, ["s"] = 5, ["t"] = 5, ["u"] = 5, ["v"] = 5,
            ["w"] = 5, ["x"] = 5, ["y"] = 5, ["z"] = 5, ["0"] = 5, ["1"] = 5,
            ["2"] = 5, ["3"] = 5, ["4"] = 5, ["5"] = 5, ["6"] = 5, ["7"] = 5,
            ["8"] = 5, ["9"] = 5, ["("] = 5, [")"] = 5, ["_"] = 5, ["-"] = 5,
            ["+"] = 5, ["="] = 5, ["\\"] = 5, ["/"] = 5, ["<"] = 5, [">"] = 5,
            ["?"] = 5, [","] = 5, ["."] = 5, ["!"] = 5, ["@"] = 5, ["#"] = 5,
            ["$"] = 5, ["%"] = 5, ["^"] = 5, ["&"] = 5, ["*"] = 5, ["'"] = 5,
            ['"'] = 5, [":"] = 5, [";"] = 5, [" "] = 5
        },
        WIDE_BLACK = {
            ["A"] = 7, ["B"] = 6, ["C"] = 6, ["D"] = 6, ["E"] = 6, ["F"] = 6,
            ["G"] = 6, ["H"] = 6, ["I"] = 6, ["J"] = 6, ["K"] = 6, ["L"] = 6,
            ["M"] = 6, ["N"] = 6, ["O"] = 6, ["P"] = 6, ["Q"] = 7, ["R"] = 6,
            ["S"] = 6, ["T"] = 6, ["U"] = 6, ["V"] = 6, ["W"] = 6, ["X"] = 6,
            ["Y"] = 6, ["Z"] = 6, ["0"] = 6, ["1"] = 6, ["2"] = 6, ["3"] = 6,
            ["4"] = 6, ["5"] = 6, ["6"] = 6, ["7"] = 6, ["8"] = 6, ["9"] = 6,
            ["("] = 6, [")"] = 6, ["_"] = 6, ["-"] = 6, ["+"] = 6, ["="] = 6,
            ["\\"] = 6, ["/"] = 6, ["<"] = 6, [">"] = 6, ["?"] = 6, [","] = 6,
            ["."] = 6, ["!"] = 6, ["@"] = 7, ["#"] = 6, ["$"] = 6, ["%"] = 6,
            ["^"] = 6, ["&"] = 6, ["*"] = 6, ["'"] = 6, ['"'] = 6, [":"] = 6,
            [";"] = 6
        }
    }

    --=====================================================
    -- Alias *_BLACK width tables to their non-black equivalents
    -- This keeps glyph support checks (lowercase, punctuation, etc.)
    -- consistent across light/dark textures.
    --=====================================================
    local function alias_widths(black_name)
        local base = black_name:gsub("_BLACK$", "")
        if self.char_widths[base] and not self.char_widths[black_name] then
            self.char_widths[black_name] = self.char_widths[base]
        end
    end

    for font_name, _ in pairs(self.font_sprites) do
        if font_name:match("_BLACK$") then
            alias_widths(font_name)
        end
    end

    
    self.player_fonts = {}
    
    Net:on("player_join", function(event)
        self:setupPlayerFonts(event.player_id)
    end)
    
    Net:on("player_disconnect", function(event)
        self:cleanupPlayerFonts(event.player_id)
    end)
    -- Auto-sync bound displays (optional; used for AnimationEngine-driven sprite props)
    self._bound_tick_enabled = true
    Net:on("tick", function(event)
        if self._bound_tick_enabled then
            self:_tick_bound_displays(event.delta_time)
        end
    end)

    
    return self
end

function FontSystem:setupPlayerFonts(player_id)
    self.player_fonts[player_id] = {
        active_displays = {},
        next_obj_id = 10000  -- Start with high ID to avoid conflicts
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

-- Returns the animation prefix for a font.
-- Dark fonts reuse the SAME animation state names as their base font.
-- Example: THICK_BLACK uses THICK_* states (but draws with THICK_BLACK texture).
local function anim_prefix_for_font(font_name)
    -- strip ONLY a trailing "_BLACK"
    return (font_name and font_name:gsub("_BLACK$", "")) or font_name
end

-- Smart punctuation normalization (FontSystem needs this too; nameplates use FontSystem directly)
local function normalize_glyph(raw)
    if not raw or raw == "" then return nil end
    if raw == " " then return " " end

    -- single quotes
    if raw == "’" or raw == "‘" then raw = "'" end

    -- double quotes
    if raw == "“" or raw == "”" then raw = '"' end

    -- dashes
    if raw == "–" or raw == "—" then raw = "-" end

    return raw
end


-- Normalize punctuation into ASCII BEFORE we iterate by bytes.
-- Handles both UTF-8 punctuation and CP1252 "smart" punctuation bytes (common on Windows).
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
    -- 0x91 ‘  0x92 ’  0x93 “  0x94 ”  0x96 –  0x97 —  0x85 …
    local b = string.char
    text = text:gsub(b(0x91), "'"):gsub(b(0x92), "'")
    text = text:gsub(b(0x93), '"'):gsub(b(0x94), '"')
    text = text:gsub(b(0x96), "-"):gsub(b(0x97), "-")
    text = text:gsub(b(0x85), "...")

    return text
end

local DEBUG_UNKNOWN_GLYPHS = true

local function dbg_unknown(font_name, raw_byte, state, text, i)
    if not DEBUG_UNKNOWN_GLYPHS then return end
    local byte = string.byte(raw_byte)
    print(string.format("[FontSystem] unknown glyph: font=%s i=%d byte=0x%02X state=%s context=%q",
        tostring(font_name), i, byte, tostring(state), tostring(text)))
end



-- Table with each letter of the alphabet as separate strings
local alphabet = {
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
}

-- Function to check if a string is in the alphabet table
function isInAlphabet(str)
    for _, letter in ipairs(alphabet) do
        if letter == str then
            return true
        end
    end
    return false
end

function FontSystem:drawTextWithId(player_id, text, x, y, font_name, scale, z_order, display_id, sprite_opts)
    font_name = font_name or "THICK"
    scale = tonumber(scale) or 2.0
    z_order = z_order or 100
    text = normalize_text(text)

    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end
    if not display_id then return nil end

    local existing = player_data.active_displays[display_id]

    -- Backwards compatibility: old callers pass a "tint" table as the last param.
    -- New callers pass a full sprite-API-style props table.
    local opts = (type(sprite_opts) == "table") and sprite_opts or nil

    -- Resolve base transform (allow opts to override the positional args)
    local base_x = (opts and type(opts.x) == "number") and opts.x or (x or 0)
    local base_y = (opts and type(opts.y) == "number") and opts.y or (y or 0)
    local base_z = (opts and type(opts.z) == "number") and opts.z or z_order

    -- Scale: allow sx/sy (or scale/scaleX/scaleY) overrides
    local base_sx = scale
    local base_sy = scale
    if opts then
        if type(opts.sx) == "number" then base_sx = opts.sx end
        if type(opts.sy) == "number" then base_sy = opts.sy end
        if type(opts.scale) == "number" then
            base_sx = opts.scale
            base_sy = opts.scale
        end
        if type(opts.scaleX) == "number" then base_sx = opts.scaleX end
        if type(opts.scaleY) == "number" then base_sy = opts.scaleY end
    end

    -- For spacing we use x-scale (sx)
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local base_spacing = 1
    local scaled_spacing = base_spacing * base_sx

    local function apply_common_sprite_props(t)
        -- Always reset tint so previous draws don't 'stick'
        t.opacity = 255
        t.r = 255
        t.g = 255
        t.b = 255
        t.color_mode = 0

        if not opts then return end
        -- origin / rotation / opacity / color
        if type(opts.ox) == "number" then t.ox = opts.ox end
        if type(opts.oy) == "number" then t.oy = opts.oy end

        local ro = opts.ro
        if ro == nil then ro = opts.rotation end
        if type(ro) == "number" then t.ro = ro end

        local opacity = opts.opacity
        if opacity == nil then opacity = opts.a end
        if opacity == nil then opacity = opts.alpha end
        if type(opacity) == "number" then
            t.opacity = opacity
        end

        if type(opts.r) == "number" then t.r = opts.r end
        if type(opts.g) == "number" then t.g = opts.g end
        if type(opts.b) == "number" then t.b = opts.b end
        if type(opts.color_mode) == "number" then t.color_mode = opts.color_mode end
    end

    if not existing then
        existing = {
            font = font_name,
            x = base_x,
            y = base_y,
            scale = scale,
            z_order = base_z,
            character_objects = {},
            text = "",
            -- binding (optional)
            bound_obj = nil,
            bound_auto_sync = nil
        }
        player_data.active_displays[display_id] = existing
    end

    local prefix = anim_prefix_for_font(font_name)

    local current_x = base_x
    local obj_i = 0

    -- Draw/update glyph sprites in place using stable obj ids
    for i = 1, #text do
        local raw = text:sub(i, i)
        local char = normalize_glyph(raw) or raw

        if (font_name == "BATTLE" or font_name == "WIDE") and char:match("%a") then
            char = char:upper()
        end

        local char_width = char_widths[char] or char_widths["A"] or 6
        local scaled_width = char_width * base_sx

        -- Space: advance only (no sprite)
        if char == " " then
            current_x = current_x + scaled_width + scaled_spacing
        else
            obj_i = obj_i + 1
            local obj_id = display_id .. "_char_" .. (10000 + obj_i)

            local state
            if char == char:lower() and isInAlphabet(char) then
                state = prefix .. "_LOWER_" .. char:upper()
            else
                state = prefix .. "_" .. char
            end

            local spr = {
                id = obj_id,
                x = current_x,
                y = base_y,
                z = base_z,
                sx = base_sx,
                sy = base_sy,
                ox = sprite_opts.ox or 0,
                oy = sprite_opts.oy or 0,
                ro = sprite_opts.ro or 0,
                a = sprite_opts.a,
                r = sprite_opts.r,
                g = sprite_opts.g,
                b = sprite_opts.b,
                opacity = sprite_opts.opacity,
                anim_state = state
            }

            apply_common_sprite_props(spr)

            Net.player_draw_sprite(player_id, font_name, spr)

            existing.character_objects[obj_i] = { obj_id = obj_id, width = scaled_width }
            current_x = current_x + scaled_width + scaled_spacing
        end
    end

    -- Erase any leftover glyph sprites from the previous longer string
    for j = obj_i + 1, #existing.character_objects do
        local tail = existing.character_objects[j]
        if tail and tail.obj_id then
            Net.player_erase_sprite(player_id, tail.obj_id)
        end
        existing.character_objects[j] = nil
    end

    existing.font = font_name
    existing.x = base_x
    existing.y = base_y
    existing.scale = scale
    existing.z_order = base_z
    existing.text = text

    return display_id
end


function FontSystem:drawText(player_id, text_id, text, x, y, z_order, font_name, scale, sprite_opts)
    font_name = font_name or "THICK"
    scale = tonumber(scale) or 2.0
    z_order = z_order or 100
    text = normalize_text(text)

    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end

    local display_id = text_id or ("text_" .. player_data.next_obj_id)
    player_data.next_obj_id = player_data.next_obj_id + 1

    return self:drawTextWithId(
        player_id,
        text,
        x,
        y,
        font_name,
        scale,
        z_order,
        display_id,
        sprite_opts
    )
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

function FontSystem:bindTextDisplay(player_id, display_id, obj, auto_sync)
    local player_data = self.player_fonts[player_id]
    if not player_data then return false end

    local display = player_data.active_displays[display_id]
    if not display then return false end
    if type(obj) ~= "table" then return false end

    display.bound_obj = obj
    if auto_sync == nil then auto_sync = true end
    display.bound_auto_sync = auto_sync and true or false
    return true
end

function FontSystem:unbindTextDisplay(player_id, display_id)
    local player_data = self.player_fonts[player_id]
    if not player_data then return false end

    local display = player_data.active_displays[display_id]
    if not display then return false end

    display.bound_obj = nil
    display.bound_auto_sync = nil
    return true
end

function FontSystem:_tick_bound_displays(_dt)
    for player_id, player_data in pairs(self.player_fonts) do
        for display_id, display in pairs(player_data.active_displays) do
            if display and display.bound_obj and display.bound_auto_sync then
                self:drawTextWithId(
                    player_id,
                    display.text or "",
                    display.x or 0,
                    display.y or 0,
                    display.font or "THICK",
                    display.scale or 2.0,
                    display.z_order or 100,
                    display_id,
                    display.bound_obj
                )
            end
        end
    end
end

function FontSystem:getTextWidth(text, font_name, scale)
    font_name = font_name or "THICK"
    scale = scale or 2.0
    text = normalize_text(text)

    
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local total_width = 0
    
    -- FIXED: Calculate spacing that scales properly
    local base_spacing = 1  -- Base spacing at scale 1.0
    local scaled_spacing = base_spacing * scale
    
    for i = 1, #text do
        local raw = text:sub(i, i)
        local char = normalize_glyph(raw) or raw
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
