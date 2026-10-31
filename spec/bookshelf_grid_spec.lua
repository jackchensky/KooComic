package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local function class()
    local object = {}
    function object:extend(fields)
        fields = fields or {}
        setmetatable(fields, { __index = self })
        return fields
    end
    function object:new(fields)
        fields = fields or {}
        setmetatable(fields, { __index = self })
        if fields.init then fields:init() end
        return fields
    end
    function object:getSize()
        if self.text and not self.width and not self.height then
            local size = tonumber(self.face and self.face.size) or 10
            local width = #tostring(self.text) * size * 0.55
            return { w = math.floor(math.min(width, self.max_width or width)), h = math.ceil(size * 1.32) }
        end
        return self.dimen or { w = self.width or 1, h = self.height or 1 }
    end
    function object:free() end
    function object:paintTo() end
    return object
end

local Widget = class()
local widget_modules = {
    "ui/widget/container/centercontainer",
    "ui/widget/container/framecontainer",
    "ui/widget/horizontalgroup",
    "ui/widget/horizontalspan",
    "ui/widget/iconwidget",
    "ui/widget/imagewidget",
    "ui/widget/overlapgroup",
    "ui/widget/textboxwidget",
    "ui/widget/textwidget",
    "ui/widget/verticalgroup",
    "ui/widget/verticalspan",
    "ui/widget/widget",
    "ui/widget/container/widgetcontainer",
}
for _, name in ipairs(widget_modules) do
    package.preload[name] = function() return Widget end
end
package.preload["ui/widget/container/inputcontainer"] = function() return Widget end
package.preload["ffi/blitbuffer"] = function()
    return {
        COLOR_WHITE = 255,
        COLOR_BLACK = 0,
        COLOR_DARK_GRAY = 64,
        COLOR_GRAY = 128,
        COLOR_GRAY_B = 176,
        COLOR_GRAY_C = 192,
        COLOR_GRAY_E = 224,
    }
end
package.preload["device"] = function()
    return {
        hasKeys = function() return false end,
        input = { group = {} },
        screen = {
            getWidth = function() return 800 end,
            getHeight = function() return 1200 end,
            scaleBySize = function(_, value) return value end,
        },
    }
end
package.preload["ui/font"] = function()
    return { getFace = function(_, _, size) return { size = size or 10 } end }
end
package.preload["ui/geometry"] = function()
    return {
        new = function(_, value)
            value.copy = function(self)
                local result = {}
                for key, content in pairs(self) do result[key] = content end
                return result
            end
            return value
        end,
    }
end
package.preload["ui/gesturerange"] = function()
    return { new = function(_, value) return value end }
end

local shown
package.preload["ui/uimanager"] = function()
    return {
        show = function(_, widget)
            shown = widget
            if widget.onShow then widget:onShow() end
        end,
        close = function(_, widget)
            if widget.onCloseWidget then widget:onCloseWidget() end
        end,
        setDirty = function() end,
    }
end

local books = {}
for index = 1, 28 do
    books[index] = {
        vol_name = "Book " .. tostring(index),
        vol_author = "Author",
        count_page = 100,
        last_readpage = index,
    }
