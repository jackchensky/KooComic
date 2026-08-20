local JSON = require("json")
local ltn12 = require("ltn12")
local socketutil = require("socketutil")
local http = require("socket.http")
local https = require("ssl.https")
local Util = require("koobone.util")

local Api = {}
Api.__index = Api

Api.BASE = "https://bookof.hk"
Api.WEB_VERSION = "7"
Api.CLIENT_VERSION = "KOOBONE/5.0.0"

local function transportFor(url)
    return tostring(url or ""):match("^https://") and https or http
end

function Api:new(settings)
    return setmetatable({ settings = assert(settings, "settings required") }, self)
end

function Api:headers(extra, include_session)
    local headers = {
        ["Accept"] = "*/*",
        ["User-Agent"] = "KOReader-KOOBONE/0.2",
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

function Api:request(options)
    options = options or {}
    local chunks
    if not options.sink then
        chunks = {}
        options.sink = socketutil.table_sink(chunks)
    end
    options.headers = options.headers or self:headers(nil, options.include_session)
    options.redirect = options.redirect == true
    socketutil:set_timeout(options.block_timeout or 20, options.total_timeout or 90)
    local transport = transportFor(options.url)
    local called, first, code, headers, status = pcall(transport.request, options)
    socketutil:reset_timeout()
    if not called then return nil, Util.cleanMessage(first) end
    code = tonumber(code)
    if not code then return nil, Util.cleanMessage(status or first or "network error") end
    local body = chunks and table.concat(chunks) or first
    return {
        code = code,
        headers = headers or {},
        status = status,
        body = body,
    }
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
    local set_cookie = Util.header(response.headers, "set-cookie")
    local key = Util.cookieValue(set_cookie, "KBSKEY")
    if not key then return nil, "登录成功响应中没有 KBSKEY" end
    local refreshed_sid = Util.cookieValue(set_cookie, "VLIBSID")
    if refreshed_sid then account.vlibsid = refreshed_sid end
    account.kbskey = key
    self.settings:flush()
    return true
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

function Api:library(limit)
    local account = self.settings:account()
    if not account.uin then return nil, "尚未登录" end
    local url = string.format("%s/vol_list.php?u=%s&by=time&limit=%d",
        self.BASE, tostring(account.uin), tonumber(limit) or 28)
    local data, err = self:requestJson{
        url = url,
        method = "GET",
        headers = self:headers(),
    }
    if not data then return nil, err end
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
            ["User-Agent"] = "KOReader-KOOBONE/0.2",
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
