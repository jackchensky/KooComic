package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path
package.preload["socket"] = function() return {} end
local http = {}
package.preload["socket.http"] = function() return http end
package.preload["socketutil"] = function() return {} end
package.preload["ltn12"] = function() return {} end
package.preload["json"] = function() return {} end
local params, cert, closed
package.preload["ssl.https"] = function()
    return { tcp = function(p)
        params = p
        return function()
            return {
                connect = function() return 1 end,
                getpeercertificate = function() return cert end,
                close = function() closed = true end,
            }
        end
    end }
end
local saved_open = io.open
io.open = function() return { close = function() end } end
local Api = require("koobone.api")
local api = Api:new({ account = function() return {} end })
local create = assert(api:secureCreate())
assert(params.verify == "peer" and params.cafile)
cert = { checkhost = function(_, host) return host == "www.koobone.com" end }
assert(create():connect("www.koobone.com", 443) == 1)
cert = { checkhost = function() return false end }
closed = false
assert(not create():connect("www.koobone.com", 443) and closed)
cert = { extensions = function() return { ["2.5.29.17"] = { dNSName = { "*.koobone.com" } } } end }
assert(create():connect("www.koobone.com", 443) == 1)
cert = { extensions = function() return { ["2.5.29.17"] = { dNSName = { "*.evil.com" } } } end }
assert(not create():connect("www.koobone.com", 443))
assert(not create():connect("other.example", 443))
http.PROXY = "http://localhost:8080"
assert(not api:secureCreate())
io.open = saved_open
print("secure transport spec: OK")
