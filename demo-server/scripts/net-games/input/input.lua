-- scripts/net-games/input/input.lua
--
-- Net Games Input Helper (sticky-state)
-- - Listens to Net:on("virtual_input") once
-- - Tracks per-player edge presses (confirm/cancel/dpad)
-- - **Now also tracks release edges** (transition from down to up)
-- - IMPORTANT: missing keys in event.events do NOT imply released
--
-- Input states (per docs):
--   1 = Pressed
--   2 = Held
--   3 = Released
-- Some forks also emit:
--   4 = Scroll (repeat pulse)
--
-- Supports BOTH event.events formats:
--   A) array: { {name="Confirm", state=1}, {name="UI Left", state=3} }
--   B) map:   { ["Confirm"]=1, ["UI Left"]=2 }
--
-- Key behavior:
-- - confirm/cancel: POP once per down. (Never repeat on hold. Scroll ignored.)
-- - directions: POP on down + repeat on Scroll pulses while held.
-- - All other non‑directional keys (shoulderl, shoulderr, start, minimap, options, custommenu)
--   behave exactly like confirm/cancel.
-- - Release events are generated whenever a key transitions from down to up
--   (including timeout‑based release for non‑dir keys).
--
-- DIRECTION COMBOS (new):
--   - get_active_direction() returns combined directions like "upleft", "downright", etc.
--   - Stateful memory prevents flickering when one axis is briefly released.
--   - Falls back to a single direction when multiple non‑combo directions are held.
--
-- Also supports:
-- - swallow(player_id, seconds): ignore input briefly + clear edges and releases
-- - require_release(player_id, {"confirm"}): ignore edges until a release is observed

local Input = {}

local LISTENER_ATTACHED = false
local st = {}

--=====================================================
-- Debug toggles
--=====================================================
Input.DEBUG = false                -- master debug
Input.DEBUG_THROTTLE = 0          -- seconds; 0 = no throttle
Input.DEBUG_CONFIRM_ONLY = false  -- if true, prints only when confirm group appears in packet
Input.DEBUG_DUMP_PACKET = false    -- if true, prints interpreted map each packet (noisy)

local function now() return os.clock() end

-- How long we wait without seeing a non‑directional key before treating it as "up".
-- Missing keys in event.events do NOT imply released.
local NON_DIR_UP_TIMEOUT = 0.06

-- Default bindings: map internal keys to lists of possible event names.
-- Extended with missing bindings from buttons.lua.
local DEFAULT_BINDINGS = {
  -- confirm & cancel with extra aliases from buttons.lua
  confirm = { "Confirm", "A", "OK", "Accept", "Interact", "Use Card" },
  cancel  = { "Cancel", "Back", "B", "Shoot", "Run" },
  -- new non‑directional keys from buttons.lua
  shoulderl = { "Shoulder L" },
  shoulderr = { "Shoulder R" },
  start     = { "Pause" },
  minimap   = { "Minimap" },
  options   = { "Option", "Special" },
  custommenu= { "Cust" },
  -- directions (unchanged)
  left    = { "UI Left", "Move Left", "Left" },
  right   = { "UI Right", "Move Right", "Right" },
  up      = { "UI Up", "Move Up", "Up" },
  down    = { "UI Down", "Move Down", "Down" },
}

-- Direction combos (diagonals) for combined direction detection
local DIRECTION_COMBOS = {
    upleft    = { "up", "left" },
    upright   = { "up", "right" },
    downleft  = { "down", "left" },
    downright = { "down", "right" },
}

-- Build lists of all keys and non‑directional keys for dynamic iteration
local ALL_KEYS = {}
local NON_DIR_KEYS = {}
for k, _ in pairs(DEFAULT_BINDINGS) do
  table.insert(ALL_KEYS, k)
  if k ~= "left" and k ~= "right" and k ~= "up" and k ~= "down" then
    table.insert(NON_DIR_KEYS, k)
  end
end

local function refresh_non_dir_timeout(s)
  local t = now()
  for _, k in ipairs(NON_DIR_KEYS) do
    if s.down[k] and t >= (s.non_dir_down_until[k] or 0) then
      -- Key timed out -> generate release event
      s.released[k] = true
      s.down[k] = false
      s.non_dir_armed[k] = true
    end
  end
end

