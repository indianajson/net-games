-- persistence.lua
-- Persistent JSON file storage with automatic debounced saving and per‑file instance management.
-- Supports chained updates and waiting for save completion via promise‑returning save().
-- Automatically creates missing directories when saving.

local json = require('scripts/libs/json')
local Utility = require('scripts/utils/utility')

local update_interval = 2          -- seconds to wait after last change before saving
local instances = {}                -- cache of active instances by file path

-- ========================================================================= --
-- Pretty‑print control                                                      --
-- ========================================================================= --
-- Set this to true to save JSON with 2‑space indentation, or to a custom   --
-- indent string (e.g. "\t" or "    "). When false or nil, compact JSON is  --
-- written.                                                                  --
-- ========================================================================= --
local PrettyPrint = true   -- change to true for pretty output

-- Simple split function (splits string on a delimiter)
local function split(str, delim)
    local result = {}
    if not str or str == "" then return result end
    for part in str:gmatch("[^" .. delim .. "]+") do
        table.insert(result, part)
    end
    return result
end

-- OS detection (copied from utils.lua for self‑containment)
local function get_os()
    if package.config:sub(1, 1) == "\\" then
        return "windows"
    else
        return "unix"
    end
end

-- Synchronously create a directory (and all parents) if it does not exist.
-- Returns true on success, false on failure (errors are printed).
local function mkdir_p(dir)
    if dir == "" then return true end
    local os_type = get_os()
    local cmd
    if os_type == "windows" then
        -- mkdir on Windows creates intermediate directories by default.
        -- 2>nul suppresses error output.
        cmd = 'mkdir "' .. dir .. '" 2>nul'
    else
        -- Unix: mkdir -p creates parents and ignores existing.
        cmd = 'mkdir -p "' .. dir .. '" 2>/dev/null'
    end
    local result = os.execute(cmd)
    if result then
        print("Created directory: " .. dir)
        return true
    else
        -- Command failed. On Windows this may be because the directory already exists.
        if os_type == "windows" then
            -- Check if the directory actually exists now
            local test_cmd = 'if exist "' .. dir .. '\\" (exit 0) else (exit 1)'
            local exists = os.execute(test_cmd)
            if exists then
                -- Directory already existed – that's fine, no error
                return true
            end
        end
        print("Failed to create directory: " .. dir)
        return false
    end
end

-- Promise‑based directory creation: extracts directory part from file path,
-- creates it synchronously, and returns an already‑resolved promise.
local function async_ensure_dir(filePath)
    local dir = filePath:match("^(.*)/") or ""
    return Utility.create_promise(function(resolve)
        mkdir_p(dir)
        resolve()
    end)
end

-- Global tick handler: updates timers for all instances and triggers saves
Net:on("tick", function(event)
    local delta = event.delta_time
    for _, inst in pairs(instances) do
        if inst.save_delay then
            inst.save_delay = inst.save_delay - delta
            if inst.save_delay <= 0 then
                inst.save_delay = nil
                if inst.dirty then
                    inst.dirty = false
                    inst:_save_internal()
                end
            end
        end
    end
end)

