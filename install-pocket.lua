-- Pocket Client Installer for Configure Storage
-- Run in-game: wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install-pocket.lua

local repo = "https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/"

local files = {
    { remote = "pocket.lua", local_name = "startup.lua" },
    { remote = "ui.lua",     local_name = "ui.lua" },
}

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Configure Storage")
print("  Pocket Client Installer")
print()
term.setTextColour(colours.white)

local failed = false
for _, file in ipairs(files) do
    term.setTextColour(colours.grey)
    write("  Downloading " .. file.remote .. "... ")

    if fs.exists(file.local_name) then
        fs.delete(file.local_name)
    end

    local ok = pcall(function()
        shell.run("wget", repo .. file.remote, file.local_name)
    end)

    if ok and fs.exists(file.local_name) then
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
    print("Check HTTP is enabled.")
else
    term.setTextColour(colours.lime)
    print("Pocket client installed!")
    print()
    term.setTextColour(colours.white)
    print("Make sure the server is running,")
    print("then reboot this pocket computer.")
    print()
    print("Must be within ~64 blocks of")
    print("the server to connect.")
    print()
    term.setTextColour(colours.grey)
    print("Type: reboot")
end
term.setTextColour(colours.white)
