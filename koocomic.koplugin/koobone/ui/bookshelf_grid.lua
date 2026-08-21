local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Metrics = require("koobone.ui.metrics")

local Screen = Device.screen
local WHITE = Blitbuffer.COLOR_WHITE
local BLACK = Blitbuffer.COLOR_BLACK
local DARK_GRAY = Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_GRAY
local LIGHT_GRAY = Blitbuffer.COLOR_GRAY_E or Blitbuffer.COLOR_LIGHT_GRAY or Blitbuffer.COLOR_GRAY

local active_text_size = "large"

local function dp(value, minimum, maximum)
    return Metrics.dp(value, minimum, maximum)
end

local function face(name, size)
    return Metrics.face(name, size, active_text_size)
end

local OffsetContainer = WidgetContainer:extend{ x_off = 0, y_off = 0 }

function OffsetContainer:getSize()
    return self[1]:getSize()
end

function OffsetContainer:paintTo(bb, x, y)
    self[1]:paintTo(bb, x + self.x_off, y + self.y_off)
end

local TapBox = InputContainer:extend{
    dimen = nil,
    callback = nil,
    hold_callback = nil,
}

function TapBox:init()
    self.dimen = self.dimen or Geom:new{ w = 1, h = 1 }
    self.ges_events = {
        TapSelect = { GestureRange:new{ ges = "tap", range = self.dimen } },
        HoldSelect = { GestureRange:new{ ges = "hold", range = self.dimen } },
    }
end

function TapBox:getSize()
    return Geom:new{ w = self.dimen.w, h = self.dimen.h }
end

function TapBox:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    if self[1] then self[1]:paintTo(bb, x, y) end
end

function TapBox:onTapSelect()
    if self.callback then self.callback() end
    return true
end

function TapBox:onHoldSelect()
    if self.hold_callback then self.hold_callback() end
    return true
end

local function fixedFrame(width, height, options, child)
    options = options or {}
    local border = tonumber(options.bordersize) or 0
    local padding = tonumber(options.padding) or 0
    local inset = (border + padding) * 2
    return FrameContainer:new{
        width = width,
        height = height,
        bordersize = border,
        padding = padding,
        margin = 0,
        radius = options.radius or 0,
        background = options.background or WHITE,
        color = options.color or BLACK,
        CenterContainer:new{
            dimen = Geom:new{
                w = math.max(1, width - inset),
                h = math.max(1, height - inset),
            },
            child or Widget:new{ dimen = Geom:new{ w = 1, h = 1 } },
        },
    }
end

local function tappable(width, height, child, callback, options)
    options = options or {}
    local box = TapBox:new{
        dimen = Geom:new{ w = width, h = height },
        callback = callback,
        hold_callback = options.hold_callback,
    }
    box[1] = fixedFrame(width, height, {
        bordersize = options.bordersize or 0,
        background = options.background or WHITE,
        color = options.color or BLACK,
    }, child)
    return box
end

local function textBox(text, width, height, size, options)
    options = options or {}
    return TextBoxWidget:new{
        text = tostring(text or ""),
        face = face(options.face or "cfont", size),
        bold = options.bold == true,
        width = math.max(1, width),
        height = math.max(1, height),
        height_adjust = false,
        height_overflow_show_ellipsis = true,
        alignment = options.alignment or "center",
        fgcolor = options.fgcolor or BLACK,
    }
end

local function singleLine(text, width, height, size, options)
    options = options or {}
    return CenterContainer:new{
        dimen = Geom:new{ w = math.max(1, width), h = math.max(1, height) },
        TextWidget:new{
            text = tostring(text or ""),
            face = face(options.face or "cfont", size),
            bold = options.bold == true,
            fgcolor = options.fgcolor or BLACK,
        },
    }
end

local NavIcon = Widget:extend{ kind = "shelf", width = 1, height = 1, color = BLACK }

