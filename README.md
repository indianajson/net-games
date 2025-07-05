# Net Games (Overview)
An advanced script for making minigames on Open Net Battle servers.

### How does it work?
> The Net Games framework provides tools for creating mini-games and UI elements in an ONB servers. It handles player avatars, camera control, UI elements, text rendering, timers, and countdowns. This script is designed for **server coders** who are comfortable writing LUA scripts based on the ONB server API.
>
> At this time, it is <u>not useful for map makers who lack scripting experience</u>, though when Netflows is released that may change. 

### Installation
> 1. Copy `/scripts/net-games/` to your server script folder.
> 2. Copy `/assets/net-games/` to your server assets folder.
> 3. Include the following code at the start of your server's main LUA script.

```
local games = require("scripts/net-games/framework")
games.start_framework()
```

> You will then access the functions via the variable you specify. For example, if you use `games` as your variable (like the example above) you would access the functions with this variable appended to the beginning like so `games.activate_framework(player_id)`. 
 

### Features
> 1. Freeze player movement while still reporting button inputs. <br>
> &nbsp; &nbsp; For example, the moveable camera during Liberation Missions
> 2. Position sprites on screen relative to the player's camera <br>
> &nbsp; &nbsp; For example, add a persistent Order Points UIs during Liberation Missions <br>
> 3. Create custom selectors with customizable cursor sprites and positioning <br>
> &nbsp; &nbsp; For example, the liberate panel selector. <br>
> 4. Respond to currently hovered selection <br>
> &nbsp; &nbsp; For example, change highlighted tiles based on which power is hovered over during liberation tile selection. <br>
> 5. Show in-game timers <br>
> &nbsp; &nbsp; For example, you can have races and time trial leaderboards.
> 6. Show in-game countdowns <br>
> &nbsp; &nbsp; For example, the sixty second countdown used in BN3 for the CyberSimon Says <br>
> And much more!


# Net Games (Documentation)

### Click any header below to expand it. 

<details><summary><h3>Player Functions</h3></summary>

#### `activate_framework(player_id)`
> **Description**: Initializes the framework for a player (required before using any other function).  
> **Parameters**:
> - `player_id` (string): The ID of the player to activate the framework for

#### `deactivate_framework(player_id)`
> **Description**: Removes all framework elements for a player and restores their original avatar.  
> **Parameters**:
> - `player_id` (string): The ID of the player to deactivate the framework for

#### `freeze_player(player_id)`
> **Description**: Freezes the player's movement while preserving input access.  
> **Parameters**:
> - `player_id` (string): The ID of the player to freeze  

#### `unfreeze_player(player_id)`
> **Description**: Releases a player from being frozen, returning them to their original position.  
> **Parameters**:
> - `player_id` (string): The ID of the player to unfreeze

#### `move_frozen_player(player_id, X, Y, Z)`
> **Description**: Instantly moves a frozen player to specified coordinates without animation.  
> **Parameters**:
> - `player_id` (string): The ID of the frozen player
> - `X`, `Y`, `Z` (number): Target coordinates

#### `walk_frozen_player(player_id, X, Y, Z, duration, wait)`
> **Description**: Moves a frozen player to coordinates with walking animation.  
> **Parameters**:
> - `player_id` (string): The ID of the frozen player
> - `X`, `Y`, `Z` (number): Target coordinates
> - `duration` (number): Animation duration in seconds
> - `wait` (boolean): Whether to wait for animation to complete  

#### `animate_frozen_player(player_id, animation_state)`
> **Description**: Plays an animation on the frozen player's avatar.  
> **Parameters**:
> - `player_id` (string): The ID of the frozen player
> - `animation_state` (string): Name of animation state to play

#### `get_frozen_player_id(player_id)`
> **Description**: Returns the bot ID of a player's frozen avatar.  
> **Parameters**:
> - `player_id` (string): The ID of the frozen player
> 
> **Returns**: Bot ID string
</details>

<details><summary><h3>Camera Functions</h3></summary>

