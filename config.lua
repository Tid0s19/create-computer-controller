-- config.lua — Simple persistent config

local config = {}
local CONFIG_FILE = "routes.json"

function config.load()
    if not fs.exists(CONFIG_FILE) then
        return { destinations = {}, groups = {} }
    end
    local f = fs.open(CONFIG_FILE, "r")
    local raw = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialiseJSON, raw)
    if ok and data and data.destinations then
        if not data.groups then data.groups = {} end
        -- Migrate old single-address format to addresses list
        local migrated = false
        for _, dest in ipairs(data.destinations) do
            if dest.address and not dest.addresses then
                dest.addresses = { dest.address }
                dest.address = nil
                migrated = true
            end
        end
        if migrated then config.save(data) end
        return data
    end
    return { destinations = {}, groups = {} }
end

function config.save(data)
    local raw = textutils.serialiseJSON(data)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(raw)
    f.close()
end

return config