function NavIcon:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function NavIcon:paintTo(bb, x, y)
    local color = self.color or BLACK
    local w, h = self.width, self.height
    local line = math.max(2, dp(1))
    if self.kind == "shelf" then
        bb:paintBorder(x + line, y + line, w - line * 2, h - line * 2, line, color)
        local third = math.floor((w - line * 4) / 3)
        bb:paintRect(x + line * 2 + third, y + line * 2, line, h - line * 4, color)
        bb:paintRect(x + line * 2 + third * 2, y + line * 2, line, h - line * 4, color)
    elseif self.kind == "download" then
        local cx = x + math.floor(w / 2)
        bb:paintRect(cx - math.floor(line / 2), y + line, line, math.floor(h * 0.55), color)
        bb:paintRect(cx - line * 3, y + math.floor(h * 0.43), line * 3, line, color)
        bb:paintRect(cx, y + math.floor(h * 0.43), line * 3, line, color)
        bb:paintRect(x + line, y + h - line * 2, w - line * 2, line, color)
    elseif self.kind == "account" then
        local head = math.max(line * 3, math.floor(h * 0.30))
        bb:paintBorder(x + math.floor((w - head) / 2), y + line, head, head, line, color)
        bb:paintBorder(x + line * 2, y + head + line * 2, w - line * 4, h - head - line * 3, line, color)
    else
        for index = 0, 2 do
            local yy = y + line + index * math.floor((h - line * 2) / 3)
            bb:paintRect(x + line, yy, w - line * 2, line, color)
            local knob = index == 1 and math.floor(w * 0.66) or math.floor(w * 0.34)
            bb:paintRect(x + knob - line, yy - line, line * 3, line * 3, color)
        end
    end
end

local PlaceholderCover = WidgetContainer:extend{
    width = 1,
    height = 1,
    title = "",
    volume = "",
}

function PlaceholderCover:init()
    local inner_w = math.max(1, self.width - dp(12))
    local inner_h = math.max(1, math.floor(self.height * 0.34))
    self[1] = CenterContainer:new{
        dimen = Geom:new{ w = self.width, h = self.height },
        VerticalGroup:new{
            align = "center",
            textBox(self.title, inner_w, math.floor(inner_h * 0.62), 14, { bold = true }),
            textBox(self.volume, inner_w, math.floor(inner_h * 0.38), 10, {}),
        },
    }
end

function PlaceholderCover:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function PlaceholderCover:paintTo(bb, x, y)
    bb:paintRect(x, y, self.width, self.height, WHITE)
    local line_w = math.max(dp(8), math.floor(self.width * 0.08))
    local step = math.max(dp(4), math.floor(self.height / 90))
    for row = 0, self.height - 1, step do
        local diagonal_x = math.floor(row * self.width / math.max(1, self.height))
        bb:paintRect(x + diagonal_x, y + row, math.min(line_w, self.width - diagonal_x), step, LIGHT_GRAY)
        local reverse_x = self.width - diagonal_x - line_w
        if reverse_x >= 0 then
            bb:paintRect(x + reverse_x, y + row, math.min(line_w, self.width - reverse_x), step, LIGHT_GRAY)
        end
    end
    bb:paintBorder(x, y, self.width, self.height, dp(1), DARK_GRAY)
    self[1]:paintTo(bb, x, y)
end

local function coverImage(path, width, height)
    if not path or path == "" then return nil end
    local image
    local ok = pcall(function()
        image = ImageWidget:new{
            file = path,
            width = width,
            height = height,
            scale_factor = 0,
            file_do_cache = true,
        }
        image:getSize()
        image.width = nil
        image.height = nil
    end)
    if not ok or not image then
        if image and image.free then pcall(image.free, image) end
        return nil
    end
    return fixedFrame(width, height, {
        bordersize = dp(1),
        background = WHITE,
        color = DARK_GRAY,
    }, image)
end

local function itemTitle(item)
    return tostring(item.vol_name or item.vol_series or item.file_md5 or "未命名漫画")
end

local function itemAuthor(item)
    return tostring(item.vol_author or "未知作者")
end

local function itemVolume(item)
    local value = item.vol_index or item.volume or item.vol_no
    if value and tostring(value) ~= "" then return "卷 " .. tostring(value) end
    local pages = tonumber(item.count_page)
    return pages and pages > 0 and (tostring(pages) .. " 页") or "KOOBONE"
end

