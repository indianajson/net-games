Animation Engine Documentation
Overview
The Animation Engine is a powerful, reusable animation system for Lua that provides:

Smooth interpolation between values

Multiple easing functions for natural motion

Animation sequences and chaining

Pre-built visual effects

Callback support for custom logic

Installation & Setup
lua
-- In your main game file
local AnimationEngine = require("/server/scripts/ezlibs-custom/animation_engine")

-- Make sure to call the update function in your game loop
function onTick(dt)
    AnimationEngine.tick(dt)
end
Basic Usage
Simple Property Animation
lua
-- Animate a position
AnimationEngine.animate(
    {x = 0, y = 0},           -- Start values
    {x = 100, y = 200},       -- Target values
    2.0,                      -- Duration in seconds
    {
        easing = "ease_in_out", -- Easing function name
        on_update = function(values)
            -- Called every frame with interpolated values
            myObject.x = values.x
            myObject.y = values.y
        end,
        on_complete = function(values, interrupted)
            if not interrupted then
                print("Animation completed!")
            end
        end
    }
)
Using Pre-built Effects
lua
-- Move an object
AnimationEngine.move_to(myObject, 300, 200, 1.5, "ease_out")

-- Scale an object
AnimationEngine.scale_to(myObject, 2.0, 1.0, "ease_in_out")

-- Rotate an object
AnimationEngine.rotate_to(myObject, 360, 2.0, "ease_in_out")

-- Fade in/out
AnimationEngine.fade_to(myObject, 0, 1.0, "ease_in_out") -- Fade out

-- Color tint
AnimationEngine.tint_to(myObject, 255, 0, 0, 1.0, "ease_in_out") -- Tint to red
Easing Functions
The engine includes 13 built-in easing functions:

Function	Description	Best For
linear	Constant speed	Simple movements
ease_in	Starts slow, accelerates	Starting motions
ease_out	Starts fast, decelerates	Ending motions
ease_in_out	Starts/ends slow	Natural movements
smoothstep	Very smooth curve	UI animations
smootherstep	Even smoother	Premium feel
elastic_in	Elastic bounce at start	Attention-grabbing
elastic_out	Elastic bounce at end	Playful effects
elastic_in_out	Elastic both ends	Cartoon effects
bounce_in	Bounces into view	Playful entrances
bounce_out	Bounces out of view	Playful exits
square	Quadratic acceleration	Power effects
cubic	Cubic acceleration	Strong emphasis
Animation Sequences
Sequences allow you to chain multiple animations together with delays and callbacks.

Basic Sequence
lua
local sequenceId = AnimationEngine.create_sequence({
    -- Step 1: Move right
    {
        type = "animate",
        target = {x = "current+100"},  -- Relative to current position
        duration = 1.0,
        easing = "ease_out"
    },
    
    -- Step 2: Pause for 0.5 seconds
    {
        type = "delay",
        duration = 0.5
    },
    
    -- Step 3: Scale up
    {
        type = "animate",
        target = {scale = 2.0},
        duration = 0.8,
        easing = "elastic_out"
    },
    
    -- Step 4: Call custom function
    {
        type = "callback",
        callback = function()
            print("Sequence step 4 completed!")
        end
    },
    
    -- Step 5: Return to original size
    {
        type = "animate",
        target = {scale = "original"},  -- Returns to original scale
        duration = 0.8,
        easing = "bounce_out"
    }
}, {
    loop = false,  -- Set to true for infinite loop
    on_complete = function()
        print("Entire sequence completed!")
    end
})

-- Start the sequence
AnimationEngine.start_sequence(sequenceId)
Advanced Sequence with Object Control
lua
local myCharacter = {x = 100, y = 100, scale = 1.0}

