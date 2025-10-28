local default_mug_anim = "/server/assets/tourney/mug.anim"
local npc_path = "/server/assets/tourney/npc-navis-testing/"

local NPC_LIST = {
    [1] = {
        player_id = npc_path .. "airman/airman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "airman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 50, -- Combat strength (1-100)
    },
    [2] = {
        player_id = npc_path .. "blastman/blastman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "blastman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 60,
    },
    [3] = {
        player_id = npc_path .. "burnerman/burnerman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "burnerman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 55,
    },
    [4] = {
        player_id = npc_path .. "colonel/colonel1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "colonel/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 70,
    },
    [5] = {
        player_id = npc_path .. "circusman/circusman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "circusman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 45,
    },
    [6] = {
        player_id = npc_path .. "cutman/cutman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "cutman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 40,
    },
    [7] = {
        player_id = npc_path .. "elementman/elementman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "elementman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 65,
    },
    [8] = {
        player_id = npc_path .. "fireman/fireman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "fireman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 58,
    },
    [9] = {
        player_id = npc_path .. "gbeast-megaman/gbeast-megaman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "gbeast-megaman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 80, -- Boss character, higher weight
    },
    [10] = {
        player_id = npc_path .. "gutsman/gutsman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "gutsman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 62,
    },
    [11] = {
        player_id = npc_path .. "hatman/hatman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "hatman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 48,
    },
    [12] = {
        player_id = npc_path .. "iceman/iceman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "iceman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 52,
    },
    [13] = {
        player_id = npc_path .. "jammingman/jammingman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "jammingman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 47,
    },
    [14] = {
        player_id = npc_path .. "protoman/protoman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "protoman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 75, -- Strong character
    },
    [15] = {
        player_id = npc_path .. "quickman/quickman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "quickman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 68,
    },
    [16] = {
        player_id = npc_path .. "roll/roll1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "roll/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 42,
    },
    [17] = {
        player_id = npc_path .. "shadowman/shadowman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "shadowman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 72,
    },
    [18] = {
        player_id = npc_path .. "starman/starman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "starman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 54,
    },
    [19] = {
        player_id = npc_path .. "woodman/woodman1.zip",
        player_mugshot = {
            mug_texture = npc_path .. "woodman/mug.png",
            mug_animation = default_mug_anim,
        },
        weight = 56,
    },
}

return NPC_LIST