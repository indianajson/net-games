-- Name of files to run. These should be the file name (without the extension) 
-- The scripts in the test_list must be located in "scripts/test-runner/tests/"
local test_list = {"test-save-game", "test-inheritence-table-example"}

local TestRunner = require("scripts/test-runner/main")

if #test_list >= 1 then
    TestRunner.run(test_list)
end