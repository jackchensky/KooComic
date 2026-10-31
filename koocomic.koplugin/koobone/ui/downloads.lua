local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local Util = require("koobone.util")

local DownloadsUI = {}

local state_names = {
    preparing = "准备中",
    downloading = "下载中",
    complete = "已完成",
    failed = "失败",
    cancelled = "已取消",
    interrupted = "未完成",
    missing = "文件已删除",
}

local function displayDetail(info)
    local detail = state_names[info.state] or tostring(info.state or "未知")
    if info.exists then
        detail = detail .. "　" .. Util.friendlySize(info.size)
    elseif info.part_exists then
        detail = detail .. "　临时文件 " .. Util.friendlySize(info.part_size)
    end
    return detail
end

local function notifyChanged(downloader)
    if downloader.notifyChanged then downloader:notifyChanged() end
end

local function requireIdle(downloader, message)
    if not downloader:isActive() then return true end
    UIManager:show(InfoMessage:new{
        text = message or "请等待当前下载任务结束后再清理。",
    })
    return false
end

function DownloadsUI.show(storage, downloader)
    local menu
    local function refresh()
        if menu then UIManager:close(menu) end
        notifyChanged(downloader)
        DownloadsUI.show(storage, downloader)
    end

    local function showRecord(row)
        local info = storage:recordInfo(row)
        if not info then
            UIManager:show(InfoMessage:new{ text = "这条下载记录无法读取。" })
            return
        end
        local title = info.title ~= "" and info.title or "未命名漫画"
        local body = table.concat({
            title,
            "",
            "状态：" .. displayDetail(info),
            info.path and ("文件：" .. info.path) or "",
            info.value.error and ("错误：" .. tostring(info.value.error)) or "",
        }, "\n")
        local dialog
        local buttons = {}

        if info.exists then
            buttons[#buttons + 1] = {
                {
                    text = "打开阅读",
                    callback = function()
                        local current = storage:recordInfo(row)
                        if not current or not current.exists then
                            UIManager:close(dialog)
                            UIManager:show(InfoMessage:new{ text = "本地文件已经不存在。" })
                            refresh()
                            return
                        end
                        UIManager:close(dialog)
                        downloader:open(current.path)
                    end,
                },
            }
            buttons[#buttons + 1] = {
                {
                    text = "删除本地漫画",
                    callback = function()
                        if not requireIdle(downloader, "请等待当前下载任务结束后再删除。") then return end
                        UIManager:close(dialog)
                        UIManager:show(ConfirmBox:new{
                            text = table.concat({
                                "确定删除 Kindle 上的本地漫画吗？",
                                "",
                                title,
                                Util.friendlySize(info.size),
                                tostring(info.path or ""),
                                "",
                                "不会删除 KOOBONE 云端书库中的漫画或阅读记录。",
                            }, "\n"),
                            cancel_text = "取消",
                            ok_text = "删除本地漫画",
                            ok_callback = function()
                                local ok, result = storage:deleteRecordFiles(info.key)
                                if not ok then
                                    UIManager:show(InfoMessage:new{
                                        text = "删除失败：\n" .. tostring(result),
                                    })
                                    return
                                end
                                UIManager:show(InfoMessage:new{
                                    text = "已删除本地漫画，释放 " ..
                                        Util.friendlySize(result) .. "。",
                                })
                                refresh()
                            end,
                        })
                    end,
                },
            }
        elseif info.part_exists then
            buttons[#buttons + 1] = {
                {
                    text = "删除临时文件及记录",
                    callback = function()
                        if not requireIdle(downloader) then return end
                        UIManager:close(dialog)
                        UIManager:show(ConfirmBox:new{
                            text = "确定删除未完成的临时文件和这条下载记录吗？\n\n" ..
                                title .. "\n" .. Util.friendlySize(info.part_size),
                            cancel_text = "取消",
                            ok_text = "删除临时文件",
                            ok_callback = function()
                                local ok, result = storage:deleteRecordPartial(info.key)
                                if not ok then
                                    UIManager:show(InfoMessage:new{
                                        text = "清理失败：\n" .. tostring(result),
                                    })
                                    return
                                end
                                UIManager:show(InfoMessage:new{
                                    text = "已删除临时文件，释放 " ..
                                        Util.friendlySize(result) .. "。",
                                })
                                refresh()
                            end,
                        })
                    end,
                },
            }
        else
            buttons[#buttons + 1] = {
                {
                    text = "移除失效记录",
                    callback = function()
                        if not requireIdle(downloader) then return end
                        UIManager:close(dialog)
                        UIManager:show(ConfirmBox:new{
                            text = "本地文件已经不存在。是否从下载管理中移除这条记录？\n\n" .. title,
                            cancel_text = "取消",
                            ok_text = "移除记录",
                            ok_callback = function()
                                storage:removeRecord(info.key)
                                UIManager:show(InfoMessage:new{ text = "已移除失效记录。" })
                                refresh()
                            end,
                        })
                    end,
                },
            }
        end

        buttons[#buttons + 1] = {
            { text = "关闭", callback = function() UIManager:close(dialog) end },
        }
        dialog = ButtonDialog:new{ title = body, buttons = buttons }
        UIManager:show(dialog)
    end

    local function showMaintenance()
        local summary = storage:maintenanceSummary()
        local dialog
        dialog = ButtonDialog:new{
            title = table.concat({
                "下载清理",
                "",
                "失效记录：" .. tostring(summary.missing_records) .. " 条",
                "临时文件：" .. tostring(summary.partial_files) .. " 个 / " ..
                    Util.friendlySize(summary.partial_bytes),
            }, "\n"),
            buttons = {
                {
                    {
                        text = "清理失效记录",
                        callback = function()
                            if not requireIdle(downloader) then return end
                            if summary.missing_records <= 0 then
                                UIManager:show(InfoMessage:new{ text = "没有失效记录。" })
                                return
                            end
                            UIManager:close(dialog)
                            UIManager:show(ConfirmBox:new{
                                text = "确定移除 " .. tostring(summary.missing_records) ..
                                    " 条本地文件已不存在的记录吗？\n\n不会删除任何现有文件。",
                                cancel_text = "取消",
                                ok_text = "清理记录",
                                ok_callback = function()
                                    local count = storage:cleanupMissingRecords()
                                    UIManager:show(InfoMessage:new{
                                        text = "已清理 " .. tostring(count) .. " 条失效记录。",
                                    })
                                    refresh()
                                end,
                            })
                        end,
                    },
                },
                {
                    {
                        text = "清理临时文件",
                        callback = function()
                            if not requireIdle(downloader) then return end
                            if summary.partial_files <= 0 then
                                UIManager:show(InfoMessage:new{ text = "没有未完成的临时文件。" })
                                return
                            end
                            UIManager:close(dialog)
                            UIManager:show(ConfirmBox:new{
                                text = "确定删除 " .. tostring(summary.partial_files) ..
                                    " 个未完成临时文件吗？\n\n预计释放 " ..
                                    Util.friendlySize(summary.partial_bytes) .. "。",
                                cancel_text = "取消",
                                ok_text = "清理临时文件",
                                ok_callback = function()
                                    local result = storage:cleanupPartialFiles()
                                    local message = "已删除 " .. tostring(result.files) ..
                                        " 个临时文件，释放 " .. Util.friendlySize(result.bytes) .. "。"
                                    if #result.errors > 0 then
                                        message = message .. "\n另有 " .. tostring(#result.errors) .. " 个文件删除失败。"
                                    end
                                    UIManager:show(InfoMessage:new{ text = message })
                                    refresh()
                                end,
                            })
                        end,
                    },
                },
                {
                    { text = "关闭", callback = function() UIManager:close(dialog) end },
                },
            },
        }
        UIManager:show(dialog)
    end

    local records = storage:records()
    if #records == 0 then
        UIManager:show(InfoMessage:new{ text = "还没有下载记录。" })
        return
    end

    local rows = {
        {
            text = "清理下载记录与临时文件",
            mandatory = "›",
            callback = showMaintenance,
        },
    }
    for _, row in ipairs(records) do
        local current_row = row
        local info = storage:recordInfo(current_row)
        if info then
            rows[#rows + 1] = {
                text = info.title ~= "" and info.title or "未命名漫画",
                mandatory = displayDetail(info),
                callback = function() showRecord(current_row) end,
            }
        end
    end
    menu = Menu:new{
        title = "KooComic·可漫下载",
        subtitle = tostring(#records) .. " 条记录",
        item_table = rows,
        is_borderless = true,
        title_bar_fm_style = true,
    }
    UIManager:show(menu)
    return menu
end

return DownloadsUI
