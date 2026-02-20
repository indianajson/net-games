local test_list = {"test-save-game", "test-inheritence-table-example"}
local TestRunner = require("scripts/test-runner/main")

if #test_list >= 1 then
    TestRunner.run(test_list)
end