#### `set_camera_position(player_id, X, Y, Z)`
> **Description**: Instantly moves the player's camera to specified coordinates.  
> **Parameters**:
> - `player_id` (string): The ID of the player
> - `X`, `Y`, `Z` (number): Target coordinates

#### `reset_camera_position(player_id)`
> **Description**: Returns camera to track the player's avatar.  
> **Parameters**:
> - `player_id` (string): The ID of the player

<!--
#### `slide_camera_position(player_id, X, Y, Z, duration)`
**Description**: Smoothly slides camera to coordinates over duration.  
**Parameters**:
- `player_id` (string): The ID of the player
- `X`, `Y`, `Z` (number): Target coordinates
- `duration` (number): Animation duration in seconds
-->
</details><details><summary><h3>UI Functions</h3></summary>

#### `add_ui_element(name, player_id, texture, animation, animation_state, horizontalOffset, verticalOffset, Z)`
> **Description**: Adds a UI element that tracks with the camera view.  
> **Parameters**:
> - `name` (string): Unique identifier for the element
> - `player_id` (string): The ID of the player
> - `texture` (string): Path to texture file
> - `animation` (string): Path to animation file
> - `animation_state` (string): Initial animation state
> - `horizontalOffset`, `verticalOffset` (number): Screen position offsets
> - `Z` (number): Z-index relative to UI (not player)

#### `change_ui_element(name, player_id, animation_state, loop)`
> **Description**: Changes the animation state of a UI element.  
> **Parameters**:
> - `name` (string): Identifier of the element to change
> - `player_id` (string): The ID of the player
> - `animation_state` (string): New animation state
> - `loop` (boolean): Whether to loop the animation

#### `move_ui_element(name, player_id, horizontalOffset, verticalOffset, Z)`
> **Description**: Moves a UI element to new screen position.  
> **Parameters**:
> - `name` (string): Identifier of the element to move
> - `player_id` (string): The ID of the player
> - `horizontalOffset`, `verticalOffset` (number): New screen position offsets
> - `Z` (number): Z-index relative to UI (not player)

#### `remove_ui_element(player_id, name)`
> **Description**: Removes a UI element.  
> **Parameters**:
> - `player_id` (string): The ID of the player
> - `name` (string): Identifier of the element to remove
</details>
<details>
 
<summary><h3>Cursor Functions</h3></summary>

#### `spawn_cursor(cursor_id, player_id, options)`
> **Description**: Creates a multi-choice cursor based on `options`.  
> **Parameters**:
> - `cursor_id` (string): Unique identifier
> - `player_id` (string): The ID of the player
> - `options` (table): Configuration including texture, animation, and selections  

The options table should include a movement direction and selections table 
`movement = "horizontal", 
selections = {
   { v=0,h=-0,z=0,name='',texture="",animation="",state=""  },
   { v=0,h=0,z=0,name='',texture="",animation="",state=""  },
   { v=0,h=0,z=0,name='',texture="",animation="",state="" }
}`

The `movement` parameter can be `horizontal`, `vertical`, or `shoulder`. If `horizontal` the cursor moves when Left or Right is pressed. If vertical the cursor moves if Up or Down. If shoulder the cursor moves when Left Shoulder is pressed.

The `selections` table defines each position the cursor can occupy. The `v`, `h`, and `z` parameters specify location (relative to screen); the `z` is relative to the UI not the player. See the section at the bottom of the documentation labeled `Z-Index Information`. The `name` is how you will identify the selection. The `cursor_hover` and `cursor_selection` will emit the name so you can react based on the player's selection. The `texture` (image file path), `animation` (.animation file path), and `state` (animation state) allows you to control the cursor appearance for every position.


#### `remove_cursor(cursor_id, player_id)`
> **Description**: Removes a cursor UI.  
> **Parameters**:
> - `cursor_id` (string): Identifier of cursor to remove
> - `player_id` (string): The ID of the player
</details>
<details>
 
