NPC PATHS MODULE
================

PURPOSE:
Defines all available NPC opponents with their assets and combat characteristics.

NPC DATA STRUCTURE:
Each NPC entry contains:
{
  player_id: string,      -- Unique NPC identifier (path to zip)
  player_mugshot: {
    mug_texture: string,  -- Path to mugshot image
    mug_animation: string -- Path to mugshot animation
  },
  weight: number         -- Combat strength (1-100)
}

NPC ROSTER:

Boss Tier (70+ weight):
- colonel (70) - Strong military opponent
- protoman (75) - Legendary swordsman
- quickman (68) - Speed-focused
- shadowman (72) - Stealth specialist  
- gbeast-megaman (80) - Final boss tier

Mid Tier (55-69):
- blastman (60) - Explosive attacks
- burnerman (55) - Fire element
- elementman (65) - Elemental mastery
- fireman (58) - Classic fire boss
- gutsman (62) - Power fighter
- woodman (56) - Nature element

Lower Tier (40-54):
- airman (50) - Wind attacks
- circusman (45) - Tricky patterns
- cutman (40) - Simple cutter
- hatman (48) - Magic tricks
- iceman (52) - Ice element
- jammingman (47) - Disruption specialist
- roll (42) - Support fighter
- starman (54) - Cosmic powers

ASSET ORGANIZATION:
All NPC assets follow pattern:
/server/assets/tourney/npc-navis-testing/[name]/

- Mugshots: [name]/mug.png
- Battle data: [name]/[name]1.zip

WEIGHT SYSTEM:
- Determines NPC battle performance
- Higher weight = better chance to win
- Used in weighted random calculations
- Balanced around player skill levels

BALANCE NOTES:
- Weight range: 40-80 (player baseline ~50)
- Variety of difficulty levels
- Thematic element strengths
- Classic Mega Man boss relationships preserved

USAGE:
- Random selection for tournament backfill
- Weight-based battle outcomes
- Consistent asset path generation
- Easy expansion by adding new entries