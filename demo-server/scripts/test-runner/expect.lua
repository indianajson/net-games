-- expect.lua
-- A minimal assertion library for use with the test runner.
-- Example:
--   local expect = require("scripts.test-runner.expect")
--   return function()
--     expect(2 + 2).toBe(4)
--     expect({a = 1}).toEqual({a = 1})
--     expect(function() error("oops") end).toThrow()
--   end
local function deep_equal(a, b)
    if a == b then return true end
    local type_a, type_b = type(a), type(b)
    if type_a ~= type_b then return false end
    if type_a == "table" then
        local seen = {} -- handle cycles (simple approach)
        local function check(x, y)
            if x == y then return true end
            if seen[x] then return seen[x] == y end
            seen[x] = y
            for k, v in pairs(x) do
                if not check(v, y[k]) then return false end
            end
            for k, _ in pairs(y) do
                if x[k] == nil then return false end
            end
            return true
        end
        return check(a, b)
    end
    return false
end

local function format(v)
    if type(v) == "string" then
        return '"' .. v .. '"'
    elseif type(v) == "table" then
        -- simple representation
        local parts = {}
        for k, v in pairs(v) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(v)
    end
end

local function expect(actual)
    local function fail(msg)
        error(msg, 2) -- skip this function in stack trace
    end

    return {
        toBe = function(expected)
            if actual ~= expected then
                fail("Expected " .. format(expected) .. " but got " ..
                         format(actual))
            end
        end,
        toEqual = function(expected)
            if not deep_equal(actual, expected) then
                fail("Expected " .. format(expected) .. " but got " ..
                         format(actual))
            end
        end,
        toBeTruthy = function()
            if not actual then
                fail("Expected truthy but got " .. format(actual))
            end
        end,
        toBeFalsy = function()
            if actual then
                fail("Expected falsy but got " .. format(actual))
            end
        end,
        toBeNil = function()
            if actual ~= nil then
                fail("Expected nil but got " .. format(actual))
            end
        end,
        toBeDefined = function()
            if actual == nil then
                fail("Expected defined value but got nil")
            end
        end,
        toBeGreaterThan = function(n)
            if not (actual > n) then
                fail("Expected " .. format(actual) .. " > " .. format(n))
            end
        end,
        toBeLessThan = function(n)
            if not (actual < n) then
                fail("Expected " .. format(actual) .. " < " .. format(n))
            end
        end,
        toThrow = function(expected_msg)
            local ok, err = pcall(actual)
            if ok then
                fail("Expected function to throw but it did not")
            end
            if expected_msg then
                if type(expected_msg) == "string" then
                    if not string.find(err, expected_msg, 1, true) then
                        fail("Expected error containing '" .. expected_msg ..
                                 "', got '" .. tostring(err) .. "'")
                    end
                elseif type(expected_msg) == "function" then
                    if not expected_msg(err) then
                        fail("Expected error to match predicate, got '" ..
                                 tostring(err) .. "'")
                    end
                end
            end
        end,
        -- convenience alias
        notToBe = function(expected)
            if actual == expected then
                fail("Expected not " .. format(expected) .. " but got it")
            end
        end
    }
end

return expect
