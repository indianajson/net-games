local POSITIONS = {
    -- Initial positions - all 8 participants at the bottom
    initial = {
        [1] = { x = 8, y = 132, z = 2 },
        [2] = { x = 34, y = 132, z = 2 },
        [3] = { x = 64, y = 132, z = 2 },
        [4] = { x = 90, y = 132, z = 2 },
        [5] = { x = 128, y = 132, z = 2 },
        [6] = { x = 154, y = 132, z = 2 },
        [7] = { x = 184, y = 132, z = 2 },
        [8] = { x = 210, y = 132, z = 2 },
    },
    -- After Round 1 - 4 winners move up
    round1_winners = {
        [1] = { x = 50, y = 54, z = 2 },
        [2] = { x = 170, y = 54, z = 2 },
        [3] = { x = 78, y = 78, z = 2 },
        [4] = { x = 142, y = 78, z = 2 }
    },
    -- After Round 2 - 2 winners move up  
    round2_winners = {
        [1] = { x = 109, y = 34, z = 2 },
        [2] = { x = 109, y = 54, z = 2 }
    },
    -- After Round 3 - 1 champion at the top
    champion = {
        [1] = { x = 109, y = 34, z = 2 }
    }
}

return POSITIONS