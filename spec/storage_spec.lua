package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local files = {}
local directories = { ["/tmp"] = true, ["/tmp/KOOBONE"] = true }

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
        attributes = function(path, attribute)
            if directories[path] and attribute == "mode" then return "directory" end
            local file = files[path]
            if file and attribute == "mode" then return "file" end
            if file and attribute == "size" then return file.size end
            return nil, "file does not exist"
        end,
        mkdir = function(path) directories[path] = true; return true end,
    }
end

G_reader_settings = {
    readSetting = function() return "/tmp" end,
}

local Storage = require("koobone.storage")
local download = { directory = "/tmp/KOOBONE", records = {} }
local flush_count = 0
local settings = {
    download = function() return download end,
    flush = function() flush_count = flush_count + 1 end,
}
local storage = Storage:new(settings)
local removed_keys = {}
storage:setRecordRemovedCallback(function(key) removed_keys[#removed_keys + 1] = key end)
local item = { vol_name = "Test book", file_type = "epub" }
local final_path = "/tmp/KOOBONE/Test book.epub"
local part_path = final_path .. ".part"

local original_remove = os.remove
local original_open = io.open
io.open = function(path, mode)
    if tostring(path):find(".koocomic%-write%-test%-", 1) then
        return {
            write = function() return true end,
            close = function() end,
        }
    end
    return original_open(path, mode)
end
os.remove = function(path)
    if tostring(path):find(".koocomic%-write%-test%-", 1) then return true end
    if not files[path] then return nil, "file does not exist" end
    files[path] = nil
    return true
end

-- A missing .part file returns nil plus an lfs error string on KOReader.
-- This must be treated as zero bytes, not passed to tonumber as its base.
assert(storage:partSize(item) == 0)

files[part_path] = { size = 12345 }
assert(storage:partSize(item) == 12345)

-- Download records report the actual filesystem state, not stale byte counts.
files[final_path] = { size = 20000 }
files["/tmp/KOOBONE/Unrelated.epub"] = { size = 777 }
storage:record(item, "complete", { bytes = 99999 })
local key = storage:itemKey(item)
local row = { key = key, value = download.records[key] }
local info = storage:recordInfo(row)
assert(info.state == "complete")
assert(info.exists == true)
assert(info.size == 20000)
assert(info.part_exists == true)

-- Switching folders affects new downloads only. Existing records continue to
-- resolve, open and delete files in the old folder.
local selected, select_err = storage:setDownloadDir("/tmp/Custom")
assert(selected == "/tmp/Custom", select_err)
assert(storage:downloadDir() == "/tmp/Custom")
assert(download.legacy_directories[1] == "/tmp/KOOBONE")
assert(storage:itemPath(item) == final_path)
assert(storage:isDownloaded(item) == true)
local new_item = { vol_name = "New book", file_type = "epub" }
assert(storage:itemPath(new_item) == "/tmp/Custom/New book.epub")

-- Deleting a downloaded item removes only its exact EPUB, matching .part,
-- and persisted record, and reports the real number of released bytes.
local ok, removed = storage:deleteItem(item)
assert(ok == true)
assert(removed == 32345)
assert(files[final_path] == nil)
assert(files[part_path] == nil)
assert(files["/tmp/KOOBONE/Unrelated.epub"].size == 777)
assert(download.records[key] == nil)
assert(removed_keys[#removed_keys] == key)

-- If a user deletes the EPUB through a computer or file manager, the stale
-- completed record is exposed as missing and can be cleaned without deleting
-- any other file.
storage:record(item, "complete", { bytes = 20000 })
row = { key = key, value = download.records[key] }
info = storage:recordInfo(row)
assert(info.state == "missing")
local summary = storage:maintenanceSummary()
assert(summary.missing_records == 1)
assert(summary.partial_files == 0)
assert(storage:cleanupMissingRecords() == 1)
assert(download.records[key] == nil)
assert(removed_keys[#removed_keys] == key)

-- Failed partial downloads are counted by their actual size and bulk cleanup
-- removes the .part plus its now-empty history record.
storage:record(item, "failed", {
    bytes = 4096,
    part_path = part_path,
    error = "timeout",
})
files[part_path] = { size = 4096 }
summary = storage:maintenanceSummary()
assert(summary.missing_records == 0)
assert(summary.partial_files == 1)
assert(summary.partial_bytes == 4096)
local cleanup = storage:cleanupPartialFiles()
assert(cleanup.files == 1)
assert(cleanup.bytes == 4096)
assert(#cleanup.errors == 0)
assert(files[part_path] == nil)
assert(download.records[key] == nil)
assert(removed_keys[#removed_keys] == key)
assert(flush_count >= 4)

local unsafe, unsafe_err = storage:validateDownloadDir("/tmp/.adds/koreader/downloads")
assert(unsafe == nil and tostring(unsafe_err):find("不能", 1, true) ~= nil)
local restored, restore_err = storage:setDownloadDir(nil)
assert(restored == "/tmp/KOOBONE", restore_err)
assert(storage:downloadDir() == "/tmp/KOOBONE")
assert(download.legacy_directories[2] == "/tmp/Custom")

os.remove = original_remove
io.open = original_open

print("storage spec: OK")
