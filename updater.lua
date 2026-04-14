-- updater.lua — Auto-update module for Create Controller
-- Downloads latest code from GitHub on boot. Reboots if files changed.

local updater = {}

local REPO = "https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/"

-- Files for each program type
local FILE_SETS = {
    controller = {
        "startup.lua",
        "config.lua",
        "network.lua",
        "router.lua",
        "display.lua",
        "ui.lua",
        "updater.lua",
    },
    sensor = {
        { remote = "sensor.lua", localName = "startup.lua" },
        "display.lua",
        "updater.lua",
    },
    pocket = {
        { remote = "pocket.lua", localName = "startup.lua" },
        "ui.lua",
        "updater.lua",
    },
}

local function download(url)
    local resp = http.get(url)
    if not resp then return nil end
    local body = resp.readAll()
    resp.close()
    return body
end

local function readFile(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    return content
end

local function writeFile(path, content)
    local f = fs.open(path, "w")
    f.write(content)
    f.close()
end

-- Check for updates and apply them
-- programType: "controller", "sensor", or "pocket"
-- Returns true if rebooting (caller should return immediately)
function updater.check(programType)
    local fileSet = FILE_SETS[programType]
    if not fileSet then return false end

    local changed = false
    local anyFailed = false

    term.setTextColour(colours.grey)
    print("Checking for updates...")

    for _, entry in ipairs(fileSet) do
        local remoteName, localName
        if type(entry) == "table" then
            remoteName = entry.remote
            localName = entry.localName
        else
            remoteName = entry
            localName = entry
        end

        local url = REPO .. remoteName
        local newContent = download(url)
        if newContent then
            local oldContent = readFile(localName)
            if newContent ~= oldContent then
                writeFile(localName, newContent)
                term.setTextColour(colours.cyan)
                print("  Updated: " .. remoteName)
                changed = true
            end
        else
            anyFailed = true
        end
    end

    if changed then
        term.setTextColour(colours.lime)
        print("Updates applied! Rebooting...")
        os.sleep(1)
        os.reboot()
        return true -- won't reach here, but signals intent
    end

    if not anyFailed then
        term.setTextColour(colours.grey)
        print("Up to date.")
    end

    return false
end

return updater
