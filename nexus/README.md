# NET War — 0.6.0 Beta

**Jack in from your apartment and fight a territorial war across the NET.**

> **This is a beta.** Everything described here is in the game and playable, but balance is still being tuned and some situations haven't been tested yet — most importantly, **removing the mod from a save that used it**. Back up your saves, and please report bugs and balance feedback in the Posts or Bugs tab.

NET War turns V's home computer into a netrunner's terminal. Open a full-screen world map of the NET, breach corporate and gang nodes floor by floor in a netrunning system inspired by the Cyberpunk RED tabletop rules, collect daemons, defend your territory and stay off Netwatch's radar.

Every breach action can be played as a **skill minigame** — where your attributes, Interface and cyberdeck change how each minigame plays — or as a classic **d10 roll**.

---

## Features

- **Full-screen NET map** of the world with 14 nodes, owned by Arasaka, Militech, Netwatch, Kang Tao, the Voodoo Boys, neutral networks — and two zones beyond the Blackwall.
- **Zoom levels:** World, Region and City. Every node has 3 regions, and every region has 2–3 sites you can breach to weaken the parent node before the big attack.
- **A living network:** factions attack each other and your nodes while you play. The network catches up with game time whenever you reconnect (up to 7 days).
- **Breaches as towers of floors:** passwords, files, Black ICE, daemon caches and a Control Node at the bottom. Lobby floors, forks, per-faction architecture styles and random modifiers (rotating passwords, cold chamber, dense fog, trace echo).
- **Seven skill minigames**, one for each action: Backdoor, Eye-Dee, Zap, Slide, ICE defense, Control and Scan.
- **Cyberpunk RED-style rules:** NET actions per turn from your Interface, ICE with Speed, Perception, Attack, Defense and REZ, special ICE effects, unsafe jack-outs.
- **Daemons:** programs found during breaches. Equip them and fire them mid-breach using your cyberdeck's real RAM. Duplicates fuse into higher rarities.
- **Defenses and intel:** build Password, Black ICE and Decoy layers on your nodes; scouting and breaching reveal enemy architectures.
- **NetWatch Bank:** your network earnings, with withdraw and deposit to V's wallet.
- **Netwatch trace:** push your luck and Netwatch strikes back, locking you out of the NET for 24 hours.
- **In-game tutorial** with a practice mode for every minigame.
- **English and Brazilian Portuguese**, following the game's on-screen text language.

---

## Requirements

