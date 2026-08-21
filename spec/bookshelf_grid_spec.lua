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
    return { getFace = function() return {} end }
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
local Grid = require("koobone.ui.bookshelf_grid")
local view = Grid.show{
    books = books,
    storage = storage,
    account = { nick = "Tester" },
    on_page_changed = function(items, page, pages)
        page_events[#page_events + 1] = { count = #items, page = page, pages = pages }
    end,
}

assert(shown == view)
assert(view.perpage == 6)
assert(view.pages == 5)
assert(#view:visibleItems() == 6)
assert(page_events[1].page == 1 and page_events[1].pages == 5)

view:update{ ui = { portrait_columns = 2, portrait_rows = 2, text_size = "large" } }
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

print("bookshelf grid spec: OK")
