local test_list = {"test-save-game"}
local TestRunner = require("scripts/test-runner/main")

if #test_list >= 1 then
    TestRunner.run(test_list)
end