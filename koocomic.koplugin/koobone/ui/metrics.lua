-- SPDX-License-Identifier: AGPL-3.0-only

local Device = require("device")
local Font = require("ui/font")

local Screen = Device.screen
local Metrics = {}

local TEXT_FACTORS = { normal = 1.00, large = 1.14, extra_large = 1.28 }

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

function Metrics.screen()
    local width, height = Screen:getWidth(), Screen:getHeight()
    local density = 1
    if type(Screen.scaleBySize) == "function" then
        local ok, scaled = pcall(Screen.scaleBySize, Screen, 100)
        if ok and tonumber(scaled) and tonumber(scaled) > 0 then
            density = clamp(tonumber(scaled) / 100, 0.65, 2.5)
        end
    end
    local logical_short = math.min(width, height) / density
    local geometry = clamp(logical_short / 758, 0.92, 1.22)
    return {
        width = width,
        height = height,
        portrait = height >= width,
        density = density,
        geometry = geometry,
    }
end

function Metrics.dp(value, minimum, maximum)
    local metric = Metrics.screen()
    local logical = (tonumber(value) or 0) * metric.geometry
    logical = clamp(logical, minimum or 0, maximum or math.huge)
    local raw = logical
    if type(Screen.scaleBySize) == "function" then
        local ok, scaled = pcall(Screen.scaleBySize, Screen, logical)
        if ok and tonumber(scaled) then raw = tonumber(scaled) end
    end
    return math.max(0, math.floor(raw + 0.5))
end

function Metrics.face(name, size, text_size)
    local factor = TEXT_FACTORS[text_size] or TEXT_FACTORS.large
    return Font:getFace(name, math.max(1, math.floor((tonumber(size) or 10) * factor + 0.5)))
end

function Metrics.grid(ui)
    local metric = Metrics.screen()
    ui = type(ui) == "table" and ui or {}
    if metric.portrait then
        return clamp(ui.portrait_columns or 3, 2, 4), clamp(ui.portrait_rows or 2, 1, 3)
    end
    return clamp(ui.landscape_columns or 4, 2, 5), clamp(ui.landscape_rows or 2, 1, 3)
end

return Metrics
