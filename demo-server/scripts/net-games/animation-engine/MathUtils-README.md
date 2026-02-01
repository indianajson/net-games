# **📊 Core Math Functions**

```lua
-- CLAMPING & NORMALIZATION
    MathUtils.clamp01(t)                    -- Clamps value between 0-1
    MathUtils.ease_clamped01(t, easing)     -- Eases then clamps 0-1
    MathUtils.clamp255(value)               -- Clamps value between 0-255
    MathUtils.ease_clamped255(t, easing)    -- Eases then clamps 0-255
```

## **MathUtils.clamp01(t) 📏**

### Purpose 
- Ensures animation progress values stay within valid 0-1 range

### Use-Case 
- Prevents overflow in interpolation calculations

### Visual
- Controls animation boundaries - keeps animations from overshooting

---

## **MathUtils.clamp255(value) 🎨**
### **Purpose** 
- Validates color component values

### **Use-Case** 
- RGB/Alpha channel safety limits
### **Visual** 
- Ensures colors stay within displayable range

---

## **MathUtils.lerp(a, b, t) ➡️**
### Purpose
- Linear interpolation between two values

### Use-Case
- Basic value transitions, 
- Position movement, 
- Scale changes

### Visual Effect 
- Creates smooth, 
- Constant-speed transitions

*Example: Moving objects, fading colors, growing/shrinking elements*

# **🌀 Easing Functions - The Magic of Natural Motion**

## **🔄 Basic Easing**

```lua
linear      -- Robotic, mechanical movement
ease_in     -- Natural acceleration (starts slow)
ease_out    -- Natural deceleration (ends slow)
ease_in_out -- Smooth acceleration & deceleration
```

## **🎭 Advanced Easing**

```lua
smoothstep     -- Professional UI transitions
smootherstep   -- Premium ultra-smooth feel
elastic_in     -- Spring anticipation before movement
elastic_out    -- Springy overshoot at end
bounce_out     -- Playful bounce effect
bounce_in      -- Objects dropping with bounce
```

## **🌊 Specialty Easing**

```lua
sine_in/sine_out/sine_in_out     -- Wave-like fluid motion
circ_in/circ_out/circ_in_out     -- Spherical orbital movement
back_in/back_out/back_in_out     -- Pull-back anticipation
instant                         -- Immediate changes
```

# **🎬 Animation Math Functions**
```lua
-- COMPLEX ANIMATIONS
MathUtils.calculate_shake_offset(time, freq, intensity, decay)
MathUtils.calculate_pulse(time, freq, min, max)
MathUtils.interpolate_color(r1,g1,b1,a1, r2,g2,b2,a2, t, easing)
```

## **MathUtils.calculate_shake_offset() 🌋**
### Purpose  
- screen/camera, 
- sprites,
- shake effects,

*etc...*

### Parameters
- frequency → Shake speed (higher = faster)
- intensity → Shake strength
- decay → Fade out over time

### Visual Effect 
- Impact vibrations, 
- Explosions, 
- Earthquakes

*Example: calculate_shake_offset(2.5, 15, 5, 0.9) → Moderate decaying shake*

## **MathUtils.calculate_pulse() 💓**
### Purpose 
- rhythmic pulsing values

### Parameters
- frequency → Pulse rate
- min_value/max_value → Pulse range

### Visual Effect
- Glowing buttons, 
- Breathing animations, 
- Attention indicators

*Example: calculate_pulse(time, 2, 1.0, 1.2) → Gentle 2Hz scale pulse*

## **MathUtils.interpolate_color() 🌈**
### Purpose 
- Smooth color transitions with easing
- Visual Effect: Color blending between any two colors

*Example: Red → Blue with ease_in_out creates smooth color shift*

## **📐 Geometric Functions**

```lua
-- SPATIAL CALCULATIONS
MathUtils.distance(x1,y1, x2,y2)           -- Euclidean distance
MathUtils.distance_squared(x1,y1, x2,y2)   -- Faster distance comparison
MathUtils.angle_between(x1,y1, x2,y2)      -- Direction calculation (radians)
MathUtils.angle_between_degrees(x1,y1, x2,y2) -- Direction (degrees)
MathUtils.point_in_rect(px,py, rx,ry, w,h) -- Hit testing
```

## **MathUtils.quadratic_bezier() 🏹**
### Purpose
- Calculates curved motion paths

