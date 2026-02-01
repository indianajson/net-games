-- animation-enums.lua (enhanced)
local AnimationEnums = {}
_G.AnimationEnums = AnimationEnums
AnimationEnums.__index = AnimationEnums

local Easing = {}
_G.AnimationEnums.Easing = Easing
AnimationEnums.Easing = Easing

function Easing.instant(t)
    return 1
end

function Easing.linear(t)
    return t
end

function Easing.ease_in(t)
    return t * t
end

function Easing.ease_out(t)
    return t * (2 - t)
end

function Easing.ease_in_out(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

function Easing.smoothstep(t)
    return t * t * (3 - 2 * t)
end

function Easing.smootherstep(t)
    return t * t * t * (t * (6 * t - 15) + 10)
end

function Easing.elastic_in(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    local s = p / 4
    return -(2^(10 * (t - 1))) * math.sin((t - 1 - s) * (2 * math.pi) / p)
end
    
function Easing.elastic_out(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    local s = p / 4
    return 2^(-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
end
    
function Easing.bounceOut(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end
    
function Easing.bounce_in(t)
    t = 1 - t
    if t < 1 / 2.75 then
        return 1 - 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 1 - (7.5625 * t * t + 0.75)
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 1 - (7.5625 * t * t + 0.9375)
    else
        t = t - 2.625 / 2.75
        return 1 - (7.5625 * t * t + 0.984375)
    end
end
    
function Easing.elastic_in_out(t)
    if t == 0 or t == 1 then return t end
    local p = 0.3
    local s = p / 4

    if t < 0.5 then
        t = t * 2  -- Scale t to [0, 1]
        return -0.5 * (2^(10 * (t - 1))) * math.sin((t - 1 - s) * (2 * math.pi) / p)
    else
        t = (t - 0.5) * 2  -- Scale t to [0, 1]
        return 0.5 * (2^(-10 * t)) * math.sin((t - s) * (2 * math.pi) / p) + 0.5
    end
end

function Easing.sine_in(t)
    return 1 - math.cos((t * math.pi) / 2)
end

function Easing.sine_out(t)
    return math.sin((t * math.pi) / 2)
end
function Easing.sine_in_out(t)
    return -(math.cos(math.pi * t) - 1) / 2
end

function Easing.circ_in(t)
    return 1 - math.sqrt(1 - t * t)
end

function Easing.circ_out(t)
    t = t - 1
    return math.sqrt(1 - t * t)
end

function Easing.circ_in_out(t)
    t = t * 2
    if t < 1 then
        return -(math.sqrt(1 - t * t) - 1) / 2
    else
        t = t - 2
        return (math.sqrt(1 - t * t) + 1) / 2
    end
end

function Easing.back_in(t)
    local s = 1.70158
    return t * t * ((s + 1) * t - s)
end

function Easing.back_out(t)
    local s = 1.70158
    t = t - 1
    return t * t * ((s + 1) * t + s) + 1
end

function Easing.back_in_out(t)
    local s = 1.70158 * 1.525
    t = t * 2
    if t < 1 then
        return 0.5 * (t * t * ((s + 1) * t - s))
    else
        t = t - 2
        return 0.5 * (t * t * ((s + 1) * t + s) + 2)
    end
end

AnimationEnums.easing_function_names = {
    instant = "instant",
    linear = "linear",
    ease_in = "ease_in",
    ease_out = "ease_out",
    ease_in_out = "ease_in_out",
    smoothstep = "smoothstep",
    smootherstep = "smootherstep",
    elastic_in = "elastic_in",
    elastic_out = "elastic_out",
    bounce_out = "bounce_out",
    bounce_in = "bounce_in",
    elastic_in_out = "elastic_in_out",
    square = "square",
    cubic = "cubic"
}

-- Animation type enums
AnimationEnums.animation_types = {
    SUMMON = "summon",
    SET = "set",
    POSITION_CHANGE = "position_change",
    ATTACK = "attack",
    SLIDE = "slide",
    BOB = "bob",
    PULSE = "pulse",
    SHAKE = "shake",
    FADE = "fade",
    TINT = "tint",
    COLOR_PULSE = "color_pulse"
}

-- Animation property enums
AnimationEnums.animation_properties = {
    POSITION_X = "x",
    POSITION_Y = "y",
    SCALE = "scale",
    SCALE_X = "scaleX",
    SCALE_Y = "scaleY",
    ROTATION = "rotation",
    ALPHA = "alpha",
    COLOR_R = "r",
    COLOR_G = "g",
    COLOR_B = "b",
    COLOR_A = "a"
}

-- Animation direction enums
AnimationEnums.directions = {
    UP = "up",
    DOWN = "down",
    LEFT = "left",
    RIGHT = "right",
    IN = "in",
    OUT = "out"
}

-- Animation trigger enums
AnimationEnums.triggers = {
    ON_CLICK = "on_click",
    ON_HOVER = "on_hover",
    ON_SHOW = "on_show",
    ON_HIDE = "on_hide",
    ON_COMPLETE = "on_complete",
    ON_START = "on_start"
}

return {
    EasingFns = AnimationEnums.easing_function_names,
    AnimationTypes = AnimationEnums.animation_types,
    Properties = AnimationEnums.animation_properties,
    Directions = AnimationEnums.directions,
    Triggers = AnimationEnums.triggers,
    Easing = Easing 
}