-- game_save.lua
-- Extension of persistence.lua that provides a staging area for changes.
-- Allows you to make multiple edits, then either commit them (save) or
-- discard them (revert) back to the last saved state.
--
-- This version supports per‑player save files using the player's secret:
--   scripts/save-files/<player_secret>/save<index>.json
-- where <index> is from 1 to MAX_SAVE_INSTANCES (configurable below).
-- The factory function accepts a player_id (string) and an index.
-- The secret is sanitized to be filesystem‑safe across platforms.

local persistence = require('scripts/persistence/persistence')
local Utility = require("scripts/tests/utility")

-- CONFIGURATION --------------------------------------------------------------
local MAX_SAVE_INSTANCES = 3                     -- maximum number of save slots per player
local SAVE_PATH_PATTERN = "scripts/save-files/%s/save%d.json"  -- path template (secret, index)
-- -----------------------------------------------------------------------------

local instances = {}   -- cache: instances[player_secret][index] = game_save object

-- Characters that are invalid in filenames on common platforms:
-- Windows: \ / : * ? " < > |
-- Unix: / and null
-- We'll replace any problematic characters with an underscore.
local function sanitize_filename_component(str)
    if not str then return "" end
    -- Replace any character that is not alphanumeric, dot, dash, or underscore with '_'
    -- This is a safe conservative approach; adjust if you need to allow more.
    local sanitized = str:gsub("[^%w%.%-_]", "_")
    -- Also ensure it doesn't start or end with a dot (to avoid hidden files issues)
    sanitized = sanitized:gsub("^%.", "_"):gsub("%.$", "_")
    return sanitized
end

-- Detect platform for fallback directory creation
local is_windows = package.config:sub(1,1) == '\\'

-- Safe path quoting for os.execute (escape double quotes)
local function escape_path_for_shell(path)
    if is_windows then
        -- Windows: enclose in double quotes and escape internal double quotes by doubling
        return '"' .. path:gsub('"', '""') .. '"'
    else
        -- Unix: enclose in single quotes and escape single quotes inside
        return "'" .. path:gsub("'", "'\\''") .. "'"
    end
end

-- Ensures that the directory portion of a file path exists.
-- Uses Garry's Mod's file.CreateDir if available (recommended),
-- otherwise falls back to os.execute with proper escaping.
local function ensure_directory_exists(filePath)
    -- Extract directory part (everything before last '/')
    local dir = filePath:match("^(.*)/[^/]*$")
    if not dir or dir == "" then return end

    -- Try using Garry's Mod file library if available (common in GMod)
    if file and file.CreateDir then
        -- file.CreateDir expects a relative path and creates all intermediates
        file.CreateDir(dir)
        return
    end

    -- Fallback: manual directory creation using io.open to check existence and os.execute to create
    -- Check if directory already exists
    local f = io.open(dir, "r")
    if f then
        f:close()
        return
    end

    -- Create directory (and parents) safely
    if is_windows then
        -- Windows: mkdir creates intermediate directories automatically
        -- Use escaped path to avoid issues with special characters
        local cmd = 'mkdir ' .. escape_path_for_shell(dir) .. ' 2>nul'
        os.execute(cmd)
    else
        -- Unix: use -p to create parents
        local cmd = 'mkdir -p ' .. escape_path_for_shell(dir)
        os.execute(cmd)
    end
    -- If it still fails, subsequent file creation will error.
end

-- Ensure that the file at the given path exists and contains an empty JSON object.
-- If the file does not exist, it is created with the content "{}".
local function ensure_save_file_exists(filePath)
    ensure_directory_exists(filePath)

    local file = io.open(filePath, "r")
    if file then
        file:close()
        return  -- file already exists
    end

    -- File doesn't exist – create it with an empty JSON object
    file = io.open(filePath, "w")
    if not file then
        error("Cannot create save file: " .. filePath .. " (directory missing or permission denied)")
    end
    file:write("{}")
    file:close()
end