### Visual Effect 
- Natural arc movements

*Example: Card flying through air, bouncing ball trajectories*


## **MathUtils.cubic_bezier() 🎢**
### Purpose 
- Complex curved paths with more control

### Visual Effect 
- Sophisticated S-shaped movements

*Example: Smooth menu slide-outs with anticipation*

## **🎲 Random Functions**
```lua
-- PROCEDURAL VARIATION
MathUtils.random_float(min, max)   -- Random decimal
MathUtils.random_int(min, max)     -- Random integer (inclusive)
MathUtils.random_sign()           -- Random direction (-1 or 1)
MathUtils.random_element(array)   -- Random array selection
```

### Use-Cases
- Particle effect variations
- Animation timing offsets
- Procedural movement patterns

## **📋 Table Operations**
```lua
-- DATA MANAGEMENT
MathUtils.deep_copy(original)   -- Recursive table copy
MathUtils.merge_tables(t1, t2)  -- Combine tables (t2 overwrites)
```

### Use-Cases
- Preserving animation templates
- Combining configuration options
- Creating animation variations

---

# **✨ Visual Effects Cheat Sheet**
## 🎯 Position Animations
```
Linear → UI sliders, progress bars
Ease Out → Objects coming to rest  
Bounce Out → Playful UI elements
Elastic → Spring-loaded menus
```

## 📏 Scale Animations
```
Ease In/Out → Natural appearing/disappearing
Elastic → Bouncy popups
Bounce → Celebration effects
```

## 🎨 Color Transitions
```
Linear → Smooth fades
Ease In → Color intensifying
Sine In/Out → Pulsing glow effects
```

## 🔄 Rotation Effects
```
Linear → Continuous spinning
Ease Out → Spinning to stop
Back In/Out → Card flip anticipation
```

## **🚀 Quick Reference Guide**
### For Professional UI

```lua
MathUtils.ease(t, "smoothstep")      -- Polished transitions
MathUtils.ease(t, "ease_in_out")     -- Natural feeling
```
### For Game Elements

```lua
MathUtils.ease(t, "bounce_out")      -- Playful bounce
MathUtils.ease(t, "elastic_out")     -- Springy feedback
```

### For Dramatic Effects

```lua
MathUtils.calculate_shake_offset()   -- Screen shake
MathUtils.ease(t, "back_in_out")     -- Anticipation
```

## **⚙️ Technical Notes**
### Performance Tips
- Use `distance_squared()` for collision detection (avoids sqrt)
- Cache easing function references if calling frequently
- Use `lerp()` for simple animations, Bézier for complex paths

### Common Patterns

```lua
-- Smooth movement with easing
local progress = elapsed / duration
local eased = MathUtils.ease(progress, "ease_out")
object.x = MathUtils.lerp(start_x, target_x, eased)

-- Color transition
local r,g,b,a = MathUtils.interpolate_color(
    start_r, start_g, start_b, start_a,
    target_r, target_g, target_b, target_a,
    progress, "ease_in_out"
)

-- Screen shake
local shake_x, shake_y = MathUtils.calculate_shake_offset(
    time, 15, 5, 0.9
)
camera.x = base_x + shake_x
```

## **🎪 Example Gallery**
### 1. Gentle Bob Animation 🐬
```lua
-- Creates floating, wave-like motion
local y = start_y + MathUtils.calculate_pulse(time, 0.5, -3, 3)
```
### 2. Impact Shake 💥

```lua
-- Strong initial shake that fades quickly
local x_shake, y_shake = MathUtils.calculate_shake_offset(
    elapsed, 20, 8, 0.85
)
```

### 3. Color Pulse Alert 🔴

```lua
-- Attention-grabbing red pulse
local r = MathUtils.calculate_pulse(time, 2, 100, 255)
object:setColor(r, 0, 0)
```

### 4. Menu Entrance 🚪

```lua
-- Sophisticated slide-in with slight overshoot
local x = MathUtils.lerp(off_screen, target_x, 
    MathUtils.ease(progress, "back_out")
)
```

# 📚 Final Notes

### This module provides the mathematical foundation for all animations in the engine. Each function serves a specific purpose in creating engaging, natural-feeling motion that enhances user experience.

### **Remember: The right easing function can transform a basic animation into something that feels alive and responsive!**

