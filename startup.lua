-- startup.lua — Configure Storage Server
-- Place computer adjacent to Stock Ticker + wireless modem
-- Optional: attach a monitor to display all managed storages
-- Pocket computers can connect wirelessly to manage config

local config = require("config")
local network = require("network")
local router = require("router")
local ui = require("ui")

local CHANNEL_POCKET = 4202

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

-- Open pocket server channel
local modem = network.getModem()
if modem then
    modem.open(CHANNEL_POCKET)
    term.setTextColour(colours.lime)
    print("Pocket server OK")
end

term.setTextColour(colours.grey)
print("Waiting for sensors...")
os.sleep(1)

local data = config.load()

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
        -- Monitor display loop
        while true do
            if not mon then mon = peripheral.find("monitor") end
            if mon and hasDisplay then
                pcall(display.controller, mon, data, network)
            end
            os.sleep(3)
        end
    end,
    function()
        -- Pocket server: handle remote config requests
        if not modem then return end
        while true do
            local ev, side, ch, reply, msg = os.pullEvent("modem_message")
            if ch == CHANNEL_POCKET and type(msg) == "table" then
                if msg.type == "ping" then
                    modem.transmit(reply, CHANNEL_POCKET, {type = "pong"})

                elseif msg.type == "config_request" then
                    modem.transmit(reply, CHANNEL_POCKET, {
                        type = "config_data",
                        data = data,
                    })

                elseif msg.type == "config_save" and msg.data then
                    data.destinations = msg.data.destinations or {}
                    data.groups = msg.data.groups or {}
                    config.save(data)

                elseif msg.type == "get_sensors" then
                    local sensors = {}
                    for _, addr in ipairs(network.getSensorAddresses()) do
                        sensors[addr] = network.getSensor(addr)
                    end
                    modem.transmit(reply, CHANNEL_POCKET, {
                        type = "sensors_data",
                        sensors = sensors,
                    })

                elseif msg.type == "get_stock" then
                    modem.transmit(reply, CHANNEL_POCKET, {
                        type = "stock_data",
                        stock = network.getStock(),
                    })
                end
            end
        end
    end
)

term.clear()
term.setCursorPos(1, 1)
print("Stopped.")
