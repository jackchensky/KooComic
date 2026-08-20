package.path = "./koobone.koplugin/?.lua;./koobone.koplugin/?/init.lua;" .. package.path

local requests = {}
local responses = {}

package.preload["socket"] = function()
    return { gettime = function() return os.time() end }
end
package.preload["socket.http"] = function()
    return { request = function() error("unexpected HTTP request") end }
end
package.preload["ssl.https"] = function()
    return {
        request = function(options)
            requests[#requests + 1] = options
            local response = assert(table.remove(responses, 1), "missing fake response")
            if response.error then error(response.error) end
            if options.sink and response.body then options.sink(response.body) end
            return 1, response.code, response.headers or {}, response.status or "OK"
        end,
    }
end
package.preload["socketutil"] = function()
    return {
        set_timeout = function() end,
        reset_timeout = function() end,
        table_sink = function(target)
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
    return { decode = function() return {} end }
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
responses[#responses + 1] = {
    code = 200,
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

print("auth API spec: OK")
