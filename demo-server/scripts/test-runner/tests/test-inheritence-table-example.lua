local function test()
local extension = require("scripts/inheritence-table-example/extension")
local test = extension("TEST", "NEW_FIELD")
    print(test)
return true
end

return test