-- Deep copy a table (simple recursive copy, assumes no cycles)
local function deep_copy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deep_copy(k)] = deep_copy(v)
    end
    return copy
end

-- Creates a new game_save instance for the given file path
local function new(filePath)
    local p = persistence(filePath)   -- get the underlying persistence instance

    local self = {
        filePath = filePath,
        persistence = p,
        saved_data = nil,    -- snapshot of the last saved state
        working_data = nil,   -- mutable working copy
        loaded = false,
        dirty = false,        -- true if working_data differs from saved_data
    }

    -- Load data from disk and initialise both saved and working copies
    function self:load()
        return p:load():and_then(function(data)
            -- data is the table from persistence (the actual in‑memory store)
            -- We keep our own copies to isolate working changes
            self.saved_data = deep_copy(data)
            self.working_data = deep_copy(data)
            self.loaded = true
            self.dirty = false
            return self.working_data
        end)
    end

    -- Apply a modification to the working copy.
    -- func receives the working data table and should modify it in place.
    function self:edit(func)
        if not self.loaded then
            error("game_save: not loaded. Call :load() first.")
        end
        func(self.working_data)
        self.dirty = true
    end

    -- Commit the working copy to disk.
    -- Returns a promise that resolves when the write completes.
    function self:save()
        if not self.loaded then
            error("game_save: not loaded. Call :load() first.")
        end
        if not self.dirty then
            -- Nothing changed – resolve immediately
            return Utility.create_promise(function(resolve) resolve() end)
        end

        -- Give persistence a fresh copy of the working data so that future
        -- modifications to working_data do not affect the saved state.
        local copy_for_save = deep_copy(self.working_data)
        self.persistence:setData(copy_for_save)

        -- Save and update saved_data on success
        return self.persistence:save():and_then(function()
            self.saved_data = deep_copy(self.working_data)
            self.dirty = false
        end)
    end

    -- Discard all changes made since the last save.
    -- Resets working_data to a copy of the last saved state.
    function self:revert()
        if not self.loaded then
            error("game_save: not loaded. Call :load() first.")
        end
        self.working_data = deep_copy(self.saved_data)
        self.dirty = false
    end

    -- Return a shallow copy of the current working data (for reading only).
    function self:getData()
        if not self.loaded then
            error("game_save: not loaded. Call :load() first.")
        end
        local copy = {}
        for k, v in pairs(self.working_data) do
            copy[k] = v
        end
        return copy
    end

    -- Check whether there are unsaved modifications.
    function self:isModified()
        return self.dirty
    end

    -- (Optional) Direct access to the working table – use with caution.
    -- Modifying the returned table will mark it dirty automatically.
    function self:getWorkingTable()
        if not self.loaded then
            error("game_save: not loaded. Call :load() first.")
        end
        return self.working_data
    end

    return self
end

-- Factory: returns the singleton game_save instance for a given player and save slot.
-- player_id : string – the player's ID
-- index     : number – save slot index (1 .. MAX_SAVE_INSTANCES)
-- The corresponding file is automatically created if it does not exist.
local function get_game_save(player_id, index)
    if type(player_id) ~= "string" then
        error("player_id must be a string")
    end
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > MAX_SAVE_INSTANCES then
        error(string.format("index must be an integer between 1 and %d", MAX_SAVE_INSTANCES))
    end

    local secret = Net.get_player_secret(player_id)
    if type(secret) ~= "string" or secret == "" then
        error("Unable to retrieve valid player secret for player_id " .. tostring(player_id))
    end

    -- Sanitize the secret to be filesystem-safe
    local safe_secret = sanitize_filename_component(secret)

    -- Initialise per‑secret cache if needed
    if not instances[safe_secret] then
        instances[safe_secret] = {}
    end

    local inst = instances[safe_secret][index]
    if not inst then
        local filePath = string.format(SAVE_PATH_PATTERN, safe_secret, index)
        ensure_save_file_exists(filePath)   -- create empty file and directories if missing
        inst = new(filePath)
        instances[safe_secret][index] = inst
    end
    return inst
end

return get_game_save