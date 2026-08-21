package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local shown = {}
local function widget()
    return {
        new = function(_, fields) return fields or {} end,
    }
end

package.preload["socket"] = function()
    return { gettime = function() return os.time() end }
end
package.preload["ui/widget/buttondialog"] = widget
package.preload["ui/widget/infomessage"] = widget
package.preload["ui/widget/menu"] = widget
package.preload["ui/widget/multiinputdialog"] = widget
package.preload["ui/uimanager"] = function()
    return {
        show = function(_, value) shown[#shown + 1] = value end,
        close = function() end,
        scheduleIn = function(_, _, callback) callback() end,
    }
end
package.preload["koobone.ui.book_detail"] = function()
    return { show = function() end }
end

local Bookshelf = require("koobone.ui.bookshelf")
local shelf = Bookshelf:new{
    library = {
        refresh = function()
            return { { vol_name = "Test book" } }
        end,
    },
    storage = {
        isDownloaded = function() return false end,
        partSize = function() error("simulated item rendering failure") end,
    },
    downloader = {},
    settings = {
        account = function() return {} end,
    },
}

-- A bad item must produce an in-app message instead of escaping the scheduled
-- callback and terminating KOReader.
local ok, err = pcall(function() shelf:refresh() end)
assert(ok == true, err)
assert(#shown == 2)
assert(shown[2].text:find("生成书架界面时发生错误", 1, true) ~= nil)
assert(shown[2].text:find("simulated item rendering failure", 1, true) ~= nil)

print("bookshelf spec: OK")
