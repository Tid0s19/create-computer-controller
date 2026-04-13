-- Sensor Installer for Create Controller
-- Run in-game: wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install-sensor.lua

local repo = "https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/"

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Create Controller - Sensor Install")
print()
term.setTextColour(colours.white)

-- Download sensor.lua as startup.lua so it auto-runs
write("  Downloading sensor... ")
if fs.exists("startup.lua") then
    fs.delete("startup.lua")
end

local ok = pcall(function()
    shell.run("wget", repo .. "sensor.lua", "startup.lua")
end)

if ok and fs.exists("startup.lua") then
    term.setTextColour(colours.lime)
    print("OK")
    print()
    term.setTextColour(colours.white)
    print("Sensor installed!")
    print()
    print("Place this computer next to:")
    print("  - A wireless modem")
    print("  - The destination chest/barrel")
    print()
    print("Then reboot. It will ask for the")
    print("frogport address on first run.")
    print()
    term.setTextColour(colours.grey)
    print("Type: reboot")
else
    term.setTextColour(colours.red)
    print("FAILED")
    print("Check HTTP is enabled.")
end
term.setTextColour(colours.white)
