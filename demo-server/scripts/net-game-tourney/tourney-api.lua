-- EXAMPLE USAGE
-- Simple tournament creation
--local tournament_id = await(TournamentAPI.create_quick_tournament(
--    player_id, 
--    area_id, 
--    board_id, 
--    {player_id, "other_player_id"} -- Fill rest with NPCs
--))
--
---- Custom tournament with specific NPCs
--local tournament_id = await(TournamentAPI.create_tournament({
--    name = "Elite Tournament",
--    area_id = area_id,
--    board_id = board_id,
--    host_player_id = player_id,
--    board_theme = "blue_bn4"
--}))
--
--await(TournamentAPI.add_player(tournament_id, player_id))
--await(TournamentAPI.add_npc(tournament_id, "/server/assets/tourney/npc-navis-testing/protoman/protoman1.zip"))
--await(TournamentAPI.add_npc(tournament_id, "/server/assets/tourney/npc-navis-testing/colonel/colonel1.zip"))
--
--await(TournamentAPI.start_tournament(tournament_id))
--
---- Event handling
--TournamentAPI.events.tournament_completed:on(function(event)
--    print("Tournament completed! Winner: " .. event.winner.player_id)
--end)

-- tournament-api.lua
local TournamentAPI = {}
local games = require("scripts/net-games/framework")

-- Internal references to existing systems
local TournamentState = require("scripts/net-game-tourney/tournament-state")
local TournamentUtils = require("scripts/net-game-tourney/tournament-utils")
local TourneyEmitters = require("scripts/net-game-tourney/emitters")

-- API Events for external consumers
TournamentAPI.events = {
    tournament_created = Net.EventEmitter.new(),
    tournament_started = Net.EventEmitter.new(),
    round_started = Net.EventEmitter.new(),
    match_started = Net.EventEmitter.new(),
    match_completed = Net.EventEmitter.new(),
    round_completed = Net.EventEmitter.new(),
    tournament_completed = Net.EventEmitter.new(),
    participant_eliminated = Net.EventEmitter.new()
}

-- Tournament Creation and Configuration
function TournamentAPI.create_tournament(options)
    return async(function()
        local defaults = {
            name = "Tournament",
            area_id = nil,
            board_id = nil,
            host_player_id = nil,
            max_participants = 8,
            backfill_npcs = true,
            tournament_type = "single", -- "single" or "multiplayer"
            board_theme = "red_orange_bn4" -- default theme
        }
        
        local config = TableUtils.shallow_copy(defaults)
        for k, v in pairs(options or {}) do
            config[k] = v
        end
        
        if not config.area_id or not config.board_id then
            error("Tournament requires area_id and board_id")
        end
        
        local tournament_id = TournamentState.create_tournament(
            config.board_id, 
            config.area_id, 
            config.host_player_id
        )
        
        -- Store configuration
        local tournament = TournamentState.get_tournament(tournament_id)
        tournament.config = config
        
        TournamentAPI.events.tournament_created:emit({
            tournament_id = tournament_id,
            config = config
        })
        
        return tournament_id
    end)
end

-- Participant Management
function TournamentAPI.add_player(tournament_id, player_id, mugshot_data)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return false end
        
        -- Get mugshot if not provided
        if not mugshot_data then
            local player_mugshot = Net.get_player_mugshot(player_id)
            mugshot_data = {
                mug_texture = player_mugshot.texture_path,
                mug_animation = "/server/assets/tourney/mug.anim"
            }
        end
        
        local participant = {
            player_id = player_id,
            player_mugshot = mugshot_data
        }
        
        local success = TournamentState.add_participant(tournament_id, participant)
        
        if success then
            print("[TournamentAPI] Added player: " .. player_id)
        end
        
        return success
    end)
end

function TournamentAPI.add_npc(tournament_id, npc_template_or_id)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return false end
        
        local npc_data
        local npc_paths = require("scripts/net-game-tourney/npc-paths")
        
        if type(npc_template_or_id) == "string" then
            -- Find NPC by ID in npc_paths
            for _, npc in ipairs(npc_paths) do
                if npc.player_id == npc_template_or_id then
                    npc_data = TableUtils.shallow_copy(npc)
                    break
                end
            end
        else
            -- Use provided template
            npc_data = TableUtils.shallow_copy(npc_template_or_id)
        end
        
        if not npc_data then
            print("[TournamentAPI] NPC not found: " .. tostring(npc_template_or_id))
            return false
        end
        
        local success = TournamentState.add_participant(tournament_id, npc_data)
        
        if success then
            print("[TournamentAPI] Added NPC: " .. npc_data.player_id)
        end
        
        return success
    end)
end

function TournamentAPI.remove_participant(tournament_id, participant_id)
    -- Note: This is complex due to tournament state - may need to recreate tournament
    print("[TournamentAPI] Participant removal not fully implemented - consider recreating tournament")
    return false
end

function TournamentAPI.get_participants(tournament_id)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return {} end
    return tournament.participants
end