end
local storage = {
    isDownloaded = function(_, item) return item.vol_name == "Book 2" end,
    partSize = function() return 0 end,
}
local page_events = {}
local refresh_count = 0
local Grid = require("koobone.ui.bookshelf_grid")
local view = Grid.show{
    books = books,
    storage = storage,
    current_book = books[1],
    current_mode = "reading",
    account = { nick = "Tester" },
    on_refresh = function() refresh_count = refresh_count + 1 end,
    on_page_changed = function(items, page, pages)
        page_events[#page_events + 1] = { count = #items, page = page, pages = pages }
    end,
}

assert(shown == view)
assert(view.perpage == 12)
assert(view.pages == 3)
assert(#view:visibleItems() == 12)
assert(page_events[1].page == 1 and page_events[1].pages == 3)
assert(view.layout.columns == 4 and view.layout.rows == 3)
assert(view.layout.hero_right == view.layout.last_cover_right)
assert(view.layout.hero_book_left == view.layout.first_cover_left)
assert(view.layout.hero_button_bottom <= view.layout.hero_meta_top)
assert(view.layout.hero_button_right == view.layout.last_cover_right)
assert(view.layout.hero_track_right == view.layout.last_cover_right)
assert(view.layout.hero_track_bottom < view.layout.hero_shelf_y)
assert(view.layout.hero_shelf_y - view.layout.hero_track_bottom >= 9)
assert(view.layout.hero_track_gap >= 4)
assert(view.layout.hero_detail_line_count >= 1 and view.layout.hero_detail_line_count <= 2)
assert(view.layout.hero_content_top - view.layout.hero_y >= 9)
assert(view.layout.hero_section_gap >= 4)
assert(view.layout.toolbar_underline_y + 2 < view.layout.grid_y)
assert(view.layout.toolbar_bottom_gap > 0)
assert(view.layout.card_tag_h >= 15)
assert(view.layout.card_tag_shadow_offset >= 2)
assert(view.layout.shelf_shadow_h >= 3)
assert(view.layout.quick_filter_count == 4)
assert(view.layout.breadcrumb_count == 1)
local large_tag_h = view.layout.card_tag_h

view:update{
    books = {{
        vol_name = "A deliberately long title for responsive layout",
        vol_author = "A deliberately long author name that must be truncated inside the paper tag",
        vol_index = "123", count_page = 900, last_readpage = 450,
    }},
    current_book = books[1],
    ui = { portrait_columns = 4, portrait_rows = 3, text_size = "extra_large" },
}
assert(view.layout.card_tag_h >= large_tag_h)
assert(view.layout.hero_button_bottom <= view.layout.hero_meta_top)
assert(view.layout.toolbar_underline_y + 2 < view.layout.grid_y)

local starter = {
    vol_name = "A first book", vol_author = "Starter Author",
    vol_index = "1", count_page = 100, last_readpage = 0,
}
view:update{ books = { starter }, current_book = starter, current_mode = "start" }
assert(view.layout.hero_mode == "start")
assert(view.layout.hero_track_right == nil)
assert(view.layout.hero_button_right == view.layout.last_cover_right)
assert(view.layout.hero_content_bottom < view.layout.hero_shelf_y)

view:update{ quick_filters = { { "all", "全部" }, { "works", "作品" } } }
assert(view.layout.quick_filter_count == 2)

view:update{ breadcrumbs = {
    { text = "全部漫画", callback = function() end },
    { text = "全部作品 2部" },
} }
assert(view.layout.breadcrumb_count == 2)
view:update{ breadcrumbs = {
    { text = "全部漫画", callback = function() end },
    { text = "全部作品", callback = function() end },
    { text = "灌篮高手 3本" },
} }
assert(view.layout.breadcrumb_count == 3)
view:update{ breadcrumbs = { { text = "全部漫画 28本" } } }
assert(view.layout.breadcrumb_count == 1)

view:update{ books = {}, current_book = false, current_mode = "empty" }
assert(view.layout.hero_mode == "empty")
assert(view.layout.hero_track_right == nil)
assert(view.layout.hero_button_right == view.layout.last_cover_right)

view:update{ books = books, current_book = books[1], current_mode = "reading",
    ui = { portrait_columns = 4, portrait_rows = 3, text_size = "large" } }
assert(view.layout.hero_mode == "reading")
assert(view.layout.hero_track_right == view.layout.last_cover_right)

local screen = require("device").screen
for _, dimensions in ipairs({ {600, 800}, {758, 1024}, {1072, 1448}, {1264, 1680}, {1024, 758} }) do
    screen.getWidth = function() return dimensions[1] end
    screen.getHeight = function() return dimensions[2] end
    view:onScreenResize()
    assert(view.layout.card_w > 0 and view.layout.card_h > 0)
    assert(view.layout.card_shelf_y > 0 and view.layout.card_tag_h > 0)
    assert(view.layout.toolbar_underline_y + 2 < view.layout.grid_y)
    assert(view.layout.hero_button_bottom <= view.layout.hero_meta_top)
    assert(view.layout.hero_track_right == view.layout.last_cover_right)
    assert(view.layout.hero_track_bottom < view.layout.hero_shelf_y)
end

screen.getWidth = function() return 800 end
screen.getHeight = function() return 1200 end
view:update{ books = books, current_book = books[1],
    ui = { portrait_columns = 2, portrait_rows = 2, text_size = "large" } }
assert(view.perpage == 4)
assert(view.pages == 7)
assert(#view:visibleItems() == 4)

view:update{ ui = { portrait_columns = 3, portrait_rows = 2, text_size = "large" } }
assert(view.perpage == 6)
assert(view.pages == 5)

view:_changePage(5)
assert(view.page == 5)
assert(#view:visibleItems() == 4)
assert(page_events[#page_events].page == 5)

view:update{ books = { books[1], books[2] } }
assert(view.page == 1)
assert(view.pages == 1)
assert(#view:visibleItems() == 2)

local icon_file = io.open("koocomic.koplugin/icons/book-open.svg", "rb")
assert(icon_file ~= nil)
icon_file:close()
assert(view.layout.hero_right == view.layout.last_cover_right)
view:_close()
assert(view.closed == true)

print("bookshelf grid spec: OK")
