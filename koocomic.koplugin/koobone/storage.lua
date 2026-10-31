local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local Util = require("koobone.util")

local Storage = {}
Storage.__index = Storage

local function fileMode(path)
    if type(path) ~= "string" or path == "" then return nil end
    return lfs.attributes(path, "mode")
end

local function fileSize(path)
    if fileMode(path) ~= "file" then return 0 end
    local size = lfs.attributes(path, "size")
    return tonumber(size) or 0
end

local function removeFile(path)
    local mode = fileMode(path)
    if mode == nil then return true, 0, false end
    if mode ~= "file" then return nil, "目标不是普通文件：" .. tostring(path) end
    local size = fileSize(path)
    local ok, err = os.remove(path)
    if not ok then return nil, Util.cleanMessage(err or "无法删除文件") end
    return true, size, true
end

local function ensureDirectory(path)
    if lfs.attributes(path, "mode") == "directory" then return true end
    local ok_util, koreader_util = pcall(require, "util")
    if ok_util and koreader_util and koreader_util.makePath then
        return koreader_util.makePath(path)
    end
    return lfs.mkdir(path)
end

local function normalizeDirectory(path)
    path = Util.trim(path or "")
    if path == "" then return nil end
    if path ~= "/" then path = path:gsub("/+$", "") end
    return path
end

local function isUnsafeDirectory(path)
    if path == "/" then return true end
    local lower = tostring(path):lower()
    return lower:match("/plugins/?$") ~= nil
        or lower:match("/settings/?$") ~= nil
        or lower:match("/%.adds/koreader/?$") ~= nil
        or lower:find("/.adds/koreader/", 1, true) ~= nil
end

function Storage:new(settings)
    return setmetatable({ settings = assert(settings, "settings required") }, self)
end

function Storage:setRecordRemovedCallback(callback)
    self.on_record_removed = callback
end

function Storage:_recordRemoved(key)
    if key ~= nil and self.on_record_removed then pcall(self.on_record_removed, key) end
end

function Storage:defaultDownloadDir()
    local home = G_reader_settings:readSetting("home_dir")
    if not home or home == "" then
        local full = DataStorage:getFullDataDir() or DataStorage:getDataDir()
        home = ffiUtil.dirname(full)
    end
    return ffiUtil.joinPath(home, "KOOBONE")
end

function Storage:downloadDir()
    local configured = normalizeDirectory(self.settings:download().directory)
    if configured and configured ~= "" then
        ensureDirectory(configured)
        return configured
    end
    local path = self:defaultDownloadDir()
    ensureDirectory(path)
    return path
end

function Storage:validateDownloadDir(path)
    path = normalizeDirectory(path)
    if not path then return nil, "请选择一个下载目录。" end
    if isUnsafeDirectory(path) then
        return nil, "不能把系统根目录、KOReader 插件目录或设置目录用作漫画下载目录。"
    end
    local mode = fileMode(path)
    if mode == nil then
        local ok, err = ensureDirectory(path)
        if not ok then return nil, "无法创建目录：" .. Util.cleanMessage(err) end
        mode = fileMode(path)
    end
    if mode ~= "directory" then return nil, "所选路径不是文件夹。" end
    local probe = ffiUtil.joinPath(path, ".koocomic-write-test-" .. tostring(os.time()))
    local handle, open_err = io.open(probe, "wb")
    if not handle then return nil, "目录不可写：" .. Util.cleanMessage(open_err) end
    local wrote, write_err = handle:write("KooComic")
    handle:close()
    if not wrote then
        os.remove(probe)
        return nil, "目录写入测试失败：" .. Util.cleanMessage(write_err)
    end
    local removed, remove_err = os.remove(probe)
    if not removed then
        return nil, "目录测试文件无法清理：" .. Util.cleanMessage(remove_err)
    end
    return path
end

