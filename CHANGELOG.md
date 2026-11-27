# JunkMate

## 0.15.1

- **The junk-to-sell line on screen is back, as an option** (off unless you switch it on): "Show the junk-to-sell line on screen" under *At a vendor*, or `/junkmate junkbanner`. It says what your junk is worth and names the nearest vendor; click it for a map pin, drag it to move it, and `/junkmate junkbanner reset` puts it back. The coin on the minimap button shows junk either way.

## 0.15.0

- **The options window is in two columns under headings** (At a vendor, Worn gear, Bags, Tooltips and minimap), about half as tall, so it fits small screens like the Legion Go.
- **The worn-gear line on screen has its own switch** ("Show the worn-gear line on screen", or `/junkmate banner`). With it off, the hammer on the minimap button and the chat line still warn you.
- **Moving it:** hover the line for how; drag it anywhere and it stays there. `/junkmate banner reset` puts it back at the top of the screen.

## 0.14.2

- **No more "Junk to sell" banner on screen:** the gold coin on the minimap button says it instead. Hover the button for what the junk is worth and the nearest vendor you've used; **right-click** it for a map pin on that vendor. Known vendors still say on their tooltip that they'll buy your junk.

## 0.14.1

- **A gold coin on the minimap button** while you carry junk JunkMate would sell, in the bottom-right corner (the hammer for worn gear stays bottom-left, the bag count top-right). Hover the button to see how many items and what they're worth.

## 0.14.0

Finding a vendor whenever you have junk to sell, the way 0.13.0 finds a repairer:

- **A line on screen** while you carry anything JunkMate would sell (grey items, plus outgrown food and gear you can't use if that's switched on) says what it's worth and names the nearest vendor you've used, with the distance kept up to date: *"Junk to sell: 6 items (1s 20c)  Nearest vendor: Mike Miller, 120 yd"*. Click it for a map pin and the arrow; drag it to move it. It goes away at a vendor, and once there's nothing left to sell.
- **Known vendors say so:** their tooltip says *"JunkMate: buys your junk (6 items, 1s 20c)"*, and targeting one says so in chat (once a minute at most).
- JunkMate now remembers every vendor whose shop you open, not just repairers. `/junkmate vendor` names the nearest one and pins it. Switch it all off in the options ("Point to a vendor when you have junk").

## 0.13.0

Finding a repairer while your gear is worn:

- **Minimap repair tracking:** while your gear is worn, JunkMate switches on the minimap's own "Repair" tracking (where the game has it), so repairers show on the minimap, and switches it off again once you've repaired. If you had it on yourself, it's left on.
- **The nearest repairer you've used:** JunkMate remembers every vendor who repairs when you open their shop. While your gear is worn, the worn-gear line names the nearest one, with the distance kept up to date as you move: *"Gear worn: 20% left  Nearest repair: William MacGregor, 180 yd"*. Click the line for a map pin and the arrow to them (drag it to move it, as before). `/junkmate repairer` does the same.
- **Known repairers say so:** their tooltip says *"JunkMate: repairs here"* (with your gear's condition while it's worn), and targeting one while your gear is worn says so in chat.
- The game doesn't tell addons which NPCs repair, so the last two only know repairers you've opened a shop with. Both can be switched off in the options.

## 0.12.0

- **The make-room window says why it picked that item,** and what would go next. JunkMate offers grey items first, then food and drink you have outgrown, then gear that is no upgrade, cheapest first; now it says so for the item on offer:
  - *"Why this one: it's grey junk; the cheapest of 4 grey items."*
  - *"Why this one: with no grey items to offer, it's food you've outgrown (level 5; you also carry level 15)."*
  - *"...it's no upgrade (item level 5; what you wear there is 12)"* or *"...your class can't use mail."*
  - *"Next in line: Torn Pelt (worth 50c)."*

## 0.11.0

- **Opens clams and other "Right Click to Open" items** when your bags get down to the warning level, before warning you. Nine clams become one stack of clam meat and the odd pearl, which frees several slots. One at a time, taking what's inside each (even with auto loot off), and chat says how many slots it freed. Type `/junkmate open` to do it now.
- Never in a fight, never while you're looting something else, and never with a vendor, bank, mailbox, trade or auction window open, where "opening" an item would sell, bank, mail or trade it instead. It stops if one of those opens part way.
- Locked boxes are left alone, and it waits for one free bag slot so what's inside has somewhere to go.
- The tooltip line on things that open says JunkMate will open them when your bags get full. Switch it off in the options.

## 0.10.2

