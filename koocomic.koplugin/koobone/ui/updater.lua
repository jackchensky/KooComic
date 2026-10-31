local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local TextViewer = require("ui/widget/textviewer")
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
        "KooComic·可漫 v" .. tostring(release.version) .. " 已发布",
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
        title = "更新 KooComic·可漫到 v" .. tostring(release.version),
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
            text = "KooComic·可漫 v" .. tostring(release.version) ..
                " 已安装。必须重启 KOReader 才能启用新版本。",
            cancel_text = "稍后重启",
            ok_text = "立即重启",
            ok_callback = function() UIManager:restartKOReader() end,
        })
    end)
end

function UpdaterUI:showAvailable(release, automatic)
    if automatic then self.updater:markPromptShown(release) end
    local dialog
    dialog = TextViewer:new{
        title = "KooComic·可漫版本更新",
        text = self:_releaseText(release),
        show_menu = false,
        buttons_table = {{
            {
                text = "稍后更新",
                callback = function()
                    UIManager:close(dialog)
                    if automatic then
                        self.updater:deferPrompt()
                        if self.on_changed then self.on_changed() end
                    end
                end,
            },
            {
                text = "立即更新",
                callback = function()
                    UIManager:close(dialog)
                    self:install(release)
                end,
            },
        }},
    }
    UIManager:show(dialog)
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
    local checking
    if manual then
        checking = InfoMessage:new{ text = "正在检查更新……", dismissable = false }
        UIManager:show(checking)
    end
    UIManager:scheduleIn(0.15, function()
        local success, release, has_update
        success, release, has_update = pcall(self.updater.check, self.updater)
        if checking then UIManager:close(checking) end
        -- Allow the previous widget's close/redraw to complete before opening
        -- another modal, particularly on e-ink displays and fast responses.
        UIManager:scheduleIn(checking and 0.1 or 0, function()
            if not success then
                if manual then UIManager:show(InfoMessage:new{ text = "检查更新失败，请稍后重试。" }) end
                return
            end
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
    end)
end

return UpdaterUI
