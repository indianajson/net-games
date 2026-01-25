AnimationSequences Documentation
📋 Overview
AnimationSequences is a Lua library providing pre-built animation sequences for game objects, compatible with any sprite ID and object properties. It uses an underlying AnimationEngine for execution.

🎬 Core Animation Sequences
```lua
1. Summon Animation
Creates a flying arc animation with scale pulse and wobble.

AnimationSequences.summon(object, start_x, start_y, start_scale, end_x, end_y, end_scale, options)
Property	Type	Required	Description
object	Table	✅	Target object
start_x, start_y	Number	✅	Starting position
start_scale	Number	✅	Starting scale
end_x, end_y	Number	✅	Ending position
end_scale	Number	✅	Ending scale
Options Table (options):

{
    duration = 0.25,            -- Animation duration (seconds)
    arc_height = 24,            -- Arc height in pixels
    peak_scale_mul = 1.35,      -- Peak scale multiplier
    wobble_deg = 5,             -- Rotation wobble in degrees
    easing = "ease_in_out",     -- Easing function
    on_complete = function(),   -- Completion callback
    on_update = function()      -- Per-frame callback
}
```

```lua
2. Set Animation
Animation with flip and rotation effects

for setting objects.AnimationSequences.set(object, start_x, start_y, start_scale, start_rotation, end_x, end_y, end_scale, end_rotation, options)
Property	Type	Required	Description
object	Table	✅	Target object
start_x, start_y	Number	✅	Starting position
start_scale, start_rotation	Number	✅	Starting transform
end_x, end_y	Number	✅	Ending position
end_scale, end_rotation	Number	✅	Ending transform
Options Table:

{
    duration = 0.18,            -- Animation duration
    peak_scale_mul = 1.15,      -- Peak scale multiplier
    flip_min = 0.06,            -- Minimum flip scale
    swap_t = 0.5,               -- Swap timing (0-1)
    easing = "ease_in_out",     -- Easing function
    on_complete = function(),   -- Completion callback
    on_update = function()      -- Per-frame callback
}
```

```lua
3. Position Change Animation
Rotates and reveals an object with scale pulse.

AnimationSequences.positionChange(object, start_rotation, end_rotation, options)
Property	Type	Required	Description
object	Table	✅	Target object
start_rotation	Number	✅	Starting rotation (degrees)
end_rotation	Number	✅	Ending rotation (degrees)
Options Table:

{
    duration = 0.18,            -- Animation duration
    peak_scale_mul = 1.15,      -- Peak scale multiplier
    easing = "ease_in_out",     -- Easing function
    on_complete = function(),   -- Completion callback
    on_update = function()      -- Per-frame callback
}
```

```lua
4. Attack Animation
Recoil and lunge animation for attack effects.

AnimationSequences.attack(object, recoil_offset, lunge_offset, options)
Property	Type	Required	Description
object	Table	✅	Target object
recoil_offset	Number	✅	Recoil distance (pixels)
lunge_offset	Number	✅	Lunge distance (pixels)
Options Table:

{
    duration = 0.22,            -- Total animation duration
    t1 = 0.25,                  -- Recoil end timing (0-1)
    t2 = 0.60,                  -- Lunge end timing (0-1)
    easing = "ease_in_out",     -- Easing function
    on_complete = function(),   -- Completion callback
    on_update = function()      -- Per-frame callback
}
```

```lua
5. Slide Animation
Slides an object from one position to another.

AnimationSequences.slideIn(object, start_x, start_y, end_x, end_y, options)
Property	Type	Required	Description
object	Table	✅	Target object
start_x, start_y	Number	✅	Starting position
end_x, end_y	Number	✅	Ending position
Options Table:

{
    duration = 0.15,            -- Animation duration
    easing = "ease_out",        -- Easing function
    on_complete = function(),   -- Completion callback
    on_update = function()      -- Per-frame callback
}
```

```lua
6. Bob Animation
Up and down floating movement.

AnimationSequences.bob(object, options)
Property	Type	Required	Description
object	Table	✅	Target object
Options Table:

{
    duration = 1.0,             -- Animation duration
    distance = 3,               -- Bob distance (pixels)
    easing = "smoothstep",      -- Easing function
    loop = true,                -- Whether to loop
    ping_pong = true,           -- Whether to ping-pong
    on_update = function()      -- Per-frame callback
}
```

