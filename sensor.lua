-- sensor.lua — Inventory reporter for Create Controller
-- Place computer touching: wireless modem + chest/barrel
-- Reports chest inventory to the controller so it knows
-- what's at this frogport destination.

local CHANNEL_CTRL = 4200   -- controller listens here
local CHANNEL_SENSOR = 4201 -- sensors listen + broadcast here
local BROADCAST_INTERVAL = 3
local CONFIG_FILE = "sensor.cfg"

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------

local function getAddress()
    if fs.exists(CONFIG_FILE) then
        local f = fs.open(CONFIG_FILE, "r")
        local addr = f.readAll()
        f.close()
        if addr and addr ~= "" then return addr:match("^%s*(.-)%s*$") end
    end

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
    local f = fs.open(CONFIG_FILE, "w")
    f.write(addr)
    f.close()
    return addr
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

local address = getAddress()
if not address then return end

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

-- Display status
term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Sensor: " .. address)
term.setTextColour(colours.white)
print("Chest: " .. invName)
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
            items = items,
            totalSlots = totalSlots,
            usedSlots = usedSlots,
            freeSlots = totalSlots - usedSlots,
        })
    end
    os.sleep(BROADCAST_INTERVAL)
end
