package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local files = {
    ["/settings/koobone.lua"] = {
        data = {
            schema_version = 2,
            account = {
                email = "reader@example.test",
                password = "local-test-only",
                remember_password = true,
                vlibsid = "session-a",
                kbskey = "session-b",
                nick = "Reader",
            },
            download = { records = { one = { state = "complete" } } },
            update = { auto_check_enabled = true },
        },
    },
    ["/settings/koocomic.lua"] = {},
}

package.preload["luasettings"] = function()
    return {
        open = function(_, path)
            files[path] = files[path] or {}
            return {
                readSetting = function(_, key) return files[path][key] end,
                saveSetting = function(_, key, value) files[path][key] = value end,
                flush = function() end,
            }
        end,
    }
end

local Settings = require("koobone.settings")
local settings = Settings:new("/settings/koocomic.lua", "/settings/koobone.lua")

assert(settings:account().email == "reader@example.test")
assert(settings:account().nick == "Reader")
assert(settings:account().remember_password == true)
assert(settings:account().password == "local-test-only")
assert(settings:ui().portrait_columns == 4)
assert(settings:ui().portrait_rows == 3)
assert(settings:ui().text_size == "large")
assert(settings.data.schema_version == 5)
assert(settings:ui().quick_filters.works == true)
assert(settings:ui().quick_filters.downloaded == true)
assert(settings:ui().quick_filters.not_downloaded == true)
assert(settings:ui().quick_filters.reading == false)
assert(type(settings:download().legacy_directories) == "table")
assert(files["/settings/koobone.lua"].data.account.nick == "Reader")
assert(files["/settings/koocomic.lua"].data.account.nick == "Reader")

-- New installations opt in to the lightweight daily version check, while an
-- existing user's explicit choice to turn it off must remain untouched.
local fresh = Settings:new("/settings/fresh.lua")
assert(fresh:update().auto_check_enabled == true)
assert(fresh:ui().portrait_columns == 4 and fresh:ui().portrait_rows == 3)
assert(fresh:ui().quick_filters.works == true)

files["/settings/existing.lua"] = {
    data = {
        schema_version = 3,
        update = { auto_check_enabled = false },
        ui = { portrait_columns = 3, portrait_rows = 2 },
    },
}
local existing = Settings:new("/settings/existing.lua")
assert(existing:update().auto_check_enabled == false)
assert(existing:ui().portrait_columns == 4 and existing:ui().portrait_rows == 3)

print("settings migration spec: OK")
