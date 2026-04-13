-- sensor.lua — Worker node for Create Controller
-- Place computer touching: wireless modem + chest/barrel + Packager
-- The Packager should connect to a Frogport on the chain conveyor
--
-- This sensor:
--   1. Reports chest inventory to the controller
--   2. Listens for "send" commands from the controller
--   3. Moves specific items from chest → Packager and ships them

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
            -- It's an inventory with transfer support
            -- Make sure it's not the packager
            local types = { peripheral.getType(name) }
            local isPackager = false
            for _, t in ipairs(types) do
                if t:find("packager") or t:find("Packager") then
                    isPackager = true
                end
            end
            if not isPackager then
                return p, name
            end
        end
    end
    return nil
end

local function findPackager()
    for _, name in ipairs(peripheral.getNames()) do
        local types = { peripheral.getType(name) }
        for _, t in ipairs(types) do
            if t:find("ackager") then
                local p = peripheral.wrap(name)
                if p and p.makePackage and p.setAddress then
                    return p, name
                end
            end
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
-- Send items via Packager
----------------------------------------------------------------------

local function sendItems(inv, invName, packager, packagerName, targetAddress, itemName, count)
    -- Set the packager to send to the target address
    packager.setAddress(targetAddress)

    -- Find slots in the chest containing the requested item
    local ok, contents = pcall(inv.list)
    if not ok or not contents then return 0 end

    local sent = 0
    for slot, item in pairs(contents) do
        if item.name == itemName and sent < count then
            local toMove = math.min(item.count, count - sent)
            -- Push items from chest to packager
            local moved = inv.pushItems(packagerName, slot, toMove)
            if moved and moved > 0 then
                sent = sent + moved
            end
        end
        if sent >= count then break end
    end

    -- Trigger the packager to create and send the package
    if sent > 0 then
        os.sleep(0.2) -- brief pause for items to settle
        pcall(packager.makePackage)
    end

    return sent
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

local packager, packagerName = findPackager()

-- Display status
term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Sensor: " .. address)
term.setTextColour(colours.white)
print("Chest: " .. invName)
if packager then
    term.setTextColour(colours.lime)
    print("Packager: " .. packagerName)
else
    term.setTextColour(colours.red)
    print("Packager: NOT FOUND")
    print("  (can receive but not send)")
end
print()
term.setTextColour(colours.lime)
print("Running...")
term.setTextColour(colours.grey)
print("Hold Ctrl+T to stop")

-- Run broadcast + command listener in parallel
parallel.waitForAny(
    -- Broadcast inventory periodically
    function()
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
                    canSend = packager ~= nil,
                })
            end
            os.sleep(BROADCAST_INTERVAL)
        end
    end,

    -- Listen for commands from controller
    function()
        while true do
            local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
            if channel == CHANNEL_SENSOR and type(message) == "table"
               and message.type == "send_command"
               and message.fromAddress == address then

                local result = 0
                if packager and inv then
                    -- Refresh inventory reference
                    inv, invName = findInventory()
                    packager, packagerName = findPackager()
                    if inv and packager then
                        result = sendItems(
                            inv, invName,
                            packager, packagerName,
                            message.toAddress,
                            message.item,
                            message.count
                        )
                    end
                end

                -- Report back
                modem.transmit(CHANNEL_CTRL, CHANNEL_SENSOR, {
                    type = "send_result",
                    fromAddress = address,
                    toAddress = message.toAddress,
                    item = message.item,
                    requested = message.count,
                    sent = result,
                })
            end
        end
    end
)
