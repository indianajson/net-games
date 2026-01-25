Animation Sequences Documentation
Overview
animation-sequences.lua provides a comprehensive library of pre-built animation effects designed to be easily used with any game object. Each function is designed to work with generic objects that have numeric properties (x, y, scale, rotation, alpha, r, g, b).

Table of Contents
Basic Animations

Complex Effects

Utility Functions

Color Animations

Sequence-Based Animations

Pre-built Compositions

Basic Animations
These are simple, single-property animations with optional looping and ping-pong support.

move_to
Animates an object's position from its current location to a target position.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate (must have x and y properties or setPosition method)
target_x	number	Required	Target X coordinate
target_y	number	Required	Target Y coordinate
duration	number	config.default_duration (0.25)	Animation duration in seconds
easing	string	config.default_easing ("ease_in_out")	Easing function name
on_complete	function	nil	Callback when animation completes
loop	boolean/number	false	true for infinite loop, false for no loop, number for specific loop count
ping_pong	boolean	false	If true, alternates between start and target positions
easing_back	string	easing	Easing function for return trip (if ping-pong)
discrete	table	nil	Array of property keys that should change instantly
Usage:

lua
-- Move to position (200, 300) over 0.5 seconds
AnimationSequences.move_to(sprite, 200, 300, 0.5, "ease_out", 
  function() print("Move complete!") end)

-- Ping-pong movement
AnimationSequences.move_to(sprite, 200, 300, 1.0, "ease_in_out", 
  nil, true, true)
scale_to
Animates an object's scale from its current scale to a target scale.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate (must have scale property or setScale method)
target_scale	number	Required	Target scale value (1.0 = normal size)
duration	number	config.default_duration	Animation duration in seconds
easing	string	config.default_easing	Easing function name
on_complete	function	nil	Callback when animation completes
loop	boolean/number	false	Looping behavior
ping_pong	boolean	false	If true, alternates between start and target scales
easing_back	string	easing	Easing function for return trip
discrete	table	nil	Discrete property keys
Usage:

lua
-- Scale up to 150%
AnimationSequences.scale_to(sprite, 1.5, 0.3, "elastic_out")

-- Pulsing scale effect
AnimationSequences.scale_to(sprite, 1.2, 0.8, "ease_in_out", 
  nil, true, true)
rotate_to
Animates an object's rotation from its current angle to a target angle.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate (must have angle or rotation property or setRotation method)
target_angle	number	Required	Target rotation in degrees
duration	number	config.default_duration	Animation duration in seconds
easing	string	config.default_easing	Easing function name
on_complete	function	nil	Callback when animation completes
loop	boolean/number	false	Looping behavior
ping_pong	boolean	false	If true, alternates between start and target angles
easing_back	string	easing	Easing function for return trip
discrete	table	nil	Discrete property keys
Usage:

lua
-- Rotate 180 degrees
AnimationSequences.rotate_to(sprite, 180, 0.5, "ease_in_out")

-- Continuous spinning
AnimationSequences.rotate_to(sprite, 360, 2.0, "linear", 
  nil, true, false)
fade_to
Animates an object's alpha/opacity from its current value to a target value.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate (must have alpha property or setAlpha method)
target_alpha	number	Required	Target alpha value (0-255)
duration	number	config.default_duration	Animation duration in seconds
easing	string	config.default_easing	Easing function name
on_complete	function	nil	Callback when animation completes
loop	boolean/number	false	Looping behavior
ping_pong	boolean	false	If true, alternates between start and target alpha
easing_back	string	easing	Easing function for return trip
discrete	table	nil	Discrete property keys
Usage:

lua
-- Fade out
AnimationSequences.fade_to(sprite, 0, 0.5, "ease_out")

-- Fade in
AnimationSequences.fade_to(sprite, 255, 0.5, "ease_in")

-- Blinking effect
AnimationSequences.fade_to(sprite, 100, 0.5, "ease_in_out", 
  nil, true, true)
