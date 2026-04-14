-- display.lua — Monitor display for controller and sensors

local display = {}

----------------------------------------------------------------------
-- Color helpers
----------------------------------------------------------------------

local function usageColor(pct)
    if pct < 25 then return colours.lime
    elseif pct < 50 then return colours.yellow
    elseif pct < 75 then return colours.orange
    else return colours.red end
end

local function drawBar(mon, x, y, width, pct)
    local filled = math.floor(width * pct / 100)
    if filled > width then filled = width end
    mon.setCursorPos(x, y)
    if filled > 0 then
        mon.setBackgroundColour(usageColor(pct))
        mon.write(string.rep(" ", filled))
    end
    if width - filled > 0 then
        mon.setBackgroundColour(colours.grey)
        mon.write(string.rep(" ", width - filled))
    end
    mon.setBackgroundColour(colours.black)
end

----------------------------------------------------------------------
-- Controller monitor: all managed storages
----------------------------------------------------------------------

function display.controller(mon, data, network)
    local mW, mH = mon.getSize()
    mon.setBackgroundColour(colours.black)
    mon.clear()

    -- Title
    mon.setCursorPos(1, 1)
    mon.setBackgroundColour(colours.grey)
    mon.write(string.rep(" ", mW))
    mon.setCursorPos(2, 1)
    mon.setTextColour(colours.yellow)
    mon.write("Configure Storage")
    mon.setBackgroundColour(colours.black)

    local y = 3
    for _, dest in ipairs(data.destinations) do
        if y + 1 > mH then break end

        local sensor = network.getGroupSensor(dest.addresses)
        local pct = 0
        local pctText = "?"

        if sensor and sensor.totalSlots > 0 then
            pct = math.floor(sensor.usedSlots / sensor.totalSlots * 100)
            pctText = pct .. "%"
        elseif not sensor then
            pctText = "offline"
        end

        -- Name and percentage
        mon.setCursorPos(2, y)
        mon.setTextColour(colours.white)
        local nameW = mW - #pctText - 3
        local name = dest.name
        if #name > nameW then name = name:sub(1, nameW - 2) .. ".." end
        mon.write(name)

        mon.setCursorPos(mW - #pctText, y)
        if sensor then
            mon.setTextColour(usageColor(pct))
        else
            mon.setTextColour(colours.red)
        end
        mon.write(pctText)

        -- Progress bar
        y = y + 1
        if y <= mH and sensor then
            drawBar(mon, 2, y, mW - 2, pct)
        end

        y = y + 2
    end

    if #data.destinations == 0 then
        mon.setCursorPos(2, 3)
        mon.setTextColour(colours.grey)
        mon.write("No containers configured")
    end
end

----------------------------------------------------------------------
-- Sensor monitor: this sensor's inventory
----------------------------------------------------------------------

function display.sensor(mon, address, items, totalSlots, usedSlots)
    local mW, mH = mon.getSize()
    mon.setBackgroundColour(colours.black)
    mon.clear()

    local pct = 0
    if totalSlots > 0 then
        pct = math.floor(usedSlots / totalSlots * 100)
    end

    -- Title bar
    mon.setCursorPos(1, 1)
    mon.setBackgroundColour(colours.grey)
    mon.write(string.rep(" ", mW))
    mon.setCursorPos(2, 1)
    mon.setTextColour(colours.yellow)
    local title = address
    if #title > mW - 6 then title = title:sub(1, mW - 8) .. ".." end
    mon.write(title)

    local pctText = pct .. "%"
    mon.setCursorPos(mW - #pctText, 1)
    mon.setTextColour(usageColor(pct))
    mon.write(pctText)
    mon.setBackgroundColour(colours.black)

    -- Progress bar
    drawBar(mon, 2, 3, mW - 2, pct)

    -- Slot info
    mon.setCursorPos(2, 4)
    mon.setTextColour(colours.grey)
    mon.write(usedSlots .. "/" .. totalSlots .. " slots")

    -- Item list
    local sorted = {}
    for name, count in pairs(items) do
        table.insert(sorted, { name = name, count = count })
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    local y = 6
    for _, item in ipairs(sorted) do
        if y > mH then break end

        -- Shorten item name (remove namespace)
        local short = item.name:gsub("^[^:]+:", "")
        short = short:gsub("_", " ")
        local countStr = tostring(item.count)
        local nameW = mW - #countStr - 3

        mon.setCursorPos(2, y)
        mon.setTextColour(colours.white)
        if #short > nameW then short = short:sub(1, nameW - 2) .. ".." end
        mon.write(short)

        mon.setCursorPos(mW - #countStr, y)
        mon.setTextColour(colours.lightGrey)
        mon.write(countStr)

        y = y + 1
    end

    if #sorted == 0 then
        mon.setCursorPos(2, 6)
        mon.setTextColour(colours.grey)
        mon.write("Empty")
    end
end

return display
