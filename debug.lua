-- debug.lua — Dump detailed stock data for an item
-- Usage: debug <search term>
-- Example: debug tuff

local args = {...}
local search = (args[1] or ""):lower()

if search == "" then
    print("Usage: debug <item name>")
    print("Example: debug tuff")
    return
end

local t = peripheral.find("Create_StockTicker")
if not t then
    print("No Stock Ticker found!")
    return
end

print("Scanning for '" .. search .. "'...")
local stock = t.stock(true)

local out = ""
local found = false
for i, item in ipairs(stock) do
    if item.name:lower():find(search, 1, true) or
       (item.displayName and item.displayName:lower():find(search, 1, true)) then
        found = true
        out = out .. "=== " .. (item.displayName or item.name) .. " ===\n"
        out = out .. textutils.serialise(item) .. "\n\n"
    end
end

if not found then
    print("No items matching '" .. search .. "' found in network.")
else
    local f = fs.open("debug_out.txt", "w")
    f.write(out)
    f.close()
    print("Written to debug_out.txt")
    print("View with: edit debug_out.txt")
end