- **Quest rewards when your bags hold nothing junk:** handing in a quest with bags full of things JunkMate normally keeps used to stop at *"nothing in them is something JunkMate would throw away"*. Now, for a quest reward or a quest item only, it offers the cheapest everyday thing it normally keeps (potions, food and drink, or crafting materials), clearly marked *"Normally kept: a crafting material."* Quest items, profession tools, the hearthstone, your keep list, equipment sets and epics are still never offered.
- If there really is nothing it could offer, chat now says to clear your bags at a vendor or the bank first and come back.
- Ordinary loot never reaches into the things JunkMate normally keeps.

## 0.10.1

- The make-room window for a quest reward now also says: *"Or clear your bags at a vendor first and come back."* Closing it is always fine; nothing is destroyed until you press Destroy.

## 0.10.0

- **Quest rewards that won't fit:** when you hand in a quest and your bags are too full for the reward, JunkMate makes room the same way it does for loot: it restacks first, then offers to destroy the cheapest thing you don't need, one press at a time, until there's enough room.
  - If the quest window is still open, the quest is then handed in for you.
  - If the game has closed the quest window (it does when the hand-in fails), chat says to talk to the quest giver again.
  - If there's a reward to choose, JunkMate never chooses: it tells you there's room and you pick.
  - A reward that stacks onto one you already carry needs no room, so nothing is offered for it.

## 0.9.2

- The make-room window now shows what the loot is worth too, so you can compare at a glance: *"Destroy Patchwork Bracers (worth 14c)? To make room for Chunk of Boar Meat x2 (worth 8c)."* Quest items and other loot vendors won't buy show no price.

## 0.9.1

- **Several items that won't fit:** after JunkMate makes room for one item and loots it, it now looks at what's still on the corpse and offers again for the next item, instead of stopping after the first. If what's left isn't worth destroying anything for (a grey worth less than the cheapest thing JunkMate would throw away), chat says so once.

## 0.9.0

- **Sells more than junk:** at a vendor, after the grey items, JunkMate also sells food and drink you've outgrown and gear your class can't use, so you need to make room far less often. At most 12 a visit, so everything sold can still be bought back from the vendor's Buyback tab. Gear you can wear but isn't an upgrade is never sold, only offered when your bags are full. Switch it off in the options.
- **Keeps more of your gear safe:** never offered or sold now:
  - gear in an equipment set;
  - gear with a special effect ("Use:", "Equip:" or "Chance on hit:", such as Riding Gloves or a Carrot on a Stick);
  - gear with resistances;
  - bind-on-equip greens and better, which are worth more at the auction house.
- **Tooltips say what JunkMate does with an item.** Hover anything in your bags: *"JunkMate keeps this: a quest item"*, or *"JunkMate: sold at vendors; 1st to go if your bags fill (outgrown food or drink)"*. Switch it off in the options.

## 0.8.3

Fixes from a code review:

