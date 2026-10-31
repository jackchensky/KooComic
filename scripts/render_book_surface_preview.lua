-- Preview adapter: uses the exact Lua surface mapping shipped in the plugin.
package.path = "./koocomic.koplugin/?.lua;" .. package.path
local Surface = require("koobone.ui.book_surface")
local input, output = arg[1], arg[2]
local w,h,sw,sh = tonumber(arg[3]),tonumber(arg[4]),tonumber(arg[5]),tonumber(arg[6])
local file = assert(io.open(input,"rb"))
local data = file:read("*all"); file:close()
assert(#data == sw*sh*3)
local pixels = {}
Surface.render(w,h,sw,sh,
    function(x,y)
        local at = (y*sw+x)*3+1
        return data:byte(at,at+2)
    end,
    function(x,y,r,g,b,a) pixels[y*w+x+1] = string.char(r,g,b,a) end)
file = assert(io.open(output,"wb"))
for y=0,h-1 do
    local row={}
    for x=0,w-1 do row[#row+1] = pixels[y*w+x+1] or string.char(0,0,0,0) end
    file:write(table.concat(row))
end
file:close()
