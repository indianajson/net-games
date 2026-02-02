-- widgets/utils.lua
-- Utility functions for widgets

local LOGGING = require('scripts/net-games/widgets/logging')
local debug_print = LOGGING.debug_print

local utils = {}

-- Screen configuration for 240x160 with 2x upscale
utils.SCREEN_WIDTH = 240
utils.SCREEN_HEIGHT = 160
utils.SCREEN_SCALE = 2.0
utils.SCREEN_SCALED_WIDTH = utils.SCREEN_WIDTH * utils.SCREEN_SCALE
utils.SCREEN_SCALED_HEIGHT = utils.SCREEN_HEIGHT * utils.SCREEN_SCALE

-- Normalize coordinates from screen space (240x160) to scaled space (480x320)
function utils.normalize_x(x)
    return x * utils.SCREEN_SCALE
end

function utils.normalize_y(y)
    return y * utils.SCREEN_SCALE
end

-- Scale coordinates back from scaled space to screen space
function utils.scale_x(x)
    return x / utils.SCREEN_SCALE
end

function utils.scale_y(y)
    return y / utils.SCREEN_SCALE
end

-- Get scaled dimensions for sprites (layout dimensions should be in screen space)
function utils.get_scaled_dimensions(width, height)
    return width * utils.SCREEN_SCALE, height * utils.SCREEN_SCALE
end

-- Check if point is within screen bounds (in screen space coordinates)
function utils.is_within_screen(x, y, width, height)
    local scaled_x = utils.normalize_x(x)
    local scaled_y = utils.normalize_y(y)
    local scaled_width = width and utils.normalize_x(width) or 0
    local scaled_height = height and utils.normalize_y(height) or 0
    
    return scaled_x >= 0 and scaled_y >= 0 and 
           scaled_x + scaled_width <= utils.SCREEN_SCALED_WIDTH and
           scaled_y + scaled_height <= utils.SCREEN_SCALED_HEIGHT
end

-- Get screen center in screen space coordinates
function utils.get_screen_center()
    return utils.SCREEN_WIDTH / 2, utils.SCREEN_HEIGHT / 2
end

-- Get screen center in scaled coordinates
function utils.get_scaled_screen_center()
    return utils.normalize_x(utils.SCREEN_WIDTH / 2), 
           utils.normalize_y(utils.SCREEN_HEIGHT / 2)
end

-- Constrain widget to screen boundaries
function utils.constrain_to_screen(x, y, width, height)
    local scaled_width = width and utils.normalize_x(width) or 0
    local scaled_height = height and utils.normalize_y(height) or 0
    local scaled_x = utils.normalize_x(x)
    local scaled_y = utils.normalize_y(y)
    
    local max_x = utils.SCREEN_SCALED_WIDTH - scaled_width
    local max_y = utils.SCREEN_SCALED_HEIGHT - scaled_height
    
    scaled_x = math.max(0, math.min(max_x, scaled_x))
    scaled_y = math.max(0, math.min(max_y, scaled_y))
    
    return utils.scale_x(scaled_x), utils.scale_y(scaled_y)
end

-- Generate a unique ID
function utils.generate_unique_id(prefix)
    prefix = prefix or "id"
    return string.format("%s_%08x", prefix, math.random(0x10000000, 0x7fffffff))
end

