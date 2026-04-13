-- startup.lua — Create Controller
-- Place computer adjacent to Stock Ticker + wireless modem
-- Optional: attach a monitor to display all managed storages

local config = require("config")
local network = require("network")
local router = require("router")
local ui = require("ui")

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Configure Storage")
print()
term.setTextColour(colours.white)

print("Connecting...")
local ok, err = network.init()
if not ok then
    term.setTextColour(colours.red)
    print(err)
    return
end
term.setTextColour(colours.lime)
print("Stock Ticker OK")
print("Wireless modem OK")

local mon = peripheral.find("monitor")
if mon then
    term.setTextColour(colours.lime)
    print("Monitor OK")
else
    term.setTextColour(colours.grey)
    print("No monitor (optional)")
end

term.setTextColour(colours.grey)
print("Waiting for sensors...")
os.sleep(1)

local data = config.load()

-- Try to load display module
local hasDisplay, display = pcall(require, "display")

parallel.waitForAny(
    function()
        ui.run(data)
        router.stop()
    end,
    function()
        router.run(data)
    end,
    function()
        network.listenForSensors()
    end,
    function()
        -- Monitor display loop (only if monitor attached)
        while true do
            if not mon then mon = peripheral.find("monitor") end
            if mon and hasDisplay then
                pcall(display.controller, mon, data, network)
            end
            os.sleep(3)
        end
    end
)

term.clear()
term.setCursorPos(1, 1)
print("Stopped.")
