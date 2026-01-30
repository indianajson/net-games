-- widgets.lua
-- Flutter-inspired widget system for net-games framework
-- Version 1.7 with Fixed Sprite Allocation
-- Updated: Fixed sprite ID uniqueness and allocation

-- Load simplified logging module
local LOGGING = require('scripts/net-games/widgets/widget-logging')
local debug_print = LOGGING.debug_print

-- Utility functions
local trim = require('scripts/net-games/avatar_utils/lua_yes_parser/src/utils/trim')
local lib = require('scripts/net-games/avatar_utils/lua_yes_parser/lib')

-- ===========================================================
-- ANIMATION ENGINE INTEGRATION
-- ===========================================================
-- Load animation modules
local AnimationEngine = nil
local AnimationSequences = nil
local AnimationEnums = nil

-- Try to load animation engine modules
local function load_animation_modules()
    if AnimationEngine and AnimationSequences and AnimationEnums then
        return true
    end
    
    local success, engine = pcall(require, 'scripts/net-games/animation-engine/animation-engine')
    if success then
        AnimationEngine = engine
        debug_print("INFO", "AnimationEngine loaded successfully")
    else
        debug_print("ERROR", "Failed to load AnimationEngine: %s", engine)
        AnimationEngine = nil
    end
    
    local success2, sequences = pcall(require, 'scripts/net-games/animation-engine/animation-sequences')
    if success2 then
        AnimationSequences = sequences
        debug_print("INFO", "AnimationSequences loaded successfully")
    else
        debug_print("ERROR", "Failed to load AnimationSequences: %s", sequences)
        AnimationSequences = nil
    end
    
    local success3, enums = pcall(require, 'scripts/net-games/animation-engine/animation-enums')
    if success3 then
        AnimationEnums = enums
        debug_print("INFO", "AnimationEnums loaded successfully")
    else
        debug_print("ERROR", "Failed to load AnimationEnums: %s", enums)
        AnimationEnums = nil
    end
    
    return AnimationEngine ~= nil and AnimationSequences ~= nil and AnimationEnums ~= nil
end

