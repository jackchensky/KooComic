local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")
local BookDetail = require("koobone.ui.book_detail")
local Util = require("koobone.util")

local grid_available, BookshelfGrid = pcall(require, "koobone.ui.bookshelf_grid")

local Bookshelf = {}
Bookshelf.__index = Bookshelf

function Bookshelf:new(options)
    return setmetatable({
        library = assert(options.library, "library required"),
        storage = assert(options.storage, "storage required"),
        downloader = assert(options.downloader, "downloader required"),
        settings = assert(options.settings, "settings required"),
        cover_cache = options.cover_cache,
        on_downloads = options.on_downloads,
        on_account = options.on_account,
        on_settings = options.on_settings,
        query = "",
        sort_mode = "recent",
        filter_mode = "all",
        cover_generation = 0,
        grid_view = nil,
    }, self)
end

local function progress(item)
    local current = tonumber(item.last_readpage) or 0
    local total = tonumber(item.count_page) or 0
    if total <= 0 then return 0 end
    return math.max(0, math.min(100, current / total * 100))
end

function Bookshelf:_visibleBooks()
    local books = {}
    local query = Util.trim(self.query):lower()
    for _, item in ipairs(self.library.items or {}) do
        local include = true
        if query ~= "" then
            local haystack = table.concat({
                tostring(item.vol_name or ""),
                tostring(item.vol_series or ""),
                tostring(item.vol_author or ""),
            }, " "):lower()
            include = haystack:find(query, 1, true) ~= nil
        end
        if include and self.filter_mode == "downloaded" then
            include = self.storage:isDownloaded(item)
        elseif include and self.filter_mode == "not_downloaded" then
            include = not self.storage:isDownloaded(item)
        elseif include and self.filter_mode == "reading" then
            local value = progress(item)
            include = value > 0 and value < 100
        elseif include and self.filter_mode == "unread" then
            include = progress(item) <= 0
        end
        if include then books[#books + 1] = item end
    end
    if self.sort_mode == "title" then
        table.sort(books, function(left, right)
            local a = tostring(left.vol_name or left.vol_series or "")
            local b = tostring(right.vol_name or right.vol_series or "")
            return a < b
        end)
    elseif self.sort_mode == "progress" then
        table.sort(books, function(left, right) return progress(left) > progress(right) end)
    end
    return books
end

function Bookshelf:_labels()
    local sort_labels = {
        recent = "最近加入",
        title = "标题排序",
        progress = "阅读进度",
    }
    local filter_labels = {
        all = "全部",
        downloaded = "已下载",
        not_downloaded = "未下载",
        reading = "阅读中",
        unread = "未阅读",
    }
    return self.query ~= "" and "已搜索" or "搜索",
        sort_labels[self.sort_mode] or "最近加入",
        filter_labels[self.filter_mode] or "全部"
end

function Bookshelf:_prepareCachedCovers(books)
    if not self.cover_cache then return end
    for _, item in ipairs(books or {}) do
        item._koobone_cover_path = self.cover_cache:localPath(item)
    end
end

function Bookshelf:_prefetchCovers(items)
    if not self.cover_cache or type(items) ~= "table" then return end
    self.cover_generation = self.cover_generation + 1
    local generation = self.cover_generation
    local pending = {}
    for _, item in ipairs(items) do
        if not item._koobone_cover_path and self.cover_cache:url(item) then
            pending[#pending + 1] = item
        end
    end
    local index = 0
    local function fetchNext()
        if generation ~= self.cover_generation or not self.grid_view or self.grid_view.closed then return end
        index = index + 1
        local item = pending[index]
        if not item then return end
        local ok, path = pcall(self.cover_cache.fetch, self.cover_cache, item)
        if ok and path then
            item._koobone_cover_path = path
            self.grid_view:refreshCovers()
        end
        UIManager:scheduleIn(0.05, fetchNext)
    end
    if #pending > 0 then UIManager:scheduleIn(0.05, fetchNext) end
end

function Bookshelf:_gridOptions(books)
    local search_label, sort_label, filter_label = self:_labels()
    return {
        books = books,
        storage = self.storage,
        account = self.settings:account(),
        ui = self.settings:ui(),
        search_label = search_label,
        sort_label = sort_label,
        filter_label = filter_label,
        on_select = function(item)
            BookDetail.show{
                item = item,
                storage = self.storage,
                downloader = self.downloader,
                settings = self.settings,
            }
        end,
        on_refresh = function() self:refresh() end,
        on_search = function() self:showSearch() end,
        on_sort = function() self:showSort() end,
        on_filter = function() self:showFilter() end,
        on_more = function() self:showMore() end,
        on_downloads = self.on_downloads,
        on_account = self.on_account,
        on_settings = self.on_settings,
        on_page_changed = function(items) self:_prefetchCovers(items) end,
    }
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
                    settings = self.settings,
                }
            end,
        }
    end
    return rows
