local ui_element_paths = "/server/assets/tourney/tourney-board-elements/"

local CONSTANTS = {
    bracket_background_path = {
        blue_bn4 = {
            gradient_texture=ui_element_paths.."blue-bn4/gradient.png",
            grid_texture=ui_element_paths.."blue-bn4/grid.png",
        },
        green_bn4 = {
            gradient_texture=ui_element_paths.."green-bn4/gradient.png",
            grid_texture=ui_element_paths.."green-bn4/grid.png",
        },
        pink_yellow_bn4 = {
            gradient_texture=ui_element_paths.."pink-yellow-bn4/gradient.png",
            grid_texture=ui_element_paths.."pink-yellow-bn4/grid.png",
        },
        pink_bn4 = {
            gradient_texture=ui_element_paths.."pink-bn4/gradient.png",
            grid_texture=ui_element_paths.."pink-bn4/grid.png",
        },
        lemon_lime_bn4 = {
            gradient_texture=ui_element_paths.."lemon-lime-bn4/gradient.png",
            grid_texture=ui_element_paths.."lemon-lime-bn4/grid.png",
        },
        green_blue_white_bn4 = {
            gradient_texture=ui_element_paths.."green-blue-white-bn4/gradient.png",
            grid_texture=ui_element_paths.."green-blue-white-bn4/grid.png",
        },
        red_orange_bn4 = {
            gradient_texture=ui_element_paths.."red-orange-bn4/gradient.png",
            grid_texture=ui_element_paths.."red-orange-bn4/grid.png",
        },
    },
    -- Bracket/Tourney Path paths
    bracket_bm_bn4 = ui_element_paths.."bracket-bm.png",
    bracket_rs_bn4 = ui_element_paths.."bracket-rs.png",
    -- Default bracket animation to be used with the above bracket_texture(s).
    default_bracket_anim_path_bn4 = ui_element_paths.."bracket.anim",
    -- Default bg animation to be used with the above BG gradients_texture(s).
    default_background_anim_path_bn4 = ui_element_paths.."gradient.anim",
    -- Default grid animation to be used with the above grid_textures.
    default_grid_anim_path_bn4 = ui_element_paths.."grid.anim",
    -- Default mugshot animation has all the needed built in empty animation_state(s)
    default_mug_anim = ui_element_paths.."mug.anim",
    -- Crown Textrue and anim (BN4)
    crown_texture_path = ui_element_paths.."crown.png",
    crown_anim_path = ui_element_paths.."crown.anim",
    -- Champion Toppers for the top of our Brackets/Tourney Path graphic
    champion_topper_bn4=ui_element_paths.."champion-topper-bn4.png",
    champion_topper_bn45=ui_element_paths.."champion-topper-bn45.png",
    -- Default Champion Topper animation path
    champion_topper_bn4_anim=ui_element_paths.."champion-topper-bn4.anim",
    champion_topper_bn45_anim=ui_element_paths.."champion-topper-bn45.anim",
}

return CONSTANTS
