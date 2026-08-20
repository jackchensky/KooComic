local Util = require("koobone.util")

local Auth = {}
Auth.__index = Auth

function Auth:new(settings, api)
    return setmetatable({
        settings = assert(settings, "settings required"),
        api = assert(api, "api required"),
    }, self)
end

function Auth:hasSession()
    local account = self.settings:account()
    return account.vlibsid ~= nil and account.kbskey ~= nil and account.uin ~= nil
end

function Auth:validateSession()
    if not self:hasSession() then return nil, "尚未登录" end
    local info, err = self.api:userInfo()
    if not info then return nil, err end
    local account = self.settings:account()
    account.uin = tonumber(info.uin)
    account.nick = info.nick or account.nick
    self.settings:flush()
    return true, info
end

function Auth:login(email, password, remember)
    email = Util.trim(email)
    password = tostring(password or "")
    if email == "" or password == "" then return nil, "请输入邮箱和密码" end

    local account = self.settings:account()
    account.vlibsid = nil
    account.kbskey = nil
    account.uin = nil
    account.nick = nil
    self.settings:flush()

    local ok, err = self.api:login(email, password)
    if not ok then return nil, err end
    local info, info_err = self.api:userInfo()
    if not info then
        self.settings:clearSession()
        return nil, info_err
    end
    account = self.settings:account()
    account.uin = tonumber(info.uin)
    account.nick = info.nick
    self.settings:setCredentials(email, password, remember)
    password = nil
    return true, info
end

function Auth:restore()
    if self:hasSession() then
        local valid, err = self:validateSession()
        if valid then return true end
        local message = tostring(err or "")
        local expired = message:find("登录状态已失效", 1, true)
            or message:find("HTTP 401", 1, true)
            or message:find("HTTP 403", 1, true)
        if not expired then
            -- Keep the session on transport, TLS, Cloudflare, or malformed
            -- response errors. A temporary network failure must not force the
            -- user to type credentials again.
            return nil, err or "无法验证登录状态", false
        end
        self.settings:clearSession()
    end
    local account = self.settings:account()
    if account.remember_password and account.email ~= "" and account.password then
        local ok, result = self:login(account.email, account.password, true)
        return ok, result, ok ~= true
    end
    return nil, "需要登录", true
end

function Auth:logout()
    self.settings:logout()
end

return Auth
