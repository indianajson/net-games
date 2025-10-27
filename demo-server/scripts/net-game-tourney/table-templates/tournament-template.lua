local TEMPLATE_TOURNAMENT_TABLE = {
    tournament_id       = 0,
    tournament_nickname = "",
    participant_count   = 0,
    status              = "INITIAL",
    participants        = {},
    round_1_results     = {},
    round_2_results     = {},
    round_3_results     = {},
    area_id             = "",
    board_id            = 0,
    board_ui_information = {
        tournament_title = "",
        title_banner     = {},
        board_background = {},
        board_grid       = {},
        board_bracker    = {},
        crowns           = {},
        champion_topper  = {},
        mugshot_frame    = {},
    }
}

local function shallow_copy(original)
    local copy = {}
    for k, v in pairs(original) do copy[k] = v end
    return copy
end

local function updateOldWithNew(old, new)
    for key, val in pairs(new) do
        if old[key] ~= nil and type(old[key]) == type(val) then old[key] = val end
    end
    return old
end

function TEMPLATE_TOURNAMENT_TABLE.modify_value(tourney, value_name, new_value)
    local copy = shallow_copy(tourney)
    copy[value_name] = new_value
    return copy
end

function TEMPLATE_TOURNAMENT_TABLE.modify_values(tourney, new_values_table)
    local copy = shallow_copy(tourney)
    return updateOldWithNew(copy, new_values_table)
end

return TEMPLATE_TOURNAMENT_TABLE
