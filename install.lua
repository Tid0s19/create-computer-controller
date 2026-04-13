-- Create Controller Installer
-- Run in-game: wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install.lua

local repo = "https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/"

local files = {
    "startup.lua",
    "config.lua",
    "network.lua",
    "router.lua",
    "ui.lua",
}

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Create Controller Installer")
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
    print("Installation complete!")
    term.setTextColour(colours.white)
    print()
    print("Place this computer next to a")
    print("Stock Ticker and reboot to start.")
    print()
    term.setTextColour(colours.grey)
    print("Or type: reboot")
end
term.setTextColour(colours.white)
