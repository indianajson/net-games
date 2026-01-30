-- widgets.lua
-- Flutter-inspired widget system for net-games framework
-- Version 2.1 with Complete Animation System
-- Updated: Fixed widget animation, sprite positioning, and layout respect for animations

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
-- SPRITE OBJECT MANAGEMENT (UPDATED WITH CUSTOM DIMENSIONS)
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
    
    -- Custom dimensions for layout (override intrinsic dimensions)
    self.layout_width = nil
    self.layout_height = nil
    
    -- Track if this sprite is currently being animated by its parent widget
    self.widget_animated = false
    self.widget_animation_properties = {}
    
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

-- Mark sprite as being animated by parent widget
function SpriteObject:set_widget_animated(is_animated, properties)
    self.widget_animated = is_animated
    if is_animated and properties then
        self.widget_animation_properties = table.deepcopy(properties)
    elseif not is_animated then
        self.widget_animation_properties = {}
    end
end

-- Check if sprite is being animated by parent widget
function SpriteObject:is_widget_animated()
    return self.widget_animated
end

-- Set custom dimensions for layout (pre-scaling)
function SpriteObject:set_layout_dimensions(width, height)
    self.layout_width = width
    self.layout_height = height
    debug_print("DETAILED", "SpriteObject.set_layout_dimensions: %s = %dx%d", 
               self.id, width or 0, height or 0)
    return self
end

-- Get dimensions for layout (either custom or from animation file)
function SpriteObject:get_layout_dimensions()
    if self.layout_width and self.layout_height then
        -- Use custom dimensions if set
        debug_print("VERBOSE", "SpriteObject.get_layout_dimensions: %s using custom %dx%d", 
                   self.id, self.layout_width, self.layout_height)
        return self.layout_width, self.layout_height
    end
    
    -- Otherwise, get dimensions from animation file (without scaling)
    local width, height = SpriteDimensionCache.get_dimensions(
        self.texture_path, self.anim_path, self.anim_state)
    
    debug_print("VERBOSE", "SpriteObject.get_layout_dimensions: %s using intrinsic %dx%d", 
               self.id, width, height)
    return width, height
end

