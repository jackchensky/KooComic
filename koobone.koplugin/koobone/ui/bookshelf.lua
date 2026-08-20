local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local BookDetail = require("koobone.ui.book_detail")
local Util = require("koobone.util")

local Bookshelf = {}
Bookshelf.__index = Bookshelf

function Bookshelf:new(options)
    return setmetatable({
        library = assert(options.library, "library required"),
        storage = assert(options.storage, "storage required"),
        downloader = assert(options.downloader, "downloader required"),
        settings = assert(options.settings, "settings required"),
        on_downloads = options.on_downloads,
        on_account = options.on_account,
        on_settings = options.on_settings,
    }, self)
end

function Bookshelf:_items(books)
    local rows = {
        {
            text = "刷新书架",
            mandatory = "↻",
            callback = function() self:refresh() end,
        },
        {
            text = "下载管理",
            mandatory = "›",
            callback = function() if self.on_downloads then self.on_downloads() end end,
        },
        {
            text = "账号与设置",
            mandatory = "›",
            callback = function() if self.on_account then self.on_account() end end,
        },
    }
    for _, item in ipairs(books or {}) do
        local downloaded = self.storage:isDownloaded(item)
        local partial = self.storage:partSize(item)
        local state = downloaded and "已下载" or (partial > 0 and "未完成" or "")
        local title = item.vol_name or item.vol_series or item.file_md5 or "未命名漫画"
        local author = item.vol_author or "未知作者"
        local progress = tostring(item.last_readpage or 0) .. "/" .. tostring(item.count_page or "?")
        rows[#rows + 1] = {
            text = title .. "\n" .. author .. "　已读 " .. progress,
            mandatory = state,
            post_text = Util.friendlySize(item.file_size),
            callback = function()
                BookDetail.show{
                    item = item,
                    storage = self.storage,
                    downloader = self.downloader,
                }
            end,
        }
    end
    return rows
end

function Bookshelf:show(books)
    if self.menu then UIManager:close(self.menu) end
    local account = self.settings:account()
    local subtitle = tostring(#(books or {})) .. " 本漫画"
    if account.nick and account.nick ~= "" then subtitle = account.nick .. "　·　" .. subtitle end
    self.menu = Menu:new{
        title = "KOOBONE 书架",
        subtitle = subtitle,
        item_table = self:_items(books),
        is_borderless = true,
        title_bar_fm_style = true,
    }
    UIManager:show(self.menu)
    return self.menu
end

function Bookshelf:refresh()
    UIManager:show(InfoMessage:new{ text = "正在刷新书架……", timeout = 1 })
    UIManager:scheduleIn(0.15, function()
        local request_ok, books, err = pcall(function()
            return self.library:refresh()
        end)
        if not request_ok then
            UIManager:show(InfoMessage:new{
                text = "刷新书架时发生错误：\n" .. Util.cleanMessage(books),
            })
            return
        end
        if not books then
            UIManager:show(InfoMessage:new{ text = "无法加载书架：\n" .. tostring(err) })
            return
        end
        local render_ok, render_err = pcall(function() self:show(books) end)
        if not render_ok then
            UIManager:show(InfoMessage:new{
                text = "生成书架界面时发生错误：\n" .. Util.cleanMessage(render_err),
            })
        end
    end)
end

return Bookshelf
