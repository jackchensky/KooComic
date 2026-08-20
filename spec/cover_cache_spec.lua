package.path = "./koobone.koplugin/?.lua;./koobone.koplugin/?/init.lua;" .. package.path

package.preload["socket"] = function()
    return { gettime = function() return os.time() end }
end
package.preload["datastorage"] = function()
    return { getDataDir = function() return "/tmp/koreader" end }
end
package.preload["ffi/util"] = function()
    return { joinPath = function(left, right) return left .. "/" .. right end }
end
package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function(path, attribute)
            if attribute == "mode" and path:match("koobone%-covers$") then return "directory" end
            if attribute == "size" then return nil, "file does not exist" end
            return nil
        end,
        mkdir = function() return true end,
    }
end

local CoverCache = require("koobone.cover_cache")
local cache = CoverCache:new{
    BASE = "https://bookof.hk",
    download = function() return nil, "not used" end,
}

assert(cache:url{ cover_small = "/covers/a.jpg" } == "https://bookof.hk/covers/a.jpg")
assert(cache:url{ cover_url = "//img.example.test/a.png" } == "https://img.example.test/a.png")
assert(cache:url{ cover = "http://bookof.hk/a.webp" } == "https://bookof.hk/a.webp")
assert(cache:url{} == nil)

local first = cache:path{ file_md5 = "stable-id", cover_url = "/covers/a.jpg" }
local second = cache:path{ file_md5 = "stable-id", cover_url = "/changed/a.jpg" }
assert(first == second)
assert(first:match("%.jpg$") ~= nil)
assert(cache:localPath{ file_md5 = "missing", cover_url = "/covers/a.jpg" } == nil)

print("cover cache spec: OK")
