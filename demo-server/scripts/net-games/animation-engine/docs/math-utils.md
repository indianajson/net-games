MathUtils Documentation
A comprehensive utility library for mathematical operations, easing functions, geometric calculations, and animation-related math in Lua.

📋 Table of Contents
Overview

Installation

Core Math Functions

Easing Functions

Animation Math Functions

Geometric Functions

Random Functions

Table Operations

Practical Examples

Integration Guide

Performance Tips

Use Case Matrix

Troubleshooting

🎯 Overview
MathUtils is a versatile utility module designed for:

Animation mathematics - Smooth transitions, easing curves, and timing functions

Geometric calculations - Distance, angles, and spatial relationships

Visual effects - Screen shakes, pulses, color transitions

Game mechanics - Randomness, physics, and movement calculations

Key Benefits:

🚀 Performance optimized - Minimal overhead, caching-friendly

🎨 Visual richness - 18+ easing functions for beautiful animations

🔧 Practical utility - Real-world functions for game development

📦 Modular design - Use only what you need

📥 Installation
lua
-- Import the module in your Lua script
local MathUtils = require("scripts/net-games/animation-engine/math-utils")
Note: The path may need adjustment based on your project structure.

🧮 Core Math Functions
Basic Operations
Function	Description	Visual Effect	Example
clamp01(t)	Clamps value between 0-1	Limits animation progress	clamp01(1.5) → 1.0
lerp(a, b, t)	Linear interpolation	Smooth transitions	lerp(0, 100, 0.5) → 50
map(value, in_min, in_max, out_min, out_max)	Maps between ranges	UI sliders, normalized input	map(50, 0, 100, -1, 1) → 0.0
normalize(value, min, max)	Normalizes to 0-1 range	Progress bars, loading indicators	normalize(75, 0, 100) → 0.75
round(num, decimals)	Rounds to decimal places	UI number formatting	round(3.14159, 2) → 3.14
approximately(a, b, epsilon)	Fuzzy equality check	Animation completion detection	approximately(0.999, 1.0, 0.01) → true
Bezier Curves
lua
-- Quadratic Bezier (3 points)
local x, y = MathUtils.quadratic_bezier(
    {x = 0, y = 0},    -- Start
    {x = 50, y = 100}, -- Control
    {x = 100, y = 0},  -- End
    0.5               -- Progress
)

-- Cubic Bezier (4 points - more control)
local x, y = MathUtils.cubic_bezier(
    {x = 0, y = 0},     -- Start
    {x = 25, y = 150},  -- Control 1
    {x = 75, y = -50},  -- Control 2
    {x = 100, y = 0},   -- End
    0.5                -- Progress
)
Visual Applications:

🎯 Projectile arcs - Natural throwing motions

🛤️ Path animations - Smooth camera movement

🎢 UI transitions - Dynamic menu reveals

✨ Particle trails - Organic movement patterns

🎭 Easing Functions
Easing functions modify the rate of change over time, creating natural-looking animations.

Easing Function Matrix
Category	Function	Visual Feeling	Best For
Linear	linear	Constant speed	Progress bars, mechanical movement
Smooth	smoothstep	Very smooth	Professional UI, cinematic effects
smootherstep	Ultra smooth	Premium animations, luxury feel
Natural	ease_in	Starts slow	Objects falling, accelerating
ease_out	Ends slow	Objects landing, decelerating
ease_in_out	Both ends slow	Most UI animations, natural motion
Bouncy	elastic_in	Spring backward	Playful entrances, fun UI
elastic_out	Spring forward	Playful exits, notifications
elastic_in_out	Spring both ways	Complete playful animations
Bouncy	bounce_in	Ball drop in	Cartoon impacts, fun landings
bounce_out	Ball bounce out	Joyful celebrations, victory
Sinusoidal	sine_in	Wave start	Floating, wave-like motion
sine_out	Wave end	Gentle stops, soft landings
sine_in_out	Full wave	Ocean waves, breathing effects
Circular	circ_in	Circular start	Orbital entry, circular reveals
circ_out	Circular end	Orbital exit, circular hides
circ_in_out	Full circle	Complete circular motions
Overshoot	back_in	Pull back then go	Dramatic entrances, attention
back_out	Overshoot then back	Dramatic exits, emphasis
back_in_out	Both overshoots	Full dramatic animations
Easing Visual Guide
text
Linear:      |--------|
Ease In:     |......--|
Ease Out:    |--......|
Ease In/Out: |....--..|
Elastic:     |~-~-~---|
Bounce:      |--~-~-~~|
Usage Examples
lua
-- Basic easing
local progress = MathUtils.ease(0.5, "ease_out")  -- Returns ~0.75

