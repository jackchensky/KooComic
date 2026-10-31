-- SPDX-License-Identifier: AGPL-3.0-only
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local ImageWidget = require("ui/widget/imagewidget")
local Widget = require("ui/widget/widget")
local Surface = require("koobone.ui.book_surface")

-- One bounded entry reused when a shelf rebuilds. Each widget owns a copy,
-- so replacing this cache cannot invalidate a still-visible widget.
local cache_key, cache_bb
local CurvedCover = Widget:extend{
    width = 1, height = 1, path = nil, warm = false, side = "left",
}

function CurvedCover:getSize()
    return Geom:new{ w = self.width, h = self.height }
end

function CurvedCover:_prepare()
    local side = self.side == "right" and "right" or "left"
    local key = table.concat({self.path or "", self.width, self.height,
        self.warm and 1 or 0, side}, "|")
    local source, probe, loader, output
    local ok = pcall(function()
        if key ~= cache_key or not cache_bb then
            local sw = math.max(1, math.ceil(self.width * 148/400))
            local sh = math.max(1, math.ceil(self.height * 189/280))
            source = Blitbuffer.new(sw, sh, Blitbuffer.TYPE_BBRGB32)
            source:paintRectRGB32(0, 0, sw, sh, Blitbuffer.ColorRGB32(
                255, self.warm and 253 or 255, self.warm and 247 or 255, 255))
            probe = ImageWidget:new{
                file = self.path, scale_factor = 1,
                file_do_cache = true, original_in_nightmode = false,
            }
            local natural = probe:getSize()
            local source_w = probe.getOriginalWidth and probe:getOriginalWidth() or natural.w
            local source_h = probe.getOriginalHeight and probe:getOriginalHeight() or natural.h
            source_w, source_h = math.max(1, source_w), math.max(1, source_h)
            local fill_scale = math.max(sw/source_w, sh/source_h)
            probe:free(); probe = nil
            -- Scale to cover and crop from the center. This removes the paper
            -- rectangle previously visible around portrait comic covers.
            loader = ImageWidget:new{
                file = self.path, width = sw, height = sh,
                scale_factor = fill_scale, center_x_ratio = 0.5, center_y_ratio = 0.5,
                file_do_cache = true, original_in_nightmode = false,
            }
            loader:getSize()
            loader:paintTo(source, 0, 0)
            output = Blitbuffer.new(self.width, self.height, Blitbuffer.TYPE_BBRGB32)
            output:paintRectRGB32(0, 0, self.width, self.height, Blitbuffer.ColorRGB32(0,0,0,0))
            local pixel = Blitbuffer.ColorRGB32(0,0,0,0)
            Surface.render(self.width, self.height, sw, sh,
                function(x,y)
                    local c = source:getPixel(x,y)
                    return c.r, c.g, c.b
                end,
                function(x,y,r,g,b,a)
                    pixel.r, pixel.g, pixel.b, pixel.alpha = r,g,b,a
                    output:setPixel(x,y,pixel)
                end, side)
            if cache_bb then cache_bb:free() end
            cache_key, cache_bb = key, output
            output = nil
        end
        self._bb = cache_bb:copy()
    end)
    if probe then probe:free() end
    if loader then loader:free() end
    if source then source:free() end
    if output then output:free() end
    if not ok then self._failed = true end
    return ok
end

function CurvedCover:paintTo(bb, x, y)
    if self._failed then return end
    if not self._bb and not self:_prepare() then return end
    -- Our pixels are straight alpha (ImageWidget's default memory-image path
    -- assumes premultiplied alpha). Blend explicitly to avoid dark fringes.
    bb:alphablitFrom(self._bb, x, y, 0, 0, self.width, self.height)
end

function CurvedCover:free()
    if self._bb then self._bb:free(); self._bb = nil end
    self._failed = nil
end

return CurvedCover
