package.path = "./koocomic.koplugin/?.lua;./koocomic.koplugin/?/init.lua;" .. package.path

local shown, closed, jobs = {}, {}, {}
local ui = {
    show = function(_, widget) shown[#shown + 1] = widget end,
    close = function(_, widget) closed[#closed + 1] = widget end,
    scheduleIn = function(_, delay, callback) jobs[#jobs + 1] = { delay = delay, run = callback } end,
}
local function widget(kind)
    return { new = function(_, value) value.kind = kind; return value end }
end
package.preload["ui/uimanager"] = function() return ui end
package.preload["ui/widget/infomessage"] = function() return widget("info") end
package.preload["ui/widget/confirmbox"] = function() return widget("confirm") end
package.preload["ui/widget/textviewer"] = function() return widget("viewer") end
package.preload["koobone.ui.download_dialog"] = function() return widget("download") end
package.preload["socket"] = function() return {} end
local UpdaterUI = require("koobone.ui.updater")
local Util = require("koobone.util")
assert(Util.cleanMessage(string.rep("更", 100), 10) == "更更...")
local release = { version = "0.5.0", size = 100, summary = "更新摘要", notes = string.rep("更新内容", 100) }
local defer_count, marked, installed = 0, 0, 0
local updater = {
    current_version = "0.4.1",
    isConfigured = function() return true end,
    check = function() return release, true end,
    shouldPrompt = function() return true end,
    markPromptShown = function() marked = marked + 1 end,
    deferPrompt = function() defer_count = defer_count + 1 end,
}
local view = UpdaterUI:new{ updater = updater, downloader = {} }
view.install = function(_, value) assert(value == release); installed = installed + 1 end
local function next_job() local job = assert(table.remove(jobs, 1)); job.run(); return job.delay end

-- Manual check must close its waiting modal before showing any result.
view:check(true)
assert(#shown == 1 and shown[1].kind == "info" and shown[1].timeout == nil)
assert(next_job() == 0.15)
assert(#closed == 1 and closed[1] == shown[1] and #shown == 1)
assert(next_job() == 0.1)
assert(shown[2].kind == "viewer" and shown[2].text:find(release.notes, 1, true))
assert(shown[2].buttons_table[1][1].text == "稍后更新")
assert(shown[2].buttons_table[1][2].text == "立即更新")
shown[2].buttons_table[1][1].callback()
assert(closed[2] == shown[2] and defer_count == 0)

-- Automatic reminders have no waiting modal, and only explicit Later counts.
view:check(false)
next_job(); next_job()
assert(shown[3].kind == "viewer" and marked == 1)
shown[3].buttons_table[1][1].callback()
assert(defer_count == 1)
view:showAvailable(release, true)
shown[4].buttons_table[1][2].callback()
assert(installed == 1 and defer_count == 1)

-- An exception must close the waiting modal and produce a user-facing error.
updater.check = function() error("test failure") end
view:check(true)
local waiting = shown[#shown]
next_job()
assert(closed[#closed] == waiting)
next_job()
assert(shown[#shown].kind == "info" and shown[#shown].text:find("失败", 1, true))
print("updater UI spec: OK")