local function ensure(player_id)
  if not st[player_id] then
    local s = {
      edge = {},
      released = {},          -- release flags (true if key was just released)
      swallow_until = 0,
      require_release = {},

      -- non‑dir latch: we synthesize an "up" if we stop seeing the key for a bit
      non_dir_down_until = {},
      non_dir_armed      = {},

      down = {},

      -- combo state for direction memory
      combo = {
        last = nil,
        last_keys = {},
        active = false,
      },

      last_print = 0,
      seen_states = {},
      seen_names = {},

      last_shape = "(none)",
      last_map = {},
      last_raw_count = 0,
    }
    -- Initialise tables for all keys
    for _, k in ipairs(ALL_KEYS) do
      s.down[k] = false
      s.edge[k] = nil
      s.released[k] = nil
      if k ~= "left" and k ~= "right" and k ~= "up" and k ~= "down" then
        s.non_dir_down_until[k] = 0
        s.non_dir_armed[k] = true
      end
    end
    st[player_id] = s
  end
  return st[player_id]
end

local function state_word(s)
  if s == 1 then return "Pressed" end
  if s == 2 then return "Held" end
  if s == 3 then return "Released" end
  if s == 4 then return "Scroll" end
  return "INVALID"
end

local function normalize_state(s)
  if s == 1 or s == 2 or s == 3 or s == 4 then return s end
  if type(s) == "string" then
    local t = s:lower()
    if t == "pressed" then return 1 end
    if t == "held" then return 2 end
    if t == "released" then return 3 end
    if t == "scroll" then return 4 end
  end
  return nil
end

local function is_pressed(s)  return s == 1 end
local function is_held(s)     return s == 2 end
local function is_released(s) return s == 3 end
local function is_scroll(s)   return s == 4 end

local function is_dir_key(k)
  return k == "left" or k == "right" or k == "up" or k == "down"
end

-- Detect payload shape and build map of ONLY events present this packet (name -> normalized state)
local function build_event_map(events)
  local map = {}
  if events == nil then
    return map, "nil", 0
  end

  -- Shape A: array of objects
  if type(events) == "table" and type(events[1]) == "table" and events[1].name ~= nil then
    local count = 0
    for _, e in ipairs(events) do
      count = count + 1
      local ns = normalize_state(e.state)
      if e.name ~= nil and ns ~= nil then
        map[e.name] = ns
      end
    end
    return map, "array", count
  end

  -- Shape B: dictionary name->state
  if type(events) == "table" then
    local count = 0
    for name, state in pairs(events) do
      count = count + 1
      local ns = normalize_state(state)
      if name ~= nil and ns ~= nil then
        map[name] = ns
      end
    end
    return map, "map", count
  end

  return map, type(events), 0
end

-- For a binding group, compute:
--   down_change: true/false/nil (nil = no change this packet)
--   saw_pressed/saw_held/saw_scroll
-- promote_scroll_to_held: ONLY true for directional groups
local function resolve_group(map, names, promote_scroll_to_held)
  local saw_pressed  = false
  local saw_held     = false
  local saw_released = false
  local saw_scroll   = false

  for _, n in ipairs(names or {}) do
    local s = map[n]
    if s ~= nil then
      if is_pressed(s)  then saw_pressed  = true end
      if is_held(s)     then saw_held     = true end
      if is_released(s) then saw_released = true end
      if is_scroll(s) then
        saw_scroll = true
        if promote_scroll_to_held then
          saw_held = true
        end
      end
    end
  end

  if saw_pressed or saw_held then
    return true, saw_pressed, saw_held, saw_scroll
  end

  if saw_released then
    return false, false, false, saw_scroll
  end

  return nil, false, false, saw_scroll
end

local function dbg_ok_to_print(s)
  if not Input.DEBUG then return false end
  if not Input.DEBUG_THROTTLE or Input.DEBUG_THROTTLE <= 0 then return true end
  local t = now()
  if (t - (s.last_print or 0)) < Input.DEBUG_THROTTLE then
    return false
  end
  s.last_print = t
  return true
end

local function map_to_string(map)
  local parts = {}
  for name, stv in pairs(map or {}) do
    local w = state_word(stv)
    table.insert(parts, tostring(name) .. "=" .. w)
  end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function any_binding_present(map, binding_list)
  for _, n in ipairs(binding_list or {}) do
    if map[n] ~= nil then return true end
  end
  return false
end

--=====================================================
-- Public API
--=====================================================

function Input.consume(player_id)
  local s = ensure(player_id)
  s.edge = {}
  s.released = {}   -- also clear release flags
end

function Input.pop(player_id, key)
  local s = ensure(player_id)
  refresh_non_dir_timeout(s)
  if s.edge[key] then
    s.edge[key] = nil
    return true
  end
  return false
end

function Input.pressed(player_id, key)
  local s = ensure(player_id)
  return s.edge[key] == true
end

-- Returns true if the key was released (edge) without consuming
function Input.released(player_id, key)
  local s = ensure(player_id)
  refresh_non_dir_timeout(s)
  return s.released[key] == true
end