| Mod | Required |
|---|---|
| Cyberpunk 2077 **2.31** | Yes (the version it was built and tested on) |
| [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380) | Yes |
| [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511) | Yes |
| [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780) | Yes |
| [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197) | Yes |
| [Cyber Engine Tweaks](https://www.nexusmods.com/cyberpunk2077/mods/107) | Only for the optional debug panel |

---

## Installation

**Vortex:** click *Mod Manager Download* and enable the mod.

**Manual:** extract the archive into your Cyberpunk 2077 folder (the one that contains `bin` and `r6`). You should end up with:

```
r6/scripts/NetWar/
r6/tweaks/NetWar/
archive/pc/mod/NetWar.archive
```

The optional **debug panel** goes to `bin/x64/plugins/cyber_engine_tweaks/mods/NetWarDebug/`.

> **Back up your saves** before installing or removing the mod. NET War stores its network state inside your save file.

---

## Getting started

1. Go to one of V's apartments and look at the computer. A **NetWar** option appears next to the usual interaction.
2. The full-screen map opens. The game stays paused while you're on it; **ESC** closes it.
3. Pick a node next to one of yours (you start with Night City) and press **JACK-IN**.
4. Go down the tower to the Control Node and take the node.
5. Open the **TUTORIAL** tab any time for a full explanation, and to practice each minigame without any risk.

---

## How it works

### The map
- Click a node to see its owner, control, floors, DV, ICE and reward.
- You can only breach nodes next to one of yours. Blackwall zones hide their floors and DV until scanned.
- **Scan** (costs 2 RAM) reveals hidden ICE and the node's architecture style.
- **Region** and **City** zoom show smaller nodes. Taking a region gives +15% control over its parent node and −1 DV when you breach it; a site gives +5%. A site requires its region to be yours.

### Bank, RAM, trace and Interface
- **NetWatch Bank:** files, rewards and daily income go here. Withdraw or deposit from the map. The bank pays for your defenses and is frozen during a Netwatch lockout.
- **RAM** is your cyberdeck's real memory (the same as the HUD). Scanning and daemons use it, and it recovers on its own.
- **Trace:** failures and ICE hits raise it; it drops over time. At 100%, Netwatch launches an offensive against your nodes and locks the NET for 24 hours.
- **Interface** is your netrunner level in the mod: 2 + INT/4 + cyberdeck rarity (+2 with the Militech Canto Mk.6) + node bonuses. It sets your NET actions per turn (2 to 5).

### The breach
- Each node is a tower. The first two floors (lobby) only hold passwords or files.
- Active passwords and Black ICE block the way down. Forks let you pick the right-hand path.
- **END TURN** refreshes your actions, but any active Black ICE on your floor attacks.
- Disconnecting with active ICE gives it one last attack. Losing all your session HP kicks you out, and you lose the daemons you collected in that breach. Getting kicked out inside the Blackwall hurts V for real.

### The minigames

Use the **CHECKS** button on the breach screen to switch between minigames and the d10 roll. The **YOUR NETRUNNER** panel always shows what's helping you.

| Action | Minigame | What helps |
|---|---|---|
| **Backdoor** (password) | **Buffer sequence:** pick codes alternating row and column to build the requested sequence inside your buffer. | Interface: shorter sequence · Technical Ability: bigger buffer · Intelligence: hints · Cyberdeck: time · Canto Mk.6: shows the true path in red · Worm daemon: hints on every step |
| **Eye-Dee** (file) | **Decode the header:** chain blocks where each one starts with the character the previous one ended with. Corrupted blocks lead to dead ends. | Interface: shorter chain · Intelligence: next block highlighted · Technical Ability: free errors · Cool 8+: clock waits for your first click · Cyberdeck: blocks already placed |
| **Zap** (attack ICE) | **Ring rhythm:** strike (click or SPACE) when the spinning marker is inside the zone. Red center = critical. | Reflexes: bigger zone · Cyberdeck/Canto: more laps · Blade daemon: second zone · Interface: more damage. ICE Defense and Speed work against you. |
| **Slide** (get past ICE) | **Scanner corridor:** advance one lane at a time (click or SPACE) without being touched by the sweeping beams. | Interface: fewer lanes · Cool: slower beams · Intelligence: narrower beams · Cyberdeck/Canto: time · Cloak/Ghost: beams blink. ICE Perception works against you. |
| **ICE defense** (end of turn) | **Reflex:** click the codes in order before the ICE strikes. Each mistake lets part of the blow through. | Reflexes: more time · Interface 10+: one fewer code · Body: less damage · Mirror daemon: blocks the attack outright |
| **Control** (control node) | **Power circuit:** rotate pieces to link the source to the core. | Interface: smaller grid · Technical Ability: pieces locked in place · Intelligence: path hints · Cyberdeck/Canto: time · Overload daemon: +6 s |
| **Scan** | **Sonar:** click (or SPACE) when the echo crosses the band. Missing everything still reveals the usual floors; a perfect run reveals the whole tower. | Reflexes: wider band · Interface/Cyberdeck: slower echo · Intelligence: lower goal · Canto Mk.6: +1 pulse |

### Daemons
- Found in daemon caches and as rewards for taking nodes. The AI Fragment only drops beyond the Blackwall.
- Equip them in the **DAEMONS** tab. In a breach, firing one is a free action that costs RAM.
- The effect is the same at every rarity; higher rarity only lowers the RAM cost. Two duplicates fuse into the next rarity.
- **Blade** (Zap +3 damage) · **Mirror** (negates one ICE hit) · **Worm** (easier passwords) · **Ghost** (zero trace on the floor) · **Overload** (+1 action) · **Anchor** (emergency disconnect instead of being kicked out) · **AI Fragment** (+3 Interface, but +2 trace per turn)

### Architectures and defenses
- Scanning a node reveals its architecture style. Breaching it records floors, depth and modifiers in the **ARCHITECTURES** tab. Intel goes stale when a node changes hands.
- Each of your nodes has 3 defense layers, paid from the bank: **Password** (+2 defense), **Black ICE** (+1, absorbs one attack) and **Decoy** (35% chance to divert an attack).

---

## Languages

The mod follows the game's **on-screen text language**: Brazilian Portuguese if the game is set to Portuguese, English for every other language. Switching the language in the game's settings switches the mod too. Older log entries keep the language they were written in. The optional CET debug panel is in Portuguese.

---

## Optional: debug panel (Cyber Engine Tweaks)

An optional CET window (opens with the CET overlay) to inspect the network, trigger breach actions, register any computer as an access point and adjust the simulation. It's meant for testing and is not needed to play.

---

## Compatibility

- Built and tested on game version **2.31**.
- The map screen reuses the game's arcade menu scene to get a flat, full-screen view. Arcade machines keep working normally.
- It adds an option to computers inside V's apartments. Other mods that change those computers should be compatible, but this hasn't been tested with every mod.

---

## Credits

- Netrunning rules inspired by **Cyberpunk RED** by R. Talsorian Games. The ICE names, stats and minigames are original to this mod.
- Built with **redscript**, **RED4ext**, **Codeware** and **TweakXL**. Thanks to their authors and to the CDPR modding community documentation.
- Cyberpunk 2077 is a trademark of CD PROJEKT S.A. This is a fan-made mod, not affiliated with CD PROJEKT RED or R. Talsorian Games.
