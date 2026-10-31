local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local IconWidget = require("ui/widget/iconwidget")
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
local CurvedCover = require("koobone.ui.curved_cover")

local Screen = Device.screen
local WHITE = Blitbuffer.COLOR_WHITE
local BLACK = Blitbuffer.COLOR_BLACK
local DARK_GRAY = Blitbuffer.COLOR_DARK_GRAY or Blitbuffer.COLOR_GRAY
local LIGHT_GRAY = Blitbuffer.COLOR_GRAY_E or Blitbuffer.COLOR_LIGHT_GRAY or Blitbuffer.COLOR_GRAY
local PAPER_GRAY = Blitbuffer.COLOR_GRAY_E or Blitbuffer.COLOR_LIGHT_GRAY or Blitbuffer.COLOR_GRAY
local EDGE_GRAY = Blitbuffer.COLOR_GRAY_B or Blitbuffer.COLOR_GRAY or DARK_GRAY
local SHADOW_GRAY = Blitbuffer.COLOR_GRAY_C or Blitbuffer.COLOR_GRAY or DARK_GRAY
local icon_root = debug.getinfo(1, "S").source:sub(2):gsub("koobone/ui/bookshelf_grid%.lua$", "icons/")
local artwork_root = icon_root:gsub("icons/$", "artwork/")
local theme = {
    ink = BLACK, muted = DARK_GRAY, page = WHITE,
    shelf = PAPER_GRAY, shelf_edge = EDGE_GRAY, shelf_shadow = SHADOW_GRAY,
    tag = PAPER_GRAY, tag_border = EDGE_GRAY, tag_shadow = SHADOW_GRAY,
    line = EDGE_GRAY, button_shadow = SHADOW_GRAY,
}

local function rgb(r, g, b, fallback)
    if type(Blitbuffer.ColorRGB32) ~= "function" then return fallback end
    local ok, color = pcall(Blitbuffer.ColorRGB32, r, g, b, 255)
    return ok and color or fallback
end

local function useColor()
    if type(Screen.isColorEnabled) ~= "function" then return false end
    local ok, enabled = pcall(Screen.isColorEnabled, Screen)
    return ok and enabled == true
end

local function setTheme()
    if useColor() then
        theme = {
            ink = rgb(116, 70, 25, BLACK), muted = rgb(130, 92, 57, DARK_GRAY),
            page = rgb(255, 251, 245, WHITE), shelf = rgb(244, 226, 200, LIGHT_GRAY),
            shelf_edge = rgb(193, 151, 105, EDGE_GRAY),
            shelf_shadow = rgb(218, 188, 151, SHADOW_GRAY),
            tag = rgb(248, 234, 214, PAPER_GRAY),
            tag_border = rgb(201, 164, 120, EDGE_GRAY),
            tag_shadow = rgb(220, 194, 160, SHADOW_GRAY),
            line = rgb(201, 164, 120, EDGE_GRAY),
            button_shadow = rgb(220, 194, 160, SHADOW_GRAY),
        }
    else
        theme = {
            ink = BLACK, muted = DARK_GRAY, page = WHITE,
            shelf = PAPER_GRAY, shelf_edge = EDGE_GRAY, shelf_shadow = SHADOW_GRAY,
            tag = PAPER_GRAY, tag_border = EDGE_GRAY, tag_shadow = SHADOW_GRAY,
            line = EDGE_GRAY, button_shadow = SHADOW_GRAY,
        }
    end
end

local function icon(name, size)
    return IconWidget:new{
        file = icon_root .. name .. ".svg", width = size, height = size, alpha = true,
    }
end

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
        background = options.background or theme.page,
        color = options.color or theme.ink,
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
        background = options.background or theme.page,
        color = options.color or theme.ink,
        radius = options.radius or 0,
        padding = options.padding or 0,
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
        fgcolor = options.fgcolor or theme.ink,
        bgcolor = options.bgcolor or theme.page,
    }
end

local function lineWidget(text, size, options)
    options = options or {}
    return TextWidget:new{
        text = tostring(text or ""),
        face = face(options.face or "cfont", size),
        bold = options.bold == true,
        fgcolor = options.fgcolor or theme.ink,
        padding = options.padding or 0,
        max_width = options.max_width,
        truncate_with_ellipsis = options.truncate_with_ellipsis ~= false,
    }
end

local function measuredLine(text, size, options)
    local widget = lineWidget(text, size, options)
    return widget, widget:getSize()
end

local function singleLine(text, width, height, size, options)
    options = options or {}
    local child = lineWidget(text, size, {
        face = options.face, bold = options.bold, fgcolor = options.fgcolor,
        max_width = math.max(1, width - dp(4)), padding = 0,
    })
    return CenterContainer:new{ dimen = Geom:new{ w = width, h = height }, child }
