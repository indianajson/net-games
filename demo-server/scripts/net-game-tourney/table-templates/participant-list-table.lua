local participant_info = require("scripts/net-game-tourney/table-templates/participant-table")
local exclusionary = require("scripts/net-game-tourney/table-templates/exclusionary-deep-copy")

local PARTICIPANT_LIST_TABLE = {

}

local function fill_participant_list()
    local copy = exclusionary.deepCopy(PARTICIPANT_LIST_TABLE)
    local final = exclusionary.deepCopy(participant_info, {modify_value =  true, modify_values = true})
    for i, p in next, copy do
        copy[i] = final
    end
    PARTICIPANT_LIST_TABLE = copy
end

fill_participant_list()

return PARTICIPANT_LIST_TABLE