local function progressPercent(item)
    local current = tonumber(item.last_readpage) or 0
    local total = tonumber(item.count_page) or 0
    if total <= 0 or current <= 0 then return 0 end
    return math.max(0, math.min(100, math.floor(current / total * 100 + 0.5)))
end

local function badge(text, width, height)
    return fixedFrame(width, height, { background = BLACK, color = BLACK },
        TextWidget:new{
            text = text,
            face = face("smallinfofont", 10),
            bold = true,
            fgcolor = WHITE,
        })
end

local function bookCard(item, width, height, storage, callback)
    local title_h = dp(25)
    local author_h = dp(19)
    local gap = dp(2)
    local cover_h = math.max(dp(110), height - title_h - author_h - gap * 2)
    local cover_w = math.min(math.floor(width * 0.94), math.floor(cover_h * 0.70))
    local title = itemTitle(item)
    local cover = coverImage(item._koobone_cover_path, cover_w, cover_h)
        or PlaceholderCover:new{
            width = cover_w,
            height = cover_h,
            title = title,
            volume = itemVolume(item),
        }
    local cover_layers = OverlapGroup:new{
        dimen = Geom:new{ w = cover_w, h = cover_h },
        allow_mirroring = false,
        cover,
    }
    local downloaded = storage:isDownloaded(item)
    local partial = storage:partSize(item)
    local progress = progressPercent(item)
    local badge_text
    if downloaded then
        badge_text = "已下载"
    elseif partial > 0 then
        badge_text = "未完成"
    elseif progress > 0 then
        badge_text = tostring(progress) .. "%"
    end
    if badge_text then
        local badge_w = math.max(dp(42), #badge_text * dp(11))
        local badge_h = dp(24)
        cover_layers[#cover_layers + 1] = OffsetContainer:new{
            x_off = math.max(0, cover_w - badge_w - dp(4)),
            y_off = dp(4),
            badge(badge_text, badge_w, badge_h),
        }
    end

    local body = VerticalGroup:new{
        align = "center",
        cover_layers,
        VerticalSpan:new{ height = gap },
        textBox(title, width, title_h, 14, { bold = true }),
        textBox(itemAuthor(item), width, author_h, 11, { fgcolor = DARK_GRAY }),
    }
    return tappable(width, height, body, callback, { hold_callback = callback })
end

local GridShelf = InputContainer:extend{
    name = "koocomic_grid_shelf",
    covers_fullscreen = true,
    stop_events_propagation = true,
    options = nil,
    page = 1,
    pages = 1,
    perpage = 6,
    closed = false,
}

function GridShelf:_add(group, x, y, child)
    group[#group + 1] = OffsetContainer:new{ x_off = x, y_off = y, child }
end

function GridShelf:visibleItems()
    local items = {}
    local first = (self.page - 1) * self.perpage + 1
    local last = math.min(#self.options.books, first + self.perpage - 1)
    for index = first, last do items[#items + 1] = self.options.books[index] end
    return items
end

function GridShelf:_notifyPage()
    if self.options.on_page_changed then
        self.options.on_page_changed(self:visibleItems(), self.page, self.pages)
    end
end

function GridShelf:_changePage(page)
    local target = math.max(1, math.min(self.pages, tonumber(page) or self.page))
    if target == self.page then return true end
    self.page = target
    self:_build()
    UIManager:setDirty(self, "full")
    self:_notifyPage()
    return true
end

function GridShelf:_close()
    if self.closed then return true end
    self.closed = true
    UIManager:close(self)
    return true
end

function GridShelf:_buildHeader(layers, margin, width, y, height)
    local back_w = math.floor(width * 0.13)
    local right_w = math.floor(width * 0.23)
    local title_w = width - back_w - right_w
    local account = self.options.account or {}
    local subtitle = tostring(account.nick or "KOOBONE 用户") .. " · " ..
        tostring(#self.options.books) .. " 本"
    local title = VerticalGroup:new{
        align = "center",
        textBox("koo漫画", title_w, math.floor(height * 0.56), 20, { bold = true }),
        textBox(subtitle, title_w, math.floor(height * 0.36), 12, { fgcolor = DARK_GRAY }),
    }
    local refresh_w = math.floor(right_w * 0.55)
    local header = HorizontalGroup:new{
        align = "center",
        tappable(back_w, height, singleLine("‹", back_w, height, 26, { bold = true }),
            function() self:_close() end),
        CenterContainer:new{ dimen = Geom:new{ w = title_w, h = height }, title },
        tappable(refresh_w, height, singleLine("↻", refresh_w, height, 21, { bold = true }),
            self.options.on_refresh),
        tappable(right_w - refresh_w, height,
            singleLine("⋮", right_w - refresh_w, height, 22, { bold = true }), self.options.on_more),
    }
    self:_add(layers, margin, y, header)
end

function GridShelf:_buildToolbar(layers, margin, width, y, height)
    local third = math.floor(width / 3)
    local last = width - third * 2
    local border = dp(1)
    local function tool(text, w, callback)
        return tappable(w, height, singleLine(text, w - dp(8), height - dp(4), 14, { bold = true }), callback, {
            bordersize = border,
        })
    end
    local toolbar = HorizontalGroup:new{
        tool("⌕  " .. tostring(self.options.search_label or "搜索"), third, self.options.on_search),
        tool("⇅  " .. tostring(self.options.sort_label or "最近加入"), third, self.options.on_sort),
        tool("≡  " .. tostring(self.options.filter_label or "全部"), last, self.options.on_filter),
    }
    self:_add(layers, margin, y, toolbar)
end

function GridShelf:_buildPager(layers, margin, width, y, height)
    local side = math.floor(width * 0.12)
    local middle = width - side * 4
    local function arrow(text, target, enabled)
        return tappable(side, height,
            TextWidget:new{
                text = text,
                face = face("cfont", 16),
                bold = true,
                fgcolor = enabled and BLACK or DARK_GRAY,
            }, enabled and function() self:_changePage(target) end or nil)
    end
    local pager = HorizontalGroup:new{
        arrow("«", 1, self.page > 1),
        arrow("‹", self.page - 1, self.page > 1),
        CenterContainer:new{
            dimen = Geom:new{ w = middle, h = height },
            TextWidget:new{
                text = "第 " .. tostring(self.page) .. " 页 / 共 " .. tostring(self.pages) .. " 页",
                face = face("smallinfofont", 11),
                bold = true,
            },
        },
        arrow("›", self.page + 1, self.page < self.pages),
        arrow("»", self.pages, self.page < self.pages),
    }
    self:_add(layers, margin, y, pager)
end

function GridShelf:_buildBottomNav(layers, width, y, height)
    local cell = math.floor(width / 4)
    local last = width - cell * 3
    local function nav(kind, label, w, selected, callback)
        local color = selected and WHITE or BLACK
        local icon_w, icon_h = dp(24), dp(20)
        local body = VerticalGroup:new{
            align = "center",
            NavIcon:new{ kind = kind, width = icon_w, height = icon_h, color = color },
            VerticalSpan:new{ height = dp(3) },
            TextWidget:new{ text = label, face = face("cfont", 13), bold = selected, fgcolor = color },
        }
        return tappable(w, height,
            CenterContainer:new{ dimen = Geom:new{ w = w - dp(4), h = height - dp(4) }, body }, callback, {
                bordersize = dp(1),
                background = selected and BLACK or WHITE,
                color = BLACK,
            })
    end
    self:_add(layers, 0, y, HorizontalGroup:new{
        nav("shelf", "书架", cell, true, nil),
        nav("download", "下载", cell, false, self.options.on_downloads),
        nav("account", "账号", cell, false, self.options.on_account),
        nav("settings", "设置", last, false, self.options.on_settings),
    })
end

function GridShelf:_build()
    if self[1] and self[1].free then self[1]:free() end
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    self.dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh }
    self.ges_events = {
        ShelfSwipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    active_text_size = tostring((self.options.ui or {}).text_size or "large")
    local columns, rows = Metrics.grid(self.options.ui)
    self.perpage = columns * rows
    self.pages = math.max(1, math.ceil(#self.options.books / self.perpage))
    self.page = math.max(1, math.min(self.pages, self.page))

    local margin = dp(10)
    local header_h = dp(72)
    local toolbar_h = dp(52)
    local pager_h = dp(46)
    local nav_h = dp(72)
    local grid_gap_y = dp(5)
    local grid_gap_x = dp(10)
    local content_w = sw - margin * 2
    local grid_y = margin + header_h + toolbar_h + dp(10)
    local pager_y = sh - nav_h - pager_h
    local grid_h = math.max(1, pager_y - grid_y - dp(8))
    local card_w = math.floor((content_w - grid_gap_x * (columns - 1)) / columns)
    local card_h = math.floor((grid_h - grid_gap_y * (rows - 1)) / rows)

    local layers = OverlapGroup:new{ dimen = self.dimen:copy(), allow_mirroring = false }
    self:_add(layers, 0, 0, fixedFrame(sw, sh, { background = WHITE }))
    self:_buildHeader(layers, margin, content_w, margin, header_h)
    self:_buildToolbar(layers, margin, content_w, margin + header_h, toolbar_h)

    local first = (self.page - 1) * self.perpage + 1
    local last = math.min(#self.options.books, first + self.perpage - 1)
    local slot = 0
    for index = first, last do
        local row = math.floor(slot / columns)
        local column = slot % columns
        local item = self.options.books[index]
        self:_add(layers,
            margin + column * (card_w + grid_gap_x),
            grid_y + row * (card_h + grid_gap_y),
            bookCard(item, card_w, card_h, self.options.storage, function()
                if self.options.on_select then self.options.on_select(item) end
            end))
        slot = slot + 1
    end
    if #self.options.books == 0 then
        self:_add(layers, margin, grid_y,
            CenterContainer:new{
                dimen = Geom:new{ w = content_w, h = grid_h },
                textBox("没有符合条件的漫画", content_w, dp(80), 15, { fgcolor = DARK_GRAY }),
            })
    end

    self:_buildPager(layers, margin, content_w, pager_y, pager_h)
    self:_buildBottomNav(layers, sw, sh - nav_h, nav_h)
    self[1] = layers
end

function GridShelf:init()
    self.options = self.options or {}
    self.options.books = self.options.books or {}
    self.page = tonumber(self.options.page) or 1
    if Device:hasKeys() and Device.input and Device.input.group then
        self.key_events = {}
        if Device.input.group.Back then self.key_events.Back = { { Device.input.group.Back } } end
        if Device.input.group.PgFwd then self.key_events.NextPage = { { Device.input.group.PgFwd } } end
        if Device.input.group.PgBack then self.key_events.PreviousPage = { { Device.input.group.PgBack } } end
    end
    self:_build()
end

function GridShelf:update(options, notify)
    if self.closed then return false end
    for key, value in pairs(options or {}) do self.options[key] = value end
    self:_build()
    UIManager:setDirty(self, "full")
    if notify ~= false then self:_notifyPage() end
    return true
end

function GridShelf:refreshCovers()
    if self.closed then return false end
    self:_build()
    UIManager:setDirty(self, "ui")
    return true
end

function GridShelf:onShelfSwipe(_, gesture)
    if gesture and gesture.direction == "west" then return self:_changePage(self.page + 1) end
    if gesture and gesture.direction == "east" then return self:_changePage(self.page - 1) end
    return false
end

function GridShelf:onNextPage()
    return self:_changePage(self.page + 1)
end

function GridShelf:onPreviousPage()
    return self:_changePage(self.page - 1)
end

function GridShelf:onBack()
    return self:_close()
end

function GridShelf:onScreenResize()
    if self.closed then return true end
    self:_build()
    UIManager:setDirty(self, "full")
    self:_notifyPage()
    return true
end

function GridShelf:onSetDimensions()
    return self:onScreenResize()
end

function GridShelf:onRotation()
    return self:onScreenResize()
end

function GridShelf:onShow()
    UIManager:setDirty(self, "full")
    self:_notifyPage()
end

function GridShelf:onCloseWidget()
    self.closed = true
    if self.options.on_close then self.options.on_close() end
end

local BookshelfGrid = {}

function BookshelfGrid.show(options)
    local view = GridShelf:new{ options = options or {} }
    UIManager:show(view)
    return view
end

return BookshelfGrid
