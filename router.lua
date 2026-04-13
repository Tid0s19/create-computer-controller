-- router.lua — Smart routing with sensor awareness

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
                            -- Only send the shortfall
                            local have = network.getItemCountAt(dest.address, rule.item)
                            local need = rule.count - have
                            if need > 0 then
                                network.sendItem(dest.address, rule.item, need)
                            end

                        elseif rule.type == "tag" then
                            -- Only send if destination has free slots
                            if sensor.freeSlots > 0 then
                                -- Limit to avoid flooding
                                local maxSend = sensor.freeSlots * 64
                                network.sendByTag(dest.address, rule.tag, maxSend)
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
