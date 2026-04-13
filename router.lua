-- router.lua — Background loop that processes rules

local network = require("network")

local router = {}
local running = false

function router.stop()
    running = false
end

function router.run(data)
    running = true

    local lastRun = {}  -- per-destination cooldown

    while running do
        for i, dest in ipairs(data.destinations) do
            local now = os.clock()
            if not lastRun[i] or now - lastRun[i] >= 10 then
                lastRun[i] = now

                for _, rule in ipairs(dest.rules) do
                    if rule.enabled then
                        if rule.type == "item" then
                            network.sendItem(dest.address, rule.item, rule.count)
                        elseif rule.type == "tag" then
                            network.sendByTag(dest.address, rule.tag)
                        end
                    end
                end
            end
        end

        os.sleep(1)
    end
end

return router