tint_to
Animates an object's RGB color from its current color to a target color.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate (must have r, g, b properties or setColor method)
target_r	number	Required	Target red value (0-255)
target_g	number	Required	Target green value (0-255)
target_b	number	Required	Target blue value (0-255)
duration	number	config.default_duration	Animation duration in seconds
easing	string	config.default_easing	Easing function name
on_complete	function	nil	Callback when animation completes
loop	boolean/number	false	Looping behavior
ping_pong	boolean	false	If true, alternates between start and target colors
easing_back	string	easing	Easing function for return trip
discrete	table	nil	Discrete property keys
Usage:

lua
-- Turn red
AnimationSequences.tint_to(sprite, 255, 0, 0, 0.3, "ease_out")

-- Color cycling
AnimationSequences.tint_to(sprite, 0, 255, 0, 1.0, "ease_in_out",
  nil, true, true)
Complex Effects
These are multi-property animations that create specific visual effects.

summon
Creates a summoning animation with arc movement, scale pulsing, and optional rotation wobble.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
start_x	number	Required	Starting X position
start_y	number	Required	Starting Y position
start_scale	number	Required	Starting scale
end_x	number	Required	Target X position
end_y	number	Required	Target Y position
end_scale	number	Required	Target scale
options	table	{}	Configuration options (see below)
Options Table:

Option	Type	Default	Description
duration	number	config.summon.duration (0.25)	Total animation duration
arc_height	number	config.summon.arc_height (24)	Height of the arc trajectory
peak_scale_mul	number	config.summon.peak_scale_mul (1.35)	Peak scale multiplier (1.0 = no pulse)
wobble_deg	number	config.summon.wobble_ro_deg (5)	Rotation wobble in degrees (0 = no wobble)
easing	string	config.default_easing	Easing function for the movement
on_complete	function	nil	Callback when animation completes
on_update	function	nil	Callback for each frame with progress data
Usage:

lua
-- Basic summon from top-left to center
AnimationSequences.summon(card,
  0, 0, 0.5,    -- Start: x, y, scale
  100, 100, 1.0, -- End: x, y, scale
  {
    arc_height = 40,
    peak_scale_mul = 1.5,
    wobble_deg = 10,
    duration = 0.3,
    on_complete = function() 
      print("Card summoned!")
    end
  }
)
set
Creates a "set" animation similar to placing a card on a table, with flip and rotation effects.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
start_x	number	Required	Starting X position
start_y	number	Required	Starting Y position
start_scale	number	Required	Starting scale
start_rotation	number	Required	Starting rotation in degrees
end_x	number	Required	Target X position
end_y	number	Required	Target Y position
end_scale	number	Required	Target scale
end_rotation	number	Required	Target rotation in degrees
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.position_change.duration (0.18)	Total animation duration
peak_scale_mul	number	config.position_change.peak_scale_mul (1.15)	Peak scale multiplier
flip_min	number	config.position_change.flip_min (0.06)	Minimum X scale during flip (creates squash effect)
swap_t	number	config.position_change.swap_t (0.5)	When to swap appearance (0-1)
easing	string	config.default_easing	Easing function
on_complete	function	nil	Completion callback
on_update	function	nil	Per-frame callback
Usage:

lua
-- Set a card with rotation
AnimationSequences.set(card,
  50, 100, 0.8, 0,     -- Start: x, y, scale, rotation
  150, 100, 1.0, 180,  -- End: x, y, scale, rotation
  {
    duration = 0.25,
    peak_scale_mul = 1.25,
    on_complete = function()
      print("Card set!")
    end
  }
)
positionChange
Animates a rotation change with scale pulsing (for card flipping or revealing).

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
start_rotation	number	Required	Starting rotation in degrees
end_rotation	number	Required	Target rotation in degrees
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.position_change.duration (0.18)	Animation duration
peak_scale_mul	number	config.position_change.peak_scale_mul (1.15)	Peak scale multiplier
easing	string	config.default_easing	Easing function
on_complete	function	nil	Completion callback
on_update	function	nil	Per-frame callback
Usage:

