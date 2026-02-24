local Utils = require("scripts/utils/utility")

local function createQuest(name)
    local quest = {
        name = name or "DEBUG",
        state = "Init",
        npc_list = {},
    }

    quest.Emitter = Utils.EventEmitter.new()
    
    quest.Emitter:on("Init", function(event)
    end)
    
    quest.Emitter:on("State Change", function(event)
    end)

    quest.Emitter:on("Set State", function(event)
    end)

    quest.Emitter:on("Cleanup", function (event)
    end)

    quest.Emitter:async_iter(quest.Emitter:on("Set State",function (event)
        print(event)
    end))


    return quest
end

-- Return the factory function (or you could return a default instance)
return createQuest