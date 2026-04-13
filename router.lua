-- router.lua — Background routing engine
-- Periodically processes enabled routes, sending matching items to destinations

local config = require("config")
local network = require("network")

local router = {}

local running = false
local status = { routes = {} }

function router.getStatus()
    return status
end

function router.stop()
    running = false
end

--- Run the routing loop. This blocks — run it inside parallel.waitForAny.
-- @param data table — config data (routes table, shared with UI)
function router.run(data)
    running = true

    -- Track per-route timers
    local timers = {}

    while running do
        status.routes = {}

        for i, route in ipairs(data.routes) do
            local rs = {
                name = route.name,
                address = route.address,
                enabled = route.enabled,
                lastResult = nil,
                lastError = nil,
            }

            if route.enabled then
                -- Check if enough time has elapsed since last run
                local now = os.clock()
                local lastRun = timers[i] or 0
                local interval = route.interval or 10

                if now - lastRun >= interval then
                    local count, err = network.executeRoute(route)
                    timers[i] = now

                    if count >= 0 then
                        rs.lastResult = count .. " items sent"
                    else
                        rs.lastResult = "error"
                        rs.lastError = err
                    end
                else
                    local remaining = math.ceil(interval - (now - lastRun))
                    rs.lastResult = "next in " .. remaining .. "s"
                end
            end

            table.insert(status.routes, rs)
        end

        -- Reload config in case UI changed it
        -- (data table is shared by reference, so changes from UI are live)

        os.sleep(1)  -- tick every second to keep timers responsive
    end
end

return router
