local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local DownloadDialog = require("koobone.ui.download_dialog")
local Util = require("koobone.util")

local UpdaterUI = {}
UpdaterUI.__index = UpdaterUI

function UpdaterUI:new(options)
    return setmetatable({
        updater = assert(options.updater, "updater required"),
        downloader = assert(options.downloader, "downloader required"),
        on_changed = options.on_changed,
    }, self)
end

function UpdaterUI:_releaseText(release)
    local rows = {
        "koo漫画 v" .. tostring(release.version) .. " 已发布",
        "当前版本：v" .. tostring(self.updater.current_version),
        "安装包：" .. Util.friendlySize(release.size),
    }
    if release.summary and release.summary ~= "" then rows[#rows + 1] = "\n" .. release.summary end
    if release.notes and release.notes ~= "" then rows[#rows + 1] = "\n" .. release.notes end
    return table.concat(rows, "\n")
end

function UpdaterUI:install(release)
    if self.downloader:isActive() then
        UIManager:show(InfoMessage:new{ text = "漫画正在下载，请完成后再更新插件。" })
        return
    end
    local dialog = DownloadDialog:new{
        title = "更新 koo漫画到 v" .. tostring(release.version),
        hide_cancel = true,
    }
    dialog:show()
    UIManager:scheduleIn(0.15, function()
        local ok, err = self.updater:install(release, function(state)
            dialog:setProgress{
                stage = state.stage,
                current = state.percent,
                total = 100,
            }
        end)
        dialog:close()
        if not ok then
            UIManager:show(InfoMessage:new{ text = "更新失败：\n" .. tostring(err) })
            return
        end
        UIManager:show(ConfirmBox:new{
            text = "koo漫画 v" .. tostring(release.version) ..
                " 已安装。必须重启 KOReader 才能启用新版本。",
            cancel_text = "稍后重启",
            ok_text = "立即重启",
            ok_callback = function() UIManager:restartKOReader() end,
        })
    end)
end

function UpdaterUI:showAvailable(release, automatic)
    if automatic then self.updater:markPromptShown(release) end
    UIManager:show(ConfirmBox:new{
        text = self:_releaseText(release),
        cancel_text = "稍后更新",
        ok_text = "立即更新",
        cancel_callback = function()
            if automatic then
                self.updater:deferPrompt()
                if self.on_changed then self.on_changed() end
            end
        end,
        ok_callback = function() self:install(release) end,
        flush_events_on_show = true,
    })
end

function UpdaterUI:check(manual)
    if not self.updater:isConfigured() then
        if manual then
            UIManager:show(InfoMessage:new{
                text = "当前版本尚未配置 GitHub 发布地址。创建仓库后即可启用在线更新。",
            })
        end
        return
    end
    if manual then UIManager:show(InfoMessage:new{ text = "正在检查更新……", timeout = 1 }) end
    UIManager:scheduleIn(0.15, function()
        local release, has_update = self.updater:check()
        if not release then
            if manual then UIManager:show(InfoMessage:new{ text = "检查更新失败：\n" .. tostring(has_update) }) end
            return
        end
        if has_update then
            if manual or self.updater:shouldPrompt(release) then
                self:showAvailable(release, not manual)
            end
        elseif manual then
            UIManager:show(InfoMessage:new{
                text = "当前已是最新版本：v" .. tostring(self.updater.current_version),
            })
        end
    end)
end

return UpdaterUI
