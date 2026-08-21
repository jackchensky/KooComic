local socket = require("socket")

local Util = {}

function Util.trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function Util.header(headers, name)
    if type(headers) ~= "table" then return nil end
    local wanted = tostring(name or ""):lower()
    for key, value in pairs(headers) do
        if type(key) == "string" and key:lower() == wanted then
            return value
        end
    end
end

function Util.cookieValue(set_cookie, name)
    if set_cookie == nil then return nil end
    if type(set_cookie) == "table" then
        for _, value in pairs(set_cookie) do
            local found = Util.cookieValue(value, name)
            if found then return found end
        end
        return nil
    end
    local escaped = tostring(name):gsub("([^%w])", "%%%1")
    return tostring(set_cookie):match(escaped .. "=([^;,%s]+)")
end

function Util.safeFilename(value)
    local name = Util.trim(value)
    name = name:gsub("[%c]", "_")
    name = name:gsub("[/\\:*?\"<>|]", "_")
    name = name:gsub("%.+$", "")
    name = name:gsub("%s+$", "")
    if name == "" then name = "KOOBONE" end
    return name
end

function Util.friendlySize(bytes)
    local value = tonumber(bytes) or 0
    if value >= 1024 * 1024 * 1024 then
        return string.format("%.2f GB", value / 1024 / 1024 / 1024)
    elseif value >= 1024 * 1024 then
        return string.format("%.1f MB", value / 1024 / 1024)
    elseif value >= 1024 then
        return string.format("%.1f KB", value / 1024)
    end
    return tostring(math.max(0, math.floor(value))) .. " B"
end

function Util.friendlyDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", math.floor(seconds / 3600),
            math.floor(seconds / 60) % 60, seconds % 60)
    end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function Util.now()
    if socket and type(socket.gettime) == "function" then
        return socket.gettime()
    end
    return os.time()
end

function Util.localDate(timestamp)
    return os.date("%Y-%m-%d", tonumber(timestamp) or os.time())
end

function Util.compareVersions(left, right)
    local function parse(value)
        local major, minor, patch = tostring(value or ""):match(
            "^v?(%d+)%.(%d+)%.(%d+)$")
        if not major then return nil end
        return { tonumber(major), tonumber(minor), tonumber(patch) }
    end
    local a, b = parse(left), parse(right)
    if not a or not b then return nil end
    for i = 1, 3 do
        if a[i] < b[i] then return -1 end
        if a[i] > b[i] then return 1 end
    end
    return 0
end

function Util.cleanMessage(value, limit)
    local text = tostring(value or ""):gsub("[%c]+", " "):gsub("%s+", " ")
    text = Util.trim(text)
    limit = tonumber(limit) or 240
    if #text > limit then text = text:sub(1, limit - 3) .. "..." end
    return text
end

return Util

