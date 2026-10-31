package.path = "./koocomic.koplugin/?.lua;" .. package.path

local files = { ["/tmp/book.epub"] = true }
local scheduled
local current_ui

package.preload["datastorage"] = function()
    return { getDataDir = function() return "/tmp" end }
end
package.preload["ffi/util"] = function()
    return { joinPath = function(left, right) return left .. "/" .. right end }
end
package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(path, attribute)
            if path == "/tmp/cache/koocomic-reading-previews" and attribute == "mode" then
                return "directory"
            end
            if files[path] and attribute == "mode" then return "file" end
        end,
        mkdir = function() return true end,
    }
end
package.preload["ui/uimanager"] = function()
    return {
        scheduleIn = function(_, _, callback) scheduled = callback end,
        unschedule = function(_, callback) if scheduled == callback then scheduled = nil end end,
        getTopmostVisibleWidget = function() return current_ui end,
    }
end

local screen_buffer = { getType = function() return 1 end }
package.preload["device"] = function()
    return {
        screen = {
            bb = screen_buffer,
            getWidth = function() return 600 end,
            getHeight = function() return 800 end,
        },
    }
end
package.preload["ffi/blitbuffer"] = function()
    return {
        new = function()
            return {
                blitFrom = function() end,
                free = function() end,
            }
        end,
    }
end
package.preload["ffi/renderimage"] = function()
    return {
        scaleBlitBuffer = function()
            return {
                writePNG = function(_, path) files[path] = true; return true end,
                free = function() end,
            }
        end,
    }
end

local original_remove, original_rename = os.remove, os.rename
os.remove = function(path)
    local existed = files[path]
    files[path] = nil
    return existed and true or nil
end
os.rename = function(from, to)
    if not files[from] then return nil end
    files[from], files[to] = nil, true
    return true
end

local records = { test_key = { path = "/tmp/book.epub" } }
local storage = {
    settings = { download = function() return { records = records } end },
    itemKey = function(_, item) return item.key end,
}
local ReadingPreview = require("koobone.reading_preview")
local preview = ReadingPreview:new(storage)
local ui = { name = "ReaderUI", document = { file = "/tmp/book.epub" } }
current_ui = ui

assert(preview:keyForDocument("/tmp/book.epub") == "test_key")
assert(preview:keyForDocument("/tmp/other.epub") == nil)
local left, right = preview:paths{ key = "test_key" }
assert(left == nil and right == nil)

preview:queue(ui, 7)
assert(type(scheduled) == "function")
scheduled(); scheduled = nil
left, right = preview:paths{ key = "test_key" }
assert(left == nil and right and files[right])

preview:queue(ui, 8)
assert(type(scheduled) == "function")
scheduled(); scheduled = nil
local next_left, next_right = preview:paths{ key = "test_key" }
assert(next_left and next_right and files[next_left] and files[next_right])
assert(next_left ~= next_right)

-- The same page token is not encoded twice, and a non-KooComic document is
-- ignored without touching the reader or creating cache files.
preview:queue(ui, 8)
assert(scheduled == nil)
ui.document.file = "/tmp/other.epub"
preview:queue(ui, 9)
assert(scheduled == nil)

preview:clear("test_key")
left, right = preview:paths{ key = "test_key" }
assert(left == nil and right == nil)

os.remove, os.rename = original_remove, original_rename
print("reading preview spec: local two-page rotation, debounce and cleanup OK")
