local AnimationEnums = {}
_G.AnimationEnums = AnimationEnums
AnimationEnums.__index = AnimationEnums

AnimationEnums.easing_function_names = {
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
    bound_in_out = "bound_in_out",
}

return {
    EasingFns = AnimationEnums.easing_function_names,
}