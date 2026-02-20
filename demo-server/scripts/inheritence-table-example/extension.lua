-- extended.lua
-- Requires base.lua and returns a function that creates extended instances.
-- Each extended instance inherits from a fresh base instance.

local createBase = require("scripts/inheritence-table-example/base")

local function createExtended(name, extraField)
    -- Create a new base instance
    local baseInstance = createBase(name)

    -- Create the extended table with its own fields
    local extended = {
        extraField = extraField or "Default extra data",
        version = 2.0          -- override base version
    }

    -- Set up inheritance: missing keys are looked up in baseInstance
    setmetatable(extended, {
        __index = baseInstance
    })

    -- Add a new method specific to the extension
    function extended:newMethod()
        print("This is an extended method. Extra field: " .. self.extraField)
    end

    -- Override an existing method
    function extended:describe()
        print("This is the extended object, based on: " .. self.name)
    end

    return extended
end

return createExtended