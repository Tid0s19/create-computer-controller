-- sensor.lua — Inventory reporter for Create Controller
-- Place computer touching: wireless modem + chest/barrel
-- Optional: attach a monitor to display inventory & fill level

local CHANNEL_CTRL = 4200   -- controller listens here
local CHANNEL_SENSOR = 4201 -- sensors listen + broadcast here
local BROADCAST_INTERVAL = 3
local CONFIG_FILE = "sensor.cfg"

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then return nil end
    local f = fs.open(CONFIG_FILE, "r")
    local raw = f.readAll()
    f.close()
    if not raw or raw == "" then return nil end

    -- Try JSON format first
    local ok, cfg = pcall(textutils.unserialiseJSON, raw)
    if ok and cfg and cfg.address then return cfg end

    -- Old plain-text format: migrate by prompting for port type
    local addr = raw:match("^%s*(.-)%s*$")
    if addr and addr ~= "" then
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColour(colours.yellow)
        print("Sensor Config Update")
        print()
        term.setTextColour(colours.white)
        print("Address: " .. addr)
        print()
        print("Is this port connected to")
        print("[S]torage or a [F]actory?")
        print()
        term.setTextColour(colours.cyan)
        write("> ")
        term.setTextColour(colours.white)
        while true do
            local _, key = os.pullEvent("key")
            if key == keys.s then
                local cfg = { address = addr, portType = "storage" }
                local fh = fs.open(CONFIG_FILE, "w")
                fh.write(textutils.serialiseJSON(cfg))
                fh.close()
                return cfg
            elseif key == keys.f then
                local cfg = { address = addr, portType = "factory" }
                local fh = fs.open(CONFIG_FILE, "w")
                fh.write(textutils.serialiseJSON(cfg))
                fh.close()
                return cfg
            end
        end
    end
    return nil
end

local function setupConfig()
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColour(colours.yellow)
    print("Create Controller - Sensor Setup")
    print()
    term.setTextColour(colours.white)
    print("Enter the frogport address this")
    print("sensor is connected to:")
    print()
    term.setTextColour(colours.cyan)
    write("> ")
    term.setTextColour(colours.white)
    local addr = read()
    if not addr or addr == "" then
        print("No address entered. Exiting.")
        return nil
    end

    print()
    print("Is this port connected to")
    print("[S]torage or a [F]actory?")
    print()
    term.setTextColour(colours.cyan)
    write("> ")
    term.setTextColour(colours.white)
    local portType
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.s then
            portType = "storage"
            break
        elseif key == keys.f then
            portType = "factory"
            break
        end
    end

    local cfg = { address = addr, portType = portType }
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialiseJSON(cfg))
    f.close()
    return cfg
end

local function findModem()
    return peripheral.find("modem", function(_, wrapped)
        return wrapped.isWireless()
    end)
end

local function findInventory()
    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        if p and p.list and p.size and p.pushItems then
            return p, name
        end
    end
    return nil
end

local function findMonitor()
    return peripheral.find("monitor")
end

----------------------------------------------------------------------
-- Inventory reading
----------------------------------------------------------------------

local function readInventory(inv)
    local items = {}
    local totalSlots = 0
    local usedSlots = 0

    local ok, contents = pcall(inv.list)
    if not ok or not contents then return items, 0, 0 end

    local ok2, size = pcall(inv.size)
    if ok2 then totalSlots = size end

    for slot, item in pairs(contents) do
        usedSlots = usedSlots + 1
        if items[item.name] then
            items[item.name] = items[item.name] + item.count
        else
            items[item.name] = item.count
        end
    end

    return items, totalSlots, usedSlots
end

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------

-- Auto-update from GitHub on boot
local hasUpdater, updater = pcall(require, "updater")
if hasUpdater and updater.check("sensor") then return end

local cfg = loadConfig() or setupConfig()
if not cfg then return end
local address = cfg.address
local portType = cfg.portType or "storage"

local modem = findModem()
if not modem then
    term.setTextColour(colours.red)
    print("No wireless modem found!")
    return
end

modem.open(CHANNEL_SENSOR)

local inv, invName = findInventory()
if not inv then
    term.setTextColour(colours.red)
    print("No inventory found!")
    print("Place next to a chest/barrel.")
    return
end

-- Optional monitor
local mon = findMonitor()

-- Try to load display module (downloaded with sensor installer)
local hasDisplay, display = pcall(require, "display")

-- Display status
term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Sensor: " .. address)
term.setTextColour(colours.white)
print("Type: " .. portType)
print("Chest: " .. invName)
if mon then
    term.setTextColour(colours.lime)
    print("Monitor: attached")
else
    term.setTextColour(colours.grey)
    print("Monitor: none")
end
print()
term.setTextColour(colours.lime)
print("Running...")
term.setTextColour(colours.grey)
print("Hold Ctrl+T to stop")

-- Broadcast inventory periodically
while true do
    inv = findInventory() or inv
    if inv then
        local items, totalSlots, usedSlots = readInventory(inv)
        modem.transmit(CHANNEL_SENSOR, CHANNEL_CTRL, {
            type = "sensor_report",
            address = address,
            portType = portType,
            items = items,
            totalSlots = totalSlots,
            usedSlots = usedSlots,
            freeSlots = totalSlots - usedSlots,
        })

        -- Update monitor if present
        if not mon then mon = findMonitor() end
        if mon and hasDisplay then
            pcall(display.sensor, mon, address, items, totalSlots, usedSlots)
        end
    end
    os.sleep(BROADCAST_INTERVAL)
end
