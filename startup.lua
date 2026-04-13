-- startup.lua — Create Controller entry point
-- Place this file on the computer (or name it startup.lua for auto-run)
-- Computer must be placed adjacent to a Create 6.0 Stock Ticker

local config = require("config")
local network = require("network")
local router = require("router")
local ui = require("ui")

-- Initialise terminal
term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Create Controller v1.0")
print()
term.setTextColour(colours.white)

-- Connect to Stock Ticker
print("Connecting to Stock Ticker...")
local ok, err = network.init()
if not ok then
    term.setTextColour(colours.red)
    print("ERROR: " .. err)
    print()
    term.setTextColour(colours.white)
    print("Place this computer next to a Stock Ticker")
    print("and run this program again.")
    return
end
term.setTextColour(colours.lime)
print("Stock Ticker connected!")
term.setTextColour(colours.white)

-- Load config
print("Loading routes...")
local data = config.load()
print("Loaded " .. #data.routes .. " route(s)")
os.sleep(0.5)

-- Run UI and router in parallel
-- UI handles user interaction, router processes routes in the background
parallel.waitForAny(
    function()
        ui.run(data)
        -- UI exited, stop the router
        router.stop()
    end,
    function()
        router.run(data)
    end
)

-- Clean exit
term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Create Controller stopped.")
term.setTextColour(colours.white)