-- Returns true and clears the release flag (consumes it)
function Input.pop_released(player_id, key)
  local s = ensure(player_id)
  refresh_non_dir_timeout(s)
  if s.released[key] then
    s.released[key] = nil
    return true
  end
  return false
end

function Input.is_down(player_id, key)
  local s = ensure(player_id)
  refresh_non_dir_timeout(s)
  return s.down[key] == true
end

function Input.swallow(player_id, seconds)
  local s = ensure(player_id)
  s.swallow_until = math.max(s.swallow_until or 0, now() + (seconds or 0))
  s.edge = {}
  s.released = {}   -- also clear releases
end

function Input.require_release(player_id, keys)
  local s = ensure(player_id)
  for _, k in ipairs(keys or {}) do
    s.require_release[k] = true
  end
end

function Input.clear_require_release(player_id, keys)
  local s = ensure(player_id)
  for _, k in ipairs(keys or {}) do
    s.require_release[k] = nil
    s.non_dir_armed[k] = true
    if s.non_dir_down_until and s.non_dir_down_until[k] ~= nil then
      s.non_dir_down_until[k] = 0
    end
    if s.down and s.down[k] ~= nil then
      s.down[k] = false
    end
  end
end

--[[
  Returns the current active direction or diagonal combo for the player.
  Possible return values:
    "left", "right", "up", "down",
    "upleft", "upright", "downleft", "downright",
    or nil if no direction is held.

  Uses stateful memory: if a combo was active and one axis is briefly released,
  the combo persists until both are released or a new valid direction appears.
]]
function Input.get_active_direction(player_id)
    local s = ensure(player_id)

    -- Get current down directions
    local down_dirs = {}
    for _, dir in ipairs({"left","right","up","down"}) do
        if s.down[dir] then
            down_dirs[dir] = true
        end
    end

    -- Convert to list
    local dir_list = {}
    for dir, _ in pairs(down_dirs) do
        table.insert(dir_list, dir)
    end
    local num_down = #dir_list

    -- No directions
    if num_down == 0 then
        s.combo.active = false
        s.combo.last = nil
        s.combo.last_keys = {}
        return nil
    end

    -- Single direction
    if num_down == 1 then
        s.combo.active = false
        s.combo.last = nil
        s.combo.last_keys = {}
        return dir_list[1]
    end

    -- Check for valid combos
    local current_combo = nil
    for combo_name, required in pairs(DIRECTION_COMBOS) do
        local all_pressed = true
        for _, dir in ipairs(required) do
            if not down_dirs[dir] then
                all_pressed = false
                break
            end
        end
        if all_pressed then
            current_combo = combo_name
            break
        end
    end

    if current_combo then
        -- Valid combo found
        s.combo.active = true
        s.combo.last = current_combo
        s.combo.last_keys = {}
        for _, dir in ipairs(DIRECTION_COMBOS[current_combo]) do
            s.combo.last_keys[dir] = true
        end
        return current_combo
    end

    -- No valid combo, but multiple directions pressed.
    -- Use memory: if we were in a combo and some of those keys are still pressed,
    -- keep returning that combo to avoid flickering.
    if s.combo.active and s.combo.last then
        local still_pressed = 0
        for dir, _ in pairs(s.combo.last_keys) do
            if down_dirs[dir] then
                still_pressed = still_pressed + 1
            end
        end
        if still_pressed >= 2 and num_down >= 2 then
            -- At least two of the original combo keys are still down
            return s.combo.last
        else
            -- Combo broken
            s.combo.active = false
            s.combo.last = nil
            s.combo.last_keys = {}
        end
    end

    -- Fallback: return the first direction (alphabetical order)
    table.sort(dir_list)
    return dir_list[1]
end

-- Resets the direction combo memory for a player (useful when changing levels or game states)
function Input.reset_direction_state(player_id)
    local s = ensure(player_id)
    s.combo = {
        last = nil,
        last_keys = {},
        active = false,
    }
end

function Input.debug_dump_last_packet(player_id)
  local s = ensure(player_id)
  print("[InputDBG] player=" .. tostring(player_id) ..
    " last_shape=" .. tostring(s.last_shape) ..
    " raw_count=" .. tostring(s.last_raw_count) ..
    " map=" .. map_to_string(s.last_map))
  local function b(x) return x and "true" or "false" end
  -- dump down state for all keys
  local down_parts = {}
  for _, k in ipairs(ALL_KEYS) do
    table.insert(down_parts, k .. "=" .. b(s.down[k]))
  end
  print("[InputDBG] down: " .. table.concat(down_parts, " "))
  -- dump edge state for all keys
  local edge_parts = {}
  for _, k in ipairs(ALL_KEYS) do
    table.insert(edge_parts, k .. "=" .. b(s.edge[k]))
  end
  print("[InputDBG] edge: " .. table.concat(edge_parts, " "))
  -- dump release state for all keys
  local release_parts = {}
  for _, k in ipairs(ALL_KEYS) do
    table.insert(release_parts, k .. "=" .. b(s.released[k]))
  end
  print("[InputDBG] release: " .. table.concat(release_parts, " "))
