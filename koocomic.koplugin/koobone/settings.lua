local LuaSettings = require("luasettings")

local Settings = {}
Settings.__index = Settings

local function defaults()
    return {
        schema_version = 3,
        account = {
            email = "",
            password = nil,
            remember_password = false,
            vlibsid = nil,
            kbskey = nil,
            uin = nil,
            nick = nil,
        },
        download = {
            directory = nil,
            records = {},
        },
        update = {
            auto_check_enabled = false,
            last_auto_update_check_at = 0,
            last_update_prompt_date = "",
            update_prompt_later_count = 0,
            auto_update_prompt_disabled = false,
            last_seen_update_version = "",
            available = nil,
            pending_version = nil,
        },
        ui = {
            portrait_columns = 3,
            portrait_rows = 2,
            landscape_columns = 4,
            landscape_rows = 2,
            text_size = "large",
        },
    }
end

local function merge(target, source)
    if type(source) ~= "table" then return target end
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            merge(target[key], value)
        else
            target[key] = value
        end
    end
    return target
end

function Settings:new(path, legacy_path)
    local object = setmetatable({
        path = assert(path, "settings path required"),
        handle = LuaSettings:open(path),
        legacy_path = legacy_path,
    }, self)
    object:load()
    return object
end

function Settings:load()
    local data = self.handle:readSetting("data")
    if type(data) ~= "table" then
        local legacy
        if self.legacy_path and self.legacy_path ~= self.path then
            local legacy_handle = LuaSettings:open(self.legacy_path)
            legacy = legacy_handle:readSetting("data") or legacy_handle:readSetting("settings")
        end
        legacy = legacy or self.handle:readSetting("settings")
        if type(legacy) == "table" then
            if type(legacy.account) == "table" then
                data = merge(defaults(), legacy)
            else
                data = defaults()
                data.account.email = legacy.email or ""
                data.account.vlibsid = legacy.vlibsid
                data.account.kbskey = legacy.kbskey
                data.account.uin = legacy.uin
                data.account.nick = legacy.nick
            end
        else
            data = defaults()
        end
    else
        data = merge(defaults(), data)
    end
    if data.account.remember_password ~= true then
        data.account.password = nil
    end
    data.schema_version = 3
    self.data = data
    self:flush()
end

function Settings:flush()
    self.handle:saveSetting("data", self.data)
    self.handle:flush()
end

function Settings:account()
    return self.data.account
end

function Settings:download()
    return self.data.download
end

function Settings:update()
    return self.data.update
end

function Settings:ui()
    return self.data.ui
end

function Settings:setCredentials(email, password, remember)
    local account = self:account()
    account.email = tostring(email or "")
    account.remember_password = remember == true
    account.password = account.remember_password and tostring(password or "") or nil
    self:flush()
end

function Settings:clearPassword()
    local account = self:account()
    account.password = nil
    account.remember_password = false
    self:flush()
end

function Settings:clearSession()
    local account = self:account()
    account.vlibsid = nil
    account.kbskey = nil
    account.uin = nil
    account.nick = nil
    self:flush()
end

function Settings:logout()
    self:clearSession()
    self:clearPassword()
end

return Settings
