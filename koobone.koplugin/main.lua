-- KOOBONE experimental KOReader plugin v0.1
-- Based on KOReader's public plugin APIs and the KOOBONE web requests
-- observed by the user in Chrome DevTools.
--
-- Security:
-- * This plugin does NOT store your password.
-- * It stores only session cookies (VLIBSID/KBSKEY) in KOReader settings.
-- * Use only on your own KOOBONE account.
--
-- Experimental: endpoint behaviour may change.

local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local JSON = require("json")
local LuaSettings = require("luasettings")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local NetworkMgr = require("ui/network/manager")
local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiUtil = require("ffi/util")
local http = require("socket.http")
local lfs = require("libs/libkoreader-lfs")
local ltn12 = require("ltn12")
local socket = require("socket")
local socketutil = require("socketutil")
local _ = require("gettext")

local Koobone = WidgetContainer:extend{
    name = "koobone",
    is_doc_only = false,
    settings_file = DataStorage:getSettingsDir() .. "/koobone.lua",
}

local BASE = "https://bookof.hk"
local WEB_VERSION = "7"
local API_VERSION = "KOOBONE/5.0.0"

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function cookie_value(set_cookie, name)
    if not set_cookie then return nil end
    if type(set_cookie) == "table" then
        for _, v in pairs(set_cookie) do
            local found = cookie_value(v, name)
            if found then return found end
        end
        return nil
    end
    return tostring(set_cookie):match(name .. "=([^;,%s]+)")
end

local function safe_filename(name)
    name = trim(name)
    name = name:gsub("[/\\:*?\"<>|]", "_")
    name = name:gsub("%s+$", "")
    if name == "" then name = "KOOBONE" end
    return name
end

local function mb(bytes)
    return string.format("%.1f MB", (tonumber(bytes) or 0) / 1024 / 1024)
end

function Koobone:loadSettings()
    if not Koobone.settings then
        Koobone.settings = LuaSettings:open(self.settings_file)
    end
    self.cfg = Koobone.settings:readSetting("settings", {
        email = "",
        vlibsid = nil,
        kbskey = nil,
        uin = nil,
        nick = nil,
    })
end

function Koobone:saveSettings()
    Koobone.settings:saveSetting("settings", self.cfg)
    Koobone.settings:flush()
end

function Koobone:init()
    self:loadSettings()
    self.ui.menu:registerToMainMenu(self)
end

function Koobone:addToMainMenu(menu_items)
    menu_items.koobone = {
        text = _("KOOBONE"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text_func = function()
                    if self.cfg.nick then
                        return _("My library") .. " (" .. self.cfg.nick .. ")"
                    end
                    return _("My library")
                end,
                callback = function()
                    self:ensureOnline(function()
                        if not self:isLoggedIn() then
                            self:showLogin()
                        else
                            self:showLibrary()
                        end
                    end)
                end,
            },
            {
                text_func = function()
                    return self:isLoggedIn() and _("Re-login") or _("Login")
                end,
                callback = function()
                    self:ensureOnline(function() self:showLogin() end)
                end,
            },
            {
                text = _("Logout / clear session"),
                enabled_func = function() return self:isLoggedIn() end,
                callback = function()
                    self.cfg.vlibsid = nil
                    self.cfg.kbskey = nil
                    self.cfg.uin = nil
                    self.cfg.nick = nil
                    self:saveSettings()
                    UIManager:show(InfoMessage:new{ text = _("KOOBONE session cleared.") })
                end,
            },
            {
                text = _("Download folder"),
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{ text = self:getDownloadDir() })
                end,
            },
        },
    }
end

function Koobone:isLoggedIn()
    return self.cfg.vlibsid and self.cfg.kbskey and self.cfg.uin
end

function Koobone:ensureOnline(cb)
    NetworkMgr:runWhenOnline(cb)
end

