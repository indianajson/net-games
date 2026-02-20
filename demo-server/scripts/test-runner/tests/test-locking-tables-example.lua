local function run()
-- simple_test.lua
local LockableTable = require("scripts/net-games/utilities/lockable-table")

-- Simple test without any recursion
print("=== Creating Lockable Table ===")
local MainDataTable = LockableTable.new({})

print("=== Adding Items ===")
MainDataTable:add("name", "Name-A-A-ron")
MainDataTable:add("TEST", {})
MainDataTable:add("value", 100)
MainDataTable:add("Testing", {testing = "Testing"})
print("Data Table:", MainDataTable.Testing.testing)
print("name:", MainDataTable.name)
print("value:", MainDataTable.value)

MainDataTable:lockKey("Testing")
MainDataTable:update("Testing", {testing = "CHANGES"})
print("IMPORTANT!!!!!!!!!!: ")
print(MainDataTable.Testing)

print("=== Locking a Key ===")
MainDataTable:lockKey("name")
local success, err = MainDataTable:add("name", "Changed")
print("Try to change locked key 'name':", success, err)

print("=== Adding New Key After Lock ===")
MainDataTable:add("newKey", "newValue")
print("newKey:", MainDataTable.newKey)

print("=== Removing Items ===")
MainDataTable:add("temp", "temporary")
print("Before remove - temp:", MainDataTable.temp)
MainDataTable:remove("temp")
print("After remove - temp:", MainDataTable.temp)

print("=== Full Lock ===")
MainDataTable:lockAll()
success, err = MainDataTable:add("blocked", "value")
print("Add to fully locked table:", success, err)

print("TESTING TO MAKE SURE WE CAN STILL READ WHEN SOMETHING IS LOCKED "..MainDataTable.name)

print("=== Unlock ===")
MainDataTable:unlockAll()
MainDataTable:add("works", "now")
print("works:", MainDataTable.works)

print("=== Iteration ===")
for k, v in pairs(MainDataTable) do
    print(k, "=", v)
end

print("=== Test Complete ===")
end

return run