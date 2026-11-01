package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local Library = require("koobone.library")

local function volume(index)
    return { file_md5 = "book-" .. tostring(index), vol_name = "漫画 " .. tostring(index) }
end

local function volumes(first, last)
    local result = {}
    for index = first, last do result[#result + 1] = volume(index) end
    return result
end

local storage = {
    itemKey = function(_, item) return item.file_md5 end,
}

-- Follow KOOBONE's official `p` pagination until totalpage, while keeping the
-- server order and returning one combined shelf to the existing UI.
local calls = {}
local pages = {
    { nowpage = "1", totalpage = "3", total = "100", data = volumes(1, 49) },
    { nowpage = "2", totalpage = "3", total = "100", data = volumes(50, 98) },
    { nowpage = "3", totalpage = "3", total = "100", data = volumes(99, 100) },
}
local api = {
    library = function(_, limit, page)
        calls[#calls + 1] = { limit = limit, page = page }
        return pages[page]
    end,
}
local library = Library:new(api, storage)
local items, response = assert(library:refresh())
assert(#items == 100 and #library.items == 100)
assert(items[1].file_md5 == "book-1" and items[100].file_md5 == "book-100")
assert(#calls == 3 and calls[1].limit == 49 and calls[3].page == 3)
assert(response.total == "100" and response.totalpage == 3 and response.nowpage == 3)

-- Older/alternate responses without totalpage still finish safely when the
-- final page is shorter than the official 49-item batch size.
calls = {}
local fallback_pages = {
    { data = volumes(1, 49) },
    { data = volumes(50, 52) },
}
api = {
    library = function(_, limit, page)
        calls[#calls + 1] = { limit = limit, page = page }
        return fallback_pages[page]
    end,
}
library = Library:new(api, storage)
items, response = assert(library:refresh())
assert(#items == 52 and #calls == 2)
assert(response.total == 52 and response.totalpage == 2)

-- Do not replace a previously usable shelf with a partial result when a later
-- page fails; the user can retry without losing the current in-memory list.
api = {
    library = function(_, _, page)
        if page == 1 then return { nowpage = 1, totalpage = 2, data = volumes(1, 49) } end
        return nil, "temporary network failure"
    end,
}
library = Library:new(api, storage)
library.items = { volume(999) }
local failed, err = library:refresh()
assert(failed == nil and err == "temporary network failure")
assert(#library.items == 1 and library.items[1].file_md5 == "book-999")

-- A server that ignores `p` must fail instead of looping forever or showing a
-- misleading partial shelf.
api = {
    library = function(_, _, page)
        return { nowpage = page, totalpage = 3, data = volumes(1, 49) }
    end,
}
library = Library:new(api, storage)
failed, err = library:refresh()
assert(failed == nil and err:find("重复", 1, true))

print("library pagination spec: OK")
