CONSTANTS MODULE
================

PURPOSE:
Centralizes all asset paths and configuration constants for tournament board visuals.

ASSET PATH ORGANIZATION:
All paths are prefixed with "/server/assets/tourney/tourney-board-elements/"

VISUAL THEMES:
bracket_background_path provides 7 color themes:
- blue_bn4, green_bn4, pink_yellow_bn4, pink_bn4
- lemon_lime_bn4, green_blue_white_bn4, red_orange_bn4

Each theme includes:
- gradient_texture: Background gradient image
- grid_texture: Overlay grid pattern

BRACKET VARIATIONS:
- bracket_bm_bn4: Blue Moon bracket style
- bracket_rs_bn4: Red Sun bracket style

ANIMATION PATHS:
- default_bracket_anim_path_bn4: Bracket animation
- default_background_anim_path_bn4: Background gradient animation  
- default_grid_anim_path_bn4: Grid overlay animation
- default_mug_anim: Mugshot animation with empty states

SPECIAL ELEMENTS:
- crown_texture_path & crown_anim_path: Crown decoration
- champion_topper_bn4/champion_topper_bn45: Top bracket decorations
- champion_topper_bn4_anim/champion_topper_bn45_anim: Topper animations

DEFAULT FALLBACKS:
If specific assets are unavailable, the system falls back to:
- red_orange_bn4 theme for backgrounds
- Default animations for all moving elements

USAGE:
This module ensures consistent asset management and makes theme changes trivial
by modifying a single location. All visual customization should be done here.