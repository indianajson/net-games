# 🎮 Input Helper Module Documentation

------------------------------------------------------------------------

## 📌 Overview

The `input.lua` module provides a **robust, sticky-state input handler**
for Net Games.

It listens to `virtual_input` events once and maintains **per-player
state** for logical actions such as:

-   `confirm`
-   `cancel`
-   `left`, `right`, `up`, `down`
-   `shoulderl`, `shoulderr`
-   `start`, `options`, and more

The module:

-   Handles multiple event payload formats\
-   Implements **edge detection** (press-once logic)\
-   Supports both momentary and repeating keys\
-   Correctly handles missing keys in packets

> Missing keys in a packet do **NOT** imply a key was released.

To solve this, the module uses:

-   `NON_DIR_UP_TIMEOUT` for non-directional keys\
-   A sticky-down model for directional keys

------------------------------------------------------------------------

# 🧠 Key Concepts

## Logical Keys

Internal logical names map to multiple possible event names.

Example:

``` lua
confirm = { "Confirm", "A", "OK" }
```

------------------------------------------------------------------------

## Edge (Press-Once)

An **edge** occurs when a key transitions from **up → down**.

-   Stored in: `s.edge[key]`
-   Retrieved via: `Input.pop()`

------------------------------------------------------------------------

## Down State

Tracks whether a key is currently held.

-   Stored in: `s.down[key]`
-   Directional keys update immediately
-   Non-directional keys use timeout logic

------------------------------------------------------------------------

# 🎯 Key Behavior Rules

## Non-Directional Keys

*(All except left/right/up/down)*

-   Generate edge only on first down signal
-   Ignore `Scroll` events
-   Auto-clear down state after `NON_DIR_UP_TIMEOUT`

Default:

``` lua
NON_DIR_UP_TIMEOUT = 0.06
```

------------------------------------------------------------------------

## Directional Keys

-   Edge on up → down transition
-   Scroll events generate repeat edges
-   Down state updates immediately
-   Absence does NOT clear state (release expected explicitly)

------------------------------------------------------------------------

# ⚙ Configuration & Debug Options

Global variables on `Input`:

  Variable                     Default   Description
  ---------------------------- --------- --------------------------------------
  `Input.DEBUG`                `false`   Enables debug prints
  `Input.DEBUG_THROTTLE`       `0`       Minimum seconds between debug prints
  `Input.DEBUG_CONFIRM_ONLY`   `false`   Only debug confirm bindings
  `Input.DEBUG_DUMP_PACKET`    `false`   Dump full interpreted packet

------------------------------------------------------------------------

# 📦 Internal Constants

``` lua
NON_DIR_UP_TIMEOUT = 0.06
```

Controls how long a non-directional key remains down without updates.

------------------------------------------------------------------------

# 🗂 Per-Player Data Structure

Each player has:

``` lua
st[player_id]
```

  Field                  Type     Description
  ---------------------- -------- ------------------------------
  `edge`                 table    Edge flags per logical key
  `down`                 table    Current down state
  `swallow_until`        number   Ignore input until timestamp
  `require_release`      table    Keys awaiting release
  `non_dir_down_until`   table    Timeout timestamps
  `non_dir_armed`        table    Edge-ready flags
  `last_print`           number   Debug throttle tracker
  `seen_states`          set      Observed state values
  `seen_names`           set      Observed event names
  `last_shape`           misc     Debug info
  `last_map`             misc     Debug info
  `last_raw_count`       misc     Debug info

------------------------------------------------------------------------

# 🚀 Public API

------------------------------------------------------------------------

## `Input.consume(player_id)`

Clears all edge flags.

``` lua
if Input.pop(player, "confirm") then
  startGame()
end

Input.consume(player)
```

------------------------------------------------------------------------

## `Input.pop(player_id, key)`

Returns `true` if key edge exists, then clears it.

``` lua
if Input.pop(player, "start") then
  togglePause()
end
```

------------------------------------------------------------------------

## `Input.pressed(player_id, key)`

Returns edge state without clearing it.

``` lua
if Input.pressed(player, "cancel") then
  pendingCancel = true
end
```

------------------------------------------------------------------------