lua
-- Flip a card over
AnimationSequences.positionChange(card,
  0,    -- Start rotation (face up)
  180,  -- End rotation (face down)
  {
    duration = 0.2,
    peak_scale_mul = 1.2,
    easing = "ease_in_out",
    on_complete = function()
      print("Card flipped!")
    end
  }
)
attack
Creates a three-phase attack animation: recoil → lunge → return.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
recoil_offset	number	Required	Recoil distance (positive = up, negative = down)
lunge_offset	number	Required	Lunge distance (positive = down, negative = up)
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.attack.duration (0.22)	Total animation duration
t1	number	config.attack.t1 (0.25)	Time when recoil ends (0-1)
t2	number	config.attack.t2 (0.60)	Time when lunge ends (0-1)
easing	string	config.default_easing	Easing function
on_complete	function	nil	Completion callback
on_update	function	nil	Per-frame callback
Usage:

lua
-- Attack animation moving downward
AnimationSequences.attack(monster,
  -10,  -- Recoil up 10 pixels
  20,   -- Lunge down 20 pixels
  {
    duration = 0.3,
    t1 = 0.2,
    t2 = 0.7,
    on_complete = function()
      print("Attack completed!")
    end
  }
)
slideIn
Slides an object from an offscreen position to a target position.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
start_x	number	Required	Starting X position (off-screen)
start_y	number	Required	Starting Y position
end_x	number	Required	Target X position
end_y	number	Required	Target Y position
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.slide.duration (0.15)	Animation duration
easing	string	config.slide.easing ("ease_out")	Easing function
on_complete	function	nil	Completion callback
on_update	function	nil	Per-frame callback
Usage:

lua
-- Slide from left side
AnimationSequences.slideIn(menuPanel,
  -200, 100,  -- Start off-screen left
  100, 100,   -- End on-screen
  {
    duration = 0.2,
    easing = "ease_out",
    on_complete = function()
      print("Menu opened!")
    end
  }
)
Utility Functions
bob
Creates a smooth up-and-down bobbing motion (great for idle animations).

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.bob.duration (1.0)	Duration of one bobbing cycle
distance	number	config.bob.distance (3)	Vertical distance to bob
easing	string	config.bob.easing ("smoothstep")	Easing function
loop	boolean	config.bob.loop (true)	Whether to loop continuously
ping_pong	boolean	config.bob.ping_pong (true)	Whether to reverse direction at ends
on_update	function	nil	Per-frame callback
Usage:

lua
-- Create a bobbing effect
AnimationSequences.bob(floatingItem, {
  distance = 5,
  duration = 1.5,
  easing = "ease_in_out"
})

-- Stop the bob animation later
AnimationEngine.stop_animation(bobId)
pulse
Creates a pulsing effect that scales and fades an object.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.pulse.duration (0.8)	Duration of one pulse cycle
scale_from	number	config.pulse.scale_from (1.0)	Starting scale
scale_to	number	config.pulse.scale_to (1.1)	Target scale
alpha_from	number	config.pulse.alpha_from (255)	Starting alpha
alpha_to	number	config.pulse.alpha_to (200)	Target alpha
easing	string	config.pulse.easing ("elastic_out")	Easing function
loop	boolean	config.pulse.loop (true)	Whether to loop continuously
ping_pong	boolean	config.pulse.ping_pong (true)	Whether to reverse direction at ends
on_update	function	nil	Per-frame callback
Usage:

lua
-- Create a pulsing highlight effect
AnimationSequences.pulse(selectedItem, {
  scale_to = 1.2,
  alpha_to = 180,
  duration = 0.6,
  easing = "ease_in_out"
})

-- Single pulse (not looping)
AnimationSequences.pulse(notification, {
  scale_to = 1.3,
  alpha_to = 150,
  duration = 0.4,
  loop = 1,  -- Single cycle
  ping_pong = true,
  on_complete = function()
    print("Pulse complete!")
  end
})
shake
Creates a screen shake or object shake effect.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to shake
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.shake.duration (0.15)	Shake duration
intensity	number	config.shake.intensity (3)	Maximum shake distance in pixels
frequency	number	config.shake.frequency (15)	Shake frequency (higher = faster shakes)
easing	string	config.shake.easing ("elastic_out")	Easing function for intensity decay
on_complete	function	nil	Completion callback
on_update	function	nil	Per-frame callback
Usage:

