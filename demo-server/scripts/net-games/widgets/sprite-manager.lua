--[[
    Sprite Manager for Pure Sprite Widget Framework
    Handles all sprite allocation, caching, and rendering
    Only uses Net sprite functions: player_alloc_sprite, player_draw_sprite, 
    player_erase_sprite, provide_asset_for_player
]]

local SpriteManager = {}
SpriteManager.__index = SpriteManager

-- Font definitions
SpriteManager.FONTS = {
    THICK = {
        path = "/server/assets/net-games/fonts_thick.png",
        char_width = 8,
        char_height = 8,
        chars_per_row = 16
    },
    BATTLE = {
        path = "/server/assets/net-games/fonts_battle.png",
        char_width = 8,
        char_height = 8,
        chars_per_row = 16
    }
}

-- Character mapping for text rendering
SpriteManager.CHAR_MAP = {
    [" "] = 0, ["!"] = 1, ["\""] = 2, ["#"] = 3, ["$"] = 4, ["%"] = 5, ["&"] = 6, ["'"] = 7,
    ["("] = 8, [")"] = 9, ["*"] = 10, ["+"] = 11, [","] = 12, ["-"] = 13, ["."] = 14, ["/"] = 15,
    ["0"] = 16, ["1"] = 17, ["2"] = 18, ["3"] = 19, ["4"] = 20, ["5"] = 21, ["6"] = 22, ["7"] = 23,
    ["8"] = 24, ["9"] = 25, [":"] = 26, [";"] = 27, ["<"] = 28, ["="] = 29, [">"] = 30, ["?"] = 31,
    ["@"] = 32, ["A"] = 33, ["B"] = 34, ["C"] = 35, ["D"] = 36, ["E"] = 37, ["F"] = 38, ["G"] = 39,
    ["H"] = 40, ["I"] = 41, ["J"] = 42, ["K"] = 43, ["L"] = 44, ["M"] = 45, ["N"] = 46, ["O"] = 47,
    ["P"] = 48, ["Q"] = 49, ["R"] = 50, ["S"] = 51, ["T"] = 52, ["U"] = 53, ["V"] = 54, ["W"] = 55,
    ["X"] = 56, ["Y"] = 57, ["Z"] = 58, ["["] = 59, ["\\"] = 60, ["]"] = 61, ["^"] = 62, ["_"] = 63,
    ["`"] = 64, ["a"] = 65, ["b"] = 66, ["c"] = 67, ["d"] = 68, ["e"] = 69, ["f"] = 70, ["g"] = 71,
    ["h"] = 72, ["i"] = 73, ["j"] = 74, ["k"] = 75, ["l"] = 76, ["m"] = 77, ["n"] = 78, ["o"] = 79,
    ["p"] = 80, ["q"] = 81, ["r"] = 82, ["s"] = 83, ["t"] = 84, ["u"] = 85, ["v"] = 86, ["w"] = 87,
    ["x"] = 88, ["y"] = 89, ["z"] = 90, ["{"] = 91, ["|"] = 92, ["}"] = 93, ["~"] = 94
}

function SpriteManager.new()
    local self = setmetatable({}, SpriteManager)
    
    -- Sprite allocation cache: [player_id][texture_hash] = allocation_data
    self.spriteAllocations = {}
    
    -- Player sprite tracking: [player_id][allocation_id] = {widget_id, sprite_index}
    self.playerSprites = {}
    
    -- Font allocations cache
    self.fontAllocations = {}
    
    return self
end

-- Generate a unique hash for texture/animation combination
function SpriteManager:_generateTextureHash(texture, animation)
    return texture .. (animation or "") .. ":" .. (texture or "") .. (animation or "")
end

-- Get or create sprite allocation for a player
function SpriteManager:getAllocation(player_id, texture, animation, widget_id)
    if not player_id or (not texture and not animation) then
        return nil, "Invalid parameters"
    end
    
    -- Initialize player structures if needed
    if not self.spriteAllocations[player_id] then
        self.spriteAllocations[player_id] = {}
        self.playerSprites[player_id] = {}
    end
    
    local texture_hash = self:_generateTextureHash(texture, animation)
    local allocations = self.spriteAllocations[player_id]
    
    -- Check if allocation already exists
    if allocations[texture_hash] then
        local alloc = allocations[texture_hash]
        
        -- Track widget usage
        if widget_id and not alloc.users[widget_id] then
            alloc.users[widget_id] = true
            alloc.reference_count = alloc.reference_count + 1
        end
        
        return alloc.id, nil
    end
    
    -- Create new allocation
    local allocation_id = "alloc_" .. texture_hash .. "_" .. player_id
    
    -- Provide asset to player
    if texture then
        Net.provide_asset_for_player(player_id, texture)
    end
    if animation then
        Net.provide_asset_for_player(player_id, animation)
    end
    
    -- Allocate sprite
    local sprite_index = Net.player_alloc_sprite(player_id, texture, animation)
    if not sprite_index then
        return nil, "Failed to allocate sprite"
    end
    
    -- Store allocation data
    allocations[texture_hash] = {
        id = allocation_id,
        texture = texture,
        animation = animation,
        sprite_index = sprite_index,
        reference_count = 1,
        users = {[widget_id] = true}
    }
    
    -- Track player sprite
    self.playerSprites[player_id][allocation_id] = {
        widget_id = widget_id,
        sprite_index = sprite_index
    }
    
    return allocation_id, nil
end

