local JSON = require("json")
local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local http = require("socket.http")
local PluginVersion = require("koobone.plugin_version")
local Util = require("koobone.util")

local Api = {}
Api.__index = Api

Api.BASE = "https://bookof.hk"
-- The API-key integration uses KOOBONE's documented service, not the legacy
-- web-login host. Never send either credential to redirects or other hosts.
Api.API_BASE = "https://www.koobone.com"
Api.WEB_VERSION = "7"
Api.CLIENT_VERSION = "KOOBONE/5.0.0"
-- bookof.hk currently returns only {"msgid":"e499"} when its login
-- endpoint receives a non-browser User-Agent. Keep the official X-KB-FROM
-- header for source/version information while using a browser-compatible UA
-- for site requests, matching the web client this adapter implements.
Api.USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " ..
    "(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

function Api:new(settings)
    return setmetatable({ settings = assert(settings, "settings required") }, self)
end

function Api:headers(extra, include_session)
    local headers = {
        ["Accept"] = "*/*",
        ["User-Agent"] = self.USER_AGENT,
        ["X-KB-FROM"] = self.CLIENT_VERSION .. " WEB(" .. self.WEB_VERSION .. ") GET /web.htm",
        ["Referer"] = self.BASE .. "/web.htm",
    }
    if include_session ~= false then
        local account = self.settings:account()
        local cookies = {}
        if account.vlibsid then cookies[#cookies + 1] = "VLIBSID=" .. account.vlibsid end
        if account.kbskey then cookies[#cookies + 1] = "KBSKEY=" .. account.kbskey end
        if #cookies > 0 then headers["Cookie"] = table.concat(cookies, "; ") end
    end
    for key, value in pairs(extra or {}) do headers[key] = value end
    return headers
end

function Api:apiHeaders(credential)
    return {
        ["Accept"] = "application/json",
        ["User-Agent"] = self.USER_AGENT,
        ["X-KB-FROM"] = "KooComic/" .. tostring(PluginVersion.version) .. " (KOReader)",
        ["X-KB-INFO"] = credential,
    }
end

local function matchesServer(cert, host)
    if not cert then return false end
    if type(cert.checkhost) == "function" then
        local ok, matched = pcall(cert.checkhost, cert, host)
        return ok and matched == true
    end
    -- Older LuaSec builds expose DNS subjectAltName entries instead. Match
    -- exact names or a whole-label wildcard only; never fall back to CN.
    if type(cert.extensions) ~= "function" then return false end
    local ok, extensions = pcall(cert.extensions, cert)
    local san = ok and type(extensions) == "table" and extensions["2.5.29.17"]
    local names = type(san) == "table" and san.dNSName
    if type(names) ~= "table" then return false end
    for _, name in ipairs(names) do
        if type(name) == "string" then
            name = name:lower()
            if name == host or (name:sub(1, 2) == "*." and
                    host:match("^[^.]+%.(.+)$") == name:sub(3)) then return true end
        end
    end
    return false
end

function Api:secureCreate()
    if http.PROXY then return nil, "API Key 连接暂不支持 HTTP 代理" end
    local candidates = { "data/ca-bundle.crt", "/mnt/us/koreader/data/ca-bundle.crt" }
    local env_ca = os.getenv("SSL_CERT_FILE")
    if env_ca and env_ca ~= "" then table.insert(candidates, 1, env_ca) end
    local ca
    for _, path in ipairs(candidates) do
        local handle = io.open(path, "rb")
        if handle then handle:close(); ca = path; break end
    end
    if not ca then return nil, "无法找到 KOReader 证书文件，请更新 KOReader 后重试" end
    local ok, https = pcall(require, "ssl.https")
    if not ok or type(https.tcp) ~= "function" then
        return nil, "当前 KOReader 不支持安全连接，请更新 KOReader 后重试"
    end
    local create = https.tcp{ verify = "peer", cafile = ca }
    return function()
        local connection = create()
        local connect = connection.connect
        function connection:connect(host, port)
            if host ~= "www.koobone.com" then return nil, "服务器地址不匹配" end
            local connected, err = connect(self, host, port)
            if not connected then return nil, err end
            local valid, certificate = pcall(function() return self:getpeercertificate() end)
            if not valid or not matchesServer(certificate, "www.koobone.com") then
                self:close()
                return nil, "服务器证书域名验证失败"
            end
            return connected
        end
        return connection
    end
end

-- Exchange the long-lived API key for the short-lived session documented by
-- KOOBONE. Do not persist anything until the whole response is validated.
function Api:exchangeApiKey(key)
    local data, err = self:requestJson{
        url = self.API_BASE .. "/uinfo.php",
        method = "GET",
        headers = self:apiHeaders(key),
        redirect = false,
        secure_credentials = true,
    }
    if not data then
        if tostring(err):match("^HTTP 401[%s$]") then
            return nil, "API Key 无效或已失效，请检查后重新输入", true
        end
        return nil, err
    end
    if tonumber(data.msgid) == 401 then
        return nil, "API Key 无效或已失效，请检查后重新输入", true
    end
    local session = type(data.sess_key) == "string" and data.sess_key or ""
    local expires = tonumber(data.skey_exp)
    local uin = tonumber(data.uin)
    if tonumber(data.msgid) ~= 0 or not uin or uin <= 0 or session == ""
        or #session > 64 or session:find("[%c]") or not expires or expires <= os.time() then
        return nil, "服务器返回的账号信息无效，请稍后重试"
    end
    return {
        uin = uin,
        nick = data.nick,
        sess_key = session,
        skey_exp = expires,
    }
end

function Api:request(options)
    options = options or {}
    local buffered_get = (options.method == nil or options.method == "GET")
        and options.sink == nil and options.source == nil
    local attempts = buffered_get and 2 or 1
    for attempt = 1, attempts do
        local request_options = {}
        for key, value in pairs(options) do request_options[key] = value end
        if options.secure_credentials then
            local create, secure_err = self:secureCreate()
            if not create then return nil, secure_err end
            request_options.create = create
        end
        request_options.headers = options.headers or self:headers(nil, options.include_session)
        request_options.redirect = options.redirect == true
        socketutil:set_timeout(options.block_timeout or 20, options.total_timeout or 90)
        local chunks
        if not options.sink then
            chunks = {}
            -- table_sink captures KOReader's current timeout when created.
            request_options.sink = socketutil.table_sink(chunks)
        end
        -- KOReader's LuaSocket performs its own HTTPS adjustment when an
        -- https:// URL is passed to socket.http.request. Keep that path.
        local called, first, raw_code, headers, status = pcall(http.request, request_options)
        socketutil:reset_timeout()
        local code = called and tonumber(raw_code) or nil
        if code then
            return {
                code = code,
                headers = headers or {},
                status = status,
                body = chunks and table.concat(chunks) or first,
            }
        end
        -- LuaSocket returns nil, error_message for transport failures.
        local err = Util.cleanMessage(called and
            (status or raw_code or first or "network error") or first)
        local lowered = err:lower()
        local wait_code = lowered:find("wantread", 1, true) and "wantread"
            or lowered:find("wantwrite", 1, true) and "wantwrite"
            or lowered:find("timeout", 1, true) and "timeout"
        if not (buffered_get and attempt < attempts and wait_code) then
            if wait_code then
                local host = tostring(options.url or ""):match("^https?://([^/%?]+)")
                return nil, "网络等待超时（" .. wait_code ..
                    (host and "；主机 " .. host or "") ..
                    (attempt > 1 and "；已重试一次" or "；未自动重试") .. "）"
            end
            return nil, err
        end
    end
end

function Api:requestOk(options, accepted)
    local response, err = self:request(options)
    if not response then return nil, err end
    accepted = accepted or { [200] = true }
    if not accepted[response.code] then
        return nil, "HTTP " .. tostring(response.code) .. " " ..
            Util.cleanMessage(response.status, 100)
    end
    return response
end

function Api:requestJson(options)
    local response, err = self:requestOk(options)
    if not response then return nil, err end
    local ok, data = pcall(JSON.decode, response.body or "")
    if not ok or type(data) ~= "table" then return nil, "服务器返回了无效数据" end
    return data, response
end

function Api:getInitialSession()
    -- /login.htm is only the static login page and currently does not create
    -- a session. /login.php does; the site root is retained as a fallback
    -- because it also creates VLIBSID before redirecting to /login.htm.
    local attempts = {
        {
            path = "/login.php?goto=web.htm",
            from = "GET /login.php",
        },
        {
            path = "/",
            from = "GET /",
        },
    }
    local last_error
    for _, attempt in ipairs(attempts) do
        local response, err = self:request{
            url = self.BASE .. attempt.path,
            method = "GET",
            include_session = false,
            headers = self:headers({
                ["X-KB-FROM"] = self.CLIENT_VERSION .. " WEB(" ..
                    self.WEB_VERSION .. ") " .. attempt.from,
            }, false),
        }
        if response and (response.code == 200 or response.code == 302) then
            local sid = Util.cookieValue(
                Util.header(response.headers, "set-cookie"), "VLIBSID")
            if sid then
                self.settings:account().vlibsid = sid
                self.settings:flush()
                return true
            end
            last_error = "初始化页面没有返回 VLIBSID"
        elseif response then
            last_error = "初始化登录会话失败：HTTP " .. tostring(response.code)
        else
            last_error = err
        end
    end
    return nil, last_error or "无法初始化登录会话"
end

local function multipart(fields)
    local boundary = "----KOReaderKoobone" .. tostring(os.time()) .. tostring(math.random(1000, 9999))
    local parts = {}
    for key, value in pairs(fields) do
        parts[#parts + 1] = "--" .. boundary .. "\r\n"
        parts[#parts + 1] = 'Content-Disposition: form-data; name="' .. key .. '"\r\n\r\n'
        parts[#parts + 1] = tostring(value) .. "\r\n"
    end
    parts[#parts + 1] = "--" .. boundary .. "--\r\n"
    return table.concat(parts), boundary
end

local function hasValidUin(value)
    local numeric = tonumber(value)
    return numeric ~= nil and numeric > 0
end

function Api:login(email, password)
    local account = self.settings:account()
    if not account.vlibsid then
        local ok, err = self:getInitialSession()
        if not ok then return nil, err end
    end
    local body, boundary = multipart{
        email = email,
        passwd = password,
        keepalive = "1",
    }
    local response, err = self:requestOk{
        url = self.BASE .. "/login_do.php",
        method = "POST",
        source = ltn12.source.string(body),
        headers = self:headers({
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
            ["Content-Length"] = tostring(#body),
            ["Origin"] = self.BASE,
            ["Referer"] = self.BASE .. "/login.php?goto=web.htm",
            ["X-KB-FROM"] = self.CLIENT_VERSION .. " POST /login.php",
        }),
    }
    body = nil
    if not response then return nil, err end

    -- The web login endpoint uses HTTP 200 for both successful and failed
    -- authentication. Its current browser client checks the JSON `uin` field
    -- for success and shows `msg` on failure, so an HTTP status alone cannot
    -- be treated as a successful login.
    local decoded_ok, login_info = pcall(JSON.decode, response.body or "")
    if not decoded_ok or type(login_info) ~= "table" then login_info = nil end

    local set_cookie = Util.header(response.headers, "set-cookie")
    local key = Util.cookieValue(set_cookie, "KBSKEY")
    local refreshed_sid = Util.cookieValue(set_cookie, "VLIBSID")
    local has_uin = login_info and hasValidUin(login_info.uin) or false
    local response_code = login_info and tonumber(login_info.ret) or nil
    local message_id = login_info and Util.cleanMessage(login_info.msgid, 32) or ""

    -- Lua considers numeric zero truthy. KOOBONE uses `uin: 0` (together
    -- with `ret: -1`) for rejected credentials, so never test this field by
    -- truthiness alone as the site's JavaScript does.
    if login_info and (response_code and response_code < 0 or
            login_info.uin ~= nil and not has_uin) then
        local message = Util.cleanMessage(
            login_info.msg or login_info.message or login_info.error, 180)
        return nil, message ~= "" and message or "登录失败，请检查邮箱和密码"
    end

    if login_info and not has_uin then
        local message = Util.cleanMessage(
            login_info.msg or login_info.message or login_info.error, 180)
        if message ~= "" then return nil, message end
        if message_id == "e499" then
            return nil, "服务器拒绝了当前客户端请求（e499）"
        elseif message_id ~= "" then
            return nil, "登录失败（服务器代码：" .. message_id .. "）"
        end
    end

    -- The current endpoint can return the authenticated session key in the
    -- JSON `skey` field instead of a KBSKEY Set-Cookie header. Treat it as the
    -- same session secret only after a positive UIN has confirmed success.
    if not key and has_uin then
        local response_key = Util.trim(login_info.skey)
        if response_key ~= "" then key = response_key end
    end

    -- Newer sessions may authenticate the existing VLIBSID without issuing a
    -- KBSKEY. Keep accepting KBSKEY for the legacy flow, but let Auth:login()
    -- verify either form immediately through /uinfo.php before it is trusted.
    if not has_uin and not key then
        return nil, login_info and "登录失败，请检查邮箱和密码" or
            "服务器返回了无法识别的登录响应"
    end

    if refreshed_sid then account.vlibsid = refreshed_sid end
    if key then account.kbskey = key end
    self.settings:flush()
    return true, login_info
end

function Api:userInfo()
    local data, err = self:requestJson{
        url = self.BASE .. "/uinfo.php?v=web&ver=" .. self.WEB_VERSION,
        method = "GET",
        headers = self:headers(),
    }
    if not data then return nil, err end
    if not data.uin then return nil, "登录状态已失效或用户资料无效" end
    return data
end

function Api:library(limit, page)
    if self.auth then
        local ok, err = self.auth:restore()
        if not ok then return nil, err end
    end
    local account = self.settings:account()
    if not account.uin or not account.sess_key then return nil, "尚未连接 KOOBONE" end
    limit = math.floor(tonumber(limit) or 49)
    page = math.floor(tonumber(page) or 1)
    if limit < 1 then limit = 49 end
    if page < 1 then page = 1 end
    local url = string.format("%s/vol_list.php?u=%s&by=time&limit=%d&p=%d",
        self.API_BASE, tostring(account.uin), limit, page)
    local function fetch()
        return self:requestJson{
            url = url,
            method = "GET",
            headers = self:apiHeaders(account.sess_key),
            secure_credentials = true,
        }
    end
    local data, err = fetch()
    local expired = (data and tonumber(data.msgid) == 401)
        or (not data and tostring(err):match("^HTTP 401[%s$]"))
    if expired and self.auth and account.api_key then
        local ok, renew_err = self.auth:login(account.api_key)
        if not ok then return nil, renew_err end
        data, err = fetch()
    end
    if not data then return nil, err end
    if tonumber(data.msgid) == 401 then return nil, "登录状态已失效，请重新连接" end
    if type(data.data) ~= "table" then return nil, "书库响应无效或登录已过期" end
    return data
end

function Api:download(url, part_path, options)
    options = options or {}
    local handle, open_err = io.open(part_path, "wb")
    if not handle then return nil, open_err or "无法创建临时文件" end
    local received = 0
    local total_hint = tonumber(options.total) or 0
    local cancelled = false
    local sink_error
    local function sink(chunk, err)
        if chunk then
            if options.is_cancelled and options.is_cancelled() then
                cancelled = true
                return nil, "cancelled"
            end
            if tonumber(options.max_bytes) and received + #chunk > options.max_bytes then
                sink_error = "download exceeds size limit"
                return nil, sink_error
            end
            local ok, write_err = handle:write(chunk)
            if not ok then return nil, write_err end
            received = received + #chunk
            if options.on_progress then options.on_progress(received, total_hint) end
        end
        return 1
    end
    local response, err = self:request{
        url = url,
        method = "GET",
        include_session = false,
        redirect = true,
        headers = options.headers or {
            ["Accept"] = "*/*",
            ["User-Agent"] = self.USER_AGENT,
            ["X-KB-FROM"] = self.CLIENT_VERSION .. " WEB(" .. self.WEB_VERSION .. ") FETCH /web.htm",
            ["Referer"] = self.BASE .. "/",
        },
        sink = sink,
        block_timeout = socketutil.FILE_BLOCK_TIMEOUT,
        total_timeout = -1,
    }
    handle:close()
    if cancelled then return nil, "cancelled", received end
    if sink_error then return nil, sink_error, received end
    if not response then return nil, err, received end
    if response.code ~= 200 then return nil, "HTTP " .. tostring(response.code), received end
    if received <= 0 then return nil, "下载内容为空", received end
    return true, response.headers, received
end

return Api