lua
-- Screen shake on impact
AnimationSequences.shake(camera, {
  intensity = 10,
  duration = 0.3,
  frequency = 20,
  on_complete = function()
    print("Shake complete!")
  end
})

-- Object shake (like a hit effect)
AnimationSequences.shake(enemy, {
  intensity = 5,
  duration = 0.2,
  frequency = 25
})
fade
Fades an object's alpha to a target value (simpler alternative to fade_to).

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
target_alpha	number	Required	Target alpha value (0-255)
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.fade.duration (0.3)	Fade duration
easing	string	config.fade.easing ("ease_in_out")	Easing function
on_complete	function	nil	Completion callback
discrete	table	nil	Discrete property keys
loop	boolean/number	false	Looping behavior
ping_pong	boolean	false	Ping-pong behavior
easing_back	string	easing	Easing for return trip
Usage:

lua
-- Fade out
AnimationSequences.fade(sprite, 0, {
  duration = 0.5,
  easing = "ease_out",
  on_complete = function()
    sprite.visible = false
  end
})

-- Fade in
AnimationSequences.fade(sprite, 255, {
  duration = 0.5,
  easing = "ease_in"
})
tint
Tints an object to a target RGB color (simpler alternative to tint_to).

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
target_r	number	Required	Target red value
target_g	number	Required	Target green value
target_b	number	Required	Target blue value
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
duration	number	config.default_duration (0.25)	Animation duration
easing	string	config.default_easing ("ease_in_out")	Easing function
on_complete	function	nil	Completion callback
discrete	table	nil	Discrete property keys
loop	boolean/number	false	Looping behavior
ping_pong	boolean	false	Ping-pong behavior
easing_back	string	easing	Easing for return trip
Usage:

lua
-- Flash red when hit
AnimationSequences.tint(sprite, 255, 100, 100, {
  duration = 0.15,
  easing = "ease_out",
  loop = 1,  -- Single cycle
  ping_pong = true
})

-- Permanently tint green
AnimationSequences.tint(sprite, 100, 255, 100, {
  duration = 0.3,
  easing = "ease_in_out"
})
Color Animations
color_pulse
Creates a color pulsing effect between two color sets (with full RGBA support).

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
start_color	table	Required	Starting color table
target_color	table	Required	Target color table
options	table	{}	Configuration options
Color Table Format:

lua
{
  r = 255,    -- Red (0-255)
  g = 255,    -- Green (0-255)
  b = 255,    -- Blue (0-255)
  a = 255     -- Alpha (0-255, optional)
}

-- OR using array format:
{255, 255, 255, 255}  -- r, g, b, a
Options Table:

Option	Type	Default	Description
duration	number	config.color_pulse.duration (0.8)	Duration of one color cycle
easing	string	config.color_pulse.easing ("ease_in_out")	Easing function
loop	boolean	config.color_pulse.loop (true)	Whether to loop continuously
ping_pong	boolean	config.color_pulse.ping_pong (true)	Whether to reverse direction at ends
on_complete	function	nil	Completion callback
on_update	function	nil	Per-frame callback
easing_back	string	easing	Easing for return trip
Usage:

lua
-- Pulse between blue and red
AnimationSequences.color_pulse(sprite,
  {r = 100, g = 100, b = 255, a = 255},  -- Start: blue
  {r = 255, g = 100, b = 100, a = 200},  -- Target: semi-transparent red
  {
    duration = 1.0,
    easing = "ease_in_out",
    loop = true,
    ping_pong = true,
    on_complete = function()
      print("Color pulse ended!")
    end
  }
)

-- Using array format
AnimationSequences.color_pulse(sprite,
  {0, 255, 0, 255},    -- Green
  {255, 255, 0, 200},  -- Yellow
  {duration = 0.8}
)
color_pulse_from_current
Same as color_pulse but uses the object's current color as the starting point.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
target_color	table	Required	Target color table
options	table	{}	Configuration options
Usage:

