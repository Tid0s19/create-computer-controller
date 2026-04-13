# Create Controller

CC:Tweaked program for smart Create 6.0 logistics automation. Uses wireless sensor computers at each location to monitor inventories and move items via Packagers. The controller decides what goes where — sensors do the shipping.

## How it works

- **Controller** = the brain. Knows every inventory, decides what needs moving.
- **Sensors** = workers at each location. Report inventory + ship items via Packager when told.
- Items move **sensor-to-sensor** via Packagers and Frogports. No Stock Ticker recycling loops.

**Example:** "Keep 50 coal at crusher" → controller sees crusher has 30, storage has 200 → tells storage sensor to ship 20 coal to "crush" address → storage Packager packages 20 coal, Frogport sends it.

## Setup

### Controller (one computer)
1. Place computer with a **wireless modem** attached
2. Optionally adjacent to a **Stock Ticker** (enables tag browsing)
3. Install: `wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install.lua`
4. `reboot`

### Sensor (one per location)
Each sensor computer needs to be **touching**:
- A **wireless modem**
- A **chest/barrel** (the inventory it monitors)
- A **Packager** (for sending items — connects to a Frogport on the chain conveyor)

Install: `wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install-sensor.lua`

Then `reboot` — it asks for the frogport address on first run.

Sensors without a Packager still work for receiving/monitoring but can't send items.

## Usage

1. Boot the controller — sensors appear automatically
2. Press **N** to add a destination, pick from discovered sensors
3. Add rules:
   - **Keep X of item** — maintains stock level, only tops up from other locations
   - **Send all with tag** — routes tagged items from wherever they are (needs Stock Ticker)
4. Rules auto-run every 10 seconds

## Controls

| Key | Action |
|-----|--------|
| Up/Down | Navigate |
| Enter | Select |
| Q | Back |
| N | New destination |
| E | Toggle rule on/off |