local walkSequence = AnimationEngine.create_sequence({
    -- Walk right
    {
        type = "animate",
        target = {x = "current+50"},
        duration = 0.5,
        easing = "linear",
        on_update = function(values)
            myCharacter.x = values.x
            myCharacter.scale = 1.0  -- Face right
        end
    },
    
    -- Jump
    {
        type = "animate",
        start = {y = "current"},
        target = {y = "current-30"},  -- Jump up
        duration = 0.3,
        easing = "ease_out"
    },
    {
        type = "animate",
        target = {y = "current"},  -- Fall down
        duration = 0.3,
        easing = "ease_in"
    },
    
    -- Walk left
    {
        type = "animate",
        target = {x = "current-50"},
        duration = 0.5,
        easing = "linear",
        on_update = function(values)
            myCharacter.x = values.x
            myCharacter.scale = -1.0  -- Face left (flipped)
        end
    }
}, {
    loop = true,  -- Loop forever
    id = "walk_animation"  -- Custom ID for easy reference
})

AnimationEngine.start_sequence(walkSequence)
Pre-built Effects
Pulse Effect
lua
-- Simple pulse (infinite loop by default)
AnimationEngine.pulse(myObject, 0.8, 1.2, 0.5)

-- Pulse with specific number of loops
AnimationEngine.pulse(myObject, 0.8, 1.2, 0.5, 3, function()
    print("Pulsed 3 times!")
end)
Shake Effect
lua
-- Shake an object
AnimationEngine.shake(myObject, 10, 1.0, 30, function()
    print("Shake complete!")
end)

-- Stronger, longer shake
AnimationEngine.shake(myObject, 20, 2.0, 15)
Bounce In Effect
lua
-- Bounce an object into view
AnimationEngine.bounce_in(myObject, 0.1, 1.5, function()
    print("Bounced in!")
end)
Loop Animations for Properties
You can create infinite or limited loops for any property:

Method 1: Using Sequences with Loop Flag
lua
-- Loop rotation forever
local rotateLoop = AnimationEngine.create_sequence({
    {
        type = "animate",
        start = {angle = 0},
        target = {angle = 360},
        duration = 2.0,
        easing = "linear",
        on_update = function(values)
            myObject.angle = values.angle
        end
    }
}, {
    loop = true,
    id = "rotation_loop"
})

AnimationEngine.start_sequence(rotateLoop)

-- Stop the loop later
AnimationEngine.stop_sequence("rotation_loop")
Method 2: Custom Loop Function
lua
function createBreatheLoop(object, property, minValue, maxValue, duration, easing)
    local seqId = AnimationEngine.create_sequence({
        {
            type = "animate",
            target = {[property] = maxValue},
            duration = duration / 2,
            easing = easing,
            on_update = function(values)
                object[property] = values[property]
            end
        },
        {
            type = "animate",
            target = {[property] = minValue},
            duration = duration / 2,
            easing = easing,
            on_update = function(values)
                object[property] = values[property]
            end
        }
    }, {
        loop = true
    })
    
    return seqId
end

-- Usage: Breathe alpha between 100 and 255
local breatheAlpha = createBreatheLoop(myObject, "alpha", 100, 255, 2.0, "ease_in_out")
AnimationEngine.start_sequence(breatheAlpha)
Method 3: Using Relative Values in Loop
lua
-- Oscillate between positions
local oscillateSeq = AnimationEngine.create_sequence({
    {
        type = "animate",
        target = {x = "current+100"},
        duration = 1.0,
        easing = "ease_in_out",
        on_update = function(values)
            myObject.x = values.x
        end
    },
    {
        type = "animate",
        target = {x = "current-100"},
        duration = 1.0,
        easing = "ease_in_out",
        on_update = function(values)
            myObject.x = values.x
        end
    }
}, {
    loop = true
})

AnimationEngine.start_sequence(oscillateSeq)
Advanced Examples
Complex Character Animation
lua
function animateCharacterEntrance(character)
    local seqId = AnimationEngine.create_sequence({
        -- Fade in
        {
            type = "animate",
            start = {alpha = 0},
            target = {alpha = 255},
            duration = 0.5,
            easing = "ease_in"
        },
        
        -- Drop from above with bounce
        {
            type = "animate",
            start = {y = -100},
            target = {y = character.y},
            duration = 0.8,
            easing = "bounce_out"
        },
        
        -- Shake on landing
        {
            type = "callback",
            callback = function()
                AnimationEngine.shake(character, 5, 0.3, 20)
            end
        },
        
        -- Pulse to indicate readiness
        {
            type = "delay",
            duration = 0.2
        },
        {
            type = "callback",
            callback = function()
                AnimationEngine.pulse(character, 0.9, 1.1, 0.3, 2)
            end
        }
    }, {
        id = "character_entrance_" .. character.id
    })
    
    AnimationEngine.start_sequence(seqId)
    return seqId
