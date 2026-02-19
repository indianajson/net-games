Persistence Module Documentation
Overview
The persistence module provides a simple, promise‑based interface for storing Lua tables as JSON files. It features automatic debounced saving, manual save control, and support for nested data access via dot‑notation paths. Each file path gets its own singleton instance, ensuring that multiple requires for the same file share the same state and save timer.

Installation
lua
local get_persistence = require('scripts/persistence/persistence')
Usage
Create an instance for a specific JSON file:

lua
local store = get_persistence('path/to/your/file.json')
All operations assume the data has been loaded. You must call :load() (or :ready()) before reading or writing.

Loading Data
lua
store:load():and_then(function(data)
    -- data is the loaded table (empty if file missing/invalid)
end)
Or use the convenience :ready():

lua
store:ready(function()
    print("Data is ready")
end)
Reading Data
After loading, obtain a shallow copy of the current data:

lua
local data = store:getData()
print(data.someKey)
Modifying Data
Top‑Level Keys
Update with a function (most flexible):

lua
store:update(function(d)
    d.counter = (d.counter or 0) + 1
    d.user = { name = "Alice" }
end)
Set a key:

lua
store:setKey("highScore", 1000)
Remove a key:

lua
store:removeKey("tempData")
Replace entire data:

lua
store:setData({ new = "data" })
Clear all data:

lua
store:clear()
Nested Keys (Dot Notation)
Work with deep paths without manually checking intermediate tables:

Set a nested value (creates missing tables):

lua
store:setPath("user.profile.email", "user@example.com")
Remove a nested key:

lua
store:removePath("user.profile.phone")
Paths can also be given as a table of keys:

lua
store:setPath({"user", "profile", "name"}, "Bob")
Saving
The module automatically schedules a save 2 seconds after the last modification (debounced). You can also force an immediate save:

lua
store:save():and_then(function()
    print("Data written to disk")
end)
:save() returns a promise that resolves when the write completes (or immediately if no changes are pending). If a save is already in progress, the new save is queued and its promise resolves after that queued save finishes.

Checking Dirty State
lua
if store.dirty then
    print("There are unsaved changes")
end
Full Example
lua
local store = get_persistence('data.json')

store:load()
    :and_then(function()
        store:update(function(d)
            d.visits = (d.visits or 0) + 1
        end)
        store:setPath("user.last_login", os.time())
        return store:save()   -- force immediate save
    end)
    :and_then(function()
        print("Saved. Current data:", store:getData())
    end)
API Reference
get_persistence(filePath) -> store
Returns the singleton instance for the given file path. Creates a new instance if none exists.

Instance Methods
store:load() -> promise
Reads the file and parses JSON into store.data. If already loaded, returns a resolved promise immediately. The promise resolves with the loaded data table.

store:ready(callback) -> promise
Convenience method: calls :load() and then invokes the callback. Returns the same promise as :load().

store:getData() -> table
Returns a shallow copy of the current data. Must be called after load.

store:setData(newData)
Replaces the entire data table with newData. Marks the store as dirty.

store:update(func)
Applies func to the internal data table. func receives the data table as its only argument and should modify it in place. Marks the store as dirty.

store:setKey(key, value)
Sets a top‑level key to value. Equivalent to update(function(d) d[key] = value end).

store:removeKey(key)
Removes a top‑level key. Equivalent to update(function(d) d[key] = nil end).

store:clear()
Resets the data to an empty table {}. Marks dirty.

store:setPath(path, value)
Sets a value at a nested location. path can be a dot‑separated string (e.g., "a.b.c") or a table of keys (e.g., {"a","b","c"}). Creates any missing intermediate tables.

store:removePath(path)
Removes a nested key. Does nothing if the path does not exist.

store:save() -> promise
Immediately writes the current data to disk, bypassing the debounce timer. Returns a promise that resolves when the write completes. If a save is already in progress, the new save is queued and its promise resolves after that save finishes.

store:updateAndSave(func)
Identical to :update(func) – included for semantic clarity (auto‑save is always active).

Properties (read‑only, but inspectable)
store.dirty – true if there are unsaved changes.

store.loaded – true after :load() has completed.

store.filePath – the file path associated with this instance.

How Auto‑Save Works
After any modification (update, setKey, etc.), the instance is marked dirty.

A timer (save_delay) is set to update_interval (2 seconds).

On each game tick, the timer is decremented. When it reaches zero, an automatic save is triggered.

Calling :save() manually cancels the timer and writes immediately.

If a manual save is requested while another save is in progress, the new save is queued (pending = true) and will start after the current one finishes. Any promises returned for the queued save resolve after that queued save completes.

Error Handling
File read/write errors are printed but do not throw. The promise returned by :save() will still resolve (to avoid hanging chains). Check logs for "Failed to decode JSON" or "Write failed".

Calling read/write methods before :load() raises an error.

Notes
The module uses a global Net:on("tick") handler to manage save timers for all instances. Ensure Net is available in your environment.

JSON encoding/decoding relies on the json module (assumed to be compatible with typical json.encode/json.decode).

The Utility.create_promise function is expected to return a promise with an :and_then method (similar to typical promise implementations).

This documentation should help you use the persistence module effectively. For a working example, refer to the provided test-persistence.lua file.