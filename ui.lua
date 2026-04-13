-- ui.lua — Terminal UI for Create Controller
-- Provides a multi-page interface for managing routing rules

local config = require("config")
local network = require("network")

local ui = {}

-- Colour shortcuts (fall back to white/black on monochrome)
local col = {
    bg      = colours.black,
    fg      = colours.white,
    header  = colours.yellow,
    accent  = colours.cyan,
    success = colours.lime,
    error   = colours.red,
    dim     = colours.grey,
    selected = colours.lightBlue,
    enabled = colours.lime,
    disabled = colours.red,
}

local W, H = term.getSize()

----------------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------------

local function clear()
    term.setBackgroundColour(col.bg)
    term.setTextColour(col.fg)
    term.clear()
end

local function writeAt(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColour(fg) end
    if bg then term.setBackgroundColour(bg) end
    term.write(text)
end

local function hline(y, char)
    writeAt(1, y, string.rep(char or "\x8c", W), col.dim)
end

local function drawHeader(title)
    writeAt(1, 1, string.rep(" ", W), col.header, colours.grey)
    local t = " Create Controller "
    writeAt(math.floor((W - #t) / 2) + 1, 1, t, col.header, colours.grey)
    writeAt(1, 2, string.rep(" ", W), col.fg, col.bg)
    if title then
        writeAt(2, 2, title, col.accent, col.bg)
    end
    hline(3)
    term.setBackgroundColour(col.bg)
end

local function drawFooter(hints)
    hline(H - 1)
    writeAt(1, H, string.rep(" ", W), col.dim, col.bg)
    writeAt(2, H, hints or "", col.dim, col.bg)
end

local function truncate(str, maxLen)
    if #str > maxLen then
        return str:sub(1, maxLen - 2) .. ".."
    end
    return str
end

local function centerText(y, text, fg)
    local x = math.floor((W - #text) / 2) + 1
    writeAt(x, y, text, fg or col.fg)
end

----------------------------------------------------------------------
-- Input helpers
----------------------------------------------------------------------

local function readInput(prompt, y, prefill)
    writeAt(2, y, prompt, col.accent)
    term.setCursorPos(2 + #prompt, y)
    term.setTextColour(col.fg)
    term.setCursorBlink(true)
    -- CC read() with optional replace char and history; prefill via write
    if prefill then
        term.write(prefill)
    end
    local input = read(nil, nil, nil, prefill)
    term.setCursorBlink(false)
    return input
end

local function confirm(msg, y)
    writeAt(2, y, msg .. " (y/n) ", col.accent)
    while true do
        local _, key = os.pullEvent("key")
        if key == keys.y then return true end
        if key == keys.n or key == keys.q then return false end
    end
end

----------------------------------------------------------------------
-- Generic scrollable list selector
----------------------------------------------------------------------

local function listSelect(title, items, opts)
    opts = opts or {}
    local selected = opts.selected or 1
    local scroll = 0
    local listH = H - 5  -- rows available for list items
    local footerHints = opts.footer or "[Up/Down] Navigate  [Enter] Select  [Q] Back"

    while true do
        clear()
        drawHeader(title)
        drawFooter(footerHints)

        if #items == 0 then
            centerText(math.floor(H / 2), opts.emptyMsg or "No items", col.dim)
        else
            -- Adjust scroll so selected is visible
            if selected - scroll > listH then
                scroll = selected - listH
            end
            if selected - scroll < 1 then
                scroll = selected - 1
            end

            for i = 1, listH do
                local idx = i + scroll
                if idx > #items then break end
                local item = items[idx]
                local y = i + 3
                local label = type(item) == "table" and item.label or tostring(item)
                label = truncate(label, W - 4)

                if idx == selected then
                    writeAt(1, y, " " .. string.rep(" ", W - 1), col.fg, colours.grey)
                    writeAt(2, y, "> ", col.selected, colours.grey)
                    writeAt(4, y, label, col.fg, colours.grey)
                    if type(item) == "table" and item.right then
                        local r = item.right
                        writeAt(W - #r, y, r, item.rightCol or col.dim, colours.grey)
                    end
                else
                    writeAt(2, y, "  ", col.dim)
                    writeAt(4, y, label, col.fg)
                    if type(item) == "table" and item.right then
                        local r = item.right
                        writeAt(W - #r, y, r, item.rightCol or col.dim)
                    end
                end
            end

            -- Scroll indicator
            if #items > listH then
                local pct = math.floor((selected / #items) * 100)
                writeAt(W - 4, 3, string.format("%3d%%", pct), col.dim)
            end
        end

        local event, key = os.pullEvent("key")
        if key == keys.up then
            selected = selected > 1 and selected - 1 or #items
        elseif key == keys.down then
            selected = selected < #items and selected + 1 or 1
        elseif key == keys.pageUp then
            selected = math.max(1, selected - listH)
        elseif key == keys.pageDown then
            selected = math.min(#items, selected + listH)
        elseif key == keys.home then
            selected = 1
        elseif key == keys["end"] then
            selected = #items
        elseif key == keys.enter then
            if #items > 0 then
                return selected, items[selected]
            end
        elseif key == keys.q then
            return nil
        elseif opts.onKey then
            local result = opts.onKey(key, selected, items)
            if result == "refresh" then
                -- items may have changed, clamp selection
                selected = math.min(selected, math.max(1, #items))
            elseif result == "back" then
                return nil
            end
        end
    end
end

----------------------------------------------------------------------
-- Page: Route List (main menu)
----------------------------------------------------------------------

local data  -- config data, loaded at start

local function routeListItems()
    local items = {}
    for i, route in ipairs(data.routes) do
        local status = route.enabled and "ON" or "OFF"
        local statusCol = route.enabled and col.enabled or col.disabled
        table.insert(items, {
            label = route.name .. " -> " .. route.address,
            right = status,
            rightCol = statusCol,
            route = route,
            index = i,
        })
    end
    return items
end

----------------------------------------------------------------------
-- Page: Filter/Exclusion editor (shared)
----------------------------------------------------------------------

local function editFilterList(route, category, filterType, label)
    -- category = "filters" or "exclusions"
    -- filterType = "items", "tags", or "globs"
    local function getItems()
        local list = route[category][filterType]
        local items = {}
        for i, v in ipairs(list) do
            table.insert(items, { label = v, index = i })
        end
        return items
    end

    local footer = "[Enter] Remove  [A] Add  [B] Browse network  [Q] Back"

    listSelect(label, getItems(), {
        emptyMsg = "No " .. filterType .. " defined. Press [A] to add.",
        footer = footer,
        onKey = function(key, sel, items)
            if key == keys.a then
                -- Add new entry
                clear()
                drawHeader("Add " .. filterType:sub(1, -2))
                local value = readInput("Value: ", 5)
                if value and value ~= "" then
                    if category == "filters" then
                        config.addFilter(route, filterType, value)
                    else
                        config.addExclusion(route, filterType, value)
                    end
                    config.save(data)
                end
                -- Rebuild list
                local newItems = getItems()
                for k in pairs(items) do items[k] = nil end
                for k, v in ipairs(newItems) do items[k] = v end
                return "refresh"

            elseif key == keys.b then
                -- Browse network items/tags
                clear()
                drawHeader("Scanning network...")
                centerText(math.floor(H / 2), "Please wait...", col.dim)

                local browseItems = {}
                if filterType == "tags" then
                    local tags = network.getAllTags()
                    for _, t in ipairs(tags) do
                        table.insert(browseItems, t)
                    end
                else
                    local names = network.getAllItems()
                    for _, n in ipairs(names) do
                        table.insert(browseItems, n)
                    end
                end

                if #browseItems == 0 then
                    clear()
                    drawHeader("Browse")
                    centerText(math.floor(H / 2), "Nothing found on network", col.error)
                    os.sleep(1.5)
                else
                    local _, picked = listSelect(
                        "Select " .. filterType:sub(1, -2) .. " from network",
                        browseItems,
                        { footer = "[Enter] Add  [Q] Cancel" }
                    )
                    if picked then
                        local val = type(picked) == "table" and picked.label or picked
                        if category == "filters" then
                            config.addFilter(route, filterType, val)
                        else
                            config.addExclusion(route, filterType, val)
                        end
                        config.save(data)
                    end
                end

                local newItems = getItems()
                for k in pairs(items) do items[k] = nil end
                for k, v in ipairs(newItems) do items[k] = v end
                return "refresh"

            elseif key == keys.enter or key == keys.delete or key == keys.x then
                -- Remove selected
                if sel and items[sel] then
                    if category == "filters" then
                        config.removeFilter(route, filterType, items[sel].index)
                    else
                        config.removeExclusion(route, filterType, items[sel].index)
                    end
                    config.save(data)
                    local newItems = getItems()
                    for k in pairs(items) do items[k] = nil end
                    for k, v in ipairs(newItems) do items[k] = v end
                    return "refresh"
                end
            end
        end,
    })
end

----------------------------------------------------------------------
-- Page: Route editor
----------------------------------------------------------------------

local function editRoute(route)
    while true do
        local statusStr = route.enabled and "Enabled" or "Disabled"
        local statusCol = route.enabled and col.enabled or col.disabled
        local items = {
            { label = "Name: " .. route.name, action = "name" },
            { label = "Address: " .. route.address, action = "address" },
            { label = "Status: " .. statusStr, right = "[Toggle]", rightCol = statusCol, action = "toggle" },
            { label = "Interval: " .. route.interval .. "s", action = "interval" },
            { label = "Stacks per item: " .. route.stackCount, action = "stacks" },
            { label = "" },
            { label = "--- Include Filters ---" },
            { label = "  Items (" .. #route.filters.items .. ")", action = "filter_items" },
            { label = "  Tags (" .. #route.filters.tags .. ")", action = "filter_tags" },
            { label = "  Globs (" .. #route.filters.globs .. ")", action = "filter_globs" },
            { label = "" },
            { label = "--- Exclusions ---" },
            { label = "  Items (" .. #route.exclusions.items .. ")", action = "excl_items" },
            { label = "  Tags (" .. #route.exclusions.tags .. ")", action = "excl_tags" },
            { label = "  Globs (" .. #route.exclusions.globs .. ")", action = "excl_globs" },
            { label = "" },
            { label = "[ Test Route ]", action = "test" },
            { label = "[ Delete Route ]", action = "delete" },
        }

        local footer = "[Enter] Edit  [Q] Back"
        local idx = listSelect("Edit Route: " .. route.name, items, { footer = footer })

        if not idx then return end

        local action = items[idx].action
        if action == "name" then
            clear()
            drawHeader("Rename Route")
            local val = readInput("Name: ", 5, route.name)
            if val and val ~= "" then
                route.name = val
                config.save(data)
            end

        elseif action == "address" then
            clear()
            drawHeader("Set Address")
            writeAt(2, 4, "Enter the frogport address (must match exactly)", col.dim)
            local val = readInput("Address: ", 6, route.address)
            if val and val ~= "" then
                route.address = val
                config.save(data)
            end

        elseif action == "toggle" then
            route.enabled = not route.enabled
            config.save(data)

        elseif action == "interval" then
            clear()
            drawHeader("Set Interval")
            local val = readInput("Seconds: ", 5, tostring(route.interval))
            val = tonumber(val)
            if val and val >= 1 then
                route.interval = math.floor(val)
                config.save(data)
            end

        elseif action == "stacks" then
            clear()
            drawHeader("Stacks Per Item")
            local val = readInput("Stacks (1-64): ", 5, tostring(route.stackCount))
            val = tonumber(val)
            if val and val >= 1 and val <= 64 then
                route.stackCount = math.floor(val)
                config.save(data)
            end

        elseif action == "filter_items" then
            editFilterList(route, "filters", "items", "Include Items")
        elseif action == "filter_tags" then
            editFilterList(route, "filters", "tags", "Include Tags")
        elseif action == "filter_globs" then
            editFilterList(route, "filters", "globs", "Include Globs")

        elseif action == "excl_items" then
            editFilterList(route, "exclusions", "items", "Exclude Items")
        elseif action == "excl_tags" then
            editFilterList(route, "exclusions", "tags", "Exclude Tags")
        elseif action == "excl_globs" then
            editFilterList(route, "exclusions", "globs", "Exclude Globs")

        elseif action == "test" then
            clear()
            drawHeader("Testing Route: " .. route.name)
            centerText(math.floor(H / 2) - 1, "Scanning network...", col.dim)

            local stock = network.getStock(true)
            local matching = 0
            local excluded = 0
            local matchList = {}

            for _, item in ipairs(stock) do
                if network.matchesFilters(item, route.filters) then
                    if network.isExcluded(item, route.exclusions) then
                        excluded = excluded + 1
                    else
                        matching = matching + 1
                        if #matchList < 10 then
                            table.insert(matchList, item.displayName or item.name)
                        end
                    end
                end
            end

            clear()
            drawHeader("Test Results: " .. route.name)
            writeAt(2, 4, "Address: " .. route.address, col.accent)
            writeAt(2, 5, "Matching items: " .. matching, col.success)
            writeAt(2, 6, "Excluded items: " .. excluded, col.error)
            writeAt(2, 8, "Sample matches:", col.fg)
            for i, name in ipairs(matchList) do
                writeAt(4, 8 + i, truncate(name, W - 6), col.dim)
            end
            if matching > #matchList then
                writeAt(4, 9 + #matchList, "... and " .. (matching - #matchList) .. " more", col.dim)
            end
            drawFooter("Press any key to continue")
            os.pullEvent("key")

        elseif action == "delete" then
            clear()
            drawHeader("Delete Route")
            if confirm("Delete '" .. route.name .. "'?", 5) then
                for i, r in ipairs(data.routes) do
                    if r == route then
                        table.remove(data.routes, i)
                        break
                    end
                end
                config.save(data)
                return
            end
        end
    end
end

----------------------------------------------------------------------
-- Page: Status dashboard
----------------------------------------------------------------------

local routerStatus = {}  -- shared state updated by router

function ui.setRouterStatus(status)
    routerStatus = status
end

local function showStatus()
    clear()
    drawHeader("Router Status")
    drawFooter("Press any key to go back")

    if not routerStatus or not routerStatus.routes then
        centerText(math.floor(H / 2), "Router not running", col.dim)
        os.pullEvent("key")
        return
    end

    local y = 4
    for _, rs in ipairs(routerStatus.routes) do
        if y > H - 3 then break end
        local statusStr
        if not rs.enabled then
            statusStr = "DISABLED"
            writeAt(2, y, truncate(rs.name, W - 20), col.dim)
            writeAt(W - #statusStr - 1, y, statusStr, col.dim)
        else
            statusStr = rs.lastResult or "pending"
            local c = rs.lastError and col.error or col.success
            writeAt(2, y, truncate(rs.name, W - 20), col.fg)
            writeAt(W - #statusStr - 1, y, statusStr, c)
        end
        y = y + 1
    end

    os.pullEvent("key")
end

----------------------------------------------------------------------
-- Main menu
----------------------------------------------------------------------

function ui.run(configData)
    data = configData

    while true do
        W, H = term.getSize()
        local items = routeListItems()

        -- Add action items at the bottom
        table.insert(items, { label = "" })
        table.insert(items, { label = "[+] New Route", action = "new" })
        table.insert(items, { label = "[S] Router Status", action = "status" })

        local footer = "[Enter] Edit  [N] New  [S] Status  [E] Toggle  [Q] Quit"
        local idx, item = listSelect("Routes", items, {
            footer = footer,
            onKey = function(key, sel, items)
                if key == keys.n then
                    -- Quick-add new route
                    clear()
                    drawHeader("New Route")
                    local name = readInput("Route name: ", 5)
                    if name and name ~= "" then
                        clear()
                        drawHeader("New Route")
                        writeAt(2, 4, "Must match the frogport's address exactly", col.dim)
                        local addr = readInput("Frogport address: ", 6)
                        if addr and addr ~= "" then
                            local route = config.newRoute(name, addr)
                            table.insert(data.routes, route)
                            config.save(data)
                            -- Rebuild list
                            local newItems = routeListItems()
                            table.insert(newItems, { label = "" })
                            table.insert(newItems, { label = "[+] New Route", action = "new" })
                            table.insert(newItems, { label = "[S] Router Status", action = "status" })
                            for k in pairs(items) do items[k] = nil end
                            for k, v in ipairs(newItems) do items[k] = v end
                        end
                    end
                    return "refresh"

                elseif key == keys.e then
                    -- Toggle enabled on selected route
                    if sel and items[sel] and items[sel].route then
                        items[sel].route.enabled = not items[sel].route.enabled
                        config.save(data)
                        local newItems = routeListItems()
                        table.insert(newItems, { label = "" })
                        table.insert(newItems, { label = "[+] New Route", action = "new" })
                        table.insert(newItems, { label = "[S] Router Status", action = "status" })
                        for k in pairs(items) do items[k] = nil end
                        for k, v in ipairs(newItems) do items[k] = v end
                        return "refresh"
                    end

                elseif key == keys.s then
                    showStatus()
                    return "refresh"
                end
            end,
        })

        if not idx then
            -- Q pressed — confirm quit
            clear()
            drawHeader("Quit")
            if confirm("Stop controller and exit?", 5) then
                return
            end
        elseif item and item.action == "new" then
            clear()
            drawHeader("New Route")
            local name = readInput("Route name: ", 5)
            if name and name ~= "" then
                clear()
                drawHeader("New Route")
                writeAt(2, 4, "Must match the frogport's address exactly", col.dim)
                local addr = readInput("Frogport address: ", 6)
                if addr and addr ~= "" then
                    local route = config.newRoute(name, addr)
                    table.insert(data.routes, route)
                    config.save(data)
                end
            end
        elseif item and item.action == "status" then
            showStatus()
        elseif item and item.route then
            editRoute(item.route)
        end
    end
end

return ui