end

function Bookshelf:_showListFallback(books)
    if self.menu then UIManager:close(self.menu) end
    local account = self.settings:account()
    local subtitle = tostring(#(books or {})) .. " 本漫画"
    if account.nick and account.nick ~= "" then subtitle = account.nick .. "　·　" .. subtitle end
    self.menu = Menu:new{
        title = "koo漫画",
        subtitle = subtitle,
        item_table = self:_items(books),
        is_borderless = true,
        title_bar_fm_style = true,
    }
    UIManager:show(self.menu)
    return self.menu
end

function Bookshelf:show(books)
    self.library.items = books or self.library.items or {}
    self:_prepareCachedCovers(self.library.items)
    local visible = self:_visibleBooks()
    if not grid_available then return self:_showListFallback(visible) end

    local options = self:_gridOptions(visible)
    if self.grid_view and not self.grid_view.closed then
        self.grid_view:update(options)
        self.menu = self.grid_view
        return self.grid_view
    end

    if self.menu then UIManager:close(self.menu) end
    local view
    options.on_close = function()
        if self.grid_view == view then
            self.grid_view = nil
            self.menu = nil
            self.cover_generation = self.cover_generation + 1
        end
    end
    local ok, result = pcall(BookshelfGrid.show, options)
    if not ok or not result then
        grid_available = false
        UIManager:show(InfoMessage:new{
            text = "当前 KOReader 无法加载网格书架，已切换到兼容列表：\n" ..
                Util.cleanMessage(result),
        })
        return self:_showListFallback(visible)
    end
    view = result
    self.grid_view = view
    self.menu = view
    return view
end

function Bookshelf:_render()
    return self:show(self.library.items)
end

function Bookshelf:showSearch()
    local dialog
    dialog = MultiInputDialog:new{
        title = "搜索书架",
        fields = {
            { text = self.query, hint = "书名或作者" },
        },
        buttons = {
            {
                {
                    text = "清除",
                    callback = function()
                        self.query = ""
                        UIManager:close(dialog)
                        self:_render()
                    end,
                },
                {
                    text = "取消",
                    callback = function() UIManager:close(dialog) end,
                },
                {
                    text = "搜索",
                    is_enter_default = true,
                    callback = function()
                        self.query = Util.trim(dialog:getFields()[1])
                        UIManager:close(dialog)
                        self:_render()
                    end,
                },
            },
        },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Bookshelf:showSort()
    local dialog
    local function choose(mode)
        self.sort_mode = mode
        UIManager:close(dialog)
        self:_render()
    end
    dialog = ButtonDialog:new{
        title = "书架排序",
        buttons = {
            { { text = "最近加入", callback = function() choose("recent") end } },
            { { text = "标题排序", callback = function() choose("title") end } },
            { { text = "阅读进度", callback = function() choose("progress") end } },
            { { text = "取消", callback = function() UIManager:close(dialog) end } },
        },
    }
    UIManager:show(dialog)
end

function Bookshelf:showFilter()
    local dialog
    local function choose(mode)
        self.filter_mode = mode
        UIManager:close(dialog)
        self:_render()
    end
    dialog = ButtonDialog:new{
        title = "筛选书架",
        buttons = {
            { { text = "全部", callback = function() choose("all") end } },
            { { text = "已下载", callback = function() choose("downloaded") end } },
            { { text = "未下载", callback = function() choose("not_downloaded") end } },
            { { text = "阅读中", callback = function() choose("reading") end } },
            { { text = "未阅读", callback = function() choose("unread") end } },
            { { text = "取消", callback = function() UIManager:close(dialog) end } },
        },
    }
    UIManager:show(dialog)
end

function Bookshelf:showMore()
    local dialog
    dialog = ButtonDialog:new{
        title = "koo漫画",
        buttons = {
            {
                {
                    text = "刷新书架",
                    callback = function() UIManager:close(dialog); self:refresh() end,
                },
            },
            {
                {
                    text = "下载管理",
                    callback = function()
                        UIManager:close(dialog)
                        if self.on_downloads then self.on_downloads() end
                    end,
                },
            },
            {
                {
                    text = "账号",
                    callback = function()
                        UIManager:close(dialog)
                        if self.on_account then self.on_account() end
                    end,
                },
                {
                    text = "设置",
                    callback = function()
                        UIManager:close(dialog)
                        if self.on_settings then self.on_settings() end
                    end,
                },
            },
            { { text = "关闭", callback = function() UIManager:close(dialog) end } },
        },
    }
    UIManager:show(dialog)
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
