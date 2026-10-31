-- KooComic·可漫 for KOReader
-- SPDX-License-Identifier: AGPL-3.0-only
--
-- The plugin only accesses the library of the account that signs in. Network
-- logs must never contain passwords, session cookies, or signed download URLs.

local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")

local AccountUI = require("koobone.ui.account")
local Api = require("koobone.api")
local Auth = require("koobone.auth")
local Bookshelf = require("koobone.ui.bookshelf")
local CoverCache = require("koobone.cover_cache")
local Downloader = require("koobone.downloader")
local DownloadsUI = require("koobone.ui.downloads")
local Library = require("koobone.library")
local LoginDialog = require("koobone.ui.login_dialog")
local PluginVersion = require("koobone.plugin_version")
local ReadingPreview = require("koobone.reading_preview")
local Settings = require("koobone.settings")
local SettingsUI = require("koobone.ui.settings")
local Storage = require("koobone.storage")
local Updater = require("koobone.updater")
local UpdaterUI = require("koobone.ui.updater")

local KooComic = WidgetContainer:extend{
    name = "koocomic",
    is_doc_only = false,
    version = PluginVersion.version,
    settings_file = DataStorage:getSettingsDir() .. "/koocomic.lua",
    legacy_settings_file = DataStorage:getSettingsDir() .. "/koobone.lua",
}

function KooComic:init()
    math.randomseed(os.time())
    self.settings = Settings:new(self.settings_file, self.legacy_settings_file)
    self.api = Api:new(self.settings)
    self.auth = Auth:new(self.settings, self.api)
    self.storage = Storage:new(self.settings)
    self.reading_preview = ReadingPreview:new(self.storage)
    self.storage:setRecordRemovedCallback(function(key)
        self.reading_preview:clear(key)
    end)
    self.cover_cache = CoverCache:new(self.api)
    self.library = Library:new(self.api, self.storage)
    self.downloader = Downloader:new{
        api = self.api,
        library = self.library,
        storage = self.storage,
        on_changed = function()
            if self.bookshelf and self.bookshelf.menu and #self.library.items > 0 then
                self.bookshelf:show(self.library.items)
            end
        end,
    }
    self.updater = Updater:new{
        settings = self.settings,
        api = self.api,
        current_version = self.version,
        manifest_url = PluginVersion.manifest_url,
        release_prefix = PluginVersion.release_prefix,
    }
    self.updater_ui = UpdaterUI:new{
        updater = self.updater,
        downloader = self.downloader,
    }
    self.bookshelf = Bookshelf:new{
        library = self.library,
        storage = self.storage,
        downloader = self.downloader,
        settings = self.settings,
        cover_cache = self.cover_cache,
        reading_preview = self.reading_preview,
        on_downloads = function() self:showDownloads() end,
        on_account = function() self:showAccount() end,
        on_settings = function() self:showSettings() end,
    }

    self.ui.menu:registerToMainMenu(self)
    self:scheduleAutomaticUpdateCheck()
    -- Only reaching the end of initialization confirms a just-installed copy
    -- can load and register successfully. The rollback backup survives until
    -- this point.
    self.updater:confirmInstalledUpdate()
end


function KooComic:_queueReadingPreview(token)
    if self.reading_preview and self.ui and self.ui.document then
        self.reading_preview:queue(self.ui, token)
    end
end

function KooComic:onReaderReady()
    local page = self.ui and self.ui.getCurrentPage and self.ui:getCurrentPage()
    self:_queueReadingPreview(page)
end

function KooComic:onPageUpdate(page)
    self:_queueReadingPreview(page)
end

function KooComic:onPosUpdate(pos, page)
    self:_queueReadingPreview(page or pos)
end

function KooComic:onCloseDocument()
    if self.reading_preview then self.reading_preview:close() end
end

function KooComic:addToMainMenu(menu_items)
    menu_items.koocomic = {
        text = "Koo可漫",
        sorting_hint = "tools",
        sub_item_table = {
            {
                text_func = function()
                    local nick = self.settings:account().nick
                    return nick and nick ~= "" and ("我的书架（" .. nick .. "）") or "我的书架"
                end,
                callback = function() self:openBookshelf() end,
            },
            {
                text = "下载管理",
                callback = function() self:showDownloads() end,
            },
            {
                text = "账号与登录",
                callback = function() self:showAccount() end,
            },
            {
                text = "版本与设置",
                callback = function() self:showSettings() end,
            },
            {
                text = "关于 KooComic·可漫",
                keep_menu_open = true,
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = "KooComic·可漫 for KOReader\nv" .. (PluginVersion.display_version or self.version) ..
                            "\n\n使用 KOOBONE 提供的 API Key 接口方案，连接用户自己的漫画书库、下载 EPUB 并在 KOReader 中阅读。" ..
                            "\n\n插件由 Jackchen 独立开发和维护，不是 KOOBONE 官方客户端；界面、功能、发布与支持由本项目负责。" ..
                            "\n\n用Koo可漫让你的KOOBONE漫画在Kindle上可以自在漫读。—— @Jackchen" ..
                            "\n\n许可证：AGPL-3.0-only",
                    })
                end,
            },
        },
    }
end

function KooComic:ensureOnline(callback)
    NetworkMgr:runWhenOnline(callback)
end

function KooComic:showLogin()
    self:ensureOnline(function()
        LoginDialog.show{
            auth = self.auth,
            settings = self.settings,
            on_success = function() self.bookshelf:refresh() end,
        }
    end)
end

function KooComic:openBookshelf()
    self:ensureOnline(function()
        UIManager:show(InfoMessage:new{ text = "正在验证登录状态……", timeout = 1 })
        UIManager:scheduleIn(0.15, function()
            local ok, err, needs_login = self.auth:restore()
            if ok then
                self.bookshelf:refresh()
            elseif needs_login then
                self:showLogin()
            else
                UIManager:show(InfoMessage:new{
                    text = "暂时无法验证登录状态，已保留当前会话：\n" .. tostring(err),
                })
            end
        end)
    end)
end

-- Conventional entry point used by SimpleUI/ZenUI style launchers.
function KooComic:launch()
    return self:openBookshelf()
end

function KooComic:showAccount()
    AccountUI.show{
        settings = self.settings,
        auth = self.auth,
        on_login = function() self:showLogin() end,
        on_logout = function()
            if self.bookshelf and self.bookshelf.menu then
                UIManager:close(self.bookshelf.menu)
                self.bookshelf.menu = nil
            end
        end,
        on_settings = function() self:showSettings() end,
    }
end

function KooComic:showDownloads()
    DownloadsUI.show(self.storage, self.downloader)
end

function KooComic:showSettings()
    SettingsUI.show{
        settings = self.settings,
        updater = self.updater,
        updater_ui = self.updater_ui,
        storage = self.storage,
        downloader = self.downloader,
        version = PluginVersion.display_version or self.version,
        on_ui_changed = function()
            if self.bookshelf and self.bookshelf.menu then self.bookshelf:show(self.library.items) end
        end,
    }
end

function KooComic:scheduleAutomaticUpdateCheck()
    UIManager:scheduleIn(5, function()
        if self.updater:shouldAutoCheck() and NetworkMgr:isConnected() then
            self.updater_ui:check(false)
        end
    end)
end

return KooComic
