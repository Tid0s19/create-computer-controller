-- network.lua — Stock Ticker wrapper

local network = {}
local ticker = nil

function network.init()
    ticker = peripheral.find("Create_StockTicker")
    if not ticker then
        return false, "No Stock Ticker found. Place computer next to one."
    end
    return true
end

function network.getStock()
    if not ticker then return {} end
    local ok, result = pcall(ticker.stock, true)
    if ok and result then return result end
    return {}
end

function network.getAllTags()
    local items = network.getStock()
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

function network.getAllItems()
    local items = network.getStock()
    local seen = {}
    local result = {}
    for _, item in ipairs(items) do
        if item.name and not seen[item.name] then
            seen[item.name] = true
            table.insert(result, {
                name = item.name,
                displayName = item.displayName or item.name,
                count = item.count,
            })
        end
    end
    table.sort(result, function(a, b) return a.displayName < b.displayName end)
    return result
end

function network.sendItem(address, itemName, count)
    if not ticker then return 0 end
    local ok, result = pcall(ticker.requestFiltered, address,
        { name = itemName, _requestCount = count })
    if ok and type(result) == "number" then
        return result
    end
    return 0
end

function network.sendByTag(address, tag)
    if not ticker then return 0 end
    local ok, result = pcall(ticker.requestFiltered, address,
        { tags = { [tag] = true } })
    if ok and type(result) == "number" then
        return result
    end
    return 0
end

return network
