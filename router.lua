-- router.lua — Smart routing with sensor awareness
-- Checks inventory across ALL sensors before moving items.
-- Only requests items when they exist at OTHER locations,
-- preventing the destination from recycling its own stock.

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

                for _, rule in ipairs(dest.rules) do
                    if rule.enabled and sensor then
                        if rule.type == "item" then
                            local have = network.getItemCountAt(dest.address, rule.item)
                            local shortfall = rule.count - have
                            if shortfall > 0 then
                                -- Check if the item exists at OTHER locations
                                local elsewhere = network.getItemCountElsewhere(dest.address, rule.item)
                                if elsewhere > 0 then
                                    -- Only request what's actually available elsewhere
                                    local toSend = math.min(shortfall, elsewhere)
                                    network.sendItem(dest.address, rule.item, toSend)
                                end
                                -- If elsewhere == 0, don't request — would just
                                -- recycle items already at the destination
                            end

                        elseif rule.type == "tag" then
                            if sensor.freeSlots > 0 then
                                -- Check if tagged items exist at other locations
                                local elsewhere = network.getTagCountElsewhere(dest.address, rule.tag)
                                if elsewhere > 0 then
                                    local maxSend = math.min(elsewhere, sensor.freeSlots * 64)
                                    network.sendByTag(dest.address, rule.tag, maxSend)
                                end
                            end
                        end
                    end
                end
            end
        end

        os.sleep(1)
    end
end

return router