-- Creates a new instance (internal)
local function new(filePath)
    local self = {
        filePath = filePath,
        data = nil,
        loaded = false,
        saving = false,
        dirty = false,
        save_delay = nil,
        pending = false,            -- true if another save is queued
        after_save = {},             -- list of resolvers waiting for the *next* save to complete
    }

    -- Mark data as dirty and schedule a save (debounced)
    function self:_mark_dirty()
        self.dirty = true
        if not self.save_delay then
            self.save_delay = update_interval
        else
            self.save_delay = update_interval  -- reset timer
        end
    end

    -- Load data from file. Returns a promise that resolves when loaded.
    function self:load()
        if self.loaded then
            return Utility.create_promise(function(resolve)
                resolve(self.data)
            end)
        end
        return Utility.create_promise(function(resolve)
            Async.read_file(self.filePath).and_then(function(content)
                local ok, decoded = pcall(function()
                    if content and content ~= "" then
                        return json.decode(content)
                    end
                    return {}
                end)
                if ok then
                    self.data = decoded
                else
                    print("Failed to decode JSON from " .. self.filePath .. ": " .. tostring(decoded))
                    self.data = {}
                end
                self.loaded = true
                resolve(self.data)
            end)
        end)
    end

    -- Get current data (returns a shallow copy)
    function self:getData()
        if not self.loaded then
            error("Data not loaded yet. Call :load() first.")
        end
        local copy = {}
        for k, v in pairs(self.data) do
            copy[k] = v
        end
        return copy
    end

    -- Replace entire data
    function self:setData(newData)
        if not self.loaded then
            error("Data not loaded yet. Call :load() first.")
        end
        self.data = newData
        self:_mark_dirty()
    end

    -- Apply a function to modify data in place
    function self:update(func)
        if not self.loaded then
            error("Data not loaded yet. Call :load() first.")
        end
        func(self.data)
        self:_mark_dirty()
    end

    -- Convenience: remove a top‑level key
    function self:removeKey(key)
        self:update(function(data)
            data[key] = nil
        end)
    end

    -- Convenience: set a top‑level key (replaces if exists)
    function self:setKey(key, value)
        self:update(function(data)
            data[key] = value
        end)
    end

    -- Clear all data (reset to empty table)
    function self:clear()
        if not self.loaded then
            error("Data not loaded yet. Call :load() first.")
        end
        self.data = {}
        self:_mark_dirty()
    end

    -- Robust helper to resolve a dot‑separated path (e.g., "user.profile.name") or table of keys
    local function resolve_path(data, path, create)
        if type(path) == "string" then
            if path == "" then return nil, nil end
            local parts = split(path, ".")
            if #parts == 0 then return nil, nil end
            path = parts
        end
        local current = data
        for i = 1, #path - 1 do
            local part = path[i]
            if type(current) ~= "table" then
                return nil, nil
            end
            if current[part] == nil then
                if create then
                    current[part] = {}
                else
                    return nil, nil
                end
            end
            current = current[part]
        end
        if type(current) ~= "table" then
            return nil, nil
        end
        return current, path[#path]
    end

    -- Remove a nested key (path can be dot‑string or table of keys)
    function self:removePath(path)
        self:update(function(data)
            local parent, key = resolve_path(data, path, false)
            if parent and key then
                parent[key] = nil
            end
        end)
    end

    -- Set a nested key (creates intermediate tables if needed)
    function self:setPath(path, value)
        self:update(function(data)
            local parent, key = resolve_path(data, path, true)
            if parent and key then
                parent[key] = value
            end
        end)
    end

    -- Internal save (called by timer or manually). Returns a promise.
    function self:_save_internal()
        if self.saving then
            -- This should never happen because we check in save()
            error("_save_internal called while already saving")
        end
        self.saving = true

        -- Encode data to JSON, optionally with pretty‑print formatting
        local ok, content
        if PrettyPrint then
            -- Pass PrettyPrint (which may be true or a custom indent string) to json.encode
            ok, content = pcall(json.encode, self.data, PrettyPrint)
        else
            ok, content = pcall(json.encode, self.data)
        end

        if not ok then
            print("Failed to encode data to JSON: " .. tostring(content))
            self.saving = false
            -- Resolve any waiting promises with nil
            for _, cb in ipairs(self.after_save) do cb() end
            self.after_save = {}
            return Utility.create_promise(function(resolve) resolve() end)
        end

        print("Writing to " .. self.filePath)  -- debug

        -- Step 1: Ensure the directory exists (create if missing)
        local dir_promise = async_ensure_dir(self.filePath)

        -- Step 2: After directory is ready, write the file
        local save_promise = Utility.create_promise(function(resolve)
            dir_promise:and_then(function()
                Async.write_file(self.filePath, content).and_then(
                    function()
                        print("Write successful")
                        self.saving = false

                        -- If there are queued resolvers, they are for the *next* save
                        -- We need to trigger that save now
                        if self.pending then
                            self.pending = false
                            -- Start the next save and attach the queued resolvers to it
                            local next_save_promise = self:_save_internal()
                            -- When the next save completes, resolve the queued resolvers
                            next_save_promise:and_then(function()
                                for _, cb in ipairs(self.after_save) do cb() end
                                self.after_save = {}
                            end)
                        else
                            -- No pending save, just resolve any resolvers (should be none)
                            for _, cb in ipairs(self.after_save) do cb() end
                            self.after_save = {}
                        end
                        resolve()  -- resolve the current save's promise
                    end,
                    function(err)
                        print("Write failed: " .. tostring(err))
                        self.saving = false
                        for _, cb in ipairs(self.after_save) do cb() end
                        self.after_save = {}
                        self.pending = false
                        resolve()  -- still resolve to avoid hanging promises
                    end
                )
            end)
        end)

        return save_promise
    end

    -- Public save: forces an immediate save (bypasses timer). Returns a promise.
    function self:save()
        -- Cancel any pending timer
        self.save_delay = nil
        if not self.dirty then
            -- Already clean – return resolved promise
            return Utility.create_promise(function(resolve) resolve() end)
        end

        self.dirty = false

        if self.saving then
            -- A save is already in progress; queue this one to happen after it
            self.pending = true
            return Utility.create_promise(function(resolve)
                table.insert(self.after_save, resolve)
            end)
        else
            return self:_save_internal()
        end
    end

    -- Convenience: load and then call a callback
    function self:ready(callback)
        return self:load():and_then(callback)
    end

    -- Update and schedule save (same as update, but name indicates auto‑save)
    function self:updateAndSave(func)
        self:update(func)
    end

    return self
end

-- Manager: returns the instance for a given file path (creates if not exist)
local function get_instance(filePath)
    if not filePath or type(filePath) ~= "string" then
        error("filePath must be a string")
    end
    local inst = instances[filePath]
    if not inst then
        inst = new(filePath)
        instances[filePath] = inst
    end
    return inst
end

return get_instance