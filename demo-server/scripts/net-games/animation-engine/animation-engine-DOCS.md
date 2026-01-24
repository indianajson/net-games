AnimationEngine - Comprehensive Documentation
Overview
AnimationEngine is a standalone Lua library for creating smooth animations, interpolations, and effects with various easing functions. It's completely decoupled from any specific rendering system, making it reusable across different projects.

Core Concepts
1. Animation Basics
An animation consists of:

Start values: Initial state

Target values: Desired end state

Duration: Time to complete (seconds)

Easing function: How the interpolation progresses over time

2. Easing Functions
Built-in easing modes:

linear: Constant speed

ease_in: Starts slow, accelerates

ease_out: Starts fast, decelerates

ease_in_out: Combines both

smoothstep: Smooth acceleration/deceleration

elastic_in: Elastic bounce at start

elastic_out: Elastic bounce at end

bounce_out: Bouncing effect at end

Installation
lua
-- In your main script:
local AnimationEngine = require("/server/scripts/ezlibs-custom/animation_engine")
Core API Reference
1. Configuration
lua
-- Toggle debug logging
AnimationEngine.set_debug(true)  -- Default: true

-- Add custom easing function
AnimationEngine.add_easing_function("my_easing", function(t)
    return t * t * t  -- Custom cubic easing
end)

-- Set default interpolation speeds (optional)
AnimationEngine.set_interpolation_speeds(
    position_speed,  -- units/sec (default: 10)
    angle_speed,     -- degrees/sec (default: 180)
    color_speed,     -- color/sec (default: 5)
    scale_speed      -- scale/sec (default: 2)
)
2. Basic Animation
AnimationEngine.animate(start_values, target_values, duration, options)
Creates a generic animation.

Parameters:

start_values: Table of starting values {x=0, y=0, scale=1, etc}

target_values: Table of target values

duration: Animation duration in seconds

options: Optional table with:

easing: Easing function name (default: "linear")

on_update: Function called each frame with current values

on_complete: Function called when animation finishes

id: Custom animation ID (auto-generated if not provided)

Returns: Animation ID string

Example:

lua
local animId = AnimationEngine.animate(
    {x=0, y=0, scale=1},          -- Start values
    {x=100, y=50, scale=2},       -- Target values
    2.0,                          -- 2 seconds
    {
        easing = "ease_in_out",
        on_update = function(values)
            -- Update your object here
            myObject.x = values.x
            myObject.y = values.y
            myObject.scale = values.scale
        end,
        on_complete = function()
            print("Animation complete!")
        end
    }
)
3. Convenience Animation Functions
Move Animation
lua
AnimationEngine.move_to(object, target_x, target_y, duration, easing, on_complete)
-- Automatically reads object.x and object.y as start values
-- If object has setPosition(x,y) method, it will be called
-- Otherwise, object.x and object.y will be set directly
Scale Animation
lua
AnimationEngine.scale_to(object, target_scale, duration, easing, on_complete)
Rotation Animation
lua
AnimationEngine.rotate_to(object, target_angle, duration, easing, on_complete)
Fade Animation
lua
AnimationEngine.fade_to(object, target_alpha, duration, easing, on_complete)
-- Alpha range: 0-255 or 0-1 depending on your system
Color Tint Animation
lua
AnimationEngine.tint_to(object, target_r, target_g, target_b, duration, easing, on_complete)
-- Color range: 0-255
4. Pre-built Effects
Pulse Effect
Creates a pulsating scale animation.

lua
AnimationEngine.pulse(object, min_scale, max_scale, duration, loops, on_complete)
-- min_scale: Minimum scale (e.g., 0.8)
-- max_scale: Maximum scale (e.g., 1.2)
-- duration: Time for one complete pulse cycle
-- loops: Number of pulses (nil for infinite)
Shake Effect
Creates a screen shake/vibration effect.