-- Get visual dimensions (including scale)
function SpriteObject:get_visual_dimensions()
    local width, height = self:get_layout_dimensions()
    
    -- Apply current scale
    local visual_width = width * (self.properties.sx or 1.0)
    local visual_height = height * (self.properties.sy or 1.0)
    
    debug_print("VERBOSE", "SpriteObject.get_visual_dimensions: %s = %dx%d * scale(%f,%f) = %dx%d", 
               self.id, width, height, 
               self.properties.sx or 1.0, self.properties.sy or 1.0,
               visual_width, visual_height)
    
    return visual_width, visual_height
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
    
    -- Calculate absolute screen position
    -- The sprite's x/y properties are relative to its widget
    -- We need to find the widget and get its absolute position
    local absolute_x = self.properties.x * 2  -- Convert widget-relative to screen
    local absolute_y = self.properties.y * 2
    
    -- Try to find the widget and add its position
    local widget = WidgetCache.get(self.widget_id, self.player_id)
    if widget then
        -- Widget's x/y are already in screen coordinates
        absolute_x = absolute_x + widget.x
        absolute_y = absolute_y + widget.y
        
        -- Also add any parent widget positions
        local parent = widget.parent
        while parent do
            absolute_x = absolute_x + parent.x
            absolute_y = absolute_y + parent.y
            parent = parent.parent
        end
    end
    
    local sprite_data = {
        id = self.id,  -- Use sprite object ID as the instance ID
        x = absolute_x,  -- Use absolute screen coordinates
        y = absolute_y,
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
    
    debug_print("VERBOSE", "SpriteObject.draw: %s at widget-relative (%d,%d) absolute (%d,%d) scale=%f,%f",
               self.id, self.properties.x, self.properties.y, absolute_x, absolute_y,
               self.properties.sx, self.properties.sy)
    
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
    -- Calculate absolute screen position
    local absolute_x = self.properties.x * 2
    local absolute_y = self.properties.y * 2
    
    -- Try to find the widget and add its position
    local widget = WidgetCache.get(self.widget_id, self.player_id)
    if widget then
        absolute_x = absolute_x + widget.x
        absolute_y = absolute_y + widget.y
        
        -- Also add any parent widget positions
        local parent = widget.parent
        while parent do
            absolute_x = absolute_x + parent.x
            absolute_y = absolute_y + parent.y
            parent = parent.parent
        end
    end
    
    return absolute_x, absolute_y
end

-- ===========================================================
-- SPRITE OBJECT ANIMATION FUNCTIONS (MIRRORING FRAMEWORK.LUA)
-- ===========================================================

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

-- Sprite-specific animation methods
function SpriteObject:slide_sprite(target_x, target_y, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "linear"
    
    return self:animate({x = target_x, y = target_y}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:scale_sprite(target_scale, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    return self:animate({sx = target_scale, sy = target_scale}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:rotate_sprite(target_rotation, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    return self:animate({ro = target_rotation}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:set_opacity_sprite(target_opacity, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    return self:animate({opacity = target_opacity, a = target_opacity}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:set_color_sprite(r, g, b, duration, easing, on_complete)
    if not self then return nil end
    
    duration = duration or 0.25
    easing = easing or "ease_in_out"
    
    return self:animate({r = r, g = g, b = b}, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

function SpriteObject:stop_sprite_animation(anim_id)
    return self:stop_animation(anim_id)
end

function SpriteObject:has_sprite_animations()
    return self:is_animating()
end

-- ===========================================================
-- DIMENSION CACHE
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
        
        -- Look for any frame
        for _, element in ipairs(elements) do
            if element.text == "frame" then
                -- Try different attribute names for width and height
                width = get_element_attribute_int(element, "w", 0)
                height = get_element_attribute_int(element, "h", 0)
                
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
-- BASE WIDGET CLASS (FIXED WITH COMPLETE ANIMATION SUPPORT)
-- ===========================================================
local Widget = {}
Widget.__index = Widget

function Widget.new(id, player_id)
    local self = setmetatable({}, Widget)
    
    self.id = id or generate_unique_id("widget")
    self.player_id = player_id
    self.x = 0
    self.y = 0
    self.sx = 1.0  -- Scale X
    self.sy = 1.0  -- Scale Y
    self.ro = 0    -- Rotation
    self.opacity = 255
    self.r = 255
    self.g = 255
    self.b = 255
    self.a = 255
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
    
    -- Track if widget is currently being animated (so layout doesn't override)
    self._layout_animation_active = false
    self._layout_animation_type = nil  -- "position", "scale", "rotation", "transform"
    
    -- Register in cache
    WidgetCache.register(self)
    
    debug_print("INFO", "Widget created: id=%s, player=%s, type=%s", self.id, self.player_id, self.widget_type)
    
    return self
end

-- ===========================================================
-- WIDGET ANIMATION FUNCTIONS (UPDATED TO ANIMATE SPRITES)
-- ===========================================================

-- Purpose: Smoothly slide/move a widget from current position to target position
function Widget:slide_widget(target_x, target_y, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.slide_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "linear"
    
    debug_print("INFO", "Widget.slide_widget: %s to (%d,%d) in %f seconds", 
               self.id, target_x, target_y, duration)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    
    -- Get starting position
    local start_x = self.x
    local start_y = self.y
    
    -- Calculate delta for all sprites
    local delta_x = target_x - start_x
    local delta_y = target_y - start_y
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "position", delta_x = delta_x, delta_y = delta_y})
        
        local sprite_props = sprite:get_properties()
        local sprite_target_x = sprite_props.x + delta_x
        local sprite_target_y = sprite_props.y + delta_y
        
        local anim_id = sprite:slide_sprite(sprite_target_x, sprite_target_y, duration, easing)
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:slide_widget(
            child_widget.x + delta_x,
            child_widget.y + delta_y,
            duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    -- Animate the widget's position for layout purposes
    return self:animate_position(target_x, target_y, duration, {
        easing = easing,
        on_update = function(values)
            -- Update widget position
            self:setPosition(values.x, values.y)
            
            -- Update sprites' absolute positions through their widget-relative positions
            -- (already handled by sprite animations)
        end,
        on_complete = function(values, interrupted)
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
            end
            
            -- Clear child widget animation flags
            for _, child_data in ipairs(child_animations) do
                if child_data.widget then
                    child_data.widget._layout_animation_active = false
                    child_data.widget._layout_animation_type = nil
                end
            end
            
            self.active_animations[anim_id] = nil
            if on_complete then
                on_complete(values, interrupted)
            end
        end
    })
end

-- Purpose: Smoothly slide/move a widget from specified start to target position
function Widget:set_slide_widget(start_x, start_y, target_x, target_y, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_slide_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.set_slide_widget: %s from (%d,%d) to (%d,%d) in %f seconds", 
               self.id, start_x, start_y, target_x, target_y, duration)
    
    -- Set starting position immediately
    self:setPosition(start_x, start_y)
    
    return self:slide_widget(target_x, target_y, duration, easing, on_complete)
end

-- Purpose: Smoothly move a widget relative to its current position
function Widget:move_widget(offset_x, offset_y, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.move_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Calculate target position
    local target_x = self.x + offset_x
    local target_y = self.y + offset_y
    
    debug_print("INFO", "Widget.move_widget: %s by (%d,%d) to (%d,%d)", 
               self.id, offset_x, offset_y, target_x, target_y)
    
    return self:slide_widget(target_x, target_y, duration, easing, on_complete)
end

-- Purpose: Smoothly scale a widget (consistent with slide pattern)
function Widget:scale_widget(target_scale, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.scale_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current scale
    local current_scale = self.sx or 1.0
    
    debug_print("INFO", "Widget.scale_widget: %s from scale %f to %f", 
               self.id, current_scale, target_scale)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "scale"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "scale", target_scale = target_scale})
        
        local anim_id = sprite:scale_sprite(target_scale, duration, easing)
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:scale_widget(target_scale, duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    return self:animate_properties(
        {sx = target_scale, sy = target_scale},
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget scale
                self:setScale(values.sx, values.sy)
                
                -- Sprites are already being animated separately
            end,
            on_complete = function(values, interrupted)
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Clear sprite animation flags
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                -- Clear child widget animation flags
                for _, child_data in ipairs(child_animations) do
                    if child_data.widget then
                        child_data.widget._layout_animation_active = false
                        child_data.widget._layout_animation_type = nil
                    end
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
            end
        }
    )
end

-- Purpose: Smoothly rotate a widget (consistent with slide pattern)
function Widget:rotate_widget(target_rotation, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.rotate_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    -- Get current rotation
    local current_rotation = self.ro or 0
    
    debug_print("INFO", "Widget.rotate_widget: %s from rotation %f to %f", 
               self.id, current_rotation, target_rotation)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "rotation"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "rotation", target_rotation = target_rotation})
        
        local anim_id = sprite:rotate_sprite(target_rotation, duration, easing)
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:rotate_widget(target_rotation, duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    return self:animate_properties(
        {ro = target_rotation},
        duration,
        {
            easing = easing,
            on_update = function(values)
                -- Update widget rotation
                self:setRotation(values.ro)
                
                -- Sprites are already being animated separately
            end,
            on_complete = function(values, interrupted)
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                -- Clear sprite animation flags
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:set_widget_animated(false)
                end
                
                -- Clear child widget animation flags
                for _, child_data in ipairs(child_animations) do
                    if child_data.widget then
                        child_data.widget._layout_animation_active = false
                        child_data.widget._layout_animation_type = nil
                    end
                end
                
                if on_complete then
                    on_complete(values, interrupted)
                end
            end
        }
    )
end

-- Purpose: Complex animation that combines slide, scale, and rotation
function Widget:transform_widget(properties, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.transform_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.transform_widget: %s with %d properties", 
               self.id, #properties)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Calculate deltas for sprites
    local delta_x = (properties.x or self.x) - self.x
    local delta_y = (properties.y or self.y) - self.y
    local target_scale = properties.sx or self.sx
    local target_rotation = properties.ro or self.ro
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {
            type = "transform", 
            delta_x = delta_x,
            delta_y = delta_y,
            target_scale = target_scale,
            target_rotation = target_rotation
        })
        
        local sprite_props = sprite:get_properties()
        local sprite_target_x = sprite_props.x + delta_x
        local sprite_target_y = sprite_props.y + delta_y
        
        -- Animate sprite with all properties
        local anim_id = sprite:animate({
            x = sprite_target_x,
            y = sprite_target_y,
            sx = target_scale,
            sy = target_scale,
            ro = target_rotation
        }, duration, {easing = easing})
        
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local child_props = {}
        if properties.x then child_props.x = child_widget.x + delta_x end
        if properties.y then child_props.y = child_widget.y + delta_y end
        if properties.sx then child_props.sx = target_scale end
        if properties.sy then child_props.sy = target_scale end
        if properties.ro then child_props.ro = target_rotation end
        
        local anim_id = child_widget:transform_widget(child_props, duration, easing)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    return self:animate_properties(properties, duration, {
        easing = easing,
        on_update = function(values)
            -- Update widget properties
            if values.x or values.y then
                self:setPosition(values.x or self.x, values.y or self.y)
            end
            if values.sx or values.sy then
                self:setScale(values.sx or self.sx, values.sy or self.sy)
            end
            if values.ro then
                self:setRotation(values.ro)
            end
            
            -- Sprites are already being animated separately
        end,
        on_complete = function(values, interrupted)
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
            end
            
            -- Clear child widget animation flags
            for _, child_data in ipairs(child_animations) do
                if child_data.widget then
                    child_data.widget._layout_animation_active = false
                    child_data.widget._layout_animation_type = nil
                end
            end
            
            if on_complete then
                on_complete(values, interrupted)
            end
        end
    })
end

-- Purpose: Apply Bob animation to a widget
function Widget:bob_widget(distance, duration, easing, loop, ping_pong)
    if not self then
        debug_print("ERROR", "Widget.bob_widget: Invalid widget")
        return nil
    end
    
    local start_y = self.y or 0
    distance = distance or 3
    duration = duration or 1.0
    easing = easing or "smoothstep"
    loop = loop or true
    ping_pong = ping_pong or true
    
    debug_print("INFO", "Widget.bob_widget: %s bob distance %d, duration %f", 
               self.id, distance, duration)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "bob", distance = distance})
        
        local sprite_props = sprite:get_properties()
        local anim_id = sprite:animate(
            {y = sprite_props.y - distance},
            duration,
            {
                easing = easing,
                loop = loop,
                ping_pong = ping_pong
            }
        )
        
        if anim_id then
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:bob_widget(distance, duration, easing, loop, ping_pong)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    return self:animate_properties(
        {y = start_y - distance},
        duration,
        {
            easing = easing,
            loop = loop,
            ping_pong = ping_pong,
            on_update = function(values)
                -- Update widget position
                self:setPosition(self.x, values.y)
                
                -- Sprites are already being animated separately
            end,
            on_complete = function(values, interrupted)
                if not loop then
                    -- Clear animation flags
                    self._layout_animation_active = false
                    self._layout_animation_type = nil
                    
                    -- Clear sprite animation flags
                    for sprite_id, sprite in pairs(self.sprite_objects) do
                        sprite:set_widget_animated(false)
                    end
                    
                    -- Clear child widget animation flags
                    for _, child_data in ipairs(child_animations) do
                        if child_data.widget then
                            child_data.widget._layout_animation_active = false
                            child_data.widget._layout_animation_type = nil
                        end
                    end
                end
            end
        }
    )
end

-- Purpose: Pulse the scale of a widget
function Widget:pulse_scale_widget(min_scale, max_scale, pulse_duration, easing, loops, on_complete)
    if not self then
        debug_print("ERROR", "Widget.pulse_scale_widget: Invalid widget")
        return nil
    end
    
    local current_scale = self.sx or 1.0
    min_scale = min_scale or current_scale * 0.9
    max_scale = max_scale or current_scale * 1.1
    pulse_duration = pulse_duration or 0.5
    
    debug_print("INFO", "Widget.pulse_scale_widget: %s pulse scale %f->%f", 
               self.id, min_scale, max_scale)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "scale"
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "pulse", min_scale = min_scale, max_scale = max_scale})
        
        -- Create pulse animation for each sprite
        local start_properties = {scale = min_scale}
        local target_properties = {scale = max_scale}
        
        if not AnimationEngine then
            load_animation_modules()
            if not AnimationEngine then
                debug_print("WARN", "Widget.pulse_scale_widget: AnimationEngine not available")
                return nil
            end
        end
        
        local anim_id = AnimationEngine.animate(start_properties, target_properties, pulse_duration / 2, {
            easing = easing or "ease_in_out",
            on_update = function(values)
                sprite:set_scale(values.scale)
            end,
            loop = loops or 1,
            ping_pong = true
        })
        
        if anim_id then
            sprite.active_animations[anim_id] = true
            table.insert(sprite_animations, {id = anim_id, sprite = sprite})
        end
    end
    
    -- Also animate child widgets
    local child_animations = {}
    for _, child_widget in pairs(self._child_widgets) do
        local anim_id = child_widget:pulse_scale_widget(min_scale, max_scale, pulse_duration, easing, loops)
        if anim_id then
            table.insert(child_animations, {id = anim_id, widget = child_widget})
        end
    end
    
    -- We'll use a custom animation for this because it's a ping-pong between two scales
    local start_properties = {scale = min_scale}
    local target_properties = {scale = max_scale}
    
    if not AnimationEngine then
        load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "Widget.pulse_scale_widget: AnimationEngine not available")
            return nil
        end
    end
    
    local anim_id = AnimationEngine.animate(start_properties, target_properties, pulse_duration / 2, {
        easing = easing or "ease_in_out",
        on_update = function(values)
            self:setScale(values.scale)
        end,
        on_complete = on_complete,
        loop = loops or 1,
        ping_pong = true
    })
    
    if anim_id then
        self.active_animations[anim_id] = true
        
        -- Store cleanup function
        self.active_animations[anim_id .. "_cleanup"] = function()
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
            end
            
            -- Clear child widget animation flags
            for _, child_data in ipairs(child_animations) do
                if child_data.widget then
                    child_data.widget._layout_animation_active = false
                    child_data.widget._layout_animation_type = nil
                end
            end
        end
    end
    
    return anim_id
end

-- Purpose: Apply color pulse from current color
function Widget:color_pulse_from_current(target_color)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_from_current: Invalid widget")
        return nil
    end
    
    local current_color = {
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        a = self.a or 255
    }
    
    return self:color_pulse_widget(current_color, target_color)
end

-- Purpose: Apply summon animation to widget (flies with arc)
function Widget:summon_widget(start_x, start_y, start_scale, 
                            end_x, end_y, end_scale, duration, arc_height, peak_scale_mul, wobble_deg, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.summon_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.25
    arc_height = arc_height or 24
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 5
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.summon_widget: %s summon from (%d,%d) to (%d,%d)", 
               self.id, start_x, start_y, end_x, end_y)
    
    -- Set starting position and scale
    self:setPosition(start_x, start_y)
    self:setScale(start_scale)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Calculate deltas for sprites
    local delta_x = end_x - start_x
    local delta_y = end_y - start_y
    local scale_delta = end_scale - start_scale
    
    -- Animate ALL sprite objects within this widget
    local sprite_animations = {}
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {
            type = "summon",
            delta_x = delta_x,
            delta_y = delta_y,
            start_scale = start_scale,
            end_scale = end_scale,
            arc_height = arc_height
        })
        
        local sprite_props = sprite:get_properties()
        local sprite_end_x = sprite_props.x + delta_x
        local sprite_end_y = sprite_props.y + delta_y
        
        -- We'll handle sprite summoning separately below
    end
    
    if not AnimationEngine then
        load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "Widget.summon_widget: AnimationEngine not available")
            return nil
        end
    end
    
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    local anim_id = nil
    
    anim_id = AnimationEngine.animate(
        {progress = 0},
        {progress = 1},
        duration,
        {
            easing = easing,
            on_update = function(values)
                local t = values.progress
                local u = 1 - t
                local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
                local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
                
                local base_scale = start_scale + (end_scale - start_scale) * t
                local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
                local current_scale = base_scale * pulse
                
                local rotation = 0
                if wobble_deg ~= 0 then
                    rotation = math.sin(math.pi * 2 * t) * wobble_deg * (1 - t)
                end
                
                self:setPosition(x, y)
                self:setScale(current_scale)
                self:setRotation(rotation)
                
                -- Update all sprites with same transform
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local sprite_props = sprite:get_properties()
                    local sprite_x = sprite_props.x + (x - start_x)
                    local sprite_y = sprite_props.y + (y - start_y)
                    
                    sprite:update({
                        x = sprite_x,
                        y = sprite_y,
                        sx = current_scale,
                        sy = current_scale,
                        ro = rotation
                    })
                end
            end,
            on_complete = function(values, interrupted)
                if not interrupted then
                    self:setPosition(end_x, end_y)
                    self:setScale(end_scale)
                    self:setRotation(0)
                    
                    -- Update all sprites to final position
                    for sprite_id, sprite in pairs(self.sprite_objects) do
                        local sprite_props = sprite:get_properties()
                        local sprite_end_x = sprite_props.x + delta_x
                        local sprite_end_y = sprite_props.y + delta_y
                        
                        sprite:update({
                            x = sprite_end_x,
                            y = sprite_end_y,
                            sx = end_scale,
                            sy = end_scale,
                            ro = 0
                        })
                        
                        sprite:set_widget_animated(false)
                    end
                end
                
                -- Clear animation flags
                self._layout_animation_active = false
                self._layout_animation_type = nil
                
                if on_complete then
                    on_complete(values, interrupted)
                end
                
                if self.active_animations and anim_id then
                    self.active_animations[anim_id] = nil
                end
            end
        }
    )
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Apply complex summon animation
function Widget:complex_summon_widget(start_x, start_y, start_scale,
                                    end_x, end_y, end_scale, arc_duration, wobble_duration, settle_duration, 
                                    arc_height, peak_scale_mul, wobble_deg, easing, on_complete, 
                                    on_update_step1, on_update_step2, on_update_step3)
    if not self then
        debug_print("ERROR", "Widget.complex_summon_widget: Invalid widget")
        return nil
    end
    
    arc_duration = arc_duration or 0.25
    wobble_duration = wobble_duration or 0.1
    settle_duration = settle_duration or 0.05
    arc_height = arc_height or 40
    peak_scale_mul = peak_scale_mul or 1.35
    wobble_deg = wobble_deg or 10
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.complex_summon_widget: %s complex summon", self.id)
    
    -- Set starting position and scale
    self:setPosition(start_x, start_y)
    self:setScale(start_scale)
    self:setRotation(0)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Calculate deltas for sprites
    local delta_x = end_x - start_x
    local delta_y = end_y - start_y
    local scale_delta = end_scale - start_scale
    
    if not AnimationEngine then
        load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "Widget.complex_summon_widget: AnimationEngine not available")
            return nil
        end
    end
    
    local control_x = (start_x + end_x) * 0.5
    local control_y = (start_y + end_y) * 0.5 - arc_height
    local sequence_steps = {}
    
    -- Step 1: Arc movement with scale pulse
    table.insert(sequence_steps, {
        type = "animate",
        duration = arc_duration,
        easing = easing,
        on_update = function(values, t, phase)
            local u = 1 - t
            local x = u*u*start_x + 2*u*t*control_x + t*t*end_x
            local y = u*u*start_y + 2*u*t*control_y + t*t*end_y
            
            local base_scale = start_scale + (end_scale - start_scale) * t
            local pulse = 1.0 + ((peak_scale_mul - 1.0) * math.sin(math.pi * t))
            local current_scale = base_scale * pulse
            
            self:setPosition(x, y)
            self:setScale(current_scale)
            self:setRotation(0)
            
            -- Update all sprites with same transform
            for sprite_id, sprite in pairs(self.sprite_objects) do
                local sprite_props = sprite:get_properties()
                local sprite_x = sprite_props.x + (x - start_x)
                local sprite_y = sprite_props.y + (y - start_y)
                
                sprite:update({
                    x = sprite_x,
                    y = sprite_y,
                    sx = current_scale,
                    sy = current_scale,
                    ro = 0
                })
            end
            
            if on_update_step1 then
                on_update_step1({x = x, y = y, scale = current_scale, progress = t})
            end
        end
    })
    
    -- Step 2: Rotation wobble
    if wobble_deg and wobble_deg > 0 then
        table.insert(sequence_steps, {
            type = "animate",
            duration = wobble_duration,
            easing = "elastic_out",
            on_update = function(values, t, phase)
                local wobble = math.sin(t * math.pi * 4) * wobble_deg * (1 - t)
                self:setRotation(wobble)
                
                -- Update all sprites with same rotation
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    sprite:update({ro = wobble})
                end
                
                if on_update_step2 then
                    on_update_step2({rotation = wobble, progress = t})
                end
            end
        })
    end
    
    -- Step 3: Final settle
    table.insert(sequence_steps, {
        type = "animate",
        duration = settle_duration,
        easing = "bounce_out",
        on_update = function(values, t, phase)
            local settle_scale = end_scale * (1 - 0.05 * (1 - t))
            self:setScale(settle_scale)
            self:setRotation(0)
            
            -- Update all sprites with same scale
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:update({
                    sx = settle_scale,
                    sy = settle_scale,
                    ro = 0
                })
            end
            
            if on_update_step3 then
                on_update_step3({scale = settle_scale, progress = t})
            end
        end,
        on_complete = function(values, interrupted)
            if not interrupted then
                self:setPosition(end_x, end_y)
                self:setScale(end_scale)
                self:setRotation(0)
                
                -- Update all sprites to final position
                for sprite_id, sprite in pairs(self.sprite_objects) do
                    local sprite_props = sprite:get_properties()
                    local sprite_end_x = sprite_props.x + delta_x
                    local sprite_end_y = sprite_props.y + delta_y
                    
                    sprite:update({
                        x = sprite_end_x,
                        y = sprite_end_y,
                        sx = end_scale,
                        sy = end_scale,
                        ro = 0
                    })
                    
                    sprite:set_widget_animated(false)
                end
            end
            
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            if on_complete then
                on_complete(values, interrupted)
            end
        end
    })
    
    local seq_id = AnimationEngine.create_sequence(sequence_steps, {
        id = "complex_summon_" .. self.id .. "_" .. math.random(1000, 9999)
    })
    
    if seq_id then
        self.active_sequences[seq_id] = true
        AnimationEngine.start_sequence(seq_id)
    end
    
    return seq_id
end

-- Purpose: Apply fade animation to widget
function Widget:set_opacity_widget(target_opacity, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_opacity_widget: Invalid widget")
        return nil
    end
    
    duration = duration or 0.3
    easing = easing or "ease_in_out"
    
    debug_print("INFO", "Widget.set_opacity_widget: %s to opacity %d", 
               self.id, target_opacity)
    
    return self:animate_opacity(target_opacity, duration, {
        easing = easing,
        on_complete = on_complete
    })
end

-- Purpose: Apply tint animation to widget
function Widget:set_widget_color(r, g, b, duration, easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.set_widget_color: Invalid widget")
        return nil
    end
    
    duration = duration or 0.25
    easing = easing or "ease_in_out"
    
    r = math.max(0, math.min(255, r or 255))
    g = math.max(0, math.min(255, g or 255))
    b = math.max(0, math.min(255, b or 255))
    
    debug_print("INFO", "Widget.set_widget_color: %s to color (%d,%d,%d)", 
               self.id, r, g, b)
    
    -- Animate ALL sprite objects within this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_color_sprite(r, g, b, duration, easing)
    end
    
    -- Also animate child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:set_widget_color(r, g, b, duration, easing)
    end
    
    return self:animate_properties(
        {r = r, g = g, b = b},
        duration,
        {
            easing = easing,
            on_complete = on_complete
        }
    )
end

-- Purpose: Apply color pulse animation to widget
function Widget:color_pulse_widget(start_color, target_color)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_widget: Invalid widget")
        return nil
    end
    
    if not AnimationSequences then
        load_animation_modules()
        if not AnimationSequences then
            debug_print("WARN", "Widget.color_pulse_widget: AnimationSequences not available")
            return nil
        end
    end
    
    debug_print("INFO", "Widget.color_pulse_widget: %s color pulse", self.id)
    
    -- Create a proxy object for the animation
    local proxy = {
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255,
        a = self.a or 255,
        setColor = function(_, r, g, b, a)
            self:setColor(r, g, b, a)
            
            -- Update all sprites with same color
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_color(r, g, b, a)
            end
        end,
        setAlpha = function(_, alpha)
            self:setOpacity(alpha)
            
            -- Update all sprites with same opacity
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_opacity(alpha)
            end
        end
    }
    
    local anim_id = AnimationSequences.color_pulse(proxy, start_color, target_color)
    
    if anim_id then
        self.active_animations[anim_id] = true
    end
    
    return anim_id
end

-- Purpose: Simple color pulse with RGB values
function Widget:color_pulse_rgb(start_r, start_g, start_b, start_a, 
                               target_r, target_g, target_b, target_a)
    if not self then
        debug_print("ERROR", "Widget.color_pulse_rgb: Invalid widget")
        return nil
    end
    
    local start_color = {
        r = start_r or 255,
        g = start_g or 255,
        b = start_b or 255,
        a = start_a or 255
    }
    
    local target_color = {
        r = target_r or 255,
        g = target_g or 255,
        b = target_b or 255,
        a = target_a or start_color.a
    }
    
    return self:color_pulse_widget(start_color, target_color)
end

-- Purpose: Apply menu cursor animation (bob + pulse)
function Widget:menu_cursor_widget(bob_distance, pulse_scale, bob_duration, pulse_duration, 
                                  orientation, easing, back_easing, on_complete)
    if not self then
        debug_print("ERROR", "Widget.menu_cursor_widget: Invalid widget")
        return nil
    end
    
    pulse_scale = pulse_scale or 1.1
    bob_distance = bob_distance or 3
    bob_duration = bob_duration or 0.8
    pulse_duration = pulse_duration or (bob_duration * 1.5)
    easing = easing or "smootherstep"
    back_easing = back_easing or "smootherstep"
    
    local orientation = orientation or "vertical"
    local axis = (orientation == "vertical") and "y" or "x"
    
    debug_print("INFO", "Widget.menu_cursor_widget: %s menu cursor animation", self.id)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "transform"
    
    -- Animate ALL sprite objects within this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {
            type = "menu_cursor",
            axis = axis,
            bob_distance = bob_distance,
            pulse_scale = pulse_scale
        })
        
        -- Bob animation for sprite
        if AnimationEngine then
            local bob_id = AnimationEngine.animate(
                {[axis] = sprite.properties[axis]},
                {[axis] = sprite.properties[axis] - bob_distance},
                bob_duration,
                {
                    easing = easing,
                    easing_back = back_easing,
                    on_update = function(values)
                        if axis == "y" then
                            sprite:update({y = values[axis]})
                        else
                            sprite:update({x = values[axis]})
                        end
                    end,
                    loop = true,
                    ping_pong = true
                }
            )
            
            -- Pulse animation for sprite
            local pulse_id = AnimationEngine.animate(
                {scale = 1.0},
                {scale = pulse_scale},
                pulse_duration,
                {
                    easing = "ease_in_out",
                    on_update = function(values)
                        sprite:update({sx = values.scale, sy = values.scale})
                    end,
                    loop = true,
                    ping_pong = true
                }
            )
            
            if bob_id then sprite.active_animations[bob_id] = true end
            if pulse_id then sprite.active_animations[pulse_id] = true end
        end
    end
    
    -- Also animate child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:menu_cursor_widget(bob_distance, pulse_scale, bob_duration, pulse_duration, 
                                      orientation, easing, back_easing, on_complete)
    end
    
    if not AnimationEngine then
        load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "Widget.menu_cursor_widget: AnimationEngine not available")
            return nil
        end
    end
    
    -- Bob animation for widget
    local bob_id = AnimationEngine.animate(
        {[axis] = self[axis]},
        {[axis] = self[axis] - bob_distance},
        bob_duration,
        {
            easing = easing,
            easing_back = back_easing,
            on_update = function(values)
                if axis == "y" then
                    self:setPosition(self.x, values[axis])
                else
                    self:setPosition(values[axis], self.y)
                end
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    -- Pulse animation for widget
    local pulse_id = AnimationEngine.animate(
        {scale = 1.0},
        {scale = pulse_scale},
        pulse_duration,
        {
            easing = "ease_in_out",
            on_update = function(values)
                self:setScale(values.scale)
            end,
            loop = true,
            ping_pong = true
        }
    )
    
    if bob_id then self.active_animations[bob_id] = true end
    if pulse_id then self.active_animations[pulse_id] = true end
    
    return {
        bob = bob_id,
        pulse = pulse_id,
        stop = function()
            AnimationEngine.stop_animation(bob_id)
            AnimationEngine.stop_animation(pulse_id)
            if self.active_animations then
                self.active_animations[bob_id] = nil
                self.active_animations[pulse_id] = nil
            end
            
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
                sprite:stop_animation()
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
                child_widget:stop_widget_animation()
            end
            
            if on_complete then
                on_complete()
            end
        end
    }
end

-- Purpose: Apply shake animation to widget
function Widget:shake_widget(intensity, duration, frequency, on_complete)
    if not self then
        debug_print("ERROR", "Widget.shake_widget: Invalid widget")
        return nil
    end
    
    intensity = intensity or 5
    duration = duration or 0.5
    frequency = frequency or 15
    
    debug_print("INFO", "Widget.shake_widget: %s shake intensity %d", self.id, intensity)
    
    -- Mark layout animation as active
    self._layout_animation_active = true
    self._layout_animation_type = "position"
    
    -- Animate ALL sprite objects within this widget
    for sprite_id, sprite in pairs(self.sprite_objects) do
        sprite:set_widget_animated(true, {type = "shake", intensity = intensity})
        
        -- Create shake animation for each sprite
        if AnimationSequences then
            local proxy = {
                x = sprite.properties.x,
                y = sprite.properties.y,
                rotation = sprite.properties.ro or 0,
                setPosition = function(_, x, y)
                    sprite:update({x = x, y = y})
                end,
                setRotation = function(_, rotation)
                    sprite:update({ro = rotation})
                end
            }
            
            AnimationSequences.shake(proxy, {
                intensity = intensity,
                duration = duration,
                frequency = frequency
            })
        end
    end
    
    -- Also animate child widgets
    for _, child_widget in pairs(self._child_widgets) do
        child_widget:shake_widget(intensity, duration, frequency)
    end
    
    if not AnimationSequences then
        load_animation_modules()
        if not AnimationSequences then
            debug_print("WARN", "Widget.shake_widget: AnimationSequences not available")
            return nil
        end
    end
    
    -- Create a proxy object for the animation
    local proxy = {
        x = self.x,
        y = self.y,
        rotation = self.ro or 0,
        setPosition = function(_, x, y)
            self:setPosition(x, y)
        end,
        setRotation = function(_, rotation)
            self:setRotation(rotation)
        end
    }
    
    local seq_id = AnimationSequences.shake(proxy, {
        intensity = intensity,
        duration = duration,
        frequency = frequency,
        on_complete = function()
            if self.active_sequences then
                self.active_sequences[seq_id] = nil
            end
            
            -- Clear animation flags
            self._layout_animation_active = false
            self._layout_animation_type = nil
            
            -- Clear sprite animation flags
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_widget_animated(false)
            end
            
            -- Clear child widget animation flags
            for _, child_widget in pairs(self._child_widgets) do
                child_widget._layout_animation_active = false
                child_widget._layout_animation_type = nil
            end
            
            if on_complete then
                on_complete()
            end
        end
    })
    
    if seq_id then
        self.active_sequences[seq_id] = true
    end
    
    return seq_id
end

-- Purpose: Apply instant transition (no animation)
function Widget:set_widget_instant(properties)
    if not self then
        debug_print("ERROR", "Widget.set_widget_instant: Invalid widget")
        return
    end
    
    debug_print("INFO", "Widget.set_widget_instant: %s instant update", self.id)
    
    for key, value in pairs(properties) do
        if key == "x" or key == "y" then
            self:setPosition(value, properties.y or self.y)
            
            -- Update all sprite positions
            local delta_x = (properties.x or self.x) - self.x
            local delta_y = (properties.y or self.y) - self.y
            
            for sprite_id, sprite in pairs(self.sprite_objects) do
                local sprite_props = sprite:get_properties()
                sprite:update({
                    x = sprite_props.x + delta_x,
                    y = sprite_props.y + delta_y
                })
            end
        elseif key == "sx" or key == "sy" then
            self:setScale(value, properties.sy or value)
            
            -- Update all sprite scales
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:update({
                    sx = value,
                    sy = properties.sy or value
                })
            end
        elseif key == "ro" then
            self:setRotation(value)
            
            -- Update all sprite rotations
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:update({ro = value})
            end
        elseif key == "opacity" then
            self:setOpacity(value)
            
            -- Update all sprite opacities
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_opacity(value)
            end
        elseif key == "r" or key == "g" or key == "b" or key == "a" then
            self:setColor(
                properties.r or self.r,
                properties.g or self.g,
                properties.b or self.b,
                properties.a or self.a
            )
            
            -- Update all sprite colors
            for sprite_id, sprite in pairs(self.sprite_objects) do
                sprite:set_color(
                    properties.r or self.r,
                    properties.g or self.g,
                    properties.b or self.b,
                    properties.a or self.a
                )
            end
        end
    end
end

-- Purpose: Reset widget to its initial state
function Widget:reset_widget(initial_values)
    if not self then
        debug_print("ERROR", "Widget.reset_widget: Invalid widget")
        return
    end
    
    debug_print("INFO", "Widget.reset_widget: %s resetting", self.id)
    
    self:stop_widget_animation()
    
    local reset_props = initial_values or {
        x = self.x or 0,
        y = self.y or 0,
        sx = self.sx or 1.0,
        sy = self.sy or 1.0,
        ro = self.ro or 0,
        opacity = self.opacity or 255,
        r = self.r or 255,
        g = self.g or 255,
        b = self.b or 255
    }
    
    self:set_widget_instant(reset_props)
end

-- Purpose: Stop widget animation
function Widget:stop_widget_animation(anim_id)
    if not self then
        debug_print("ERROR", "Widget.stop_widget_animation: Invalid widget")
        return false
    end
    
    if anim_id then
        local success = false
        if AnimationEngine then
            success = AnimationEngine.stop_animation(anim_id)
            if not success then
                success = AnimationEngine.stop_sequence(anim_id)
            end
        end
        
        if success then
            if self.active_animations then
                self.active_animations[anim_id] = nil
            end
            if self.active_sequences then
                self.active_sequences[anim_id] = nil
            end
        end
        return success
    else
        -- Stop all animations
        if AnimationEngine then
            if self.active_animations then
                for id, _ in pairs(self.active_animations) do
                    AnimationEngine.stop_animation(id)
                end
                self.active_animations = {}
            end
            if self.active_sequences then
                for id, _ in pairs(self.active_sequences) do
                    AnimationEngine.stop_sequence(id)
                end
                self.active_sequences = {}
            end
        end
        
        -- Clear animation flags
        self._layout_animation_active = false
        self._layout_animation_type = nil
        
        -- Stop animations on all sprites
        for _, sprite in pairs(self.sprite_objects) do
            sprite:stop_animation()
            sprite:set_widget_animated(false)
        end
        
        -- Stop animations on child widgets
        for _, widget in pairs(self._child_widgets) do
            widget:stop_widget_animation()
        end
        
        return true
    end
end

-- Purpose: Check if a widget has active animations
function Widget:has_active_animations()
    if not self then return false end
    
    local has_animations = false
    
    if self.active_animations and next(self.active_animations) ~= nil then
        has_animations = true
    end
    
    if self.active_sequences and next(self.active_sequences) ~= nil then
        has_animations = true
    end
    
    return has_animations
end

-- Purpose: Check if a specific animation is running on a widget
function Widget:is_animation_running(anim_id)
    if not self then return false end
    
    local is_running = false
    
    if self.active_animations and self.active_animations[anim_id] then
        is_running = true
    end
    
    if self.active_sequences and self.active_sequences[anim_id] then
        is_running = true
    end
    
    return is_running
end

-- Purpose: Get widget properties
function Widget:get_widget_properties()
    if not self then return nil end
    
    return {
        x = self.x,
        y = self.y,
        sx = self.sx,
        sy = self.sy,
        ro = self.ro,
        opacity = self.opacity,
        r = self.r,
        g = self.g,
        b = self.b,
        a = self.a,
        visible = self.state.visible,
        enabled = self.state.enabled,
        has_animations = self:has_active_animations()
    }
end

-- ===========================================================
-- WIDGET BASE METHODS (CONTINUED)
-- ===========================================================

-- Create and manage sprite objects with optional layout dimensions
function Widget:create_sprite(sprite_id, texture_path, anim_path, anim_state, layout_width, layout_height)
    -- Generate unique sprite ID if not provided
    local unique_sprite_id = sprite_id or generate_unique_id("sprite")
    
    if self.sprite_objects[unique_sprite_id] then
        debug_print("WARN", "Widget.create_sprite: Sprite %s already exists in widget %s", 
                   unique_sprite_id, self.id)
        return self.sprite_objects[unique_sprite_id]
    end
    
    local sprite = SpriteObject.new(unique_sprite_id, self.id, self.player_id, 
                                   texture_path, anim_path, anim_state)
    
    -- Set custom layout dimensions if provided
    if layout_width and layout_height then
        sprite:set_layout_dimensions(layout_width, layout_height)
    end
    
    self.sprite_objects[unique_sprite_id] = sprite
    
    -- Add to children for layout
    table.insert(self.children, {
        type = "sprite",
        sprite_id = unique_sprite_id,
        sprite = sprite,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state,
        layout_width = layout_width,  -- Store custom dimensions
        layout_height = layout_height,
        id = unique_sprite_id
    })
    
    self.state.dirty = true
    self.state.needs_layout = true
    
    debug_print("INFO", "Widget.create_sprite: %s added to widget %s with layout dimensions %dx%d", 
               unique_sprite_id, self.id, layout_width or 0, layout_height or 0)
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

-- Set layout dimensions for sprite (pre-scaling)
function Widget:set_sprite_layout_dimensions(sprite_id, width, height)
    local sprite = self.sprite_objects[sprite_id]
    if sprite then
        sprite:set_layout_dimensions(width, height)
        
        -- Update the child entry with layout dimensions
        for _, child in ipairs(self.children) do
            if child.type == "sprite" and child.sprite_id == sprite_id then
                child.layout_width = width
                child.layout_height = height
                break
            end
        end
        
        self.state.dirty = true
        self.state.needs_layout = true
        
        debug_print("INFO", "Widget.set_sprite_layout_dimensions: %s = %dx%d", 
                   sprite_id, width, height)
        return true
    else
        debug_print("WARN", "Widget.set_sprite_layout_dimensions: Sprite %s not found", sprite_id)
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
        
        -- Mark all sprites as needing redraw since position changed
        for sprite_id, sprite in pairs(self.sprite_objects) do
            sprite.drawn = false
        end
    end
    return self
end

function Widget:setScale(sx, sy)
    debug_print("VERBOSE", "Widget.setScale: %s from (%f,%f) to (%f,%f)", 
               self.id, self.sx, self.sy, sx, sy or sx)
    
    if self.sx ~= sx or self.sy ~= (sy or sx) then
        self.sx = sx
        self.sy = sy or sx
        self.state.dirty = true
    end
    return self
end

function Widget:setRotation(ro)
    debug_print("VERBOSE", "Widget.setRotation: %s from %f to %f", 
               self.id, self.ro, ro)
    
    if self.ro ~= ro then
        self.ro = ro
        self.state.dirty = true
    end
    return self
end

function Widget:setColor(r, g, b, a)
    debug_print("VERBOSE", "Widget.setColor: %s to (%d,%d,%d,%d)", 
               self.id, r, g, b, a)
    
    self.r = r or self.r
    self.g = g or self.g
    self.b = b or self.b
    self.a = a or self.a
    self.state.dirty = true
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
    
    self.opacity = opacity
    
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

-- Add child with optional layout dimensions
function Widget:addChild(child)
    if child and child.id then
        child.parent = self
        
        if child.type == "sprite" and child.texture_path then
            -- Create sprite object with optional layout dimensions
            local unique_sprite_id = child.sprite_id or generate_unique_id("sprite")
            local sprite = self:create_sprite(
                unique_sprite_id,
                child.texture_path,
                child.anim_path,
                child.anim_state,
                child.layout_width,  -- Pass custom dimensions
                child.layout_height
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
            
            debug_print("DETAILED", "Widget.addChild: Added sprite %s to widget %s with layout %dx%d", 
                       sprite.id, self.id, child.layout_width or 0, child.layout_height or 0)
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

-- UPDATED: Respects sprite animations when positioning
function Widget:updateLayout(force)
    debug_print("VERBOSE", "Widget.updateLayout: %s dirty=%s, force=%s, needs_layout=%s, layout_animation=%s", 
               self.id, tostring(self.state.dirty), tostring(force), tostring(self.state.needs_layout),
               tostring(self._layout_animation_active))
    
    if self.state.dirty or force or self.state.needs_layout then
        -- Skip layout updates if widget is being animated (unless forced)
        if self._layout_animation_active and not force then
            debug_print("DETAILED", "  Skipping layout update due to active animation")
            return false
        end
        
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
            -- Calculate widget-relative position (relative to this widget's top-left)
            local child_widget_x = child.x + self.padding.left + self.margin.left
            local child_widget_y = child.y + self.padding.top + self.margin.top
            
            debug_print("VERBOSE", "  Child %d: type=%s, widget-relative=(%d,%d), layout=(%d,%d)",
                       i, child.sprite_id and "sprite" or "widget", 
                       child_widget_x, child_widget_y, child.x, child.y)
            
            if child.sprite_id then
                -- Update sprite position (using widget-relative coordinates)
                local sprite = self.sprite_objects[child.sprite_id]
                if sprite then
                    -- Check if sprite is being animated by widget
                    if not sprite:is_widget_animated() then
                        -- Only set sprite position if it's not being animated
                        sprite:set_position(child_widget_x, child_widget_y)
                        debug_print("DETAILED", "    Sprite %s positioned at widget-relative (%d,%d)", 
                                   child.sprite_id, child_widget_x, child_widget_y)
                    else
                        debug_print("DETAILED", "    Sprite %s is being animated, skipping layout position", 
                                   child.sprite_id)
                    end
                    
                    if child.visible ~= nil then
                        sprite:set_visible(self.state.visible and child.visible)
                    else
                        sprite:set_visible(self.state.visible)
                    end
                else
                    debug_print("WARN", "    Sprite not found: %s", child.sprite_id)
                end
            elseif child.widget then
                -- Update child widget position (relative to this widget's screen position)
                debug_print("VERBOSE", "    Updating child widget: %s", child.widget.id)
                
                -- Check if child widget is being animated
                if not child.widget._layout_animation_active then
                    -- Set child widget position relative to parent widget's position
                    child.widget:setPosition(self.x + child_widget_x, self.y + child_widget_y)
                    child.widget:updateLayout(force)
                else
                    debug_print("DETAILED", "    Child widget %s is being animated, skipping layout position", 
                               child.widget.id)
                end
            end
        end
        
        -- Update child widgets that might not have been in positioned_children
        local widget_count = 0
        for _, widget in pairs(self._child_widgets) do
            widget_count = widget_count + 1
            if not widget._layout_animation_active then
                widget:updateLayout(force)
            else
                debug_print("DETAILED", "  Child widget %s is being animated, skipping layout update", widget.id)
            end
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
    
    -- Draw all sprites in this widget
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
    
    -- Update layout if dirty and not being animated
    if self.state.dirty and not self._layout_animation_active then
        if self:updateLayout(false) then
            updated = true
        end
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

function Widget:animate_properties(properties, duration, options)
    options = options or {}  -- Ensure options is always a table
    
    if not AnimationEngine then
        load_animation_modules()
        if not AnimationEngine then
            debug_print("WARN", "Widget.animate_properties: AnimationEngine not available")
            return nil
        end
    end
    
    local start_properties = {
        x = self.x,
        y = self.y,
        sx = self.sx,
        sy = self.sy,
        ro = self.ro,
        opacity = self.opacity,
        r = self.r,
        g = self.g,
        b = self.b,
        a = self.a
    }
    
    local target_properties = {}
    for key, value in pairs(properties) do
        if start_properties[key] ~= nil then
            target_properties[key] = value
        end
    end
    
    local anim_id = AnimationEngine.animate(start_properties, target_properties, duration, {
        easing = options.easing or "ease_in_out",
        on_update = function(values)
            if values.x or values.y then
                self:setPosition(values.x or self.x, values.y or self.y)
            end
            if values.sx or values.sy then
                self:setScale(values.sx or self.sx, values.sy or self.sy)
            end
            if values.ro then
                self:setRotation(values.ro)
            end
            if values.opacity then
                self:setOpacity(values.opacity)
            end
            if values.r or values.g or values.b or values.a then
                self:setColor(values.r or self.r, values.g or self.g, values.b or self.b, values.a or self.a)
            end
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
    })
    
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
    
    local anim_id = AnimationEngine.animate(
        {opacity = self.opacity},
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
    print(indent .. "  Layout Animation Active: " .. tostring(self._layout_animation_active))
    print(indent .. "  Layout Animation Type: " .. (self._layout_animation_type or "none"))
    print(indent .. "  Sprites: " .. table_count(self.sprite_objects))
    print(indent .. "  Sprite Groups: " .. table_count(self.sprite_groups))
    print(indent .. "  Children: " .. #self.children)
    print(indent .. "  Child Widgets: " .. table_count(self._child_widgets))
    print(indent .. "  Active Animations: " .. table_count(self.active_animations))
    
    if table_count(self.sprite_objects) > 0 then
        print(indent .. "  Sprite details:")
        for sprite_id, sprite in pairs(self.sprite_objects) do
            local layout_width, layout_height = sprite:get_layout_dimensions()
            local visual_width, visual_height = sprite:get_visual_dimensions()
            print(indent .. "    " .. sprite_id .. ": " .. 
                  (sprite.texture_path or "unknown") .. 
                  " (template: " .. sprite.template_id .. 
                  ", layout: " .. layout_width .. "x" .. layout_height ..
                  ", visual: " .. visual_width .. "x" .. visual_height ..
                  ", position: (" .. sprite.properties.x .. "," .. sprite.properties.y .. ")" ..
                  ", widget animated: " .. tostring(sprite:is_widget_animated()) ..
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
-- ROW WIDGET (UPDATED TO RESPECT ANIMATIONS)
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
    
    -- First pass: calculate dimensions and collect positioned children
    for i, child in ipairs(self.children) do
        local child_width, child_height = 0, 0
        local child_id = nil
        local child_sprite_id = nil
        local child_widget = nil
        
        if child.type == "sprite" then
            child_id = child.id
            child_sprite_id = child.sprite_id
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                -- Use layout dimensions if specified, otherwise use visual dimensions
                if child.layout_width and child.layout_height then
                    -- Use custom layout dimensions (pre-scaling)
                    child_width = child.layout_width
                    child_height = child.layout_height
                    debug_print("DETAILED", "  Child %d using custom layout: %dx%d", 
                               i, child_width, child_height)
                else
                    -- Use visual dimensions (including scale)
                    child_width, child_height = sprite:get_visual_dimensions()
                    debug_print("DETAILED", "  Child %d using visual dimensions: %dx%d", 
                               i, child_width, child_height)
                end
            end
        elseif child.widget then
            child_id = child.widget.id
            child_widget = child.widget
            child_width, child_height = child.widget:getCalculatedSize()
            debug_print("DETAILED", "  Child %d widget dimensions: %dx%d", i, child_width, child_height)
        elseif child.width and child.height then
            child_id = child.id
            child_width = child.width
            child_height = child.height
            debug_print("DETAILED", "  Child %d explicit dimensions: %dx%d", i, child_width, child_height)
        else
            debug_print("WARN", "  Child %d has no dimensions!", i)
        end
        
        -- Adjust for cross axis alignment
        if self.cross_axis_alignment == "stretch" then
            child_height = math.max(child_height, available_height - self.padding.top - self.padding.bottom)
            debug_print("DETAILED", "    Stretched height to: %d", child_height)
        end
        
        -- Create positioned child object
        local positioned_child = {
            x = total_width,
            y = 0,
            width = child_width,
            height = child_height,
            visible = child.visible ~= false,
            id = child_id
        }
        
        -- Set type-specific properties
        if child_sprite_id then
            positioned_child.sprite_id = child_sprite_id
        elseif child_widget then
            positioned_child.widget = child_widget
        end
        
        table.insert(positioned_children, positioned_child)
        
        debug_print("DETAILED", "  Child %d positioned at x=%d, y=%d, size=%dx%d", 
                   i, positioned_child.x, positioned_child.y, child_width, child_height)
        
        total_width = total_width + child_width
        max_height = math.max(max_height, child_height)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_width = total_width + self.spacing
            debug_print("DETAILED", "  Added spacing: total_width now %d", total_width)
        end
    end
    
    debug_print("DETAILED", "  First pass total: width=%d, max_height=%d", total_width, max_height)
    
    -- Adjust for main axis alignment
    local extra_width = available_width - total_width - self.padding.left - self.padding.right
    debug_print("DETAILED", "  Extra width available: %d", extra_width)
    
    if extra_width > 0 then
        local start_x = 0
        
        if self.main_axis_alignment == "center" then
            start_x = extra_width / 2
            debug_print("DETAILED", "  Center alignment: start_x=%d", start_x)
        elseif self.main_axis_alignment == "end" then
            start_x = extra_width
            debug_print("DETAILED", "  End alignment: start_x=%d", start_x)
        elseif self.main_axis_alignment == "space_between" then
            if #positioned_children > 1 then
                local spacing = extra_width / (#positioned_children - 1)
                debug_print("DETAILED", "  Space between: spacing=%d", spacing)
                for i = 2, #positioned_children do
                    positioned_children[i].x = positioned_children[i].x + (spacing * (i - 1))
                end
            end
        elseif self.main_axis_alignment == "space_around" then
            local spacing = extra_width / #positioned_children
            debug_print("DETAILED", "  Space around: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].x = positioned_children[i].x + (spacing * (i - 0.5))
            end
        elseif self.main_axis_alignment == "space_evenly" then
            local spacing = extra_width / (#positioned_children + 1)
            debug_print("DETAILED", "  Space evenly: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].x = positioned_children[i].x + (spacing * i)
            end
        end
        
        -- Apply start offset
        if start_x > 0 then
            debug_print("DETAILED", "  Applying start offset: %d", start_x)
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
            debug_print("DETAILED", "  Child %d centered vertically: y=%d", i, child.y)
        elseif self.cross_axis_alignment == "end" then
            child.y = extra_height
            debug_print("DETAILED", "  Child %d aligned to end: y=%d", i, child.y)
        else
            debug_print("DETAILED", "  Child %d aligned to start: y=0", i)
        end
    end
    
    local layout_width = math.max(total_width, self.width)
    local layout_height = math.max(max_height, self.height)
    
    debug_print("INFO", "Row layout calculated: %s = %dx%d, positioned %d children", 
               self.id, layout_width, layout_height, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

-- ===========================================================
-- COLUMN WIDGET (UPDATED TO RESPECT ANIMATIONS)
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
    
    -- First pass: calculate dimensions and collect positioned children
    for i, child in ipairs(self.children) do
        local child_width, child_height = 0, 0
        local child_id = nil
        local child_sprite_id = nil
        local child_widget = nil
        
        if child.type == "sprite" then
            child_id = child.id
            child_sprite_id = child.sprite_id
            local sprite = self.sprite_objects[child.sprite_id]
            if sprite then
                -- Use layout dimensions if specified, otherwise use visual dimensions
                if child.layout_width and child.layout_height then
                    -- Use custom layout dimensions (pre-scaling)
                    child_width = child.layout_width
                    child_height = child.layout_height
                    debug_print("DETAILED", "  Child %d using custom layout: %dx%d", 
                               i, child_width, child_height)
                else
                    -- Use visual dimensions (including scale)
                    child_width, child_height = sprite:get_visual_dimensions()
                    debug_print("DETAILED", "  Child %d using visual dimensions: %dx%d", 
                               i, child_width, child_height)
                end
            end
        elseif child.widget then
            child_id = child.widget.id
            child_widget = child.widget
            child_width, child_height = child.widget:getCalculatedSize()
            debug_print("DETAILED", "  Child %d widget dimensions: %dx%d", i, child_width, child_height)
        elseif child.width and child.height then
            child_id = child.id
            child_width = child.width
            child_height = child.height
            debug_print("DETAILED", "  Child %d explicit dimensions: %dx%d", i, child_width, child_height)
        else
            debug_print("WARN", "  Child %d has no dimensions!", i)
        end
        
        -- Adjust for cross axis alignment
        if self.cross_axis_alignment == "stretch" then
            child_width = math.max(child_width, available_width - self.padding.left - self.padding.right)
            debug_print("DETAILED", "    Stretched width to: %d", child_width)
        end
        
        -- Create positioned child object
        local positioned_child = {
            x = 0,
            y = total_height,
            width = child_width,
            height = child_height,
            visible = child.visible ~= false,
            id = child_id
        }
        
        -- Set type-specific properties
        if child_sprite_id then
            positioned_child.sprite_id = child_sprite_id
        elseif child_widget then
            positioned_child.widget = child_widget
        end
        
        table.insert(positioned_children, positioned_child)
        
        debug_print("DETAILED", "  Child %d positioned at x=%d, y=%d, size=%dx%d", 
                   i, positioned_child.x, positioned_child.y, child_width, child_height)
        
        total_height = total_height + child_height
        max_width = math.max(max_width, child_width)
        
        -- Add spacing except after last child
        if i < #self.children then
            total_height = total_height + self.spacing
            debug_print("DETAILED", "  Added spacing: total_height now %d", total_height)
        end
    end
    
    debug_print("DETAILED", "  First pass total: max_width=%d, height=%d", max_width, total_height)
    
    -- Adjust for main axis alignment
    local extra_height = available_height - total_height - self.padding.top - self.padding.bottom
    debug_print("DETAILED", "  Extra height available: %d", extra_height)
    
    if extra_height > 0 then
        local start_y = 0
        
        if self.main_axis_alignment == "center" then
            start_y = extra_height / 2
            debug_print("DETAILED", "  Center alignment: start_y=%d", start_y)
        elseif self.main_axis_alignment == "end" then
            start_y = extra_height
            debug_print("DETAILED", "  End alignment: start_y=%d", start_y)
        elseif self.main_axis_alignment == "space_between" then
            if #positioned_children > 1 then
                local spacing = extra_height / (#positioned_children - 1)
                debug_print("DETAILED", "  Space between: spacing=%d", spacing)
                for i = 2, #positioned_children do
                    positioned_children[i].y = positioned_children[i].y + (spacing * (i - 1))
                end
            end
        elseif self.main_axis_alignment == "space_around" then
            local spacing = extra_height / #positioned_children
            debug_print("DETAILED", "  Space around: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].y = positioned_children[i].y + (spacing * (i - 0.5))
            end
        elseif self.main_axis_alignment == "space_evenly" then
            local spacing = extra_height / (#positioned_children + 1)
            debug_print("DETAILED", "  Space evenly: spacing=%d", spacing)
            for i = 1, #positioned_children do
                positioned_children[i].y = positioned_children[i].y + (spacing * i)
            end
        end
        
        -- Apply start offset
        if start_y > 0 then
            debug_print("DETAILED", "  Applying start offset: %d", start_y)
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
            debug_print("DETAILED", "  Child %d centered horizontally: x=%d", i, child.x)
        elseif self.cross_axis_alignment == "end" then
            child.x = extra_width
            debug_print("DETAILED", "  Child %d aligned to end: x=%d", i, child.x)
        else
            debug_print("DETAILED", "  Child %d aligned to start: x=0", i)
        end
    end
    
    local layout_width = math.max(max_width, self.width)
    local layout_height = math.max(total_height, self.height)
    
    debug_print("INFO", "Column layout calculated: %s = %dx%d, positioned %d children", 
               self.id, layout_width, layout_height, #positioned_children)
    
    return layout_width, layout_height, positioned_children
end

-- ===========================================================
-- GRID WIDGET (UPDATED TO RESPECT ANIMATIONS)
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

function Grid:addItem(item_id, texture_path, anim_path, anim_state, data, layout_width, layout_height)
    debug_print("INFO", "Grid.addItem: %s adding item %s", self.id, item_id)
    
    local item = {
        id = item_id,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state or "",
        data = data or {},
        sprite_id = generate_unique_id(self.id .. "_item"),
        layout_width = layout_width,
        layout_height = layout_height
    }
    
    table.insert(self.items, item)
    
    -- Add as child sprite with optional layout dimensions
    self:addChild({
        type = "sprite",
        sprite_id = item.sprite_id,
        texture_path = texture_path,
        anim_path = anim_path,
        anim_state = anim_state,
        layout_width = layout_width,
        layout_height = layout_height,
        id = item_id
    })
    
    debug_print("DETAILED", "  Item sprite_id: %s, layout: %dx%d", 
               item.sprite_id, layout_width or 0, layout_height or 0)
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
    
    debug_print("DETAILED", "  Initial cell size: %dx%d", cell_width, cell_height)
    
    if cell_width == 0 or cell_height == 0 then
        -- Auto-size: find largest item
        local max_item_width, max_item_height = 0, 0
        
        for i, item in ipairs(self.items) do
            local item_width, item_height
            local sprite = self.sprite_objects[item.sprite_id]
            
            if sprite then
                -- Use layout dimensions if specified, otherwise use visual dimensions
                if item.layout_width and item.layout_height then
                    item_width = item.layout_width
                    item_height = item.layout_height
                else
                    item_width, item_height = sprite:get_visual_dimensions()
                end
            else
                -- Fallback to dimension cache
                item_width, item_height = SpriteDimensionCache.get_dimensions(
                    item.texture_path, item.anim_path, item.anim_state)
            end
            
            debug_print("DETAILED", "  Item %d (%s) dimensions: %dx%d", 
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
        
        debug_print("DETAILED", "  Item %d: row=%d, col=%d, base position=(%d,%d)", 
                   i, row, col, x, y)
        
        -- Get item dimensions
        local sprite_width, sprite_height
        local sprite = self.sprite_objects[item.sprite_id]
        
        if sprite then
            if item.layout_width and item.layout_height then
                -- Use custom layout dimensions
                sprite_width = item.layout_width
                sprite_height = item.layout_height
            else
                -- Use visual dimensions
                sprite_width, sprite_height = sprite:get_visual_dimensions()
            end
        else
            -- Fallback
            sprite_width, sprite_height = SpriteDimensionCache.get_dimensions(
                item.texture_path, item.anim_path, item.anim_state)
        end
        
        -- Center sprite in cell
        local offset_x = (cell_width - sprite_width) / 2
        local offset_y = (cell_height - sprite_height) / 2
        
        debug_print("DETAILED", "    Sprite: %dx%d, offset=(%d,%d)", 
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
-- CONTAINER WIDGET (UPDATED TO RESPECT ANIMATIONS)
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
    
    debug_print("DETAILED", "  Available for child: %dx%d (after padding)", 
               child_width, child_height)
    
    -- Update child layout
    self.child:setSize(child_width, child_height)
    self.child:updateLayout()
    
    local child_layout_width, child_layout_height = self.child:getCalculatedSize()
    
    debug_print("DETAILED", "  Child calculated size: %dx%d", 
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
-- EXPANDED WIDGET (UPDATED TO RESPECT ANIMATIONS)
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
            layout_width = option.width,  -- Support custom width
            layout_height = option.height, -- Support custom height
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
            layout_width = element.width,  -- Support custom width
            layout_height = element.height, -- Support custom height
            id = element.id
        })
    end
    
    return hud
end

-- ===========================================================
-- ANIMATION HELPERS (UPDATED TO ANIMATE SPRITES)
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
    
    -- Animate widget position (which will also animate sprites)
    return widget:slide_widget(target_x, target_y, duration, options.easing, options.on_complete)
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
    
    -- Animate widget opacity (which will also animate sprites)
    return widget:set_opacity_widget(target_opacity, duration, options.easing, options.on_complete)
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
    
    -- Use widget's pulse animation (which will also animate sprites)
    return widget:pulse_scale_widget(scale_from, scale_to, duration, easing, loop, on_complete)
end

-- Shake animation
function WidgetAnimations.shakeWidget(widget, intensity, duration, easing, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.shakeWidget: Invalid widget")
        return nil
    end
    
    -- Use widget's shake animation (which will also animate sprites)
    return widget:shake_widget(intensity, duration, easing, on_complete)
end

-- Color pulse animation
function WidgetAnimations.colorPulseWidget(widget, target_color, duration, easing, loop, on_complete)
    if not widget then
        debug_print("ERROR", "WidgetAnimations.colorPulseWidget: Invalid widget")
        return nil
    end
    
    -- Use widget's color pulse animation (which will also animate sprites)
    return widget:color_pulse_widget(target_color, duration, easing, loop, on_complete)
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
    print(indent .. "│  Layout Animation: " .. tostring(widget._layout_animation_active))
    print(indent .. "│  Layout Animation Type: " .. (widget._layout_animation_type or "none"))
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
                print(indent .. "│        layout: " .. (child.layout_width or "auto") .. "x" .. (child.layout_height or "auto"))
                local sprite = widget:get_sprite(child.sprite_id)
                if sprite then
                    print(indent .. "│        template: " .. sprite.template_id)
                    print(indent .. "│        widget animated: " .. tostring(sprite:is_widget_animated()))
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