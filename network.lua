-- network.lua — Create 6.0 logistics network interface
-- Wraps Stock Ticker peripheral (place computer adjacent to it)

local network = {}

-- Peripheral reference (lazy-loaded)
local ticker = nil

function network.init()
    ticker = peripheral.find("Create_StockTicker")
    if not ticker then
        return false, "No Stock Ticker found. Place computer next to a Stock Ticker."
    end
    return true
end

function network.hasTicker()
    return ticker ~= nil
end

--- Get all items currently in the logistics network.
-- @param detailed boolean — if true, includes tags, displayName, etc.
-- @return table — indexed list of item tables
function network.getStock(detailed)
    if not ticker then return {} end
    local ok, result = pcall(ticker.stock, detailed or false)
    if ok and result then
        return result
    end
    return {}
end

--- Get detailed info for a specific stock index.
-- @param index number
-- @return table or nil
function network.getStockDetail(index)
    if not ticker then return nil end
    local ok, result = pcall(ticker.getStockItemDetail, index)
    if ok then return result end
    return nil
end

--- Build a list of all unique tags found across all items in the network.
-- @return table — sorted list of tag strings
function network.getAllTags()
    local items = network.getStock(true)
    local tagSet = {}
    for _, item in ipairs(items) do
        if item.tags then
            for tag, _ in pairs(item.tags) do
                tagSet[tag] = true
            end
        end
    end
    local tags = {}
    for tag, _ in pairs(tagSet) do
        table.insert(tags, tag)
    end
    table.sort(tags)
    return tags
end

--- Build a list of all unique item names in the network.
-- @return table — sorted list of item name strings
function network.getAllItems()
    local items = network.getStock(false)
    local nameSet = {}
    for _, item in ipairs(items) do
        if item.name then
            nameSet[item.name] = true
        end
    end
    local names = {}
    for name, _ in pairs(nameSet) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- Check if an item name matches a glob pattern.
-- Supports * (any chars) and ? (single char).
local function globMatch(pattern, str)
    -- Escape lua pattern specials, then convert glob wildcards
    local p = pattern:gsub("([%.%+%-%^%$%(%)%%])", "%%%1")
    p = p:gsub("%*", ".*")
    p = p:gsub("%?", ".")
    return str:match("^" .. p .. "$") ~= nil
end

network.globMatch = globMatch

--- Check if an item should be excluded based on route exclusion rules.
-- @param itemDetail table — detailed item info (from stock(true))
-- @param exclusions table — { items={}, tags={}, globs={} }
-- @return boolean — true if the item should be excluded
function network.isExcluded(itemDetail, exclusions)
    if not exclusions then return false end

    -- Check item name exclusions
    if exclusions.items then
        for _, name in ipairs(exclusions.items) do
            if itemDetail.name == name then
                return true
            end
        end
    end

    -- Check tag exclusions
    if exclusions.tags and itemDetail.tags then
        for _, tag in ipairs(exclusions.tags) do
            if itemDetail.tags[tag] then
                return true
            end
        end
    end

    -- Check glob exclusions
    if exclusions.globs then
        for _, pattern in ipairs(exclusions.globs) do
            if globMatch(pattern, itemDetail.name) then
                return true
            end
        end
    end

    return false
end

--- Check if an item matches any of the route's include filters.
-- @param itemDetail table — detailed item info (from stock(true))
-- @param filters table — { items={}, tags={}, globs={} }
-- @return boolean
function network.matchesFilters(itemDetail, filters)
    if not filters then return false end

    -- If no filters defined at all, match nothing
    local hasAny = false
    for _, list in pairs(filters) do
        if #list > 0 then hasAny = true break end
    end
    if not hasAny then return false end

    -- Check item name matches
    if filters.items then
        for _, name in ipairs(filters.items) do
            if itemDetail.name == name then
                return true
            end
        end
    end

    -- Check tag matches
    if filters.tags and itemDetail.tags then
        for _, tag in ipairs(filters.tags) do
            if itemDetail.tags[tag] then
                return true
            end
        end
    end

    -- Check glob matches
    if filters.globs then
        for _, pattern in ipairs(filters.globs) do
            if globMatch(pattern, itemDetail.name) then
                return true
            end
        end
    end

    return false
end

--- Send items matching a route's filters (minus exclusions) to the destination.
-- Uses Stock Ticker's requestFiltered for efficiency.
-- @param route table — route config from config module
-- @return number — total items requested, or -1 on error
-- @return string|nil — error message if failed
function network.executeRoute(route)
    if not ticker then
        return -1, "No Stock Ticker"
    end
    if not route.address or route.address == "" then
        return -1, "No address set"
    end
    if not route.enabled then
        return 0, "Route disabled"
    end

    local maxPerItem = (route.stackCount or 1) * 64

    -- Get detailed stock to apply our filter/exclusion logic
    local stock = network.getStock(true)
    local totalRequested = 0

    for _, item in ipairs(stock) do
        if network.matchesFilters(item, route.filters) and
           not network.isExcluded(item, route.exclusions) then
            -- Use requestFiltered with an exact name match + count cap
            local count = math.min(item.count, maxPerItem)
            if count > 0 then
                local ok, result = pcall(ticker.requestFiltered, route.address,
                    { name = item.name, _requestCount = count })
                if ok and type(result) == "number" then
                    totalRequested = totalRequested + result
                end
            end
        end
    end

    return totalRequested
end

return network
