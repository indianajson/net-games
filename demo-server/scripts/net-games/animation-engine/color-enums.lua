local COLORS = {}
_G.COLORS = COLORS
COLORS.__index = COLORS


COLORS.Color = {}

_G.Color = Color
Color.__index = Color

Color.White = {r = 255, g = 255, b = 255}
Color.Red = {r = 255, g = 0, b = 0}
Color.Green = {r = 0, g = 255, b = 0}
Color.Blue = {r = 0, g = 0, b = 255}
Color.Black = {r = 0, g = 0, b = 0}