<summary><h3>Text Functions</h3></summary>

#### `write_text(text_id, player_id, font, color, text, verticalOffset, horizontalOffset, Z)`
> **Description**: Renders text on screen.  
> **Parameters**:
> - `text_id` (string): Unique identifier
> - `player_id` (string): The ID of the player
> - `font` (string): Font style name
> - `color` (string): Text color
> - `text` (string): Content to display
> - `verticalOffset`, `horizontalOffset` (number): Screen position
> - `Z` (number): Z-index relative to UI (not player)

#### `erase_text(text_id, player_id)`
> **Description**: Removes rendered text.  
> **Parameters**:
> - `text_id` (string): Identifier of text to remove
> - `player_id` (string): The ID of the player
</details>
<details>
 
<summary><h3>Countdown and Timer Functions</h3></summary>

#### `spawn_countdown(player_id, horizontalOffset, verticalOffset, Z, duration)`
> **Description**: Creates a countdown display counting down to zero.  
> **Parameters**:
> - `player_id` (string): The ID of the player
> - `horizontalOffset`, `verticalOffset` (number): Screen position
> - `Z` (number): Z-index relative to UI (not player)
> - `duration` (number): Initial time in seconds

#### `start_countdown(player_id)`
> **Description**: Starts a paused countdown.  
> **Parameters**:
> - `player_id` (string): The ID of the player

#### `pause_countdown(player_id)`
> **Description**: Pauses an active countdown.  
> **Parameters**:
> - `player_id` (string): The ID of the player
> 
> **Returns**: Remaining time in seconds

#### `remove_countdown(player_id)`
> **Description**: Removes a countdown display.  
> **Parameters**:
> - `player_id` (string): The ID of the player

#### `spawn_timer(player_id, horizontalOffset, verticalOffset, Z)`
> **Description**: Creates a timer display counting up from zero.  
> **Parameters**:
> - `player_id` (string): The ID of the player
> - `horizontalOffset`, `verticalOffset` (number): Screen position
> - `Z` (number): Z-index relative to UI (not player)

#### `start_timer(player_id)`
> **Description**: Starts a paused timer.  
> **Parameters**:
> - `player_id` (string): The ID of the player

#### `pause_timer(player_id)`
> **Description**: Pauses an active timer.  
> **Parameters**:
> - `player_id` (string): The ID of the player
>
> **Returns**: Current time in seconds

#### `remove_timer(player_id)`
> **Description**: Removes a timer display.  
> **Parameters**:
> - `player_id` (string): The ID of the player
</details>
<details>
<summary><h3>Game Events</h3></summary>

#### `Game:on("button_press", function(event) end)`
> **Description**: Emitted whenever a player presses a button.  
> **Event Data**:
> - `player_id` (string): The ID of the player
> - `button` (string): Button name ("A", "LS", "D", "U", "L", or "R")

#### `Game:on("cursor_selection", function(event) end)`
> **Description**: Emitted when cursor selection is confirmed.  
> **Event Data**:
> - `player_id` (string): The ID of the player
> - `cursor` (string): Cursor identifier
> - `selection` (table): Selected option data

#### `Game:on("cursor_hover", function(event) end)`
> **Description**: Emitted when cursor hovers over a new selection.  
> **Event Data**:
> - `player_id` (string): The ID of the player
> - `cursor` (string): Cursor identifier
> - `selection` (table): Hovered option data

#### `Game:on("countdown_ended", function(event) end)`
> **Description**: Emitted when countdown reaches zero for a given player.  
> **Event Data**:
> - `player_id` (string): The ID of the player
</details>

## Z-Index Information

For any of the functions that tell you the Z variable is relative to UI this is different than the normal Z index related to the map. For these functions, if you provide Z = 0, it actually sets the Z to 100 (to keep it above all map elements). By putting in Z = -1 the Z becomes 99 (so it is still above the map but below any UI elements at Z = 0). By putting in Z = 1 the Z becomes 101 putting it above the elements which have Z = 0. 