-- With clamping (ensures 0-1 range)
local safe_progress = MathUtils.ease_clamped(1.5, "elastic_out")

-- Direct access to easing table
local eased = MathUtils.easing_functions.bounce_out(0.7)
Pro Tip: Different easings for different phases create polish:

lua
-- Menu animation: quick in, slow out
local open_t = MathUtils.ease(progress, "ease_out")
local close_t = MathUtils.ease(progress, "ease_in")
🎬 Animation Math Functions
Timing and Progress
lua
-- Calculate normalized progress from time
local progress = MathUtils.calculate_progress(elapsed_time, total_duration)

-- Example: 2-second animation, 1 second elapsed
-- progress = 1.0 / 2.0 = 0.5
Interpolation Utilities
lua
-- Interpolate with easing applied
local position = MathUtils.interpolate_with_easing(
    0,      -- Start value
    100,    -- End value
    0.5,    -- Progress (0-1)
    "ease_out"  -- Easing function
)

-- Color interpolation with alpha
local r, g, b, a = MathUtils.interpolate_color(
    255, 0, 0, 255,      -- Red, fully opaque
    0, 0, 255, 128,      -- Blue, half transparent
    0.5,                 -- Midpoint
    "ease_in_out"        -- Smooth transition
)
Visual Effects
Screen Shake
lua
-- Calculate shake offset with decay
local shakeX, shakeY = MathUtils.calculate_shake_offset(
    time_elapsed,   -- Seconds since shake started
    15,             -- Frequency (shakes per second)
    3.0,            -- Intensity (pixel offset)
    0.9             -- Decay (90% each frame)
)
Visual Applications:

💥 Explosions - Strong, high-frequency shake

🌋 Earthquakes - Sustained, low-frequency shake

⚡ Impacts - Quick, intense shake

🏹 Weapons - Subtle, directional shake

Pulse Effects
lua
-- Create a breathing/pulsing effect
local scale = MathUtils.calculate_pulse(
    time_variable,  -- Running time counter
    2.0,            -- 2 pulses per second
    1.0,            -- Minimum value
    1.2             -- Maximum value
)
Visual Applications:

❤️ Health indicators - Pulsing when low

🔔 Notifications - Attention-grabbing pulses

💡 Interactive elements - Hover pulse effects

🌟 Power-ups - Glowing pulse animation

📐 Geometric Functions
Distance and Positioning
Function	Formula	Use Case
distance(x1, y1, x2, y2)	√((x₂-x₁)² + (y₂-y₁)²)	Proximity detection, scaling by distance
distance_squared(x1, y1, x2, y2)	(x₂-x₁)² + (y₂-y₁)²	Fast distance comparison (no sqrt)
angle_between(x1, y1, x2, y2)	atan2(y₂-y₁, x₂-x₁)	Aiming, rotation toward target
midpoint(x1, y1, x2, y2)	((x₁+x₂)/2, (y₁+y₂)/2)	Center points, tween positioning
Practical Examples
lua
-- Check if player is in range (fast version)
local dist_sq = MathUtils.distance_squared(player.x, player.y, enemy.x, enemy.y)
if dist_sq < attack_range * attack_range then
    -- Enemy is in range (avoided sqrt calculation)
end

-- Rotate object to face target
local angle = MathUtils.angle_between(object.x, object.y, target.x, target.y)
object.rotation = MathUtils.rad_to_deg(angle)

