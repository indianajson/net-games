-- Font System for Timer Display (Following example_sprites pattern)
FontSystem = {}
FontSystem.__index = FontSystem

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

function FontSystem:init()
    local COMP_TEX  = "/server/assets/net-games/fonts/fonts_compressed.png"
    local COMP_ANIM = "/server/assets/net-games/fonts/fonts_compressed.animation"
    local DARK_TEX  = "/server/assets/net-games/fonts/fonts_dark_compressed.png"
    local DARK_ANIM = "/server/assets/net-games/fonts/fonts_dark_compressed.animation"

    local WIDE_ANIM = "/server/assets/net-games/fonts/fonts_wide.animation"
    local GRADIENT_ANIM = "/server/assets/net-games/fonts/fonts_gradient.animation"
    local THICK_ANIM = "/server/assets/net-games/fonts/fonts_thick.animation"
    local BATTLE_ANIM = "/server/assets/net-games/fonts/fonts_battle.animation"
    local THIN_ANIM = "/server/assets/net-games/fonts/fonts_thin.animation"
    local TINY_ANIM = "/server/assets/net-games/fonts/fonts_tiny.animation"


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
    
    return self
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
    if raw == "�" or raw == "�" then raw = "'" end

    -- double quotes
    if raw == "�" or raw == "�" then raw = '"' end

    -- dashes
    if raw == "�" or raw == "�" then raw = "-" end

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
    text = text:gsub("�", "'"):gsub("�", "'")
    text = text:gsub("�", '"'):gsub("�", '"')
    text = text:gsub("�", "-"):gsub("�", "-")
    text = text:gsub("�", "...")

    -- CP1252 smart punctuation bytes (Windows-1252)
    -- 0x91 �  0x92 �  0x93 �  0x94 �  0x96 �  0x97 �  0x85 �
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

-- =====================================================
-- NEW: Glyph existence and fallback helpers
-- =====================================================
function FontSystem:glyph_exists(font_name, glyph)
    local widths = self.char_widths[font_name] or self.char_widths.THICK
    return widths and widths[glyph] ~= nil
end

function FontSystem:choose_glyph(font_name, glyph)
    if self:glyph_exists(font_name, glyph) then
        return glyph
    end
    if glyph:match("%a") then
        local up = glyph:upper()
        if self:glyph_exists(font_name, up) then
            return up
        end
    end
    if self:glyph_exists(font_name, "?") then
        return "?"
    end
    return nil
end

-- =====================================================
-- NEW: Word wrapping to lines (pixel‑based)
-- =====================================================
function FontSystem:wrapTextToLines(text, font_name, scale, max_width)
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local base_spacing = 1
    local scaled_spacing = base_spacing * scale

    local function string_width(str)
        local w = 0
        for i = 1, #str do
            local ch = str:sub(i, i)
            if ch == " " then
                w = w + (char_widths[" "] or char_widths["A"] or 6) * scale + scaled_spacing
            else
                local glyph = self:choose_glyph(font_name, ch) or "?"
                local cw = char_widths[glyph] or char_widths["A"] or 6
                w = w + cw * scale + scaled_spacing
            end
        end
        if #str > 0 then
            w = w - scaled_spacing
        end
        return w
    end

    local lines = {}
    local current_line = ""
    local current_width = 0

    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    -- Simple approach: treat all whitespace as word boundaries, collapse multiple spaces
    -- This matches typical text display; for exact space preservation we'd need a tokenizer.
    -- We'll use a tokenizer similar to text-display.lua's for accuracy.

    -- Tokenizer for words, spaces, newlines
    local tokens = {}
    local i = 1
    while i <= #text do
        local c = text:sub(i, i)
        if c == "\n" then
            table.insert(tokens, { t = "newline" })
            i = i + 1
        elseif c == " " then
            local j = i
            while j <= #text and text:sub(j, j) == " " do
                j = j + 1
            end
            table.insert(tokens, { t = "spaces", n = j - i })
            i = j
        elseif c:match("%s") then
            table.insert(tokens, { t = "spaces", n = 1 })
            i = i + 1
        else
            local j = i
            while j <= #text do
                local cj = text:sub(j, j)
                if cj == "\n" or cj:match("%s") then break end
                j = j + 1
            end
            table.insert(tokens, { t = "word", v = text:sub(i, j - 1) })
            i = j
        end
    end

    local idx = 1
    while idx <= #tokens do
        local tok = tokens[idx]

        if tok.t == "newline" then
            table.insert(lines, current_line)
            current_line = ""
            current_width = 0
            idx = idx + 1

        elseif tok.t == "spaces" then
            local space_str = string.rep(" ", tok.n)
            local space_width = string_width(space_str)
            if current_width + space_width <= max_width then
                current_line = current_line .. space_str
                current_width = current_width + space_width
                idx = idx + 1
            else
                -- spaces at start of line? if current_line empty, ignore spaces
                if current_line == "" then
                    idx = idx + 1
                else
                    table.insert(lines, current_line)
                    current_line = ""
                    current_width = 0
                    -- do not advance idx, reprocess spaces on new line
                end
            end

        else -- word
            local word = tok.v
            local word_width = string_width(word)

            if current_width + word_width <= max_width then
                current_line = current_line .. word
                current_width = current_width + word_width
                idx = idx + 1
            else
                if current_line == "" then
                    -- word longer than line: split it (fallback: use as much as fits)
                    -- For simplicity, we just put the whole word and hope it's rare
                    table.insert(lines, word)
                    idx = idx + 1
                else
                    table.insert(lines, current_line)
                    current_line = ""
                    current_width = 0
                    -- try the word again on the new line
                end
            end
        end
    end

    if current_line ~= "" then
        table.insert(lines, current_line)
    end

    return lines
