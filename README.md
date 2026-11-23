# JunkMate

Sells your junk and repairs your gear whenever you open a vendor. An addon for World of Warcraft: Forever (client 1.60.x).

Formerly called VendorMate. It was renamed in 0.3.0 because a Retail addon called VendorMate is already on CurseForge. Type `/junkmate` now.

## What it does

Every time you open a vendor window, JunkMate:

- **sells the junk** in your bags (the grey items the game's own "Sell All Junk" button would sell), and
- **repairs your gear**, if the vendor can and you can afford it,

then tells you in chat what that earned and cost, for example:

> Sold 7 junk items for 12s 50c. Repaired for 34s.

Hold **Shift** while opening a vendor to skip both that time.

It also **warns you when your gear is wearing out**. While your most worn piece is below 25% durability, a line stays on screen ("Gear worn: 18% left"), with one line in chat when it first drops below. It clears once you repair. A blacksmith's hammer also pulses on JunkMate's minimap button; click it and the top of the window names the worn piece. You can drag the line to wherever you like, and set the level to 10%, 25% or 50%.

It also **warns you when your bags are nearly full**. Down to your last 4 slots, the minimap button shows how many are left (a yellow number) and chat says so; once the bags are full it shows a flashing red **!**. Set it to 2, 4 or 8 free slots. Only ordinary bags count, not herb, mining or other special bags.

**Vendor prices on tooltips:** hover over any item to see what it sells for at a vendor, and for a stack what the whole stack is worth ("Vendor: 13c each, 20 for 2s 60c"). Items a vendor will not buy say so. Handy for deciding what to vendor, auction or mail to your bank alt. Forever's own tooltip already shows the sell price of the whole stack; there JunkMate adds only what one is worth ("Sell price each: 3c"), for stacks.

## Options

Type `/junkmate` (or `/jmate`) to open the options, click JunkMate's minimap button (drag it to move it), or use the addon's entry in the minimap's addon list. The top of the window always shows your gear's condition and your bags' free slots.

| Setting | Command |
|---|---|
| Sell junk when a vendor opens | `/junkmate junk` |
| Repair when a vendor who can opens | `/junkmate repair` |
| Say in chat what was sold and repaired | `/junkmate report` |
| Warn on screen when gear is wearing out | `/junkmate worn` |
| Warn when your bags are nearly full | `/junkmate bags` |
| Vendor prices on item tooltips | `/junkmate price` |
| Show the minimap button | `/junkmate button` |

## Good to know

- Only junk is sold: grey items. Nothing white or better is ever touched.
- A mistaken sale can be bought back from the vendor's Buyback tab, as usual.
- Repairs are paid from your own money, never a guild bank.

## Controller

With a game controller, the **B** button closes the JunkMate window, like the X and Escape do. While a window is open, B closes it; once it is closed, B goes back to whatever you have it set to. When a fight starts, B goes straight back to its usual job, even with the window open.

## More from this author

Other small addons for World of Warcraft: Forever, all free:

- **[GatherLog](https://www.curseforge.com/wow/addons/gatherlog)** remembers ore, herbs, fishing pools, skinning spots, chests and rares across all your characters, and guides you back to the best spots.
- **[MouseTip](https://www.curseforge.com/wow/addons/mousetip)** shows tooltips at your mouse cursor.
- **[RangeShade](https://www.curseforge.com/wow/addons/rangeshade)** shades action buttons red when your target is out of range.
- **[AltGlance](https://www.curseforge.com/wow/addons/altglance)** shows all your characters at a glance: level, gold, rested and where you left them.
- **[SwiftQuest](https://www.curseforge.com/wow/addons/swiftquest)** accepts quests and hands them in as soon as you talk to the quest giver, without ever choosing a reward for you.
- **[SessionRecap](https://www.curseforge.com/wow/addons/sessionrecap)** keeps a running tally of your play session: gold, experience per hour, quests, gathering and loot.
- **[MacroKit](https://www.curseforge.com/wow/addons/macrokit)** adds ready-made macros for your class and spec, for all nine classes, and never overwrites your own.
- **[ZoomPad](https://www.curseforge.com/wow/addons/zoompad)** puts big + and - buttons on screen that zoom the camera, made for the Steam Deck touchscreen.
- **[GamepadMacros](https://www.curseforge.com/wow/addons/gamepadmacros)** adds ready-made macros for controller and Steam Deck players: heal yourself, use a quest item, save and wear gear, leave a group, emotes.
- **[FDR - Flight Data Recorder](https://www.curseforge.com/wow/addons/fdr-flight-data-recorder)** times every flight-master flight and counts your next one down to landing.

## Installing

Install it from [CurseForge](https://www.curseforge.com/wow/addons/junkmate) with the CurseForge app, or by hand: copy this folder into `World of Warcraft\_forever_\Interface\AddOns\` as `JunkMate`, restart the game, and enable JunkMate on the character select screen.

## Developing

- `tools\Link-Addon.ps1` links this folder into the game's AddOns folder, so edits are live after `/reload`.
- `python tests/run.py` runs the tests (`pip install lupa` once). They run the addon in real Lua 5.1 against a fake of the game's API.
- `tools\Publish.ps1 -Message "..."` runs the tests and pushes to GitHub. GitHub runs the tests again on every push.

## Releasing

`tools\Publish.ps1 -Message "Release x.y.z" -Tag vx.y.z` publishes and tags. The tag makes GitHub package the addon and attach the zip to a GitHub release.

To also upload to CurseForge and Wago, two things are needed once:

1. Create the project on each site, then add its ID to `JunkMate.toc`:
   `## X-Curse-Project-ID: 123456` and `## X-Wago-ID: abc123`.
2. Create an upload token on each site and add it to this repository's secrets (Settings, Secrets and variables, Actions) as `CF_API_KEY` and `WAGO_API_TOKEN`.

Before each release: raise `## Version:` in `JunkMate.toc` and add the version to `CHANGELOG.md`.

## Licence

MIT. See `LICENSE`.
