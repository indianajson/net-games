local TEMPLATE_TOURNAMENT_TABLE = {
    host_id               = "",
    tournament_id         = 0,
    tournament_nickname   = "",
    participant_count     = 0,
    status                = "INITIAL",
    participants          = {},
    round_1_matches       = {
        matchups = {},
        winners = {[1] = {}, [2] = {}, [3] = {}, [4] = {}},
        losers = {[1] = {}, [2] = {}, [3] = {}, [4] = {}},
    },
    round_2_matches       = {
        matchups = {},
        winners = {[1] = {}, [2] = {}},
        losers = {[1] = {}, [2] = {}},
    },
    round_3_matches       = {
        matchups = {},
        winners = {[1] = {}},
        losers = {[1] = {}},
    },
    area_id               = "",
    board_id              = 0,
    -- TODO: [board_ui_information] - fill in defaults
    board_ui_information  = {
        tournament_title  = "",
        title_banner      = {},
        board_background  = {},
        board_grid        = {},
        board_bracker     = {},
        crowns            = {},
        champion_topper   = {},
        mugshot_frame     = {},
    }
}

local function shallow_copy(original)
  local copy = {}

  for key, value in pairs(original) do
    copy[key] = value
  end

  return copy
end

local function updateOldWithNew(old, new)
    for key, newValue in pairs(new) do
        local oldValue = old[key]
        if oldValue ~= nil and type(oldValue) == type(newValue) then
            old[key] = newValue
        end
    end
    return old
end

function TEMPLATE_TOURNAMENT_TABLE.modify_value(tourney, value_name, new_value)
    local copy = shallow_copy(tourney)
    for name, value in next, copy do
        if name == value_name then
            print(name .. "exists")
            copy[name] = new_value
        end
    end
    return copy
end

function TEMPLATE_TOURNAMENT_TABLE.modify_values(tourney, new_values_table)
    local copy = shallow_copy(tourney)
    local result = updateOldWithNew(copy, new_values_table)
    return result
end

return TEMPLATE_TOURNAMENT_TABLE