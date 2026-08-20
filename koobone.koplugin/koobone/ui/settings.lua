local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local SettingsUI = {}

function SettingsUI.show(options)
    local settings = assert(options.settings, "settings required")
    local updater = assert(options.updater, "updater required")
    local updater_ui = assert(options.updater_ui, "updater ui required")
    local storage = assert(options.storage, "storage required")
    local version = assert(options.version, "version required")
    local state = settings:update()
    local reminder
    if state.auto_update_prompt_disabled then
        reminder = "已停止（已稍后 3 次）"
    elseif state.auto_check_enabled then
        reminder = "每天检查"
    else
        reminder = "关闭"
    end
    local title = table.concat({
        "版本与设置",
        "",
        "当前版本：v" .. version,
        "KOReader：" .. tostring(updater:koreaderVersion()),
        "更新提醒：" .. reminder,
    }, "\n")

    local dialog
    dialog = ButtonDialog:new{
        title = title,
        buttons = {
            {
                {
                    text = "检查更新",
                    callback = function()
                        UIManager:close(dialog)
                        updater_ui:check(true)
                    end,
                },
            },
            {
                {
                    text = state.auto_update_prompt_disabled and
                        "重新开启自动提醒" or
                        (state.auto_check_enabled and "关闭每天检查" or "开启每天检查"),
                    callback = function()
                        if state.auto_update_prompt_disabled then
                            UIManager:show(ConfirmBox:new{
                                text = "重新开启后，稍后更新次数将从零开始计算。",
                                cancel_text = "取消",
                                ok_text = "重新开启",
                                ok_callback = function()
                                    updater:resetPromptPolicy()
                                    UIManager:close(dialog)
                                    UIManager:show(InfoMessage:new{ text = "已重新开启自动更新提醒。" })
                                end,
                            })
                        else
                            state.auto_check_enabled = not state.auto_check_enabled
                            settings:flush()
                            UIManager:close(dialog)
                            UIManager:show(InfoMessage:new{
                                text = state.auto_check_enabled and
                                    "已开启每天自动检查。只提醒，不会自动安装。" or
                                    "已关闭每天自动检查。",
                            })
                        end
                    end,
                },
            },
            {
                {
                    text = "下载目录",
                    callback = function()
                        UIManager:show(InfoMessage:new{ text = storage:downloadDir() })
                    end,
                },
            },
            {
                {
                    text = "更新安全说明",
                    callback = function()
                        UIManager:show(InfoMessage:new{
                            text = "更新只使用 HTTPS，校验安装包大小和 SHA-256，安全解压后先备份旧版本。安装必须由用户确认并在重启后生效。",
                        })
                    end,
                },
            },
            {
                {
                    text = "关闭",
                    callback = function() UIManager:close(dialog) end,
                },
            },
        },
    }
    UIManager:show(dialog)
    return dialog
end

return SettingsUI