lua
-- Pulse from current color to red
AnimationSequences.color_pulse_from_current(sprite,
  {r = 255, g = 50, b = 50, a = 255},
  {
    duration = 0.5,
    loop = 1,  -- Single cycle
    ping_pong = true
  }
)
color_pulse_to
Convenience wrapper for color_pulse that accepts individual RGB(A) parameters.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
target_r	number	Required	Target red value
target_g	number	Required	Target green value
target_b	number	Required	Target blue value
target_a	number	current alpha	Target alpha value
duration	number	0.8	Duration of one color cycle
easing	string	"ease_in_out"	Easing function
on_complete	function	nil	Completion callback
loop	boolean	true	Whether to loop continuously
ping_pong	boolean	true	Whether to reverse direction at ends
easing_back	string	easing	Easing for return trip
discrete	table	nil	Discrete property keys
Usage:

lua
-- Pulse to red with lower alpha
AnimationSequences.color_pulse_to(sprite,
  255, 0, 0, 200,  -- r, g, b, a
  0.8, "elastic_in_out",
  function() print("Pulse complete!") end
)

-- Single red flash
AnimationSequences.color_pulse_to(sprite,
  255, 0, 0, 255,
  0.3, "ease_out",
  nil, 1, true  -- loop = 1 (single cycle), ping_pong = true
)
Sequence-Based Animations
These animations use the AnimationEngine's sequence system to chain multiple effects together.

complexSummon
A multi-step summon animation with arc movement, scale pulse, rotation wobble, and settling effect.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
start_x	number	Required	Starting X position
start_y	number	Required	Starting Y position
start_scale	number	Required	Starting scale
end_x	number	Required	Target X position
end_y	number	Required	Target Y position
end_scale	number	Required	Target scale
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
arc_height	number	24	Height of the arc trajectory
arc_duration	number	0.25	Duration of arc movement phase
peak_scale_mul	number	1.35	Peak scale multiplier during pulse
wobble_deg	number	nil	Rotation wobble in degrees (if nil, no wobble)
wobble_duration	number	0.1	Duration of wobble phase
settle_duration	number	0.05	Duration of settling phase
easing	string	"ease_in_out"	Easing function for main movement
on_complete	function	nil	Callback when entire sequence completes
on_update_step1	function	nil	Callback for arc movement phase
on_update_step2	function	nil	Callback for wobble phase
on_update_step3	function	nil	Callback for settle phase
Usage:

lua
-- Complex summon with all effects
AnimationSequences.complexSummon(card,
  50, -50, 0.3,   -- Start above screen
  100, 100, 1.0,  -- End position
  {
    arc_height = 40,
    wobble_deg = 15,
    arc_duration = 0.3,
    wobble_duration = 0.15,
    settle_duration = 0.08,
    on_update_step1 = function(data)
      print("Arc progress: " .. data.progress)
    end,
    on_complete = function()
      print("Complex summon complete!")
    end
  }
)
Pre-built Compositions
These are ready-to-use animation combinations for common UI/game scenarios.

menuCursor
Creates a combined bob + pulse animation for menu cursor highlighting.

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
bob_distance	number	2	Vertical bobbing distance
pulse_scale	number	1.1	Scale pulse target
duration	number	0.8	Base duration for both animations
Returns:

A table with two animation IDs: {bob = bobId, pulse = pulseId}

Usage:

lua
-- Create menu cursor effect
local cursorAnims = AnimationSequences.menuCursor(menuItem, {
  bob_distance = 3,
  pulse_scale = 1.15,
  duration = 1.0
})

-- Stop both animations later
AnimationEngine.stop_animation(cursorAnims.bob)
AnimationEngine.stop_animation(cursorAnims.pulse)
highlightCard
Lifts and glows a card when highlighted (for hover effects).

Parameters:

Parameter	Type	Default	Description
object	table	Required	The object to animate
options	table	{}	Configuration options
Options Table:

Option	Type	Default	Description
lift_amount	number	5	How many pixels to lift the card
glow_alpha	number	100	Alpha value for glow effect
duration	number	0.15	Animation duration
on_complete	function	nil	Completion callback
Usage:

lua
-- Highlight a card on hover
local highlightId = AnimationSequences.highlightCard(card, {
  lift_amount = 8,
  glow_alpha = 150,
  duration = 0.2,
  on_complete = function()
    print("Card highlighted!")
  end
})

-- Remove highlight (use fade_to or reverse the values)
Object Property Requirements
For any object to work with AnimationSequences, it needs to support property access or setter methods:

