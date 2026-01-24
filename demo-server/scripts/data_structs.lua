local ColorMode = {
  MULT = 0,  -- Multiply (default)
  ADD = 1,   -- Addititve
  COLOR = 2, -- Colorize
}

local BattleItem = {
  MONEY = 0,
  CARD = 1,
  HEALTH = 2,
  FRAGMENT = 3
}

-- Virtual input events and states
local InputState = {
  NONE = 0,
  PRESSED = 1,
  HELD = 2,
  RELEASED = 3
}

local InputEvent = {
  ---
  --- OW Events
  ---
  RUN = "Run",
  INTERACT = "Interact",
  MINIMAP = "Minimap",
  ---
  --- Battle Events
  --- 
  SHOOT = "Shoot",
  USE_CARD = "Use Card",
  SPECIAL = "Special",
  CUST_MENU = "Cust Menu",
  PAUSE = "Pause",
  ---
  --- Shared Battle & OW Events
  ---
  MOVE_UP = "Move Up",
  MOVE_DOWN = "Move Down",
  MOVE_LEFT = "Move Left",
  MOVE_RIGHT = "Move Right",
  SHOULDER_L = "Shoulder L",
  SHOULDER_R = "Shoulder R",
  ---
  --- UI Events
  ---
  UI_UP = "UI Up",
  UI_DOWN = "UI Down",
  UI_LEFT = "UI Left",
  UI_RIGHT = "UI Right",
  CONFIRM = "Confirm",
  CANCEL = "Cancel",
  OPTION = "Option",
  --- 
  --- META
  --- 
  LEN = 21
}

return {
  ColorMode=ColorMode,
  BattleItem=BattleItem,
  InputState=InputState,
  InputEvent=InputEvent,
}