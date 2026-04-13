-- startup.lua — Create Controller
-- Place computer next to a Stock Ticker

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

print("Connecting to Stock Ticker...")
local ok, err = network.init()
if not ok then
    term.setTextColour(colours.red)
    print(err)
    return
end
term.setTextColour(colours.lime)
print("Connected!")
os.sleep(0.3)

local data = config.load()

parallel.waitForAny(
    function()
        ui.run(data)
        router.stop()
    end,
    function()
        router.run(data)
    end
)

term.clear()
term.setCursorPos(1, 1)
print("Stopped.")
