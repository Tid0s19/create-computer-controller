-- router.lua — Smart routing via sensor-to-sensor transfers
-- No more Stock Ticker for moving items. The controller finds
-- which sensor has the items needed and commands it to ship
-- them via its Packager.

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
                            -- Find sources that have this item
                            local sources = network.findItemSources(rule.item, dest.address)
                            local remaining = shortfall
                            for _, source in ipairs(sources) do
                                if remaining <= 0 then break end
                                local toSend = math.min(remaining, source.count)
                                network.commandSend(
                                    source.address,
                                    dest.address,
                                    rule.item,
                                    toSend
                                )
                                remaining = remaining - toSend
                            end
                        end

                    elseif rule.type == "tag" then
                        if sensor.freeSlots > 0 then
                            -- Find sources with tagged items
                            local sources = network.findTagSources(rule.tag, dest.address)
                            local budget = sensor.freeSlots * 64
                            for _, source in ipairs(sources) do
                                if budget <= 0 then break end
                                local toSend = math.min(budget, source.count)
                                network.commandSend(
                                    source.address,
                                    dest.address,
                                    source.item,
                                    toSend
                                )
                                budget = budget - toSend
                            end
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
