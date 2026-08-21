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
}

function DownloadsUI.show(storage, downloader)
    local rows = {}
    for _, row in ipairs(storage:records()) do
        local value = row.value
        local detail = state_names[value.state] or tostring(value.state or "未知")
        if tonumber(value.bytes) and value.bytes > 0 then
            detail = detail .. "　" .. Util.friendlySize(value.bytes)
        end
        rows[#rows + 1] = {
            text = value.title ~= "" and value.title or "未命名漫画",
            mandatory = detail,
            callback = function()
                if value.state == "complete" and value.path then
                    downloader:open(value.path)
                else
                    UIManager:show(InfoMessage:new{
                        text = table.concat({
                            value.title or "",
                            "状态：" .. detail,
                            value.error and ("错误：" .. value.error) or "",
                        }, "\n"),
                    })
                end
            end,
        }
    end
    if #rows == 0 then
        UIManager:show(InfoMessage:new{ text = "还没有下载记录。" })
        return
    end
    local menu = Menu:new{
        title = "koo漫画下载",
        subtitle = tostring(#rows) .. " 条记录",
        item_table = rows,
        is_borderless = true,
        title_bar_fm_style = true,
    }
    UIManager:show(menu)
    return menu
end

return DownloadsUI
