package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local requests, replies, decoded = {}, {}, {}
package.preload["socket"] = function() return { gettime = function() return os.time() end } end
package.preload["socket.http"] = function()
    return { request = function(options)
        requests[#requests + 1] = options
        local reply = assert(table.remove(replies, 1), "missing mocked response")
        if reply.error then return nil, reply.error end
        if options.sink then options.sink("mock body") end
        return 1, reply.code, {}, reply.status or "OK"
    end }
end
package.preload["socketutil"] = function()
    return {
        set_timeout = function() end, reset_timeout = function() end,
        table_sink = function(chunks) return function(chunk) if chunk then chunks[#chunks+1] = chunk end return 1 end end,
    }
end
package.preload["ltn12"] = function() return { source = { string = function(s) return s end } } end
package.preload["json"] = function() return { decode = function() return assert(table.remove(decoded, 1)) end } end
local Api = require("koobone.api")
local Auth = require("koobone.auth")
local account = { vlibsid = "old-session", uin = 7 }
local settings = { account = function() return account end, flush = function() end }
local api = Api:new(settings)
-- The transport itself is covered separately; these tests exercise protocol
-- behavior without opening a network connection or requiring a CA bundle.
api.secureCreate = function() return function() end end
local auth = Auth:new(settings, api)

local ok, err, needs_login = auth:restore()
assert(not ok and needs_login and account.vlibsid == "old-session")

replies[#replies+1] = { code = 200 }
decoded[#decoded+1] = { msgid = 0, uin = 42, sess_key = "temporary-session", skey_exp = os.time() + 5000, nick = "Reader" }
ok, err = auth:login("key-for-test")
assert(ok, err)
assert(account.api_key == "key-for-test" and account.sess_key == "temporary-session")
assert(requests[1].url == "https://www.koobone.com/uinfo.php")
assert(requests[1].headers["X-KB-INFO"] == "key-for-test")
assert(requests[1].redirect == false)

replies[#replies+1] = { code = 200 }
decoded[#decoded+1] = { data = {} }
local shelf = assert(api:library(28))
assert(type(shelf.data) == "table")
assert(requests[2].headers["X-KB-INFO"] == "temporary-session")
assert(requests[2].url:match("^https://www%.koobone%.com/vol_list%.php"))

-- A rejected replacement key never overwrites the existing credentials.
replies[#replies+1] = { code = 200 }
decoded[#decoded+1] = { msgid = 401 }
ok, err = auth:login("invalid-test-key")
assert(not ok and err:find("无效", 1, true))
assert(account.api_key == "key-for-test" and account.sess_key == "temporary-session")

-- A session expired on the server is renewed once and the shelf is retried.
replies[#replies+1] = { code = 200 }
decoded[#decoded+1] = { msgid = 401 }
replies[#replies+1] = { code = 200 }
decoded[#decoded+1] = { msgid = 0, uin = 42, sess_key = "renewed-session", skey_exp = os.time() + 5000 }
replies[#replies+1] = { code = 200 }
decoded[#decoded+1] = { data = {} }
assert(api:library(28))
assert(requests[4].headers["X-KB-INFO"] == "temporary-session")
assert(requests[5].headers["X-KB-INFO"] == "key-for-test")
assert(requests[6].headers["X-KB-INFO"] == "renewed-session")

-- An outage during renewal must preserve local credentials and not ask for
-- a new key as though the user had entered an invalid one.
account.skey_exp = os.time() - 1
replies[#replies+1] = { code = 503 }
ok, err, needs_login = auth:restore()
assert(not ok and not needs_login and err:find("503", 1, true))
assert(account.api_key == "key-for-test" and account.sess_key == "renewed-session")

print("API key auth spec: OK")
