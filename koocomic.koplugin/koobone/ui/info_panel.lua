-- SPDX-License-Identifier: AGPL-3.0-only

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Metrics = require("koobone.ui.metrics")

local Screen = Device.screen

-- Merge only adjacent single-button rows when height is tight. Keep button
-- objects, callbacks and order unchanged, and never create rows over 2 items.
local function compactButtons(rows)
    local compact = {}
    for _, row in ipairs(rows or {}) do
        local previous = compact[#compact]
        if #row == 1 and previous and #previous == 1 then
            previous[2] = row[1]
        else
            local copy = {}
            for _, button in ipairs(row) do copy[#copy + 1] = button end
            compact[#compact + 1] = copy
        end
    end
    return compact
end

local InfoPanel = InputContainer:extend{
    name = "koocomic_info_panel",
    covers_fullscreen = true,
    stop_events_propagation = true,
    closed = false,
}

function InfoPanel:init()
    self.dimen = Screen:getSize()
    local metric = Metrics.screen()
    local frame_width = math.floor(metric.width * (metric.portrait and 0.90 or 0.72))
    local padding = Metrics.dp(18)
    local border = math.max(2, Metrics.dp(1))
    local content_width = math.max(1, frame_width - (padding + border) * 2)
    local max_height = math.floor(metric.height * 0.94)
    local max_content_height = math.max(1, max_height - (padding + border) * 2)
    local preferred_height = math.floor(metric.height * (metric.portrait and 0.70 or 0.78))
    local preferred_content_height = math.max(1, preferred_height - (padding + border) * 2)
    local gap_above_body, gap_above_buttons = Metrics.dp(8), Metrics.dp(10)
    local title_height, subtitle_height = Metrics.dp(44), Metrics.dp(28)
    local min_body_height = Metrics.dp(75)

    local title = TextBoxWidget:new{
        text = tostring(self.title or "KooComic·可漫"),
        face = Metrics.face("ffont", 22, self.text_size),
        bold = true, width = content_width, height = title_height,
        height_adjust = false, height_overflow_show_ellipsis = true,
        alignment = "center",
    }
    local subtitle
    if self.subtitle and self.subtitle ~= "" then
        subtitle = TextBoxWidget:new{
            text = tostring(self.subtitle),
            face = Metrics.face("cfont", 14, self.text_size),
            width = content_width, height = subtitle_height,
            height_adjust = false, height_overflow_show_ellipsis = true,
            alignment = "center",
            fgcolor = Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_GRAY,
        }
    end
    local function buttonTable(buttons)
        return ButtonTable:new{
            width = content_width, show_parent = self, zero_sep = false,
            buttons = buttons,
        }
    end
    self.button_table = buttonTable(self.buttons or {})
    local header_height = title:getSize().h + (subtitle and subtitle:getSize().h or 0)
    local fixed_height = header_height + gap_above_body + gap_above_buttons
    local buttons_height = self.button_table:getSize().h
    if fixed_height + min_body_height + buttons_height > max_content_height then
        local compact = compactButtons(self.buttons)
        if #compact < #(self.buttons or {}) then
            self.button_table:free()
            self.button_table = buttonTable(compact)
            buttons_height = self.button_table:getSize().h
        end
    end
    local content_height = math.min(max_content_height, math.max(preferred_content_height,
        fixed_height + buttons_height + min_body_height))
    local body_height = math.max(1, content_height - fixed_height - buttons_height)

    local group = VerticalGroup:new{ align = "center" }
    group[#group + 1] = title
    if subtitle then group[#group + 1] = subtitle end
    group[#group + 1] = VerticalSpan:new{ height = gap_above_body }
    self.body_widget = ScrollTextWidget:new{
        text = tostring(self.body or ""),
        face = Metrics.face("cfont", 16, self.text_size),
        width = content_width,
        height = body_height,
        alignment = self.body_align or "left",
        dialog = self,
    }
    group[#group + 1] = self.body_widget
    group[#group + 1] = VerticalSpan:new{ height = gap_above_buttons }
    group[#group + 1] = self.button_table

    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        color = Blitbuffer.COLOR_BLACK,
        bordersize = border,
        radius = Metrics.dp(8),
        padding = padding,
        CenterContainer:new{ dimen = Geom:new{ w = content_width, h = content_height }, group },
    }
    self[1] = CenterContainer:new{ dimen = self.dimen, self.frame }
end

function InfoPanel:close()
    if self.closed then return end
    self.closed = true
    UIManager:close(self)
end

function InfoPanel:onBack()
    self:close()
    return true
end

function InfoPanel:onShow()
    UIManager:setDirty(self, "ui")
end

function InfoPanel:onCloseWidget()
    if self.frame and self.frame.dimen then
        UIManager:setDirty(nil, function() return "ui", self.frame.dimen end)
    end
end

return InfoPanel
