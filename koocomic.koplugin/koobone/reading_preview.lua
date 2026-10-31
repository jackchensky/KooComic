-- SPDX-License-Identifier: AGPL-3.0-only
-- Keeps only the two latest low-resolution page previews for a downloaded
-- KooComic title. Failures are intentionally silent: reading and the shelf
-- must keep working on older KOReader builds without the required image APIs.
local DataStorage = require("datastorage")
local ffiUtil = require("ffi/util")
local lfs = require("libs/libkoreader-lfs")

local ReadingPreview = {}
ReadingPreview.__index = ReadingPreview

local PREVIEW_W, PREVIEW_H = 180, 248

local function ensureDirectory(path)
    if lfs.attributes(path, "mode") == "directory" then return true end
    local ok, util = pcall(require, "util")
    if ok and util and util.makePath then return util.makePath(path) end
    return lfs.mkdir(path)
end

local function isFile(path)
    return type(path) == "string" and lfs.attributes(path, "mode") == "file"
end

local function hash(value)
    local number = 5381
    value = tostring(value or "")
    for index = 1, #value do
        number = (number * 33 + value:byte(index)) % 4294967296
    end
    return string.format("%08x", number)
end

function ReadingPreview:new(storage)
    local directory = ffiUtil.joinPath(DataStorage:getDataDir(), "cache")
    directory = ffiUtil.joinPath(directory, "koocomic-reading-previews")
    ensureDirectory(directory)
    return setmetatable({
        storage = assert(storage, "storage required"),
        directory = directory,
        last_tokens = {},
    }, self)
end

function ReadingPreview:_paths(key)
    local base = ffiUtil.joinPath(self.directory, hash(key))
    return base .. "-left.png", base .. "-right.png", base .. "-next.png"
end

function ReadingPreview:paths(item)
    local key = self.storage:itemKey(item)
    local left, right = self:_paths(key)
    return isFile(left) and left or nil, isFile(right) and right or nil
end

function ReadingPreview:keyForDocument(path)
    if type(path) ~= "string" or path == "" then return nil end
    for key, value in pairs(self.storage.settings:download().records or {}) do
        if type(value) == "table" and value.path == path and isFile(path) then return key end
    end
end

function ReadingPreview:clear(key)
    if key == nil then return end
    local left, right, temporary = self:_paths(key)
    os.remove(left); os.remove(right); os.remove(temporary)
    self.last_tokens[key] = nil
end

function ReadingPreview:_capture(key, token, ui, document_path)
    if not ui or not ui.document or ui.document.file ~= document_path then return end
    local ok_device, Device = pcall(require, "device")
    local ok_bb, Blitbuffer = pcall(require, "ffi/blitbuffer")
    local ok_render, RenderImage = pcall(require, "ffi/renderimage")
    if not ok_device or not ok_bb or not ok_render then return end
    local screen = Device.screen
    local screen_bb = screen and screen.bb
    if not screen_bb or type(screen_bb.getType) ~= "function" then return end

    local ok_manager, UIManager = pcall(require, "ui/uimanager")
    if ok_manager and type(UIManager.getTopmostVisibleWidget) == "function" then
        local top = UIManager:getTopmostVisibleWidget()
        if top and top ~= ui and top.name ~= "ReaderUI" then return end
    end

    local width = type(screen.getWidth) == "function" and screen:getWidth()
        or (screen:getSize() or {}).w
    local height = type(screen.getHeight) == "function" and screen:getHeight()
        or (screen:getSize() or {}).h
    width, height = tonumber(width), tonumber(height)
    if not width or not height or width < 2 or height < 2 then return end

    local ratio = PREVIEW_W / PREVIEW_H
    local crop_w, crop_h = math.floor(height * ratio + 0.5), height
    if crop_w > width then
        crop_w, crop_h = width, math.floor(width / ratio + 0.5)
    end
    local crop_x, crop_y = math.floor((width - crop_w) / 2), math.floor((height - crop_h) / 2)
    local crop, scaled
    local left, right, temporary = self:_paths(key)
    os.remove(temporary)
    local success = pcall(function()
        crop = Blitbuffer.new(crop_w, crop_h, screen_bb:getType())
        crop:blitFrom(screen_bb, 0, 0, crop_x, crop_y, crop_w, crop_h)
        scaled = RenderImage:scaleBlitBuffer(crop, PREVIEW_W, PREVIEW_H, true)
        crop = nil -- ownership was transferred to scaleBlitBuffer
        local wrote, write_err = scaled:writePNG(temporary)
        if not wrote then error(write_err or "cannot write reading preview") end
    end)
    if crop and crop.free then crop:free() end
    if scaled and scaled.free then scaled:free() end
    if not success or not isFile(temporary) then
        os.remove(temporary)
        return
    end

    if isFile(right) then
        os.remove(left)
        if not os.rename(right, left) then os.remove(right) end
    end
    os.remove(right)
    if not os.rename(temporary, right) then
        os.remove(temporary)
        return
    end
    self.last_tokens[key] = token
end

function ReadingPreview:queue(ui, token)
    local document_path = ui and ui.document and ui.document.file
    local key = self:keyForDocument(document_path)
    if not key then return end
    token = tostring(token or "")
    if token ~= "" and self.last_tokens[key] == token then return end

    local ok, UIManager = pcall(require, "ui/uimanager")
    if not ok or type(UIManager.scheduleIn) ~= "function" then return end
    if self.pending and type(UIManager.unschedule) == "function" then
        UIManager:unschedule(self.pending)
    end
    self.pending = function()
        self.pending = nil
        self:_capture(key, token, ui, document_path)
    end
    -- Avoid competing with page rendering. Rapid page turns replace this job,
    -- so only a page that remains visible is encoded.
    UIManager:scheduleIn(1.5, self.pending)
end

function ReadingPreview:close()
    local ok, UIManager = pcall(require, "ui/uimanager")
    if ok and self.pending and type(UIManager.unschedule) == "function" then
        UIManager:unschedule(self.pending)
    end
    self.pending = nil
end

return ReadingPreview
