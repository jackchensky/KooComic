local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local Util = require("koobone.util")

local Storage = {}
Storage.__index = Storage

local function ensureDirectory(path)
    if lfs.attributes(path, "mode") == "directory" then return true end
    local ok_util, koreader_util = pcall(require, "util")
    if ok_util and koreader_util and koreader_util.makePath then
        return koreader_util.makePath(path)
    end
    return lfs.mkdir(path)
end

function Storage:new(settings)
    return setmetatable({ settings = assert(settings, "settings required") }, self)
end

function Storage:downloadDir()
    local configured = self.settings:download().directory
    if configured and configured ~= "" then
        ensureDirectory(configured)
        return configured
    end
    local home = G_reader_settings:readSetting("home_dir")
    if not home or home == "" then
        local full = DataStorage:getFullDataDir() or DataStorage:getDataDir()
        home = ffiUtil.dirname(full)
    end
    local path = ffiUtil.joinPath(home, "KOOBONE")
    ensureDirectory(path)
    return path
end

function Storage:itemKey(item)
    return tostring(item.file_md5 or item.vol_id or item.vol_name or item.vol_series or "unknown")
end

function Storage:itemPath(item)
    local extension = Util.trim(item.file_type or "epub"):lower()
    if extension == "" or extension:find("[^%w]", 1) then extension = "epub" end
    local title = Util.safeFilename(item.vol_name or item.vol_series or item.file_md5)
    return ffiUtil.joinPath(self:downloadDir(), title .. "." .. extension)
end

function Storage:partPath(item)
    return self:itemPath(item) .. ".part"
end

function Storage:isDownloaded(item)
    return lfs.attributes(self:itemPath(item), "mode") == "file"
end

function Storage:partSize(item)
    -- lfs.attributes returns nil plus an error string when the file is absent.
    -- Store only its first return value so tonumber never receives that error
    -- string as the optional numeric-base argument.
    local size = lfs.attributes(self:partPath(item), "size")
    return tonumber(size) or 0
end

function Storage:record(item, state, extra)
    local records = self.settings:download().records
    local key = self:itemKey(item)
    local value = records[key] or {}
    value.title = item.vol_name or item.vol_series or ""
    value.path = self:itemPath(item)
    value.state = state
    value.updated_at = os.time()
    if type(extra) == "table" then
        for field, content in pairs(extra) do value[field] = content end
    end
    records[key] = value
    self.settings:flush()
    return value
end

function Storage:records()
    local rows = {}
    for key, value in pairs(self.settings:download().records) do
        rows[#rows + 1] = { key = key, value = value }
    end
    table.sort(rows, function(a, b)
        return tonumber(a.value.updated_at or 0) > tonumber(b.value.updated_at or 0)
    end)
    return rows
end

return Storage
