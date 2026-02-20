-- test-runner.lua
-- Simple test runner for scripts in "scripts/tests/".
-- Usage:
--   local runner = require("scripts.tests.test-runner")  -- adjust path as needed
--   runner.run({"math_test", "string_test"})  -- run specific tests
--   runner.run()                               -- run all tests found
--
-- Each test file must return a function that performs the test.
-- The function may return a boolean or simply error on failure.

local TEST_DIR = "scripts/test-runner/tests/"

-- Detect platform for directory listing
local is_windows = package.config:sub(1,1) == '\\'

-- List all Lua files in the test directory (without .lua extension)
local function list_test_files()
    local tests = {}
    local command

    if is_windows then
        -- Windows: dir /B gives bare filenames, /A-D excludes directories
        command = 'dir "' .. TEST_DIR .. '" /B /A-D 2>nul'
    else
        -- Unix: ls -p appends / to directories, then grep -v / excludes them
        command = 'ls -p "' .. TEST_DIR .. '" 2>/dev/null | grep -v /'
    end

    local handle = io.popen(command)
    if not handle then
        error("Could not list test files. Make sure the directory exists.")
    end

    for line in handle:lines() do
        local name = line:match("^(.*)%.lua$")
        if name then
            table.insert(tests, name)
        end
    end
    handle:close()

    return tests
end

-- Load a test module and return its function
local function load_test(name)
    local path = TEST_DIR .. name .. ".lua"
    -- Use dofile to load the file; pcall catches syntax/runtime errors
    local ok, result = pcall(dofile, path)
    if not ok then
        error("Failed to load test '" .. name .. "': " .. tostring(result))
    end
    if type(result) ~= "function" then
        error("Test '" .. name .. "' must return a function")
    end
    return result
end

-- Run a single test and return result (true = pass, false = fail with message)
local function run_test(name)
    local func = load_test(name)
    local ok, err = pcall(func)
    if not ok then
        return false, err  -- error during test execution
    end
    -- If the test function returns a boolean, use it; otherwise assume success
    if err ~= nil and type(err) == "boolean" then
        return err, err and "passed" or "failed (returned false)"
    end
    return true, "passed"
end

-- Public interface: run a list of test names (default: all)
local function run(test_list)
    if not test_list or #test_list == 0 then
        test_list = list_test_files()
        if #test_list == 0 then
            print("No test files found in " .. TEST_DIR)
            return
        end
    end

    print("Running " .. #test_list .. " test(s)...")
    print("")

    local passed = 0
    local failed = 0
    local results = {}

    for _, name in ipairs(test_list) do
        io.write("  " .. name .. " ... ")
        local success, msg = run_test(name)
        if success then
            print("✅ " .. (msg or "passed"))
            passed = passed + 1
        else
            print("❌ " .. (msg or "failed"))
            failed = failed + 1
            table.insert(results, {name = name, error = msg})
        end
    end

    print("")
    print(string.format("Results: %d passed, %d failed", passed, failed))

    if #results > 0 then
        print("\nFailures:")
        for _, f in ipairs(results) do
            print("  " .. f.name .. ": " .. tostring(f.error))
        end
    end

    return passed, failed, results
end

return { run = run }