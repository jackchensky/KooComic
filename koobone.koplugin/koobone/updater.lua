local Archiver = require("ffi/archiver")
local DataStorage = require("datastorage")
local JSON = require("json")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")
local sha2 = require("ffi/sha2")
local Util = require("koobone.util")
local Version = require("version")

local Updater = {}
Updater.__index = Updater

Updater.MAX_MANIFEST_BYTES = 128 * 1024
Updater.MAX_PACKAGE_BYTES = 15 * 1024 * 1024

local function pluginDirFromSource()
    local source = debug.getinfo(1, "S").source or ""
    return source:match("^@?(.+)/koobone/updater%.lua$")
end

local function ensureDirectory(path)
    if lfs.attributes(path, "mode") == "directory" then return true end
    local ok_util, koreader_util = pcall(require, "util")
    if ok_util and koreader_util and koreader_util.makePath then
        return koreader_util.makePath(path)
    end
    return lfs.mkdir(path)
end

local function removeFile(path)
    if path and path ~= "" then pcall(os.remove, path) end
end

local function removeTree(path)
    if type(path) ~= "string" or path == "" or path == "/" then
        return nil, "invalid cleanup path"
    end
    if not lfs.attributes(path, "mode") then return true end
    if not ffiUtil.purgeDir then return nil, "directory cleanup unavailable" end
    local ok, err = pcall(ffiUtil.purgeDir, path)
    return ok and true or nil, err
end

local function readFile(path, max_bytes)
    local handle, err = io.open(path, "rb")
    if not handle then return nil, err end
    local size = handle:seek("end")
    if not size or (max_bytes and size > max_bytes) then
        handle:close()
        return nil, "file is larger than expected"
    end
    handle:seek("set", 0)
    local data = handle:read("*a")
    handle:close()
    return data
end

local function sha256File(path)
    local handle, err = io.open(path, "rb")
    if not handle then return nil, err end
    local digest = sha2.sha256()
    while true do
        local chunk = handle:read(128 * 1024)
        if not chunk then break end
        digest(chunk)
    end
    handle:close()
    return digest()
end

