local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local pathchooser_available, PathChooser = pcall(require, "ui/widget/pathchooser")

local SettingsUI = {}

function SettingsUI.show(options)
    local settings = assert(options.settings, "settings required")
    local updater = assert(options.updater, "updater required")
    local updater_ui = assert(options.updater_ui, "updater ui required")
    local storage = assert(options.storage, "storage required")
    local downloader = options.downloader
    local version = assert(options.version, "version required")
    local state = settings:update()
    local ui = settings:ui()
    local text_size_labels = { normal = "标准", large = "大", extra_large = "特大" }
    local text_size_label = text_size_labels[ui.text_size] or "大"
    local reminder
    if state.auto_update_prompt_disabled then
        reminder = "已停止（已稍后 3 次）"
    elseif state.auto_check_enabled then
        reminder = "每天检查"
    else
        reminder = "关闭"
    end
    local title = table.concat({
        "KooComic·可漫设置",
        "",
        "竖屏书架：" .. tostring(ui.portrait_columns) .. " 列 × " .. tostring(ui.portrait_rows) .. " 行",
        "横屏书架：" .. tostring(ui.landscape_columns) .. " 列 × " .. tostring(ui.landscape_rows) .. " 行",
        "界面文字：" .. text_size_label,
        "下载目录：" .. storage:downloadDir(),
        "",
        "当前版本：v" .. version,
        "KOReader：" .. tostring(updater:koreaderVersion()),
        "更新提醒：" .. reminder,
    }, "\n")

    local dialog
    local function applyUiChange()
        settings:flush()
        UIManager:close(dialog)
        if options.on_ui_changed then options.on_ui_changed() end
        SettingsUI.show(options)
    end
    local function cycle(key, values)
        local current = ui[key]
        local target = values[1]
        for index, value in ipairs(values) do
            if value == current then target = values[index % #values + 1]; break end
        end
        ui[key] = target
        applyUiChange()
    end
    local function applyDirectory(path)
        local valid, err = storage:validateDownloadDir(path)
        if not valid then
            UIManager:show(InfoMessage:new{ text = "无法使用这个下载目录：\n" .. tostring(err) })
            return
        end
        local current = storage:downloadDir()
        if valid == current then
            UIManager:show(InfoMessage:new{ text = "当前已经使用这个下载目录。" })
            return
        end
        UIManager:show(ConfirmBox:new{
            text = table.concat({
                "确定切换漫画下载目录吗？",
                "",
                "新目录：" .. valid,
                "",
                "只影响之后的新下载；旧目录中的漫画不会移动，仍可继续打开和删除。",
            }, "\n"),
            cancel_text = "取消",
            ok_text = "切换目录",
            ok_callback = function()
                local saved, save_err = storage:setDownloadDir(valid)
                if not saved then
                    UIManager:show(InfoMessage:new{ text = "切换失败：\n" .. tostring(save_err) })
                    return
                end
                UIManager:show(InfoMessage:new{ text = "下载目录已切换：\n" .. saved })
                if options.on_ui_changed then options.on_ui_changed() end
            end,
        })
    end
    local function chooseDirectory()
        if downloader and downloader:isActive() then
            UIManager:show(InfoMessage:new{ text = "请等待当前下载任务结束后再切换目录。" })
            return
        end
        if not pathchooser_available or not PathChooser then
            UIManager:show(InfoMessage:new{
                text = "当前 KOReader 版本不支持目录选择器，请先升级 KOReader。",
            })
            return
        end
        UIManager:close(dialog)
        UIManager:show(PathChooser:new{
            select_directory = true,
            select_file = false,
            show_files = false,
            path = storage:downloadDir(),
            onConfirm = function(path) applyDirectory(path) end,
        })
    end
    local function showDirectoryMenu()
        local directory_dialog
        directory_dialog = ButtonDialog:new{
            title = "漫画下载目录\n\n当前：" .. storage:downloadDir(),
            buttons = {
                { { text = "选择新目录", callback = function()
                    UIManager:close(directory_dialog)
                    chooseDirectory()
                end } },
                { { text = "恢复默认目录", callback = function()
                    if downloader and downloader:isActive() then
                        UIManager:show(InfoMessage:new{ text = "请等待当前下载任务结束后再切换目录。" })
                        return
                    end
                    UIManager:close(directory_dialog)
                    applyDirectory(storage:defaultDownloadDir())
                end } },
                { { text = "关闭", callback = function() UIManager:close(directory_dialog) end } },
            },
        }
        UIManager:show(directory_dialog)
    end
    dialog = ButtonDialog:new{
        title = title,
        buttons = {
            {
                {
                    text = "竖屏列数：" .. tostring(ui.portrait_columns),
                    callback = function() cycle("portrait_columns", { 2, 3, 4 }) end,
                },
                {
                    text = "竖屏行数：" .. tostring(ui.portrait_rows),
                    callback = function() cycle("portrait_rows", { 1, 2, 3 }) end,
                },
            },
            {
                {
                    text = "横屏列数：" .. tostring(ui.landscape_columns),
                    callback = function() cycle("landscape_columns", { 2, 3, 4, 5 }) end,
                },
                {
                    text = "横屏行数：" .. tostring(ui.landscape_rows),
                    callback = function() cycle("landscape_rows", { 1, 2, 3 }) end,
                },
            },
            {
                {
                    text = "界面文字：" .. text_size_label,
                    callback = function() cycle("text_size", { "normal", "large", "extra_large" }) end,
                },
            },
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
                    callback = showDirectoryMenu,
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
