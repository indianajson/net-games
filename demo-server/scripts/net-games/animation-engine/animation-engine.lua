-- animation-engine.lua
-- Public API & main entry point for the Animation Engine

local AnimationEngine = {}

-- ==============================
-- Internal Requires
-- ==============================
local Enums = require("scripts/net-games/animation-engine/animation-enums")
local MathUtils = require("scripts/net-games/animation-engine/math-utils")

-- Backward compatibility for legacy code
_G.AnimationEngine = AnimationEngine
AnimationEngine.__index = AnimationEngine
-- ==============================
-- Internal State
-- ==============================
local _animations = {}
local _sequences = {}
local _debug = false

local function log(...)
    if _debug then
        print("[AnimationEngine]", ...)
    end
end

-- ==============================
-- Core Helpers
-- ==============================
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function apply_easing(easing, t)
    local fn = Enums.Easing[easing] or Enums.Easing["linear"]
    return fn(t)
end

-- ==============================
-- Animation API
-- ==============================
function AnimationEngine.animate(start_values, target_values, duration, options)
    options = options or {}

    local id = options.id or ("anim_" .. tostring(os.clock()))
    local easing = options.easing or "linear"

    _animations[id] = {
        start = start_values,
        target = target_values,
        duration = duration,
        elapsed = 0,
        easing = easing,
        loop = options.loop,
        on_update = options.on_update,
        on_complete = options.on_complete
    }

    log("Animation started:", id)
    return id
end

function AnimationEngine.stop_animation(id)
    if _animations[id] then
        _animations[id] = nil
        return true
    end
    return false
end

function AnimationEngine.delay(duration, callback)
    return AnimationEngine.animate({}, {}, duration, {
        on_complete = callback
    })
end

-- ==============================
-- Sequence API
-- ==============================
function AnimationEngine.create_sequence(steps, options)
    options = options or {}

    local id = options.id or ("seq_" .. tostring(os.clock()))

    _sequences[id] = {
        id = id,
        steps = steps,
        index = 1,
        active_anim = nil,
        elapsed = 0,
        loop = options.loop,
        on_complete = options.on_complete
    }

    return id
end

function AnimationEngine.start_sequence(id)
    local seq = _sequences[id]
    if not seq then return end

    seq.index = 1
    seq.elapsed = 0
    seq.active_anim = nil
end

function AnimationEngine.stop_sequence(id)
    _sequences[id] = nil
end

-- ==============================
-- Tick / Update Loop
-- ==============================
function AnimationEngine.tick(dt)
    -- ---- Animations ----
    for id, anim in pairs(_animations) do
        anim.elapsed = anim.elapsed + dt
        local t = math.min(anim.elapsed / anim.duration, 1)
        t = apply_easing(anim.easing, t)

        local values = {}
        for k, v in pairs(anim.start) do
            if type(v) == "number" and type(anim.target[k]) == "number" then
                values[k] = lerp(v, anim.target[k], t)
            else
                values[k] = anim.target[k]
            end
        end

        if anim.on_update then
            anim.on_update(values, t)
        end

        if anim.elapsed >= anim.duration then
            if anim.on_complete then
                anim.on_complete(values)
            end
            if anim.loop then
                anim.elapsed = 0
            else
                _animations[id] = nil
            end
        end
    end

    -- ---- Sequences ----
    for _, seq in pairs(_sequences) do
        local step = seq.steps[seq.index]
        if not step then
            if seq.loop then
                seq.index = 1
            else
                if seq.on_complete then seq.on_complete() end
                _sequences[seq.id] = nil
            end
            goto continue
        end

        if step.type == "delay" then
            seq.elapsed = seq.elapsed + dt
            if seq.elapsed >= step.duration then
                seq.elapsed = 0
                seq.index = seq.index + 1
            end

        elseif step.type == "animate" then
            if not seq.active_anim then
                seq.active_anim = AnimationEngine.animate(
                    step.from,
                    step.to,
                    step.duration,
                    {
                        easing = step.easing,
                        on_update = step.on_update,
                        on_complete = function()
                            seq.active_anim = nil
                            seq.index = seq.index + 1
                        end
                    }
                )
            end

        elseif step.type == "callback" then
            if step.fn then step.fn() end
            seq.index = seq.index + 1
        end

        ::continue::
    end
end

-- ==============================
-- Utilities
-- ==============================
function AnimationEngine.clear_all()
    _animations = {}
    _sequences = {}
end

function AnimationEngine.set_debug(v)
    _debug = v
end

function AnimationEngine.add_easing_function(name, fn)
    Enums[name] = fn
end

-- ==============================
-- Public API Surface
-- ==============================
AnimationEngine.Enums = Enums
AnimationEngine.Math = MathUtils

-- Require sequences LAST and inject engine
local Sequences = require("scripts/net-games/animation-engine/animation-sequences")
if type(Sequences.set_engine) == "function" then
    Sequences.set_engine(AnimationEngine)
end
AnimationEngine.Sequences = Sequences

return AnimationEngine
