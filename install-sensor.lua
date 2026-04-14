-- Sensor Installer for Create Controller
-- Run in-game: wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install-sensor.lua

local repo = "https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/"

term.clear()
term.setCursorPos(1, 1)
term.setTextColour(colours.yellow)
print("Configure Storage - Sensor Install")
print()
term.setTextColour(colours.white)

local failed = false

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
else
    term.setTextColour(colours.red)
    print("FAILED")
    failed = true
end

-- Download display module
term.setTextColour(colours.grey)
write("  Downloading display... ")
if fs.exists("display.lua") then
    fs.delete("display.lua")
end

local ok2 = pcall(function()
    shell.run("wget", repo .. "display.lua", "display.lua")
end)

if ok2 and fs.exists("display.lua") then
    term.setTextColour(colours.lime)
    print("OK")
else
    term.setTextColour(colours.red)
    print("FAILED")
    failed = true
end

-- Download updater module
term.setTextColour(colours.grey)
write("  Downloading updater... ")
if fs.exists("updater.lua") then
    fs.delete("updater.lua")
end

local ok3 = pcall(function()
    shell.run("wget", repo .. "updater.lua", "updater.lua")
end)

if ok3 and fs.exists("updater.lua") then
    term.setTextColour(colours.lime)
    print("OK")
else
    term.setTextColour(colours.red)
    print("FAILED")
    failed = true
end

print()
if failed then
    term.setTextColour(colours.red)
    print("Some files failed to download.")
    print("Check HTTP is enabled.")
else
    term.setTextColour(colours.lime)
    print("Sensor installed!")
    print()
    term.setTextColour(colours.white)
    print("Place this computer next to:")
    print("  - A wireless modem")
    print("  - The destination chest/barrel")
    print("  - Monitor (optional, shows")
    print("    inventory & fill level)")
    print()
    print("Then reboot. It will ask for the")
    print("frogport address on first run.")
    print()
    term.setTextColour(colours.grey)
    print("Type: reboot")
end
term.setTextColour(colours.white)