end

-- =====================================================
-- NEW: Unified text drawing function
-- =====================================================
function FontSystem:drawTextEx(player_id, text, opts)
    opts = opts or {}
    local x = opts.x or 0
    local y = opts.y or 0
    local font_name = opts.font or "THICK"
    local scale = opts.scale or 2.0
    local z = opts.z or 100
    local width = opts.width          -- nil = no wrapping
    local height = opts.height        -- reserved for future
    local per_char_cb = opts.per_char_cb   -- function(line_idx, char_idx, raw_char, props) → overrides
    local display_id = opts.display_id
    local tint = opts.tint
    local align = opts.align or "left"      -- left, center, right (horizontal)
    local valign = opts.valign or "top"      -- top, center, bottom (vertical)

    text = normalize_text(text)

    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end

    -- Get font metrics
    local char_widths = self.char_widths[font_name] or self.char_widths.THICK
    local base_spacing = 1
    local scaled_spacing = base_spacing * scale
    local line_height = 12 * scale   -- can be made configurable later

    -- Wrap text if width given
    local lines
    if width then
        lines = self:wrapTextToLines(text, font_name, scale, width)
    else
        lines = { text }
    end

    -- Manage display entry
    local existing
    if display_id then
        existing = player_data.active_displays[display_id]
        if existing then
            -- Optional: early exit if nothing changed (skip per_char_cb for simplicity)
            -- We'll redraw fully each time to keep it simple.
        else
            existing = { character_objects = {} }
            player_data.active_displays[display_id] = existing
        end
    else
        display_id = "tmp_" .. tostring(math.random(1000000))
        existing = { character_objects = {} }
        player_data.active_displays[display_id] = existing
    end

    -- Erase all old objects
    for _, obj in ipairs(existing.character_objects) do
        Net.player_erase_sprite(player_id, obj.obj_id)
    end

    local new_objects = {}
    local line_y = y

    for line_idx, line in ipairs(lines) do
        local current_x = x
        for char_idx = 1, #line do
            local raw = line:sub(char_idx, char_idx)

            if raw == " " then
                -- Space: advance only
                local space_width = (char_widths[" "] or char_widths["A"] or 6) * scale
                current_x = current_x + space_width + scaled_spacing
            else
                local glyph = self:choose_glyph(font_name, raw)
                if glyph then
                    local char_width = char_widths[glyph] or char_widths["A"] or 6
                    local scaled_width = char_width * scale

                    -- Determine default anim state
                    local prefix = anim_prefix_for_font(font_name)
                    -- State names are always uppercase for letters, and exact for punctuation/digits
                    local state = prefix .. "_" .. glyph:upper()

                    -- Default sprite properties
                    local props = {
                        id = display_id .. "_" .. line_idx .. "_" .. char_idx,
                        x = current_x,
                        y = line_y,
                        z = z,
                        sx = scale,
                        sy = scale,
                        anim_state = state,
                        opacity = 255,
                    }

                    -- Apply global tint
                    if tint then
                        if tint.r then props.r = tint.r end
                        if tint.g then props.g = tint.g end
                        if tint.b then props.b = tint.b end
                        if tint.opacity then props.opacity = tint.opacity end
                        if tint.color_mode then props.color_mode = tint.color_mode end
                    end

                    -- Per‑character callback
                    if per_char_cb then
                        local overrides = per_char_cb(line_idx, char_idx, raw, props)
                        if overrides then
                            for k, v in pairs(overrides) do
                                props[k] = v
                            end
                        end
                    end

                    Net.player_draw_sprite(player_id, font_name, props)

                    table.insert(new_objects, { obj_id = props.id })
                    current_x = current_x + scaled_width + scaled_spacing
                else
                    -- No glyph available: advance using default width
                    current_x = current_x + (char_widths["A"] or 6) * scale + scaled_spacing
                end
            end
        end
        line_y = line_y + line_height
    end

    existing.character_objects = new_objects
    return display_id
end

function FontSystem:drawTextWithId(player_id, text, x, y, font_name, scale, z_order, display_id, tint)
    return self:drawTextEx(player_id, text, {
        x = x, y = y,
        font = font_name,
        scale = scale,
        z = z_order,
        display_id = display_id,
        tint = tint,
    })
end

function FontSystem:drawText(player_id, text_id, text, x, y, z_order, font_name, scale)
    font_name = font_name or "THICK"
    scale = tonumber(scale) or 2.0
    z_order = z_order or 100
    text = normalize_text(text)

    local player_data = self.player_fonts[player_id]
    if not player_data then return nil end

    local display_id = text_id or ("text_" .. player_data.next_obj_id)
    player_data.next_obj_id = player_data.next_obj_id + 1

    return self:drawTextEx(player_id, text, {
        x = x, y = y,
        font = font_name,
        scale = scale,
        z = z_order,
        display_id = display_id,
    })
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