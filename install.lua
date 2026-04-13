-- Create Controller Installer
-- Run in-game: wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install.lua

local repo = "https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/"

local files = {
    "startup.lua",
    "config.lua",
    "network.lua",
    "router.lua",
    "display.lua",
    "ui.lua",
}

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Configure Storage - Installer")
print()
term.setTextColour(colours.white)

local failed = false
for _, file in ipairs(files) do
    local url = repo .. file
    term.setTextColour(colours.grey)
    write("  Downloading " .. file .. "... ")

    -- Remove old version if it exists
    if fs.exists(file) then
        fs.delete(file)
    end

    local ok, err = pcall(function()
        shell.run("wget", url, file)
    end)

    if ok and fs.exists(file) then
        term.setTextColour(colours.lime)
        print("OK")
    else
        term.setTextColour(colours.red)
        print("FAILED")
        failed = true
    end
end

print()
if failed then
    term.setTextColour(colours.red)
    print("Some files failed to download.")
    print("Check your HTTP config is enabled.")
else
    term.setTextColour(colours.lime)
    print("Controller installed!")
    term.setTextColour(colours.white)
    print()
    print("This computer needs:")
    print("  - Adjacent to a Stock Ticker")
    print("  - Wireless modem attached")
    print("  - Monitor (optional, shows all")
    print("    containers & fill levels)")
    print()
    print("At each destination, place a")
    print("sensor computer next to the")
    print("chest + wireless modem.")
    print("Install sensor with:")
    term.setTextColour(colours.cyan)
    print()
    print("wget run https://raw.githubuserco")
    print("ntent.com/Tid0s19/create-computer")
    print("-controller/master/install-sensor")
    print(".lua")
    print()
    term.setTextColour(colours.grey)
    print("Type: reboot")
end
term.setTextColour(colours.white)