local function normalizeNotes(notes)
    if type(notes) == "table" then
        local rows = {}
        for _, value in ipairs(notes) do
            local row = Util.cleanMessage(value, 240)
            if row ~= "" then rows[#rows + 1] = "• " .. row end
        end
        notes = table.concat(rows, "\n")
    end
    notes = tostring(notes or "")
    if #notes > 1800 then notes = notes:sub(1, 1797) .. "..." end
    return notes
end

function Updater:new(options)
    options = options or {}
    return setmetatable({
        settings = assert(options.settings, "settings required"),
        api = assert(options.api, "api required"),
        current_version = assert(options.current_version, "current version required"),
        manifest_url = options.manifest_url or "",
        release_prefix = options.release_prefix or "",
        plugin_dir = options.plugin_dir or pluginDirFromSource(),
    }, self)
end

function Updater:isConfigured()
    return self.manifest_url:match("^https://") ~= nil
        and self.release_prefix:match("^https://") ~= nil
end

function Updater:_manifestUrlAllowed(url)
    return self:isConfigured() and url == self.manifest_url
end

function Updater:_packageUrlAllowed(url)
    return self:isConfigured() and type(url) == "string"
        and url:sub(1, #self.release_prefix) == self.release_prefix
end

function Updater:_validateManifest(data)
    if type(data) ~= "table" then return nil, "更新清单格式无效" end
    local version = tostring(data.version or "")
    if not Util.compareVersions(version, version) then return nil, "版本号格式无效" end
    if data.channel ~= nil and data.channel ~= "stable" then return nil, "不是正式版更新" end
    if data.package_type ~= nil and data.package_type ~= "full" then
        return nil, "只支持完整更新包"
    end
    local package_url = data.package_url
    if not self:_packageUrlAllowed(package_url) then return nil, "更新包地址不在允许范围内" end
    local size = tonumber(data.size)
    if not size or size <= 0 or size > self.MAX_PACKAGE_BYTES then
        return nil, "更新包大小无效"
    end
    local sha256 = tostring(data.sha256 or ""):lower():gsub("%s+", "")
    if not sha256:match("^[0-9a-f]+$") or #sha256 ~= 64 then
        return nil, "更新包缺少有效 SHA-256"
    end
    return {
        version = version,
        package_url = package_url,
        size = size,
        sha256 = sha256,
        summary = Util.cleanMessage(data.summary, 320),
        notes = normalizeNotes(data.notes),
        published_at = Util.cleanMessage(data.published_at, 40),
        min_koreader = Util.cleanMessage(data.min_koreader, 40),
    }
end

function Updater:check()
    if not self:isConfigured() then return nil, "not_configured" end
    if not self:_manifestUrlAllowed(self.manifest_url) then return nil, "更新清单地址无效" end
    local response, err = self.api:requestOk{
        url = self.manifest_url,
        method = "GET",
        include_session = false,
        redirect = true,
        headers = {
            ["Accept"] = "application/json",
            ["User-Agent"] = "KOReader-KOOBONE-Updater/0.2",
        },
        block_timeout = 15,
        total_timeout = 30,
    }
    if not response then return nil, err end
    if #(response.body or "") > self.MAX_MANIFEST_BYTES then
        return nil, "更新清单过大"
    end
    local ok, decoded = pcall(JSON.decode, response.body or "")
    if not ok then return nil, "无法解析更新清单" end
    local release, validate_err = self:_validateManifest(decoded)
    if not release then return nil, validate_err end

    local state = self.settings:update()
    state.last_auto_update_check_at = os.time()
    state.last_seen_update_version = release.version
    if Util.compareVersions(release.version, self.current_version) == 1 then
        state.available = release
    else
        state.available = nil
    end
    self.settings:flush()
    return release, Util.compareVersions(release.version, self.current_version) == 1
end

function Updater:shouldAutoCheck()
    local state = self.settings:update()
    if not self:isConfigured() or state.auto_check_enabled ~= true then return false end
    if state.auto_update_prompt_disabled == true then return false end
    return Util.localDate(state.last_auto_update_check_at) ~= Util.localDate()
end

function Updater:shouldPrompt(release)
    local state = self.settings:update()
    if not release or Util.compareVersions(release.version, self.current_version) ~= 1 then return false end
    if state.auto_update_prompt_disabled == true then return false end
    if tonumber(state.update_prompt_later_count or 0) >= 3 then return false end
    return state.last_update_prompt_date ~= Util.localDate()
end

function Updater:markPromptShown(release)
    local state = self.settings:update()
    state.last_update_prompt_date = Util.localDate()
    state.last_seen_update_version = release and release.version or state.last_seen_update_version
    self.settings:flush()
end

function Updater:deferPrompt()
    local state = self.settings:update()
    state.update_prompt_later_count = math.min(3,
        tonumber(state.update_prompt_later_count or 0) + 1)
    if state.update_prompt_later_count >= 3 then
        state.auto_update_prompt_disabled = true
        state.auto_check_enabled = false
    end
    self.settings:flush()
end

function Updater:resetPromptPolicy()
    local state = self.settings:update()
    state.update_prompt_later_count = 0
    state.auto_update_prompt_disabled = false
    state.last_update_prompt_date = ""
    state.auto_check_enabled = true
    self.settings:flush()
end

function Updater:_extractPackage(archive_path, stage_path)
    local reader = Archiver.Reader:new()
    if not reader:open(archive_path) then
        reader:close()
        return nil, reader.err or "无法打开更新包"
    end
    local ok, err = true, nil
    for entry in reader:iterate() do
        local path = entry.path
        local safe = type(path) == "string" and path ~= ""
            and path:sub(1, 1) ~= "/"
            and path:find("\\", 1, true) == nil
            and path:match("^koobone%.koplugin/") ~= nil
            and path:match("^%.%./") == nil
            and path:match("/%.%./") == nil
            and path:match("/%.%.$") == nil
        if not safe then
            ok, err = nil, "更新包包含不安全路径"
            break
        end
        if not reader:extractToPath(path, stage_path .. "/" .. path) then
            ok, err = nil, reader.err or "解压更新包失败"
            break
        end
    end
    if reader.err then ok, err = nil, reader.err end
    reader:close()
    return ok, err
end

function Updater:install(release, on_progress)
    if not release or not self:_packageUrlAllowed(release.package_url) then
        return nil, "更新信息无效"
    end
    local function report(stage, percent, current, total)
        if on_progress then
            on_progress{
                stage = stage,
                percent = percent,
                current = current or 0,
                total = total or 0,
            }
        end
    end

    local base = DataStorage:getDataDir() .. "/koobone-updates"
    local archive = base .. "/koobone-update.zip"
    local stage = base .. "/stage"
    removeFile(archive)
    removeTree(stage)
    ensureDirectory(base)
    ensureDirectory(stage)

    report("正在下载更新包", 2, 0, release.size)
    local ok, err = self.api:download(release.package_url, archive, {
        total = release.size,
        max_bytes = self.MAX_PACKAGE_BYTES,
        headers = {
            ["Accept"] = "application/zip, application/octet-stream",
            ["User-Agent"] = "KOReader-KOOBONE-Updater/0.2",
        },
        on_progress = function(current, total)
            local ratio = total > 0 and math.min(1, current / total) or 0
            report("正在下载更新包", math.floor(2 + ratio * 68), current, total)
        end,
    })
    if not ok then removeFile(archive); removeTree(stage); return nil, err end

    local archive_size = lfs.attributes(archive, "size")
    local size = tonumber(archive_size) or 0
    if size ~= tonumber(release.size) then
        removeFile(archive); removeTree(stage)
        return nil, "更新包大小校验失败"
    end
    report("正在校验 SHA-256", 76)
    local actual, hash_err = sha256File(archive)
    if not actual or actual:lower() ~= release.sha256 then
        removeFile(archive); removeTree(stage)
        return nil, hash_err or "SHA-256 校验失败"
    end

    report("正在安全解压", 86)
    local unpacked, unpack_err = self:_extractPackage(archive, stage)
    removeFile(archive)
    if not unpacked then removeTree(stage); return nil, unpack_err end

    local staged_plugin = stage .. "/koobone.koplugin"
    local meta = readFile(staged_plugin .. "/_meta.lua", 64 * 1024)
    local main = readFile(staged_plugin .. "/main.lua", 1024 * 1024)
    local staged_version = meta and meta:match('version%s*=%s*"([^"]+)"') or nil
    if not main or staged_version ~= release.version then
        removeTree(stage)
        return nil, "更新包结构或版本号不正确"
    end

    report("正在备份并安装", 96)
    local backup = self.plugin_dir .. ".backup"
    removeTree(backup)
    local moved_old, old_err = os.rename(self.plugin_dir, backup)
    if not moved_old then removeTree(stage); return nil, old_err or "无法备份当前插件" end
    local moved_new, new_err = os.rename(staged_plugin, self.plugin_dir)
    if not moved_new then
        os.rename(backup, self.plugin_dir)
        removeTree(stage)
        return nil, new_err or "无法启用新版本，已恢复旧版本"
    end
    removeTree(stage)
    local state = self.settings:update()
    state.pending_version = release.version
    state.available = nil
    self.settings:flush()
    report("安装完成", 100)
    return true
end

function Updater:confirmInstalledUpdate()
    local state = self.settings:update()
    if state.pending_version ~= self.current_version then return false end
    local backup = self.plugin_dir .. ".backup"
    removeTree(backup)
    state.pending_version = nil
    self.settings:flush()
    return true
end

function Updater:koreaderVersion()
    return Version:getShortVersion()
end

return Updater