-- Find center for UI placement
local center_x, center_y = MathUtils.midpoint(
    screen_left, screen_top,
    screen_right, screen_bottom
)
Hit Testing
lua
-- Check if point is inside rectangle
local is_inside = MathUtils.point_in_rect(
    mouse_x, mouse_y,    -- Point to test
    button_x, button_y,  -- Rectangle position
    button_w, button_h   -- Rectangle size
)

-- Check if point is within circle
local dist_sq = MathUtils.distance_squared(point_x, point_y, circle_x, circle_y)
local is_in_circle = dist_sq <= circle_radius * circle_radius
🎲 Random Functions
Random Number Generation
Function	Returns	Visual Application
random_float(min, max)	Float in range	Natural variation in animations
random_int(min, max)	Integer in range	Dice rolls, random selection
random_sign()	-1 or 1	Random direction for particles
random_element(array)	Random array element	Random colors, sounds, effects
Example: Particle System
lua
function create_particle()
    local particle = {
        x = start_x,
        y = start_y,
        velocity_x = MathUtils.random_float(-50, 50),
        velocity_y = MathUtils.random_float(-100, -50),
        scale = MathUtils.random_float(0.5, 1.5),
        color = MathUtils.random_element({"red", "orange", "yellow"}),
        life = MathUtils.random_float(1.0, 3.0)
    }
    return particle
end
Visual Applications:

🔥 Fire effects - Random upward motion

❄️ Snowfall - Gentle random drifting

✨ Magic sparks - Explosive random directions

🍃 Leaves falling - Natural random patterns

🗃️ Table Operations
Deep Copy and Merging
lua
-- Create independent copy of table
local original = {x = 10, nested = {y = 20}}
local copy = MathUtils.deep_copy(original)

-- Modify copy without affecting original
copy.nested.y = 30
print(original.nested.y)  -- Still 20

-- Merge configuration tables
local defaults = {duration = 1.0, easing = "linear"}
local overrides = {duration = 2.0, loop = true}
local config = MathUtils.merge_tables(defaults, overrides)
-- Result: {duration = 2.0, easing = "linear", loop = true}
🛠️ Practical Examples
Example 1: Smooth Camera Follow
lua
function update_camera(dt)
    -- Calculate target position (center on player)
    local target_x = player.x - screen_width / 2
    local target_y = player.y - screen_height / 2
    
    -- Smooth interpolation with easing
    local progress = MathUtils.calculate_progress(camera_time, camera_smooth_time)
    local eased = MathUtils.ease(progress, "ease_out")
    
    camera.x = MathUtils.lerp(camera.x, target_x, eased)
    camera.y = MathUtils.lerp(camera.y, target_y, eased)
end
Example 2: Health Bar Animation
lua
function update_health_bar(dt)
    -- Current health (0-1 normalized)
    local current_health = player.health / player.max_health
    
    -- Animate health bar with bounce effect at low health
    local easing = (current_health < 0.3) and "elastic_out" or "ease_out"
    local display_health = MathUtils.interpolate_with_easing(
        display_health, current_health, dt * 10, easing
    )
    
    -- Add pulse effect when health is critical
    if current_health < 0.2 then
        local pulse = MathUtils.calculate_pulse(
            pulse_time, 2.5, 0.8, 1.2
        )
        health_bar.scaleX = display_health * pulse
    else
        health_bar.scaleX = display_health
    end
end
Example 3: Menu Navigation Effects
lua
function animate_menu_selection(selected_index, previous_index)
    -- Deselect previous item (quick shrink)
    AnimationEngine.animate(
        {scale = 1.1},
        {scale = 1.0},
        0.1,
        {easing = "ease_in"}
    )
    
    -- Select new item (bouncy growth)
    AnimationEngine.animate(
        {scale = 1.0},
        {scale = 1.1},
        0.3,
        {
            easing = "elastic_out",
            on_update = function(values)
                menu_items[selected_index].scale = values.scale
            end
        }
    )
    
    -- Add color pulse for emphasis
    MathUtils.color_pulse_to(
        menu_items[selected_index],
        255, 200, 100, 255,  -- Gold highlight
        0.5, "ease_in_out",
        nil, 1, true  -- Single cycle, ping-pong
    )
