MUGSHOT POSITION MODULE
=======================

PURPOSE:
Defines all coordinate positions for participant mugshots throughout tournament progression.

COORDINATE SYSTEM:
- x: Horizontal position (0-240)
- y: Vertical position (0-132) 
- z: Layering depth (2 for mugshots, above UI elements)

POSITION TIERS:

initial (Round 0 - 8 positions):
All participants start at bottom in two rows:
[1] x: 8, y: 132    [5] x: 128, y: 132
[2] x: 34, y: 132   [6] x: 154, y: 132  
[3] x: 64, y: 132   [7] x: 184, y: 132
[4] x: 90, y: 132   [8] x: 210, y: 132

round1_winners (Round 1 - 4 positions):
Winners move up to middle tier:
[1] x: 22, y: 82    [3] x: 142, y: 82
[2] x: 78, y: 82    [4] x: 198, y: 82

round2_winners (Round 2 - 2 positions):
Winners move to upper tier:
[1] x: 50, y: 56    [2] x: 170, y: 56

champion (Round 3 - 1 position):
Tournament winner at top center:
[1] x: 110, y: 34

BRACKET PAIRING LOGIC:
Positions are organized to visually represent tournament bracket:
- Positions 1-2 form first match, 3-4 second match, etc.
- Left-side winners move to left middle positions
- Right-side winners move to right middle positions
- Final positions maintain left/right bracket symmetry

ANIMATION SUPPORT:
The coordinate system supports smooth transitions between rounds.
Z-coordinate ensures mugshots always appear above board elements.