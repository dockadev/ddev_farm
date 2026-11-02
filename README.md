# ddev_farm

Farming and live market resource for FiveM (QBCore / QBX / ESX).
Players harvest crops, sell to a dynamic market and level up their bargaining bonus.

- Author: **dockadev**
- Version: **1.1.0**
- Price: **Free** — full source, no escrow, no obfuscation
- Source: **https://github.com/dockadev/ddev_farm**
- UI languages: **English, Türkçe, Deutsch, Français, Italiano, Español**

This resource is released for free. The complete source is public so you can read,
audit and modify it. There is no asset protection, no license server and no phone-home
call anywhere in the code.

---

## Features

- **Two-stage harvest minigame** — a progress bar pauses at 25% and 75% for a timing
  check; the number of successful checks decides the produce quality
  (Spoiled / Normal / Prime).
- **Live supply & demand market** — prices move with real player sales, not with a
  fixed table. Dumping stock pushes the price down, an idle market drifts back to its
  base price automatically.
- **Player progression** — lifetime harvests unlock levels, each level adds a bargaining
  bonus to your sell price.
- **No-restart node placement tool (`/farmplace`)** — place single nodes or draw lines
  with spacing, height and rotation control, then apply them in-game.
- **In-game admin panel (`/farmadmin`)** — market, harvest, minigame, world, progression,
  tools, setup and language tabs. Everything is editable without touching a file.
- **6 languages** — English, Turkish, German, French, Italian, Spanish (server-wide
  switchable from the admin panel).
- **Server-side validation** — harvest limits, daily caps, sell caps, anti-dump damping
  and inventory checks. Client events are never trusted.

---

## Requirements

| Resource | Purpose |
|---|---|
| `oxmysql` | Database |
| `ox_lib` | Notifications, locale |
| `ox_inventory` | Items |

Optional (only for the corn prop): **BzZz Addon Props** (free community prop pack,
author `BzZz`, version 2.0.0). The corn model is
`prop_bzzz_gardenpack_cornstalk001`. If the pack is not installed, corn nodes are
skipped silently; everything else keeps working. You can also point
`Config.CropPropModel.corn` to any prop you already stream.

---

## Installation

1. Copy the `ddev_farm` folder into your resources directory.
2. Add the item definitions below to `ox_inventory/data/items.lua`.
3. Add images `apple.png`, `tomato.png`, `corn.png`, `orange.png` to
   `ox_inventory/web/images/` (icons can also be taken from `ddev_farm/web/images`).
4. `ensure ddev_farm` in `server.cfg` (after `oxmysql`, `ox_lib`, `ox_inventory`).
5. Start the server. Database tables are created automatically.

```lua
['apple'] = {
    label = 'Apple',
    weight = 800,
    stack = true,
    close = true,
    description = 'Apple picked in the orchard. Its quality determines the price.',
    client = { image = 'apple.png' },
},

['tomato'] = {
    label = 'Tomato',
    weight = 600,
    stack = true,
    close = true,
    description = 'Tomato picked in the orchard. Its quality determines the price.',
    client = { image = 'tomato.png' },
},

['corn'] = {
    label = 'Corn',
    weight = 700,
    stack = true,
    close = true,
    description = 'Corn picked in the orchard. Its quality determines the price.',
    client = { image = 'corn.png' },
},

['orange'] = {
    label = 'Orange',
    weight = 900,
    stack = true,
    close = true,
    description = 'Orange picked in the orchard. Its quality determines the price.',
    client = { image = 'orange.png' },
},
```

> The repository holds the resource files at its root. Rename the downloaded folder to
> `ddev_farm` so the `ensure ddev_farm` line matches.

---

## Commands

| Command | Access | Description |
|---|---|---|
| `/farmpanel` | Everyone | Player panel: level, bonus roadmap, recent sales, preferences |
| `/farmadmin` | Admin | Config panel: market, harvest, minigame, world, progression, tools, setup, languages |
| `/farmplace` | Admin | Node placement tool (Place / Line mode, ground snap, NPC position) |
| `/farmpos <crop>` | Admin | Quick alternative: saves your current standing position to `farmpos_<crop>.lua` |

### Admin access

Access is checked in this order:

1. **ACE** — `group.admin` or `command` (`Config.Admin.aces`)
2. **Framework admin group**
   - QBX / QB: `PlayerData.group` is one of `admin`, `god`, `owner`, `superadmin`, `management`
   - ESX: `player.getGroup()` returns an admin group

