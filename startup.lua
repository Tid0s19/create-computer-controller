-- startup.lua — Create Controller
-- Place computer with wireless modem (Stock Ticker optional, for tag browsing)

local config = require("config")
local network = require("network")
local router = require("router")
local ui = require("ui")

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Create Controller")
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
print("Wireless modem OK")
if network.hasTicker() then
    print("Stock Ticker OK (tag browsing)")
else
    term.setTextColour(colours.yellow)
    print("No Stock Ticker (tag browsing disabled)")
end
term.setTextColour(colours.grey)
print("Waiting for sensors...")
os.sleep(1)

local data = config.load()

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
    end
)

term.clear()
term.setCursorPos(1, 1)
print("Stopped.")
