# 🎞️ Animation Engine Documentation

## Overview
The **Animation Engine** is a standalone Lua module for creating smooth, reusable animations and interpolations.  
It provides a comprehensive system for animating object properties with support for:

- **Easing functions**
- **Looping & ping-pong animations**
- **Animation sequences**
- **Discrete (instant) value handling**

---

## 🛠️ Setup & Initialization

### 1. Required Files
```lua
-- Core files (all required)
animation-engine.lua      -- Main engine
animation-enums.lua       -- Enum definitions
animation-sequences.lua   -- Pre-built animations
math-utils.lua            -- Math functions
```

### 2. Basic Setup

**Option 1: Let files register themselves globally**
```lua
-- Files automatically register to _G when required
```

**Option 2: Require them explicitly**
```lua
local AnimationEngine = require("scripts/net-games/animation-engine/animation-engine")
local AnimationSequences = require("scripts/net-games/animation-engine/animation-sequences")
local MathUtils = require("scripts/net-games/animation-engine/math-utils")
```

### 3. Integration with Game Loop
```lua
-- The engine automatically hooks to Net:on("tick") in animation-engine.lua
-- If using a custom loop, call manually:

function update(dt)
    AnimationEngine.tick(dt)
end
```

---

## ⚙️ Core Animation Engine API

### `AnimationEngine.animate(start_values, target_values, duration, options)`
Creates a smooth animation between values.

#### Parameters
- **start_values** *(table, required)*  
  Initial property values
  ```lua
  { x = 0, y = 0, scale = 1 }
  ```

- **target_values** *(table, required)*  
  Target property values
  ```lua
  { x = 100, y = 100, scale = 2 }
  ```

- **duration** *(number, required)*  
  Duration in seconds

- **options** *(table, optional)*  
  Animation configuration

#### Options
- `easing` *(string, default: "linear")*
- `easing_back` *(string, default: same as easing)*
- `on_update(values, progress, phase)`
- `on_complete(final_values, interrupted)`
- `loop` *(boolean | number)*
- `ping_pong` *(boolean)*
- `discrete` *(array)*
- `id` *(string)*

#### Returns
- **Animation ID** *(string)*

#### Example
```lua
local animId = AnimationEngine.animate(
    { x = 0, y = 0, scale = 1 },
    { x = 100, y = 100, scale = 2 },
    1.0,
    {
        easing = "ease_in_out",
        on_update = function(values)
            myObject.x = values.x
            myObject.y = values.y
            myObject.scale = values.scale
        end,
        on_complete = function()
            print("Animation complete!")
        end
    }
)
```

---

### `AnimationEngine.animate_discrete_first(...)`
Discrete values change immediately, then continuous values animate.

```lua
AnimationEngine.animate_discrete_first(
    { x = 0, visible = false },
    { x = 100, visible = true },
    1.0,
    {
        discrete = { "visible" },
        on_update = function(values)
            myObject.x = values.x
            myObject.visible = values.visible
        end
    }
)
```

---

### `AnimationEngine.stop_animation(id)`
Stops an active animation.  
Returns **true** if stopped, otherwise **false**.

---

### `AnimationEngine.set_to(object, values)`
Instantly sets object properties (no animation).

```lua
AnimationEngine.set_to(mySprite, {
    x = 100,
    y = 200,
    scale = 1.5,
    alpha = 255,
    rotation = 45
})
```

---

## 🔗 Sequence Management

### `AnimationEngine.create_sequence(steps, options)`

#### Step Types

**Delay**
```lua
{ type = "delay", duration = 0.5 }
```

**Animate**
```lua
{
    type = "animate",
    start = { x = 0, y = 0 },
    target = { x = 100, y = 100 },
    duration = 1.0,
    easing = "ease_in_out",
    on_update = function(values) end
}
```

**Callback**
```lua
{ type = "callback", callback = function() end }
```

#### Sequence Options
- `loop`
- `on_complete`
- `id`

### Starting & Stopping Sequences
```lua
AnimationEngine.start_sequence(sequenceId)
AnimationEngine.stop_sequence(sequenceId)
```

---

## 🧰 Utility Functions
- `AnimationEngine.delay(duration, callback)`
- `AnimationEngine.clear_all()`
- `AnimationEngine.get_active_count()`
- `AnimationEngine.get_sequence_count()`
- `AnimationEngine.set_debug(true)`
- `AnimationEngine.add_easing_function(name, func)`

---

## 🎬 Animation Sequences API
Defined in **animation-sequences.lua**.

Available animations:
- `summon`
- `positionChange`
- `attack`
- `slideIn`
- `bob`
- `pulse`
- `color_pulse`
- `shake`
- `fade`
- `tint`

---

## 📦 Object Property Requirements

### Supported Properties
- `x`, `y`
- `scale`, `scaleX`, `scaleY`
- `rotation` / `angle`
- `alpha` *(0–255)*
- `r`, `g`, `b`

### Direct Properties
```lua
local myObject = {
    x = 100,
    y = 100,
    scale = 1,
    rotation = 0,
    alpha = 255,
    r = 255, g = 255, b = 255
}
```

### Setter Methods (Also Supported)
```lua
local myObject = {
    setPosition = function(self, x, y) end,
    setScale = function(self, scale) end,
    setRotation = function(self, rotation) end,
    setAlpha = function(self, alpha) end,
    setColor = function(self, r, g, b) end
}
```

---

## 🧠 Easing Functions
Defined in **animation-enums.lua**:
- `instant`
- `linear`
- `ease_in`, `ease_out`, `ease_in_out`
- `smoothstep`, `smootherstep`
- `elastic_in`, `elastic_out`, `elastic_in_out`
- `bounce_in`, `bounce_out`
- `square`, `cubic`

---

## 🚑 Troubleshooting

| Problem | Solution |
|------|--------|
| Animations don’t play | Ensure `tick(dt)` is called |
| Properties don’t update | Check object compatibility |
| Animation completes instantly | Duration > 0 and easing ≠ `"instant"` |
| Conflicting animations | Stop old animations or use IDs |

---

## 🚀 Quick Start Template
```lua
local AnimationEngine = require("animation-engine")

local mySprite = {
    x = 100,
    y = 100,
    scale = 1,
    alpha = 255
}

AnimationEngine.animate(
    { x = 100, scale = 1 },
    { x = 200, scale = 2 },
    1.5,
    {
        easing = "ease_in_out",
        on_update = function(values)
            mySprite.x = values.x
            mySprite.scale = values.scale
        end,
        on_complete = function()
            print("Done!")
        end
    }
)

function update(dt)
    AnimationEngine.tick(dt)
end
```
