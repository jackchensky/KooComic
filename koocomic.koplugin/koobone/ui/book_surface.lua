-- SPDX-License-Identifier: AGPL-3.0-only
-- Left page of artwork/open-book-*.svg, in its 400 x 280 coordinates.
-- Pure Lua: also used to render the desktop preview and test the mapping.
local Surface = {}
local min, max, floor = math.min, math.max, math.floor
local function clamp(n, lo, hi) return max(lo, min(hi, n)) end

local function leftPoint(u, v)
    return 30 + 162*u + 6*u*u + v*(-12 + 18*u - 6*u*u),
        26 - 40*u + 49*u*u + v*(210 + 6*u - 8*u*u)
end

function Surface.point(u, v, side)
    if side == "right" then
        local x, y = leftPoint(1 - u, v)
        return 400 - x, y
    end
    return leftPoint(u, v)
end

local function leftInverse(x, y)
    local u, v = (x - 30)/168, (y - 26)/210
    for _ = 1, 4 do
        local px, py = leftPoint(u, v)
        local xu, xv = 162 + 12*u + v*(18 - 12*u), -12 + 18*u - 6*u*u
        local yu, yv = -40 + 98*u + v*(6 - 16*u), 210 + 6*u - 8*u*u
        local det = xu*yv - xv*yu
        if math.abs(det) < 1e-8 then return nil end
        local dx, dy = px - x, py - y
        u, v = u - (dx*yv - dy*xv)/det, v - (dy*xu - dx*yu)/det
    end
    return u, v
end


function Surface.inverse(x, y, side)
    if side == "right" then
        local u, v = leftInverse(400 - x, y)
        return u and 1 - u or nil, v
    end
    return leftInverse(x, y)
end

-- sample(x,y) returns RGB from a small, aspect-fitted thumbnail.
-- write(x,y,r,g,b,alpha) receives straight-alpha pixels, not premultiplied.
function Surface.render(width, height, sw, sh, sample, write, side)
    side = side == "right" and "right" or "left"
    local start_x = side == "right" and math.floor(width/2) or 0
    local end_x = side == "right" and width - 1 or math.ceil(width/2) - 1
    for y = 0, height - 1 do
        for x = start_x, end_x do
            local u, v = Surface.inverse((x + .5)*400/width, (y + .5)*280/height, side)
            if u then
                -- Fill the whole paper surface. The alpha feather below keeps
                -- the original page outline visible without adding a white
                -- rectangular picture mat around narrow comic covers.
                local s, t = u, v
                local edge = min(s, 1-s)*148*width/400
                edge = min(edge, min(t, 1-t)*189*height/280)
                local alpha = floor(clamp(edge + .5, 0, 1)*255+.5)
                if alpha > 0 then
                    s, t = clamp(s, 0, 1), clamp(t, 0, 1)
                    -- A little horizontal compression towards the gutter.
                    local bend = .055*math.sin(math.pi*s)
                    local tex_s = side == "right" and s + bend or s - bend
                    local fx, fy = tex_s*(sw-1), t*(sh-1)
                    local x0, y0 = floor(fx), floor(fy)
                    local x1, y1 = min(sw-1, x0+1), min(sh-1, y0+1)
                    local ax, ay = fx-x0, fy-y0
                    local r00,g00,b00 = sample(x0,y0)
                    local r10,g10,b10 = sample(x1,y0)
                    local r01,g01,b01 = sample(x0,y1)
                    local r11,g11,b11 = sample(x1,y1)
                    local w00, w10 = (1-ax)*(1-ay), ax*(1-ay)
                    local w01, w11 = (1-ax)*ay, ax*ay
                    local gutter, outside = side == "right" and (1-s) or s,
                        side == "right" and s or (1-s)
                    local shade = 1 - .18*gutter^6 - .04*outside^8
                    write(x,y,
                        floor((r00*w00+r10*w10+r01*w01+r11*w11)*shade+.5),
                        floor((g00*w00+g10*w10+g01*w01+g11*w11)*shade+.5),
                        floor((b00*w00+b10*w10+b01*w01+b11*w11)*shade+.5),
                        alpha)
                end
            end
        end
    end
end

return Surface
