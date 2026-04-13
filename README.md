# Create Controller

A CC:Tweaked program for automating Create 6.0 logistics routing. Define rules to automatically send items from your Stock Link network to any frogport address, filtered by item name, tag, or glob pattern — with exclusions.

## Requirements

- Minecraft with **Create 6.0+** and **CC:Tweaked**
- A **Stock Ticker** connected to your logistics network
- A **CC:Tweaked Computer** placed adjacent to the Stock Ticker
- Frogports at your destinations (crusher, smelter, etc.)

## Setup

1. Place a **Stock Ticker** connected to your logistics network (Stock Links)
2. Place a **Computer** (regular or advanced) next to the Stock Ticker
3. Copy all `.lua` files to the computer:
   - `startup.lua` — entry point (auto-runs on boot)
   - `config.lua` — config persistence
   - `network.lua` — Stock Ticker API wrapper
   - `router.lua` — background routing engine
   - `ui.lua` — terminal UI

## Usage

The program runs automatically when the computer boots (since the entry point is `startup.lua`).

### Creating a Route

1. Press **N** or select **[+] New Route**
2. Enter a name (e.g. "Crusher", "Smelter", "Fuel Store")
3. Enter the frogport address — this must **exactly match** the address on the destination frogport

### Configuring Filters

Select a route and edit its filters. There are three types:

- **Items** — Exact item IDs (e.g. `minecraft:cobblestone`)
- **Tags** — Item tags (e.g. `c:ores`, `forge:ingots`) — matches any item with that tag
- **Globs** — Wildcard patterns (e.g. `minecraft:*_ore`, `create:crushed_*`)

When browsing items or tags, press **B** to scan the network and pick from what's actually in stock.

### Exclusions

Same three types (items, tags, globs) but these **prevent** matching items from being sent. Exclusions override filters — if an item matches both a filter and an exclusion, it won't be sent.

### Settings per Route

- **Interval** — How often (in seconds) the route checks and sends items (default: 10s)
- **Stacks per item** — Max stacks of each item type to send per cycle (default: 1)
- **Enabled/Disabled** — Toggle with **E** from the route list

### Testing

Select a route and choose **[ Test Route ]** to see which items in your network currently match the filters (and which are excluded) without actually sending anything.

### Keyboard Shortcuts

| Key | Context | Action |
|-----|---------|--------|
| Up/Down | Lists | Navigate |
| PgUp/PgDn | Lists | Jump pages |
| Enter | Lists | Select/Edit |
| Q | Anywhere | Go back |
| N | Route list | New route |
| E | Route list | Toggle enable/disable |
| S | Route list | View router status |
| A | Filter list | Add new filter |
| B | Filter list | Browse network items/tags |
| X/Del | Filter list | Remove selected |

## Example: Crusher Automation

1. Create a route named "Crusher" with address "crusher"
2. Add a tag filter: `create:crushable` (or whatever tag your crushable items share)
3. Alternatively, add glob filters like `minecraft:*_ore` or specific items
4. Add exclusions for anything you don't want crushed (e.g. `minecraft:diamond_ore`)
5. Set stacks to 4 and interval to 15s
6. The router will automatically pull matching items from the network and send them to your crusher frogport

## How It Works

The program runs two coroutines in parallel:
- **UI** — handles all user interaction in the terminal
- **Router** — background loop that ticks every second, checking each enabled route's interval timer and executing `requestFiltered()` on the Stock Ticker to send matching items

Routes are saved to `routes.json` on the computer and persist across reboots.
