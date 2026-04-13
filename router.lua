-- router.lua — Routing via Stock Ticker requestFiltered
-- The controller checks destination sensors for shortfalls,
-- then uses the Stock Ticker to request items from the network.

local network = require("network")

local router = {}
local running = false

function router.stop()
    running = false
end

function router.run(data)
    running = true
    local lastRun = {}

    while running do
        for i, dest in ipairs(data.destinations) do
            local now = os.clock()
            if not lastRun[i] or now - lastRun[i] >= 10 then
                lastRun[i] = now
                local sensor = network.getSensor(dest.address)
                if not sensor then goto continue end

                for _, rule in ipairs(dest.rules) do
                    if not rule.enabled then goto nextRule end

                    if rule.type == "item" then
                        local have = network.getItemCountAt(dest.address, rule.item)
                        local shortfall = rule.count - have
                        if shortfall > 0 then
                            network.requestItems(dest.address, rule.item, shortfall)
                        end

                    elseif rule.type == "tag" then
                        if sensor.freeSlots > 0 then
                            local budget = sensor.freeSlots * 64
                            network.requestTagged(dest.address, rule.tag, budget)
                        end
                    end

                    ::nextRule::
                end
                ::continue::
            end
        end

        os.sleep(1)
    end
end

return router
