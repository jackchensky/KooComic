local Library = {}
Library.__index = Library

function Library:new(api, storage)
    return setmetatable({
        api = assert(api, "api required"),
        storage = assert(storage, "storage required"),
        items = {},
        fetched_at = 0,
    }, self)
end

function Library:refresh()
    local response, err = self.api:library(28)
    if not response then return nil, err end
    self.items = response.data
    self.fetched_at = os.time()
    return self.items, response
end

function Library:freshItem(item)
    local items, err = self:refresh()
    if not items then return nil, err end
    local wanted = self.storage:itemKey(item)
    for _, candidate in ipairs(items) do
        if self.storage:itemKey(candidate) == wanted then return candidate end
    end
    return nil, "刷新书库后没有找到这本漫画"
end

return Library

