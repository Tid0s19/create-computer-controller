# Create Controller

CC:Tweaked program for automating Create 6.0 logistics. Place a computer next to a Stock Ticker, define where items should go, and it handles the rest.

## Setup

1. Place a **Stock Ticker** on your logistics network
2. Place a **Computer** next to it
3. Install (in-game): `wget run https://raw.githubusercontent.com/Tid0s19/create-computer-controller/master/install.lua`
4. `reboot`

## Usage

**Add a destination** — give it a name and the frogport address (must match exactly).

**Add rules** to each destination:
- **Keep X of item** — sends up to X of a specific item (e.g. "Keep 50 Iron Ingots")
- **Send all with tag** — sends everything matching a tag (e.g. all items tagged `crushable`)

You can browse items and tags live from the network, or type them manually.

Rules run automatically every 10 seconds in the background.

## Controls

| Key | Action |
|-----|--------|
| Up/Down | Navigate |
| Enter | Select |
| Q | Back |
| N | New destination |
| E | Toggle rule on/off |