Group membership alone is not visible to scripts, so the check looks for an ACE the group
normally holds. Servers that grant admins `command` (the usual QBCore/ESX setup) are
detected without any extra line:

```cfg
add_ace group.admin command allow
```

If your staff uses a different ACE, add its name to `Config.Admin.aces`.

---

## Placement workflow

1. Enable noclip or freecam yourself (the tool does not enable it).
2. `/farmplace` → pick crop, mode, spacing, height and rotation → **Start Placement**.
3. Place / draw the line, confirm with `E`, exit with `X`.
4. `/farmadmin` → **Setup → Node Management → Apply Nodes** — nodes become active
   immediately, no restart needed.
5. Use the per-crop **Clear** button to reset a single crop.

Points are stored in `farmpos_<crop>.lua`; they are applied automatically on boot.

---

## Configuration

| File | Purpose |
|---|---|
| `config/config.lua` | Core config: locale, harvest, economy, market, progression, support links |
| `config/zones.lua` | Harvest zones, node lists, blips |
| `config/crops.lua` | Crop definitions (names, base price, yield, grow time) |
| `config/npcpos.lua` | Market NPC position (written by the placement tool) |
| `config/locales.lua` | Server-side strings (notifications) for all 6 languages |
| `config/server.lua` | Server-only settings (Discord webhook) |

### Language

`Config.Locale = 'en'` — can also be changed in game from
`/farmadmin → World → Interface Language` (a **server-wide** setting: it changes the
language for every player).

### Skill check engine

```lua
Config.SkillCheck.engine = 'custom' -- 'custom' | 'ox'
```

- `custom` — the two-stage timing check shipped with the resource (default look)
- `ox` — uses `lib.skillCheck` from ox_lib; difficulty and inputs come from `Config.SkillCheck.ox`

### Support links

```lua
Config.Support = {
    discord = 'https://discord.gg/Gep3cg64q4',
    store = '',   -- optional store link
}
```
Leave a field empty to hide its button. Discord link is shown in the admin sidebar.

---

## Notes

- All prices are driven by real player sales (supply/demand). Selling in bulk lowers
  the price; an idle market returns to the base price automatically.
- Daily sell / harvest caps, anti-dump damping and inventory validation are enforced
  server-side. Never trust client events.
- `resmon` stays low: node scanning is throttled, props are streamed by distance.
- Restart the resource after changing market NPC, blip or model settings; node
  placement does **not** require a restart.

---

## Changelog

### 1.1.0

- Admin access is ACE-first: `group.admin` / `command`, with framework group fallback; config identifier lists and `/farmace` removed
- Server admin commands use `lib.addCommand` (`/farmadmin`, `/farmplace`)
- Client reads use the ox_lib `cache` (`cache.ped`)
- Harvest nodes are scanned only when the player moves (200 ms throttle); the nearest marker and its options are cached (100 ms / 500 ms)
- New `Config.SkillCheck.engine` option: `custom` or `ox` (`lib.skillCheck`), switchable in `/farmadmin → Harvest → Skill Check Engine`
- New world-anchored marker flow: diamond morphs into an E card, hover sell card at the NPC, nearest-only rendering
- Harvest UI merged with the skill check, crop-colored border and fading separator; harvest charge counter (`Harvest 3/3`) and exhaustion warning
- Canceled harvests now consume a charge
- Economy: fresh-market baseline calibration, `simulationAffectsPrice`, stock decay, anti-dump payout option, baseline-aware reset
- Market tick can be forced from `/farmadmin → Tools → Run Tick Now`; `/ddev_economy_tick` removed
- New price trend arrows (green/red/gray) based on the previous price
- Player panel renamed to `/farmpanel`; admin-style layout, save button, notification/sound switches under Lifetime
- Recent Sales grouped by crop (4 × 2 entries) with precise average unit price
- `/farmadmin` fully restyled: tabs, switches, dropdowns, Tools/Setup pages, inline Discord link
- `/farmplace` placement tools and the interaction hint restyled to the same theme
- 6-language UI reviewed, labels use Title Case

### 1.0.0

- Initial public release

---

## Contributing

Issues and pull requests are welcome. If you translate a string or find a bug, open an
issue with the resource version, your framework (QBX / QB / ESX) and the exact console
error.

---

## License

Free to use, modify and run on your own server. The source is public so that it can be
audited — that is a requirement for free releases on the Cfx.re forum.

You may **not** resell this resource, re-upload it as your own work, or ship it inside a
paid package. If you redistribute a modified version, keep this credit and link back to
the original repository.

Third-party prop assets (BzZz Addon Props) are **not** included and remain under their
author's terms.
