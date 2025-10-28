UI DATA MODULE
==============

PURPOSE:
Defines all UI element names, positions, and layout data for the tournament board display.

KEY DATA STRUCTURES:

frame_names:
- Array of all UI element identifiers that need to be managed
- Includes mugshot frames (MUG_FRAME_1-8), mugshots (MUG_1-8), and board elements
- Used for cleanup operations

unmoving_ui_pos:
- Coordinate positions for static UI elements
- All positions include x, y, z coordinates for proper layering

UI ELEMENT POSITIONS:

bg (Background):
- x: 0, y: 0, z: -2 (bottom layer)

grid (Board Grid):
- x: 0, y: 0, z: -1 (above background)

title_banner (Title Banner):
- x: 0, y: 0, z: 0 (default layer)

bracket (Tournament Bracket):
- x: 0, y: 0, z: 0 (default layer)

crown1, crown2 (Crown Decorations):
- crown1: x: 64, y: 48, z: 0
- crown2: x: 176, y: 48, z: 0

champion_topper_bn4 (Champion Topper):
- x: 80, y: 40, z: 1 (top layer)

Z-COORDINATE LAYERING:
- -2: Background
- -1: Grid
-  0: Default UI elements
-  1: Top layer elements
-  2: Mugshots (handled separately in mug-pos.lua)

USAGE:
This module provides the foundational layout data that ensures consistent positioning
across all tournament board displays. The z-coordinate system prevents visual clipping
and ensures proper element layering.