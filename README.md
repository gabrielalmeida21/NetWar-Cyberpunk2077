# NET War — Cyberpunk 2077 mod (0.6.0 Beta)

**Jack in from your apartment and fight a territorial war across the NET.**

NET War turns V's home computer into a netrunner's terminal: a full-screen world map of the NET, breaches played floor by floor in a netrunning system inspired by the Cyberpunk RED tabletop rules, seven skill-based minigames, daemons, node defenses and a living network where factions fight while you play.

- **Players:** see [`nexus/README.md`](nexus/README.md) for the full feature list, requirements, installation and how to play.
- **Download:** grab the release zip and extract it into your game folder (see below).

> **Beta:** balance is still being tuned and removing the mod from a save that used it hasn't been tested yet. Back up your saves.

---

## Requirements

Cyberpunk 2077 **2.31**, [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380), [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511), [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) and [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197). [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) only for the optional debug panel.

## Repository layout

| Path | What it is |
|---|---|
| `r6/scripts/NetWar/` | The mod, in redscript. `Core/` state, save and public API · `Data/` factions, nodes, ICE, daemons, texts · `Sim/` territory simulation · `Breach/` breach session, architecture generator and the minigame rules · `Access/` the computer interaction · `UI/` all screens (ink widgets built in code) |
| `r6/tweaks/NetWar/` | TweakXL record for the "NetWar" computer interaction |
| `archive/source/` | Source of the map texture atlas (`.inkatlas` as WolvenKit JSON) |
| `bin/x64/plugins/cyber_engine_tweaks/mods/NetWarDebug/` | Optional CET debug panel (Portuguese) |
| `tools/` | Build scripts (see below) |
| `nexus/` | Player-facing README and the Nexus description (BBCode, generated from the README) |

Design notes: the core (`Core`, `Data`, `Sim`, `Breach`) never depends on the UI; screens only read state and call `NetWarSystem`'s public API. Save data is kept in `persistent` fields of simple types, and nodes are identified by fixed numeric codes. Every visible text goes through `NWL.T(pt, en)`, which follows the game's on-screen text language.

## Building from source (Windows)

All scripts default to `D:\SteamLibrary\steamapps\common\Cyberpunk 2077`; pass `-GamePath` or set `CP2077_PATH` for another location. Script comments are in Portuguese.

1. **Map texture** (only if you change the map):
   ```
   cd tools/gen-map
   npm install
   node gen-map.mjs
   ```
   Writes `tools/gen-map/out/netwar_map.png` and regenerates `r6/scripts/NetWar/UI/MapDots.reds` (the fallback dot grid).
2. **Archive:** put the [WolvenKit](https://github.com/WolvenKit/WolvenKit) CLI in `.tools/wolvenkit/`, then run `.\tools\build-archive.ps1`. It produces `archive/packed/archive/pc/mod/NetWar.archive`.
3. **Compile check:** `.\tools\check-scripts.ps1` compiles the scripts together with Codeware and TweakXL in a temporary folder, without touching the game's script cache.
4. **Install locally:** `.\deploy.ps1` mirrors the mod folders into the game (`.\deploy.ps1 -Remove` removes them).
5. **Release zips:** `.\tools\package.ps1` builds `dist/NetWar-<version>-beta.zip` and `dist/NetWar-DebugPanel-<version>-beta.zip` and regenerates `nexus/description.bbcode`.

## Credits

- Netrunning rules inspired by **Cyberpunk RED** by R. Talsorian Games. The ICE names, stats and minigames are original to this mod.
- Built with **redscript**, **RED4ext**, **Codeware** and **TweakXL**; map texture packed with **WolvenKit**. World map data from **Natural Earth** (public domain) via `world-atlas`.
- Cyberpunk 2077 is a trademark of CD PROJEKT S.A. This is a fan-made mod, not affiliated with CD PROJEKT RED or R. Talsorian Games.

## License

[MIT](LICENSE) © 2026 Gabriel Almeida Silva