function Koobone:headers(extra)
    local h = {
        ["Accept"] = "*/*",
        ["X-KB-FROM"] = API_VERSION .. " WEB(" .. WEB_VERSION .. ") GET /web.htm",
        ["Referer"] = BASE .. "/web.htm",
    }
    if self.cfg.vlibsid or self.cfg.kbskey then
        local c = {}
        if self.cfg.vlibsid then c[#c+1] = "VLIBSID=" .. self.cfg.vlibsid end
        if self.cfg.kbskey then c[#c+1] = "KBSKEY=" .. self.cfg.kbskey end
        h["Cookie"] = table.concat(c, "; ")
    end
    if extra then
        for k,v in pairs(extra) do h[k] = v end
    end
    return h
end

function Koobone:httpRequest(req, file_path)
    local sink = {}
    if file_path then
        local fh, err = io.open(file_path, "wb")
        if not fh then return false, err end
        req.sink = ltn12.sink.file(fh)
        socketutil:set_timeout(30, 600)
    else
        req.sink = ltn12.sink.table(sink)
        socketutil:set_timeout(20, 90)
    end

    local ok, code, headers, status = pcall(function()
        local _, c, h, s = http.request(req)
        return c, h, s
    end)
    socketutil:reset_timeout()

    if not ok then
        if file_path then os.remove(file_path) end
        return false, tostring(code)
    end

    if tonumber(code) ~= 200 then
        if file_path then os.remove(file_path) end
        return false, "HTTP " .. tostring(code) .. " " .. tostring(status or "")
    end

    if file_path then
        return true, file_path, headers
    end
    return true, table.concat(sink), headers
end

function Koobone:getInitialVlibsid()
    local req = {
        url = BASE .. "/login.htm?goto=web.htm",
        method = "GET",
        headers = {
            ["Accept"] = "*/*",
            ["X-KB-FROM"] = API_VERSION .. " WEB(" .. WEB_VERSION .. ") GET /login.htm",
        },
    }
    local ok, _, headers = self:httpRequest(req)
    if not ok then return false, _ end
    local sid = cookie_value(headers and (headers["set-cookie"] or headers["Set-Cookie"]), "VLIBSID")
    if sid then
        self.cfg.vlibsid = sid
        self:saveSettings()
    end
    return true
end

local function multipart_body(fields)
    local boundary = "----KOReaderKoobone" .. tostring(os.time())
    local out = {}
    for k,v in pairs(fields) do
        out[#out+1] = "--" .. boundary .. "\r\n"
        out[#out+1] = 'Content-Disposition: form-data; name="' .. k .. '"\r\n\r\n'
        out[#out+1] = tostring(v) .. "\r\n"
    end
    out[#out+1] = "--" .. boundary .. "--\r\n"
    return table.concat(out), boundary
end

function Koobone:doLogin(email, password)
    email, password = trim(email), password or ""
    if email == "" or password == "" then
        return false, _("Email and password are required.")
    end

    if not self.cfg.vlibsid then
        local ok, err = self:getInitialVlibsid()
        if not ok then return false, err end
    end

    local body, boundary = multipart_body{
        email = email,
        passwd = password,
        keepalive = "1",
    }

    local req = {
        url = BASE .. "/login_do.php",
        method = "POST",
        source = ltn12.source.string(body),
        headers = self:headers{
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
            ["Content-Length"] = tostring(#body),
            ["Origin"] = BASE,
            ["Referer"] = BASE .. "/login.php?goto=web.htm",
            ["X-KB-FROM"] = API_VERSION .. " POST /login.php",
        },
    }

    local ok, _, headers = self:httpRequest(req)
    if not ok then return false, _ end

    local key = cookie_value(headers and (headers["set-cookie"] or headers["Set-Cookie"]), "KBSKEY")
    if not key then
        return false, _("Login did not return KBSKEY.")
    end

    self.cfg.email = email
    self.cfg.kbskey = key

    local info_ok, info = self:getUserInfo()
    if not info_ok then
        self.cfg.kbskey = nil
        return false, info
    end

    self.cfg.uin = tonumber(info.uin)
    self.cfg.nick = info.nick
    self:saveSettings()
    return true
end

function Koobone:getUserInfo()
    local req = {
        url = BASE .. "/uinfo.php?v=web&ver=" .. WEB_VERSION,
        method = "GET",
        headers = self:headers(),
    }
    local ok, body = self:httpRequest(req)
    if not ok then return false, body end
    local j_ok, data = pcall(JSON.decode, body)
    if not j_ok or type(data) ~= "table" or not data.uin then
        return false, _("Invalid user-info response.")
    end
    return true, data
end

function Koobone:getLibrary()
    if not self.cfg.uin then return false, _("Not logged in.") end
    local url = string.format(
        "%s/vol_list.php?u=%s&by=time&limit=28",
        BASE, tostring(self.cfg.uin)
    )
    local req = { url = url, method = "GET", headers = self:headers() }
    local ok, body = self:httpRequest(req)
    if not ok then return false, body end
    local j_ok, data = pcall(JSON.decode, body)
    if not j_ok or type(data) ~= "table" or type(data.data) ~= "table" then
        return false, _("Invalid library response.")
    end
    return true, data
end

function Koobone:showLogin()
    local dlg
    dlg = MultiInputDialog:new{
        title = _("KOOBONE login"),
        fields = {
            {
                text = self.cfg.email or "",
                hint = _("Email"),
            },
            {
                text = "",
                hint = _("Password"),
                text_type = "password",
            },
        },
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function() UIManager:close(dlg) end,
                },
                {
                    text = _("Login"),
                    is_enter_default = true,
                    callback = function()
                        local fields = dlg:getFields()
                        local email = fields[1]
                        local password = fields[2]
                        UIManager:close(dlg)
                        UIManager:show(InfoMessage:new{ text = _("Logging in…"), timeout = 1 })
                        local ok, err = self:doLogin(email, password)
                        if ok then
                            UIManager:show(InfoMessage:new{ text = _("Logged in to KOOBONE.") })
                            self:showLibrary()
                        else
                            UIManager:show(InfoMessage:new{ text = _("Login failed: ") .. tostring(err) })
                        end
                    end,
                },
            },
        },
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

function Koobone:showLibrary()
    local ok, lib = self:getLibrary()
    if not ok then
        UIManager:show(InfoMessage:new{ text = _("Unable to load KOOBONE library: ") .. tostring(lib) })
        return
    end

    local buttons = {}
    for _, item in ipairs(lib.data) do
        local title = item.vol_name or item.vol_series or item.file_md5 or _("Untitled")
        local author = item.vol_author or ""
        local info = string.format("%s\n%s · %s · %s/%s",
            title,
            author,
            mb(item.file_size),
            tostring(item.last_readpage or 0),
            tostring(item.count_page or "?")
        )
        buttons[#buttons+1] = {
            {
                text = info,
                callback = function()
                    if self.library_dialog then
                        UIManager:close(self.library_dialog)
                        self.library_dialog = nil
                    end
                    self:downloadItem(item)
                end,
            },
        }
    end

    if #buttons == 0 then
        UIManager:show(InfoMessage:new{ text = _("Your KOOBONE library is empty.") })
        return
    end

    buttons[#buttons+1] = {
        {
            text = _("Close"),
            callback = function()
                if self.library_dialog then
                    UIManager:close(self.library_dialog)
                    self.library_dialog = nil
                end
            end,
        },
    }

    self.library_dialog = ButtonDialog:new{
        title = _("KOOBONE library"),
        buttons = buttons,
    }
    UIManager:show(self.library_dialog)
end

function Koobone:getDownloadDir()
    local home = G_reader_settings:readSetting("home_dir")
    if not home or home == "" then
        -- Kindle and most KOReader ports expose the user-visible storage
        -- as the parent directory of the KOReader data folder.
        local full = DataStorage:getFullDataDir() or DataStorage:getDataDir()
        home = ffiUtil.dirname(full)
    end
    local dir = ffiUtil.joinPath(home, "KOOBONE")
    if lfs.attributes(dir, "mode") ~= "directory" then
        lfs.mkdir(dir)
    end
    return dir
end

function Koobone:downloadItem(item)
    if not item.file_url or item.file_url == "" then
        UIManager:show(InfoMessage:new{ text = _("This item has no download URL.") })
        return
    end

    local ext = item.file_type or "epub"
    local title = safe_filename(item.vol_name or item.vol_series or item.file_md5 or "KOOBONE")
    local path = ffiUtil.joinPath(self:getDownloadDir(), title .. "." .. ext)

    if lfs.attributes(path, "mode") == "file" then
        UIManager:show(ConfirmBox:new{
            text = _("File already exists. Open it?"),
            ok_text = _("Open"),
            ok_callback = function() ReaderUI:showReader(path) end,
        })
        return
    end

    UIManager:show(InfoMessage:new{
        text = _("Downloading may take several minutes…"),
        timeout = 2,
    })
    UIManager:forceRePaint()

    local req = {
        url = item.file_url,
        method = "GET",
        headers = {
            ["Accept"] = "*/*",
            ["X-KB-FROM"] = API_VERSION .. " WEB(" .. WEB_VERSION .. ") FETCH /web.htm",
            ["Referer"] = BASE .. "/",
        },
    }
    local ok, result = self:httpRequest(req, path)
    if not ok then
        UIManager:show(InfoMessage:new{ text = _("Download failed: ") .. tostring(result) })
        return
    end

    UIManager:show(ConfirmBox:new{
        text = _("Download complete:\n") .. path,
        ok_text = _("Open"),
        cancel_text = _("Later"),
        ok_callback = function() ReaderUI:showReader(path) end,
    })
end

return Koobone
