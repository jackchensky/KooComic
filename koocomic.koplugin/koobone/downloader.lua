local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local DownloadDialog = require("koobone.ui.download_dialog")
local Util = require("koobone.util")

local Downloader = {}
Downloader.__index = Downloader

function Downloader:new(options)
    options = options or {}
    return setmetatable({
        api = assert(options.api, "api required"),
        library = assert(options.library, "library required"),
        storage = assert(options.storage, "storage required"),
        active = false,
        cancelled = false,
        on_changed = options.on_changed,
    }, self)
end

function Downloader:isActive()
    return self.active == true
end

function Downloader:open(path)
    ReaderUI:showReader(path)
end

function Downloader:_finishChanged()
    if self.on_changed then pcall(self.on_changed) end
end

function Downloader:download(item)
    if self.active then
        UIManager:show(InfoMessage:new{ text = "已有一个下载任务正在进行。" })
        return
    end
    local final_path = self.storage:itemPath(item)
    if self.storage:isDownloaded(item) then
        UIManager:show(ConfirmBox:new{
            text = "这本漫画已经下载完成。\n\n" .. final_path,
            cancel_text = "关闭",
            ok_text = "打开阅读",
            ok_callback = function() self:open(final_path) end,
        })
        return
    end

    self.active = true
    self.cancelled = false
    self.storage:record(item, "preparing")
    local dialog = DownloadDialog:new{
        title = item.vol_name or item.vol_series or "koo漫画",
        on_cancel = function() self.cancelled = true end,
    }
    dialog:show()

    UIManager:scheduleIn(0.15, function()
        dialog:setStage("正在刷新书库并获取最新下载地址……")
        local fresh, refresh_err = self.library:freshItem(item)
        if not fresh or not fresh.file_url or fresh.file_url == "" then
            self.active = false
            dialog:close()
            self.storage:record(item, "failed", { error = Util.cleanMessage(refresh_err or "没有下载地址") })
            UIManager:show(InfoMessage:new{
                text = "无法开始下载：\n" .. tostring(refresh_err or "没有可用下载地址"),
            })
            self:_finishChanged()
            return
        end

        local part_path = self.storage:partPath(fresh)
        final_path = self.storage:itemPath(fresh)
        local total = tonumber(fresh.file_size) or tonumber(item.file_size) or 0
        local started_at = Util.now()
        self.storage:record(fresh, "downloading", { bytes = 0, total = total })
        local ok, result, received = self.api:download(fresh.file_url, part_path, {
            total = total,
            is_cancelled = function() return self.cancelled end,
            on_progress = function(current, expected)
                local elapsed = math.max(0.001, Util.now() - started_at)
                local speed = current / elapsed
                local eta = expected > 0 and speed > 0 and (expected - current) / speed or nil
                dialog:setProgress{
                    stage = "正在下载 EPUB",
                    current = current,
                    total = expected,
                    speed = speed,
                    eta = eta,
                }
            end,
        })

        self.active = false
        if not ok then
            local cancelled = result == "cancelled" or self.cancelled
            dialog:close()
            self.storage:record(fresh, cancelled and "cancelled" or "failed", {
                bytes = tonumber(received) or 0,
                total = total,
                part_path = part_path,
                error = cancelled and nil or Util.cleanMessage(result),
            })
            UIManager:show(InfoMessage:new{
                text = cancelled and
                    "下载已取消，临时文件已保留。下次下载会重新开始。" or
                    ("下载失败，临时文件已保留：\n" .. tostring(result)),
            })
            self:_finishChanged()
            return
        end

        dialog:setStage("下载完成，正在保存文件……")
        local moved, move_err = os.rename(part_path, final_path)
        if not moved then
            dialog:close()
            self.storage:record(fresh, "failed", {
                bytes = tonumber(received) or 0,
                total = total,
                part_path = part_path,
                error = Util.cleanMessage(move_err),
            })
            UIManager:show(InfoMessage:new{ text = "保存文件失败：\n" .. tostring(move_err) })
            self:_finishChanged()
            return
        end

        self.storage:record(fresh, "complete", {
            bytes = tonumber(received) or 0,
            total = total,
            part_path = nil,
            error = nil,
        })
        dialog:close()
        self:_finishChanged()
        UIManager:show(ConfirmBox:new{
            text = "下载完成：\n" .. final_path,
            cancel_text = "稍后阅读",
            ok_text = "立即打开",
            ok_callback = function() self:open(final_path) end,
        })
    end)
end

return Downloader
