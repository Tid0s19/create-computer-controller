-- network.lua — Stock Ticker + wireless sensor network

local network = {}
local ticker = nil
local modem = nil

local CHANNEL = 4200       -- we listen on this
local REPLY_CHANNEL = 4201 -- sensors broadcast on this

-- Sensor data: keyed by frogport address
-- Each entry: { items = {}, totalSlots = N, freeSlots = N, lastSeen = clock }
local sensors = {}

function network.init()
    ticker = peripheral.find("Create_StockTicker")
    if not ticker then
        return false, "No Stock Ticker found. Place computer next to one."
    end

    modem = peripheral.find("modem", function(name, wrapped)
        return wrapped.isWireless()
    end)
    if not modem then
        return false, "No wireless modem found. Attach one to this computer."
    end

    modem.open(REPLY_CHANNEL)
    return true
end

-- Process incoming sensor messages (call from parallel loop)
function network.listenForSensors()
    while true do
        local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
        if channel == REPLY_CHANNEL and type(message) == "table"
           and message.type == "sensor_report" and message.address then
            sensors[message.address] = {
                items = message.items or {},
                totalSlots = message.totalSlots or 0,
                usedSlots = message.usedSlots or 0,
                freeSlots = message.freeSlots or 0,
                lastSeen = os.clock(),
            }
        end
    end
end

-- Get all known sensor addresses (auto-discovered destinations)
function network.getSensorAddresses()
    local addrs = {}
    local now = os.clock()
    for addr, data in pairs(sensors) do
        -- Only include sensors seen in last 30 seconds
        if now - data.lastSeen < 30 then
            table.insert(addrs, addr)
        end
    end
    table.sort(addrs)
    return addrs
end

-- Get sensor data for a specific address
function network.getSensor(address)
    local data = sensors[address]
    if not data then return nil end
    if os.clock() - data.lastSeen > 30 then return nil end
    return data
end

-- How many of a specific item are at a destination?
function network.getItemCountAt(address, itemName)
    local data = network.getSensor(address)
    if not data or not data.items then return 0 end
    return data.items[itemName] or 0
end

-- Get all items currently at a destination
function network.getItemsAt(address)
    local data = network.getSensor(address)
    if not data then return {} end
    return data.items or {}
end

-- Stock Ticker methods
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

function network.sendByTag(address, tag, maxCount)
    if not ticker then return 0 end
    local filter = { tags = { [tag] = true } }
    if maxCount then
        filter._requestCount = maxCount
    end
    local ok, result = pcall(ticker.requestFiltered, address, filter)
    if ok and type(result) == "number" then
        return result
    end
    return 0
end

return network
