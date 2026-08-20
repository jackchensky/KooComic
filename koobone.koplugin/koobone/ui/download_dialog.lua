local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local ProgressWidget = require("ui/widget/progresswidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Util = require("koobone.util")

local Screen = Device.screen

local DownloadDialog = InputContainer:extend{
    name = "koobone_download_progress",
    covers_fullscreen = true,
    stop_events_propagation = true,
    title = "正在下载",
}

function DownloadDialog:init()
    self.dimen = Screen:getSize()
    self.cancelled = false
    self.closed = false
    self.last_draw_at = 0

    local frame_width = math.floor(Screen:getWidth() * 0.84)
    local frame_height = math.floor(Screen:getHeight() * 0.58)
    local content_width = frame_width - Size.padding.large * 2
    local content_height = frame_height - Size.padding.large * 2
    local group = VerticalGroup:new{ align = "center" }

    self.title_widget = TextBoxWidget:new{
        text = self.title or "正在下载",
        face = Font:getFace("ffont", 22),
        bold = true,
        width = content_width,
        height = math.floor(content_height * 0.18),
        height_adjust = false,
        height_overflow_show_ellipsis = true,
        alignment = "center",
    }
    group[#group + 1] = self.title_widget
    group[#group + 1] = VerticalSpan:new{ width = Size.padding.large }

    self.progress_widget = ProgressWidget:new{
        width = content_width,
        height = Screen:scaleBySize(20),
        percentage = 0,
        fillcolor = Blitbuffer.COLOR_BLACK,
        padding = Size.padding.small,
        margin = Size.margin.tiny,
    }
    group[#group + 1] = self.progress_widget
    group[#group + 1] = VerticalSpan:new{ width = Size.padding.small }

    self.percent_widget = TextBoxWidget:new{
        text = "0%",
        face = Font:getFace("cfont", 19),
        width = content_width,
        height = math.floor(content_height * 0.08),
        height_adjust = false,
        alignment = "center",
    }
    group[#group + 1] = self.percent_widget
    group[#group + 1] = VerticalSpan:new{ width = Size.padding.large }

    self.status_widget = TextBoxWidget:new{
        text = "准备下载……",
        face = Font:getFace("cfont", 18),
        width = content_width,
        height = math.floor(content_height * 0.35),
        height_adjust = false,
        height_overflow_show_ellipsis = true,
        alignment = "center",
    }
    group[#group + 1] = self.status_widget
    group[#group + 1] = VerticalSpan:new{ width = Size.padding.large }

    if not self.hide_cancel then
        self.button_table = ButtonTable:new{
            width = content_width,
            show_parent = self,
            zero_sep = true,
            buttons = {{
                {
                    text = self.cancel_text or "取消下载",
                    callback = function()
                        if self.cancelled then return end
                        self.cancelled = true
                        self.status_widget:setText("正在取消，已下载部分将保留……")
                        self:_redraw(true)
                        if self.on_cancel then self.on_cancel() end
                    end,
                },
            }},
        }
        group[#group + 1] = self.button_table
    end

    local fixed = CenterContainer:new{
        dimen = Geom:new{ w = content_width, h = content_height },
        group,
    }
    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius = Size.radius.window,
        padding = Size.padding.large,
        fixed,
    }
    self[1] = CenterContainer:new{ dimen = self.dimen, self.frame }
end

function DownloadDialog:_redraw(force)
    if self.closed then return end
    local now = Util.now()
    if not force and now - self.last_draw_at < 1 then return end
    self.last_draw_at = now
    UIManager:setDirty(self, function() return "fast", self.frame.dimen or self.dimen end)
    UIManager:forceRePaint()
end

function DownloadDialog:setProgress(state)
    state = state or {}
    local current = tonumber(state.current) or 0
    local total = tonumber(state.total) or 0
    local ratio = total > 0 and math.min(1, current / total) or 0
    self.progress_widget:setPercentage(ratio)
    self.percent_widget:setText(total > 0 and
        tostring(math.floor(ratio * 100 + 0.5)) .. "%" or "--%")

    local rows = { tostring(state.stage or "正在下载") }
    if total > 0 then
        rows[#rows + 1] = Util.friendlySize(current) .. " / " .. Util.friendlySize(total)
    else
        rows[#rows + 1] = Util.friendlySize(current)
    end
    if tonumber(state.speed) and state.speed > 0 then
        local line = Util.friendlySize(state.speed) .. "/s"
        if tonumber(state.eta) and state.eta >= 0 then
            line = line .. "　剩余约 " .. Util.friendlyDuration(state.eta)
        end
        rows[#rows + 1] = line
    end
    self.status_widget:setText(table.concat(rows, "\n"))
    self:_redraw(ratio >= 1)
end

function DownloadDialog:setStage(text)
    self.status_widget:setText(tostring(text or ""))
    self:_redraw(true)
end

function DownloadDialog:show()
    UIManager:show(self, "ui")
end

function DownloadDialog:close()
    if self.closed then return end
    self.closed = true
    UIManager:close(self, "ui")
end

function DownloadDialog:onCloseWidget()
    if self.frame and self.frame.dimen then
        UIManager:setDirty(nil, function() return "ui", self.frame.dimen end)
    end
end

return DownloadDialog
