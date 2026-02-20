-- base.lua
-- Returns a simple table instance with some properties and methods.
-- This table can be used as a prototype for extension.

local function createBase(name)
    local base = {
        name = name or "Base",
        version = 1.0
    }

    function base:greet()
        print("Hello, I am " .. self.name .. " (version " .. self.version .. ")")
    end

    function base:describe()
        print("This is the base object.")
    end

    return base
end

-- Return the factory function (or you could return a default instance)
return createBase