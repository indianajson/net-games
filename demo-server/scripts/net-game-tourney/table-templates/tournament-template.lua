local tblutils = require("scripts/table-utils")

local TEMPLATE_TOURNAMENT_TABLE = {
    tournament_id = 0,
    tournament_nickname = "Default Tournament",
    participant_count = 0,
    max_participants = 8,
    status = "INITIAL",
    participants = {},
    current_round = 0,
    matches = {},
    winners = {},
    round_1_results = {},
    round_2_results = {},
    round_3_results = {},
    area_id = "",
    board_id = 0,
    board_ui_information = {
        tournament_title = "Tournament",
        title_banner = { texture = "", animation = "" },
        board_background = { texture = "", animation = "" },
        board_grid = { texture = "", animation = "" },
        board_bracket = { texture = "", animation = "" },
        crowns = { texture = "", animation = "" },
        champion_topper = { texture = "", animation = "" },
        mugshot_frame = { texture = "", animation = "" },
    },
    created_time = 0,
    last_updated = 0
}

-- ... existing utility functions ...

function TEMPLATE_TOURNAMENT_TABLE.create_from_template(tournament_nickname, area_id, board_id)
    local new_tournament = tblutils.shallow_copy(TEMPLATE_TOURNAMENT_TABLE)
    new_tournament.tournament_nickname = tournament_nickname or "New Tournament"
    new_tournament.area_id = area_id or ""
    new_tournament.board_id = board_id or 0
    new_tournament.created_time = os.time()
    new_tournament.last_updated = os.time()
    return new_tournament
end

function TEMPLATE_TOURNAMENT_TABLE.validate_participant(participant)
    return participant and
        participant.player_id and
        participant.player_mugshot and
        participant.player_mugshot.mug_texture and
        participant.player_mugshot.mug_animation
end

return TEMPLATE_TOURNAMENT_TABLE
