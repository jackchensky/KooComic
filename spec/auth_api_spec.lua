package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local requests = {}
local responses = {}
local json_results = {}
local active_block_timeout
local sink_block_timeouts = {}

package.preload["socket"] = function()
    return { gettime = function() return os.time() end }
end
package.preload["socket.http"] = function()
    return {
        request = function(options)
            requests[#requests + 1] = options
            local response = assert(table.remove(responses, 1), "missing fake response")
            if response.error then error(response.error) end
            if response.transport_error then
                if options.sink and response.body then options.sink(response.body) end
                return nil, response.transport_error
            end
            if options.sink and response.body then options.sink(response.body) end
            return 1, response.code, response.headers or {}, response.status or "OK"
        end,
    }
end
package.preload["ssl.https"] = function()
    return {
        request = function() error("ssl.https.request must not be called directly") end,
    }
end
package.preload["socketutil"] = function()
    return {
        set_timeout = function(_, block_timeout)
            active_block_timeout = block_timeout
        end,
        reset_timeout = function() active_block_timeout = nil end,
        table_sink = function(target)
            sink_block_timeouts[#sink_block_timeouts + 1] = active_block_timeout
            return function(chunk)
                if chunk then target[#target + 1] = chunk end
                return 1
            end
        end,
    }
end
package.preload["ltn12"] = function()
    return { source = { string = function(value) return value end } }
end
package.preload["json"] = function()
    return {
        decode = function()
            local result = table.remove(json_results, 1)
            if result == "decode-error" then error("invalid json") end
            return result or {}
        end,
    }
end

local Api = require("koobone.api")

local account = {}
local flush_count = 0
local settings = {
    account = function() return account end,
    flush = function() flush_count = flush_count + 1 end,
}
local api = Api:new(settings)

-- Current server behaviour: /login.php creates VLIBSID.
responses[#responses + 1] = {
    code = 200,
    headers = { ["Set-Cookie"] = "VLIBSID=session-one; Path=/; HttpOnly" },
}
local ok, err = api:getInitialSession()
assert(ok == true, err)
assert(requests[1].url == "https://bookof.hk/login.php?goto=web.htm")
assert(requests[1].headers.Cookie == nil)
assert(requests[1].headers["User-Agent"]:match("^Mozilla/5%.0"))
assert(account.vlibsid == "session-one")
assert(flush_count == 1)

-- If /login.php changes, accept VLIBSID from the root 302 response.
account.vlibsid = nil
responses[#responses + 1] = { code = 200, headers = {} }
responses[#responses + 1] = {
    code = 302,
    headers = { ["set-cookie"] = "VLIBSID=session-two; Path=/" },
    status = "Found",
}
ok, err = api:getInitialSession()
assert(ok == true, err)
assert(requests[2].url == "https://bookof.hk/login.php?goto=web.htm")
assert(requests[3].url == "https://bookof.hk/")
assert(account.vlibsid == "session-two")

-- A successful login may rotate VLIBSID while returning KBSKEY.
json_results[#json_results + 1] = { uin = 42 }
responses[#responses + 1] = {
    code = 200,
    body = [[{"uin":42}]],
    headers = {
        ["set-cookie"] = {
            "VLIBSID=session-three; Path=/",
            "KBSKEY=login-key; Path=/; HttpOnly",
        },
    },
}
ok, err = api:login("reader@example.test", "test-password")
assert(ok == true, err)
assert(requests[4].url == "https://bookof.hk/login_do.php")
assert(requests[4].headers.Cookie == "VLIBSID=session-two")
assert(account.vlibsid == "session-three")
assert(account.kbskey == "login-key")

-- HTTP 200 is also used for rejected credentials. Surface the sanitized
-- server message instead of misreporting a missing KBSKEY.
json_results[#json_results + 1] = {
    ret = -1,
    msg = "邮箱地址错误或密码错误。",
    msgid = 501,
    uin = 0,
    skey = "",
}
responses[#responses + 1] = {
    code = 200,
    body = [[{"ret":-1,"msg":"邮箱地址错误或密码错误。","msgid":501,"uin":0,"skey":""}]],
    headers = {},
}
ok, err = api:login("reader@example.test", "wrong-password")
assert(ok == nil)
assert(err == "邮箱地址错误或密码错误。")
assert(account.vlibsid == "session-three")
assert(account.kbskey == "login-key")

-- Current login responses may return the session secret as JSON `skey`
-- instead of issuing a KBSKEY cookie. Preserve it for authenticated requests.
account.kbskey = nil
json_results[#json_results + 1] = { ret = 0, uin = 84, skey = "json-login-key" }
responses[#responses + 1] = {
    code = 200,
    body = [[{"ret":0,"uin":84,"skey":"json-login-key"}]],
    headers = { ["set-cookie"] = "VLIBSID=session-four; Path=/; HttpOnly" },
}
ok, err = api:login("reader@example.test", "test-password")
assert(ok == true, err)
assert(account.vlibsid == "session-four")
assert(account.kbskey == "json-login-key")

-- VLIBSID-only success is also accepted; Auth:login immediately verifies it
-- through /uinfo.php before treating the account as logged in.
account.kbskey = nil
json_results[#json_results + 1] = { ret = 0, uin = 126, skey = "" }
responses[#responses + 1] = {
    code = 200,
    body = [[{"ret":0,"uin":126,"skey":""}]],
    headers = { ["set-cookie"] = "VLIBSID=session-five; Path=/; HttpOnly" },
}
ok, err = api:login("reader@example.test", "test-password")
assert(ok == true, err)
assert(account.vlibsid == "session-five")
assert(account.kbskey == nil)

-- bookof.hk uses e499 when it rejects a client before checking credentials.
-- Surface that condition explicitly instead of calling it a password error.
json_results[#json_results + 1] = { msgid = "e499" }
responses[#responses + 1] = {
    code = 200,
    body = [[{"msgid":"e499"}]],
    headers = {},
}
ok, err = api:login("reader@example.test", "test-password")
assert(ok == nil)
assert(err == "服务器拒绝了当前客户端请求（e499）")

-- Invalid JSON without a legacy success cookie must not become a session.
json_results[#json_results + 1] = "decode-error"
responses[#responses + 1] = {
    code = 200,
    body = "not-json",
    headers = {},
}
ok, err = api:login("reader@example.test", "test-password")
assert(ok == nil)
assert(err == "服务器返回了无法识别的登录响应")

-- A legacy cookie session cannot be used as an API-key session.
local Auth = require("koobone.auth")
account.uin = 126
local auth = Auth:new(settings, api)
assert(auth:hasSession() == false)

-- A buffered GET gets a fresh sink and one retry after a socket wait error.
-- KOReader still routes HTTPS through socket.http for Kindle compatibility.
responses[#responses + 1] = { transport_error = "wantread", body = "partial" }
responses[#responses + 1] = { code = 200, body = "complete" }
local before = #requests
local response, request_err = api:request{
    url = "https://download.example.test/book.epub",
    method = "GET",
    include_session = false,
}
assert(response and response.body == "complete", request_err)
assert(#requests == before + 2)
assert(requests[before + 1].url == "https://download.example.test/book.epub")
assert(requests[before + 2].url == "https://download.example.test/book.epub")
assert(sink_block_timeouts[#sink_block_timeouts] == 20)

-- A repeated failure remains visible on screen with the safe host and retry
-- count; it never includes URL query parameters or account credentials.
responses[#responses + 1] = { transport_error = "wantread" }
responses[#responses + 1] = { transport_error = "wantread" }
before = #requests
response, request_err = api:request{
    url = "https://bookof.hk/uinfo.php?token=secret-test-value",
    method = "GET",
}
assert(response == nil)
assert(#requests == before + 2)
assert(request_err:find("wantread", 1, true))
assert(request_err:find("bookof.hk", 1, true))
assert(request_err:find("已重试一次", 1, true))
assert(not request_err:find("secret-test-value", 1, true))

-- POST and streamed downloads are not retried: their source or partial file
-- cannot safely be replayed by this generic request helper.
responses[#responses + 1] = { transport_error = "wantread" }
before = #requests
response, request_err = api:request{
    url = "https://bookof.hk/login_do.php",
    method = "POST",
    source = "test-body",
}
assert(response == nil and #requests == before + 1)
assert(request_err:find("未自动重试", 1, true))

responses[#responses + 1] = { transport_error = "wantread", body = "partial" }
before = #requests
response, request_err = api:request{
    url = "https://download.example.test/book.epub",
    method = "GET",
    sink = function() return 1 end,
}
assert(response == nil and #requests == before + 1)
assert(request_err:find("未自动重试", 1, true))

print("auth API spec: OK")