function Storage:setDownloadDir(path)
    local target = normalizeDirectory(path) or self:defaultDownloadDir()
    local valid, err = self:validateDownloadDir(target)
    if not valid then return nil, err end
    local download = self.settings:download()
    local current = normalizeDirectory(download.directory) or self:defaultDownloadDir()
    if current ~= valid then
        download.legacy_directories = type(download.legacy_directories) == "table"
            and download.legacy_directories or {}
        local exists = false
        for _, legacy in ipairs(download.legacy_directories) do
            if normalizeDirectory(legacy) == current then exists = true; break end
        end
        if not exists then download.legacy_directories[#download.legacy_directories + 1] = current end
    end
    download.directory = valid == self:defaultDownloadDir() and nil or valid
    self.settings:flush()
    return valid
end

function Storage:itemKey(item)
    return tostring(item.file_md5 or item.vol_id or item.vol_name or item.vol_series or "unknown")
end

function Storage:_filename(item)
    local extension = Util.trim(item.file_type or "epub"):lower()
    if extension == "" or extension:find("[^%w]", 1) then extension = "epub" end
    local title = Util.safeFilename(item.vol_name or item.vol_series or item.file_md5)
    return title .. "." .. extension
end

function Storage:newItemPath(item)
    return ffiUtil.joinPath(self:downloadDir(), self:_filename(item))
end

function Storage:itemPath(item)
    local key = self:itemKey(item)
    local record = self.settings:download().records[key]
    if type(record) == "table" and type(record.path) == "string" and record.path ~= "" then
        if fileMode(record.path) == "file" or fileMode(record.path .. ".part") == "file" then
            return record.path
        end
    end
    local filename = self:_filename(item)
    for _, directory in ipairs(self.settings:download().legacy_directories or {}) do
        local candidate = ffiUtil.joinPath(directory, filename)
        if fileMode(candidate) == "file" or fileMode(candidate .. ".part") == "file" then
            return candidate
        end
    end
    return self:newItemPath(item)
end

function Storage:partPath(item)
    local record = self.settings:download().records[self:itemKey(item)]
    if type(record) == "table" and type(record.part_path) == "string"
        and record.part_path ~= "" and fileMode(record.part_path) == "file" then
        return record.part_path
    end
    return self:itemPath(item) .. ".part"
end

function Storage:isDownloaded(item)
    return lfs.attributes(self:itemPath(item), "mode") == "file"
end

function Storage:fileSize(path)
    return fileSize(path)
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
    if state == "preparing" or state == "downloading" or state == "complete" then
        value.error = nil
    end
    if state == "complete" then value.part_path = nil end
    if type(extra) == "table" then
        for field, content in pairs(extra) do value[field] = content end
    end
    records[key] = value
    self.settings:flush()
    return value
end

function Storage:recordInfo(row)
    local key = row and row.key
    local value = row and row.value or row
    if type(value) ~= "table" then return nil end
    local path = type(value.path) == "string" and value.path or nil
    local part_path = type(value.part_path) == "string" and value.part_path or
        (path and (path .. ".part") or nil)
    local exists = fileMode(path) == "file"
    local part_exists = fileMode(part_path) == "file"
    local state = value.state
    if exists then
        state = "complete"
    elseif part_exists then
        if state == "complete" or state == "preparing" or state == "downloading" then
            state = "interrupted"
        end
    elseif state == "complete" or state == "preparing" or state == "downloading" then
        state = "missing"
    end
    return {
        key = key,
        value = value,
        title = value.title or "",
        path = path,
        part_path = part_path,
        state = state,
        exists = exists,
        size = exists and fileSize(path) or 0,
        part_exists = part_exists,
        part_size = part_exists and fileSize(part_path) or 0,
    }
end

function Storage:removeRecord(key)
    local records = self.settings:download().records
    if key == nil or records[key] == nil then return true, false end
    records[key] = nil
    self.settings:flush()
    self:_recordRemoved(key)
    return true, true
end

function Storage:_deleteRecordFiles(key, final_path, part_path, delete_final, delete_part)
    local removed_bytes = 0
    if delete_final then
        local ok, size_or_err = removeFile(final_path)
        if not ok then return nil, size_or_err end
        removed_bytes = removed_bytes + (tonumber(size_or_err) or 0)
    end
    if delete_part then
        local ok, size_or_err = removeFile(part_path)
        if not ok then return nil, size_or_err end
        removed_bytes = removed_bytes + (tonumber(size_or_err) or 0)
    end
    if key ~= nil then self.settings:download().records[key] = nil end
    self.settings:flush()
    self:_recordRemoved(key)
    return true, removed_bytes
end

function Storage:deleteItem(item)
    local key = self:itemKey(item)
    local record = self.settings:download().records[key]
    local final_path = record and record.path or self:itemPath(item)
    local part_path = record and record.part_path or nil
    if not part_path or part_path == "" then part_path = final_path .. ".part" end
    return self:_deleteRecordFiles(key, final_path, part_path, true, true)
end

function Storage:deletePartialItem(item)
    local key = self:itemKey(item)
    local record = self.settings:download().records[key]
    local final_path = record and record.path or self:itemPath(item)
    local part_path = record and record.part_path or nil
    if not part_path or part_path == "" then part_path = final_path .. ".part" end
    return self:_deleteRecordFiles(key, final_path, part_path, false, true)
end

function Storage:deleteRecordFiles(key)
    local value = self.settings:download().records[key]
    if type(value) ~= "table" then return nil, "下载记录不存在" end
    local path = type(value.path) == "string" and value.path or nil
    local part_path = type(value.part_path) == "string" and value.part_path or
        (path and (path .. ".part") or nil)
    return self:_deleteRecordFiles(key, path, part_path, true, true)
end

function Storage:deleteRecordPartial(key)
    local value = self.settings:download().records[key]
    if type(value) ~= "table" then return nil, "下载记录不存在" end
    local path = type(value.path) == "string" and value.path or nil
    local part_path = type(value.part_path) == "string" and value.part_path or
        (path and (path .. ".part") or nil)
    return self:_deleteRecordFiles(key, path, part_path, false, true)
end

function Storage:maintenanceSummary()
    local summary = {
        missing_records = 0,
        partial_files = 0,
        partial_bytes = 0,
    }
    for _, row in ipairs(self:records()) do
        local info = self:recordInfo(row)
        if info then
            if not info.exists and not info.part_exists then
                summary.missing_records = summary.missing_records + 1
            end
            if info.part_exists then
                summary.partial_files = summary.partial_files + 1
                summary.partial_bytes = summary.partial_bytes + info.part_size
            end
        end
    end
    return summary
end

function Storage:cleanupMissingRecords()
    local records = self.settings:download().records
    local removed = 0
    for key, value in pairs(records) do
        local info = self:recordInfo{ key = key, value = value }
        if info and not info.exists and not info.part_exists then
            records[key] = nil
            self:_recordRemoved(key)
            removed = removed + 1
        end
    end
    if removed > 0 then self.settings:flush() end
    return removed
end

function Storage:cleanupPartialFiles()
    local records = self.settings:download().records
    local removed_files, removed_bytes = 0, 0
    local errors = {}
    for key, value in pairs(records) do
        local info = self:recordInfo{ key = key, value = value }
        if info and info.part_exists then
            local ok, size_or_err = removeFile(info.part_path)
            if ok then
                removed_files = removed_files + 1
                removed_bytes = removed_bytes + (tonumber(size_or_err) or 0)
                if info.exists then
                    value.part_path = nil
                    value.state = "complete"
                    value.error = nil
                else
                    records[key] = nil
                    self:_recordRemoved(key)
                end
            else
                errors[#errors + 1] = tostring(size_or_err)
            end
        end
    end
    if removed_files > 0 then self.settings:flush() end
    return {
        files = removed_files,
        bytes = removed_bytes,
        errors = errors,
    }
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
