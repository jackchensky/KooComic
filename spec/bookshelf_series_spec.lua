package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local function widget()
    return { new = function(_, fields) return fields or {} end }
end

package.preload["socket"] = function()
    return { gettime = function() return os.time() end }
end

package.preload["ui/widget/buttondialog"] = widget
package.preload["ui/widget/infomessage"] = widget
package.preload["ui/widget/menu"] = widget
package.preload["ui/widget/multiinputdialog"] = widget
package.preload["ui/uimanager"] = function()
    return { show = function() end, close = function() end, scheduleIn = function() end }
end
package.preload["koobone.ui.book_detail"] = function()
    return { show = function() end }
end
package.preload["koobone.ui.bookshelf_grid"] = function()
    return { show = function(options) return { options = options, closed = false } end }
end

local items = {}
for index = 1, 3 do
    items[#items + 1] = {
        vol_name = "灌篮高手 卷 " .. tostring(index),
        vol_series = "灌篮高手",
        vol_index = tostring(index),
        vol_author = "井上雄彦",
        file_md5 = "slam-" .. tostring(index),
        count_page = 100,
        last_readpage = index == 2 and 30 or 0,
    }
end
for index = 1, 9 do
    items[#items + 1] = {
        vol_name = "全职猎人 卷 " .. tostring(index),
        vol_series = "全职猎人",
        vol_index = tostring(index),
        vol_author = "富坚义博",
        file_md5 = "hunter-" .. tostring(index),
        count_page = 120,
        last_readpage = 0,
    }
end

local ui = {
    quick_filters = {
        works = true,
        downloaded = true,
        not_downloaded = true,
        reading = false,
        unread = false,
    },
}
local settings = {
    account = function() return {} end,
    ui = function() return ui end,
    flush = function() end,
}
local storage = {
    isDownloaded = function(_, item)
        return item.file_md5 == "slam-1" or item.file_md5 == "hunter-1"
    end,
    partSize = function() return 0 end,
}

local Bookshelf = require("koobone.ui.bookshelf")
local shelf = Bookshelf:new{
    library = { items = items },
    storage = storage,
    downloader = {},
    settings = settings,
}

local quick = shelf:_quickFilters()
assert(#quick == 4)
assert(quick[1][1] == "all" and quick[2][1] == "works")

shelf.filter_mode = "works"
local works = shelf:_visibleBooks()
assert(#works == 2)
assert(works[1]._koobone_series == true)
assert(works[1]._series_count == 3)
assert(works[1]._series_downloaded == 1)
assert(works[1]._representative.file_md5 == "slam-2")
assert(works[2]._series_count == 9)
local work_options = shelf:_gridOptions(works)
assert(#work_options.breadcrumbs == 2)
assert(work_options.breadcrumbs[1].text == "全部漫画")
assert(work_options.breadcrumbs[2].text == "全部作品 2部")

shelf.series_key = works[1]._series_key
shelf.series_name = works[1].vol_series
local volumes = shelf:_visibleBooks()
assert(#volumes == 3)
assert(volumes[1].vol_index == "1")
assert(volumes[2].vol_index == "2")
assert(volumes[3].vol_index == "3")
local series_options = shelf:_gridOptions(volumes)
assert(#series_options.breadcrumbs == 3)
assert(series_options.breadcrumbs[2].text == "全部作品")
assert(series_options.breadcrumbs[3].text == "灌篮高手 3本")

ui.quick_filters.works = false
ui.quick_filters.reading = true
quick = shelf:_quickFilters()
assert(#quick == 4)
assert(quick[2][1] == "downloaded")
assert(quick[4][1] == "reading")

print("bookshelf series spec: OK")