end
UI Animation System
lua
local UIAnimations = {
    slideIn = function(uiElement, fromSide)
        local startX, startY = uiElement.x, uiElement.y
        local targetX, targetY = uiElement.x, uiElement.y
        
        if fromSide == "left" then
            startX = -uiElement.width
        elseif fromSide == "right" then
            startX = love.graphics.getWidth()
        elseif fromSide == "top" then
            startY = -uiElement.height
        elseif fromSide == "bottom" then
            startY = love.graphics.getHeight()
        end
        
        return AnimationEngine.move_to(uiElement, targetX, targetY, 0.5, "elastic_out")
    end,
    
    slideOut = function(uiElement, toSide)
        local targetX, targetY = uiElement.x, uiElement.y
        
        if toSide == "left" then
            targetX = -uiElement.width
        elseif toSide == "right" then
            targetX = love.graphics.getWidth()
        elseif toSide == "top" then
            targetY = -uiElement.height
        elseif toSide == "bottom" then
            targetY = love.graphics.getHeight()
        end
        
        return AnimationEngine.move_to(uiElement, targetX, targetY, 0.3, "ease_in")
    end,
    
    highlight = function(uiElement)
        AnimationEngine.tint_to(uiElement, 255, 255, 200, 0.2, "ease_in_out", function()
            AnimationEngine.tint_to(uiElement, 255, 255, 255, 0.2, "ease_in_out")
        end)
    end
}
Management and Control
Stop Animations
lua
-- Stop specific animation
AnimationEngine.stop_animation(animationId)

-- Stop specific sequence
AnimationEngine.stop_sequence(sequenceId)

-- Clear all animations
AnimationEngine.clear_all()
Check Status
lua
-- Get counts
local activeAnimations = AnimationEngine.get_active_count()
local activeSequences = AnimationEngine.get_sequence_count()

print("Active: " .. activeAnimations .. " animations, " .. activeSequences .. " sequences")
Delayed Actions
lua
-- Execute after delay
AnimationEngine.delay(2.0, function()
    print("This runs after 2 seconds!")
)

-- Chain delays
AnimationEngine.delay(1.0, function()
    print("First delay")
    AnimationEngine.delay(1.0, function()
        print("Second delay")
    end)
end)
Animation Enums Documentation
The animation-enums.lua file provides a convenient way to reference easing function names:

lua
local Enums = require("scripts/net-games/animation-engine/animation-enums")

-- Use enums for type safety
AnimationEngine.animate(start, target, duration, {
    easing = Enums.EasingFns.elastic_out,
    on_update = function(values) -- ... end
})

-- All available enums
print(Enums.EasingFns.linear)        -- "linear"
print(Enums.EasingFns.ease_in_out)   -- "ease_in_out"
print(Enums.EasingFns.bounce_in)     -- "bounce_in"
Tips & Best Practices
Use meaningful IDs: Assign custom IDs to important animations for easy management

Clean up on object removal: Call AnimationEngine.clear_all() or stop specific animations when objects are destroyed

Chain callbacks: Use the on_complete callback to trigger the next action

Mix easing functions: Combine different easings in sequences for natural motion

Use relative values: "current+50" is more maintainable than hardcoded values

Test performance: Complex sequences with many objects may need optimization

Use loops sparingly: Infinite loops can accumulate; remember to stop them when done

Troubleshooting
Animation not playing?

Make sure AnimationEngine.tick(dt) is called in your game loop

Check that duration > 0

Verify easing function name is spelled correctly

"Invalid key to 'next'" error?

Use the fixed update functions provided above

Don't modify animation tables in callbacks (create new animations instead)

Animation jumps at end?

Make sure start and target values are the correct type (both numbers or both tables)

Memory leaks?

Always stop sequences when objects are destroyed

Use AnimationEngine.clear_all() when switching scenes