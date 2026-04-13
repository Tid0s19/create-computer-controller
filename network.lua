-- network.lua — Wireless sensor network + Stock Ticker for tag lookups

local network = {}
local ticker = nil
local modem = nil

local CHANNEL_CTRL = 4200   -- controller listens here
local CHANNEL_SENSOR = 4201 -- sensors listen + broadcast here

-- Sensor data: keyed by frogport address
local sensors = {}

function network.init()
    ticker = peripheral.find("Create_StockTicker")
    -- Stock Ticker is optional now — only needed for tag browsing

    modem = peripheral.find("modem", function(_, wrapped)
        return wrapped.isWireless()
    end)
    if not modem then
        return false, "No wireless modem found. Attach one to this computer."
    end

    modem.open(CHANNEL_SENSOR)
    modem.open(CHANNEL_CTRL)
    return true
end

function network.hasTicker()
    return ticker ~= nil
end

-- Process incoming sensor messages (call from parallel loop)
function network.listenForSensors()
    while true do
        local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
        if type(message) == "table" then
            if message.type == "sensor_report" and message.address then
                sensors[message.address] = {
                    items = message.items or {},
                    totalSlots = message.totalSlots or 0,
                    usedSlots = message.usedSlots or 0,
                    freeSlots = message.freeSlots or 0,
                    canSend = message.canSend or false,
                    lastSeen = os.clock(),
                }
            end
        end
    end
end

-- Get all known sensor addresses
function network.getSensorAddresses()
    local addrs = {}
    local now = os.clock()
    for addr, data in pairs(sensors) do
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

-- Find which sensors have a given item (excluding a specific address)
-- Returns list of { address, count } sorted by count descending
function network.findItemSources(itemName, excludeAddress)
    local sources = {}
    local now = os.clock()
    for addr, data in pairs(sensors) do
        if addr ~= excludeAddress and now - data.lastSeen < 30
           and data.canSend and data.items and data.items[itemName] then
            table.insert(sources, {
                address = addr,
                count = data.items[itemName],
            })
        end
    end
    table.sort(sources, function(a, b) return a.count > b.count end)
    return sources
end

-- Find which sensors have items matching a tag (excluding a specific address)
-- Returns list of { address, item, count }
function network.findTagSources(tag, excludeAddress)
    if not ticker then return {} end

    -- Get tagged item names from Stock Ticker
    local stock = network.getStock()
    local taggedItems = {}
    for _, item in ipairs(stock) do
        if item.tags and item.tags[tag] then
            taggedItems[item.name] = true
        end
    end

    local sources = {}
    local now = os.clock()
    for addr, data in pairs(sensors) do
        if addr ~= excludeAddress and now - data.lastSeen < 30
           and data.canSend and data.items then
            for itemName, count in pairs(data.items) do
                if taggedItems[itemName] and count > 0 then
                    table.insert(sources, {
                        address = addr,
                        item = itemName,
                        count = count,
                    })
                end
            end
        end
    end
    return sources
end

-- Send a command to a sensor to ship items
function network.commandSend(fromAddress, toAddress, itemName, count)
    if not modem then return end
    modem.transmit(CHANNEL_SENSOR, CHANNEL_CTRL, {
        type = "send_command",
        fromAddress = fromAddress,
        toAddress = toAddress,
        item = itemName,
        count = count,
    })
end

-- Stock Ticker methods (for tag/item browsing only)
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

return network
