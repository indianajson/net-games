local mugshot_base_z = 3
local POSITIONS = {
    -- Initial positions - all 8 participants at the bottom
    initial = {
        [1] = { x = 8, y = 132, z = mugshot_base_z },
        [2] = { x = 34, y = 132, z = mugshot_base_z },
        [3] = { x = 64, y = 132, z = mugshot_base_z },
        [4] = { x = 90, y = 132, z = mugshot_base_z },
        [5] = { x = 128, y = 132, z = mugshot_base_z },
        [6] = { x = 154, y = 132, z = mugshot_base_z },
        [7] = { x = 184, y = 132, z = mugshot_base_z },
        [8] = { x = 210, y = 132, z = mugshot_base_z },
    },
    -- After Round 1 - 4 winners move up
    round1_winners = {
        [1] = { x = 22, y = 82, z = mugshot_base_z },
        [2] = { x = 78, y = 82, z = mugshot_base_z },
        [3] = { x = 142, y = 82, z = mugshot_base_z },
        [4] = { x = 198, y = 82, z = mugshot_base_z }
    },
    -- After Round 2 - 2 winners move up  
    round2_winners = {
        [1] = { x = 50, y = 56, z = mugshot_base_z },
        [2] = { x = 170, y = 56, z = mugshot_base_z }
    },
    -- After Round 3 - 1 champion at the top
    champion = {
        [1] = { x = 110, y = 34, z = mugshot_base_z }
    }
}

return POSITIONS