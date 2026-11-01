local Library = {}
Library.__index = Library

-- KOOBONE's web client requests 49 volumes per page and follows the `p`
-- parameter until `totalpage`. Keep the same batch size so large libraries do
-- not require one oversized response on memory-constrained Kindle devices.
Library.PAGE_SIZE = 49

function Library:new(api, storage)
    return setmetatable({
        api = assert(api, "api required"),
        storage = assert(storage, "storage required"),
        items = {},
        fetched_at = 0,
    }, self)
end

function Library:refresh()
    local page = 1
    local total_pages
    local items, seen = {}, {}
    local last_response

    while true do
        local response, err = self.api:library(self.PAGE_SIZE, page)
        if not response then return nil, err end
        if type(response.data) ~= "table" then return nil, "书库分页响应无效" end

        local reported_page = tonumber(response.nowpage)
        if reported_page and reported_page > 0 and math.floor(reported_page) ~= page then
            return nil, "书库分页响应与请求页码不一致"
        end
        local reported_total_pages = tonumber(response.totalpage)
        if reported_total_pages and reported_total_pages > 0 then
            total_pages = math.floor(reported_total_pages)
        end

        local new_count = 0
        for _, item in ipairs(response.data) do
            local ok, key = pcall(self.storage.itemKey, self.storage, item)
            key = ok and tostring(key or "") or ""
            if key == "" or not seen[key] then
                if key ~= "" then seen[key] = true end
                items[#items + 1] = item
                new_count = new_count + 1
            end
        end
        last_response = response

        if total_pages and page >= total_pages then break end
        if not total_pages and #response.data < self.PAGE_SIZE then break end
        if #response.data == 0 then
            return nil, "KOOBONE 在书库结束前返回了空分页"
        end
        if new_count == 0 then
            return nil, "KOOBONE 返回了重复的书库分页，请稍后重试"
        end
        page = page + 1
    end

    local summary = {}
    for key, value in pairs(last_response or {}) do summary[key] = value end
    summary.data = items
    summary.nowpage = page
    summary.totalpage = total_pages or page
    if not tonumber(summary.total) or tonumber(summary.total) < #items then
        summary.total = #items
    end

    self.items = items
    self.fetched_at = os.time()
    return self.items, summary
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

