-- SPDX-License-Identifier: AGPL-3.0-only

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Metrics = require("koobone.ui.metrics")

local Screen = Device.screen

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
    local frame_height = math.floor(metric.height * (metric.portrait and 0.70 or 0.78))
    local padding = Metrics.dp(18)
    local content_width = frame_width - padding * 2
    local content_height = frame_height - padding * 2
    local title_height = math.floor(content_height * 0.14)
    local subtitle_height = math.floor(content_height * 0.09)
    local body_height = math.floor(content_height * 0.49)

    local group = VerticalGroup:new{ align = "center" }
    group[#group + 1] = TextBoxWidget:new{
        text = tostring(self.title or "koo漫画"),
        face = Metrics.face("ffont", 22, self.text_size),
        bold = true,
        width = content_width,
        height = title_height,
        height_adjust = false,
        height_overflow_show_ellipsis = true,
        alignment = "center",
    }
    if self.subtitle and self.subtitle ~= "" then
        group[#group + 1] = TextBoxWidget:new{
            text = tostring(self.subtitle),
            face = Metrics.face("cfont", 14, self.text_size),
            width = content_width,
            height = subtitle_height,
            height_adjust = false,
            height_overflow_show_ellipsis = true,
            alignment = "center",
            fgcolor = Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_GRAY,
        }
    else
        group[#group + 1] = VerticalSpan:new{ height = subtitle_height }
    end
    group[#group + 1] = VerticalSpan:new{ height = Metrics.dp(8) }
    group[#group + 1] = TextBoxWidget:new{
        text = tostring(self.body or ""),
        face = Metrics.face("cfont", 16, self.text_size),
        width = content_width,
        height = body_height,
        height_adjust = false,
        height_overflow_show_ellipsis = true,
        alignment = self.body_align or "left",
    }
    group[#group + 1] = VerticalSpan:new{ height = Metrics.dp(10) }
    self.button_table = ButtonTable:new{
        width = content_width,
        show_parent = self,
        zero_sep = false,
        buttons = self.buttons or {},
    }
    group[#group + 1] = self.button_table

    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        color = Blitbuffer.COLOR_BLACK,
        bordersize = math.max(2, Metrics.dp(1)),
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
