package.path = "./koobone.koplugin/?.lua;./koobone.koplugin/?/init.lua;" .. package.path

local function class()
    local object = {}
    function object:extend(fields)
        fields = fields or {}
        setmetatable(fields, { __index = self })
        return fields
    end
    function object:new(fields)
        fields = fields or {}
        setmetatable(fields, { __index = self })
        return fields
    end
    return object
end

local Widget = class()
local noop_widget_modules = {
    "ui/widget/buttondialog",
    "ui/widget/checkbutton",
    "ui/widget/confirmbox",
    "ui/widget/infomessage",
    "ui/widget/menu",
    "ui/widget/multiinputdialog",
    "ui/widget/buttontable",
    "ui/widget/container/centercontainer",
    "ui/widget/container/framecontainer",
    "ui/widget/container/inputcontainer",
    "ui/widget/progresswidget",
    "ui/widget/textboxwidget",
    "ui/widget/verticalgroup",
    "ui/widget/verticalspan",
}
for _, name in ipairs(noop_widget_modules) do
    package.preload[name] = function() return Widget end
end
package.preload["ui/widget/container/widgetcontainer"] = function() return Widget end

package.preload["datastorage"] = function()
    return {
        getSettingsDir = function() return "/tmp" end,
        getDataDir = function() return "/tmp" end,
        getFullDataDir = function() return "/tmp/koreader" end,
    }
end
package.preload["ui/network/manager"] = function()
    return {
        runWhenOnline = function(_, callback) callback() end,
        isConnected = function() return false end,
    }
end
package.preload["ui/uimanager"] = function()
    return {
        scheduleIn = function() end,
        show = function() end,
        close = function() end,
        setDirty = function() end,
        forceRePaint = function() end,
    }
end
package.preload["apps/reader/readerui"] = function()
    return { showReader = function() end }
end
package.preload["socket"] = function()
    return { gettime = function() return os.time() end }
end
package.preload["socket.http"] = function()
    return { request = function() return nil, 500, {}, "test" end }
end
package.preload["ssl.https"] = function()
    return { request = function() return nil, 500, {}, "test" end }
end
package.preload["socketutil"] = function()
    return {
        FILE_BLOCK_TIMEOUT = 15,
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
    return { source = { string = function() return function() end end } }
end
package.preload["json"] = function()
    return { decode = function() return {} end }
end
package.preload["ffi/util"] = function()
    return {
        dirname = function() return "/tmp" end,
        joinPath = function(left, right) return left .. "/" .. right end,
        purgeDir = function() return true end,
    }
end
package.preload["libs/libkoreader-lfs"] = function()
    return {
        attributes = function() return nil end,
        mkdir = function() return true end,
    }
end
package.preload["ffi/archiver"] = function()
    return { Reader = { new = function() return {} end } }
end
package.preload["ffi/sha2"] = function()
    return { sha256 = function() return function() return "" end end }
end
package.preload["ffi/blitbuffer"] = function()
    return { COLOR_BLACK = 0, COLOR_WHITE = 1 }
end
package.preload["device"] = function()
    return {
        screen = {
            getSize = function() return { w = 600, h = 800 } end,
            getWidth = function() return 600 end,
            getHeight = function() return 800 end,
            scaleBySize = function(_, value) return value end,
        },
    }
end
package.preload["ui/font"] = function()
    return { getFace = function() return {} end }
end
package.preload["ui/geometry"] = function()
    return { new = function(_, value) return value end }
end
package.preload["ui/size"] = function()
    return {
        padding = { small = 2, large = 8 },
        margin = { tiny = 1 },
        border = { window = 1 },
        radius = { window = 2 },
    }
end
package.preload["version"] = function()
    return { getShortVersion = function() return "test" end }
end
package.preload["luasettings"] = function()
    local handle = {
        readSetting = function() return nil end,
        saveSetting = function() end,
        flush = function() end,
    }
    return { open = function() return handle end }
end

G_reader_settings = {
    readSetting = function() return "/tmp" end,
}

local Plugin = dofile("koobone.koplugin/main.lua")
assert(Plugin.version == "0.2.0")
local instance = Plugin:new{
    ui = { menu = { registerToMainMenu = function() end } },
}
instance:init()
assert(instance.settings ~= nil)
assert(instance.downloader ~= nil)
assert(instance.updater ~= nil)

print("plugin load spec: OK")
