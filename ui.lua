-- ui.lua — Simple terminal UI for Create Controller

local config = require("config")
local network = require("network")

local ui = {}
local W, H

-- Colours
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
-- Generic list picker — returns index or nil
----------------------------------------------------------------------

local function pick(title, items, hints, onKey)
    local sel, scroll = 1, 0
    local rows = H - 4

    while true do
        W, H = term.getSize()
        rows = H - 4
        clear()
        bar(1, " " .. title)
        footer(hints or "Up/Down:Move  Enter:Select  Q:Back")

        if #items == 0 then
            at(2, math.floor(H / 2), "Nothing here yet", C.dim)
        else
            if sel - scroll > rows then scroll = sel - rows end
            if sel - scroll < 1 then scroll = sel - 1 end

            for i = 1, rows do
                local idx = i + scroll
                if idx > #items then break end
                local it = items[idx]
                local y = i + 2
                local label = type(it) == "table" and it.label or tostring(it)
                local right = type(it) == "table" and it.right or nil

                if idx == sel then
                    at(1, y, string.rep(" ", W), nil, colours.grey)
                    at(2, y, "> " .. trunc(label, W - 6), C.sel, colours.grey)
                    if right then
                        at(W - #right, y, right, (type(it) == "table" and it.rcol) or C.dim, colours.grey)
                    end
                else
                    at(4, y, trunc(label, W - 6), colours.white)
                    if right then
                        at(W - #right, y, right, (type(it) == "table" and it.rcol) or C.dim)
                    end
                end
            end
        end

        local _, key = os.pullEvent("key")
        if key == keys.up then
            sel = sel > 1 and sel - 1 or #items
            -- Skip empty spacer lines
            while sel > 0 and type(items[sel]) == "table" and items[sel].label == "" do
                sel = sel > 1 and sel - 1 or #items
            end
        elseif key == keys.down then
            sel = sel < #items and sel + 1 or 1
            while sel <= #items and type(items[sel]) == "table" and items[sel].label == "" do
                sel = sel < #items and sel + 1 or 1
            end
        elseif key == keys.enter and #items > 0 then
            if type(items[sel]) == "table" and items[sel].label == "" then
                -- Don't select spacers
            else
                return sel
            end
        elseif key == keys.q then
            return nil
        elseif onKey then
            local result = onKey(key, sel)
            if result == "refresh" then
                sel = math.min(sel, math.max(1, #items))
            end
        end
    end
end

----------------------------------------------------------------------
-- Browse network: pick an item
----------------------------------------------------------------------

local function browseItems()
    clear()
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

    local idx = pick("Pick item from network", list, "Enter:Select  Q:Cancel")
    if idx then return list[idx].name, list[idx].label end
    return nil
end

----------------------------------------------------------------------
-- Browse network: pick a tag
----------------------------------------------------------------------

local function browseTags()
    clear()
    bar(1, " Scanning network...")
    at(2, 3, "Please wait...", C.dim)

    local tags = network.getAllTags()
    if #tags == 0 then
        at(2, 5, "No tags found on network", C.err)
        os.sleep(1.5)
        return nil
    end

    local idx = pick("Pick tag from network", tags, "Enter:Select  Q:Cancel")
    if idx then return tags[idx] end
    return nil
end

----------------------------------------------------------------------
-- Edit a destination's rules
----------------------------------------------------------------------

local function ruleLabel(rule)
    if rule.type == "item" then
        return "Keep " .. rule.count .. "x " .. (rule.displayName or rule.item)
    elseif rule.type == "tag" then
        return "Send all [" .. rule.tag .. "]"
    end
    return "???"
end

local function editDestination(dest, data)
    while true do
        local items = {}
        for i, rule in ipairs(dest.rules) do
            local status = rule.enabled and "ON" or "OFF"
            local scol = rule.enabled and C.on or C.off
            table.insert(items, { label = ruleLabel(rule), right = status, rcol = scol, idx = i })
        end
        table.insert(items, { label = "" })
        table.insert(items, { label = "[+] Keep X of item...", action = "add_item" })
        table.insert(items, { label = "[+] Send all with tag...", action = "add_tag" })
        table.insert(items, { label = "[R] Rename", action = "rename" })
        table.insert(items, { label = "[D] Delete destination", action = "delete" })

        local idx = pick(dest.name .. " (" .. dest.address .. ")", items,
            "Enter:Edit  E:Toggle  X:Remove  Q:Back",
            function(key, sel)
                if key == keys.e and items[sel] and items[sel].idx then
                    local rule = dest.rules[items[sel].idx]
                    rule.enabled = not rule.enabled
                    config.save(data)
                    -- Update the displayed status
                    items[sel].right = rule.enabled and "ON" or "OFF"
                    items[sel].rcol = rule.enabled and C.on or C.off
                    return "refresh"
                end
            end)

        if not idx then return end

        local it = items[idx]

        if it.action == "add_item" then
            -- Add "keep X of item" rule
            clear()
            bar(1, " Add item rule")
            at(2, 3, "Browse network or type manually?", C.dim)
            local list = { "Browse network items", "Type item ID manually" }
            local choice = pick("Add item rule", list, "Enter:Select  Q:Cancel")

            local itemName, displayName
            if choice == 1 then
                itemName, displayName = browseItems()
            elseif choice == 2 then
                clear()
                bar(1, " Add item rule")
                itemName = input("Item ID: ", 3)
                displayName = itemName
            end

            if itemName and itemName ~= "" then
                clear()
                bar(1, " Add item rule")
                at(2, 3, "Item: " .. (displayName or itemName), C.accent)
                local countStr = input("How many to keep: ", 5)
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
            -- Add "send all with tag" rule
            clear()
            bar(1, " Add tag rule")
            local list = { "Browse network tags", "Type tag manually" }
            local choice = pick("Add tag rule", list, "Enter:Select  Q:Cancel")

            local tag
            if choice == 1 then
                tag = browseTags()
            elseif choice == 2 then
                clear()
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

        elseif it.action == "rename" then
            clear()
            bar(1, " Rename")
            local name = input("New name: ", 3, dest.name)
            if name and name ~= "" then
                dest.name = name
                config.save(data)
            end

        elseif it.action == "delete" then
            clear()
            bar(1, " Delete destination")
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
            -- Edit existing rule
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
                    bar(1, " Change amount")
                    local val = input("New amount: ", 3, tostring(rule.count))
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

function ui.run(data)
    while true do
        W, H = term.getSize()
        local items = {}
        for _, dest in ipairs(data.destinations) do
            local active = 0
            for _, r in ipairs(dest.rules) do
                if r.enabled then active = active + 1 end
            end
            local right = active .. " rule" .. (active ~= 1 and "s" or "")
            table.insert(items, { label = dest.name .. " -> " .. dest.address, right = right, rcol = C.dim, dest = dest })
        end
        table.insert(items, { label = "" })
        table.insert(items, { label = "[+] Add destination", action = "add" })

        local idx = pick("Create Controller", items, "Enter:Edit  N:New  Q:Quit",
            function(key, sel)
                if key == keys.n then
                    clear()
                    bar(1, " New destination")
                    local name = input("Name (e.g. Crusher): ", 3)
                    if name and name ~= "" then
                        clear()
                        bar(1, " New destination")
                        local addr = input("Frogport address: ", 3)
                        if addr and addr ~= "" then
                            local dest = { name = name, address = addr, rules = {} }
                            table.insert(data.destinations, dest)
                            config.save(data)
                            -- Rebuild list
                            local newItems = {}
                            for _, d in ipairs(data.destinations) do
                                local active = 0
                                for _, r in ipairs(d.rules) do
                                    if r.enabled then active = active + 1 end
                                end
                                local right = active .. " rule" .. (active ~= 1 and "s" or "")
                                table.insert(newItems, { label = d.name .. " -> " .. d.address, right = right, rcol = C.dim, dest = d })
                            end
                            table.insert(newItems, { label = "" })
                            table.insert(newItems, { label = "[+] Add destination", action = "add" })
                            for k in pairs(items) do items[k] = nil end
                            for k, v in ipairs(newItems) do items[k] = v end
                        end
                    end
                    return "refresh"
                end
            end)

        if not idx then
            clear()
            bar(1, " Quit")
            at(2, 3, "Stop controller and exit? (y/n)", C.accent)
            local _, key = os.pullEvent("key")
            if key == keys.y then return end
        elseif items[idx].action == "add" then
            clear()
            bar(1, " New destination")
            local name = input("Name (e.g. Crusher): ", 3)
            if name and name ~= "" then
                clear()
                bar(1, " New destination")
                local addr = input("Frogport address: ", 3)
                if addr and addr ~= "" then
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