-- Tournament Control
function TournamentAPI.start_tournament(tournament_id)
    return async(function()
        local tournament = TournamentState.get_tournament(tournament_id)
        if not tournament then return false end
        
        -- Initialize participant states
        TournamentState.initialize_participant_states(tournament_id)
        
        -- Set up board data
        local constants = require("scripts/net-game-tourney/constants")
        local board_background_info = constants.bracket_background_path[tournament.config.board_theme or "red_orange_bn4"]
        
        -- Store board data for UI
        local function store_tournament_board_data(t_id, background_info, participants)
            local tourney = TournamentState.get_tournament(t_id)
            if tourney then
                tourney.board_data = {
                    background_info = background_info,
                    participants = participants,
                    stored_mugshots = {}
                }
                
                for i, participant in ipairs(participants) do
                    tourney.board_data.stored_mugshots[i] = {
                        player_id = participant.player_id,
                        mug_texture = participant.player_mugshot.mug_texture,
                        position = {x = 0, y = 0, z = 2} -- Will be set by position system
                    }
                end
            end
        end
        
        store_tournament_board_data(tournament_id, board_background_info, tournament.participants)
        
        -- Start tournament in state system
        local success = TournamentState.start_tournament(tournament_id)
        
        if success then
            TournamentAPI.events.tournament_started:emit({
                tournament_id = tournament_id,
                round = tournament.current_round
            })
            
            -- Run the tournament battles
            await(TournamentAPI.run_tournament_battles(tournament_id))
        end
        
        return success
    end)
end

function TournamentAPI.run_tournament_battles(tournament_id)
    return async(function()
        -- This uses the existing battle system from main.lua
        local run_tournament_battles = require("scripts/net-game-tourney/main").run_tournament_battles
        if run_tournament_battles then
            await(run_tournament_battles(tournament_id))
        else
            print("[TournamentAPI] Battle system not available")
        end
    end)
end

function TournamentAPI.pause_tournament(tournament_id)
    -- Note: Pausing is complex - tournaments are designed to run to completion
    print("[TournamentAPI] Tournament pausing not implemented - tournaments run to completion")
    return false
end

function TournamentAPI.end_tournament(tournament_id)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return false end
    
    -- Clean up all participants
    for _, participant in ipairs(tournament.participants) do
        if not string.find(participant.player_id, ".zip") then
            TournamentState.remove_player_from_tournament(participant.player_id)
        end
    end
    
    TournamentState.cleanup_tournament(tournament_id)
    
    TournamentAPI.events.tournament_completed:emit({
        tournament_id = tournament_id,
        winner = tournament.winners[1]
    })
    
    return true
end

-- Tournament Information
function TournamentAPI.get_tournament_status(tournament_id)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return nil end
    
    return {
        tournament_id = tournament_id,
        status = tournament.status,
        current_round = tournament.current_round,
        participants_count = #tournament.participants,
        active_matches = #tournament.matches,
        winners = tournament.winners,
        host = tournament.host_player_id
    }
end

function TournamentAPI.get_round_results(tournament_id, round_number)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament then return {} end
    
    return tournament.round_results[round_number] or {}
end

function TournamentAPI.get_winner(tournament_id)
    local tournament = TournamentState.get_tournament(tournament_id)
    if not tournament or #tournament.winners == 0 then return nil end
    return tournament.winners[1]
end

-- Utility Functions
function TournamentAPI.list_active_tournaments()
    local all_tournaments = TournamentState.get_all_tournaments() or {}
    local active = {}
    
    for id, tournament in pairs(all_tournaments) do
        if tournament.status ~= "COMPLETED" then
            table.insert(active, {
                tournament_id = id,
                status = tournament.status,
                participants = #tournament.participants,
                current_round = tournament.current_round
            })
        end
    end
    
    return active
end

function TournamentAPI.is_player_in_tournament(player_id)
    return TournamentState.is_player_in_tournament(player_id)
end

function TournamentAPI.get_player_tournament(player_id)
    local tournament_id = TournamentState.get_tournament_id_by_player(player_id)
    if tournament_id then
        return TournamentState.get_tournament(tournament_id)
    end
    return nil
end

-- Quick Start Functions
function TournamentAPI.create_quick_tournament(host_player_id, area_id, board_id, participants)
    return async(function()
        -- participants can be: 
        -- - array of player IDs (NPCs will be auto-filled)
        -- - array of participant objects {player_id, player_mugshot}
        -- - number of desired participants (will fill with NPCs)
        
        local tournament_id = await(TournamentAPI.create_tournament({
            host_player_id = host_player_id,
            area_id = area_id,
            board_id = board_id,
            name = "Quick Tournament",
            tournament_type = "multiplayer"
        }))
        
        if type(participants) == "number" then
            -- Fill with NPCs
            for i = 1, participants do
                if i == 1 then
                    await(TournamentAPI.add_player(tournament_id, host_player_id))
                else
                    await(TournamentAPI.add_npc(tournament_id)) -- Random NPC
                end
            end
        else
            -- Add provided participants
            for _, participant in ipairs(participants) do
                if type(participant) == "string" then
                    await(TournamentAPI.add_player(tournament_id, participant))
                else
                    await(TournamentAPI.add_player(tournament_id, participant.player_id, participant.player_mugshot))
                end
            end
        end
        
        return tournament_id
    end)
end

-- Backwards Compatibility Wrapper
function TournamentAPI.setup_from_object_interaction(player_id, object_id, area_id)
    -- This wraps the existing object interaction system for easy migration
    local main = require("scripts/net-game-tourney/main")
    
    if main.create_consistent_tournament then
        return async(function()
            local constants = require("scripts/net-game-tourney/constants")
            local TiledUtils = require("scripts/net-game-tourney/tiled-utils")
            local TournamentUtils = require("scripts/net-game-tourney/tournament-utils")
            
            local object = Net.get_object_by_id(area_id, object_id)
            local board_background_setup_info = TournamentUtils.get_board_background_and_grid(object, TiledUtils, constants)
            
            local tournament_id, participants = await(main.create_consistent_tournament(
                player_id, object_id, area_id, board_background_setup_info, true
            ))
            
            if tournament_id then
                await(main.run_tournament_battles(tournament_id))
            end
            
            return tournament_id
        end)
    end
end

return TournamentAPI