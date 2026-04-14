-- router.lua — Routing via Stock Ticker requestFiltered
-- The controller checks destination sensors for shortfalls,
-- then uses the Stock Ticker to request items from the network.
-- Factory-port items are excluded from stock calculations.
-- Container groups are treated as one logical unit with consolidation.

local network = require("network")

local router = {}
local running = false

function router.stop()
    running = false
end

function router.run(data)
    running = true
    local lastRun = {}
    local lastConsolidate = {}

    while running do
        for i, dest in ipairs(data.destinations) do
            local now = os.clock()

            -- Normal rule processing every 10 seconds
            if not lastRun[i] or now - lastRun[i] >= 10 then
                lastRun[i] = now
                local sensor = network.getGroupSensor(dest.addresses)
                if not sensor then goto continue end

                local targetAddr = network.getBestAddress(dest.addresses)

                for _, rule in ipairs(dest.rules) do
                    if not rule.enabled then goto nextRule end

                    if rule.type == "item" then
                        local have = network.getGroupItemCount(dest.addresses, rule.item)
                        local shortfall = rule.count - have
                        if shortfall > 0 then
                            network.requestItems(targetAddr, rule.item, shortfall)
                        end

                    elseif rule.type == "tag" then
                        if sensor.freeSlots > 0 then
                            local budget = sensor.freeSlots * 64
                            local tagged = network.getAdjustedTaggedStock(rule.tag)
                            for _, item in ipairs(tagged) do
                                if budget <= 0 then break end
                                local atDest = network.getGroupItemCount(dest.addresses, item.name)
                                local toRequest = math.min(item.count - atDest, budget)
                                if toRequest > 0 then
                                    network.requestItems(targetAddr, item.name, toRequest)
                                    budget = budget - toRequest
                                end
                            end
                        end

                    elseif rule.type == "group" then
                        local group = nil
                        for _, g in ipairs(data.groups or {}) do
                            if g.name == rule.groupName then
                                group = g
                                break
                            end
                        end
                        if group and sensor.freeSlots > 0 then
                            local budget = sensor.freeSlots * 64
                            local stockMap = network.getAdjustedStockMap()
                            for _, groupItem in ipairs(group.items) do
                                if budget <= 0 then break end
                                local inStock = stockMap[groupItem.name] or 0
                                local atDest = network.getGroupItemCount(dest.addresses, groupItem.name)
                                local toRequest = math.min(inStock - atDest, budget)
                                if toRequest > 0 then
                                    network.requestItems(targetAddr, groupItem.name, toRequest)
                                    budget = budget - toRequest
                                end
                            end
                        end
                    end

                    ::nextRule::
                end
                ::continue::
            end

            -- Consolidation for multi-port groups every 60 seconds
            if #dest.addresses > 1 then
                if not lastConsolidate[i] or now - lastConsolidate[i] >= 60 then
                    lastConsolidate[i] = now
                    local requests = 0

                    -- Build map: itemName -> {addr = count, ...}
                    local itemMap = {}
                    for _, addr in ipairs(dest.addresses) do
                        local sensorData = network.getSensor(addr)
                        if sensorData then
                            for name, count in pairs(sensorData.items) do
                                if not itemMap[name] then itemMap[name] = {} end
                                itemMap[name][addr] = count
                            end
                        end
                    end

                    -- Find fragmented items and consolidate
                    for itemName, addrCounts in pairs(itemMap) do
                        if requests >= 3 then break end

                        -- Count how many addresses hold this item
                        local holders = 0
                        local homeAddr, homeCount = nil, 0
                        for addr, count in pairs(addrCounts) do
                            holders = holders + 1
                            if count > homeCount then
                                homeAddr = addr
                                homeCount = count
                            end
                        end

                        -- Only consolidate if item is in multiple containers
                        if holders > 1 and homeAddr then
                            local homeSensor = network.getSensor(homeAddr)
                            if homeSensor and homeSensor.freeSlots > 0 then
                                local fragments = 0
                                for addr, count in pairs(addrCounts) do
                                    if addr ~= homeAddr then
                                        fragments = fragments + count
                                    end
                                end
                                local canFit = homeSensor.freeSlots * 64
                                local toMove = math.min(fragments, canFit)
                                if toMove > 0 then
                                    network.requestItems(homeAddr, itemName, toMove)
                                    requests = requests + 1
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
