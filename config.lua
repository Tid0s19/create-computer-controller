-- config.lua — Simple persistent config

local config = {}
local CONFIG_FILE = "routes.json"

function config.load()
    if not fs.exists(CONFIG_FILE) then
        return { destinations = {} }
    end
    local f = fs.open(CONFIG_FILE, "r")
    local raw = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialiseJSON, raw)
    if ok and data and data.destinations then
        return data
    end
    return { destinations = {} }
end

function config.save(data)
    local raw = textutils.serialiseJSON(data)
    local f = fs.open(CONFIG_FILE, "w")
    f.write(raw)
    f.close()
end

return config
