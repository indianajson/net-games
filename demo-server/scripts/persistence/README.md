Documentation for persistence.lua and save-game.lua
Table of Contents
Overview

persistence.lua

Purpose

API Reference

Usage Example

Important Notes

save-game.lua

Purpose

Configuration

API Reference

Usage Examples

File Structure & Safety

Important Notes

Overview
This pair of modules provides a robust, asynchronous save/load system for game data, with support for staging changes (edit, commit, revert) and per‑player isolated save files. persistence.lua handles low‑level file I/O and promise‑based operations, while save-game.lua builds on top of it to offer a workspace‑style interface where changes can be made to a working copy and then either saved to disk or discarded.

persistence.lua
Purpose
persistence.lua is a low‑level module responsible for reading from and writing to JSON files on disk. It abstracts the filesystem operations and provides a promise‑based API, allowing asynchronous file I/O without blocking the main thread. Each instance is bound to a specific file path and maintains an in‑memory copy of the data.

API Reference
persistence(filePath)
Constructor
Creates a new persistence instance for the given file path. The file is not immediately read; you must call :load() to read its contents.

Parameters:
filePath (string) – Path to the JSON file (relative to the game’s working directory).

Returns:
A new persistence object with the methods below.

:load()
Reads the JSON file from disk and parses its contents. If the file does not exist or is invalid, an appropriate error is propagated through the promise.

Returns:
A promise that resolves with the parsed Lua table (the data from the file) or rejects with an error.

:setData(data)
Replaces the in‑memory data of this persistence instance with a new table. This does not write to disk; it only updates the internal cache. Subsequent calls to :save() will write this data.

Parameters:
data (table) – The new data to store.

Returns:
Nothing.

:save()
Writes the current in‑memory data to the JSON file on disk. The file is overwritten with the new content.

Returns:
A promise that resolves when the write completes successfully, or rejects on error.

:getData() (optional, assumed)
Returns the current in‑memory data table. This is the same table that was loaded or last set via :setData(). Modifying the returned table will affect the in‑memory copy, but will not be written to disk until :save() is called.

Returns:
The in‑memory data table.

Usage Example
lua
local persistence = require('scripts/persistence/persistence')

local save = persistence('saves/player.json')

-- Load existing data
save:load():and_then(function(data)
    print('Loaded:', data)
    -- Modify data
    data.score = 100
    save:setData(data)
    -- Save changes
    return save:save()
end):and_then(function()
    print('Save completed')
end):catch(function(err)
    print('Error:', err)
end)
Important Notes
All file operations are asynchronous and return promises (assumed to be compatible with the Utility.create_promise used in save-game.lua).

The module does not create directories automatically; the path’s parent directories must exist before calling :save().

File content must be valid JSON. On load, the JSON is parsed into a Lua table; on save, the table is serialised to JSON.

save-game.lua
Purpose
save-game.lua extends persistence.lua to provide a staging area for changes. Each player has their own isolated set of save slots (up to a configurable maximum). The module maintains a working copy of the data that can be modified freely, and a saved snapshot representing the last committed state. You can:

Make multiple edits via :edit().

Commit changes to disk with :save().

Discard unsaved changes with :revert().

Read a shallow copy of the working data via :getData().

All operations are per‑player, using the player’s secret (obtained from Net.get_player_secret) to create a unique folder, ensuring that one player cannot access another’s saves.

Configuration
At the top of the file, you can adjust:

lua
local MAX_SAVE_INSTANCES = 3   -- number of save slots per player (1..n)
local SAVE_PATH_PATTERN = "scripts/save-files/%s/save%d.json"  -- secret, index
MAX_SAVE_INSTANCES defines how many separate save files each player can have.

SAVE_PATH_PATTERN determines where files are stored. %s is replaced with the sanitized player secret, %d with the slot index.

API Reference
get_game_save(player_id, index)
Factory function – Returns the singleton game_save instance for a given player and save slot. If the instance does not exist yet, it is created, and the underlying JSON file is automatically initialised with an empty object {} if missing.

Parameters:
player_id (string) – The player’s identifier.
index (number) – Save slot number, from 1 to MAX_SAVE_INSTANCES.

Returns:
A game_save object with the methods below.

Throws:

If player_id is not a string.

If index is not an integer in the valid range.

If the player secret cannot be retrieved (empty or not a string).

If file/directory creation fails (e.g., permission denied).

