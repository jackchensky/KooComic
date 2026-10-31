package.path = "./koocomic.koplugin/?.lua;" .. package.path
local Surface = require("koobone.ui.book_surface")
-- Geometry must match the original SVG page corners and remain invertible.
for _, corner in ipairs({{0,0,30,26},{1,0,198,35},{0,1,18,236},{1,1,198,243}}) do
    local x,y = Surface.point(corner[1],corner[2])
    assert(x == corner[3] and y == corner[4])
end
for _, corner in ipairs({{0,0,202,35},{1,0,370,26},{0,1,202,243},{1,1,382,236}}) do
    local x,y = Surface.point(corner[1],corner[2],"right")
    assert(x == corner[3] and y == corner[4])
end
for u=0,1,.05 do for v=0,1,.05 do
    local x,y = Surface.point(u,v)
    local ru,rv = Surface.inverse(x,y)
    assert(math.abs(u-ru)<1e-6 and math.abs(v-rv)<1e-6)
    x,y = Surface.point(u,v,"right")
    ru,rv = Surface.inverse(x,y,"right")
    assert(math.abs(u-ru)<1e-6 and math.abs(v-rv)<1e-6)
end end
for _,side in ipairs({"left","right"}) do for _,w in ipairs({1,60,120,160,240,400}) do
    local h, painted, partial = math.max(1,math.floor(w*.7)), 0, 0
    local sw,sh=math.max(1,math.ceil(w*.37)),math.max(1,math.ceil(h*.675))
    Surface.render(w,h,sw,sh,function(x,y)
        assert(x>=0 and x<sw and y>=0 and y<sh)
        assert(x==math.floor(x) and y==math.floor(y))
        return 180,120,60
    end,function(x,y,r,g,b,a)
        if side=="right" then
            assert(x>=math.floor(w/2) and x<w and y>=0 and y<h)
        else
            assert(x>=0 and x<math.ceil(w/2) and y>=0 and y<h)
        end
        assert(r<=180 and g<=120 and b<=60 and r>0 and a>0 and a<=255)
        painted=painted+1
        if a<255 then partial=partial+1 end
    end,side)
    if w>=60 then assert(painted>w*h*.18 and painted<w*h*.35 and partial>0) end
end end

-- Exercise resource ownership separately from KOReader's native renderer.
local live,loads = 0,0
local function color(r,g,b,a) return {r=r,g=g,b=b,alpha=a} end
local function buffer(w,h)
    live=live+1
    local bb={w=w,h=h}
    function bb:paintRectRGB32() assert(not self.freed) end
    function bb:getPixel(x,y)
        assert(not self.freed and x>=0 and x<self.w and y>=0 and y<self.h)
        return color(180,120,60,255)
    end
    function bb:setPixel(x,y,c)
        assert(not self.freed and x>=0 and x<self.w and y>=0 and y<self.h and c.alpha>0)
    end
    function bb:copy() assert(not self.freed); return buffer(self.w,self.h) end
    function bb:free() assert(not self.freed); self.freed=true;live=live-1 end
    return bb
end
package.preload['ffi/blitbuffer']=function()
    return {new=buffer,ColorRGB32=color,TYPE_BBRGB32=1}
end
local Widget={}
function Widget:extend(fields) return setmetatable(fields,{__index=self}) end
function Widget:new(fields) return setmetatable(fields,{__index=self}) end
package.preload['ui/widget/widget']=function() return Widget end
package.preload['ui/geometry']=function() return {new=function(_,f)return f end} end
package.preload['ui/widget/imagewidget']=function()
    return {new=function(_,opts)
        loads=loads+1
        return {
            getSize=function()
                if opts.file=='bad' then error('decode failed') end
                return {w=opts.width or 100,h=opts.height or 150}
            end,
            getOriginalWidth=function() return 100 end,
            getOriginalHeight=function() return 150 end,
            paintTo=function() end,free=function() end,
        }
    end}
end
local Cover=require('koobone.ui.curved_cover')
local target={alphablitFrom=function(_,bb)assert(not bb.freed)end}
local function make(path) return Cover:new{path=path,width=60,height=42} end
local first=make('first');first:paintTo(target,0,0)
assert(live==2 and loads==2 and first._bb)
first:paintTo(target,0,0);assert(loads==2)
local second=make('first');second:paintTo(target,0,0)
assert(live==3 and loads==2 and second._bb~=first._bb)
first:free();assert(live==2)
local third=make('third');third:paintTo(target,0,0)
assert(live==3 and loads==4)
second:paintTo(target,0,0) -- Cache replacement must not invalidate this copy.
second:free();third:free();assert(live==1)
local bad=make('bad');bad:paintTo(target,0,0)
assert(live==1 and bad._failed and loads==5)
bad:paintTo(target,0,0);assert(loads==5) -- No failing decode on every repaint.
print('book surface spec: geometry, sampling, cache ownership and decode failure OK')
