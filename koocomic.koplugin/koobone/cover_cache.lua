local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local Util = require("koobone.util")

local CoverCache = {}
CoverCache.__index = CoverCache

local MAX_COVER_BYTES = 5 * 1024 * 1024

local function ensureDirectory(path)
    if lfs.attributes(path, "mode") == "directory" then return true end
    local ok, koreader_util = pcall(require, "util")
    if ok and koreader_util and koreader_util.makePath then
        return koreader_util.makePath(path)
    end
    return lfs.mkdir(path)
end

local function hash(value)
    local number = 5381
    value = tostring(value or "")
    for index = 1, #value do
        number = (number * 33 + value:byte(index)) % 4294967296
    end
    local digits = "0123456789abcdef"
    local output = {}
    for index = 8, 1, -1 do
        local digit = number % 16
        output[index] = digits:sub(digit + 1, digit + 1)
        number = math.floor(number / 16)
    end
    return table.concat(output)
end

local function extension(url)
    local ext = tostring(url or ""):lower():match("%.([%w]+)[%?#]")
        or tostring(url or ""):lower():match("%.([%w]+)$")
    if ext == "jpeg" then return "jpg" end
    if ext == "jpg" or ext == "png" or ext == "gif" or ext == "webp" then
        return ext
    end
    return "jpg"
end

local function fileSize(path)
    local size = lfs.attributes(path, "size")
    return tonumber(size) or 0
end

local function looksLikeImage(path)
    local handle = io.open(path, "rb")
    if not handle then return false end
    local head = handle:read(12) or ""
    handle:close()
    if head:sub(1, 3) == "\255\216\255" then return true end
    if head:sub(1, 8) == "\137PNG\r\n\26\n" then return true end
    if head:sub(1, 3) == "GIF" then return true end
    return head:sub(1, 4) == "RIFF" and head:sub(9, 12) == "WEBP"
end

function CoverCache:new(api)
    local base = ffiUtil.joinPath(DataStorage:getDataDir(), "cache")
    local directory = ffiUtil.joinPath(base, "koobone-covers")
    ensureDirectory(directory)
    return setmetatable({
        api = assert(api, "api required"),
        directory = directory,
    }, self)
end

function CoverCache:url(item)
    local url = item and (item.cover_small or item.cover_url or item.cover or
        item.thumb_url or item.thumbnail) or nil
    url = tostring(url or "")
    if url == "" then return nil end
    if url:match("^//") then return "https:" .. url end
    if url:match("^/") then return self.api.BASE .. url end
    if url:match("^http://bookof%.hk/") then
        return "https://" .. url:sub(#"http://" + 1)
    end
    return url
end

function CoverCache:path(item)
    local url = self:url(item)
    if not url or url == "" then return nil end
    local key = item.file_md5 or item.vol_id or url
    return ffiUtil.joinPath(self.directory, hash(key) .. "." .. extension(url))
end

function CoverCache:localPath(item)
    local path = self:path(item)
    if path and fileSize(path) > 0 and looksLikeImage(path) then return path end
    return nil
end

function CoverCache:fetch(item)
    local existing = self:localPath(item)
    if existing then return existing end
    local url = self:url(item)
    local path = self:path(item)
    if not url or not path then return nil, "没有封面地址" end
    if not tostring(url):match("^https://") then return nil, "封面地址不是 HTTPS" end

    local temporary = path .. ".part"
    os.remove(temporary)
    local ok, err = self.api:download(url, temporary, {
        max_bytes = MAX_COVER_BYTES,
        headers = {
            ["Accept"] = "image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8",
            ["User-Agent"] = "kooComic-KOReader/0.4.0",
            ["Referer"] = self.api.BASE .. "/",
        },
    })
    if not ok then
        os.remove(temporary)
        return nil, Util.cleanMessage(err)
    end
    if not looksLikeImage(temporary) then
        os.remove(temporary)
        return nil, "封面响应不是受支持的图片"
    end
    os.remove(path)
    local moved, move_err = os.rename(temporary, path)
    if not moved then
        os.remove(temporary)
        return nil, Util.cleanMessage(move_err or "无法保存封面")
    end
    return path
end

return CoverCache
