# JunkMate

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