lua
AnimationEngine.shake(object, intensity, duration, frequency, on_complete)
-- intensity: Maximum shake distance in units
-- duration: Total shake time in seconds
-- frequency: Shakes per second
Bounce In Effect
Elastic bounce-in animation for UI elements.

lua
AnimationEngine.bounce_in(object, start_scale, duration, on_complete)
-- start_scale: Starting scale (e.g., 0 for scale from 0 to 1)
5. Animation Sequences
Sequences allow chaining multiple animations and delays.

Creating a Sequence
lua
local sequenceId = AnimationEngine.create_sequence(steps, options)

-- Steps format:
local steps = {
    {
        type = "animate",      -- or "delay" or "callback"
        target = {x=100, y=50},-- Target values (for animate)
        duration = 1.0,        -- Duration in seconds
        easing = "ease_out",   -- Easing function
        on_update = function(values)
            -- Update object each frame
        end
    },
    {
        type = "delay",
        duration = 0.5         -- Wait 0.5 seconds
    },
    {
        type = "callback",
        callback = function()
            -- Execute custom code
        end
    }
}

-- Options:
local options = {
    loop = true,              -- Loop indefinitely
    on_complete = function()  -- Called when sequence ends
        print("Sequence complete!")
    end
}
Starting a Sequence
lua
AnimationEngine.start_sequence(sequenceId)
Advanced Sequence Features
Relative Values:

lua
{
    type = "animate",
    target = {
        x = "current+10",     -- Move 10 units right from current position
        y = "original"        -- Return to original Y position
    },
    duration = 1.0
}
Available value references:

"current": Current value from previous step

"current+10": Current value plus offset

"original": Original value from sequence start

6. Utility Functions
Delay
lua
AnimationEngine.delay(2.0, function()
    print("This runs after 2 seconds")
end)
Stop Animations
lua
-- Stop specific animation
AnimationEngine.stop_animation(animId)

-- Stop specific sequence
AnimationEngine.stop_sequence(sequenceId)

-- Stop all animations
AnimationEngine.clear_all()
Get Statistics
lua
local activeAnimations = AnimationEngine.get_active_count()
local activeSequences = AnimationEngine.get_sequence_count()
7. Integration with Game Loop
lua
-- Call this every frame with delta time
function update(dt)
    AnimationEngine.tick(dt)
end

-- Or hook into your game's tick event:
Net:on("tick", function(event)
    AnimationEngine.tick(event.delta_time)
end)
Complete Examples
Example 1: Basic Object Animation
lua
-- Define an object (could be anything with x,y,scale properties)
local mySprite = {
    x = 100,
    y = 100,
    scale = 1,
    angle = 0,
    alpha = 255,
    r = 255,
    g = 255,
    b = 255
}

-- Move with bounce easing
AnimationEngine.move_to(mySprite, 300, 200, 1.5, "bounce_out", function()
    print("Moved to position!")
end)

-- Fade out
AnimationEngine.fade_to(mySprite, 128, 1.0, "ease_in_out")

-- Complex animation with multiple properties
AnimationEngine.animate(
    {scale=1, angle=0},
    {scale=2, angle=360},
    2.0,
    {
        easing = "ease_in_out",
        on_update = function(values)
            mySprite.scale = values.scale
            mySprite.angle = values.angle
            -- Update your rendering system here
            renderSprite(mySprite)
        end
    }
)
Example 2: Complex Sequence
lua
local uiElement = {x=50, y=50, scale=1, alpha=255}

