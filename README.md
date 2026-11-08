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

It also **warns you when your gear is wearing out**. While your most worn piece is below 25% durability, a line stays on screen ("Gear worn: 18% left"), with one line in chat when it first drops below. It clears once you repair. You can drag the line to wherever you like, and set the level to 10%, 25% or 50%.

## Options

Type `/junkmate` to open the options, or use the addon's entry in the minimap's addon list.

| Setting | Command |
|---|---|
| Sell junk when a vendor opens | `/junkmate junk` |
| Repair when a vendor who can opens | `/junkmate repair` |
| Say in chat what was sold and repaired | `/junkmate report` |
| Warn on screen when gear is wearing out | `/junkmate worn` |

## Good to know

- Only junk is sold: grey items. Nothing white or better is ever touched.
- A mistaken sale can be bought back from the vendor's Buyback tab, as usual.
- Repairs are paid from your own money, never a guild bank.

## More from this author

Other small addons for World of Warcraft: Forever, all free:

- **[GatherLog](https://github.com/bizzal70/GatherLog)** remembers ore, herbs, fishing pools, skinning spots, chests and rares across all your characters, and guides you back to the best spots.
- **[MouseTip](https://www.curseforge.com/wow/addons/mousetip)** shows tooltips at your mouse cursor.
- **[RangeShade](https://www.curseforge.com/wow/addons/rangeshade)** shades action buttons red when your target is out of range.
- **[AltGlance](https://github.com/bizzal70/AltGlance)** shows all your characters at a glance: level, gold, rested and where you left them.
- **[SwiftQuest](https://github.com/bizzal70/SwiftQuest)** accepts quests and hands them in as soon as you talk to the quest giver, without ever choosing a reward for you.
- **[SessionRecap](https://github.com/bizzal70/SessionRecap)** keeps a running tally of your play session: gold, experience per hour, quests, gathering and loot.
- **[MacroKit](https://github.com/bizzal70/MacroKit)** adds ready-made macros for your class and spec, for all nine classes, and never overwrites your own.
- **[ZoomPad](https://github.com/bizzal70/ZoomPad)** puts big + and - buttons on screen that zoom the camera, made for the Steam Deck touchscreen.

## Installing

Install it from [CurseForge](https://www.curseforge.com/wow/addons/junkmate) (once approved) with the CurseForge app, or by hand: copy this folder into `World of Warcraft\_forever_\Interface\AddOns\` as `JunkMate`, restart the game, and enable JunkMate on the character select screen.

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
