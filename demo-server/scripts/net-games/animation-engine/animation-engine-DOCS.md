🎬 Animation Engine Documentation
📋 Table of Contents
🚀 Quick Start

🎯 Core Concepts

✨ Basic Animation

⚙️ Animation Options

🎨 Pre-built Effects

🔀 Discrete Values

🎭 Animation Sequences

🛠️ Utility Functions

⚡ Instant Transitions

📊 Configuration

📈 Easing Functions

🎮 Examples & Use Cases

🚨 Troubleshooting

🚀 Quick Start
Installation & Setup
lua
-- Load the animation engine
local AnimationEngine = require("/server/scripts/ezlibs-custom/animation_engine")

-- The engine automatically sets up in your game loop via Net events
-- For manual control, call tick() in your update function:
function update(dt)
    AnimationEngine.tick(dt)
end
Your First Animation
lua
local mySprite = { x = 100, y = 100 }

AnimationEngine.move_to(
    mySprite,      -- Object to animate
    300, 200,      -- Target position
    1.5,           -- Duration (seconds)
    "ease_out",    -- Easing function
    function()     -- Completion callback
        print("Movement complete!")
    end
)
🎯 Core Concepts
📊 Animation Types
Type	Description	When to Use
Continuous	Smooth interpolation between values	Position, scale, rotation, color
Discrete	Immediate value changes	State changes, flags, modes
Instant	Zero-duration transition	Immediate visual updates
Sequence	Ordered animation chain	Complex multi-step animations
🔄 How It Works
lua
1. Create Animation
   ↓
2. Engine Updates (60 FPS)
   ↓
3. Interpolation Calculations
   ↓
4. Callback Execution
   ↓
5. Cleanup & Completion
✨ Basic Animation
📝 AnimationEngine.animate()
The core animation function for full control.

lua
local animationId = AnimationEngine.animate(
    start_values,    -- Starting property values
    target_values,   -- Target property values
    duration,        -- Animation length in seconds
    options          -- Configuration table (optional)
)
🎯 Example: Multi-property Animation
lua
AnimationEngine.animate(
    {
        x = 0,
        y = 0,
        scale = 1,
        rotation = 0,
        opacity = 1
    },
    {
        x = 300,
        y = 200,
        scale = 2,
        rotation = 360,
        opacity = 0.5
    },
    2.0,  -- 2 seconds
    {
        easing = "ease_in_out",
        on_update = function(values, progress, phase)
            -- Update your object here
            sprite.x = values.x
            sprite.y = values.y
            sprite.scale = values.scale
        end,
        on_complete = function(final_values, was_interrupted)
            if not was_interrupted then
                print("Animation finished successfully!")
            end
        end
    }
)
⚙️ Animation Options
📋 Options Reference Table
Option	Type	Default	Description
easing	string	"linear"	Easing function name
easing_back	string	same as easing	Easing for ping-pong return
on_update	function	nil	Called each frame: (values, progress, phase)
on_complete	function	nil	Called on end: (values, interrupted)
loop	bool/number	false	true=infinite, number=specific count
ping_pong	bool	false	Bounce between start and target
discrete	table	{}	Keys that change immediately
id	string	auto-generated	Custom identifier
max_cycles	number	nil	Maximum loop iterations
🔄 Looping & Ping-Pong Examples
lua
-- Infinite loop
{ loop = true }

-- Loop 3 times
{ loop = 3 }

-- Ping-pong (back and forth)
{ 
    loop = true, 
    ping_pong = true,
    easing = "ease_in_out",
    easing_back = "elastic_out"  -- Different easing for return
}

