-- ui.lua — Terminal UI for Configure Storage

local config = require("config")
local network = require("network")

local ui = {}
local W, H

local C = {
    title   = colours.yellow,
    accent  = colours.cyan,
    ok      = colours.lime,
    err     = colours.red,
    dim     = colours.grey,
    sel     = colours.lightBlue,
    on      = colours.lime,
    off     = colours.red,
}

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------

local function clear()
    term.setBackgroundColour(colours.black)
    term.setTextColour(colours.white)
    term.clear()
end

local function at(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColour(fg) end
    if bg then term.setBackgroundColour(bg) end
    term.write(text)
    if bg then term.setBackgroundColour(colours.black) end
end

local function bar(y, text, fg)
    at(1, y, string.rep(" ", W), nil, colours.grey)
    at(2, y, text, fg or C.title, colours.grey)
end

local function footer(text)
    at(1, H, string.rep(" ", W), C.dim, colours.black)
    at(2, H, text, C.dim)
end

local function trunc(s, n)
    return #s > n and s:sub(1, n - 2) .. ".." or s
end

local function input(prompt, y, prefill)
    at(2, y, prompt, C.accent)
    term.setCursorPos(2 + #prompt, y)
    term.setTextColour(colours.white)
    term.setCursorBlink(true)
    local r = read(nil, nil, nil, prefill)
    term.setCursorBlink(false)
    return r
end

----------------------------------------------------------------------
-- Usage color: green (empty) → red (full)
----------------------------------------------------------------------

local function usageColor(pct)
    if pct < 25 then return colours.lime
    elseif pct < 50 then return colours.yellow
    elseif pct < 75 then return colours.orange
    else return colours.red end
end

local function usageText(sensor)
    if not sensor or sensor.totalSlots == 0 then return "?", C.dim end
    local pct = math.floor(sensor.usedSlots / sensor.totalSlots * 100)
    return pct .. "%", usageColor(pct)
end

----------------------------------------------------------------------
-- Generic list picker (with optional search)
----------------------------------------------------------------------

local function pick(title, items, hints, onKey, opts)
    opts = opts or {}
    local searchable = opts.searchable or false
    local sel, scroll = 1, 0
    local search = ""

    -- Build filtered index list
    local function buildVisible()
        local vis = {}
        if search == "" then
            for i = 1, #items do vis[#vis + 1] = i end
        else
            local q = search:lower()
            for i, item in ipairs(items) do
                if type(item) == "table" and item.label == "" then
                    -- skip spacers when filtering
                else
                    local label = type(item) == "table" and item.label or tostring(item)
                    local match = label:lower():find(q, 1, true)
                    if not match and type(item) == "table" and item.name then
                        match = item.name:lower():find(q, 1, true)
                    end
                    if match then vis[#vis + 1] = i end
                end
            end
        end
        return vis
    end

    local visible = buildVisible()

    -- Skip initial spacers
    while sel <= #visible do
        local it = items[visible[sel]]
        if type(it) == "table" and it.label == "" then
            sel = sel + 1
        else
            break
        end
    end

    while true do
        W, H = term.getSize()
        local searchRow = searchable and 1 or 0
        local rows = H - 4 - searchRow
        clear()
        bar(1, " " .. title)

        if searchable then
            at(2, 3, "Search: ", C.accent)
            at(10, 3, search, colours.white)
            at(10 + #search, 3, "_", C.dim)
        end

        local baseY = 3 + searchRow
        local hintText
        if searchable and search ~= "" then
            hintText = "Type:Filter  Q:Clear  Enter:Select"
        elseif searchable then
            hintText = hints or "Type:Search  Enter:Select  Q:Back"
        else
            hintText = hints or "Up/Down:Move  Enter:Select  Q:Back"
        end
        footer(hintText)

        if #visible == 0 then
            if search ~= "" then
                at(2, baseY + 1, "No matches", C.dim)
            else
                at(2, math.floor(H / 2), "Nothing here yet", C.dim)
            end
        else
            if sel - scroll > rows then scroll = sel - rows end
            if sel - scroll < 1 then scroll = sel - 1 end

            for i = 1, rows do
                local vidx = i + scroll
                if vidx > #visible then break end
                local origIdx = visible[vidx]
                local it = items[origIdx]
                local y = baseY + i - 1
                local label = type(it) == "table" and it.label or tostring(it)
                local right = type(it) == "table" and it.right or nil

                if vidx == sel then
                    at(1, y, string.rep(" ", W), nil, colours.grey)
                    at(2, y, "> " .. trunc(label, W - 6), C.sel, colours.grey)
                    if right then
                        local rc = (type(it) == "table" and it.rcol) or C.dim
                        -- Fix: grey text invisible on grey highlight
                        if rc == colours.grey then rc = colours.white end
                        at(W - #right, y, right, rc, colours.grey)
                    end
                else
                    at(4, y, trunc(label, W - 6), colours.white)
                    if right then
                        at(W - #right, y, right, (type(it) == "table" and it.rcol) or C.dim)
                    end
                end
            end
        end

        local ev = {os.pullEvent()}

        if ev[1] == "key" then
            local key = ev[2]
            if key == keys.up then
                sel = sel > 1 and sel - 1 or #visible
                while sel > 0 and sel <= #visible do
                    local it = items[visible[sel]]
                    if type(it) == "table" and it.label == "" then
                        sel = sel > 1 and sel - 1 or #visible
                    else
                        break
                    end
                end
            elseif key == keys.down then
                sel = sel < #visible and sel + 1 or 1
                while sel <= #visible do
                    local it = items[visible[sel]]
                    if type(it) == "table" and it.label == "" then
                        sel = sel < #visible and sel + 1 or 1
                    else
                        break
                    end
                end
            elseif key == keys.enter and #visible > 0 then
                local it = items[visible[sel]]
                if not (type(it) == "table" and it.label == "") then
                    return visible[sel]
                end
            elseif key == keys.backspace and searchable then
                if search ~= "" then
                    search = search:sub(1, -2)
                    visible = buildVisible()
                    sel = 1; scroll = 0
                end
            elseif key == keys.q then
                if searchable and search ~= "" then
                    search = ""
                    visible = buildVisible()
                    sel = 1; scroll = 0
                else
                    return nil
                end
            elseif not searchable and onKey then
                local result = onKey(key, #visible > 0 and visible[sel] or 0)
                if result == "refresh" then
                    visible = buildVisible()
                    sel = math.min(sel, math.max(1, #visible))
                end
            end
        elseif ev[1] == "char" and searchable then
            search = search .. ev[2]
            visible = buildVisible()
            sel = 1; scroll = 0
        elseif ev[1] == "key" and not searchable and onKey then
            -- already handled above
        end
    end
end

----------------------------------------------------------------------
-- Browse network items/tags (searchable)
----------------------------------------------------------------------

local function browseItems()
    clear()
    W, H = term.getSize()
    bar(1, " Scanning network...")
    at(2, 3, "Please wait...", C.dim)

    local items = network.getAllItems()
    if #items == 0 then
        at(2, 5, "No items found on network", C.err)
        os.sleep(1.5)
        return nil
    end

    local list = {}
    for _, it in ipairs(items) do
        table.insert(list, {
            label = it.displayName,
            right = tostring(it.count),
            rcol = C.dim,
            name = it.name,
        })
    end

    local idx = pick("Pick item", list, "Type:Search  Enter:Select  Q:Cancel", nil, {searchable = true})
    if idx then return list[idx].name, list[idx].label end
    return nil
end

local function browseTags()
    clear()
    W, H = term.getSize()
    bar(1, " Scanning network...")
    at(2, 3, "Please wait...", C.dim)

    local tags = network.getAllTags()
    if #tags == 0 then
        at(2, 5, "No tags found on network", C.err)
        os.sleep(1.5)
        return nil
    end

    local list = {}
    for _, tag in ipairs(tags) do
        table.insert(list, { label = tag, name = tag })
    end

    local idx = pick("Pick tag", list, "Type:Search  Enter:Select  Q:Cancel", nil, {searchable = true})
    if idx then return tags[idx] end
    return nil
end

----------------------------------------------------------------------
-- Browse attribute filters (searchable)
----------------------------------------------------------------------

-- Attributes we can detect from item detail data
local ATTRIBUTES = {
    { key = "fuel",       label = "Is furnace fuel",   match = function(d) return d.burnTime and d.burnTime > 0 end },
    { key = "damaged",    label = "Is damaged",        match = function(d) return d.damage and d.damage > 0 end },
    { key = "damageable", label = "Can be damaged",    match = function(d) return d.maxDamage and d.maxDamage > 0 end },
    { key = "enchanted",  label = "Is enchanted",      match = function(d) return d.enchantments and #d.enchantments > 0 end },
    { key = "stackable",  label = "Is stackable",      match = function(d) return d.maxCount and d.maxCount > 1 end },
    { key = "unstackable",label = "Not stackable",     match = function(d) return d.maxCount and d.maxCount == 1 end },
    { key = "food",       label = "Is food",           match = function(d) return d.tags and d.tags["c:foods"] end },
    { key = "ore",        label = "Is an ore",         match = function(d) return d.tags and d.tags["c:ores"] end },
}

-- Tag-based attributes (checked via item tags in stock data)
local TAG_ATTRIBUTES = {
    { key = "smeltable",  label = "Can be smelted",    tag = "c:ingots",    source = true },
    { key = "crushable",  label = "Can be crushed",    tagPattern = "crush" },
    { key = "washable",   label = "Can be washed",     tagPattern = "wash" },
    { key = "fuel_tag",   label = "Is fuel (tag)",     tag = "minecraft:coals" },
    { key = "logs",       label = "Is a log/wood",     tag = "minecraft:logs" },
    { key = "planks",     label = "Is planks",         tag = "minecraft:planks" },
    { key = "stone",      label = "Is stone",          tag = "c:stones" },
    { key = "dye",        label = "Is a dye",          tag = "c:dyes" },
    { key = "glass",      label = "Is glass",          tag = "c:glass_blocks" },
    { key = "ingot",      label = "Is an ingot",       tag = "c:ingots" },
    { key = "nugget",     label = "Is a nugget",       tag = "c:nuggets" },
    { key = "gem",        label = "Is a gem",          tag = "c:gems" },
    { key = "raw_ore",    label = "Is raw ore",        tag = "c:raw_materials" },
    { key = "dust",       label = "Is dust",           tag = "c:dusts" },
}

local function browseAttributes()
    local list = {}

    -- Detail-based attributes
    for _, attr in ipairs(ATTRIBUTES) do
        table.insert(list, { label = attr.label, name = attr.key, attrType = "detail", attr = attr })
    end

    -- Tag-based attributes
    for _, attr in ipairs(TAG_ATTRIBUTES) do
        table.insert(list, { label = attr.label, name = attr.key, attrType = "tag_attr", attr = attr })
    end

    table.insert(list, { label = "" })
    table.insert(list, { label = "Name contains...", name = "__name_filter", attrType = "name" })

    local idx = pick("Pick attribute", list, "Type:Search  Enter:Select  Q:Cancel", nil, {searchable = true})
    if not idx then return nil end

    local chosen = list[idx]

    if chosen.attrType == "name" then
        clear()
        W, H = term.getSize()
        bar(1, " Name filter")
        local pattern = input("Item name contains: ", 3)
        if pattern and pattern ~= "" then
            return { type = "attribute", attrType = "name", pattern = pattern:lower(), label = "Name contains '" .. pattern .. "'" }
        end
        return nil
    end

    return { type = "attribute", attrType = chosen.attrType, key = chosen.attr.key, label = chosen.label, attr = chosen.attr }
end

----------------------------------------------------------------------
-- Pick a destination address (from sensors or manual)
----------------------------------------------------------------------

local function pickAddress()
    local addrs = network.getSensorAddresses()

    local list = {}
    for _, addr in ipairs(addrs) do
        local sensor = network.getSensor(addr)
        local right, rcol = "?", C.dim
        if sensor then
            right, rcol = usageText(sensor)
        end
        table.insert(list, { label = addr, right = right, rcol = rcol, addr = addr })
    end
    table.insert(list, { label = "" })
    table.insert(list, { label = "Type address manually...", action = "manual" })

    local idx = pick("Select frogport address", list, "Enter:Select  Q:Cancel")
    if not idx then return nil end

    if list[idx].action == "manual" then
        clear()
        W, H = term.getSize()
        bar(1, " Add New Storage Container")
        local addr = input("Frogport address: ", 3)
        if addr and addr ~= "" then return addr end
        return nil
    end

    return list[idx].addr
end

----------------------------------------------------------------------
-- Edit destination rules
----------------------------------------------------------------------

local function ruleLabel(rule)
    if rule.type == "item" then
        return "Keep " .. rule.count .. "x " .. (rule.displayName or rule.item)
    elseif rule.type == "tag" then
        return "Send all [" .. rule.tag .. "]"
    elseif rule.type == "attribute" then
        return "Send all: " .. (rule.label or rule.key or "?")
    end
    return "???"
end

local function ruleStatus(rule, address)
    if not rule.enabled then return "OFF", C.off end
    if rule.type == "item" then
        local have = network.getItemCountAt(address, rule.item)
        if have >= rule.count then
            return have .. "/" .. rule.count, C.ok
        else
            return have .. "/" .. rule.count, C.accent
        end
    end
    return "ON", C.on
end

local function editDestination(dest, data)
    while true do
        W, H = term.getSize()
        local items = {}
        local sensor = network.getSensor(dest.address)

        -- Sensor status line
        if sensor then
            local pctText, pctCol = usageText(sensor)
            local total = 0
            for _, c in pairs(sensor.items) do total = total + c end
            table.insert(items, {
                label = "Sensor: online | " .. total .. " items",
                right = pctText .. " full",
                rcol = pctCol,
                action = "info"
            })
        else
            table.insert(items, {
                label = "Sensor: offline (no data)",
                right = "!",
                rcol = C.err,
                action = "info"
            })
        end
        table.insert(items, { label = "" })

        -- Rules
        for i, rule in ipairs(dest.rules) do
            local status, scol = ruleStatus(rule, dest.address)
            table.insert(items, { label = ruleLabel(rule), right = status, rcol = scol, idx = i })
        end
        table.insert(items, { label = "" })
        table.insert(items, { label = "[+] Keep X of item...", action = "add_item" })
        table.insert(items, { label = "[+] Send all with tag...", action = "add_tag" })
        table.insert(items, { label = "[+] Send all by attribute...", action = "add_attr" })
        table.insert(items, { label = "[R] Rename", action = "rename" })
        table.insert(items, { label = "[D] Delete container", action = "delete" })

        local idx = pick(dest.name .. " (" .. dest.address .. ")", items,
            "Enter:Edit  E:Toggle  Q:Back",
            function(key, sel)
                if key == keys.e and items[sel] and items[sel].idx then
                    local rule = dest.rules[items[sel].idx]
                    rule.enabled = not rule.enabled
                    config.save(data)
                    local status, scol = ruleStatus(rule, dest.address)
                    items[sel].right = status
                    items[sel].rcol = scol
                    return "refresh"
                end
            end)

        if not idx then return end

        local it = items[idx]

        if it.action == "info" then
            -- Show detailed sensor inventory
            if sensor then
                local invItems = {}
                for name, count in pairs(sensor.items) do
                    table.insert(invItems, { label = name, right = tostring(count), rcol = C.dim, name = name })
                end
                table.sort(invItems, function(a, b) return a.label < b.label end)
                if #invItems == 0 then
                    table.insert(invItems, { label = "(empty)" })
                end
                pick("Inventory at " .. dest.address, invItems, "Type:Search  Q:Back", nil, {searchable = true})
            end

        elseif it.action == "add_item" then
            clear()
            W, H = term.getSize()
            bar(1, " Add item rule")
            local list = { "Browse network items", "Type item ID manually" }
            local choice = pick("Add item rule", list, "Enter:Select  Q:Cancel")

            local itemName, displayName
            if choice == 1 then
                itemName, displayName = browseItems()
            elseif choice == 2 then
                clear()
                W, H = term.getSize()
                bar(1, " Add item rule")
                itemName = input("Item ID: ", 3)
                displayName = itemName
            end

            if itemName and itemName ~= "" then
                clear()
                W, H = term.getSize()
                bar(1, " Add item rule")
                at(2, 3, "Item: " .. (displayName or itemName), C.accent)
                local have = network.getItemCountAt(dest.address, itemName)
                if have > 0 then
                    at(2, 4, "Currently in container: " .. have, C.dim)
                end
                local countStr = input("How many to keep stocked: ", 6)
                local count = tonumber(countStr)
                if count and count > 0 then
                    table.insert(dest.rules, {
                        type = "item",
                        item = itemName,
                        displayName = displayName,
                        count = math.floor(count),
                        enabled = true,
                    })
                    config.save(data)
                end
            end

        elseif it.action == "add_tag" then
            clear()
            W, H = term.getSize()
            bar(1, " Add tag rule")
            local list = { "Browse network tags", "Type tag manually" }
            local choice = pick("Add tag rule", list, "Enter:Select  Q:Cancel")

            local tag
            if choice == 1 then
                tag = browseTags()
            elseif choice == 2 then
                clear()
                W, H = term.getSize()
                bar(1, " Add tag rule")
                tag = input("Tag: ", 3)
            end

            if tag and tag ~= "" then
                table.insert(dest.rules, {
                    type = "tag",
                    tag = tag,
                    enabled = true,
                })
                config.save(data)
            end

        elseif it.action == "add_attr" then
            local result = browseAttributes()
            if result then
                local rule = {
                    type = "attribute",
                    attrType = result.attrType,
                    label = result.label,
                    enabled = true,
                }
                if result.attrType == "name" then
                    rule.pattern = result.pattern
                elseif result.attrType == "tag_attr" then
                    rule.tag = result.attr.tag
                    rule.tagPattern = result.attr.tagPattern
                    rule.key = result.key
                else
                    rule.key = result.key
                end
                table.insert(dest.rules, rule)
                config.save(data)
            end

        elseif it.action == "rename" then
            clear()
            W, H = term.getSize()
            bar(1, " Rename")
            local name = input("New name: ", 3, dest.name)
            if name and name ~= "" then
                dest.name = name
                config.save(data)
            end

        elseif it.action == "delete" then
            clear()
            W, H = term.getSize()
            bar(1, " Delete container")
            at(2, 3, "Delete '" .. dest.name .. "'? (y/n)", C.err)
            local _, key = os.pullEvent("key")
            if key == keys.y then
                for i, d in ipairs(data.destinations) do
                    if d == dest then
                        table.remove(data.destinations, i)
                        break
                    end
                end
                config.save(data)
                return
            end

        elseif it.idx then
            local rule = dest.rules[it.idx]
            local actions = { "Toggle on/off", "Remove rule" }
            if rule.type == "item" then
                table.insert(actions, 1, "Change amount")
            end
            local choice = pick("Edit: " .. ruleLabel(rule), actions, "Enter:Select  Q:Cancel")
            if choice then
                local action = actions[choice]
                if action == "Change amount" then
                    clear()
                    W, H = term.getSize()
                    bar(1, " Change amount")
                    local have = network.getItemCountAt(dest.address, rule.item)
                    at(2, 3, "Currently in container: " .. have, C.dim)
                    local val = input("New amount to keep: ", 5, tostring(rule.count))
                    val = tonumber(val)
                    if val and val > 0 then
                        rule.count = math.floor(val)
                        config.save(data)
                    end
                elseif action == "Toggle on/off" then
                    rule.enabled = not rule.enabled
                    config.save(data)
                elseif action == "Remove rule" then
                    table.remove(dest.rules, it.idx)
                    config.save(data)
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- Main screen
----------------------------------------------------------------------

local function buildMainList(data)
    local items = {}
    for _, dest in ipairs(data.destinations) do
        local sensor = network.getSensor(dest.address)
        local right, rcol
        if sensor then
            right, rcol = usageText(sensor)
        else
            right = "no sensor"
            rcol = C.err
        end
        table.insert(items, { label = dest.name, right = right, rcol = rcol, dest = dest })
    end
    table.insert(items, { label = "" })
    table.insert(items, { label = "[+] Add New Storage Container", action = "add" })
    return items
end

function ui.run(data)
    while true do
        W, H = term.getSize()
        local items = buildMainList(data)

        local idx = pick("Configure Storage", items, "Enter:Edit  N:New  Q:Quit",
            function(key, sel)
                if key == keys.n then
                    clear()
                    W, H = term.getSize()
                    bar(1, " Add New Storage Container")
                    local name = input("Container Name (e.g. Tools): ", 3)
                    if name and name ~= "" then
                        local addr = pickAddress()
                        if addr then
                            table.insert(data.destinations, { name = name, address = addr, rules = {} })
                            config.save(data)
                            local newItems = buildMainList(data)
                            for k in pairs(items) do items[k] = nil end
                            for k, v in ipairs(newItems) do items[k] = v end
                        end
                    end
                    return "refresh"
                end
            end)

        if not idx then
            clear()
            W, H = term.getSize()
            bar(1, " Quit")
            at(2, 3, "Stop controller and exit? (y/n)", C.accent)
            local _, key = os.pullEvent("key")
            if key == keys.y then return end
        elseif items[idx].action == "add" then
            clear()
            W, H = term.getSize()
            bar(1, " Add New Storage Container")
            local name = input("Container Name (e.g. Tools): ", 3)
            if name and name ~= "" then
                local addr = pickAddress()
                if addr then
                    table.insert(data.destinations, {
                        name = name,
                        address = addr,
                        rules = {},
                    })
                    config.save(data)
                end
            end
        elseif items[idx].dest then
            editDestination(items[idx].dest, data)
        end
    end
end

return ui