end
🔗 Integration Guide
With AnimationEngine
lua
local AnimationEngine = require("scripts/net-games/animation-engine/animation-engine")
local MathUtils = require("scripts/net-games/animation-engine/math-utils")

-- Custom animation with math effects
function custom_shake_animation(object, intensity, duration)
    return AnimationEngine.animate(
        {x = object.x, y = object.y},
        {x = object.x, y = object.y},  -- Same position (we'll override)
        duration,
        {
            easing = "linear",
            on_update = function(values, t)
                -- Override with shake effect
                local shake_x, shake_y = MathUtils.calculate_shake_offset(
                    t * duration, 15, intensity, 1 - t
                )
                object.x = values.x + shake_x
                object.y = values.y + shake_y
            end
        }
    )
end
With AnimationSequences
lua
local AnimationSequences = require("scripts/net-games/animation-engine/animation-sequences")

-- Enhanced summon with math utilities
function enhanced_summon(object, start_pos, end_pos)
    local arc_height = MathUtils.distance(
        start_pos.x, start_pos.y,
        end_pos.x, end_pos.y
    ) * 0.3  -- Dynamic arc based on distance
    
    return AnimationSequences.summon(
        object,
        start_pos.x, start_pos.y, 0.5,
        end_pos.x, end_pos.y, 1.0,
        {
            arc_height = arc_height,
            wobble_deg = MathUtils.random_int(5, 15),
            easing = "elastic_out"
        }
    )
end
Standalone Usage
lua
-- You can use MathUtils independently
function calculate_trajectory(start_x, start_y, target_x, target_y, speed)
    local angle = MathUtils.angle_between(start_x, start_y, target_x, target_y)
    local velocity_x = math.cos(angle) * speed
    local velocity_y = math.sin(angle) * speed
    
    return velocity_x, velocity_y
end
⚡ Performance Tips
Optimization Strategies
Technique	Implementation	Benefit
Local caching	local lerp = MathUtils.lerp	Reduces table lookups
Avoid sqrt	Use distance_squared() for comparisons	2-3x faster than distance()
Pre-calculation	Compute control points once, not per frame	Reduces repetitive math
Easing lookup	Cache easing function if used repeatedly	Faster than string lookup each time
Code Examples
lua
-- OPTIMIZED: Local function references
local lerp = MathUtils.lerp
local ease = MathUtils.ease
local distance_sq = MathUtils.distance_squared

function optimized_update(dt)
    -- Fast distance check (no sqrt)
    if distance_sq(obj1.x, obj1.y, obj2.x, obj2.y) < 100*100 then
        -- Objects are within 100 units
    end
    
    -- Fast interpolation with cached function
    obj.x = lerp(obj.x, target_x, dt * speed)
end

-- UNOPTIMIZED: Repeated table lookups
function slow_update(dt)
    if MathUtils.distance(obj1.x, obj1.y, obj2.x, obj2.y) < 100 then
        -- Slow due to sqrt and table lookup
    end
    
    obj.x = MathUtils.lerp(obj.x, target_x, dt * speed)
end
🎯 Use Case Matrix
Scenario	Recommended Functions	Visual Result	Code Pattern
UI Button Press	ease_out, lerp, calculate_pulse	Smooth depression with subtle bounce	ease_out for press, small elastic_out release
Menu Transitions	ease_in_out, quadratic_bezier	Elegant slide with slight arc	Bezier for path, ease_in_out for timing
Damage Feedback	calculate_shake_offset, interpolate_color	Screen shake + red flash	High-frequency shake with red-to-white color
Victory Celebration	bounce_out, elastic_out, random_*	Bouncing, springy effects with randomness	Multiple bounces with random delays
Loading Indicators	calculate_pulse, lerp	Pulsing dots or growing bar	Sequential pulses with ease_in_out
Card/Deck Games	quadratic_bezier, ease_out, random_sign	Natural arc movement with slight rotation	Bezier arc with random_sign for rotation variance
Particle Systems	random_float, lerp, angle_between	Organic, natural-looking particle movement	Random initial velocity with smooth interpolation
Camera Movement	map, lerp, ease_out, distance	Smooth following with edge resistance	ease_out for smooth stop, map for bounds
Health/Resource Bars	lerp, interpolate_color, calculate_pulse	Smooth depletion with color change and critical pulse	Color interpolation based on value, pulse when low
Tooltips/Hints	ease_out, lerp, calculate_pulse	Smooth fade and slide with attention pulse	Quick ease_out for in, slower for out with pulse
🔧 Troubleshooting
Common Issues and Solutions
Problem	Possible Cause	Solution
Animation feels mechanical/jerky	Using linear easing	Try ease_in_out or smoothstep
Performance drops with many objects	Calling distance() in loops	Use distance_squared() for comparisons
Animations speed up/slow down inconsistently	Not using delta time (dt)	Multiply progress by dt for frame-rate independence
Color transitions look wrong/washed out	Colors outside 0-255 range	Use clamp01() or ensure colors are in valid range
Bezier curves look wrong	Control points in wrong order	Remember: start → control → end for quadratic
Screen shake doesn't decay	Forgetting decay parameter	Add decay: 1 - (elapsed / total_time)
Randomness seems patterned	Not seeding random generator	Call math.randomseed(os.time()) at start
Debugging Example
lua
function debug_animation(animation_id, object)
    -- Add debug callback to monitor animation
    AnimationEngine.animate(
        object.start_values,
        object.target_values,
        object.duration,
        {
            easing = object.easing,
            on_update = function(values, t)
                print(string.format(
                    "Anim %s: t=%.2f, x=%.1f, y=%.1f",
                    animation_id, t, values.x or 0, values.y or 0
                ))
                object.x = values.x
                object.y = values.y
            end
        }
    )
end
🚀 Extension and Customization
Adding Custom Easing Functions
lua
-- Add custom easing to MathUtils
MathUtils.easing_functions.double_bounce = function(t)
    -- Custom double bounce effect
    if t < 0.5 then
        return MathUtils.easing_functions.bounce_out(t * 2) * 0.5
    else
        return 0.5 + MathUtils.easing_functions.bounce_out((t - 0.5) * 2) * 0.5
    end
end

-- Use your custom easing
local value = MathUtils.ease(0.3, "double_bounce")
Creating Utility Wrappers
lua
-- Create game-specific math utilities
local GameMath = {}

function GameMath.screen_percentage_to_pixels(percent_x, percent_y)
    return MathUtils.map(percent_x, 0, 1, 0, screen_width),
           MathUtils.map(percent_y, 0, 1, 0, screen_height)
end

function GameMath.oscillate(time, speed, min, max)
    local t = (math.sin(time * speed * math.pi * 2) + 1) / 2
    return MathUtils.lerp(min, max, t)
end

return GameMath
📚 Quick Reference Card
Most Frequently Used Functions
lua
-- 1. Basic movement
position = MathUtils.lerp(start, target, progress)

-- 2. Smooth timing
progress = MathUtils.ease(raw_progress, "ease_in_out")

-- 3. Distance check (fast)
if MathUtils.distance_squared(x1, y1, x2, y2) < range*range then
    -- In range
end

-- 4. Screen shake
shake_x, shake_y = MathUtils.calculate_shake_offset(time, 15, 3.0, decay)

-- 5. Color transition
r, g, b = MathUtils.interpolate_color(r1, g1, b1, r2, g2, b2, t, "ease_out")

-- 6. Random element
random_item = MathUtils.random_element(item_list)
Cheat Sheet: Easing Selection
Want this effect...	Use this easing
Natural, smooth motion	ease_in_out
Playful, bouncy effect	elastic_out or bounce_out
Dramatic entrance	back_in
Quick response	ease_out
Slow buildup	ease_in
Mechanical precision	linear
Premium feel	smoothstep or smootherstep
📞 Support and Resources
Getting Help
Check the examples section in each function's documentation

Use the debug functions to visualize easing curves

Start with ease_in_out for most animations - it's the most universally pleasing

Next Steps
Experiment with different easing functions on simple objects

Combine multiple effects (easing + shake + color)

Profile performance if using with hundreds of objects

Extend with your own game-specific math utilities

*Last Updated: v1.0.0 | Compatible with AnimationEngine v2.0+*