end

local ColorBlock = Widget:extend{ width = 1, height = 1, color = WHITE, fallback = WHITE }

function ColorBlock:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function ColorBlock:paintTo(bb, x, y)
    if self.color ~= self.fallback and type(bb.paintRectRGB32) == "function" then
        local ok = pcall(bb.paintRectRGB32, bb, x, y, self.width, self.height, self.color)
        if ok then return end
    end
    bb:paintRect(x, y, self.width, self.height, self.fallback)
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
            textBox(self.title, inner_w, math.floor(inner_h * 0.62), 14,
                { bold = true, bgcolor = WHITE }),
            textBox(self.volume, inner_w, math.floor(inner_h * 0.38), 10,
                { bgcolor = WHITE }),
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
    local title = tostring(item.vol_series or item.vol_name or item.file_md5 or "未命名漫画")
    local short = title:gsub("%s*[-·_：:]?%s*卷%s*%d+%s*$", "")
    return short ~= "" and short or title
end

local function itemAuthor(item)
    if item._koobone_series then
        return "已下载 " .. tostring(item._series_downloaded or 0) .. "/"
            .. tostring(item._series_count or 0)
    end
    return tostring(item.vol_author or "未知作者")
end

local function itemVolume(item)
    if item._koobone_series then return "共 " .. tostring(item._series_count or 0) .. " 卷" end
    local value = item.vol_index or item.volume or item.vol_no
    if value and tostring(value) ~= "" then return "卷 " .. tostring(value) end
    local from_name = tostring(item.vol_name or ""):match("卷%s*(%d+)")
    if from_name then return "卷 " .. from_name end
    local pages = tonumber(item.count_page)
    return pages and pages > 0 and (tostring(pages) .. " 页") or "KOOBONE"
end

