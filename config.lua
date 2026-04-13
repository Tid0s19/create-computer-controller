-- config.lua — Persistent route configuration for Create Controller
-- Saves/loads routing rules to a JSON file on the computer

local config = {}

local CONFIG_FILE = "routes.json"

-- Default empty config structure
local function defaultConfig()
    return {
        routes = {}
        -- Each route:
        -- {
        --   name = "Crusher",
        --   address = "crusher",
        --   enabled = true,
        --   interval = 10,         -- seconds between requests
        --   stackCount = 1,        -- how many stacks per item per cycle
        --   filters = {
        --     items = { "minecraft:cobblestone", "minecraft:gravel" },
        --     tags = { "c:ores", "create:crushable" },
        --     globs = { "minecraft:*_ore" },
        --   },
        --   exclusions = {
        --     items = { "minecraft:diamond_ore" },
        --     tags = { "c:storage_blocks" },
        --     globs = { "*_deepslate_*" },
        --   },
        -- }
    }
end

function config.load()
    if not fs.exists(CONFIG_FILE) then
        return defaultConfig()
    end
    local f = fs.open(CONFIG_FILE, "r")
    local raw = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialiseJSON, raw)
    if ok and data and data.routes then
        return data
    end
    return defaultConfig()
end

function config.save(data)
    local raw = textutils.serialiseJSON(data)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(raw)
    f.close()
end

function config.newRoute(name, address)
    return {
        name = name or "",
        address = address or "",
        enabled = true,
        interval = 10,
        stackCount = 1,
        filters = {
            items = {},
            tags = {},
            globs = {},
        },
        exclusions = {
            items = {},
            tags = {},
            globs = {},
        },
    }
end

function config.addFilter(route, filterType, value)
    local list = route.filters[filterType]
    if not list then return false end
    for _, v in ipairs(list) do
        if v == value then return false end -- duplicate
    end
    table.insert(list, value)
    return true
end

function config.removeFilter(route, filterType, index)
    local list = route.filters[filterType]
    if not list or not list[index] then return false end
    table.remove(list, index)
    return true
end

function config.addExclusion(route, filterType, value)
    local list = route.exclusions[filterType]
    if not list then return false end
    for _, v in ipairs(list) do
        if v == value then return false end
    end
    table.insert(list, value)
    return true
end

function config.removeExclusion(route, filterType, index)
    local list = route.exclusions[filterType]
    if not list or not list[index] then return false end
    table.remove(list, index)
    return true
end

return config
