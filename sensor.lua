-- sensor.lua — Destination sensor for Create Controller
-- Place computer + wireless modem next to the destination chest/barrel
-- Run: sensor <frogport-address>
-- Or install as startup.lua and it will prompt for the address on first run

local CHANNEL = 4200       -- main listening channel
local REPLY_CHANNEL = 4201 -- sensor broadcast channel
local BROADCAST_INTERVAL = 3
local CONFIG_FILE = "sensor.cfg"

-- Load or prompt for address
local function getAddress()
    if fs.exists(CONFIG_FILE) then
        local f = fs.open(CONFIG_FILE, "r")
        local addr = f.readAll()
        f.close()
        if addr and addr ~= "" then return addr:match("^%s*(.-)%s*$") end
    end

    -- Check command line args
    local args = { ... }
    if args[1] and args[1] ~= "" then
        local f = fs.open(CONFIG_FILE, "w")
        f.write(args[1])
        f.close()
        return args[1]
    end

    -- Prompt
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColour(colours.yellow)
    print("Create Controller - Sensor Setup")
    print()
    term.setTextColour(colours.white)
    print("Enter the frogport address this")
    print("sensor monitors:")
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

-- Find wireless modem
local function findModem()
    local modem = peripheral.find("modem", function(name, wrapped)
        return wrapped.isWireless()
    end)
    return modem
end

-- Find inventory (chest, barrel, vault, etc.)
local function findInventory()
    for _, name in ipairs(peripheral.getNames()) do
        local types = { peripheral.getType(name) }
        for _, t in ipairs(types) do
            if t == "inventory" or t:find("chest") or t:find("barrel")
               or t:find("shulker") or t:find("vault") or t:find("crate") then
                local p = peripheral.wrap(name)
                if p and p.list then
                    return p, name
                end
            end
        end
        -- Fallback: anything with a list() method
        local p = peripheral.wrap(name)
        if p and p.list and not p.isWireless then
            return p, name
        end
    end
    return nil
end

-- Read inventory contents, summarised by item name
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

-- Main
local address = getAddress()
if not address then return end

local modem = findModem()
if not modem then
    term.setTextColour(colours.red)
    print("No wireless modem found!")
    print("Attach one and try again.")
    return
end

modem.open(CHANNEL)

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
print("Inventory: " .. invName)
print("Broadcasting on ch " .. REPLY_CHANNEL)
print()
term.setTextColour(colours.lime)
print("Running...")
term.setTextColour(colours.grey)
print()
print("Hold Ctrl+T to stop")

-- Broadcast loop
while true do
    -- Re-find inventory in case it was broken/replaced
    inv = findInventory()
    if inv then
        local items, totalSlots, usedSlots = readInventory(inv)
        local message = {
            type = "sensor_report",
            address = address,
            items = items,
            totalSlots = totalSlots,
            usedSlots = usedSlots,
            freeSlots = totalSlots - usedSlots,
        }
        modem.transmit(REPLY_CHANNEL, CHANNEL, message)
    end
    os.sleep(BROADCAST_INTERVAL)
end
