package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local part_size

package.preload["socket"] = function()
    return { gettime = function() return os.time() end }
end
package.preload["datastorage"] = function()
    return {
        getFullDataDir = function() return "/tmp/koreader" end,
        getDataDir = function() return "/tmp/koreader" end,
    }
end
package.preload["ffi/util"] = function()
    return {
        dirname = function() return "/tmp" end,
        joinPath = function(left, right) return left .. "/" .. right end,
    }
end
package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(_, attribute)
            if attribute == "mode" then return "directory" end
            if part_size ~= nil then return part_size end
            return nil, "file does not exist"
        end,
        mkdir = function() return true end,
    }
end

G_reader_settings = {
    readSetting = function() return "/tmp" end,
}

local Storage = require("koobone.storage")
local settings = {
    download = function()
        return { directory = "/tmp/KOOBONE", records = {} }
    end,
}
local storage = Storage:new(settings)
local item = { vol_name = "Test book", file_type = "epub" }

-- A missing .part file returns nil plus an lfs error string on KOReader.
-- This must be treated as zero bytes, not passed to tonumber as its base.
assert(storage:partSize(item) == 0)

part_size = 12345
assert(storage:partSize(item) == 12345)

print("storage spec: OK")