-- Draw a sprite for a player
function SpriteManager:drawSprite(player_id, allocation_id, properties)
    if not player_id or not allocation_id then
        return false, "Invalid parameters"
    end
    
    -- Find the allocation
    local sprite_data = nil
    for _, alloc in pairs(self.spriteAllocations[player_id] or {}) do
        if alloc.id == allocation_id then
            sprite_data = alloc
            break
        end
    end
    
    if not sprite_data then
        return false, "Allocation not found"
    end
    
    -- Prepare draw parameters
    local draw_params = {
        x = properties.x or 0,
        y = properties.y or 0,
        z = properties.z or 0,
        scale = properties.scale or 1.0,
        scale_x = properties.scale_x or (properties.scale or 1.0),
        scale_y = properties.scale_y or (properties.scale or 1.0),
        rotation = properties.rotation or 0,
        opacity = properties.opacity or 255,
        red = properties.color and properties.color.r or 255,
        green = properties.color and properties.color.g or 255,
        blue = properties.color and properties.color.b or 255,
        alpha = properties.color and properties.color.a or 255
    }
    
    -- Draw the sprite
    local success = Net.player_draw_sprite(
        player_id,
        sprite_data.sprite_index,
        draw_params.x,
        draw_params.y,
        draw_params.z,
        draw_params.scale_x,
        draw_params.scale_y,
        draw_params.rotation,
        draw_params.opacity,
        draw_params.red,
        draw_params.green,
        draw_params.blue,
        draw_params.alpha
    )
    
    return success, success and nil or "Failed to draw sprite"
end

-- Erase a sprite for a player
function SpriteManager:eraseSprite(player_id, allocation_id)
    if not player_id or not allocation_id then
        return false, "Invalid parameters"
    end
    
    -- Find the allocation
    local sprite_data = nil
    for _, alloc in pairs(self.spriteAllocations[player_id] or {}) do
        if alloc.id == allocation_id then
            sprite_data = alloc
            break
        end
    end
    
    if not sprite_data then
        return false, "Allocation not found"
    end
    
    -- Erase the sprite
    local success = Net.player_erase_sprite(player_id, sprite_data.sprite_index)
    return success, success and nil or "Failed to erase sprite"
end

-- Release an allocation (decrement reference count)
function SpriteManager:releaseAllocation(player_id, allocation_id, widget_id)
    if not player_id or not allocation_id then
        return false, "Invalid parameters"
    end
    
    local allocations = self.spriteAllocations[player_id]
    if not allocations then
        return false, "No allocations for player"
    end
    
    -- Find the allocation by ID
    local target_alloc = nil
    local texture_hash = nil
    
    for hash, alloc in pairs(allocations) do
        if alloc.id == allocation_id then
            target_alloc = alloc
            texture_hash = hash
            break
        end
    end
    
    if not target_alloc then
        return false, "Allocation not found"
    end
    
    -- Remove widget from users
    if widget_id and target_alloc.users[widget_id] then
        target_alloc.users[widget_id] = nil
        target_alloc.reference_count = target_alloc.reference_count - 1
    else
        target_alloc.reference_count = math.max(0, target_alloc.reference_count - 1)
    end
    
    -- Remove allocation if no longer used
    if target_alloc.reference_count <= 0 then
        -- Erase sprite from screen
        self:eraseSprite(player_id, allocation_id)
        
        -- Remove from tracking
        allocations[texture_hash] = nil
        if self.playerSprites[player_id] then
            self.playerSprites[player_id][allocation_id] = nil
        end
        
        -- Note: We don't actually deallocate the sprite - Net handles cleanup on disconnect
    end
    
    return true, nil
end

-- Get font allocation for character rendering
function SpriteManager:getFontAllocation(player_id, font_type, char_index)
    if not player_id or not font_type then
        return nil, "Invalid parameters"
    end
    
    local font = self.FONTS[font_type]
    if not font then
        return nil, "Invalid font type"
    end
    
    -- Ensure font is loaded
    if not self.fontAllocations[player_id] then
        self.fontAllocations[player_id] = {}
    end
    if not self.fontAllocations[player_id][font_type] then
        self.fontAllocations[player_id][font_type] = {}
    end
    
    local font_cache = self.fontAllocations[player_id][font_type]
    
    -- Generate animation path for character
    local char_animation = font.path .. "?animation=" .. tostring(char_index)
    local texture_hash = self:_generateTextureHash(font.path, char_animation)
    
    -- Check if already allocated
    if font_cache[texture_hash] then
        return font_cache[texture_hash], nil
    end
    
    -- Create new allocation
    local allocation_id, error = self:getAllocation(player_id, font.path, char_animation, "font_system")
    if not allocation_id then
        return nil, error
    end
    
    font_cache[texture_hash] = allocation_id
    return allocation_id, nil
end

-- Get character index from character
function SpriteManager:getCharIndex(char)
    return self.CHAR_MAP[char] or 0  -- Default to space if not found
end

-- Clean up all resources for a player (on disconnect)
function SpriteManager:cleanupPlayer(player_id)
    if not player_id then return end
    
    self.spriteAllocations[player_id] = nil
    self.playerSprites[player_id] = nil
    self.fontAllocations[player_id] = nil
end

-- Get sprite index from allocation ID
function SpriteManager:getSpriteIndex(player_id, allocation_id)
    if not player_id or not allocation_id then
        return nil
    end
    
    local allocations = self.spriteAllocations[player_id]
    if not allocations then return nil end
    
    for _, alloc in pairs(allocations) do
        if alloc.id == allocation_id then
            return alloc.sprite_index
        end
    end
    
    return nil
end

return SpriteManager