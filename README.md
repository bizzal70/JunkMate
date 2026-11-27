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

**Makes room for loot.** When something won't fit in your bags, JunkMate first **restacks** them, putting partial stacks together, which loses nothing. If that doesn't free a slot, a small window offers to destroy the cheapest thing you don't need, so the loot fits:

> Destroy [Broken Fang] (worth 5c)? To make room for [Green Bracers].

The window opens on the left of the screen, above the chat, so it never covers the middle; drag it wherever you like. During a fight it stays hidden and comes back once the fight is over, except for **quest items**: if one won't fit mid-fight, the window shows at once so you can grab it and run. In a fight the controller's A button can't be borrowed, so click Destroy, or set the key binding (Key Bindings > AddOns > JunkMate > "Make room: destroy the offered item").

**Nothing is ever destroyed until you press Destroy.** Then the loot is picked up for you. Press **Not this one** to see the next choice, or **Keep always** so JunkMate never offers that item again.

- **What it offers, in order:** grey items first, then food and drink you've outgrown, then gear that isn't an upgrade for your class (wrong armour type, or a lower item level than what you wear), cheapest first.
- **What it never offers:** quest items, crafting materials, recipes, profession tools (skinning knife, mining pick, fishing poles, enchanting rods and so on), the hearthstone, soul shards and class reagents, keys, bags, ammo, potions and other consumables, gear that would be an upgrade, anything epic, buff food ("well fed"), and the **best food and drink you carry for your level**. So only the old stacks of apples and bread go, never what you'd actually eat.
- **Worth it or not:** it only makes room for quest items, crafting materials, anything green or better, upgrades, or loot worth more than what would go. A 1-copper pebble won't cost you anything.

JunkMate also **restacks on its own** when your bags get down to the warning level, before warning you.

**Tidies the bank.** When you open your bank, JunkMate puts the bank's partial stacks together, then tops up its partial stacks of crafting materials from your bags (15 Linen Cloth in the bank and 7 in your bags: 5 go in to make 20, and 2 stay with you), and says in chat what it did. Only crafting materials move, and only onto stacks already in the bank, so the food, potions, ammo and reagents you carry stay with you and nothing lands in an empty bank slot. Hold **Shift** while opening the bank to skip it.

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
| Offer to make room when loot won't fit | (options window) |
| Restack when bags get nearly full | (options window) |
| Tidy the bank when it opens | (options window), or `/junkmate bank` to run it now |

Also: `/junkmate room` (make room now, without loot), `/junkmate restack` (restack now), `/junkmate keep` (what it never offers; `/junkmate keep clear` empties it) and `/junkmate destroyed` (what was destroyed this session).

## Good to know

- Only junk is sold: grey items. Nothing white or better is ever sold.
- A destroyed item is gone for good. That is why JunkMate never destroys anything without you pressing the button, and says in chat what went.
- A mistaken sale can be bought back from the vendor's Buyback tab, as usual.
- Repairs are paid from your own money, never a guild bank.

## Controller

With a game controller, the **B** button closes the JunkMate window, like the X and Escape do. In the make-room window, **A** destroys, **X** shows the next choice and **Y** keeps the item always. While a window is open, B closes it; once it is closed, B goes back to whatever you have it set to. When a fight starts, B goes straight back to its usual job, even with the window open.

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