-- Deep copy a table
function utils.table_deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.table_deepcopy(orig_key)] = utils.table_deepcopy(orig_value)
        end
        setmetatable(copy, utils.table_deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Count table elements
function utils.table_count(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Check if table contains value
function utils.table_contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Load animation modules correctly
function utils.load_animation_modules()
    debug_print("INFO", "Loading animation modules via AnimationEngine...")
    
    local AnimationEngine = require('scripts/net-games/animation-engine/animation-engine')
    
    -- Use the backward compatibility method if available, otherwise get from engine
    if AnimationEngine.load_animation_modules then
        return AnimationEngine.load_animation_modules()
    else
        return AnimationEngine, AnimationEngine.Sequences, AnimationEngine.Enums
    end
end

-- Safe wrapper for Net API calls
function utils.safe_net_call(func_name, ...)
    if not Net or not Net[func_name] then
        debug_print("ERROR", "Net.%s not available", func_name)
        return false
    end
    local success, result = pcall(Net[func_name], ...)
    if not success then
        debug_print("ERROR", "Net.%s failed: %s", func_name, result)
        return false
    end
    return result
end

-- Merge two tables
function utils.table_merge(t1, t2)
    local result = utils.table_deepcopy(t1)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(result[k]) == "table" then
            result[k] = utils.table_merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

-- Clamp a value between min and max
function utils.clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    end
    return value
end

-- Linear interpolation
function utils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Round to nearest integer
function utils.round(value)
    return math.floor(value + 0.5)
end

-- Format number with specified decimal places
function utils.format_number(num, decimals)
    decimals = decimals or 2
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

-- Create a color table from RGB values
function utils.create_color(r, g, b, a)
    return {
        r = utils.clamp(r or 255, 0, 255),
        g = utils.clamp(g or 255, 0, 255),
        b = utils.clamp(b or 255, 0, 255),
        a = utils.clamp(a or 255, 0, 255)
    }
end

-- Convert screen coordinates to percentage
function utils.to_percent_x(x)
    return (x / utils.SCREEN_WIDTH) * 100
end

function utils.to_percent_y(y)
    return (y / utils.SCREEN_HEIGHT) * 100
end

-- Convert percentage to screen coordinates
function utils.from_percent_x(percent)
    return (percent / 100) * utils.SCREEN_WIDTH
end

function utils.from_percent_y(percent)
    return (percent / 100) * utils.SCREEN_HEIGHT
end

-- Get screen aspect ratio
function utils.get_aspect_ratio()
    return utils.SCREEN_WIDTH / utils.SCREEN_HEIGHT
end

-- Check if two rectangles intersect (in screen space)
function utils.rectangles_intersect(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x1 + w1 > x2 and
           y1 < y2 + h2 and
           y1 + h1 > y2
end

-- Get distance between two points (in screen space)
function utils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Get angle between two points (in radians)
function utils.angle_between(x1, y1, x2, y2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- Convert degrees to radians
function utils.deg_to_rad(degrees)
    return degrees * (math.pi / 180)
end

-- Convert radians to degrees
function utils.rad_to_deg(radians)
    return radians * (180 / math.pi)
end

-- Check if point is within rectangle (in screen space)
function utils.point_in_rectangle(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and
           py >= ry and py <= ry + rh
end

-- Create a gradient color table
function utils.create_gradient(color1, color2, steps)
    local gradient = {}
    for i = 0, steps - 1 do
        local t = i / (steps - 1)
        table.insert(gradient, {
            r = utils.lerp(color1.r, color2.r, t),
            g = utils.lerp(color1.g, color2.g, t),
            b = utils.lerp(color1.b, color2.b, t),
            a = utils.lerp(color1.a, color2.a, t)
        })
    end
    return gradient
end

-- Parse color from hex string
function utils.parse_hex_color(hex)
    hex = hex:gsub("#", "")
    if #hex == 3 then
        return {
            r = tonumber(hex:sub(1, 1) .. hex:sub(1, 1), 16),
            g = tonumber(hex:sub(2, 2) .. hex:sub(2, 2), 16),
            b = tonumber(hex:sub(3, 3) .. hex:sub(3, 3), 16),
            a = 255
        }
    elseif #hex == 6 then
        return {
            r = tonumber(hex:sub(1, 2), 16),
            g = tonumber(hex:sub(3, 4), 16),
            b = tonumber(hex:sub(5, 6), 16),
            a = 255
        }
    elseif #hex == 8 then
        return {
            r = tonumber(hex:sub(1, 2), 16),
            g = tonumber(hex:sub(3, 4), 16),
            b = tonumber(hex:sub(5, 6), 16),
            a = tonumber(hex:sub(7, 8), 16)
        }
    end
    return {r = 255, g = 255, b = 255, a = 255}
end

-- Format color as hex string
function utils.format_hex_color(color)
    return string.format("#%02x%02x%02x%02x", 
        math.floor(color.r or 255), 
        math.floor(color.g or 255), 
        math.floor(color.b or 255), 
        math.floor(color.a or 255))
end

-- Debug print for table
function utils.debug_print_table(tbl, indent)
    indent = indent or 0
    local spaces = string.rep(" ", indent)
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(spaces .. k .. ":")
            utils.debug_print_table(v, indent + 2)
        else
            print(spaces .. k .. ": " .. tostring(v))
        end
    end
end

-- NEW: Convert table to string for debugging
function utils.table_to_string(tbl)
    local result = "{"
    local first = true
    for k, v in pairs(tbl) do
        if not first then result = result .. ", " end
        if type(k) == "string" then
            result = result .. k .. "="
        end
        if type(v) == "table" then
            result = result .. utils.table_to_string(v)
        elseif type(v) == "string" then
            result = result .. '"' .. v .. '"'
        else
            result = result .. tostring(v)
        end
        first = false
    end
    return result .. "}"
end

-- NEW: Calculate alignment with origin offset
-- This positions the ORIGIN point at the aligned position
function utils.align_with_origin(width, height, ox, oy, container_width, container_height, 
                                 main_align, cross_align, is_main_axis_horizontal)
    local x, y = 0, 0
    
    if is_main_axis_horizontal then
        -- For Row widget (main axis is horizontal)
        -- Main axis alignment affects X position
        if main_align == "center" then
            x = (container_width - width) / 2
        elseif main_align == "end" then
            x = container_width - width
        end
        -- "start" alignment leaves x at 0
        
        -- Cross axis alignment affects Y position
        if cross_align == "center" then
            y = (container_height - height) / 2
        elseif cross_align == "end" then
            y = container_height - height
        end
        -- "start" alignment leaves y at 0
    else
        -- For Column widget (main axis is vertical)
        -- Main axis alignment affects Y position
        if main_align == "center" then
            y = (container_height - height) / 2
        elseif main_align == "end" then
            y = container_height - height
        end
        -- "start" alignment leaves y at 0
        
        -- Cross axis alignment affects X position
        if cross_align == "center" then
            x = (container_width - width) / 2
        elseif cross_align == "end" then
            x = container_width - width
        end
        -- "start" alignment leaves x at 0
    end
    
    -- Adjust position so the ORIGIN point is at (x, y)
    -- The layout stores top-left positions, so we need to add the origin offset
    local top_left_x = x - ox
    local top_left_y = y - oy
    
    return top_left_x, top_left_y
end

-- NEW: Calculate alignment for multiple children with spacing
function utils.distribute_children_with_origin(total_children, container_size, total_size, 
                                              spacing, alignment, is_main_axis)
    local positions = {}
    local start_pos = 0
    
    if alignment == "center" then
        start_pos = (container_size - total_size) / 2
    elseif alignment == "end" then
        start_pos = container_size - total_size
    elseif alignment == "space_between" and total_children > 1 then
        spacing = (container_size - total_size) / (total_children - 1)
        start_pos = 0
    elseif alignment == "space_around" then
        spacing = (container_size - total_size) / total_children
        start_pos = spacing / 2
    elseif alignment == "space_evenly" then
        spacing = (container_size - total_size) / (total_children + 1)
        start_pos = spacing
    end
    
    return start_pos, spacing
end

return utils