:load()
Reads the save file from disk and initialises both the saved snapshot and the working copy with the file’s contents. This must be called before any other operations (except the factory function).

Returns:
A promise that resolves with the working data table after loading completes. The promise is the one returned by the underlying persistence:load().

:edit(func)
Applies a modification to the working copy. The function func receives the working data table and should modify it in place. After the call, the instance is marked as dirty (unsaved changes).

Parameters:
func (function) – A function that takes the working data table and modifies it.

Throws:
If :load() has not been called yet.

Example:

lua
save:edit(function(data)
    data.playerName = "New Name"
    data.inventory.gold = data.inventory.gold + 50
end)
:save()
Commits the current working copy to disk. If the instance is not dirty (no changes since last load or save), the returned promise resolves immediately without writing.

Returns:
A promise that resolves when the write completes successfully. On success, the saved snapshot is updated to match the working copy, and the dirty flag is cleared.

Throws:
If :load() has not been called.

:revert()
Discards all unsaved changes by resetting the working copy to a deep copy of the last saved snapshot. The dirty flag is cleared.

Throws:
If :load() has not been called.

:getData()
Returns a shallow copy of the current working data. This is safe for reading; modifications to the returned table will not affect the working copy (and thus will not be considered for saving). For direct manipulation, use :edit() or :getWorkingTable() with caution.

Returns:
A new table containing key‑value pairs from the working data.

Throws:
If :load() has not been called.

:isModified()
Returns true if there are unsaved changes in the working copy, false otherwise.

Returns:
Boolean.

:getWorkingTable() (use with caution)
Returns the actual working data table. Modifications to this table will directly affect the working copy and will automatically mark the instance as dirty. This method is provided for advanced use cases where you need to pass the table to external functions that expect to modify it directly. In most cases, prefer :edit().

Returns:
The mutable working data table.

Throws:
If :load() has not been called.

Usage Examples
Basic flow: load, edit, save
lua
local game_save = require('scripts/save-game/save-game')

-- Get player's first save slot
local save = game_save("player123", 1)

save:load():and_then(function(data)
    print("Current gold:", data.gold)
    -- Edit the working copy
    save:edit(function(d)
        d.gold = (d.gold or 0) + 100
        d.lastPlayed = os.time()
    end)
    -- Save changes
    return save:save()
end):and_then(function()
    print("Save successful")
end):catch(function(err)
    print("Error:", err)
end)
Discarding changes
lua
save:load():and_then(function()
    -- Make some changes
    save:edit(function(d) d.experiment = "test" end)
    -- Oops, discard them
    save:revert()
    -- Now working copy is back to the saved state
    print(save:isModified())  -- false
end)
Reading data without modifying
lua
save:load():and_then(function()
    local data = save:getData()  -- safe read‑only copy
    print("Player name:", data.name)
end)
File Structure & Safety
Each player’s saves are stored in scripts/save-files/<sanitized_secret>/.

The secret obtained from Net.get_player_secret(player_id) is sanitised to be filesystem‑safe: any character that is not alphanumeric, dot, dash, or underscore is replaced with an underscore. This prevents invalid filenames on Windows (which disallows \ / : * ? " < > |) and Unix (which disallows / and null).

The module attempts to create directories using Garry’s Mod’s file.CreateDir if available; otherwise, it falls back to os.execute with platform‑appropriate commands and proper shell escaping.

Empty save files are initialised with the content {} to ensure valid JSON from the start.

The cache (instances) is keyed by the sanitized secret and slot index, so each player/slot pair is a singleton.

Important Notes
load() must be called first – Before using edit, save, revert, or any data access methods, you must await the promise returned by :load(). Failure to do so will result in errors.

Asynchronous operations – Both :load() and :save() return promises. Use .and_then() / .catch() (or your preferred promise chaining) to handle completion.

Deep copies – The module uses a simple recursive deep copy for snapshots and data isolation. It assumes tables contain no cycles. If your data has cycles or complex metatables, you may need a more robust copy routine.

Per‑player isolation – The secret ensures that even if two players have the same player_id string (unlikely), their files are stored in separate directories. This also prevents one player from accessing another’s saves by guessing file paths.

Maximum instances – The limit is enforced per player. You cannot have more than MAX_SAVE_INSTANCES slots per player. Requesting an index outside this range throws an error.

This documentation should give you a complete understanding of both modules and how to use them effectively in your game.