```lua
7. Pulse Animation
Scale and alpha pulsing effect.

AnimationSequences.pulse(object, options)
Property	Type	Required	Description
object	Table	✅	Target object
Options Table:

{
    duration = 0.8,             -- Animation duration
    scale_from = 1.0,           -- Starting scale
    scale_to = 1.1,             -- Target scale
    alpha_from = 255,           -- Starting alpha (0-255)
    alpha_to = 200,             -- Target alpha (0-255)
    easing = "elastic_out",     -- Easing function
    loop = true,                -- Whether to loop
    ping_pong = true,           -- Whether to ping-pong
    on_update = function()      -- Per-frame callback
}
```

```lua
8. Color Pulse Animation
Transitions between two color sets.

AnimationSequences.color_pulse(object, start_color, target_color, options)
Property	Type	Required	Description
object	Table	✅	Target object
start_color	Table	✅	{r, g, b, a} values (0-255)
target_color	Table	✅	Target color values
Options Table:

{
    duration = 0.8,             -- Animation duration
    easing = "ease_in_out",     -- Easing function
    loop = true,                -- Whether to loop
    ping_pong = true,           -- Whether to ping-pong
    on_complete = function(),   -- Completion callback
    on_update = function()      -- Per-frame callback
}
Alternative:

AnimationSequences.color_pulse_from_current(object, target_color, options)
Uses object's current color as starting point.
```

```lua
9. Shake Animation
Screen shake effect.

AnimationSequences.shake(object, options)
Property	Type	Required	Description
object	Table	✅	Target object
Options Table:

{
    duration = 0.15,            -- Animation duration
    intensity = 3,              -- Shake intensity (pixels)
    frequency = 15,             -- Shake frequency
    easing = "elastic_out",     -- Easing function
    on_complete = function(),   -- Completion callback
    on_update = function()      -- Per-frame callback
}
10. Fade Animation
Fades an object's alpha.
```

```lua
AnimationSequences.fade(object, target_alpha, options)
Property	Type	Required	Description
object	Table	✅	Target object
target_alpha	Number	✅	Target alpha (0-255)
Options Table:

{
    duration = 0.3,             -- Animation duration
    easing = "ease_in_out",     -- Easing function
    on_complete = function(),   -- Completion callback
    discrete = false,           -- Use discrete animation
    loop = false,               -- Loop control
    ping_pong = false           -- Ping-pong control
}
```

⚙️ Utility Functions
Simple Property Animations:
lua
AnimationSequences.move_to(object, target_x, target_y, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
AnimationSequences.scale_to(object, target_scale, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
AnimationSequences.rotate_to(object, target_angle, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
AnimationSequences.fade_to(object, target_alpha, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
AnimationSequences.tint_to(object, target_r, target_g, target_b, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
Specialized Animations:
lua
AnimationSequences.complexSummon()    -- Multi-step summon with arc, wobble, and settle
AnimationSequences.menuCursor()       -- Combined bob + pulse for menu cursors
AnimationSequences.highlightCard()    -- Lift + glow effect for card highlighting
🎯 Common Object Requirements
All objects passed to AnimationSequences must support at least:

Property/Method	Purpose	Alternative
x, y	Position	setPosition()
scale	Uniform scale	scaleX, scaleY (for set animation)
rotation / angle	Rotation	setRotation()
alpha	Transparency (0-255)	setAlpha()
r, g, b	Color	setColor()
📈 Easing Functions
"ease_in_out" (default)

"ease_out"

"smoothstep"

"elastic_out"

"bounce_out"

Plus any others supported by AnimationEngine

💡 Example Usage
lua
-- Summon a card
AnimationSequences.summon(cardSprite, 
    0, 100, 0.5,   -- Start position/scale
    100, 100, 1.0, -- End position/scale
    {
        duration = 0.3,
        on_complete = function() 
            print("Card summoned!")
        end
    }
)

-- Make object bob up and down
AnimationSequences.bob(menuItem, {
    distance = 3,
    duration = 1.0
})
📝 Notes
All durations are in seconds

Positions are in pixels

Rotations are in degrees

Alpha values range 0-255

Most animations return a sequence ID for animation control