-- Original vector book shell. All content positions share its 400 x 280
-- coordinate system, so paper edges and content cannot scale independently.
-- When the reader has locally cached its last two real page previews, put the
-- previous page on the left and the current page on the right. Otherwise fall
-- back to a cover and title page; never invent manga panels.
local function openBook(item, width, height)
    local sx, sy = width / 400, height / 280
    local function px(value) return math.floor(value * sx + 0.5) end
    local function py(value) return math.floor(value * sy + 0.5) end
    local paper = useColor() and rgb(255, 253, 247, WHITE) or WHITE
    local layer = OverlapGroup:new{
        dimen = Geom:new{ w = width, h = height }, allow_mirroring = false,
    }
    local function add(x, y, child)
        layer[#layer + 1] = OffsetContainer:new{ x_off = x, y_off = y, child }
    end
    add(0, 0, ImageWidget:new{
        file = artwork_root .. (useColor() and "open-book-warm.svg" or "open-book-mono.svg"),
        width = width, height = height, alpha = true, file_do_cache = true,
    })
    local slot_w, slot_h = math.max(1, px(130)), math.max(1, py(179))
    local preview_left = item and item._koobone_preview_left
    local preview_right = item and item._koobone_preview_right
    local left_path = preview_left or (item and item._koobone_cover_path)
    if left_path and left_path ~= "" then
        add(0, 0, CurvedCover:new{
            path = left_path, width = width, height = height,
            warm = useColor(), side = "left",
        })
    else
        -- Remains visible if the item has no image at all. Do not place it
        -- behind a feathered page preview, where its edges could show through.
        add(px(44), py(43), CenterContainer:new{
            dimen = Geom:new{ w = slot_w, h = slot_h },
            icon("book-open", math.max(1, math.floor(slot_w * 0.55))),
        })
    end
    -- Font size follows the available paper width, with the existing UI size
    -- preference still applied by face(). Body height is measured, not assumed.
    local scale = math.min(1, slot_w / math.max(1, dp(65)))
    if preview_right and preview_right ~= "" then
        add(0, 0, CurvedCover:new{
            path = preview_right, width = width, height = height,
            warm = useColor(), side = "right",
        })
    else
        local title = TextBoxWidget:new{
            text = item and itemTitle(item) or "我的漫画",
            face = face("cfont", 9 * scale), bold = true,
            width = slot_w, height = math.max(1, py(70)),
            height_adjust = true, height_overflow_show_ellipsis = true,
            alignment = "center", fgcolor = theme.ink, bgcolor = paper,
        }
        local volume = TextWidget:new{
            text = item and itemVolume(item) or "KooComic",
            face = face("smallinfofont", 7 * scale), fgcolor = theme.muted,
            max_width = slot_w,
        }
        local body = VerticalGroup:new{
            align = "center", title, VerticalSpan:new{ height = math.max(1, py(10)) }, volume,
        }
        add(px(226), py(43), CenterContainer:new{
            dimen = Geom:new{ w = slot_w, h = slot_h }, body,
        })
    end
    return layer
end

local function progressPercent(item)
    local current = tonumber(item.last_readpage) or 0
    local total = tonumber(item.count_page) or 0
    if total <= 0 or current <= 0 then return 0 end
    return math.max(0, math.min(100, math.floor(current / total * 100 + 0.5)))
end

local function badge(text, width, height)
    return fixedFrame(width, height, { background = theme.ink, color = theme.ink },
        TextWidget:new{
            text = text,
            face = face("smallinfofont", 10),
            bold = true,
            fgcolor = WHITE,
        })
end

local function cardStyle(width, height)
    local _, title_size = measuredLine("漫画书名", 11, { bold = true, max_width = width })
    local _, tag_size = measuredLine("卷 01 · 作者", 8, { max_width = width })
    local title_h = math.max(dp(18), title_size.h + dp(2))
    local tag_h = math.max(dp(15), tag_size.h + dp(4))
    local shelf_y = math.max(dp(28), height - title_h - tag_h + dp(1))
    return { shelf_y = shelf_y, title_h = title_h, tag_h = tag_h }
end

local function toolbarStyle()
    local _, heading_size = measuredLine("全部漫画", 17, { bold = true })
    local _, tab_size = measuredLine("已下载", 11)
    local title_h = math.max(dp(30), heading_size.h + dp(8))
    local tab_h = math.max(dp(23), tab_size.h + dp(6))
    return { title_h = title_h, tab_h = tab_h, bottom_gap = dp(7),
        height = title_h + tab_h + dp(7) }
end

local function bookCard(item, width, height, style, storage, callback)
    style = style or cardStyle(width, height)
    local shelf_y, title_h, tag_h = style.shelf_y, style.title_h, style.tag_h
    local cover_h = math.max(1, shelf_y - dp(5))
    local cover_w = math.min(math.floor(width * 0.72), math.floor(cover_h * 0.70))
    local cover_x = math.floor((width - cover_w) / 2)
    local title = itemTitle(item)
    local cover = coverImage(item._koobone_cover_path, cover_w, cover_h)
        or PlaceholderCover:new{
            width = cover_w,
            height = cover_h,
            title = title,
            volume = itemVolume(item),
        }
    local layers = OverlapGroup:new{ dimen = Geom:new{ w = width, h = height }, allow_mirroring = false }
    layers[#layers + 1] = OffsetContainer:new{ x_off = cover_x, y_off = 0, cover }
    local downloaded = item._koobone_series
        and (tonumber(item._series_count) or 0) > 0
        and tonumber(item._series_downloaded) == tonumber(item._series_count)
        or (not item._koobone_series and storage:isDownloaded(item))
    local partial = item._koobone_series and 0 or storage:partSize(item)
    local progress = progressPercent(item)
    local badge_text
    if downloaded then
        badge_text = "已下载"
    elseif item._koobone_series and (tonumber(item._series_downloaded) or 0) > 0 then
        badge_text = "已下 " .. tostring(item._series_downloaded) .. "/" .. tostring(item._series_count)
    elseif partial > 0 then
        badge_text = "未完成"
    elseif progress > 0 then
        badge_text = tostring(progress) .. "%"
    end
    if badge_text then
        local badge_w, badge_h = item._koobone_series and dp(48) or dp(36), dp(17)
        layers[#layers + 1] = OffsetContainer:new{
            x_off = cover_x + math.max(0, cover_w - badge_w), y_off = dp(2),
            badge(badge_text, badge_w, badge_h),
        }
    end
    layers[#layers + 1] = OffsetContainer:new{
        x_off = 0, y_off = shelf_y,
        singleLine(title, width, title_h, 11, { bold = true }),
    }
    local tag_text = itemVolume(item) .. " · " .. itemAuthor(item)
    local _, tag_label_size = measuredLine(tag_text, 8, {
        fgcolor = theme.muted, max_width = math.max(1, width - dp(10)),
    })
    local tag_w = math.min(width - dp(4),
        math.max(math.floor(cover_w * 0.92), tag_label_size.w + dp(12)))
    local tag_label = lineWidget(tag_text, 8, {
        fgcolor = theme.ink, max_width = math.max(1, tag_w - dp(10)),
    })
    local tag_x = math.floor((width - tag_w) / 2)
    local tag_y = shelf_y + title_h - dp(1)
    layers[#layers + 1] = OffsetContainer:new{
        x_off = tag_x + dp(1), y_off = tag_y + dp(2),
        fixedFrame(tag_w, tag_h, {
            background = theme.tag_shadow, color = theme.tag_shadow,
            radius = dp(3),
        }),
    }
    layers[#layers + 1] = OffsetContainer:new{
        x_off = tag_x, y_off = tag_y,
        fixedFrame(tag_w, tag_h, {
            background = theme.tag, color = theme.tag_border,
            bordersize = dp(1), radius = dp(3), padding = dp(1),
        }, tag_label),
    }
    local box = TapBox:new{
        dimen = Geom:new{ w = width, h = height },
        callback = callback, hold_callback = callback,
    }
    box[1] = layers
    return box
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
    local action_w = math.max(dp(42), math.floor(width * 0.09))
    local brand = HorizontalGroup:new{
        align = "center",
        icon("book-open", dp(26)),
        HorizontalSpan:new{ width = dp(7) },
        TextWidget:new{ text = "KooComic·可漫", face = face("cfont", 16), bold = true, fgcolor = BLACK },
    }
    self:_add(layers, margin, y,
        CenterContainer:new{ dimen = Geom:new{ w = math.min(width - action_w * 3, dp(190)),
            h = height }, brand })
    local actions = {
        { "search", self.options.on_search },
        { "refresh-cw", self.options.on_refresh },
        { "x", function() self:_close() end },
    }
    for index, action in ipairs(actions) do
        self:_add(layers, margin + width - action_w * (4 - index), y,
            tappable(action_w, height, icon(action[1], dp(22)), action[2]))
    end
    self:_add(layers, margin, y + height - dp(1),
        ColorBlock:new{ width = width, height = dp(1), color = theme.line, fallback = LIGHT_GRAY })
end

function GridShelf:_buildToolbar(layers, margin, width, y, height)
    local toolbar = toolbarStyle()
    local title_h, tab_h = toolbar.title_h, toolbar.tab_h
    local tab_y = y + title_h
    local underline_y = tab_y + tab_h - dp(2)
    local filter_w = math.max(dp(84), math.floor(width * 0.20))
    local sort_w = math.max(dp(68), math.floor(width * 0.17))
    local heading_w = width - filter_w - sort_w
    local breadcrumbs = self.options.breadcrumbs
    if type(breadcrumbs) ~= "table" or #breadcrumbs == 0 then
        breadcrumbs = { {
            text = tostring(self.options.section_title or "全部漫画") .. " "
                .. tostring(self.options.total_count or #self.options.books),
        } }
    end
    self.layout.breadcrumb_count = #breadcrumbs
    if #breadcrumbs == 1 then
        local heading_text = tostring(breadcrumbs[1].text or "全部漫画")
        self:_add(layers, margin, y,
            textBox(heading_text, heading_w - dp(5), title_h, 17,
                { bold = true, alignment = "left" }))
    else
        local font_size = #breadcrumbs >= 3 and 12 or 14
        local separator_w = dp(14)
        local available = math.max(1, heading_w - separator_w * (#breadcrumbs - 1))
        local desired, total = {}, separator_w * (#breadcrumbs - 1)
        for index, crumb in ipairs(breadcrumbs) do
            local _, size = measuredLine(crumb.text, font_size, { bold = true })
            desired[index] = size.w + dp(6)
            total = total + desired[index]
        end
        if total > heading_w then
            local each = math.max(dp(36), math.floor(available / #breadcrumbs))
            for index = 1, #breadcrumbs do desired[index] = each end
            desired[#breadcrumbs] = math.max(dp(36), available - each * (#breadcrumbs - 1))
        end
        local parts = { align = "center" }
        for index, crumb in ipairs(breadcrumbs) do
            local segment_w = math.max(1, desired[index])
            parts[#parts + 1] = tappable(segment_w, title_h,
                lineWidget(crumb.text, font_size, {
                    bold = true, max_width = math.max(1, segment_w - dp(4)),
                }), crumb.callback)
            if index < #breadcrumbs then
                parts[#parts + 1] = CenterContainer:new{
                    dimen = Geom:new{ w = separator_w, h = title_h },
                    icon("chevron-right", dp(12)),
                }
            end
        end
        self:_add(layers, margin, y, HorizontalGroup:new(parts))
    end
    local sort_label = HorizontalGroup:new{
        align = "center", icon("arrow-down-up", dp(14)),
        HorizontalSpan:new{ width = dp(2) },
        TextWidget:new{ text = tostring(self.options.sort_label or "最近加入"),
            face = face("cfont", 10), fgcolor = DARK_GRAY },
    }
    self:_add(layers, margin + width - filter_w - sort_w, y,
        tappable(sort_w, title_h, sort_label, self.options.on_sort))
    local filter_icon = HorizontalGroup:new{
        align = "center", icon("sliders-horizontal", dp(17)),
        HorizontalSpan:new{ width = dp(2) },
        TextWidget:new{ text = "分类筛选", face = face("cfont", 10), fgcolor = BLACK },
    }
    self:_add(layers, margin + width - filter_w, y,
        tappable(filter_w, title_h, filter_icon, self.options.on_filter,
            { hold_callback = self.options.on_filter_customize }))
    local labels = self.options.quick_filters or {
        { "all", "全部" }, { "works", "作品" },
        { "downloaded", "已下载" }, { "not_downloaded", "未下载" },
    }
    self.layout.quick_filter_count = #labels
    local tab_w = math.floor(width * 0.13)
    for index, entry in ipairs(labels) do
        local selected = (self.options.filter_mode or "all") == entry[1]
        local x = margin + (index - 1) * tab_w
        self:_add(layers, x, tab_y,
            tappable(tab_w, tab_h,
                singleLine(entry[2], tab_w, tab_h, 11,
                    { bold = selected, fgcolor = selected and theme.ink or theme.muted }),
                function()
                    if self.options.on_quick_filter then self.options.on_quick_filter(entry[1]) end
                end))
        if selected then
            self:_add(layers, x + dp(6), underline_y,
                ColorBlock:new{ width = tab_w - dp(12), height = dp(2), color = theme.ink, fallback = BLACK })
        end
    end
    self.layout.toolbar_title_h = title_h
    self.layout.toolbar_tab_h = tab_h
    self.layout.toolbar_underline_y = underline_y
    self.layout.toolbar_bottom_gap = math.max(0, y + height - underline_y - dp(2))
end

function GridShelf:_buildPager(layers, margin, width, y, height)
    local block_w = math.min(width, dp(150))
    local start_x = margin + math.floor((width - block_w) / 2)
    local arrow_w = math.floor(block_w * 0.26)
    self:_add(layers, start_x, y,
        tappable(arrow_w, height, icon("chevron-left", dp(18)),
            self.page > 1 and function() self:_changePage(self.page - 1) end or nil,
            { hold_callback = self.page > 1 and function() self:_changePage(1) end or nil }))
    self:_add(layers, start_x + arrow_w, y,
        tappable(block_w - arrow_w * 2, height,
            CenterContainer:new{
                dimen = Geom:new{ w = block_w - arrow_w * 2, h = height },
                lineWidget(string.format("%02d / %02d", self.page, self.pages), 11,
                    { bold = true, max_width = block_w - arrow_w * 2 - dp(4) }),
            }, nil))
    self:_add(layers, start_x + block_w - arrow_w, y,
        tappable(arrow_w, height, icon("chevron-right", dp(18)),
            self.page < self.pages and function() self:_changePage(self.page + 1) end or nil,
            { hold_callback = self.page < self.pages and function() self:_changePage(self.pages) end or nil }))
end

function GridShelf:_buildBottomNav(layers, width, y, height)
    local cell = math.floor(width / 4)
    local last = width - cell * 3
    local function nav(kind, label, w, selected, callback)
        local body = VerticalGroup:new{
            align = "center",
            icon(kind, dp(23)),
            VerticalSpan:new{ height = dp(2) },
            TextWidget:new{ text = label, face = face("cfont", 11), bold = selected,
                fgcolor = selected and BLACK or DARK_GRAY },
        }
        return tappable(w, height,
            CenterContainer:new{ dimen = Geom:new{ w = w, h = height }, body }, callback)
    end
    self:_add(layers, 0, y, HorizontalGroup:new{
        nav("book-open-active", "书架", cell, true, nil),
        nav("download", "下载", cell, false, self.options.on_downloads),
        nav("user-round", "账号", cell, false, self.options.on_account),
        nav("settings", "设置", last, false, self.options.on_settings),
    })
    self:_add(layers, 0, y,
        ColorBlock:new{ width = width, height = dp(1), color = theme.line, fallback = LIGHT_GRAY })
end

function GridShelf:_buildHero(layers, margin, width, y, height, columns, card_w, gap_x, shelf_cover_w)
    local item = self.options.current_book
    if item == false then item = nil end
    local mode = self.options.current_mode
    if mode ~= "reading" and mode ~= "start" and mode ~= "empty" then
        mode = item and (progressPercent(item) > 0 and "reading" or "start") or "empty"
    end
    if not item then mode = "empty" end
    local is_reading = mode == "reading" and item ~= nil
    local shelf_y = y + height - dp(10)
    local book_x = margin + math.floor((card_w - shelf_cover_w) / 2)
    local book_w = math.max(1, math.floor(math.min(shelf_cover_w * 1.8,
        math.max(1, height - dp(28)) * 400 / 280)))
    local book_h = math.max(1, math.floor(book_w * 280 / 400 + 0.5))
    local book_y = shelf_y - dp(3) - book_h
    self:_add(layers, book_x, book_y, openBook(item, book_w, book_h))
    local hero_right = margin + (columns - 1) * (card_w + gap_x) +
        math.floor((card_w + shelf_cover_w) / 2)
    self.layout.hero_right = hero_right
    self.layout.hero_book_left = book_x
    local info_x = book_x + book_w + dp(16)
    local info_w = math.max(dp(60), hero_right - info_x)
    local button_label = mode == "reading" and "继续阅读"
        or (mode == "start" and "开始阅读" or "刷新书架")
    local continue_text, continue_size = measuredLine(button_label, 10, { bold = true })
    local button_w = math.min(dp(118), math.max(dp(98), continue_size.w + dp(36)))
    button_w = math.min(button_w, math.max(dp(60), math.floor(info_w * 0.48)))
    local button_h = math.max(dp(28), continue_size.h + dp(8))
    local label = mode == "reading" and "正在阅读"
        or (mode == "start" and "挑一本开始" or "欢迎使用")
    local label_y = y + dp(9)
    local _, label_size = measuredLine(label, 10, { max_width = info_w })
    local label_h = math.max(dp(15), label_size.h)
    local title_y = label_y + label_h + dp(1)
    local title_text = item and itemTitle(item) or "书架里还没有漫画"
    local _, title_size = measuredLine(title_text, 16,
        { bold = true, max_width = math.max(1, info_w - button_w - dp(5)) })
    local title_row_h = math.max(button_h, title_size.h)
    self:_add(layers, info_x, label_y + math.floor((label_h - label_size.h) / 2),
        lineWidget(label, 10, { fgcolor = theme.muted, max_width = info_w }))
    self:_add(layers, info_x, title_y + math.floor((title_row_h - title_size.h) / 2),
        lineWidget(title_text, 16, {
            bold = true, max_width = math.max(1, info_w - button_w - dp(5)),
        }))
    local continue_label = HorizontalGroup:new{
        align = "center",
        continue_text,
        HorizontalSpan:new{ width = dp(3) },
        icon(mode == "empty" and "refresh-cw" or "arrow-right", dp(14)),
    }
    local button_y = title_y + math.floor((title_row_h - button_h) / 2)
    local button_x = hero_right - button_w
    self:_add(layers, button_x + dp(1), button_y + dp(2),
        fixedFrame(button_w, button_h, {
            background = theme.button_shadow, color = theme.button_shadow,
            radius = math.floor(button_h / 2),
        }))
    self:_add(layers, button_x, button_y,
        tappable(button_w, button_h, continue_label,
            function()
                if mode == "empty" then
                    if self.options.on_refresh then self.options.on_refresh() end
                elseif self.options.on_continue then
                    self.options.on_continue(item)
                end
            end, {
                bordersize = dp(1), background = theme.tag, color = theme.tag_border,
                radius = math.floor(button_h / 2),
            }))

    local progress = item and progressPercent(item) or 0
    local meta_y = title_y + title_row_h + dp(3)
    local meta_text
    if mode == "reading" then
        meta_text = itemVolume(item) .. " · 已读 " .. tostring(progress) .. "%"
    elseif mode == "start" then
        meta_text = itemVolume(item) .. " · " .. itemAuthor(item)
    else
        meta_text = "连接 KOOBONE 并同步个人漫画书架"
    end
    local _, meta_size = measuredLine(meta_text, 10, { max_width = info_w })
    local meta_h = math.max(dp(15), meta_size.h)
    self:_add(layers, info_x, meta_y + math.floor((meta_h - meta_size.h) / 2),
        lineWidget(meta_text, 10, { fgcolor = theme.muted, max_width = info_w }))

    local detail_lines
    if mode == "reading" then
        detail_lines = {
            "作者：" .. itemAuthor(item),
            "上次读到第 " .. tostring(item.last_readpage or 0) .. " 页……",
        }
    elseif mode == "start" then
        detail_lines = {
            "作者：" .. itemAuthor(item),
            "从下方书架选择，也可以从这一本开始……",
        }
    end
    local detail_y = meta_y + meta_h + dp(1)
    local detail_drawn = false
    local detail_line_count = 0
    local content_bottom = meta_y + meta_h
    local track_h = dp(4)
    local latest_track_y = shelf_y - track_h - dp(9)
    if detail_lines then
        local line_y = detail_y
        local detail_limit = is_reading and (latest_track_y - dp(4)) or (shelf_y - dp(7))
        for index, detail_text in ipairs(detail_lines) do
            local line_width = index == 2 and math.floor(info_w * 0.67) or info_w
            local _, detail_size = measuredLine(detail_text, 9, { max_width = line_width })
            local detail_h = math.max(dp(14), detail_size.h)
            if line_y + detail_h <= detail_limit then
                self:_add(layers, info_x, line_y + math.floor((detail_h - detail_size.h) / 2),
                    lineWidget(detail_text, 9, {
                        fgcolor = theme.muted, max_width = line_width,
                    }))
                line_y = line_y + detail_h
                content_bottom = line_y
                detail_drawn = true
                detail_line_count = detail_line_count + 1
            else
                break
            end
        end
    end
    if is_reading then
        local track_y = math.min(latest_track_y, content_bottom + dp(4))
        self:_add(layers, info_x, track_y,
            ColorBlock:new{ width = info_w, height = track_h,
                color = theme.shelf_shadow, fallback = LIGHT_GRAY })
        if progress > 0 then
            self:_add(layers, info_x, track_y,
                ColorBlock:new{ width = math.max(1, math.floor(info_w * progress / 100)),
                    height = track_h, color = theme.ink, fallback = DARK_GRAY })
        end
        self.layout.hero_track_right = info_x + info_w
        self.layout.hero_track_bottom = track_y + track_h
        self.layout.hero_track_gap = track_y - content_bottom
    end
    self.layout.hero_mode = mode
    self.layout.hero_button_bottom = button_y + button_h
    self.layout.hero_meta_top = meta_y
    self.layout.hero_button_right = hero_right
    self.layout.hero_shelf_y = shelf_y
    self.layout.hero_detail_drawn = detail_drawn
    self.layout.hero_detail_line_count = detail_line_count
    self.layout.hero_detail_second_width = math.floor(info_w * 0.67)
    self.layout.hero_content_top = label_y
    self.layout.hero_content_bottom = content_bottom

    self:_add(layers, margin, shelf_y + dp(5),
        ColorBlock:new{ width = width, height = dp(3),
            color = theme.shelf_shadow, fallback = SHADOW_GRAY })
    self:_add(layers, margin, shelf_y,
        ColorBlock:new{ width = width, height = dp(5), color = theme.shelf, fallback = LIGHT_GRAY })
    self:_add(layers, margin, shelf_y + dp(4),
        ColorBlock:new{ width = width, height = dp(2),
            color = theme.shelf_edge, fallback = EDGE_GRAY })
end

function GridShelf:_build()
    if self[1] and self[1].free then self[1]:free() end
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    self._last_screen_w, self._last_screen_h = sw, sh
    self._last_rotation = Screen.getRotationMode and Screen:getRotationMode() or nil
    self.dimen = Geom:new{ x = 0, y = 0, w = sw, h = sh }
    self.ges_events = {
        ShelfSwipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    active_text_size = tostring((self.options.ui or {}).text_size or "large")
    setTheme()
    local columns, rows = Metrics.grid(self.options.ui)
    self.perpage = columns * rows
    self.pages = math.max(1, math.ceil(#self.options.books / self.perpage))
    self.page = math.max(1, math.min(self.pages, self.page))

    local margin = dp(9)
    local header_h = math.min(dp(52), math.floor(sh * 0.075))
    local hero_h = math.min(dp(150), math.floor(sh * 0.195))
    local toolbar = toolbarStyle()
    local toolbar_h = toolbar.height
    local pager_h = math.min(dp(36), math.floor(sh * 0.05))
    local nav_h = math.min(dp(60), math.floor(sh * 0.085))
    local section_gap = dp(4)
    local grid_top_gap = dp(2)
    local pager_lift = dp(4)
    local grid_gap_y = dp(8)
    local grid_gap_x = dp(5)
    local content_w = sw - margin * 2
    local hero_y = margin + header_h
    local toolbar_y = hero_y + hero_h + section_gap
    local grid_y = toolbar_y + toolbar_h + grid_top_gap
    local pager_y = sh - nav_h - pager_h - pager_lift
    local grid_h = math.max(1, pager_y - grid_y - dp(3))
    local card_w = math.floor((content_w - grid_gap_x * (columns - 1)) / columns)
    local card_h = math.floor((grid_h - grid_gap_y * (rows - 1)) / rows)
    local card_style = cardStyle(card_w, card_h)
    local shelf_cover_w = math.min(math.floor(card_w * 0.72),
        math.floor(math.max(dp(48), card_h - dp(39)) * 0.70))
    self.layout = {
        columns = columns, rows = rows, card_w = card_w, card_h = card_h,
        hero_y = hero_y, grid_y = grid_y, pager_y = pager_y,
        toolbar_y = toolbar_y, toolbar_h = toolbar_h,
        hero_h = hero_h, hero_section_gap = section_gap,
        grid_top_gap = grid_top_gap, pager_lift = pager_lift,
        card_shelf_y = card_style.shelf_y, card_title_h = card_style.title_h,
        card_tag_h = card_style.tag_h, card_tag_shadow_offset = dp(2),
        shelf_shadow_h = dp(3),
        first_cover_left = margin + math.floor((card_w - shelf_cover_w) / 2),
        last_cover_right = margin + (columns - 1) * (card_w + grid_gap_x) +
            math.floor((card_w + shelf_cover_w) / 2),
    }

    local layers = OverlapGroup:new{ dimen = self.dimen:copy(), allow_mirroring = false }
    self:_add(layers, 0, 0,
        ColorBlock:new{ width = sw, height = sh, color = theme.page, fallback = WHITE })
    self:_buildHeader(layers, margin, content_w, margin, header_h)
    self:_buildHero(layers, margin, content_w, hero_y, hero_h,
        columns, card_w, grid_gap_x, shelf_cover_w)
    self:_buildToolbar(layers, margin, content_w, toolbar_y, toolbar_h)

    local first = (self.page - 1) * self.perpage + 1
    local last = math.min(#self.options.books, first + self.perpage - 1)
    for row = 0, rows - 1 do
        local shelf_y = grid_y + row * (card_h + grid_gap_y) + card_style.shelf_y
        self:_add(layers, margin, shelf_y + card_style.title_h + dp(1),
            ColorBlock:new{ width = content_w, height = dp(3),
                color = theme.shelf_shadow, fallback = SHADOW_GRAY })
        self:_add(layers, margin, shelf_y,
            ColorBlock:new{ width = content_w, height = card_style.title_h,
                color = theme.shelf, fallback = LIGHT_GRAY })
        self:_add(layers, margin, shelf_y + card_style.title_h - dp(1),
            ColorBlock:new{ width = content_w, height = dp(2),
                color = theme.shelf_edge, fallback = EDGE_GRAY })
    end
    local slot = 0
    for index = first, last do
        local row = math.floor(slot / columns)
        local column = slot % columns
        local item = self.options.books[index]
        self:_add(layers,
            margin + column * (card_w + grid_gap_x),
            grid_y + row * (card_h + grid_gap_y),
            bookCard(item, card_w, card_h, card_style, self.options.storage, function()
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
    if type(UIManager.scheduleIn) ~= "function" then
        self:_build()
        UIManager:setDirty(self, "full")
        self:_notifyPage()
        return true
    end
    self._dimension_generation = (tonumber(self._dimension_generation) or 0) + 1
    local generation = self._dimension_generation
    if self._dimension_task and type(UIManager.unschedule) == "function" then
        UIManager:unschedule(self._dimension_task)
    end
    local last_w, last_h, stable, attempts = nil, nil, 0, 0
    local task
    task = function()
        if self.closed or self._dimension_task ~= task or generation ~= self._dimension_generation then return end
        attempts = attempts + 1
        local sw, sh = Screen:getWidth(), Screen:getHeight()
        local rotation = Screen.getRotationMode and Screen:getRotationMode() or nil
        if sw == last_w and sh == last_h then stable = stable + 1
        else last_w, last_h, stable = sw, sh, 0 end
        if stable >= 1 or attempts >= 8 then
            self._dimension_task = nil
            if sw == self._last_screen_w and sh == self._last_screen_h and rotation == self._last_rotation then
                return
            end
            self:_build()
            UIManager:setDirty(self, "full")
            self:_notifyPage()
            return
        end
        UIManager:scheduleIn(0.08, task)
    end
    self._dimension_task = task
    UIManager:scheduleIn(0.06, task)
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
    self._dimension_generation = (tonumber(self._dimension_generation) or 0) + 1
    if self._dimension_task and type(UIManager.unschedule) == "function" then
        UIManager:unschedule(self._dimension_task)
    end
    self._dimension_task = nil
    if self.options.on_close then self.options.on_close() end
end

local BookshelfGrid = {}

function BookshelfGrid.show(options)
    local view = GridShelf:new{ options = options or {} }
    UIManager:show(view)
    return view
end

return BookshelfGrid
