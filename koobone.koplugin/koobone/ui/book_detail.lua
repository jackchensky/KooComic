local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local Util = require("koobone.util")

local BookDetail = {}

function BookDetail.show(options)
    local item = assert(options.item, "item required")
    local storage = assert(options.storage, "storage required")
    local downloader = assert(options.downloader, "downloader required")
    local downloaded = storage:isDownloaded(item)
    local partial = storage:partSize(item)
    local title = item.vol_name or item.vol_series or "未命名漫画"
    local author = item.vol_author or "未知作者"
    local progress = tostring(item.last_readpage or 0) .. " / " .. tostring(item.count_page or "?")
    local local_state = downloaded and "已下载" or
        (partial > 0 and ("有临时文件 " .. Util.friendlySize(partial)) or "未下载")
    local description = table.concat({
        title,
        "",
        "作者：" .. author,
        "文件：" .. Util.friendlySize(item.file_size),
        "KOOBONE 进度：" .. progress,
        "本地状态：" .. local_state,
    }, "\n")

    local dialog
    local action_text = downloaded and "打开阅读" or (partial > 0 and "重新下载" or "下载")
    dialog = ButtonDialog:new{
        title = description,
        buttons = {
            {
                {
                    text = "关闭",
                    callback = function() UIManager:close(dialog) end,
                },
                {
                    text = action_text,
                    callback = function()
                        UIManager:close(dialog)
                        if downloaded then
                            downloader:open(storage:itemPath(item))
                        else
                            downloader:download(item)
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    return dialog
end

return BookDetail

