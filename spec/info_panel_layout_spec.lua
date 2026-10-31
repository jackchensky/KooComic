package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local screen = { w = 600, h = 800, scale = 1 }
local function class(kind)
    local cls = {}
    function cls:extend(fields) return setmetatable(fields or {}, { __index = self }) end
    function cls:new(fields)
        local object = setmetatable(fields or {}, { __index = self })
        object.kind = kind
        if object.init then object:init() end
        return object
    end
    function cls:free() self.freed = true end
    function cls:getSize()
        if kind == "buttons" then return { w = self.width, h = #self.buttons * math.floor(68 * screen.scale) } end
        if kind == "vertical" then
            local h = 0
            for _, child in ipairs(self) do h = h + child:getSize().h end
            return { w = 1, h = h }
        end
        if kind == "center" then return self.dimen end
        if kind == "frame" then
            local size = self[1]:getSize()
            return { w = size.w + 2 * (self.padding + self.bordersize), h = size.h + 2 * (self.padding + self.bordersize) }
        end
        return { w = self.width or 1, h = self.height or 0 }
    end
    return cls
end
package.preload["ffi/blitbuffer"] = function() return { COLOR_BLACK = 0, COLOR_WHITE = 1, COLOR_GRAY = 2 } end
package.preload["device"] = function() return { screen = { getSize = function() return { w = screen.w, h = screen.h } end } } end
package.preload["ui/geometry"] = function() return { new = function(_, t) return t end } end
package.preload["ui/uimanager"] = function() return { close = function() end, setDirty = function() end } end
package.preload["koobone.ui.metrics"] = function() return {
    screen = function() return { width = screen.w, height = screen.h, portrait = screen.h >= screen.w } end,
    dp = function(n) return math.floor(n * screen.scale + 0.5) end,
    face = function() return {} end,
} end
for name, kind in pairs({
    ["ui/widget/buttontable"] = "buttons",
    ["ui/widget/container/centercontainer"] = "center",
    ["ui/widget/container/framecontainer"] = "frame",
    ["ui/widget/container/inputcontainer"] = "input",
    ["ui/widget/textboxwidget"] = "text",
    ["ui/widget/scrolltextwidget"] = "scroll",
    ["ui/widget/verticalgroup"] = "vertical",
    ["ui/widget/verticalspan"] = "span",
}) do package.preload[name] = function() return class(kind) end end

local Panel = require("koobone.ui.info_panel")
local buttons = {
    { { text = "更换 API Key" } },
    { { text = "清除旧版密码" } },
    { { text = "退出账号" } },
    { { text = "版本与设置" }, { text = "关闭" } },
}
local function check(w, h, scale)
    screen.w, screen.h, screen.scale = w, h, scale
    local panel = Panel:new{ title = "账号管理", subtitle = "连接状态", body = "状态\n昵称\nAPI Key", buttons = buttons }
    local inner = panel.frame[1]
    local group = inner[1]
    assert(group:getSize().h <= inner.dimen.h, "content overlaps frame")
    assert(panel.frame:getSize().h <= h * 0.94 + 1, "frame exceeds screen")
    assert(panel.body_widget.kind == "scroll" and panel.body_widget.height >= 1)
    local labels = {}
    for _, row in ipairs(panel.button_table.buttons) do
        for _, button in ipairs(row) do labels[#labels + 1] = button.text end
    end
    assert(#labels == 5 and labels[1] == "更换 API Key" and labels[5] == "关闭")
    return #panel.button_table.buttons
end
assert(check(600, 800, 1) == 4)
assert(check(800, 600, 1) == 4)
assert(check(800, 450, 1) == 3)
check(1200, 1600, 1.5)
print("info panel layout spec: OK")
