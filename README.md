# Create Controller

CC:Tweaked program for smart Create 6.0 logistics automation. Uses wireless sensor computers at each destination to monitor inventory levels, so items are only sent when actually needed — like a programmable Factory Gauge with tag support.

## How it works

- **Controller computer** sits next to a Stock Ticker + wireless modem
- **Sensor computers** sit next to destination chests + wireless modem, broadcasting inventory levels
- Controller sees all sensors automatically, knows what's at each destination
- Rules like "keep 50 iron ingots" only send the shortfall
- Rules like "send all [crushable]" only send when there's room

## Setup

### Controller (main computer)
1. Place computer next to a **Stock Ticker** on your logistics network
2. Attach a **wireless modem** to the computer
3. Install: `wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install.lua`
4. `reboot`

### Sensor (at each destination)
1. Place a computer next to the **destination chest/barrel**
2. Attach a **wireless modem**
3. Install: `wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install-sensor.lua`
4. `reboot` — it will ask for the frogport address

Sensors auto-announce to the controller. No configuration needed on the controller side.

## Usage

1. Press **N** to add a destination — sensors appear automatically in the address picker
2. Add rules:
   - **Keep X of item** — maintains stock level, only sends when below threshold
   - **Send all with tag** — routes tagged items, only when destination has room
3. Rules run automatically every 10 seconds

## Controls

| Key | Action |
|-----|--------|
| Up/Down | Navigate |
| Enter | Select |
| Q | Back |
| N | New destination |
| E | Toggle rule on/off |
