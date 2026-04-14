-- pocket.lua — Remote configuration client for Configure Storage
-- Run on a wireless pocket computer to manage config on the move
-- Connects to the server wirelessly to browse items, edit rules, etc.

-- Auto-update from GitHub on boot
local hasUpdater, updater = pcall(require, "updater")
if hasUpdater and updater.check("pocket") then return end

local CHANNEL_SERVER = 4202
local REPLY_CHANNEL = 4203 + os.getComputerID()

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

local modem = peripheral.find("modem", function(_, w) return w.isWireless() end)
if not modem then
    term.setTextColour(colours.red)
    print("No wireless modem found!")
    return
end
modem.open(REPLY_CHANNEL)

-- Send a request to the server and wait for a response
local function request(msg, timeout)
    timeout = timeout or 5
    modem.transmit(CHANNEL_SERVER, REPLY_CHANNEL, msg)
    local timer = os.startTimer(timeout)
    while true do
        local ev = {os.pullEvent()}
        if ev[1] == "modem_message" and ev[3] == REPLY_CHANNEL and type(ev[5]) == "table" then
            os.cancelTimer(timer)
            return ev[5]
        elseif ev[1] == "timer" and ev[2] == timer then
            return nil
        end
    end
end

----------------------------------------------------------------------
-- Connect
----------------------------------------------------------------------

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Configure Storage")
print("  Pocket Client")
print()
term.setTextColour(colours.white)
print("Connecting to server...")

local resp = request({type = "ping"})
if not resp or resp.type ~= "pong" then
    term.setTextColour(colours.red)
    print("No server found!")
    print()
    print("Make sure the server is")
    print("running and within wireless")
    print("range (~64 blocks).")
    return
end
term.setTextColour(colours.lime)
print("Connected!")

print("Loading config...")
local configResp = request({type = "config_request"})
if not configResp or not configResp.data then
    term.setTextColour(colours.red)
    print("Failed to load config!")
    return
end

local data = configResp.data
if not data.groups then data.groups = {} end
if not data.destinations then data.destinations = {} end

----------------------------------------------------------------------
-- Proxy config module
----------------------------------------------------------------------

local configProxy = {}

function configProxy.load()
    return data
end

function configProxy.save(d)
    data = d
    request({type = "config_save", data = d}, 3)
end

package.loaded.config = configProxy

----------------------------------------------------------------------
-- Proxy network module (fetches from server)
----------------------------------------------------------------------

local sensorCache = {}
local stockCache = nil
local stockCacheTime = 0

local function refreshSensors()
    local resp = request({type = "get_sensors"}, 3)
    if resp and resp.sensors then
        sensorCache = resp.sensors
    end
end

local function refreshStock()
    local now = os.clock()
    if stockCache and now - stockCacheTime < 10 then return end
    local resp = request({type = "get_stock"}, 5)
    if resp and resp.stock then
        stockCache = resp.stock
        stockCacheTime = now
    end
end

local networkProxy = {}

function networkProxy.init() return true end
function networkProxy.hasTicker() return true end

function networkProxy.getSensorAddresses()
    refreshSensors()
    local addrs = {}
    for addr in pairs(sensorCache) do
        table.insert(addrs, addr)
    end
    table.sort(addrs)
    return addrs
end

function networkProxy.getSensor(address)
    refreshSensors()
    return sensorCache[address]
end

function networkProxy.getItemCountAt(address, itemName)
    refreshSensors()
    local s = sensorCache[address]
    if not s or not s.items then return 0 end
    return s.items[itemName] or 0
end

function networkProxy.getSensorPortType(address)
    refreshSensors()
    local s = sensorCache[address]
    if not s then return "storage" end
    return s.portType or "storage"
end

function networkProxy.getGroupSensor(addresses)
    refreshSensors()
    local totalItems = {}
    local totalSlots = 0
    local usedSlots = 0
    local freeSlots = 0
    local anyOnline = false

    for _, addr in ipairs(addresses) do
        local data = sensorCache[addr]
        if data then
            anyOnline = true
            for name, count in pairs(data.items or {}) do
                totalItems[name] = (totalItems[name] or 0) + count
            end
            totalSlots = totalSlots + (data.totalSlots or 0)
            usedSlots = usedSlots + (data.usedSlots or 0)
            freeSlots = freeSlots + (data.freeSlots or 0)
        end
    end

    if not anyOnline then return nil end
    return {
        items = totalItems,
        totalSlots = totalSlots,
        usedSlots = usedSlots,
        freeSlots = freeSlots,
    }
end

function networkProxy.getGroupItemCount(addresses, itemName)
    refreshSensors()
    local total = 0
    for _, addr in ipairs(addresses) do
        local s = sensorCache[addr]
        if s and s.items then
            total = total + (s.items[itemName] or 0)
        end
    end
    return total
end

function networkProxy.getStockElsewhere(excludeAddresses, itemName)
    refreshSensors()
    local excludeSet = {}
    for _, addr in ipairs(excludeAddresses) do
        excludeSet[addr] = true
    end
    local total = 0
    for addr, data in pairs(sensorCache) do
        if not excludeSet[addr] and (data.portType or "storage") ~= "factory" then
            if data.items and data.items[itemName] then
                total = total + data.items[itemName]
            end
        end
    end
    return total
end

function networkProxy.getStockMapElsewhere(excludeAddresses)
    refreshSensors()
    local excludeSet = {}
    for _, addr in ipairs(excludeAddresses) do
        excludeSet[addr] = true
    end
    local map = {}
    for addr, data in pairs(sensorCache) do
        if not excludeSet[addr] and (data.portType or "storage") ~= "factory" then
            for name, count in pairs(data.items or {}) do
                map[name] = (map[name] or 0) + count
            end
        end
    end
    return map
end

function networkProxy.getTaggedStockElsewhere(excludeAddresses, tag)
    refreshStock()
    if not stockCache then return {} end
    local elsewhereMap = networkProxy.getStockMapElsewhere(excludeAddresses)
    local result = {}
    for _, item in ipairs(stockCache) do
        if item.tags and item.tags[tag] then
            local available = elsewhereMap[item.name] or 0
            if available > 0 then
                table.insert(result, { name = item.name, count = available })
            end
        end
    end
    return result
end

function networkProxy.getBestAddress(addresses)
    refreshSensors()
    local best = addresses[1]
    local bestFree = -1
    for _, addr in ipairs(addresses) do
        local s = sensorCache[addr]
        if s and (s.freeSlots or 0) > bestFree then
            bestFree = s.freeSlots
            best = addr
        end
    end
    return best
end

function networkProxy.getStock()
    refreshStock()
    return stockCache or {}
end

function networkProxy.getAllItems()
    refreshStock()
    if not stockCache then return {} end
    local seen = {}
    local result = {}
    for _, item in ipairs(stockCache) do
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

function networkProxy.getAllTags()
    refreshStock()
    if not stockCache then return {} end
    local tagSet = {}
    for _, item in ipairs(stockCache) do
        if item.tags then
            for tag in pairs(item.tags) do
                tagSet[tag] = true
            end
        end
    end
    local tags = {}
    for tag in pairs(tagSet) do
        table.insert(tags, tag)
    end
    table.sort(tags)
    return tags
end

package.loaded.network = networkProxy

----------------------------------------------------------------------
-- Run UI
----------------------------------------------------------------------

term.setTextColour(colours.grey)
print("Starting UI...")
os.sleep(0.5)

local ui = require("ui")
ui.run(data)

term.clear()
term.setCursorPos(1, 1)
print("Disconnected.")
