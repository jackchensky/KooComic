local Util = require("koobone.util")

local Auth = {}
Auth.__index = Auth

function Auth:new(settings, api)
    local object = setmetatable({ settings = assert(settings), api = assert(api) }, self)
    api.auth = object
    return object
end

function Auth:hasSession()
    local account = self.settings:account()
    return type(account.api_key) == "string" and account.api_key ~= ""
        and type(account.sess_key) == "string" and account.sess_key ~= ""
        and tonumber(account.uin) ~= nil
end

-- Keep the existing account untouched until the new key is verified. This
-- allows users to correct an input error without losing the previous session.
function Auth:login(key)
    key = Util.trim(key)
    if key == "" then return nil, "请输入 API Key" end
    if key:find("[%c%s]") then return nil, "API Key 不能包含空格或换行，请检查输入" end
    local info, err, invalid = self.api:exchangeApiKey(key)
    if not info then return nil, err, invalid end
    local account = self.settings:account()
    account.api_key = key
    account.sess_key = info.sess_key
    account.skey_exp = info.skey_exp
    account.uin = info.uin
    account.nick = info.nick
    self.settings:flush()
    return true, info
end

function Auth:restore()
    local account = self.settings:account()
    if type(account.api_key) ~= "string" or account.api_key == "" then
        return nil, "请输入 API Key", true
    end
    if self:hasSession() and (tonumber(account.skey_exp) or 0) > os.time() + 60 then
        return true
    end
    local ok, err, invalid = self:login(account.api_key)
    if ok then return true end
    -- Preserve the key and session on every failure, including a temporary
    -- outage; prompt for a replacement only on an explicit invalid-key reply.
    return nil, err, invalid == true
end

function Auth:logout()
    self.settings:logout()
end

return Auth