local seqId = AnimationEngine.create_sequence({
    -- Fade in
    {
        type = "animate",
        start = {alpha=0},
        target = {alpha=255},
        duration = 0.5,
        easing = "ease_out",
        on_update = function(values)
            uiElement.alpha = values.alpha
        end
    },
    
    -- Bounce into position
    {
        type = "animate",
        target = {x=200, scale=1.2},
        duration = 0.8,
        easing = "elastic_out"
    },
    {
        type = "animate",
        target = {scale=1.0},
        duration = 0.3,
        easing = "bounce_out"
    },
    
    -- Wait a moment
    {
        type = "delay",
        duration = 1.0
    },
    
    -- Shake for attention
    {
        type = "callback",
        callback = function()
            AnimationEngine.shake(uiElement, 5, 0.5, 10)
        end
    },
    
    -- Pulse continuously
    {
        type = "callback",
        callback = function()
            AnimationEngine.pulse(uiElement, 0.95, 1.05, 1.0)
        end
    }
}, {
    on_complete = function()
        print("UI element fully animated!")
    end
})

AnimationEngine.start_sequence(seqId)
Example 3: Sprite Integration
lua
-- Integration with a sprite system
local function animateSprite(sprite, params)
    -- params: {x, y, scale, rotation, alpha, r, g, b, duration, easing}
    
    local animValues = {}
    for key, value in pairs(params) do
        if key ~= "duration" and key ~= "easing" and key ~= "on_complete" then
            animValues[key] = value
        end
    end
    
    -- Get current values from sprite
    local currentValues = {
        x = sprite:getX(),
        y = sprite:getY(),
        scale = sprite:getScale(),
        rotation = sprite:getRotation(),
        alpha = sprite:getAlpha(),
        r = sprite:getRed(),
        g = sprite:getGreen(),
        b = sprite:getBlue()
    }
    
    return AnimationEngine.animate(
        currentValues,
        animValues,
        params.duration or 0.5,
        {
            easing = params.easing or "linear",
            on_update = function(values)
                sprite:setPosition(values.x, values.y)
                sprite:setScale(values.scale)
                sprite:setRotation(values.rotation)
                sprite:setAlpha(values.alpha)
                sprite:setColor(values.r, values.g, values.b)
            end,
            on_complete = params.on_complete
        }
    )
end
Best Practices
Always clean up: Use AnimationEngine.clear_all() when switching scenes/levels

Use appropriate easing:

UI elements: ease_out or bounce_out

Physical objects: linear or ease_in_out

Attention effects: elastic or bounce

Keep durations reasonable:

UI animations: 0.2-0.5 seconds

Transitions: 0.5-1.5 seconds

Special effects: Varies based on effect

Chain with sequences: For complex animations instead of nested callbacks

Test performance: Monitor with get_active_count() if animating many objects

Troubleshooting
Problem: Animations don't run
Solution: Ensure AnimationEngine.tick(dt) is called every frame

Problem: Memory leak
Solution: Call AnimationEngine.clear_all() when objects are destroyed

Problem: Animations are jumpy
Solution: Ensure consistent delta time in tick() calls

Problem: Object properties not updating
Solution: Check that on_update callback correctly sets object properties

Advanced Usage
Custom Interpolation
lua
-- Manual interpolation between any values
local currentScale = AnimationEngine.interpolate(
    1.0,      -- Start
    2.0,      -- Target
    0.5,      -- t (0-1)
    "ease_in" -- Easing
)

-- Table interpolation
local pos = AnimationEngine.interpolate(
    {x=0, y=0},
    {x=100, y=50},
    0.5,
    "ease_out"
)
Creating Composite Effects
lua
function flashEffect(object, duration)
    local originalAlpha = object.alpha or 255
    local sequence = {
        {type="animate", target={alpha=0}, duration=duration/4, easing="linear"},
        {type="animate", target={alpha=originalAlpha}, duration=duration/4, easing="linear"},
        {type="animate", target={alpha=0}, duration=duration/4, easing="linear"},
        {type="animate", target={alpha=originalAlpha}, duration=duration/4, easing="linear"}
    }
    return AnimationEngine.create_sequence(sequence)
end

This documentation covers all major aspects of the AnimationEngine. The library is flexible and can be adapted to any object system that needs smooth animations and transitions.