## `Input.is_down(player_id, key)`

Returns whether key is currently held.

``` lua
if Input.is_down(player, "left") then
  moveSelection(-1)
end
```

------------------------------------------------------------------------

## `Input.swallow(player_id, seconds)`

Ignores input for a duration.

``` lua
Input.swallow(player, 0.2)
```

------------------------------------------------------------------------

## `Input.require_release(player_id, keys)`

Prevents keys from generating new edges until released.

``` lua
Input.require_release(player, {"confirm", "cancel"})
```

------------------------------------------------------------------------

## `Input.clear_require_release(player_id, keys)`

Manually resets require-release state.

------------------------------------------------------------------------

## `Input.debug_dump_last_packet(player_id)`

Prints last packet debug information.

``` lua
Input.debug_dump_last_packet(player)
```

------------------------------------------------------------------------

## `Input.attach_virtual_input_listener([bindings])`

Must be called once at startup.

Default bindings example:

``` lua
local DEFAULT_BINDINGS = {
  confirm = { "Confirm", "A", "OK", "Accept", "Interact", "Use Card" },
  cancel  = { "Cancel", "Back", "B", "Shoot", "Run" },
  shoulderl = { "Shoulder L" },
  shoulderr = { "Shoulder R" },
  start     = { "Pause" },
  minimap   = { "Minimap" },
  options   = { "Option", "Special" },
  custommenu= { "Cust" },
  left    = { "UI Left", "Move Left", "Left" },
  right   = { "UI Right", "Move Right", "Right" },
  up      = { "UI Up", "Move Up", "Up" },
  down    = { "UI Down", "Move Down", "Down" },
}
```

Usage:

``` lua
local Input = require("input")
Input.attach_virtual_input_listener()
```

------------------------------------------------------------------------

# 🧩 Practical Usage Example

``` lua
local Input = require("input")

function init()
  Input.attach_virtual_input_listener()
end

function updatePlayer(player)
  if Input.pop(player, "confirm") then
    activateSelectedItem()
  end

  if Input.pop(player, "cancel") then
    goBack()
  end

  if Input.pop(player, "start") then
    togglePause()
  end

  local dx, dy = 0, 0
  if Input.is_down(player, "left")  then dx = dx - 1 end
  if Input.is_down(player, "right") then dx = dx + 1 end
  if Input.is_down(player, "up")    then dy = dy - 1 end
  if Input.is_down(player, "down")  then dy = dy + 1 end

  moveCursor(dx, dy)

  Input.consume(player)
end

function openPauseMenu()
  Input.swallow(player, 0.1)
  Input.require_release(player, {"confirm", "cancel"})
  showPauseUI()
end
```

------------------------------------------------------------------------

# ⚠ Edge Case Handling

-   Clients sending only `Held` → First `Held` treated as press
-   Clients omitting releases → Timeout clears non-dir keys
-   Scroll ignored for non-dir, repeat for dir
-   Swallow overrides everything

------------------------------------------------------------------------

# 🛠 Custom Bindings Example

``` lua
local myBindings = {
  confirm = { "Confirm", "A" },
  cancel  = { "Cancel", "B" },
  inventory = { "I", "Inventory" },
  left  = { "Left" },
  right = { "Right" },
  up    = { "Up" },
  down  = { "Down" },
}

Input.attach_virtual_input_listener(myBindings)
```

------------------------------------------------------------------------

# 🔍 Debugging Tips

``` lua
Input.DEBUG = true
Input.DEBUG_THROTTLE = 0.5
```

-   Use `DEBUG_CONFIRM_ONLY` to filter output
-   Use `debug_dump_last_packet()` for inspection

------------------------------------------------------------------------

# 🧬 Internal Functions (Reference)

-   `build_event_map(events)`
-   `resolve_group(map, names, promote_scroll)`
-   `refresh_non_dir_timeout(s)`

------------------------------------------------------------------------

## ✅ Summary

This module provides:

-   Reliable sticky-state input handling\
-   Clean edge detection\
-   Timeout-based safety for missing releases\
-   Flexible binding support\
-   Extensive debugging tools

Designed for robustness across Net Games forks while maintaining a clean
API for game logic.