-- Delayed loop start
AnimationEngine.delay(1.0, function()
    AnimationEngine.animate(..., { loop = true })
end)
🎨 Pre-built Effects
📍 Movement Animations
move_to(object, x, y, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
lua
-- Basic movement
AnimationEngine.move_to(sprite, 500, 300, 1.5, "ease_out")

-- With callbacks
AnimationEngine.move_to(
    player,
    400, 200,
    2.0,
    "elastic_out",
    function() 
        print("Player arrived!")
    end,
    false,  -- loop
    true,   -- ping_pong
    "linear" -- easing_back
)
📏 Scale Animations
scale_to(object, scale, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
lua
-- Pulse effect
AnimationEngine.scale_to(
    button,
    1.2,
    0.3,
    "ease_in_out",
    function()
        AnimationEngine.scale_to(button, 1.0, 0.3, "ease_in_out")
    end
)

-- Continuous breathing effect
AnimationEngine.scale_to(
    creature,
    1.1,
    1.0,
    "ease_in_out",
    nil,
    true,  -- loop
    true   -- ping_pong
)
🔄 Rotation Animations
rotate_to(object, angle, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
lua
-- Continuous spinning
AnimationEngine.rotate_to(
    gear,
    360,  -- Target angle (degrees)
    2.0,  -- Duration
    "linear",
    nil,
    true  -- loop (spins continuously)
)

-- Wobble effect
AnimationEngine.rotate_to(
    jelly,
    15,   -- 15 degrees
    0.5,
    "ease_in_out",
    nil,
    true,
    true   -- ping_pong creates wobble
)
🌫️ Fade Animations
fade_to(object, alpha, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
lua
-- Fade out
AnimationEngine.fade_to(
    dialog,
    0,    -- Target alpha (0=transparent)
    0.5,
    "ease_out",
    function()
        dialog.visible = false
    end
)

-- Fade in
dialog.visible = true
AnimationEngine.fade_to(dialog, 255, 0.5, "ease_in")

-- Blinking effect
AnimationEngine.fade_to(
    warning,
    128,  -- Half opacity
    0.3,
    "linear",
    nil,
    true,
    true   -- ping_pong creates blink
)
🌈 Color Animations
tint_to(object, r, g, b, duration, easing, on_complete, loop, ping_pong, easing_back, discrete)
lua
-- Damage flash (red)
AnimationEngine.tint_to(
    player,
    255, 100, 100,  -- Red tint
    0.1,
    "instant",
    function()
        AnimationEngine.tint_to(player, 255, 255, 255, 0.2, "linear")
    end
)

-- Color cycle
local colors = {
    {255, 200, 200},  -- Light red
    {200, 255, 200},  -- Light green
    {200, 200, 255},  -- Light blue
}
local colorIndex = 1

function cycleColor()
    local color = colors[colorIndex]
    AnimationEngine.tint_to(
        aura,
        color[1], color[2], color[3],
        1.0,
        "ease_in_out",
        function()
            colorIndex = (colorIndex % #colors) + 1
            cycleColor()
        end
    )
end
cycleColor()
🔀 Discrete Values
🎯 What Are Discrete Values?
Discrete values change immediately at animation start, not smoothly over time.

Type	Example	Discrete?	Why?
Continuous	Position, Scale	❌ No	Smooth transitions look natural
Discrete	State, Mode, Flag	✅ Yes	Intermediate values don't make sense
📝 Using Discrete Values
Method 1: Basic Discrete Array
lua
AnimationEngine.animate(
    { x = 0, state = "idle", mode = 1 },
    { x = 100, state = "walking", mode = 2 },
    1.0,
    {
        discrete = {"state", "mode"},  -- These change IMMEDIATELY
        on_update = function(values)
            -- At t=0.001: state="walking", mode=2 (already!)
            -- x animates smoothly from 0 to 100
        end
    }
)
Method 2: Discrete-First Helper
lua
AnimationEngine.animate_discrete_first(
    { x = 0, state = "idle" },
    { x = 100, state = "attacking" },
    1.0,
    {
        discrete = {"state"},
        on_update = function(values)
            -- state becomes "attacking" on FIRST frame
            -- x animates over 1 second
        end
    }
)
Method 3: Pre-built Discrete Effects
lua
AnimationEngine.move_to_discrete_first(
    character,
    300, 200,  -- Target
    1.5,       -- Duration
    "ease_out",
    nil,       -- on_complete
    false,     -- loop
    false,     -- ping_pong
    nil,       -- easing_back
    {"state", "action"}  -- discrete keys
)
🎮 Practical Examples
Character State Machine
lua
function setCharacterState(character, newState)
    local currentX, currentY = character.x, character.y
    
    AnimationEngine.animate(
        {
            x = currentX,
            y = currentY,
            state = character.state,
            weapon = character.weapon
        },
        {
            x = currentX,
            y = currentY,
            state = newState,
            weapon = newState == "attacking" and "sword" or "none"
        },
        0.1,  -- Quick transition
        {
            discrete = {"state", "weapon"},  -- Immediate state change
            on_update = function(values)
                character.state = values.state
                character.weapon = values.weapon
                
                -- Visual feedback based on state
                if values.state == "damaged" then
                    character.tint = {255, 100, 100}
                end
            end
        }
    )
end
UI Mode Switching
lua
function switchUIMode(ui, newMode)
    AnimationEngine.animate(
        {
            mode = ui.mode,
            color_scheme = ui.color_scheme,
            x = ui.panel.x
        },
        {
            mode = newMode,
            color_scheme = MODE_COLORS[newMode],
            x = newMode == "advanced" and 50 or 0
        },
        0.3,
        {
            discrete = {"mode", "color_scheme"},  -- Immediate mode switch
            easing = "ease_out",
            on_update = function(values)
                ui.mode = values.mode
                ui.color_scheme = values.color_scheme
                ui.panel.x = values.x
                
                -- Update UI based on new mode
                updateUIForMode(values.mode)
            end
        }
    )
end
🎭 Animation Sequences
📦 Creating Sequences
lua
local sequenceId = AnimationEngine.create_sequence(
    steps,    -- Array of step definitions
    options   -- { id, loop, on_complete }
)
🔧 Step Types
1. Animation Step
lua
{
    type = "animate",
    start = { x = 0 },          -- Optional (defaults to current)
    target = { x = 100 },       -- Required
    duration = 1.0,             -- Required
    easing = "linear",          -- Optional
    discrete = {"state"},       -- Optional
    on_update = function(values) end  -- Optional
}
2. Delay Step
lua
{
    type = "delay",
    duration = 0.5  -- Seconds to wait
}
3. Callback Step
lua
{
    type = "callback",
    callback = function()
        print("Step complete!")
    end
}
🔗 Special Value References
lua
-- In sequence step targets:
{
    x = "current",        -- Current value
    y = "current+50",     -- Current value + 50
    scale = "original",   -- Original starting value
    alpha = 128           -- Literal value
}
🎬 Complete Sequence Example
lua
local attackSequence = AnimationEngine.create_sequence({
    -- Step 1: Wind-up
    {
        type = "animate",
        target = {
            scale = 1.3,
            rotation = -15,
            state = "charging"  -- Discrete!
        },
        duration = 0.3,
        easing = "ease_out",
        discrete = {"state"}
    },
    
    -- Step 2: Lunge forward
    {
        type = "animate",
        target = {
            x = "current+200",  -- Move 200px forward
            y = "current",
            state = "attacking"
        },
        duration = 0.1,
        easing = "instant",  -- Very fast!
        discrete = {"state"}
    },
    
    -- Step 3: Hit effect
    {
        type = "callback",
        callback = function()
            playSound("hit.wav")
            spawnParticles()
        end
    },
    
    -- Step 4: Return
    {
        type = "animate",
        target = {
            x = "original",  -- Back to start
            y = "original",
            scale = 1.0,
            rotation = 0,
            state = "idle"
        },
        duration = 0.5,
        easing = "ease_out",
        discrete = {"state"}
    },
    
    -- Step 5: Cooldown delay
    {
        type = "delay",
        duration = 0.2
    }
}, {
    loop = false,  -- Play once
    on_complete = function()
        print("Attack sequence finished!")
    end
})

-- Start the sequence
AnimationEngine.start_sequence(attackSequence)
🔄 Looping Sequences
lua
-- Infinite loop
{ loop = true }

-- Loop 3 times
{ loop = 3 }

-- Ping-pong sequence
local bounceSeq = AnimationEngine.create_sequence({
    { type = "animate", target = {x = 100}, duration = 1 },
    { type = "animate", target = {x = 0}, duration = 1 }
}, {
    loop = true  -- Will bounce back and forth forever
})
⏸️ Sequence Control
lua
-- Start/Restart
AnimationEngine.start_sequence("my_sequence")

-- Stop (with cleanup)
AnimationEngine.stop_sequence("my_sequence")

-- Check if sequence exists
if sequences["my_sequence"] then
    print("Sequence is running")
end
🛠️ Utility Functions
⏱️ Delayed Callbacks
lua
-- Simple delay
AnimationEngine.delay(2.5, function()
    print("2.5 seconds later...")
end)

-- Chained delays
AnimationEngine.delay(1.0, function()
    print("One...")
    AnimationEngine.delay(1.0, function()
        print("Two...")
        AnimationEngine.delay(1.0, function()
            print("Three!")
        end)
    end)
end)
📊 System Monitoring
lua
-- Get active counts
local animCount = AnimationEngine.get_active_count()
local seqCount = AnimationEngine.get_sequence_count()
print(string.format("Active: %d animations, %d sequences", animCount, seqCount))

-- Performance tracking
function monitorPerformance()
    local count = AnimationEngine.get_active_count()
    if count > 50 then
        print("Warning: High animation count - " .. count)
    end
end
🧹 Cleanup Functions
lua
-- Stop specific animation
AnimationEngine.stop_animation("anim_1234")

-- Stop specific sequence
AnimationEngine.stop_sequence("seq_5678")

-- Nuclear option: Stop EVERYTHING
AnimationEngine.clear_all()
⚡ Instant Transitions
🎯 AnimationEngine.set_to()
Immediate property setting - no animation.

lua
-- Set multiple properties at once
AnimationEngine.set_to(mySprite, {
    x = 100,
    y = 200,
    scale = 1.5,
    alpha = 128,
    visible = true
})

-- With object-specific setters
local UIElement = {
    setPosition = function(self, x, y) ... end,
    setAlpha = function(self, a) ... end
}

AnimationEngine.set_to(UIElement, {
    x = 300,
    y = 150,
    alpha = 255
})
⚡ Instant Easing
lua
-- Using "instant" easing
AnimationEngine.animate(
    { x = 0 },
    { x = 100 },
    0,  -- Duration ignored
    { easing = "instant" }  -- Jumps immediately to target
)

-- In sequences
{
    type = "animate",
    target = { mode = "advanced" },
    duration = 0,  -- Zero duration
    easing = "instant"  -- Immediate change
}
📊 Configuration
🔧 Engine Settings
lua
-- Toggle debug logging
AnimationEngine.set_debug(true)  -- Enable
AnimationEngine.set_debug(false) -- Disable

-- Default speeds (used by some helper functions)
AnimationEngine.set_interpolation_speeds(
    10,   -- position (units/sec)
    180,  -- rotation (degrees/sec)
    5,    -- color (components/sec)
    2     -- scale (units/sec)
)
🎨 Custom Easing Functions
lua
-- Add a custom easing function
AnimationEngine.add_easing_function("my_custom_ease", function(t)
    -- t goes from 0 to 1
    -- Return eased value from 0 to 1
    return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
end)

-- Use it in animations
AnimationEngine.animate(..., {
    easing = "my_custom_ease",
    ...
})
📈 Easing Functions
📊 Easing Function Gallery
Function	Preview	Description
instant	─────█	Immediate jump
linear	──────	Constant speed
ease_in	~~~~─█	Start slow, accelerate
ease_out	█─~~~~	Start fast, decelerate
ease_in_out	~───~	Slow start/end, fast middle
smoothstep	~~~~~~	Smooth S-curve
elastic_in	↶↷─█	Elastic bounce at start
elastic_out	█─↷↶	Elastic bounce at end
bounce_out	█⌒⌒⌒	Multiple bounces at end
bounce_in	⌒⌒⌒█	Multiple bounces at start
📝 Usage Examples
lua
-- Menu slide-in
AnimationEngine.move_to(menu, 0, 0, 0.5, "elastic_out")

-- Button press
AnimationEngine.scale_to(button, 0.9, 0.1, "ease_in")
AnimationEngine.scale_to(button, 1.0, 0.2, "elastic_out")

-- Page transition
AnimationEngine.fade_to(oldPage, 0, 0.3, "ease_out")
AnimationEngine.fade_to(newPage, 255, 0.3, "ease_in")

-- Celebration bounce
AnimationEngine.move_to(
    confetti,
    100, 200,
    0.8,
    "bounce_out"
)
🎯 Choosing the Right Easing
lua
-- Physical movements
"ease_out", "bounce_out"

-- UI elements
"ease_in_out", "smoothstep"

-- Special effects
"elastic_out", "bounce_out"

-- Immediate actions
"instant"

-- Continuous motion
"linear"
🎮 Examples & Use Cases
🕹️ Game Character Controller
lua
local PlayerController = {
    moveTo = function(self, x, y)
        -- Stop any existing movement
        if self.moveAnim then
            AnimationEngine.stop_animation(self.moveAnim)
        end
        
        -- Start new movement
        self.moveAnim = AnimationEngine.move_to(
            self.sprite,
            x, y,
            self.moveSpeed,
            "ease_out",
            function()
                self.moveAnim = nil
                self:setState("idle")
            end
        )
        
        -- Immediate state change
        self:setState("moving")
    end,
    
    takeDamage = function(self, amount)
        -- Flash red
        AnimationEngine.tint_to(
            self.sprite,
            255, 100, 100,
            0.1,
            "instant",
            function()
                AnimationEngine.tint_to(
                    self.sprite,
                    255, 255, 255,
                    0.3,
                    "linear"
                )
            end
        )
        
        -- Knockback effect
        local knockX = self.sprite.x - 20
        local knockY = self.sprite.y - 10
        
        AnimationEngine.move_to(
            self.sprite,
            knockX, knockY,
            0.1,
            "ease_out",
            function()
                AnimationEngine.move_to(
                    self.sprite,
                    self.sprite.x + 20,
                    self.sprite.y + 10,
                    0.2,
                    "elastic_out"
                )
            end
        )
    end
}
🎨 UI System
lua
local UIManager = {
    showDialog = function(self, dialog)
        -- Reset position off-screen
        AnimationEngine.set_to(dialog, {
            x = -dialog.width,
            y = 100,
            alpha = 0
        })
        
        dialog.visible = true
        
        -- Slide in with fade
        AnimationEngine.animate(
            { x = -dialog.width, alpha = 0 },
            { x = 100, alpha = 255 },
            0.5,
            {
                easing = "elastic_out",
                on_update = function(values)
                    dialog.x = values.x
                    dialog.alpha = values.alpha
                end
            }
        )
    end,
    
    buttonHover = function(self, button)
        -- Stop any existing animations
        AnimationEngine.stop_animation(button.animId)
        
        -- Scale up with color change
        button.animId = AnimationEngine.animate(
            { scale = button.scale, tint = button.tint },
            { scale = 1.1, tint = {255, 255, 200} },
            0.2,
            {
                easing = "ease_out",
                on_update = function(values)
                    button.scale = values.scale
                    button.tint = values.tint
                end
            }
        )
    end,
    
    notification = function(self, message)
        local notif = createNotification(message)
        
        -- Sequence: slide up, pause, slide out
        local seq = AnimationEngine.create_sequence({
            {
                type = "animate",
                target = { y = 50 },
                duration = 0.3,
                easing = "ease_out"
            },
            {
                type = "delay",
                duration = 2.0
            },
            {
                type = "animate",
                target = { y = -100 },
                duration = 0.3,
                easing = "ease_in"
            },
            {
                type = "callback",
                callback = function()
                    notif:destroy()
                end
            }
        })
        
        AnimationEngine.start_sequence(seq)
    end
}
🌌 Particle Effects
lua
local ParticleSystem = {
    emitBurst = function(self, x, y, count)
        for i = 1, count do
            local particle = self:createParticle(x, y)
            
            -- Random direction and speed
            local angle = math.random() * math.pi * 2
            local speed = math.random(50, 200)
            local targetX = x + math.cos(angle) * speed
            local targetY = y + math.sin(angle) * speed
            
            -- Animate with gravity simulation
            AnimationEngine.animate(
                {
                    x = x,
                    y = y,
                    scale = 1,
                    alpha = 255
                },
                {
                    x = targetX,
                    y = targetY + 100,  -- Gravity pull
                    scale = 0,
                    alpha = 0
                },
                math.random(1, 3),
                {
                    easing = "ease_out",
                    on_update = function(values)
                        particle.x = values.x
                        particle.y = values.y
                        particle.scale = values.scale
                        particle.alpha = values.alpha
                    end,
                    on_complete = function()
                        particle:destroy()
                    end
                }
            )
        end
    end
}
🚨 Troubleshooting
🔍 Common Issues & Solutions
Problem	Solution
Animation not starting	Ensure AnimationEngine.tick(dt) is being called
Values not updating	Check on_update callback is properly assigned
Discrete values not changing	Verify keys are in discrete array
Memory leak	Stop animations when objects are destroyed
Performance issues	Monitor with get_active_count()
📝 Debug Checklist
lua
-- 1. Enable debug logging
AnimationEngine.set_debug(true)

-- 2. Check animation count
print("Active animations:", AnimationEngine.get_active_count())

-- 3. Verify update loop
function update(dt)
    AnimationEngine.tick(dt)  -- Make sure this is called!
end

-- 4. Check completion callbacks
on_complete = function(values, interrupted)
    if interrupted then
        print("Animation was stopped early!")
    end
end
⚡ Performance Tips
lua
1. **Use discrete values** for state changes
2. **Stop animations** when no longer needed
3. **Reuse sequences** instead of creating new ones
4. **Monitor counts** during development
5. **Use instant easing** for immediate changes
📚 Quick Reference
🎯 Essential Functions
lua
-- Animation
AnimationEngine.animate(start, target, duration, options)
AnimationEngine.stop_animation(id)

-- Pre-built effects
.move_to(object, x, y, duration, ...)
.scale_to(object, scale, duration, ...)
.rotate_to(object, angle, duration, ...)
.fade_to(object, alpha, duration, ...)
.tint_to(object, r, g, b, duration, ...)

-- Sequences
.create_sequence(steps, options)
.start_sequence(id)
.stop_sequence(id)

-- Utilities
.set_to(object, values)
.delay(duration, callback)
.clear_all()
🎨 Easing Cheat Sheet
text
instant     : ║ (Immediate)
linear      : ░░░░░░░░ (Constant)
ease_in     : ░░░░▓▓▓▓ (Start slow)
ease_out    : ▓▓▓▓░░░░ (End slow)
ease_in_out : ░░▓▓▓▓░░ (Slow ends)
elastic_out : ▓▓▓▓⌒⌒⌒ (Bouncy end)
bounce_out  : ▓▓⌒⌒⌒⌒⌒ (Multiple bounces)
🚀 Next Steps
📖 Advanced Topics to Explore
Custom easing functions for unique effects

Animation blending for smooth transitions

Time scaling for slow-motion effects

Event-driven animations for game events

Performance optimization for large scenes

🔗 Integration Ideas
lua
-- With physics engines
AnimationEngine.animate(..., {
    on_update = function(values)
        physicsBody.position = {values.x, values.y}
    end
})

-- With sound systems
AnimationEngine.animate(..., {
    on_update = function(values, progress)
        sound.setVolume(progress)
    end
})

-- With shader systems
AnimationEngine.animate(..., {
    on_update = function(values)
        shader.setUniform("u_time", values.time)
    end
})
📞 Need Help?
🆘 Common Questions
Q: My animation is stuttering. Why?
A: Ensure tick(dt) is called consistently with a stable delta time.

Q: Can I animate nested properties?
A: Yes! Use dot notation in keys: {"position.x", "scale.y"}

Q: How do I chain animations without sequences?
A: Use completion callbacks to start the next animation.

Q: Can I use this with non-visual objects?
A: Absolutely! Animate any numeric properties.

🎉 Congratulations!
You now have a complete, production-ready animation system at your fingertips. Happy animating! 🎬

Documentation generated for Animation Engine v1.0
Last updated: January 24th 2026

