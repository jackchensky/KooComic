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
        reading_preview = options.reading_preview,
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

local function seriesName(item)
    local explicit = Util.trim(item.vol_series or "")
    if explicit ~= "" then return explicit end
    local name = Util.trim(item.vol_name or item.file_md5 or "未命名作品")
    local stripped = name
        :gsub("%s*[-·_：:]?%s*第%s*%d+%s*卷%s*$", "")
        :gsub("%s*[-·_：:]?%s*卷%s*%d+%s*$", "")
        :gsub("%s*[-·_：:]?%s*[Vv][Oo][Ll]%.?%s*%d+%s*$", "")
    return Util.trim(stripped) ~= "" and Util.trim(stripped) or name
end

local function seriesKey(item)
    return seriesName(item):lower():gsub("%s+", " ")
end

local function volumeNumber(item)
    local value = tonumber(item.vol_index or item.volume or item.vol_no)
    if value then return value end
    return tonumber(tostring(item.vol_name or ""):match("卷%s*(%d+)")) or math.huge
end

function Bookshelf:_visibleBooks()
    local books = {}
    -- Once a work is opened, show every volume in that work even when the
    -- user entered it from a search result that matched only one volume.
    local query = self.series_key and "" or Util.trim(self.query):lower()
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
        if include and self.series_key then
            include = seriesKey(item) == self.series_key
        elseif include and self.filter_mode == "downloaded" then
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
    if self.series_key then
        table.sort(books, function(left, right)
            local a, b = volumeNumber(left), volumeNumber(right)
            if a == b then
                return tostring(left.vol_name or "") < tostring(right.vol_name or "")
            end
            return a < b
        end)
        return books
    end
    if self.filter_mode == "works" then
        local groups, order = {}, {}
        for _, item in ipairs(books) do
            local key = seriesKey(item)
            local group = groups[key]
            if not group then
                group = { key = key, name = seriesName(item), items = {} }
                groups[key] = group
                order[#order + 1] = group
            end
            group.items[#group.items + 1] = item
        end
        local works = {}
        for _, group in ipairs(order) do
            table.sort(group.items, function(left, right)
                return volumeNumber(left) < volumeNumber(right)
            end)
            local representative = group.items[1]
            local downloaded = 0
            for _, item in ipairs(group.items) do
                local value = progress(item)
                if value > 0 and value < 100 then representative = item end
                if self.storage:isDownloaded(item) then downloaded = downloaded + 1 end
            end
            works[#works + 1] = {
                _koobone_series = true,
                _series_key = group.key,
                _series_items = group.items,
                _series_count = #group.items,
                _series_downloaded = downloaded,
                _representative = representative,
                _koobone_cover_path = representative._koobone_cover_path,
                vol_name = group.name,
                vol_series = group.name,
                vol_author = representative.vol_author,
                last_readpage = representative.last_readpage,
                count_page = representative.count_page,
                file_md5 = "series:" .. group.key,
            }
        end
        books = works
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
        works = "作品",
    }
    return self.query ~= "" and "已搜索" or "搜索",
        sort_labels[self.sort_mode] or "最近加入",
        filter_labels[self.filter_mode] or "全部"
end

function Bookshelf:_quickFilters()
    local configured = self.settings:ui().quick_filters or {}
    local labels = { { "all", "全部" } }
    for _, entry in ipairs({
        { "works", "作品" },
        { "downloaded", "已下载" },
        { "not_downloaded", "未下载" },
        { "reading", "阅读中" },
        { "unread", "未阅读" },
    }) do
        if configured[entry[1]] == true then labels[#labels + 1] = entry end
    end
    return labels
end

function Bookshelf:_workCount()
    local seen, count = {}, 0
    for _, item in ipairs(self.library.items or {}) do
        local key = seriesKey(item)
        if not seen[key] then
            seen[key] = true
            count = count + 1
        end
    end
    return count
end

function Bookshelf:_prepareCachedCovers(books)
    if not self.cover_cache then return end
    for _, item in ipairs(books or {}) do
        item._koobone_cover_path = self.cover_cache:localPath(item)
    end
end

function Bookshelf:_currentBook()
    local first
    for _, item in ipairs(self.library.items or {}) do
        first = first or item
        local value = progress(item)
        if value > 0 and value < 100 and self.storage:isDownloaded(item) then
            return item, "reading"
        end
    end
    for _, item in ipairs(self.library.items or {}) do
        local value = progress(item)
        if value > 0 and value < 100 then return item, "reading" end
    end
    if first then return first, "start" end
    return nil, "empty"
end

function Bookshelf:_prefetchCovers(items)
    if not self.cover_cache or type(items) ~= "table" then return end
    self.cover_generation = self.cover_generation + 1
    local generation = self.cover_generation
    local pending = {}
    for _, item in ipairs(items) do
        local source = item._representative or item
        item._koobone_cover_path = item._koobone_cover_path or source._koobone_cover_path
            or self.cover_cache:localPath(source)
        if not item._koobone_cover_path and self.cover_cache:url(source) then
            pending[#pending + 1] = item
        end
    end
    local index = 0
    local changed = 0
    local function fetchNext()
        if generation ~= self.cover_generation or not self.grid_view or self.grid_view.closed then return end
        index = index + 1
        local item = pending[index]
        if not item then return end
        local source = item._representative or item
        local ok, path = pcall(self.cover_cache.fetch, self.cover_cache, source)
        if ok and path then
            item._koobone_cover_path = path
            source._koobone_cover_path = path
            changed = changed + 1
        end
        if changed > 0 and (changed >= 3 or index == #pending) then
            self.grid_view:refreshCovers()
            changed = 0
        end
        UIManager:scheduleIn(0.05, fetchNext)
    end
    if #pending > 0 then UIManager:scheduleIn(0.05, fetchNext) end
end

function Bookshelf:_gridOptions(books)
    local search_label, sort_label, filter_label = self:_labels()
    local current_book, current_mode = self:_currentBook()
    if current_book and self.reading_preview then
        current_book._koobone_preview_left, current_book._koobone_preview_right =
            self.reading_preview:paths(current_book)
    end
    local breadcrumbs
    local function showAllBooks()
        self.series_key, self.series_name = nil, nil
        self.filter_mode = "all"
        self:_render()
    end
    local function showAllWorks()
        self.series_key, self.series_name = nil, nil
        self.filter_mode = "works"
        self:_render()
    end
    if self.series_key then
        breadcrumbs = {
            { text = "全部漫画", callback = showAllBooks },
            { text = "全部作品", callback = showAllWorks },
            { text = tostring(self.series_name or "作品") .. " " .. tostring(#books) .. "本" },
        }
    elseif self.filter_mode == "works" then
        breadcrumbs = {
            { text = "全部漫画", callback = showAllBooks },
            { text = "全部作品 " .. tostring(#books) .. "部" },
        }
    else
        breadcrumbs = {
            { text = "全部漫画 " .. tostring(#books) .. "本" },
        }
    end
    return {
        books = books,
        storage = self.storage,
        account = self.settings:account(),
        ui = self.settings:ui(),
        total_count = #books,
        breadcrumbs = breadcrumbs,
        section_title = self.series_key and (self.series_name or "作品")
            or (self.filter_mode == "works" and "全部作品" or "全部漫画"),
        quick_filters = self:_quickFilters(),
        current_book = current_book or false,
        current_mode = current_mode,
        filter_mode = self.filter_mode,
        search_label = search_label,
        sort_label = sort_label,
        filter_label = filter_label,
        on_select = function(item)
            if item._koobone_series then
                self.series_key = item._series_key
                self.series_name = item.vol_series or item.vol_name
                self:_render()
                return
            end
            BookDetail.show{
                item = item,
                storage = self.storage,
                downloader = self.downloader,
                settings = self.settings,
            }
        end,
        on_continue = function(item)
            if self.storage:isDownloaded(item) then
                self.downloader:open(self.storage:itemPath(item))
            else
                BookDetail.show{
                    item = item, storage = self.storage,
                    downloader = self.downloader, settings = self.settings,
                }
            end
        end,
        on_refresh = function() self:refresh() end,
        on_search = function() self:showSearch() end,
        on_sort = function() self:showSort() end,
        on_filter = function() self:showFilter() end,
        on_filter_customize = function() self:showQuickFilterSettings() end,
        on_quick_filter = function(mode)
            self.series_key, self.series_name = nil, nil
            self.filter_mode = mode
            self:_render()
        end,
        on_downloads = self.on_downloads,
        on_account = self.on_account,
        on_settings = self.on_settings,
        on_page_changed = function(items)
            local current = self:_currentBook()
            local pending = {}
            if current then pending[#pending + 1] = current end
            for _, item in ipairs(items) do
                if item ~= current then pending[#pending + 1] = item end
            end
            self:_prefetchCovers(pending)
        end,
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
    if self.series_key then
        table.insert(rows, 1, {
            text = "返回作品列表",
            mandatory = "‹",
            callback = function()
                self.series_key, self.series_name = nil, nil
                self:_render()
            end,
        })
    end
    for _, item in ipairs(books or {}) do
        local downloaded = not item._koobone_series and self.storage:isDownloaded(item)
        local partial = not item._koobone_series and self.storage:partSize(item) or 0
        local state = downloaded and "已下载" or (partial > 0 and "未完成" or "")
        local title = item.vol_name or item.vol_series or item.file_md5 or "未命名漫画"
        local author = item.vol_author or "未知作者"
        local progress = tostring(item.last_readpage or 0) .. "/" .. tostring(item.count_page or "?")
        if item._koobone_series then
            state = "共 " .. tostring(item._series_count or 0) .. " 卷"
            author = "已下载 " .. tostring(item._series_downloaded or 0) .. "/"
                .. tostring(item._series_count or 0)
            progress = ""
        end
        rows[#rows + 1] = {
            text = title .. "\n" .. author .. (progress ~= "" and ("　已读 " .. progress) or ""),
            mandatory = state,
            post_text = item._koobone_series and "›" or Util.friendlySize(item.file_size),
            callback = function()
                if item._koobone_series then
                    self.series_key = item._series_key
                    self.series_name = item.vol_series or item.vol_name
                    self:_render()
                    return
                end
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
        title = "KooComic·可漫",
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
        self.series_key, self.series_name = nil, nil
        self.filter_mode = mode
        UIManager:close(dialog)
        self:_render()
    end
    dialog = ButtonDialog:new{
        title = "筛选书架",
        buttons = {
            { { text = "全部", callback = function() choose("all") end } },
            { { text = "作品", callback = function() choose("works") end } },
            { { text = "已下载", callback = function() choose("downloaded") end } },
            { { text = "未下载", callback = function() choose("not_downloaded") end } },
            { { text = "阅读中", callback = function() choose("reading") end } },
            { { text = "未阅读", callback = function() choose("unread") end } },
            { { text = "取消", callback = function() UIManager:close(dialog) end } },
        },
    }
    UIManager:show(dialog)
end

function Bookshelf:showQuickFilterSettings()
    local ui = self.settings:ui()
    local selected = {}
    for key, value in pairs(ui.quick_filters or {}) do selected[key] = value == true end
    local entries = {
        { "works", "作品" },
        { "downloaded", "已下载" },
        { "not_downloaded", "未下载" },
        { "reading", "阅读中" },
        { "unread", "未阅读" },
    }
    local dialog
    local function showDialog()
        local buttons = {
            { { text = "☑ 全部（固定）", enabled = false } },
        }
        for _, entry in ipairs(entries) do
            local key, label = entry[1], entry[2]
            buttons[#buttons + 1] = { {
                text = (selected[key] and "☑ " or "☐ ") .. label,
                callback = function()
                    selected[key] = not selected[key]
                    UIManager:close(dialog)
                    showDialog()
                end,
            } }
        end
        buttons[#buttons + 1] = {
            { text = "取消", callback = function() UIManager:close(dialog) end },
            { text = "保存", callback = function()
                ui.quick_filters = selected
                self.settings:flush()
                if self.filter_mode ~= "all" and selected[self.filter_mode] ~= true then
                    self.filter_mode = "all"
                    self.series_key, self.series_name = nil, nil
                end
                UIManager:close(dialog)
                self:_render()
            end },
        }
        dialog = ButtonDialog:new{
            title = "自定义快捷分类\n\n长按“分类筛选”可再次修改。",
            buttons = buttons,
        }
        UIManager:show(dialog)
    end
    showDialog()
end

function Bookshelf:showMore()
    local dialog
    dialog = ButtonDialog:new{
        title = "KooComic·可漫",
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