- **Never destroys more than it showed:** if a stack grows after it's offered (restacking topped it up, say), pressing Destroy now offers it again at its new size instead of destroying the bigger stack.
- **After a fight, the window waits a little longer before a press counts** (1.5 seconds), so pressing A to jump while it reappears can't destroy anything.
- Loot that won't go into bags that have room is tried once, not over and over.
- Selling junk one item at a time (only on clients without the game's own Sell All Junk) now checks each slot again before selling, so an item moved into that slot meanwhile is never sold.
- Bank tidying finds the bank's bags on clients that name them differently, and never mistakes your own reagent bag for a bank bag.
- The options window no longer redraws itself on every bag change while it's closed.
- `/junkmate room` no longer says your bags are full when they aren't.

## 0.8.2

- **Quest items in a fight:** if a quest item won't fit while you're fighting, the make-room window shows at once (titled "Make room for the quest item?") instead of waiting for the fight to end, and it skips restacking so it's quick. Click **Destroy** and the quest item is looted straight away, so you can grab it and run. Other loot still waits until the fight is over.
- **New key binding:** Key Bindings > AddOns > JunkMate > "Make room: destroy the offered item". It works mid-fight, when the controller's A button can't be borrowed, so bind it to a key or a controller button combination.
- Fixed: loot that didn't fit while JunkMate was busy restacking the bags was ignored. It's now looted as soon as the restack makes room.

## 0.8.1

- **The make-room window is out of your way:** it now opens on the left side of the screen, above the chat, instead of over the middle. Drag it anywhere and it stays there (`/junkmate room reset` puts it back).
- **In a fight it tucks itself away,** and comes back with the same offer once the fight is over. If your bags fill up mid-fight, it says so in chat and waits until the fight ends.

## 0.8.0

- **Tidies the bank.** When you open your bank, JunkMate puts its partial stacks together, then tops up the bank's partial stacks of crafting materials from your bags. For example, with 15 Linen Cloth in the bank and 7 in your bags, 5 go in to make 20 and 2 stay with you.
- Only crafting materials move from your bags to the bank, and only onto stacks already there: food, potions, ammo and reagents you carry are never taken, and nothing is put into an empty bank slot.
- Works with the bank's own slots and its bags (or bank tabs). Hold **Shift** while opening the bank to skip it, type `/junkmate bank` to run it again, or switch it off in the options.

## 0.7.0

- **Make room for loot.** When something won't fit in your bags, JunkMate first restacks them (that loses nothing). If that doesn't free a slot, a small window offers to destroy the cheapest thing you don't need, so the loot fits: grey items first, then food and drink you've outgrown, then gear that isn't an upgrade. **Nothing is destroyed until you press Destroy** (A on a controller). After that, the loot is picked up for you.
- **Never offered:** quest items, crafting materials, recipes, profession tools (skinning knife, mining pick, fishing poles, enchanting rods...), the hearthstone, soul shards and class reagents, keys, bags, ammo, potions and other consumables, gear that would be an upgrade for your class, anything epic, buff food, and the best food and drink you carry for your level.
- It only offers to make room for loot that's worth it: quest items, crafting materials, green or better, upgrades, or anything worth more than what would go.
- **Not this one** (X) offers the next item; **Keep always** (Y) means JunkMate never offers that item again (`/junkmate keep` lists them, `/junkmate keep clear` empties the list).
- **Restacks on its own** when your bags get down to the warning level, before warning you.
- New commands: `/junkmate room`, `/junkmate restack`, `/junkmate destroyed`. Both new features can be switched off in the options.

## 0.6.4

- **Controller:** when a fight starts, B goes straight back to its usual job, even with a JunkMate window open (it used to stay on closing the window until the fight ended). It closes the window again once the fight is over.

## 0.6.3

- **Worn gear has its own sign:** a pulsing blacksmith's hammer in the bottom-left corner of the minimap button, so it never looks like the bag warning (the yellow number, or the flashing red ! when full, top right). Both can show at once.

## 0.6.2

- The minimap button now shows **how many bag slots are left** (a yellow 3, 2, 1) while your bags are getting full, and a **flashing red !** once they are full. Worn gear still shows the flashing red ! too.

## 0.6.1

- **Controller:** the B button now closes the JunkMate window, like the X and Escape. While it is open, B closes it; once it is closed, B does whatever you have it set to again.

## 0.6.0

- **Bags nearly full warning:** when you are down to your last 4 bag slots, the ! on JunkMate's minimap button lights up yellow, and one line in chat says how many are left. Once the bags are completely full the ! turns red and chat says so once more. Both clear as soon as there is room again.
- The top of the options window now shows your bags' free slots under the gear's condition. Set the warning to 2, 4 or 8 free slots, or turn it off there or with `/junkmate bags`.
- Only ordinary bags count: a herb bag, mining bag or quiver holds just one kind of thing, so its free slots are left out.

## 0.5.0

- **Minimap button:** JunkMate now has its own button on the minimap rim. Click it to open the options; drag it to move it. Hide it with `/junkmate button` or in the options.
- **A red ! for worn gear:** while your gear is below the warning level, a red ! pulses on the minimap button. Click it and the top of the window says how worn your gear is and which piece ("Gear worn: 18% left on [Chestguard]. Time to repair."). With nothing worn it says your gear is fine.

## 0.4.1

- Forever's own tooltip already shows the sell price of the whole stack. For a stack, JunkMate now adds what one is worth ("Sell price each: 3c"), to compare items in stacks of different sizes.

## 0.4.0

- **Vendor price on item tooltips:** hover over an item to see what it sells for at a vendor, and for a stack what the whole stack is worth ("Vendor: 13c each, 20 for 2s 60c"). Items a vendor will not buy say so. If the game already shows its own sell price, JunkMate adds nothing. Turn it off with `/junkmate price` or in the options.

## 0.3.0

- **VendorMate is now JunkMate.** A Retail addon called VendorMate is already on CurseForge, so this one could not be listed there under that name. The slash command is now `/junkmate` (or `/jmate`), the folder is `JunkMate`, and the saved settings are `JunkMateDB`. Nothing else changes. Entries below this one use the old name.

## 0.2.0

- New: a warning when your gear is wearing out. A line appears on screen while your most worn piece is below 25% (or 10% or 50%, your choice), with one line in chat when it first drops below. Drag the on-screen line to move it. Turn it off with `/vendormate worn` or in the options.

## 0.1.0

- First version.