-- ===========================================================
-- PARSER HELPER FUNCTIONS
-- ===========================================================
-- Helper function to parse animation files with better error handling
local function parse_animation_file(file_path)
    if not file_path or file_path == "" then
        debug_print("WARN", "parse_animation_file: Empty file path")
        return nil, {}
    end
    
    local success, elements, errors = pcall(lib.parse, file_path)
    
    if not success then
        debug_print("ERROR", "parse_animation_file: Failed to parse %s - %s", file_path, elements)
        return nil, { { line = 1, type = "FILE_READ_ERROR" } }
    end
    
    if errors and #errors > 0 then
        debug_print("WARN", "parse_animation_file: Found %d errors in %s", #errors, file_path)
        for i, err in ipairs(errors) do
            debug_print("WARN", "  Line %d: %s", err.line, err.type)
        end
    end
    
    return elements, errors or {}
end

-- Helper function to get element attribute with fallback
local function get_element_attribute(element, attr_name, default_value)
    if not element or not element.getKeyValue then
        return default_value
    end
    
    local value = element:getKeyValue(attr_name)
    if value == nil or value == "" then
        return default_value
    end
    
    -- Try to parse as integer
    local num_value = tonumber(value)
    if num_value then
        return num_value
    end
    
    return value
end

-- Helper function to get element attribute as integer
local function get_element_attribute_int(element, attr_name, default_value)
    if not element or not element.getKeyValueAsInt then
        return default_value or 0
    end
    
    return element:getKeyValueAsInt(attr_name, default_value or 0)
end

-- ===========================================================
-- UTILITY FUNCTIONS
-- ===========================================================
local function table_count(t)
    local count = 0
    if t then
        for _ in pairs(t) do count = count + 1 end
    end
    return count
end

local function table_deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table_deepcopy(orig_key)] = table_deepcopy(orig_value)
        end
        setmetatable(copy, table_deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

table.deepcopy = table_deepcopy

local function table_contains(t, value)
    for _, v in pairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

-- Generate unique ID
local function generate_unique_id(prefix)
    local random_part = tostring(math.random(10000, 99999))
    local time_part = tostring(os.time()):sub(-6)
    return (prefix or "id") .. "_" .. time_part .. "_" .. random_part
end

-- ===========================================================
-- WIDGET CACHE
-- ===========================================================
local WidgetCache = {}
local _widget_cache = {} -- player_id -> widget_id -> widget

function WidgetCache.register(widget)
    if not widget or not widget.id or not widget.player_id then
        debug_print("ERROR", "WidgetCache.register: Invalid widget")
        return false
    end
    
    if not _widget_cache[widget.player_id] then
        _widget_cache[widget.player_id] = {}
    end
    
    _widget_cache[widget.player_id][widget.id] = widget
    debug_print("INFO", "WidgetCache.register: %s for player %s", widget.id, widget.player_id)
    return true
end

function WidgetCache.unregister(widget_id, player_id)
    if _widget_cache[player_id] then
        local removed = _widget_cache[player_id][widget_id] ~= nil
        _widget_cache[player_id][widget_id] = nil
        if removed then
            debug_print("INFO", "WidgetCache.unregister: %s for player %s", widget_id, player_id)
        end
        return removed
    end
    return false
end

function WidgetCache.get(widget_id, player_id)
    if _widget_cache[player_id] then
        return _widget_cache[player_id][widget_id]
    end
    return nil
end

function WidgetCache.get_all(player_id)
    if _widget_cache[player_id] then
        local widgets = {}
        for id, widget in pairs(_widget_cache[player_id]) do
            table.insert(widgets, widget)
        end
        return widgets
    end
    return {}
end

function WidgetCache.clear_player(player_id)
    if _widget_cache[player_id] then
        local count = 0
        for _ in pairs(_widget_cache[player_id]) do count = count + 1 end
        _widget_cache[player_id] = nil
        debug_print("INFO", "WidgetCache.clear_player: Cleared %d widgets for player %s", count, player_id)
        return count
    end
    return 0
end

function WidgetCache.stats()
    local total = 0
    for player_id, widgets in pairs(_widget_cache) do
        local count = 0
        for _ in pairs(widgets) do count = count + 1 end
        debug_print("INFO", "  Player %s: %d widgets", player_id, count)
        total = total + count
    end
    debug_print("INFO", "WidgetCache total: %d widgets across %d players", 
               total, table_count(_widget_cache))
    return total
end

-- ===========================================================
-- SPRITE OBJECT MANAGEMENT (FIXED)
-- ===========================================================
local SpriteObject = {}
SpriteObject.__index = SpriteObject

function SpriteObject.new(sprite_id, widget_id, player_id, texture_path, anim_path, anim_state)
    local self = setmetatable({}, SpriteObject)
    
    -- Generate a unique ID for this sprite object
    self.id = sprite_id or generate_unique_id("sprite")
    self.widget_id = widget_id
    self.player_id = player_id
    self.texture_path = texture_path
    self.anim_path = anim_path
    self.anim_state = anim_state or ""
    
    -- Generate a unique template ID for allocation (based on texture/anim paths)
    self.template_id = self.id .. "_template"
    
    self.properties = {
        x = 0,
        y = 0,
        z = 0,
        sx = 2.0,
        sy = 2.0,
        ro = 0,
        opacity = 255,
        r = 255,
        g = 255,
        b = 255,
        a = 255,
        color_mode = 0,
        visible = true
    }
    self.allocated = false
    self.drawn = false
    self.drawn_properties = nil
    
    -- Animation tracking
    self.active_animations = {}
    
    debug_print("DETAILED", "SpriteObject created: %s for widget %s (template: %s)", 
               self.id, widget_id, self.template_id)
    
    return self
end

function SpriteObject:allocate()
    if self.allocated then
        debug_print("VERBOSE", "SpriteObject.allocate: %s already allocated", self.id)
        return true
    end
    
    debug_print("DETAILED", "SpriteObject.allocate: %s with texture=%s, anim=%s, template_id=%s", 
               self.id, self.texture_path, self.anim_path or "none", self.template_id)
    
    -- Provide assets
    if self.anim_path and self.anim_path ~= "" then
        Net.provide_asset_for_player(self.player_id, self.anim_path)
    end
    Net.provide_asset_for_player(self.player_id, self.texture_path)
    
    -- Allocate sprite template
    local success, result = pcall(Net.player_alloc_sprite, self.player_id, self.template_id, {
        texture_path = self.texture_path,
        anim_path = self.anim_path or "",
        anim_state = self.anim_state
    })
    
    if success then
        self.allocated = true
        debug_print("INFO", "SpriteObject.allocate: %s allocated successfully (template: %s)", 
                   self.id, self.template_id)
        return true
    else
        debug_print("ERROR", "SpriteObject.allocate: Failed to allocate %s (template: %s) - %s", 
                   self.id, self.template_id, result)
        return false
    end
end

function SpriteObject:get_origin_offset()
    -- Try to parse the animation file to get origin information
    if not self.anim_path or self.anim_path == "" then
        return 0, 0
    end
    
    local elements, errors = parse_animation_file(self.anim_path)
    
    if not elements or #elements == 0 then
        debug_print("WARN", "SpriteObject.get_origin_offset: No elements found in %s", self.anim_path)
        return 0, 0
    end
    
    local ox, oy = 0, 0
    local in_correct_state = false
    
    debug_print("DETAILED", "Looking for origin in animation state: %s", self.anim_state or "default")
    
    for _, element in ipairs(elements) do
        -- Check if this element starts an animation state
        if element.text == "animation" then
            local state_attr = get_element_attribute(element, "state", "")
            debug_print("VERBOSE", "Found animation element with state: %s", state_attr)
            
            in_correct_state = (state_attr == self.anim_state) or 
                              (self.anim_state == "" and state_attr == "") or
                              (self.anim_state == "" and state_attr == nil)
            
            if in_correct_state then
                debug_print("DETAILED", "Entering correct animation state")
            end
        elseif in_correct_state and element.text == "frame" then
            -- Get origin from frame attributes
            ox = get_element_attribute_int(element, "originx", 0)
            oy = get_element_attribute_int(element, "originy", 0)
            
            -- Try alternative attribute names
            if ox == 0 then
                ox = get_element_attribute_int(element, "ox", 0)
            end
            if oy == 0 then
                oy = get_element_attribute_int(element, "oy", 0)
            end
            
            if ox ~= 0 or oy ~= 0 then
                debug_print("DETAILED", "Found origin for sprite %s: ox=%d, oy=%d", 
                           self.id, ox, oy)
            end
            break
        end
    end
    
    return ox, oy
end

function SpriteObject:draw()
    if not self.allocated then
        if not self:allocate() then
            return false
        end
    end
    
    -- Only draw if visible
    if not self.properties.visible then
        debug_print("VERBOSE", "SpriteObject.draw: %s is not visible, skipping draw", self.id)
        return true
    end
    
    -- Get origin offset if available
    local ox, oy = self:get_origin_offset()
    
    local sprite_data = {
        id = self.id,  -- Use sprite object ID as the instance ID
        x = self.properties.x * 2,  -- Convert to screen coordinates
        y = self.properties.y * 2,
        z = self.properties.z,
        sx = self.properties.sx,
        sy = self.properties.sy,
        ro = self.properties.ro,
        ox = ox,  -- Use origin from animation file
        oy = oy,  -- Use origin from animation file
        a = self.properties.a,
        r = self.properties.r,
        g = self.properties.g,
        b = self.properties.b,
        color_mode = self.properties.color_mode,
        anim_state = self.anim_state,
        opacity = self.properties.opacity
    }
    
    debug_print("VERBOSE", "SpriteObject.draw: %s at (%d,%d) scale=%f,%f origin=(%d,%d) visible=%s template=%s",
               self.id, self.properties.x, self.properties.y,
               self.properties.sx, self.properties.sy,
               ox, oy,
               tostring(self.properties.visible),
               self.template_id)
    
    -- Draw sprite instance using the template
    local success, result = pcall(Net.player_draw_sprite, self.player_id, self.template_id, sprite_data)
    
    if success then
        self.drawn = true
        self.drawn_properties = table.deepcopy(self.properties)
        return true
    else
        debug_print("ERROR", "SpriteObject.draw: Failed to draw %s (template: %s) - %s", 
                   self.id, self.template_id, result)
        return false
    end
end

function SpriteObject:update(properties)
    if not self.allocated then
        debug_print("WARN", "SpriteObject.update: %s not allocated yet, drawing first", self.id)
        return self:draw()
    end
    
    -- Merge properties
    for key, value in pairs(properties) do
        if self.properties[key] ~= nil then
            self.properties[key] = value
        end
    end
    
    -- Only redraw if properties changed
    local needs_redraw = false
    if not self.drawn_properties then
        needs_redraw = true
    else
        for key, value in pairs(properties) do
            if self.drawn_properties[key] ~= value then
                needs_redraw = true
                break
            end
        end
    end
    
    if needs_redraw then
        return self:draw()
    end
    
    return true
end

function SpriteObject:set_position(x, y)
    return self:update({x = x, y = y})
end

function SpriteObject:set_scale(sx, sy)
    return self:update({sx = sx or self.properties.sx, sy = sy or sx or self.properties.sy})
end

function SpriteObject:set_visible(visible)
    return self:update({visible = visible})
end

function SpriteObject:set_opacity(opacity)
    return self:update({opacity = opacity, a = opacity})
end

function SpriteObject:set_color(r, g, b, a)
    return self:update({
        r = r or self.properties.r,
        g = g or self.properties.g,
        b = b or self.properties.b,
        a = a or self.properties.a,
        opacity = a or self.properties.opacity
    })
end

function SpriteObject:set_rotation(rotation)
    return self:update({ro = rotation})
end

function SpriteObject:set_z(z)
    return self:update({z = z})
end

function SpriteObject:remove()
    if self.allocated then
        debug_print("INFO", "SpriteObject.remove: Removing %s (template: %s)", self.id, self.template_id)
        
        -- Remove the sprite instance
        local success, result = pcall(Net.player_erase_sprite, self.player_id, self.id)
        if success then
            self.allocated = false
            self.drawn = false
            self.drawn_properties = nil
            debug_print("INFO", "SpriteObject.remove: %s removed successfully", self.id)
        else
            debug_print("ERROR", "SpriteObject.remove: Failed to remove %s - %s", self.id, result)
        end
        return success
    end
    return true
end

function SpriteObject:get_properties()
    return table.deepcopy(self.properties)
end

function SpriteObject:get_absolute_position()
    -- Returns absolute screen coordinates
    return self.properties.x * 2, self.properties.y * 2
end

-- Animation methods
function SpriteObject:animate(properties, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    if not AnimationEngine then
        debug_print("WARN", "SpriteObject.animate: AnimationEngine not loaded")
        return nil
    end
    
    local start_properties = self:get_properties()
    local target_properties = {}
    
    -- Build target properties
    for key, value in pairs(properties) do
        if start_properties[key] ~= nil then
            target_properties[key] = value
        end
    end
    
    local anim_id = AnimationEngine.animate(start_properties, target_properties, duration, {
        easing = options.easing or "ease_in_out",
        on_update = function(values)
            self:update(values)
        end,
        on_complete = function(values, interrupted)
            self.active_animations[anim_id] = nil
            if options.on_complete then
                options.on_complete(values, interrupted)
            end
        end
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

function SpriteObject:stop_animation(anim_id)
    if anim_id then
        if AnimationEngine then
            AnimationEngine.stop_animation(anim_id)
        end
        self.active_animations[anim_id] = nil
    else
        -- Stop all animations
        for id, _ in pairs(self.active_animations) do
            if AnimationEngine then
                AnimationEngine.stop_animation(id)
            end
        end
        self.active_animations = {}
    end
end

function SpriteObject:is_animating()
    return next(self.active_animations) ~= nil
end

-- ===========================================================
-- DIMENSION CACHE (UPDATED WITH CORRECT ANIMATION PARSING)
-- ===========================================================
local SpriteDimensionCache = {}
local _dimension_cache = {} -- texture_path|anim_path|anim_state -> {width, height}

function SpriteDimensionCache.get_dimensions(texture_path, anim_path, anim_state)
    if not texture_path then
        debug_print("ERROR", "get_dimensions: texture_path is nil!")
        return 0, 0
    end
    
    local key = texture_path .. "|" .. (anim_path or "no_anim") .. "|" .. (anim_state or "")
    
    debug_print("VERBOSE", "get_dimensions called: texture=%s, anim=%s, state=%s", 
               texture_path, anim_path or "nil", anim_state or "nil")
    
    if _dimension_cache[key] then
        debug_print("VERBOSE", "Cache hit for key: %s = %dx%d", key, 
                   _dimension_cache[key].width, _dimension_cache[key].height)
        return _dimension_cache[key].width, _dimension_cache[key].height
    end
    
    debug_print("INFO", "Cache miss for key: %s, parsing...", key)
    
    -- If no anim_path is provided, try to guess it
    local actual_anim_path = anim_path
    if not actual_anim_path and texture_path then
        -- Try common animation file extensions
        if texture_path:match("%.png$") then
            actual_anim_path = texture_path:gsub("%.png$", ".anim")
        else
            actual_anim_path = texture_path .. ".anim"
        end
        debug_print("VERBOSE", "Guessed anim_path: %s", actual_anim_path)
    end
    
    if not actual_anim_path then
        debug_print("WARN", "No animation path provided or guessed, using fallback 0x0")
        _dimension_cache[key] = {width = 0, height = 0}
        return 0, 0
    end
    
    -- Try to parse the animation file
    local elements, errors = parse_animation_file(actual_anim_path)
    
    debug_print("VERBOSE", "Parser result: elements count=%d, errors count=%d", 
               elements and #elements or 0, errors and #errors or 0)
    
    if elements and #elements > 0 then
        local width, height = 0, 0
        
        -- First, if anim_state is specified, look for that specific state
        if anim_state and anim_state ~= "" then
            debug_print("DETAILED", "Looking for specific animation state: %s", anim_state)
            
            local in_correct_state = false
            for _, element in ipairs(elements) do
                -- Check if this element starts an animation state
                if element.text == "animation" then
                    local state_attr = get_element_attribute(element, "state", "")
                    debug_print("VERBOSE", "Found animation element with state: %s", state_attr)
                    
                    in_correct_state = (state_attr == anim_state)
                elseif in_correct_state and element.text == "frame" then
                    -- Found a frame in the correct animation state
                    width = get_element_attribute_int(element, "w", 0)
                    height = get_element_attribute_int(element, "h", 0)
                    
                    debug_print("DETAILED", "Frame in state %s: w=%d, h=%d", 
                               anim_state, width, height)
                    
                    if width > 0 and height > 0 then
                        break
                    end
                end
            end
        end
        
        -- If no specific state found or no state specified, look for any frame
        if width == 0 or height == 0 then
            debug_print("DETAILED", "No specific state found, looking for any frame...")
            
            for _, element in ipairs(elements) do
                if element.text == "frame" then
                    -- Try different attribute names for width and height
                    width = get_element_attribute_int(element, "w", 0)
                    height = get_element_attribute_int(element, "h", 0)
                    
                    debug_print("VERBOSE", "Parsed element: text=%s, w=%d, h=%d", 
                               element.text, width, height)
                    
                    -- If w/h not found, try alternative names
                    if width == 0 then
                        width = get_element_attribute_int(element, "frame_width", 0)
                    end
                    if height == 0 then
                        height = get_element_attribute_int(element, "frame_height", 0)
                    end
                    
                    -- If still not found, try width/height without frame_ prefix
                    if width == 0 then
                        width = get_element_attribute_int(element, "width", 0)
                    end
                    if height == 0 then
                        height = get_element_attribute_int(element, "height", 0)
                    end
                    
                    if width > 0 and height > 0 then
                        debug_print("DETAILED", "Found frame dimensions: %dx%d (using attributes w/h)", width, height)
                        break
                    end
                end
            end
        end
        
        if width == 0 or height == 0 then
            debug_print("WARN", "Could not find frame dimensions in animation file: %s", actual_anim_path)
            width, height = 0, 0
        end
        
        -- Cache the dimensions (in original sprite pixels)
        _dimension_cache[key] = {width = width, height = height}
        debug_print("INFO", "Cached dimensions for %s: %dx%d", key, width, height)
        return width, height
    else
        -- Parse failed or no elements, use fallback
        debug_print("WARN", "Failed to parse animation file or no elements: %s, using fallback 0x0", actual_anim_path)
        _dimension_cache[key] = {width = 0, height = 0}
        return 0, 0
    end
end

function SpriteDimensionCache.clear()
    _dimension_cache = {}
    debug_print("INFO", "Cleared dimension cache")
end

function SpriteDimensionCache.stats()
    local count = 0
    for _ in pairs(_dimension_cache) do count = count + 1 end
    debug_print("INFO", "Dimension cache: %d entries", count)
    return count
end

-- ===========================================================
-- BASE WIDGET CLASS
-- ===========================================================
local Widget = {}
Widget.__index = Widget

function Widget.new(id, player_id)
    local self = setmetatable({}, Widget)
    
    self.id = id or generate_unique_id("widget")
    self.player_id = player_id
    self.x = 0
    self.y = 0
    self.width = 0  -- 0 means size to content
    self.height = 0 -- 0 means size to content
    self.padding = {top = 0, right = 0, bottom = 0, left = 0}
    self.margin = {top = 0, right = 0, bottom = 0, left = 0}
    self.children = {}  -- For layout positioning
    self.sprite_objects = {}  -- sprite_id -> SpriteObject
    self.sprite_groups = {}   -- group_name -> {sprite_id1, sprite_id2, ...}
    self.state = {
        visible = true,
        enabled = true,
        dirty = true,
        needs_layout = true
    }
    self.z_order = 0
    self.parent = nil
    self._calculated_size = {width = 0, height = 0}
    self._child_widgets = {} -- For nested widgets
    self.widget_type = "Widget"  -- For debugging
    
    -- Animation tracking
    self.active_animations = {}
    self.active_sequences = {}
    
    -- Register in cache
    WidgetCache.register(self)
    
    debug_print("INFO", "Widget created: id=%s, player=%s, type=%s", self.id, self.player_id, self.widget_type)
    
    return self
end

-- Create and manage sprite objects
function Widget:create_sprite(sprite_id, texture_path, anim_path, anim_state)
    -- Generate unique sprite ID if not provided
    local unique_sprite_id = sprite_id or generate_unique_id("sprite")
    
    if self.sprite_objects[unique_sprite_id] then
        debug_print("WARN", "Widget.create_sprite: Sprite %s already exists in widget %s", 
                   unique_sprite_id, self.id)
        return self.sprite_objects[unique_sprite_id]
    end
    
    local sprite = SpriteObject.new(unique_sprite_id, self.id, self.player_id, 
                                   texture_path, anim_path, anim_state)
    self.sprite_objects[unique_sprite_id] = sprite
    
    -- Add to children for layout
    table.insert(self.children, {
        type = "sprite",
        sprite_id = unique_sprite_id,
        sprite = sprite,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state,
        id = unique_sprite_id
    })
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.create_sprite: %s added to widget %s", unique_sprite_id, self.id)
    return sprite
end

-- Create sprite group
function Widget:create_sprite_group(group_name, sprite_ids)
    self.sprite_groups[group_name] = sprite_ids or {}
    debug_print("INFO", "Widget.create_sprite_group: Group %s created with %d sprites", 
               group_name, #self.sprite_groups[group_name])
    return self
end

-- Add sprite to group
function Widget:add_sprite_to_group(group_name, sprite_id)
    if not self.sprite_groups[group_name] then
        self.sprite_groups[group_name] = {}
    end
    
    if not table_contains(self.sprite_groups[group_name], sprite_id) then
        table.insert(self.sprite_groups[group_name], sprite_id)
        debug_print("DETAILED", "Widget.add_sprite_to_group: %s added to group %s", 
                   sprite_id, group_name)
    end
    
    return self
end

-- Set properties for specific sprite
function Widget:set_sprite_properties(sprite_id, properties)
    local sprite = self.sprite_objects[sprite_id]
    if sprite then
        debug_print("DETAILED", "Widget.set_sprite_properties: %s in widget %s", 
                   sprite_id, self.id)
        return sprite:update(properties)
    else
        debug_print("WARN", "Widget.set_sprite_properties: Sprite %s not found in widget %s", 
                   sprite_id, self.id)
        return false
    end
end

-- Set properties for sprite group
function Widget:set_group_properties(group_name, properties)
    local group = self.sprite_groups[group_name]
    if group then
        debug_print("DETAILED", "Widget.set_group_properties: Group %s in widget %s (%d sprites)", 
                   group_name, self.id, #group)
        local success = true
        for _, sprite_id in ipairs(group) do
            if not self:set_sprite_properties(sprite_id, properties) then
                success = false
            end
        end
        return success
    else
        debug_print("WARN", "Widget.set_group_properties: Group %s not found in widget %s", 
                   group_name, self.id)
        return false
    end
end

-- Set properties for all sprites in widget
function Widget:set_all_sprites_properties(properties, recursive)
    debug_print("DETAILED", "Widget.set_all_sprites_properties: Widget %s (%d sprites)", 
               self.id, table_count(self.sprite_objects))
    
    local success = true
    
    -- Set for all sprites in this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        if not sprite:update(properties) then
            success = false
        end
    end
    
    -- Recursively set for child widgets
    if recursive then
        for _, child_widget in pairs(self._child_widgets) do
            if not child_widget:set_all_sprites_properties(properties, recursive) then
                success = false
            end
        end
    end
    
    return success
end

-- Get sprite by ID
function Widget:get_sprite(sprite_id)
    return self.sprite_objects[sprite_id]
end

-- Get all sprites
function Widget:get_all_sprites()
    local sprites = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprites[sprite_id] = sprite
    end
    return sprites
end

-- Remove sprite
function Widget:remove_sprite(sprite_id)
    local sprite = self.sprite_objects[sprite_id]
    if sprite then
        -- Stop any active animations
        sprite:stop_animation()
        
        -- Remove from sprite objects
        self.sprite_objects[sprite_id] = nil
        
        -- Remove from children list
        for i, child in ipairs(self.children) do
            if child.type == "sprite" and child.sprite_id == sprite_id then
                table.remove(self.children, i)
                break
            end
        end
        
        -- Remove from groups
        for group_name, group in pairs(self.sprite_groups) do
            for i, id in ipairs(group) do
                if id == sprite_id then
                    table.remove(group, i)
                    break
                end
            end
        end
        
        -- Actually remove the sprite
        sprite:remove()
        
        self.state.dirty = true
        self.state.needs_layout = true
        
        debug_print("INFO", "Widget.remove_sprite: %s removed from widget %s", sprite_id, self.id)
        return true
    end
    return false
end

function Widget:setPosition(x, y)
    debug_print("VERBOSE", "Widget.setPosition: %s from (%d,%d) to (%d,%d)", 
               self.id, self.x, self.y, x, y)
    
    if self.x ~= x or self.y ~= y then
        self.x = x
        self.y = y
        self.state.dirty = true
    end
    return self
end

function Widget:setSize(width, height)
    debug_print("VERBOSE", "Widget.setSize: %s from (%d,%d) to (%d,%d)", 
               self.id, self.width, self.height, width or 0, height or 0)
    
    if self.width ~= width or self.height ~= height then
        self.width = width or 0
        self.height = height or 0
        self.state.dirty = true
        self.state.needs_layout = true
    end
    return self
end

function Widget:setPadding(top, right, bottom, left)
    self.padding = {
        top = top or self.padding.top,
        right = right or (bottom and top or self.padding.right),
        bottom = bottom or top or self.padding.bottom,
        left = left or (right and top or self.padding.left)
    }
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("VERBOSE", "Widget.setPadding: %s = top=%d, right=%d, bottom=%d, left=%d",
               self.id, self.padding.top, self.padding.right, self.padding.bottom, self.padding.left)
    
    return self
end

function Widget:setMargin(top, right, bottom, left)
    self.margin = {
        top = top or self.margin.top,
        right = right or (bottom and top or self.margin.right),
        bottom = bottom or top or self.margin.bottom,
        left = left or (right and top or self.margin.left)
    }
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("VERBOSE", "Widget.setMargin: %s = top=%d, right=%d, bottom=%d, left=%d",
               self.id, self.margin.top, self.margin.right, self.margin.bottom, self.margin.left)
    
    return self
end

function Widget:setVisible(visible)
    debug_print("VERBOSE", "Widget.setVisible: %s = %s", self.id, tostring(visible))
    
    if self.state.visible ~= visible then
        self.state.visible = visible
        self.state.dirty = true
        
        -- Update all sprites
        self:set_all_sprites_properties({visible = visible}, false)
    end
    return self
end

function Widget:setZOrder(z_order)
    self.z_order = z_order or 0
    debug_print("VERBOSE", "Widget.setZOrder: %s = %d", self.id, self.z_order)
    return self
end

-- Animation methods
function Widget:setOpacity(opacity, recursive)
    debug_print("VERBOSE", "Widget.setOpacity: %s = %d, recursive=%s", self.id, opacity, tostring(recursive))
    
    -- Update all sprites in this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_opacity(opacity)
    end
    
    -- Recursively set for child widgets
    if recursive then
        for _, child_widget in pairs(self._child_widgets) do
            child_widget:setOpacity(opacity, recursive)
        end
    end
    
    return self
end

-- Use SpriteObject instead of direct frame calls
function Widget:addChild(child)
    if child and child.id then
        child.parent = self
        
        if child.type == "sprite" and child.texture_path then
            -- Create sprite object
            local unique_sprite_id = child.sprite_id or generate_unique_id("sprite")
            local sprite = self:create_sprite(
                unique_sprite_id,
                child.texture_path,
                child.anim_path,
                child.anim_state
            )
            
            -- Set initial properties if provided
            if child.x or child.y then
                sprite:set_position(child.x or 0, child.y or 0)
            end
            if child.scale then
                sprite:set_scale(child.scale)
            end
            if child.visible ~= nil then
                sprite:set_visible(child.visible)
            end
            
            debug_print("DETAILED", "Widget.addChild: Added sprite %s to widget %s", 
                       sprite.id, self.id)
        else
            table.insert(self.children, child)
            debug_print("DETAILED", "Widget.addChild: Added child with id=%s to widget %s",
                       child.id or "unknown", self.id)
        end
        
        self.state.dirty = true
        self.state.needs_layout = true
        
    else
        debug_print("ERROR", "Widget.addChild: Invalid child provided to %s", self.id)
    end
    return self
end

function Widget:removeChild(child_id)
    debug_print("INFO", "Widget.removeChild: %s removing child_id=%s", self.id, child_id)
    
    -- Check if it's a sprite
    if self.sprite_objects[child_id] then
        return self:remove_sprite(child_id)
    end
    
    -- Check children list
    for i, child in ipairs(self.children) do
        if child.id == child_id then
            -- If it's a widget, destroy it
            if child.widget then
                child.widget:destroy()
            end
            
            table.remove(self.children, i)
            self.state.dirty = true
            self.state.needs_layout = true
            
            debug_print("INFO", "  Successfully removed child at index %d", i)
            return true
        end
    end
    
    debug_print("WARN", "  Child not found: %s", child_id)
    return false
end

function Widget:clearChildren()
    debug_print("INFO", "Widget.clearChildren: %s clearing %d children and %d sprites", 
               self.id, #self.children, table_count(self.sprite_objects))
    
    -- Remove all sprites
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:remove()
    end
    self.sprite_objects = {}
    self.sprite_groups = {}
    
    -- Clear children list
    self.children = {}
    self.state.dirty = true
    self.state.needs_layout = true
    
    return self
end

function Widget:addWidget(widget)
    if widget and widget.update then
        widget.parent = self
        self._child_widgets[widget.id] = widget
        
        -- Add to children for layout
        table.insert(self.children, {
            type = "widget",
            widget = widget,
            id = widget.id
        })
        
        self.state.dirty = true
        self.state.needs_layout = true
        
        debug_print("INFO", "Widget.addWidget: %s added widget %s", self.id, widget.id)
    else
        debug_print("ERROR", "Widget.addWidget: Invalid widget provided to %s", self.id)
    end
    return self
end

function Widget:removeWidget(widget_id)
    debug_print("INFO", "Widget.removeWidget: %s removing widget_id=%s", self.id, widget_id)
    
    if self._child_widgets[widget_id] then
        -- Remove from child widgets
        self._child_widgets[widget_id] = nil
        
        -- Remove from children list
        for i, child in ipairs(self.children) do
            if child.widget and child.widget.id == widget_id then
                table.remove(self.children, i)
                break
            end
        end
        
        self.state.dirty = true
        self.state.needs_layout = true
        
        debug_print("INFO", "  Successfully removed widget")
        return true
    end
    
    debug_print("WARN", "  Widget not found: %s", widget_id)
    return false
end

-- Abstract method to be overridden
function Widget:calculateLayout(available_width, available_height)
    debug_print("VERBOSE", "Widget.calculateLayout (base): %s available=%dx%d", 
               self.id, available_width, available_height)
    
    -- Returns: {width, height, positioned_children}
    return 0, 0, {}
end

function Widget:updateLayout(force)
    debug_print("VERBOSE", "Widget.updateLayout: %s dirty=%s, force=%s, needs_layout=%s", 
               self.id, tostring(self.state.dirty), tostring(force), tostring(self.state.needs_layout))
    
    if self.state.dirty or force or self.state.needs_layout then
        -- Calculate available space considering parent constraints
        local available_width = self.width > 0 and self.width or 9999
        local available_height = self.height > 0 and self.height or 9999
        
        debug_print("DETAILED", "  Available space: %dx%d", available_width, available_height)
        
        local layout_width, layout_height, positioned_children = 
            self:calculateLayout(available_width, available_height)
        
        -- Update calculated size
        self._calculated_size = {
            width = layout_width,
            height = layout_height
        }
        
        debug_print("DETAILED", "  Calculated layout: %dx%d, children positioned: %d",
                   layout_width, layout_height, #positioned_children)
        
        -- Position children (sprites and widgets)
        for i, child in ipairs(positioned_children) do
            local child_x = self.x + child.x + self.padding.left + self.margin.left
            local child_y = self.y + child.y + self.padding.top + self.margin.top
            
            debug_print("VERBOSE", "  Child %d: type=%s, x=%d, y=%d, absolute=(%d,%d)",
                       i, child.sprite_id and "sprite" or "widget", 
                       child.x, child.y, child_x, child_y)
            
            if child.sprite_id then
                -- Update sprite position
                local sprite = self.sprite_objects[child.sprite_id]
                if sprite then
                    sprite:set_position(child_x, child_y)
                    if child.visible ~= nil then
                        sprite:set_visible(self.state.visible and child.visible)
                    else
                        sprite:set_visible(self.state.visible)
                    end
                else
                    debug_print("WARN", "    Sprite not found: %s", child.sprite_id)
                end
            elseif child.widget then
                -- Update child widget
                debug_print("VERBOSE", "    Updating child widget: %s", child.widget.id)
                child.widget:setPosition(child_x, child_y):updateLayout(force)
            end
        end
        
        -- Update child widgets
        local widget_count = 0
        for _, widget in pairs(self._child_widgets) do
            widget_count = widget_count + 1
            widget:updateLayout(force)
        end
        
        if widget_count > 0 then
            debug_print("DETAILED", "  Updated %d child widgets", widget_count)
        end
        
        self.state.dirty = false
        self.state.needs_layout = false
        debug_print("INFO", "Widget layout updated: %s", self.id)
        return true
    else
        debug_print("VERBOSE", "  Widget not dirty, skipping update")
        return false
    end
end

-- Draw all sprites in widget
function Widget:draw(force)
    debug_print("VERBOSE", "Widget.draw: %s with %d sprites", 
               self.id, table_count(self.sprite_objects))
    
    local success = true
    
    -- Draw all sprites
    for sprite_id, sprite in pairs(self.sprite_objects) do
        if force or not sprite.drawn or (sprite.drawn_properties and sprite.drawn_properties.visible ~= sprite.properties.visible) then
            if not sprite:draw() then
                success = false
                debug_print("ERROR", "  Failed to draw sprite: %s", sprite_id)
            end
        end
    end
    
    -- Draw child widgets
    for _, widget in pairs(self._child_widgets) do
        if not widget:draw(force) then
            success = false
        end
    end
    
    return success
end

-- Tick-based update method
function Widget:update(dt)
    debug_print("VERBOSE", "Widget.update: %s with dt=%f", self.id, dt)
    
    local updated = false
    
    -- Update animations through AnimationEngine (which is already updated via tick event)
    -- Check if we need to update layout due to animations
    if self:is_animating() then
        self.state.dirty = true
    end
    
    -- Update layout if dirty
    if self.state.dirty then
        self:updateLayout(false)
        updated = true
    end
    
    -- Update child widgets
    for _, widget in pairs(self._child_widgets) do
        if widget:update(dt) then
            updated = true
        end
    end
    
    return updated
end

-- Proper destruction with cache cleanup
function Widget:destroy()
    debug_print("INFO", "Widget.destroy: %s destroying %d sprites and %d child widgets", 
               self.id, table_count(self.sprite_objects), table_count(self._child_widgets))
    
    -- Stop all animations
    self:stop_all_animations()
    
    -- Remove all sprite objects
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:remove()
    end
    self.sprite_objects = {}
    self.sprite_groups = {}
    
    -- Destroy child widgets
    local widget_count = 0
    for _, widget in pairs(self._child_widgets) do
        widget_count = widget_count + 1
        widget:destroy()
    end
    self._child_widgets = {}
    
    -- Clear children list
    self.children = {}
    
    -- Unregister from cache
    WidgetCache.unregister(self.id, self.player_id)
    
    self.state.dirty = true
    
    debug_print("INFO", "Widget destroyed: %s", self.id)
end

function Widget:getCalculatedSize()
    debug_print("VERBOSE", "Widget.getCalculatedSize: %s = %dx%d", 
               self.id, self._calculated_size.width, self._calculated_size.height)
    
    return self._calculated_size.width, self._calculated_size.height
end

-- Animation methods
function Widget:animate_position(target_x, target_y, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    if not AnimationEngine then
        load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "Widget.animate_position: AnimationEngine not available")
            return nil
        end
    end
    
    local anim_id = AnimationEngine.animate(
        {x = self.x, y = self.y},
        {x = target_x, y = target_y},
        duration,
        {
            easing = options.easing or "ease_in_out",
            on_update = function(values)
                self:setPosition(values.x, values.y)
                if options.on_update then
                    options.on_update(values)
                end
            end,
            on_complete = function(values, interrupted)
                self.active_animations[anim_id] = nil
                if options.on_complete then
                    options.on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

function Widget:animate_opacity(target_opacity, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    if not AnimationEngine then
        load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "Widget.animate_opacity: AnimationEngine not available")
            return nil
        end
    end
    
    -- Get current opacity from first sprite
    local current_opacity = 255
    for _, sprite in pairs(self.sprite_objects) do
        current_opacity = sprite.properties.opacity or 255
        break
    end
    
    local anim_id = AnimationEngine.animate(
        {opacity = current_opacity},
        {opacity = target_opacity},
        duration,
        {
            easing = options.easing or "ease_in_out",
            on_update = function(values)
                self:setOpacity(values.opacity, options.recursive or false)
                if options.on_update then
                    options.on_update(values)
                end
            end,
            on_complete = function(values, interrupted)
                self.active_animations[anim_id] = nil
                if options.on_complete then
                    options.on_complete(values, interrupted)
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

function Widget:stop_animation(anim_id)
    if anim_id then
        if AnimationEngine then
            AnimationEngine.stop_animation(anim_id)
        end
        self.active_animations[anim_id] = nil
    else
        -- Stop all animations
        for id, _ in pairs(self.active_animations) do
            if AnimationEngine then
                AnimationEngine.stop_animation(id)
            end
        end
        self.active_animations = {}
    end
end

function Widget:stop_all_animations()
    self:stop_animation()
    
    -- Stop animations on all sprites
    for _, sprite in pairs(self.sprite_objects) do
        sprite:stop_animation()
    end
    
    -- Stop animations on child widgets
    for _, widget in pairs(self._child_widgets) do
        widget:stop_all_animations()
    end
end

function Widget:is_animating()
    if next(self.active_animations) ~= nil then
        return true
    end
    
    -- Check sprites
    for _, sprite in pairs(self.sprite_objects) do
        if sprite:is_animating() then
            return true
        end
    end
    
    -- Check child widgets
    for _, widget in pairs(self._child_widgets) do
        if widget:is_animating() then
            return true
        end
    end
    
    return false
end

function Widget:printDebugInfo(level)
    level = level or 0
    local indent = string.rep("  ", level)
    
    print(indent .. "Widget: " .. self.id .. " (" .. self.widget_type .. ")")
    print(indent .. "  Position: (" .. self.x .. ", " .. self.y .. ")")
    print(indent .. "  Size: " .. self.width .. "x" .. self.height)
    print(indent .. "  State: visible=" .. tostring(self.state.visible) .. 
          ", enabled=" .. tostring(self.state.enabled) .. 
          ", dirty=" .. tostring(self.state.dirty))
    print(indent .. "  Sprites: " .. table_count(self.sprite_objects))
    print(indent .. "  Sprite Groups: " .. table_count(self.sprite_groups))
    print(indent .. "  Children: " .. #self.children)
    print(indent .. "  Child Widgets: " .. table_count(self._child_widgets))
    print(indent .. "  Active Animations: " .. table_count(self.active_animations))
    
    if table_count(self.sprite_objects) > 0 then
        print(indent .. "  Sprite details:")
        for sprite_id, sprite in pairs(self.sprite_objects) do
            print(indent .. "    " .. sprite_id .. ": " .. 
                  (sprite.texture_path or "unknown") .. 
                  " (template: " .. sprite.template_id .. 
                  ", animating: " .. tostring(sprite:is_animating()) .. ")")
        end
    end
    
    if table_count(self.sprite_groups) > 0 then
        print(indent .. "  Sprite Group details:")
        for group_name, sprite_ids in pairs(self.sprite_groups) do
            print(indent .. "    " .. group_name .. ": " .. #sprite_ids .. " sprites")
        end
    end
end

-- ===========================================================
-- ROW WIDGET
-- ===========================================================
local Row = setmetatable({}, {__index = Widget})

function Row.new(id, player_id)
    local self = Widget.new(id, player_id)
    setmetatable(self, {__index = Row})
    
    self.main_axis_alignment = "start"
    self.cross_axis_alignment = "start"
    self.spacing = 0
    self.widget_type = "Row"
    
    debug_print("INFO", "Row created: %s", self.id)
    
    return self
end

function Row:setAlignment(main_axis, cross_axis)
    self.main_axis_alignment = main_axis or self.main_axis_alignment
    self.cross_axis_alignment = cross_axis or self.cross_axis_alignment
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Row.setAlignment: %s main=%s, cross=%s", 
               self.id, self.main_axis_alignment, self.cross_axis_alignment)
    
    return self
end

function Row:setSpacing(spacing)
    self.spacing = spacing or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Row.setSpacing: %s = %d", self.id, self.spacing)
    
    return self
end

function Row:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "Row.calculateLayout: %s with %d children", 
               self.id, #self.children)
    
    local total_width = 0
    local max_height = 0
    local positioned_children = {}
    
    debug_print("VERBOSE", "  Main axis alignment: %s", self.main_axis_alignment)
    debug_print("VERBOSE", "  Cross axis alignment: %s", self.cross_axis_alignment)
    debug_print("VERBOSE", "  Spacing: %d", self.spacing)
    
    -- First pass: calculate dimensions
    for i, child in ipairs(self.children) do
        local child_width, child_height = 0, 0
        
        if child.type == "sprite" then
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                child_width, child_height = SpriteDimensionCache.get_dimensions(
                    child.texture_path, child.anim_path, child.anim_state)
                
                debug_print("VERBOSE", "  Child %d sprite dimensions: %dx%d", 
                           i, child_width, child_height)
                
                -- Apply scale if specified
                local props = sprite:get_properties()
                if props.sx then
                    child_width = child_width * props.sx
                    child_height = child_height * props.sy or props.sx
                    debug_print("VERBOSE", "    After scale %f,%f: %dx%d", 
                               props.sx, props.sy or props.sx, child_width, child_height)
                end
            end
        elseif child.widget then
            child_width, child_height = child.widget:getCalculatedSize()
            debug_print("VERBOSE", "  Child %d widget dimensions: %dx%d", i, child_width, child_height)
        elseif child.width and child.height then
            child_width = child.width
            child_height = child.height
            debug_print("VERBOSE", "  Child %d explicit dimensions: %dx%d", i, child_width, child_height)
        else
            debug_print("WARN", "  Child %d has no dimensions!", i)
        end
        
        -- Adjust for cross axis alignment
        if self.cross_axis_alignment == "stretch" then
            child_height = math.max(child_height, available_height - self.padding.top - self.padding.bottom)
            debug_print("VERBOSE", "    Stretched height to: %d", child_height)
        end
        
        table.insert(positioned_children, {
            sprite_id = child.sprite_id,
            widget = child.widget,
            width = child_width,
            height = child_height,
            x = total_width,
            y = 0,
            visible = child.visible ~= false
        })
        
        debug_print("VERBOSE", "  Child %d positioned at x=%d", i, total_width)
        
        total_width = total_width + child_width
        max_height = math.max(max_height, child_height)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_width = total_width + self.spacing
            debug_print("VERBOSE", "  Added spacing: total_width now %d", total_width)
        end
    end
    
    debug_print("DETAILED", "  First pass total: width=%d, max_height=%d", total_width, max_height)
    
    -- Adjust for main axis alignment
    local extra_width = available_width - total_width - self.padding.left - self.padding.right
    debug_print("VERBOSE", "  Extra width available: %d", extra_width)
    
    if extra_width > 0 then
        local start_x = 0
        
        if self.main_axis_alignment == "center" then
            start_x = extra_width / 2
            debug_print("VERBOSE", "  Center alignment: start_x=%d", start_x)
        elseif self.main_axis_alignment == "end" then
            start_x = extra_width
            debug_print("VERBOSE", "  End alignment: start_x=%d", start_x)
        elseif self.main_axis_alignment == "space_between" then
            if #positioned_children > 1 then
                local spacing = extra_width / (#positioned_children - 1)
                debug_print("VERBOSE", "  Space between: spacing=%d", spacing)
                for i = 2, #positioned_children do
                    positioned_children[i].x = positioned_children[i].x + (spacing * (i - 1))
                end
            end
        elseif self.main_axis_alignment == "space_around" then
            local spacing = extra_width / #positioned_children
            debug_print("VERBOSE", "  Space around: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].x = positioned_children[i].x + (spacing * (i - 0.5))
            end
        elseif self.main_axis_alignment == "space_evenly" then
            local spacing = extra_width / (#positioned_children + 1)
            debug_print("VERBOSE", "  Space evenly: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].x = positioned_children[i].x + (spacing * i)
            end
        end
        
        -- Apply start offset
        if start_x > 0 then
            debug_print("VERBOSE", "  Applying start offset: %d", start_x)
            for _, child in ipairs(positioned_children) do
                child.x = child.x + start_x
            end
        end
    end
    
    -- Adjust for cross axis alignment
    for i, child in ipairs(positioned_children) do
        local extra_height = max_height - child.height
        
        if self.cross_axis_alignment == "center" then
            child.y = extra_height / 2
            debug_print("VERBOSE", "  Child %d centered vertically: y=%d", i, child.y)
        elseif self.cross_axis_alignment == "end" then
            child.y = extra_height
            debug_print("VERBOSE", "  Child %d aligned to end: y=%d", i, child.y)
        else
            debug_print("VERBOSE", "  Child %d aligned to start: y=0", i)
        end
    end
    
    local layout_width = math.max(total_width, self.width)
    local layout_height = math.max(max_height, self.height)
    
    debug_print("INFO", "Row layout calculated: %s = %dx%d", 
               self.id, layout_width, layout_height)
    
    return layout_width, layout_height, positioned_children
end

-- ===========================================================
-- COLUMN WIDGET
-- ===========================================================
local Column = setmetatable({}, {__index = Widget})

function Column.new(id, player_id)
    local self = Widget.new(id, player_id)
    setmetatable(self, {__index = Column})
    
    self.main_axis_alignment = "start"
    self.cross_axis_alignment = "start"
    self.spacing = 0
    self.widget_type = "Column"
    
    debug_print("INFO", "Column created: %s", self.id)
    
    return self
end

function Column:setAlignment(main_axis, cross_axis)
    self.main_axis_alignment = main_axis or self.main_axis_alignment
    self.cross_axis_alignment = cross_axis or self.cross_axis_alignment
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Column.setAlignment: %s main=%s, cross=%s", 
               self.id, self.main_axis_alignment, self.cross_axis_alignment)
    
    return self
end

function Column:setSpacing(spacing)
    self.spacing = spacing or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Column.setSpacing: %s = %d", self.id, self.spacing)
    
    return self
end

function Column:calculateLayout(available_width, available_height)
    debug_print("DETAILED", "Column.calculateLayout: %s with %d children", 
               self.id, #self.children)
    
    local total_height = 0
    local max_width = 0
    local positioned_children = {}
    
    debug_print("VERBOSE", "  Main axis alignment: %s", self.main_axis_alignment)
    debug_print("VERBOSE", "  Cross axis alignment: %s", self.cross_axis_alignment)
    debug_print("VERBOSE", "  Spacing: %d", self.spacing)
    
    -- First pass: calculate dimensions
    for i, child in ipairs(self.children) do
        local child_width, child_height = 0, 0
        
        if child.type == "sprite" then
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                child_width, child_height = SpriteDimensionCache.get_dimensions(
                    child.texture_path, child.anim_path, child.anim_state)
                
                debug_print("VERBOSE", "  Child %d sprite dimensions: %dx%d", 
                           i, child_width, child_height)
                
                -- Apply scale if specified
                local props = sprite:get_properties()
                if props.sx then
                    child_width = child_width * props.sx
                    child_height = child_height * props.sy or props.sx
                    debug_print("VERBOSE", "    After scale %f,%f: %dx%d", 
                               props.sx, props.sy or props.sx, child_width, child_height)
                end
            end
        elseif child.widget then
            child_width, child_height = child.widget:getCalculatedSize()
            debug_print("VERBOSE", "  Child %d widget dimensions: %dx%d", i, child_width, child_height)
        elseif child.width and child.height then
            child_width = child.width
            child_height = child.height
            debug_print("VERBOSE", "  Child %d explicit dimensions: %dx%d", i, child_width, child_height)
        else
            debug_print("WARN", "  Child %d has no dimensions!", i)
        end
        
        -- Adjust for cross axis alignment
        if self.cross_axis_alignment == "stretch" then
            child_width = math.max(child_width, available_width - self.padding.left - self.padding.right)
            debug_print("VERBOSE", "    Stretched width to: %d", child_width)
        end
        
        table.insert(positioned_children, {
            sprite_id = child.sprite_id,
            widget = child.widget,
            width = child_width,
            height = child_height,
            x = 0,
            y = total_height,
            visible = child.visible ~= false
        })
        
        debug_print("VERBOSE", "  Child %d positioned at y=%d", i, total_height)
        
        total_height = total_height + child_height
        max_width = math.max(max_width, child_width)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_height = total_height + self.spacing
            debug_print("VERBOSE", "  Added spacing: total_height now %d", total_height)
        end
    end
    
    debug_print("DETAILED", "  First pass total: max_width=%d, height=%d", max_width, total_height)
    
    -- Adjust for main axis alignment
    local extra_height = available_height - total_height - self.padding.top - self.padding.bottom
    debug_print("VERBOSE", "  Extra height available: %d", extra_height)
    
    if extra_height > 0 then
        local start_y = 0
        
        if self.main_axis_alignment == "center" then
            start_y = extra_height / 2
            debug_print("VERBOSE", "  Center alignment: start_y=%d", start_y)
        elseif self.main_axis_alignment == "end" then
            start_y = extra_height
            debug_print("VERBOSE", "  End alignment: start_y=%d", start_y)
        elseif self.main_axis_alignment == "space_between" then
            if #positioned_children > 1 then
                local spacing = extra_height / (#positioned_children - 1)
                debug_print("VERBOSE", "  Space between: spacing=%d", spacing)
                for i = 2, #positioned_children do
                    positioned_children[i].y = positioned_children[i].y + (spacing * (i - 1))
                end
            end
        elseif self.main_axis_alignment == "space_around" then
            local spacing = extra_height / #positioned_children
            debug_print("VERBOSE", "  Space around: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].y = positioned_children[i].y + (spacing * (i - 0.5))
            end
        elseif self.main_axis_alignment == "space_evenly" then
            local spacing = extra_height / (#positioned_children + 1)
            debug_print("VERBOSE", "  Space evenly: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].y = positioned_children[i].y + (spacing * i)
            end
        end
        
        -- Apply start offset
        if start_y > 0 then
            debug_print("VERBOSE", "  Applying start offset: %d", start_y)
            for _, child in ipairs(positioned_children) do
                child.y = child.y + start_y
            end
        end
    end
    
    -- Adjust for cross axis alignment
    for i, child in ipairs(positioned_children) do
        local extra_width = max_width - child.width
        
        if self.cross_axis_alignment == "center" then
            child.x = extra_width / 2
            debug_print("VERBOSE", "  Child %d centered horizontally: x=%d", i, child.x)
        elseif self.cross_axis_alignment == "end" then
            child.x = extra_width
            debug_print("VERBOSE", "  Child %d aligned to end: x=%d", i, child.x)
        else
            debug_print("VERBOSE", "  Child %d aligned to start: x=0", i)
        end
    end
    
    local layout_width = math.max(max_width, self.width)
    local layout_height = math.max(total_height, self.height)
    
    debug_print("INFO", "Column layout calculated: %s = %dx%d", 
               self.id, layout_width, layout_height)
    
    return layout_width, layout_height, positioned_children
end

-- ===========================================================
-- GRID WIDGET
-- ===========================================================
local Grid = setmetatable({}, {__index = Widget})

function Grid.new(id, player_id)
    local self = Widget.new(id, player_id)
    setmetatable(self, {__index = Grid})
    
    self.columns = 3
    self.horizontal_spacing = 0
    self.vertical_spacing = 0
    self.cell_width = 0  -- 0 means auto-size
    self.cell_height = 0 -- 0 means auto-size
    self.items = {}
    self.selected_index = 0
    self.on_selection_changed = nil
    self.widget_type = "Grid"
    
    debug_print("INFO", "Grid created: %s", self.id)
    
    return self
end

function Grid:setColumns(columns)
    self.columns = math.max(1, columns or 3)
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Grid.setColumns: %s = %d", self.id, self.columns)
    
    return self
end

function Grid:setSpacing(horizontal, vertical)
    self.horizontal_spacing = horizontal or self.horizontal_spacing
    self.vertical_spacing = vertical or self.vertical_spacing
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Grid.setSpacing: %s = h=%d, v=%d", 
               self.id, self.horizontal_spacing, self.vertical_spacing)
    
    return self
end

function Grid:setCellSize(width, height)
    self.cell_width = width or 0
    self.cell_height = height or 0
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Grid.setCellSize: %s = %dx%d", 
               self.id, self.cell_width, self.cell_height)
    
    return self
end

function Grid:addItem(item_id, texture_path, anim_path, anim_state, data)
    debug_print("INFO", "Grid.addItem: %s adding item %s", self.id, item_id)
    
    local item = {
        id = item_id,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state or "",
        data = data or {},
        sprite_id = generate_unique_id(self.id .. "_item")
    }
    
    table.insert(self.items, item)
    
    -- Add as child sprite
    self:addChild({
        type = "sprite",
        sprite_id = item.sprite_id,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state,
        id = item_id
    })
    
    debug_print("DETAILED", "  Item sprite_id: %s", item.sprite_id)
    debug_print("DETAILED", "  Total items: %d", #self.items)
    
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Grid:removeItem(item_id)
    debug_print("INFO", "Grid.removeItem: %s removing item %s", self.id, item_id)
    
    for i, item in ipairs(self.items) do
        if item.id == item_id then
            -- Remove sprite
            self:removeChild(item.sprite_id)
            
            -- Remove from items
            table.remove(self.items, i)
            
            -- Update selection if needed
            if self.selected_index >= i then
                self.selected_index = math.max(0, self.selected_index - 1)
            end
            
            debug_print("DETAILED", "  Item removed, selected_index now %d", self.selected_index)
            
            self.state.dirty = true
            self.state.needs_layout = true
            return true
        end
    end
    
    debug_print("WARN", "  Item not found: %s", item_id)
    return false
end

function Grid:clearItems()
    debug_print("INFO", "Grid.clearItems: %s clearing %d items", self.id, #self.items)
    
    for _, item in ipairs(self.items) do
        self:removeChild(item.sprite_id)
    end
    self.items = {}
    self.selected_index = 0
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Grid:setSelectedIndex(index, emit_event)
    local new_index = math.max(0, math.min(index, #self.items))
    
    debug_print("INFO", "Grid.setSelectedIndex: %s from %d to %d (total items: %d)",
               self.id, self.selected_index, new_index, #self.items)
    
    if new_index ~= self.selected_index then
        self.selected_index = new_index
        
        if emit_event ~= false and self.on_selection_changed then
            local selected_item = new_index > 0 and self.items[new_index] or nil
            debug_print("DETAILED", "  Calling on_selection_changed callback")
            self.on_selection_changed(new_index, selected_item)
        end
        
        self.state.dirty = true
    else
        debug_print("VERBOSE", "  Selection unchanged")
    end
    return self
end

function Grid:calculateLayout(available_width, available_height)
    if #self.items == 0 then
        debug_print("WARN", "Grid.calculateLayout: %s has no items", self.id)
        return 0, 0, {}
    end
    
    debug_print("DETAILED", "Grid.calculateLayout: %s with %d items, %d columns", 
               self.id, #self.items, self.columns)
    
    -- Calculate cell dimensions
    local cell_width = self.cell_width
    local cell_height = self.cell_height
    
    debug_print("VERBOSE", "  Initial cell size: %dx%d", cell_width, cell_height)
    
    if cell_width == 0 or cell_height == 0 then
        -- Auto-size: find largest item
        local max_item_width, max_item_height = 0, 0
        
        for i, item in ipairs(self.items) do
            local item_width, item_height = SpriteDimensionCache.get_dimensions(
                item.texture_path, item.anim_path, item.anim_state)
            
            debug_print("VERBOSE", "  Item %d (%s) dimensions: %dx%d", 
                       i, item.id, item_width, item_height)
            
            max_item_width = math.max(max_item_width, item_width)
            max_item_height = math.max(max_item_height, item_height)
        end
        
        cell_width = cell_width == 0 and max_item_width or cell_width
        cell_height = cell_height == 0 and max_item_height or cell_height
        
        debug_print("DETAILED", "  Auto-sized cell: %dx%d", cell_width, cell_height)
    end
    
    -- Calculate grid dimensions
    local rows = math.ceil(#self.items / self.columns)
    local grid_width = (cell_width * self.columns) + (self.horizontal_spacing * (self.columns - 1))
    local grid_height = (cell_height * rows) + (self.vertical_spacing * (rows - 1))
    
    debug_print("DETAILED", "  Grid dimensions: %dx%d (rows=%d)", grid_width, grid_height, rows)
    
    -- Position items
    local positioned_children = {}
    
    for i, item in ipairs(self.items) do
        local row = math.floor((i - 1) / self.columns)
        local col = (i - 1) % self.columns
        
        local x = col * (cell_width + self.horizontal_spacing)
        local y = row * (cell_height + self.vertical_spacing)
        
        debug_print("VERBOSE", "  Item %d: row=%d, col=%d, base position=(%d,%d)", 
                   i, row, col, x, y)
        
        -- Center sprite in cell
        local sprite_width, sprite_height = SpriteDimensionCache.get_dimensions(
            item.texture_path, item.anim_path, item.anim_state)
        
        local offset_x = (cell_width - sprite_width) / 2
        local offset_y = (cell_height - sprite_height) / 2
        
        debug_print("VERBOSE", "    Sprite: %dx%d, offset=(%d,%d)", 
                   sprite_width, sprite_height, offset_x, offset_y)
        
        table.insert(positioned_children, {
            sprite_id = item.sprite_id,
            x = x + offset_x,
            y = y + offset_y,
            visible = true
        })
    end
    
    debug_print("INFO", "Grid layout calculated: %s = %dx%d, positioned %d items", 
               self.id, grid_width, grid_height, #positioned_children)
    
    return grid_width, grid_height, positioned_children
end

-- ===========================================================
-- CONTAINER WIDGET
-- ===========================================================
local Container = setmetatable({}, {__index = Widget})

function Container.new(id, player_id)
    local self = Widget.new(id, player_id)
    setmetatable(self, {__index = Container})
    
    self.child = nil
    self.widget_type = "Container"
    
    debug_print("INFO", "Container created: %s", self.id)
    
    return self
end

function Container:setChild(widget)
    debug_print("INFO", "Container.setChild: %s setting child to %s", 
               self.id, widget and widget.id or "nil")
    
    if self.child then
        debug_print("VERBOSE", "  Removing previous child")
        self:removeWidget(self.child.id)
    end
    
    self.child = widget
    if widget then
        widget.parent = self
        self:addWidget(widget)
        debug_print("VERBOSE", "  Child parent set")
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Container:calculateLayout(available_width, available_height)
    if not self.child then
        debug_print("WARN", "Container.calculateLayout: %s has no child", self.id)
        return 0, 0, {}
    end
    
    debug_print("DETAILED", "Container.calculateLayout: %s with child %s", 
               self.id, self.child.id)
    
    -- Calculate available space for child
    local child_width = available_width - self.padding.left - self.padding.right
    local child_height = available_height - self.padding.top - self.padding.bottom
    
    debug_print("VERBOSE", "  Available for child: %dx%d (after padding)", 
               child_width, child_height)
    
    -- Update child layout
    self.child:setSize(child_width, child_height)
    self.child:updateLayout()
    
    local child_layout_width, child_layout_height = self.child:getCalculatedSize()
    
    debug_print("VERBOSE", "  Child calculated size: %dx%d", 
               child_layout_width, child_layout_height)
    
    -- Position child
    local positioned_children = {{
        widget = self.child,
        x = self.padding.left,
        y = self.padding.top,
        visible = self.state.visible
    }}
    
    local layout_width = child_layout_width + self.padding.left + self.padding.right
    local layout_height = child_layout_height + self.padding.top + self.padding.bottom
    
    debug_print("INFO", "Container layout calculated: %s = %dx%d", 
               self.id, layout_width, layout_height)
    
    return layout_width, layout_height, positioned_children
end

-- ===========================================================
-- EXPANDED WIDGET
-- ===========================================================
local Expanded = setmetatable({}, {__index = Widget})

function Expanded.new(id, player_id)
    local self = Widget.new(id, player_id)
    setmetatable(self, {__index = Expanded})
    
    self.flex = 1
    self.child = nil
    self.widget_type = "Expanded"
    
    debug_print("INFO", "Expanded created: %s", self.id)
    
    return self
end

function Expanded:setFlex(flex)
    self.flex = math.max(1, flex or 1)
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("DETAILED", "Expanded.setFlex: %s = %d", self.id, self.flex)
    
    return self
end

function Expanded:setChild(widget)
    debug_print("INFO", "Expanded.setChild: %s setting child to %s", 
               self.id, widget and widget.id or "nil")
    
    if self.child then
        debug_print("VERBOSE", "  Removing previous child")
        self:removeWidget(self.child.id)
    end
    
    self.child = widget
    if widget then
        widget.parent = self
        self:addWidget(widget)
    end
    
    self.state.dirty = true
    self.state.needs_layout = true
    return self
end

function Expanded:calculateLayout(available_width, available_height)
    if not self.child then
        debug_print("WARN", "Expanded.calculateLayout: %s has no child", self.id)
        return 0, 0, {}
    end
    
    debug_print("DETAILED", "Expanded.calculateLayout: %s with child %s, taking %dx%d", 
               self.id, self.child.id, available_width, available_height)
    
    -- Expanded takes all available space
    self.child:setSize(available_width, available_height)
    self.child:updateLayout()
    
    local child_layout_width, child_layout_height = self.child:getCalculatedSize()
    
    local positioned_children = {{
        widget = self.child,
        x = 0,
        y = 0,
        visible = self.state.visible
    }}
    
    return child_layout_width, child_layout_height, positioned_children
end

-- ===========================================================
-- SELECTION MANAGER
-- ===========================================================
local SelectionManager = {}

function SelectionManager.new()
    local self = {
        selected_widget = nil,
        selected_index = 0,
        widgets = {},
        on_selection_changed = nil,
        movement_type = "vertical" -- vertical, horizontal, grid
    }
    
    debug_print("INFO", "SelectionManager created")
    
    function self:registerWidget(widget)
        if widget and widget.id then
            self.widgets[widget.id] = widget
            debug_print("INFO", "SelectionManager.registerWidget: %s", widget.id)
        else
            debug_print("ERROR", "SelectionManager.registerWidget: Invalid widget")
        end
    end
    
    function self:unregisterWidget(widget_id)
        debug_print("INFO", "SelectionManager.unregisterWidget: %s", widget_id)
        self.widgets[widget_id] = nil
    end
    
    function self:selectWidget(widget_id, index)
        debug_print("INFO", "SelectionManager.selectWidget: %s at index %d", 
                   widget_id, index or 0)
        
        if self.widgets[widget_id] then
            local prev_widget = self.selected_widget
            
            if prev_widget and prev_widget.setSelectedIndex then
                debug_print("DETAILED", "  Clearing selection from previous widget")
                prev_widget:setSelectedIndex(0, false)
            end
            
            self.selected_widget = self.widgets[widget_id]
            self.selected_index = index or 1
            
            if self.selected_widget.setSelectedIndex then
                debug_print("DETAILED", "  Setting selection on widget")
                self.selected_widget:setSelectedIndex(self.selected_index, false)
            end
            
            if self.on_selection_changed then
                debug_print("DETAILED", "  Calling on_selection_changed callback")
                self.on_selection_changed(self.selected_widget, self.selected_index)
            end
            
            debug_print("INFO", "  Widget selected successfully")
            return true
        end
        
        debug_print("ERROR", "  Widget not found: %s", widget_id)
        return false
    end
    
    function self:moveSelection(direction)
        if not self.selected_widget then
            debug_print("WARN", "SelectionManager.moveSelection: No widget selected")
            return false
        end
        
        debug_print("INFO", "SelectionManager.moveSelection: %s in direction %s", 
                   self.selected_widget.id, direction)
        
        local new_index = self.selected_index
        
        if direction == "up" or direction == "left" then
            new_index = math.max(1, self.selected_index - 1)
            debug_print("VERBOSE", "  Moving up/left: %d -> %d", self.selected_index, new_index)
        elseif direction == "down" or direction == "right" then
            if self.selected_widget.items then
                new_index = math.min(#self.selected_widget.items, self.selected_index + 1)
                debug_print("VERBOSE", "  Moving down/right (items): %d -> %d", self.selected_index, new_index)
            elseif self.selected_widget.children then
                new_index = math.min(#self.selected_widget.children, self.selected_index + 1)
                debug_print("VERBOSE", "  Moving down/right (children): %d -> %d", self.selected_index, new_index)
            end
        end
        
        if new_index ~= self.selected_index then
            self.selected_index = new_index
            
            if self.selected_widget.setSelectedIndex then
                debug_print("DETAILED", "  Updating widget selection")
                self.selected_widget:setSelectedIndex(self.selected_index, false)
            end
            
            if self.on_selection_changed then
                debug_print("DETAILED", "  Calling on_selection_changed callback")
                self.on_selection_changed(self.selected_widget, self.selected_index)
            end
            
            debug_print("INFO", "  Selection moved successfully")
            return true
        end
        
        debug_print("VERBOSE", "  Selection unchanged")
        return false
    end
    
    function self:getSelectedItem()
        if not self.selected_widget or not self.selected_widget.items then
            debug_print("VERBOSE", "SelectionManager.getSelectedItem: No item selected")
            return nil
        end
        
        local item = self.selected_widget.items[self.selected_index]
        debug_print("VERBOSE", "SelectionManager.getSelectedItem: %s", 
                   item and item.id or "nil")
        return item
    end
    
    function self:clearSelection()
        debug_print("INFO", "SelectionManager.clearSelection")
        
        if self.selected_widget and self.selected_widget.setSelectedIndex then
            self.selected_widget:setSelectedIndex(0, false)
        end
        
        self.selected_widget = nil
        self.selected_index = 0
    end
    
    function self:printDebugInfo()
        print("[SelectionManager Debug]")
        print("  Selected widget:", self.selected_widget and self.selected_widget.id or "nil")
        print("  Selected index:", self.selected_index)
        print("  Registered widgets:", #self.widgets)
        for id, _ in pairs(self.widgets) do
            print("    - " .. id)
        end
    end
    
    return self
end

-- ===========================================================
-- WIDGET BUILDER
-- ===========================================================
local WidgetBuilder = {}

function WidgetBuilder.createMenu(id, player_id, options)
    debug_print("INFO", "WidgetBuilder.createMenu: %s with %d options", id, #options)
    
    local menu = Column.new(id, player_id)
        :setSpacing(10)
        :setAlignment("start", "center")
    
    for i, option in ipairs(options) do
        debug_print("DETAILED", "  Adding menu option %d: %s", i, option.id or i)
        
        menu:addChild({
            type = "sprite",
            sprite_id = generate_unique_id(id .. "_option"),
            texture_path = option.texture_path,
            anim_path = option.anim_path,
            anim_state = option.anim_state or "normal",
            id = option.id or ("option_" .. i)
        })
    end
    
    return menu
end

function WidgetBuilder.createInventoryGrid(id, player_id, columns, cell_size)
    debug_print("INFO", "WidgetBuilder.createInventoryGrid: %s, columns=%d, cell_size=%d", 
               id, columns, cell_size)
    
    local grid = Grid.new(id, player_id)
        :setColumns(columns)
        :setSpacing(5, 5)
        :setCellSize(cell_size, cell_size)
    
    return grid
end

function WidgetBuilder.createHUD(id, player_id, elements)
    debug_print("INFO", "WidgetBuilder.createHUD: %s with %d elements", id, #elements)
    
    local hud = Row.new(id, player_id)
        :setSpacing(20)
        :setAlignment("space_between", "center")
    
    for i, element in ipairs(elements) do
        debug_print("DETAILED", "  Adding HUD element %d: %s", i, element.id)
        
        hud:addChild({
            type = "sprite",
            sprite_id = generate_unique_id(id .. "_" .. element.id),
            texture_path = element.texture_path,
            anim_path = element.anim_path,
            anim_state = element.anim_state,
            id = element.id
        })
    end
    
    return hud
end

-- ===========================================================
-- ANIMATION HELPERS (UPDATED - NO FRAMEWORK DEPENDENCY)
-- ===========================================================
local WidgetAnimations = {}

-- Slide widget animation using internal AnimationEngine
function WidgetAnimations.slideWidget(widget, target_x, target_y, duration, ...)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.slideWidget: Invalid widget")
        return nil
    end
    
    -- Handle variable arguments for backward compatibility
    local args = {...}
    local options = {}
    
    -- If the last argument is a function, treat it as on_complete
    if #args > 0 and type(args[#args]) == "function" then
        options.on_complete = args[#args]
        table.remove(args, #args)
    end
    
    -- If there's still an argument and it's a string, treat it as easing
    if #args > 0 and type(args[#args]) == "string" then
        options.easing = args[#args]
        table.remove(args, #args)
    end
    
    -- If the remaining argument is a table, merge it with options
    if #args > 0 and type(args[#args]) == "table" then
        for k, v in pairs(args[#args]) do
            options[k] = v
        end
    end
    
    -- Ensure animation modules are loaded
    load_animation_modules()
    
    if not AnimationEngine then
        debug_print("ERROR", "WidgetAnimations.slideWidget: AnimationEngine not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.slideWidget: %s to (%d,%d) in %f seconds", 
               widget.id, target_x, target_y, duration or 0.5)
    
    -- Animate widget position
    local anim_id = widget:animate_position(target_x, target_y, duration, options)
    
    debug_print("INFO", "  Started slide animation: %s", anim_id or "failed")
    return anim_id
end

-- Fade widget animation using internal AnimationEngine
function WidgetAnimations.fadeWidget(widget, target_opacity, duration, ...)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.fadeWidget: Invalid widget")
        return nil
    end
    
    -- Handle variable arguments for backward compatibility
    local args = {...}
    local options = {}
    
    -- If the last argument is a function, treat it as on_complete
    if #args > 0 and type(args[#args]) == "function" then
        options.on_complete = args[#args]
        table.remove(args, #args)
    end
    
    -- If there's still an argument and it's a string, treat it as easing
    if #args > 0 and type(args[#args]) == "string" then
        options.easing = args[#args]
        table.remove(args, #args)
    end
    
    -- If the remaining argument is a table, merge it with options
    if #args > 0 and type(args[#args]) == "table" then
        for k, v in pairs(args[#args]) do
            options[k] = v
        end
    end
    
    -- Ensure animation modules are loaded
    load_animation_modules()
    
    if not AnimationEngine then
        debug_print("ERROR", "WidgetAnimations.fadeWidget: AnimationEngine not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.fadeWidget: %s to opacity %d in %f seconds", 
               widget.id, target_opacity, duration or 0.5)
    
    -- Animate widget opacity
    local anim_id = widget:animate_opacity(target_opacity, duration, options)
    
    debug_print("INFO", "  Started fade animation: %s", anim_id or "failed")
    return anim_id
end

-- Hero animation (sprite to sprite) using AnimationSequences
function WidgetAnimations.heroAnimation(from_widget, from_child_id, to_widget, to_child_id, 
                                       duration, arc_height, on_complete)
    if not from_widget or not to_widget then
        debug_print("ERROR", "WidgetAnimations.heroAnimation: Invalid widgets")
        return nil
    end
    
    -- Ensure animation modules are loaded
    load_animation_modules()
    
    if not AnimationSequences then
        debug_print("ERROR", "WidgetAnimations.heroAnimation: AnimationSequences not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.heroAnimation: %s.%s -> %s.%s", 
               from_widget.id, from_child_id, to_widget.id, to_child_id)
    
    -- Find the sprites
    local from_sprite, to_sprite
    
    for sprite_id, sprite in pairs(from_widget.sprite_objects) do
        if sprite_id == from_child_id then
            from_sprite = sprite
            debug_print("DETAILED", "  Found from_sprite: %s", sprite_id)
            break
        end
    end
    
    for sprite_id, sprite in pairs(to_widget.sprite_objects) do
        if sprite_id == to_child_id then
            to_sprite = sprite
            debug_print("DETAILED", "  Found to_sprite: %s", sprite_id)
            break
        end
    end
    
    if not from_sprite or not to_sprite then
        debug_print("ERROR", "  Could not find sprites")
        return nil
    end
    
    -- Get positions
    local from_props = from_sprite:get_properties()
    local to_props = to_sprite:get_properties()
    
    local start_x, start_y = from_sprite:get_absolute_position()
    local end_x, end_y = to_sprite:get_absolute_position()
    
    -- Convert to widget-relative coordinates for animation
    local start_scale = from_props.sx or 1.0
    local end_scale = to_props.sx or 1.0
    
    debug_print("DETAILED", "  Start: (%d,%d) scale=%f, End: (%d,%d) scale=%f", 
               start_x, start_y, start_scale, end_x, end_y, end_scale)
    
    -- Use summon animation from AnimationSequences
    return AnimationSequences.summon(from_sprite, 
        start_x, start_y, start_scale,
        end_x, end_y, end_scale,
        {
            duration = duration or 0.25,
            arc_height = arc_height or 24,
            peak_scale_mul = 1.2,
            wobble_deg = 5,
            easing = "ease_in_out",
            on_complete = on_complete
        }
    )
end

-- Pulse animation for highlighting
function WidgetAnimations.pulseWidget(widget, scale_from, scale_to, duration, easing, loop, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.pulseWidget: Invalid widget")
        return nil
    end
    
    -- Ensure animation modules are loaded
    load_animation_modules()
    
    if not AnimationSequences then
        debug_print("ERROR", "WidgetAnimations.pulseWidget: AnimationSequences not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.pulseWidget: %s pulse scale %f->%f", 
               widget.id, scale_from or 1.0, scale_to or 1.1)
    
    local animations = {}
    
    -- Pulse each sprite in the widget
    for sprite_id, sprite in pairs(widget.sprite_objects) do
        local anim_id = AnimationSequences.pulse(sprite, {
            scale_from = scale_from or 1.0,
            scale_to = scale_to or 1.1,
            alpha_from = 255,
            alpha_to = 200,
            duration = duration or 0.8,
            easing = easing or "elastic_out",
            loop = loop or false,
            ping_pong = true,
            on_complete = on_complete
        })
        
        if anim_id then
            table.insert(animations, anim_id)
        end
    end
    
    return animations
end

-- Shake animation
function WidgetAnimations.shakeWidget(widget, intensity, duration, easing, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.shakeWidget: Invalid widget")
        return nil
    end
    
    -- Ensure animation modules are loaded
    load_animation_modules()
    
    if not AnimationSequences then
        debug_print("ERROR", "WidgetAnimations.shakeWidget: AnimationSequences not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.shakeWidget: %s shake intensity=%d", 
               widget.id, intensity or 3)
    
    local animations = {}
    
    -- Shake each sprite in the widget
    for sprite_id, sprite in pairs(widget.sprite_objects) do
        local anim_id = AnimationSequences.shake(sprite, {
            intensity = intensity or 3,
            duration = duration or 0.15,
            frequency = 15,
            easing = easing or "elastic_out",
            on_complete = on_complete
        })
        
        if anim_id then
            table.insert(animations, anim_id)
        end
    end
    
    return animations
end

-- Color pulse animation
function WidgetAnimations.colorPulseWidget(widget, target_color, duration, easing, loop, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.colorPulseWidget: Invalid widget")
        return nil
    end
    
    -- Ensure animation modules are loaded
    load_animation_modules()
    
    if not AnimationSequences then
        debug_print("ERROR", "WidgetAnimations.colorPulseWidget: AnimationSequences not available")
        return nil
    end
    
    debug_print("INFO", "WidgetAnimations.colorPulseWidget: %s color pulse to (%d,%d,%d)", 
               widget.id, target_color.r or 255, target_color.g or 255, target_color.b or 255)
    
    local animations = {}
    
    -- Color pulse each sprite in the widget
    for sprite_id, sprite in pairs(widget.sprite_objects) do
        local anim_id = AnimationSequences.color_pulse_from_current(sprite, target_color, {
            duration = duration or 0.8,
            easing = easing or "ease_in_out",
            loop = loop or false,
            ping_pong = true,
            on_complete = on_complete
        })
        
        if anim_id then
            table.insert(animations, anim_id)
        end
    end
    
    return animations
end

-- ===========================================================
-- TICK-BASED UPDATE SYSTEM
-- ===========================================================

-- Global update function for all widgets
local function update_all_widgets(dt)
    debug_print("VERBOSE", "WidgetSystem.tick: Updating all widgets with dt=%f", dt)
    
    local updated_count = 0
    local total_widgets = 0
    
    -- Update all widgets for all players
    for player_id, widgets in pairs(_widget_cache) do
        for widget_id, widget in pairs(widgets) do
            total_widgets = total_widgets + 1
            if widget:update(dt) then
                updated_count = updated_count + 1
            end
        end
    end
    
    if updated_count > 0 then
        debug_print("DETAILED", "WidgetSystem.tick: Updated %d/%d widgets", updated_count, total_widgets)
    end
    
    return updated_count
end

-- Set up tick event handler
Net:on("tick", function(event)
    local dt = event.delta_time
    
    -- Update AnimationEngine (if loaded)
    if AnimationEngine then
        AnimationEngine.tick(dt)
    else
        -- Try to load animation modules if not loaded yet
        load_animation_modules()
        if AnimationEngine then
            AnimationEngine.tick(dt)
        end
    end
    
    -- Update all widgets
    update_all_widgets(dt)
end)

-- ===========================================================
-- EVENT INTEGRATION
-- ===========================================================
local WidgetEvents = {
    selection_manager = nil
}

function WidgetEvents.initialize()
    debug_print("INFO", "WidgetEvents.initialize")
    
    WidgetEvents.selection_manager = SelectionManager.new()
    
    -- Hook into virtual_input events
    Net:on("virtual_input", function(event)
        if not WidgetEvents.selection_manager then
            debug_print("WARN", "WidgetEvents: selection_manager not initialized")
            return
        end
        
        debug_print("VERBOSE", "WidgetEvents: virtual_input from player %s", event.player_id)
        
        for _, button in ipairs(event.events) do
            debug_print("VERBOSE", "  Button: %s, state: %d", button.name, button.state)
            
            if button.state == 1 then -- Button pressed
                if button.name == "Move Up" then
                    debug_print("INFO", "WidgetEvents: Move Up pressed")
                    WidgetEvents.selection_manager:moveSelection("up")
                elseif button.name == "Move Down" then
                    debug_print("INFO", "WidgetEvents: Move Down pressed")
                    WidgetEvents.selection_manager:moveSelection("down")
                elseif button.name == "Move Left" then
                    debug_print("INFO", "WidgetEvents: Move Left pressed")
                    WidgetEvents.selection_manager:moveSelection("left")
                elseif button.name == "Move Right" then
                    debug_print("INFO", "WidgetEvents: Move Right pressed")
                    WidgetEvents.selection_manager:moveSelection("right")
                elseif button.name == "Interact" or button.name == "Confirm" then
                    debug_print("INFO", "WidgetEvents: Confirm pressed")
                    local selected_item = WidgetEvents.selection_manager:getSelectedItem()
                    if selected_item then
                        debug_print("INFO", "WidgetEvents: Emitting widget_item_selected for %s", selected_item.id)
                        Net:emit("widget_item_selected", {
                            player_id = event.player_id,
                            item = selected_item
                        })
                    else
                        debug_print("WARN", "WidgetEvents: No item selected")
                    end
                end
            end
        end
    end)
    
    -- Widget item selected event
    Net:on("widget_item_selected", function(event)
        debug_print("INFO", "WidgetEvents: widget_item_selected: %s", 
                   event.item and event.item.id or "unknown")
        print("[widgets] Item selected: " .. (event.item.id or "unknown"))
    end)
    
    debug_print("INFO", "WidgetEvents initialized successfully")
end

-- ===========================================================
-- DEBUG UTILITIES
-- ===========================================================
local WidgetDebug = {}

function WidgetDebug.printWidgetTree(widget, level)
    level = level or 0
    local indent = string.rep("  ", level)
    
    print(indent .. "┌─ " .. widget.id .. " (" .. (widget.widget_type or "Widget") .. ")")
    print(indent .. "│  Position: (" .. widget.x .. ", " .. widget.y .. ")")
    print(indent .. "│  Size: " .. widget.width .. "x" .. widget.height)
    print(indent .. "│  Children: " .. #widget.children)
    print(indent .. "│  Sprites: " .. table_count(widget.sprite_objects))
    print(indent .. "│  Animating: " .. tostring(widget:is_animating()))
    print(indent .. "│  Dirty: " .. tostring(widget.state.dirty))
    print(indent .. "│  Visible: " .. tostring(widget.state.visible))
    
    if #widget.children > 0 then
        print(indent .. "│  Child details:")
        for i, child in ipairs(widget.children) do
            if child.type == "sprite" then
                print(indent .. "│    " .. i .. ": Sprite [" .. (child.sprite_id or "unknown") .. "]")
                print(indent .. "│        texture: " .. (child.texture_path or "none"))
                print(indent .. "│        anim: " .. (child.anim_path or "none"))
                print(indent .. "│        state: " .. (child.anim_state or "none"))
                local sprite = widget:get_sprite(child.sprite_id)
                if sprite then
                    print(indent .. "│        template: " .. sprite.template_id)
                end
            elseif child.widget then
                print(indent .. "│    " .. i .. ": Widget [" .. child.widget.id .. "]")
                WidgetDebug.printWidgetTree(child.widget, level + 2)
            else
                print(indent .. "│    " .. i .. ": Unknown child type")
            end
        end
    end
    
    -- Print sprite groups
    if table_count(widget.sprite_groups) > 0 then
        print(indent .. "│  Sprite Groups:")
        for group_name, sprite_ids in pairs(widget.sprite_groups) do
            print(indent .. "│    - " .. group_name .. ": " .. #sprite_ids .. " sprites")
        end
    end
    
    -- Print child widgets
    local widget_count = table_count(widget._child_widgets)
    if widget_count > 0 then
        print(indent .. "│  Child Widgets: " .. widget_count)
        for _, child_widget in pairs(widget._child_widgets) do
            WidgetDebug.printWidgetTree(child_widget, level + 2)
        end
    end
    
    print(indent .. "└─")
end

function WidgetDebug.enableDebug(level)
    if level then
        LOGGING.set_debug_level(level)
    else
        LOGGING.enable_debug()
    end
    print("[Widgets] Debug enabled at level: " .. LOGGING.get_debug_level())
end

function WidgetDebug.disableDebug()
    LOGGING.disable_debug()
    print("[Widgets] Debug disabled")
end

function WidgetDebug.getStats()
    local stats = {
        dimension_cache_entries = SpriteDimensionCache.stats(),
        widget_cache_entries = WidgetCache.stats(),
        widget_types = {
            row = "Row",
            column = "Column",
            grid = "Grid",
            container = "Container",
            expanded = "Expanded"
        },
        animation_engine_loaded = AnimationEngine ~= nil,
        animation_sequences_loaded = AnimationSequences ~= nil,
        debug_mode = LOGGING.is_debug_enabled() and ("ENABLED (" .. LOGGING.get_debug_level() .. ")") or "DISABLED"
    }
    
    print("[Widgets Debug Stats]")
    print("  Dimension cache entries:", stats.dimension_cache_entries)
    print("  Widget cache entries:", stats.widget_cache_entries)
    print("  AnimationEngine loaded:", stats.animation_engine_loaded)
    print("  AnimationSequences loaded:", stats.animation_sequences_loaded)
    print("  Debug mode:", stats.debug_mode)
    
    return stats
end

-- ===========================================================
-- MODULE EXPORT
-- ===========================================================
return {
    -- Base classes
    Widget = Widget,
    Row = Row,
    Column = Column,
    Grid = Grid,
    Container = Container,
    Expanded = Expanded,
    
    -- Managers
    SelectionManager = SelectionManager,
    
    -- Builders
    Builder = WidgetBuilder,
    
    -- Animations
    Animations = WidgetAnimations,
    
    -- Events
    Events = WidgetEvents,
    
    -- Dimension cache
    SpriteDimensionCache = SpriteDimensionCache,
    
    -- Widget cache
    WidgetCache = WidgetCache,
    
    -- Sprite Object class
    SpriteObject = SpriteObject,
    
    -- Debug utilities
    Debug = WidgetDebug,
    
    -- Log management
    Log = {
        set_level = LOGGING.set_debug_level,
        get_level = LOGGING.get_debug_level,
        enable = LOGGING.enable_debug,
        disable = LOGGING.disable_debug,
        is_enabled = LOGGING.is_debug_enabled
    },
    
    -- Utility functions
    createRow = function(id, player_id) return Row.new(id, player_id) end,
    createColumn = function(id, player_id) return Column.new(id, player_id) end,
    createGrid = function(id, player_id) return Grid.new(id, player_id) end,
    createContainer = function(id, player_id) return Container.new(id, player_id) end,
    createExpanded = function(id, player_id) return Expanded.new(id, player_id) end,
    
    -- Cache functions
    getWidget = function(widget_id, player_id)
        return WidgetCache.get(widget_id, player_id)
    end,
    
    getPlayerWidgets = function(player_id)
        return WidgetCache.get_all(player_id)
    end,
    
    clearPlayerWidgets = function(player_id)
        return WidgetCache.clear_player(player_id)
    end,
    
    printCacheStats = function()
        return WidgetCache.stats()
    end,
    
    -- Animation control
    loadAnimationModules = load_animation_modules,
    stopAllAnimations = function(widget)
        if widget then
            widget:stop_all_animations()
        else
            -- Stop animations on all widgets
            for player_id, widgets in pairs(_widget_cache) do
                for _, widget in pairs(widgets) do
                    widget:stop_all_animations()
                end
            end
        end
    end,
    
    -- Quick creation
    quickMenu = WidgetBuilder.createMenu,
    quickInventory = WidgetBuilder.createInventoryGrid,
    quickHUD = WidgetBuilder.createHUD,
    
    -- Debug control
    enableDebug = WidgetDebug.enableDebug,
    disableDebug = WidgetDebug.disableDebug,
    printWidgetTree = WidgetDebug.printWidgetTree,
    getStats = WidgetDebug.getStats,
    
    -- Tick-based update system
    updateAllWidgets = update_all_widgets,
    
    -- Initialize
    init = function()
        LOGGING.info("Widget system initialized")
        return true
    end,
    
    -- Helper functions
    generateUniqueId = generate_unique_id
}