end

function Input.attach_virtual_input_listener(bindings)
  if LISTENER_ATTACHED then
    print("[Input] listener already attached")
    return
  end
  LISTENER_ATTACHED = true
  print("[Input] attaching Net:on('virtual_input') listener")

  bindings = bindings or DEFAULT_BINDINGS

  Net:on("virtual_input", function(event)
    local player_id = event.player_id
    local s = ensure(player_id)
    local t = now()

    -- swallow window: ignore packets completely
    if s.swallow_until and t < s.swallow_until then
      if Input.DEBUG and dbg_ok_to_print(s) then
        print("[InputDBG] SWALLOWED packet player=" .. tostring(player_id))
      end
      return
    end

    local map, shape, raw_count = build_event_map(event.events)
    s.last_shape = shape
    s.last_raw_count = raw_count
    s.last_map = map

    -- track seen states/names for discovery
    for name, stv in pairs(map) do
      s.seen_names[name] = true
      s.seen_states[stv] = true
    end

    -- Apply group logic for every key in our binding set
    for _, k in ipairs(ALL_KEYS) do
      local down_change, saw_pressed, saw_held, saw_scroll =
        resolve_group(map, bindings[k], is_dir_key(k))

      --=====================================================
      -- NON-DIRECTION KEYS: POP once per down.
      -- IMPORTANT: IGNORE Scroll completely for non‑dir keys.
      -- Some clients never emit Pressed; they jump straight to Held.
      -- So: allow Held to create an edge ONLY if we were previously up.
      --=====================================================
      if not is_dir_key(k) then
        local saw_down_signal = saw_pressed or (saw_held and not s.down[k])

        if s.require_release[k] then
          if saw_down_signal then
            s.non_dir_down_until[k] = t + NON_DIR_UP_TIMEOUT
            s.down[k] = true
          elseif t >= (s.non_dir_down_until[k] or 0) then
            -- Release due to timeout
            if s.down[k] then
              s.released[k] = true
            end
            s.down[k] = false
            s.non_dir_armed[k] = true
            s.require_release[k] = nil
          end

        else
          if saw_down_signal then
            s.non_dir_down_until[k] = t + NON_DIR_UP_TIMEOUT

            if (not s.down[k]) and s.non_dir_armed[k] then
              s.edge[k] = true
              s.non_dir_armed[k] = false
            end

            s.down[k] = true

          elseif t >= (s.non_dir_down_until[k] or 0) then
            -- Release due to timeout
            if s.down[k] then
              s.released[k] = true
            end
            s.down[k] = false
            s.non_dir_armed[k] = true
          end
        end

      --=====================================================
      -- DIRECTIONS: sticky down state + repeat on Scroll pulses
      --=====================================================
      else
        if s.require_release[k] then
          if down_change == false then
            if s.down[k] then
              s.released[k] = true
            end
            s.require_release[k] = nil
            s.down[k] = false
          else
            if down_change ~= nil then
              local was = s.down[k]
              s.down[k] = down_change
              if down_change == true and not was then
                s.edge[k] = true
              end
              if down_change == false and was then
                s.released[k] = true
              end
            end
          end

        else
          if down_change ~= nil then
            local was = s.down[k]
            s.down[k] = down_change
            if down_change == true and not was then
              s.edge[k] = true
            end
            if down_change == false and was then
              s.released[k] = true
            end
          end

          -- repeat while held (Scroll pulses)
          if saw_scroll and s.down[k] then
            s.edge[k] = true
          end
        end
      end
    end

    if Input.DEBUG and dbg_ok_to_print(s) then
      local confirm_present = any_binding_present(map, bindings.confirm)
      if (not Input.DEBUG_CONFIRM_ONLY) or confirm_present then
        local function b(x) return x and "true" or "false" end

        -- Build edge string for all keys
        local edge_parts = {}
        for _, k in ipairs(ALL_KEYS) do
          table.insert(edge_parts, k .. "=" .. b(s.edge[k]))
        end

        print("[InputDBG] player=" .. tostring(player_id) ..
          " shape=" .. tostring(shape) ..
          " raw_count=" .. tostring(raw_count) ..
          " confirm_present=" .. tostring(confirm_present))

        print("[InputDBG] edges: " .. table.concat(edge_parts, " "))

        if Input.DEBUG_DUMP_PACKET then
          print("[InputDBG] packet_map=" .. map_to_string(map))
        end
      end
    end
  end)
end

return Input