Required Properties/Methods by Animation Type:
Animation	Required Properties	Optional Methods
Position animations	x, y	setPosition(x, y)
Scale animations	scale	setScale(value)
Rotation animations	angle or rotation	setRotation(value)
Alpha animations	alpha	setAlpha(value)
Color animations	r, g, b	setColor(r, g, b)
Example Object Structures:
lua
-- Simple table object
local simpleSprite = {
    x = 100,
    y = 100,
    scale = 1.0,
    rotation = 0,
    alpha = 255,
    r = 255,
    g = 255,
    b = 255
}

-- Object with setter methods
local advancedSprite = {
    x = 100,
    y = 100,
    scale = 1.0,
    rotation = 0,
    alpha = 255,
    r = 255,
    g = 255,
    b = 255,
    
    setPosition = function(self, x, y)
        self.x = x
        self.y = y
        -- Update actual display object here
    end,
    
    setScale = function(self, scale)
        self.scale = scale
        -- Update actual display object
    end
}

-- Using with a framework like LÖVE or similar
local frameworkSprite = {
    instance = love.graphics.newImage("sprite.png"),
    x = 100,
    y = 100,
    
    setPosition = function(self, x, y)
        self.x = x
        self.y = y
        -- Framework-specific update
    end
}
Discrete Animations
Some animations support discrete properties that change instantly rather than interpolating:

lua
-- Change visibility instantly, animate position smoothly
AnimationSequences.move_to(sprite, 200, 300, 0.5, "ease_out", nil, false, false, nil, {"visible"})
Common discrete properties:

visible (boolean)

state (string/enum)

frame (integer)

Any property that shouldn't tween between values

Easing Functions Reference
All animations support these easing functions (from animation-enums.lua):

Easing Name	Description	Best For
instant	Immediate change	Instant transitions, discrete properties
linear	Constant speed	Mechanical movements
ease_in	Starts slow, ends fast	Accelerating out of position
ease_out	Starts fast, ends slow	Decelerating into position
ease_in_out	Slow start and end	Smooth, natural movements
smoothstep	Very smooth curve	UI animations, transitions
smootherstep	Even smoother curve	Premium feel animations
elastic_in	Overshoots on start	Bouncy entrances
elastic_out	Overshoots on end	Bouncy exits
bounce_out	Bounces at end	Playful, bouncy effects
bounce_in	Bounces at start	Playful entrances
elastic_in_out	Overshoots both sides	Extreme bounciness
square	Quadratic acceleration	Strong acceleration
cubic	Cubic acceleration	Very strong acceleration
Configuration
You can modify default settings globally:

lua
-- Change default durations and easings
AnimationSequences.config.default_duration = 0.3
AnimationSequences.config.default_easing = "ease_out"

-- Modify specific animation types
AnimationSequences.config.summon.duration = 0.4
AnimationSequences.config.summon.arc_height = 30

AnimationSequences.config.pulse.duration = 1.0
AnimationSequences.config.pulse.scale_to = 1.2
Best Practices
Always stop animations when objects are destroyed or no longer needed:

lua
function onObjectDestroyed(objectId)
    AnimationSequences.stopAll(objectId)
end
Use appropriate durations:

UI animations: 0.1-0.3 seconds

Gameplay animations: 0.2-0.5 seconds

Cinematic animations: 0.5-2.0 seconds

Combine animations for complex effects:

lua
-- Attack with shake and color flash
local attackId = AnimationSequences.attack(enemy, -10, 20)
local shakeId = AnimationSequences.shake(enemy, {intensity = 3})
local flashId = AnimationSequences.tint_to(enemy, 255, 100, 100, 0.2, "ease_out", nil, 1, true)
Use callbacks for game logic:

lua
AnimationSequences.fade_to(sprite, 0, 0.5, "ease_out", function()
    sprite.visible = false
    removeFromGame(sprite)
end)
Test on target hardware - complex sequences with many active animations may impact performance.

This comprehensive animation library provides everything needed for rich, engaging visual feedback in games and applications. Each animation is designed to be flexible, customizable, and easy to integrate into existing codebases.

