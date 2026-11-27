-- The game's side: a purse, a vendor, and bags.
MONEY = 50000
SHIFT = false
CAN_REPAIR, REPAIR_COST = true, 0
REPAIRS = 0
JUNK = 0            -- how many junk items the game says are in the bags
JUNK_VALUE = 0      -- what they are worth altogether
SELL_ENABLED = true
SELL_CALLS = 0
GetMoney = function() return MONEY end
IsShiftKeyDown = function() return SHIFT end
CanMerchantRepair = function() return CAN_REPAIR end
GetRepairAllCost = function() return REPAIR_COST, REPAIR_COST > 0 end
RepairAllItems = function() REPAIRS = REPAIRS + 1; MONEY = MONEY - REPAIR_COST; REPAIR_COST = 0 end
C_MerchantFrame = {
    IsSellAllJunkEnabled = function() return SELL_ENABLED end,
    GetNumJunkItems = function() return JUNK end,
    -- Like the real game, the money arrives after the call returns.
    SellAllJunkItems = function() SELL_CALLS = SELL_CALLS + 1; PENDING = JUNK_VALUE; JUNK, JUNK_VALUE = 0, 0 end,
}
PENDING = 0
-- bag -> list of { quality =, hasNoValue =, isLocked = }
BAGS = { [0] = {}, {}, {}, {}, {} }
USED = {}
C_Container = {
    GetContainerNumSlots = function(bag) return #BAGS[bag] end,
    GetContainerItemInfo = function(bag, slot) return BAGS[bag][slot] end,
    UseContainerItem = function(bag, slot) USED[#USED + 1] = bag .. ":" .. slot end,
}

-- slot -> { current, maximum } durability; a slot left out has none
GEAR = {}
GetInventoryItemDurability = function(slot) local g = GEAR[slot]; if g then return g[1], g[2] end end
GetInventoryItemLink = function(_, slot) if slot == 5 then return "[Chestguard]" end end

local ns = LoadAddon(ADDON_DIR, "JunkMate")
local function check(cond, what) if not cond then error("CHECK FAILED: " .. what, 2) end; io.write("pass  ", what, "\n") end
-- Opens a vendor, lets the money from selling arrive, then runs the delayed report.
local function visit()
    local printedBefore = #PRINTED
    Fire("MERCHANT_SHOW")
    MONEY = MONEY + PENDING; PENDING = 0
    local timers = AFTERS; AFTERS = {}
    for _, fn in ipairs(timers) do fn() end
    Fire("MERCHANT_CLOSED")
    local said = {}
    for i = printedBefore + 1, #PRINTED do said[#said + 1] = PRINTED[i] end
    return table.concat(said, " | ")
end

check(ns.Money(12345) == "1g 23s 45c" and ns.Money(500) == "5s" and ns.Money(0) == "0c" and ns.Money(10007) == "1g 7c", "money is written as gold, silver and copper")

Fire("MERCHANT_SHOW")
check(SELL_CALLS == 0 and REPAIRS == 0, "before its settings load, the addon does nothing at a vendor")
Fire("ADDON_LOADED", "JunkMate")
check(ns.db.sellJunk and ns.db.repair and ns.db.report, "settings start with selling, repairing and reporting on")

local said = visit()
check(SELL_CALLS == 0 and REPAIRS == 0 and said == "", "with nothing to sell or repair, it does and says nothing")

JUNK, JUNK_VALUE = 3, 1250
said = visit()
check(SELL_CALLS == 1 and MONEY == 51250, "junk is sold when a vendor opens")
check(said:find("Sold 3 junk items for 12s 50c.", 1, true) ~= nil, "and it says what the junk earned: " .. said)

REPAIR_COST = 3400
said = visit()
check(REPAIRS == 1 and MONEY == 47850 and said:find("Repaired for 34s.", 1, true) ~= nil, "gear is repaired and the cost reported: " .. said)

JUNK, JUNK_VALUE, REPAIR_COST = 1, 80, 500
said = visit()
check(said:find("Sold 1 junk item for 80c.", 1, true) ~= nil and said:find("Repaired for 5s.", 1, true) ~= nil, "selling and repairing together are reported correctly: " .. said)

JUNK, JUNK_VALUE, REPAIR_COST = 2, 100, 700
SHIFT = true
said = visit()
check(SELL_CALLS == 2 and REPAIRS == 2 and said == "", "holding Shift skips both")
SHIFT = false

REPAIR_COST, MONEY = 999999, 1000
said = visit()
check(REPAIRS == 2 and said:find("more than you are carrying", 1, true) ~= nil, "repairs that cannot be afforded are not attempted, and it says so")
check(SELL_CALLS == 3, "but the junk is still sold")
REPAIR_COST, MONEY = 0, 50000

CAN_REPAIR, REPAIR_COST = false, 700
visit()
check(REPAIRS == 2, "a vendor who cannot repair is not asked to")
CAN_REPAIR, REPAIR_COST = true, 0

SlashCmdList.JUNKMATE("junk")
JUNK, JUNK_VALUE = 4, 400
visit()
check(SELL_CALLS == 3 and not ns.db.sellJunk, "/junkmate junk turns selling off")
SlashCmdList.JUNKMATE("junk")
SlashCmdList.JUNKMATE("repair")
REPAIR_COST = 300
visit()
check(REPAIRS == 2 and SELL_CALLS == 4, "/junkmate repair turns repairing off, and selling carries on")
SlashCmdList.JUNKMATE("repair"); REPAIR_COST = 0
SlashCmdList.JUNKMATE("report")
JUNK, JUNK_VALUE = 2, 200
said = visit()
check(SELL_CALLS == 5 and said == "", "/junkmate report turns the chat line off")
SlashCmdList.JUNKMATE("report")

SELL_ENABLED = false; JUNK = 2
visit()
check(SELL_CALLS == 5, "where the game has junk selling disabled, nothing is sold")
SELL_ENABLED = true; JUNK = 0

-- a client without the built-in: grey items with a value are sold one by one
local sellAll = C_MerchantFrame.SellAllJunkItems
C_MerchantFrame.SellAllJunkItems = nil
BAGS[0] = { { quality = 0 }, { quality = 1 }, { quality = 0, hasNoValue = true }, { quality = 0, isLocked = true } }
BAGS[2] = { { quality = 2 }, { quality = 0 } }
TICKERS = {}
Fire("MERCHANT_SHOW")
local ticker = TICKERS[1]
local fake = { Cancel = function(self) self.cancelled = true end }
for _ = 1, 5 do if not fake.cancelled then ticker(fake) end end
check(table.concat(USED, " ") == "0:1 2:2" and fake.cancelled, "without it, only grey items a vendor will pay for are sold, then it stops")
USED = {}; TICKERS = {}
Fire("MERCHANT_SHOW"); Fire("MERCHANT_CLOSED")
fake = { Cancel = function(self) self.cancelled = true end }
TICKERS[1](fake)
check(#USED == 0 and fake.cancelled, "closing the vendor stops the selling at once")
C_MerchantFrame.SellAllJunkItems = sellAll
BAGS[0], BAGS[2] = {}, {}
AFTERS = {}

-- the game misbehaving must not leave an error on screen
GetRepairAllCost = function() error("something this client does differently") end
local ok = pcall(Fire, "MERCHANT_SHOW")
check(ok and PRINTED[#PRINTED]:find("Something went wrong at this vendor", 1, true) ~= nil, "a surprise from the game is reported in chat, not as an error")
GetRepairAllCost = function() return REPAIR_COST, REPAIR_COST > 0 end
Fire("MERCHANT_CLOSED"); AFTERS = {}

-- worn gear
local notice = JunkMateDurabilityNotice
local label
for _, f in ipairs(Frames()) do
    if rawget(f, "__text") and f.__text:find("Gear worn", 1, true) then label = f end
end
Fire("PLAYER_LOGIN")
check(not notice.__shown and ns.db.durabilityWarn and ns.db.durabilityLevel == 25, "with no worn gear there is no warning")
GEAR = { [1] = { 60, 100 }, [5] = { 40, 100 }, [16] = { 90, 100 }, [4] = { 0, 0 } }
Fire("UPDATE_INVENTORY_DURABILITY")
check(not notice.__shown and ns.LowestDurability() == 40, "gear above the level raises no warning")
local printedBefore = #PRINTED
GEAR[5] = { 18, 100 }
Fire("UPDATE_INVENTORY_DURABILITY")
for _, f in ipairs(Frames()) do
    if rawget(f, "__text") and f.__text:find("Gear worn", 1, true) then label = f end
end
check(notice.__shown and label.__text == "Gear worn: 18% left", "the most worn piece dropping below the level shows a line on screen ")
check(#PRINTED == printedBefore + 1 and PRINTED[#PRINTED]:find("down to 18%", 1, true) ~= nil, "and says so once in chat")
check(ns.worn == 18 and ns.wornBadge.__shown and not ns.bagBadge.__shown and JunkMateMinimapButton.__shown, "and puts the hammer on the minimap button, not the bag sign")
check(ns.GearStatus():find("Gear worn: 18% left on [Chestguard]", 1, true) ~= nil, "the options say which piece is worn: " .. ns.GearStatus())
GEAR[5] = { 12, 100 }
Fire("UPDATE_INVENTORY_DURABILITY")
check(label.__text == "Gear worn: 12% left" and #PRINTED == printedBefore + 1, "as it wears further the line updates, without repeating in chat")
GEAR[5] = { 100, 100 }
Fire("MERCHANT_CLOSED")
check(not notice.__shown, "repairing clears the warning")
check(not ns.worn and not ns.wornBadge.__shown, "and the ! on the minimap button")
check(ns.GearStatus():find("Gear is fine: the most worn piece has 60%", 1, true) ~= nil, "the options then say the gear is fine: " .. ns.GearStatus())
GEAR[5] = { 20, 100 }
Fire("UPDATE_INVENTORY_DURABILITY")
check(notice.__shown and #PRINTED == printedBefore + 2, "and it warns afresh the next time")
SlashCmdList.JUNKMATE("worn")
check(not notice.__shown and not ns.db.durabilityWarn, "/junkmate worn turns the warning off")
SlashCmdList.JUNKMATE("worn")
check(notice.__shown, "and back on")
notice.__scripts.OnDragStart(notice); notice.__scripts.OnDragStop(notice)
check(ns.db.noticePosition ~= nil, "the on-screen line can be dragged, and remembers where")
GetInventoryItemDurability = function() error("something this client does differently") end
check(pcall(Fire, "UPDATE_INVENTORY_DURABILITY"), "a surprise from the game while checking gear does not raise an error")
GetInventoryItemDurability = function(slot) local g = GEAR[slot]; if g then return g[1], g[2] end end
GEAR = {}; Fire("UPDATE_INVENTORY_DURABILITY")

-- Bags nearly full. A bag's list holds { quality = } for an item, false for an empty slot.
local function Fill(bag, used, free)
    BAGS[bag] = {}
    for i = 1, used do BAGS[bag][i] = { quality = 1 } end
    for i = used + 1, used + free do BAGS[bag][i] = false end
end
check(ns.db.bagWarn and ns.db.bagLevel == 4, "the bags warning starts on, at 4 free slots")
Fill(0, 13, 3)
local before = #PRINTED
Fire("BAG_UPDATE_DELAYED")
check(ns.bagsLow == 3 and PRINTED[#PRINTED]:find("Only 3 bag slots left.", 1, true) ~= nil, "3 free slots warns in chat: " .. tostring(PRINTED[#PRINTED]))
check(ns.bagBadge.__shown and ns.badgeMark.__text == "3", "and the minimap button shows how many slots are left: " .. tostring(ns.badgeMark.__text))
Fire("BAG_UPDATE_DELAYED")
check(#PRINTED == before + 1, "it says so once, not on every change")
Fill(0, 16, 0)
Fire("BAG_UPDATE_DELAYED")
check(ns.bagsLow == 0 and PRINTED[#PRINTED]:find("bags are full", 1, true) ~= nil and #PRINTED == before + 2, "and once more when the bags are full")
check(ns.bagBadge.__shown and ns.badgeMark.__text == "!", "full bags turn the number into a flashing !")
check(select(1, ns.BagStatus()):find("Bags full: 0 of 16 slots free", 1, true) ~= nil, "the options say the bags are full: " .. ns.BagStatus())
Fill(0, 6, 10)
Fire("BAG_UPDATE_DELAYED")
check(ns.bagsLow == nil and not ns.bagBadge.__shown, "with room again the ! goes away")
check(select(1, ns.BagStatus()) == "Bags: 10 of 16 slots free.", "and the options show the free slots: " .. ns.BagStatus())
Fill(0, 14, 2)
Fire("BAG_UPDATE_DELAYED")
check(#PRINTED == before + 3, "and it warns afresh the next time")
-- The game's own count, where it has one; a herb bag's free slots do not count.
Fill(1, 0, 20)
C_Container.GetContainerNumFreeSlots = function(bag)
    local free = 0
    for _, item in ipairs(BAGS[bag]) do if not item then free = free + 1 end end
    return free, bag == 1 and 32 or 0
end
Fire("BAG_UPDATE_DELAYED")
check(ns.bagsLow == 2, "a herb bag's empty slots do not count as room")
SlashCmdList.JUNKMATE("bags")
check(not ns.db.bagWarn and ns.bagsLow == nil and not ns.bagBadge.__shown, "/junkmate bags turns the warning off")
SlashCmdList.JUNKMATE("bags")
check(ns.db.bagWarn and ns.bagsLow == 2, "and back on")
local numFree = C_Container.GetContainerNumFreeSlots
C_Container.GetContainerNumFreeSlots = function() error("something this client does differently") end
check(pcall(Fire, "BAG_UPDATE_DELAYED"), "a surprise from the game while checking bags does not raise an error")
C_Container.GetContainerNumFreeSlots = numFree
Fill(0, 2, 14); Fill(1, 0, 0)
Fire("BAG_UPDATE_DELAYED")

-- options window
SlashCmdList.JUNKMATE("")
check(JunkMateOptions:IsShown(), "/junkmate opens the options")
local rows = {}
for _, f in ipairs(Frames()) do
    if rawget(f, "Refresh") and f.__scripts.OnClick then rows[#rows + 1] = f end
end
check(#rows == 18, "the options have eighteen controls")
local statusLine
for _, f in ipairs(Frames()) do
    if rawget(f, "__text") and f.__text:find("^Gear") then statusLine = f end
end
check(statusLine ~= nil, "the options show the gear's condition: " .. (statusLine and statusLine.__text or "none"))
local bagLine
for _, f in ipairs(Frames()) do
    if rawget(f, "__text") and f.__text:find("^Bags") then bagLine = f end
end
check(bagLine ~= nil and bagLine.__text == "Bags: 14 of 16 slots free.", "and the bags' free slots: " .. (bagLine and bagLine.__text or "none"))
rows[7].__scripts.OnClick(rows[7])
check(ns.db.bagLevel == 8, "the bags row steps the slots up")
rows[7].__scripts.OnClick(rows[7]); rows[7].__scripts.OnClick(rows[7])
check(ns.db.bagLevel == 4, "and comes back round")
rows[6].__scripts.OnClick(rows[6])
check(not ns.db.bagWarn, "the bags switch turns it off")
rows[6].__scripts.OnClick(rows[6])
rows[9].__scripts.OnClick(rows[9])
check(not ns.db.minimapButton and not JunkMateMinimapButton.__shown, "the last row hides the minimap button")
SlashCmdList.JUNKMATE("button")
check(ns.db.minimapButton and JunkMateMinimapButton.__shown, "and /junkmate button shows it again")
JunkMateMinimapButton.__scripts.OnClick(JunkMateMinimapButton)
check(not JunkMateOptions:IsShown(), "clicking the minimap button toggles the options")
JunkMateMinimapButton.__scripts.OnClick(JunkMateMinimapButton)
check(JunkMateOptions:IsShown(), "and opens them again")
for index, key in ipairs({ "sellJunk", "repair", "report", "durabilityWarn" }) do
    rows[index].__scripts.OnClick(rows[index])
    local off = not ns.db[key]
    rows[index].__scripts.OnClick(rows[index])
    assert(off and ns.db[key], key)
end
check(true, "each switch turns its setting off and on")
rows[5].__scripts.OnClick(rows[5])
check(ns.db.durabilityLevel == 50, "the last steps the warning level up")
rows[5].__scripts.OnClick(rows[5]); rows[5].__scripts.OnClick(rows[5])
check(ns.db.durabilityLevel == 25, "and comes back round")
JunkMate_OnAddonCompartmentClick()
check(not JunkMateOptions:IsShown(), "the minimap addon list entry toggles the options")
SlashCmdList.JUNKMATE("help")

-- Vendor price on item tooltips.
local priceHook
ITEM_HOOKS = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, hook) if kind == "item" then ITEM_HOOKS[#ITEM_HOOKS + 1] = hook end end }
priceHook = function(...) for _, hook in ipairs(ITEM_HOOKS) do hook(...) end end
Enum.TooltipDataType = { Item = "item" }
Enum.TooltipDataLineType = { SellPrice = 11 }
local PRICES = { [2589] = 13, [6948] = 0 }
C_Item = C_Item or {}
C_Item.GetItemInfo = function(id)
    if PRICES[id] == nil then return nil end
    return "item", "link", 1, 5, 1, "Trade Goods", "Cloth", 20, "", 0, PRICES[id]
end
Fire("PLAYER_LOGIN")
local lines = {}
rawset(GameTooltip, "AddLine", function(_, text) lines[#lines + 1] = text end)
local owner = {}
rawset(GameTooltip, "GetOwner", function() return owner end)
local function Hover(id, count, data)
    lines = {}
    owner = { count = count }
    priceHook(GameTooltip, data or { id = id, lines = {} })
    return table.concat(lines, "|")
end
check(Hover(2589, 1) == "Vendor: 13c each", "a single item shows what it sells for")
check(Hover(2589, 20) == "Vendor: 13c each, 20 for 2s 60c", "a stack shows its whole worth too: " .. Hover(2589, 20))
check(Hover(6948, 1) == "Vendor: can't be sold", "an item vendors will not buy says so")
check(Hover(12345, 1) == "", "an item the game has not loaded yet adds nothing")
check(Hover(2589, 1, { id = 2589, lines = { { type = 11 } } }) == "", "if the game shows its own sell price, a single item gets nothing more")
check(Hover(2589, 8, { id = 2589, lines = { { type = 11 } } }) == "Sell price each: 13c", "and a stack gets the price of one under the game's stack price")
SlashCmdList.JUNKMATE("price")
check(Hover(2589, 1) == "" and not ns.db.priceTooltip, "/junkmate price turns it off")
SlashCmdList.JUNKMATE("price")
check(Hover(2589, 1) ~= "", "and on again")

-- The controller's B button closes the window while it is shown.
do
    local bound = {}
    SetOverrideBinding = function(owner, _, key, command) bound[owner] = { key = key, command = command } end
    ClearOverrideBindings = function(owner) bound[owner] = nil end
    local w = JunkMateOptions
    w:Show(); w.__scripts.OnShow(w)
    check(bound[w] and bound[w].key == "PAD2" and bound[w].command == "CLICK " .. w.padClose:GetName() .. ":LeftButton",
        "while the window is shown, the controller's B button is set to close it")
    w.padClose.__scripts.OnClick(w.padClose)
    check(not w:IsShown(), "pressing B closes it")
    w.__scripts.OnHide(w)
    check(bound[w] == nil, "and B gets its usual job back once it is closed")
    IN_COMBAT_SAVED = InCombatLockdown; InCombatLockdown = function() return true end
    w:Show(); w.__scripts.OnShow(w)
    check(bound[w] == nil, "bindings are not changed in combat")
    InCombatLockdown = IN_COMBAT_SAVED
    Fire("PLAYER_REGEN_ENABLED")
    check(bound[w] ~= nil, "but are once it ends")
    w:Hide(); w.__scripts.OnHide(w)
end

-- When a fight starts, B is handed back at once, even with the window open.
do
    local bound = {}
    SetOverrideBinding = function(owner, _, key) bound[owner] = key end
    ClearOverrideBindings = function(owner) bound[owner] = nil end
    local w = CreateFrame("Frame", "PadFightTestWindow", UIParent)
    w.HookScript = function(self, event, fn)
        local previous = self.__scripts[event]
        self.__scripts[event] = previous and function(...) previous(...); fn(...) end or fn
    end
    w.GetName = function() return "PadFightTestWindow" end
    w:Hide()
    ns.CloseWithPadB(w, "PadFightTestWindow")
    w:Show(); w.__scripts.OnShow(w)
    check(bound[w] == "PAD2", "with the window open, B closes it")
    Fire("PLAYER_REGEN_DISABLED")
    check(bound[w] == nil, "when a fight starts, B is handed back at once")
    Fire("PLAYER_REGEN_ENABLED")
    check(bound[w] == "PAD2", "and borrowed again once the fight is over")
    w:Hide(); w.__scripts.OnHide(w)
end

-- Restacking and making room for loot (Room.lua).
do
    -- Items: id -> { name, q(uality), ilvl, min(level), stack, loc, price, class, sub }
    ITEMS = {
        [2589] = { name = "Linen Cloth", q = 1, stack = 20, price = 13, class = 7, sub = 0 },
        [9001] = { name = "Broken Fang", q = 0, price = 5, class = 15, sub = 0 },
        [9002] = { name = "Torn Pelt", q = 0, price = 50, class = 15, sub = 0 },
        [7005] = { name = "Skinning Knife", q = 1, ilvl = 4, loc = "INVTYPE_WEAPONMAINHAND", price = 4, class = 2, sub = 15 },
        [9003] = { name = "Bandit Bandana", q = 1, price = 0, class = 12, sub = 0 },
        [9004] = { name = "Gnoll Paw", q = 1, price = 0, class = 15, sub = 0 },
        [6948] = { name = "Hearthstone", q = 1, price = 0, class = 15, sub = 0 },
        [9010] = { name = "Tough Jerky", q = 1, min = 5, stack = 20, price = 2, class = 0, sub = 5 },
        [9011] = { name = "Roasted Quail", q = 1, min = 15, stack = 20, price = 10, class = 0, sub = 5 },
        [9012] = { name = "Smoked Bear Meat", q = 1, min = 25, stack = 20, price = 12, class = 0, sub = 5 },
        [9013] = { name = "Spring Water", q = 1, min = 1, stack = 20, price = 1, class = 0, sub = 5 },
        [9014] = { name = "Crispy Bat Wing", q = 1, min = 1, stack = 20, price = 3, class = 0, sub = 5 },
        [858] = { name = "Lesser Healing Potion", q = 1, min = 3, stack = 5, price = 5, class = 0, sub = 1 },
        [9020] = { name = "Cloth Bracers", q = 2, ilvl = 20, loc = "INVTYPE_WRIST", price = 80, class = 4, sub = 1 },
        [9021] = { name = "Mail Chest", q = 2, ilvl = 25, loc = "INVTYPE_CHEST", price = 120, class = 4, sub = 3 },
        [9022] = { name = "Cloth Gloves", q = 1, ilvl = 5, loc = "INVTYPE_HAND", price = 10, class = 4, sub = 1 },
        [9023] = { name = "Epic Ring", q = 4, ilvl = 40, loc = "INVTYPE_FINGER", price = 900, class = 4, sub = 0 },
        [9030] = { name = "Worn Gloves", q = 1, ilvl = 12, loc = "INVTYPE_HAND", price = 8, class = 4, sub = 1 },
        [9040] = { name = "Green Bracers", q = 2, ilvl = 18, loc = "INVTYPE_WRIST", price = 60, class = 4, sub = 1 },
        [9041] = { name = "Shiny Pebble", q = 1, price = 1, class = 15, sub = 0 },
    }
    SPELLS = { [9010] = "Food", [9011] = "Food", [9012] = "Food", [9013] = "Drink", [9014] = "Food", [858] = "Healing Potion" }
    C_Item.GetItemInfo = function(item)
        local id = type(item) == "number" and item or tonumber(tostring(item):match("item:(%d+)") or "")
        local it = id and ITEMS[id]
        if not it then return nil end
        return it.name, "item:" .. id, it.q, it.ilvl or 1, it.min or 0, "type", "sub", it.stack or 1, it.loc or "", "icon",
            it.price or 0, it.class, it.sub
    end
    C_Item.GetItemSpell = function(id) return SPELLS[id] end
    C_TooltipInfo = { GetBagItem = function(bag, slot)
        local item = BAGS[bag][slot]
        if item and item.itemID == 9014 then
            return { lines = { { leftText = "Use: Restores 61 health over 18 sec. If you spend at least 10 seconds eating you will become well fed." } } }
        end
        return { lines = {} }
    end }
    C_Container.GetContainerItemQuestInfo = function(bag, slot)
        local item = BAGS[bag][slot]
        return { isQuestItem = item and item.itemID == 9004 or false }
    end
    UnitClass = function() return "Mage", "MAGE" end
    GetInventoryItemLink = function(_, slot) if slot == 10 then return "item:9030" end end

    -- The cursor, as the game has it.
    CURSOR, DELETED, LOOTED = nil, {}, {}
    C_Container.PickupContainerItem = function(bag, slot)
        local item = BAGS[bag][slot]
        if CURSOR then
            if not item then
                CURSOR.item.stackCount = CURSOR.count
                BAGS[bag][slot] = CURSOR.item
                CURSOR = nil
            elseif item.itemID == CURSOR.itemID then
                local add = math.min((ITEMS[item.itemID].stack or 1) - item.stackCount, CURSOR.count)
                item.stackCount, CURSOR.count = item.stackCount + add, CURSOR.count - add
                if CURSOR.count == 0 then CURSOR = nil end
            end
        elseif item then
            CURSOR = { itemID = item.itemID, count = item.stackCount, item = item, bag = bag, slot = slot }
            BAGS[bag][slot] = false
        end
    end
    C_Container.SplitContainerItem = function(bag, slot, count)
        local item = BAGS[bag][slot]
        local copy = {}
        for k, v in pairs(item) do copy[k] = v end
        CURSOR = { itemID = item.itemID, count = count, item = copy, bag = bag, slot = slot }
        item.stackCount = item.stackCount - count
        if item.stackCount == 0 then BAGS[bag][slot] = false end
    end
    CursorHasItem = function() return CURSOR ~= nil end
    GetCursorInfo = function() if CURSOR then return "item", CURSOR.itemID end end
    ClearCursor = function()
        if not CURSOR then return end
        local c = CURSOR
        CURSOR = nil
        local item = BAGS[c.bag][c.slot]
        if item then item.stackCount = item.stackCount + c.count
        else c.item.stackCount = c.count; BAGS[c.bag][c.slot] = c.item end
    end
    DeleteCursorItem = function() DELETED[#DELETED + 1] = CURSOR.itemID; CURSOR = nil end
    LootSlot = function(slot) LOOTED[#LOOTED + 1] = slot end
    LOOTS = {}
    GetNumLootItems = function() return #LOOTS end
    GetLootSlotInfo = function(slot) local l = LOOTS[slot]; return "icon", l.name, l.count or 1, nil, l.q, false, false, nil end
    GetLootSlotLink = function(slot) return LOOTS[slot].link end
    local tickers = {}
    C_Timer.NewTicker = function(_, fn)
        local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
        tickers[#tickers + 1] = t
        return t
    end
    local function RunTickers()
        for _, t in ipairs(tickers) do
            for _ = 1, 100 do if t.cancelled then break end; t.fn(t) end
        end
        tickers = {}
    end
    local function RunAfters()
        local timers = AFTERS; AFTERS = {}
        for _, fn in ipairs(timers) do fn() end
    end
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local function Bag(list, size)
        local bag = {}
        for i = 1, size do bag[i] = list[i] or false end
        return bag
    end
    local function Said() return PRINTED[#PRINTED] or "" end
    for bag = 1, 4 do BAGS[bag] = {} end

    -- Restacking by hand.
    BAGS[0] = Bag({ Item(2589, 7), Item(2589, 7), Item(2589, 15) }, 16)
    local moves, freed = ns.RestackPlan()
    check(#moves == 2 and freed == 1, "partial stacks of 7, 7 and 15 make a plan that frees a slot")
    SlashCmdList.JUNKMATE("restack")
    RunTickers()
    check(BAGS[0][3].stackCount == 20 and BAGS[0][1].stackCount == 9 and BAGS[0][2] == false and CURSOR == nil,
        "restacking tops up the fullest stack and empties the smallest")
    check(Said():find("Restacked your bags: 1 slot freed.", 1, true) ~= nil, "and says so: " .. Said())
    SlashCmdList.JUNKMATE("restack")
    check(Said():find("Nothing to restack", 1, true) ~= nil and #tickers == 0, "with nothing left to merge, it says so")

    -- Restacking on its own when the bags get nearly full.
    local list = {}
    for i = 1, 13 do list[i] = Item(9022) end
    list[14], list[15] = Item(2589, 3), Item(2589, 4)
    BAGS[0] = Bag(list, 16)
    local before = #PRINTED
    Fire("BAG_UPDATE_DELAYED")
    check(#PRINTED == before and #tickers == 1, "down to 1 free slot with stacks to merge, it restacks before warning")
    RunTickers()
    check(BAGS[0][15].stackCount == 7 and BAGS[0][14] == false, "the two linen stacks become one")
    check(PRINTED[before + 1]:find("1 slot freed", 1, true) ~= nil and Said():find("Only 2 bag slots left.", 1, true) ~= nil,
        "then says what it freed, and warns about what is left: " .. Said())
    ns.db.restack = false
    BAGS[0][14] = Item(2589, 3)
    NOW = NOW + 60
    Fire("BAG_UPDATE_DELAYED")
    check(#tickers == 0, "with restacking switched off, it does not")
    ns.db.restack = true

    -- What would be offered, and in what order.
    BAGS[0] = Bag({ Item(9021), Item(7005), Item(9003), Item(9004), Item(6948), Item(9010, 3), Item(9011, 4), Item(9012, 2),
        Item(9013, 5), Item(9014, 2), Item(858, 2), Item(9020), Item(9002), Item(9022), Item(9023), Item(9001) }, 16)
    local names = {}
    for _, item in ipairs(ns.RoomCandidates()) do names[#names + 1] = item.name end
    check(table.concat(names, ",") == "Broken Fang,Torn Pelt,Tough Jerky,Cloth Gloves,Mail Chest",
        "greys first, then outgrown food, then gear that is no upgrade, cheapest first: " .. table.concat(names, ","))
    check(true, "never offered: profession tools, quest items, the hearthstone, the best food and drink, buff food, potions, upgrades, epics")

    -- Loot that will not fit.
    LOOTS = { { link = "item:9040", name = "Green Bracers", q = 2 } }
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    local room = JunkMateRoom
    check(room:IsShown() and room.what:GetText():find("item:9001", 1, true) and room.why:GetText():find("item:9040", 1, true),
        "a green that will not fit brings up the window, offering the cheapest grey: " .. tostring(room.what:GetText()))
    room.destroy.__scripts.OnClick(room.destroy)
    check(#DELETED == 0, "a press straight away is ignored, so nothing unseen is destroyed")
    NOW = NOW + 1
    room.destroy.__scripts.OnClick(room.destroy)
    check(DELETED[1] == 9001 and BAGS[0][16] == false and not room:IsShown(), "pressing Destroy destroys it")
    check(Said():find("Destroyed item:9001 (worth 5c) to make room.", 1, true) ~= nil, "and says what went: " .. Said())
    room.__scripts.OnHide(room)
    Fire("BAG_UPDATE_DELAYED")
    check(LOOTED[1] == 1, "once the bags have room, the green is looted")

    -- Not this one, and keep always.
    BAGS[0][16] = Item(9001)
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    NOW = NOW + 1
    room.next.__scripts.OnClick(room.next)
    check(room.what:GetText():find("item:9002", 1, true) ~= nil, "Not this one offers the next cheapest")
    NOW = NOW + 1
    room.keep.__scripts.OnClick(room.keep)
    check(ns.db.keep[9002] and room.what:GetText():find("item:9010", 1, true) ~= nil, "Keep always remembers the item and moves on")
    SlashCmdList.JUNKMATE("keep")
    check(Said():find("Kept: item:9002", 1, true) ~= nil, "/junkmate keep lists it")
    SlashCmdList.JUNKMATE("keep clear")
    check(next(ns.db.keep) == nil, "/junkmate keep clear forgets them")
    Fire("LOOT_CLOSED")
    room.__scripts.OnHide(room)
    check(not room:IsShown(), "closing the loot window closes the offer")

    -- Loot not worth it.
    LOOTS = { { link = "item:9041", name = "Shiny Pebble", q = 1 } }
    before = #PRINTED
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(not room:IsShown() and Said():find("is worth less than item:9001", 1, true) ~= nil,
        "a white worth less than the cheapest candidate is left, and it says why: " .. Said())
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(#PRINTED == before + 1, "only once per loot window")
    Fire("LOOT_CLOSED")

    -- Safety.
    LOOTS = {}
    SlashCmdList.JUNKMATE("room")
    check(room:IsShown() and room.why:GetText() == "To free a bag slot.", "/junkmate room offers something just to free a slot")
    NOW = NOW + 1
    CURSOR = { itemID = 1, count = 1, item = {}, bag = 1, slot = 1 }
    room.destroy.__scripts.OnClick(room.destroy)
    check(#DELETED == 1 and Said():find("holding an item", 1, true) ~= nil, "nothing is destroyed while an item is in hand")
    CURSOR = nil
    DeleteCursorItem = function() end
    room.destroy.__scripts.OnClick(room.destroy)
    check(#DELETED == 1 and BAGS[0][16] and BAGS[0][16].itemID == 9001 and CURSOR == nil and Said():find("would not let", 1, true) ~= nil,
        "if the game refuses, the item goes back where it was")
    DeleteCursorItem = function() DELETED[#DELETED + 1] = CURSOR.itemID; CURSOR = nil end
    BAGS[0][16] = Item(9002)
    room.destroy.__scripts.OnClick(room.destroy)
    check(#DELETED == 1, "if the item moved, it is not destroyed; the offer is looked at again")

    -- Out of the way: not in the middle of the screen, and hidden in a fight.
    check(room.__point[1] == "LEFT" and room.__point[3] == "LEFT", "the window sits on the left, not over the middle of the screen")
    room.__scripts.OnDragStop(room)
    check(ns.db.roomPoint ~= nil, "it can be dragged, and remembers where")
    SlashCmdList.JUNKMATE("room reset")
    check(ns.db.roomPoint == nil and room.__point[1] == "LEFT", "/junkmate room reset puts it back")
    SlashCmdList.JUNKMATE("room")
    check(room:IsShown(), "(shown again)")
    Fire("PLAYER_REGEN_DISABLED")
    check(not room:IsShown(), "a fight starting tucks it away")
    room.__scripts.OnHide(room)
    Fire("PLAYER_REGEN_ENABLED")
    check(room:IsShown() and room.what:GetText() ~= nil, "and it comes back, still offering the same item, once the fight is over")
    room.destroy.__scripts.OnClick(room.destroy)
    check(#DELETED == 1, "with a fresh pause before a press counts")
    room:Hide(); room.__scripts.OnHide(room)
    Fire("PLAYER_REGEN_DISABLED")
    local said = #PRINTED
    SlashCmdList.JUNKMATE("room")
    check(not room:IsShown() and PRINTED[#PRINTED]:find("once the fight is over", 1, true) ~= nil, "bags full in a fight: it waits, and says so")
    Fire("PLAYER_REGEN_ENABLED")
    check(room:IsShown(), "then offers after the fight")
    room:Hide(); room.__scripts.OnHide(room)

    -- A quest item in a fight: offered at once, no restacking first.
    BAGS[0][15] = Item(2589, 3); BAGS[0][14] = Item(2589, 4)
    ITEMS[9050] = { name = "Gnoll Collar", q = 1, price = 0, class = 12, sub = 0 }
    LOOTS = { { link = "item:9050", name = "Gnoll Collar", q = 1 } }
    Fire("PLAYER_REGEN_DISABLED")
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(room:IsShown() and not ns.Restacking() and room.title:GetText():find("quest item", 1, true),
        "a quest item that will not fit, mid-fight: the window shows at once, without restacking first")
    check(room.why:GetText():find("item:9050", 1, true) ~= nil, "offering room for the quest item")
    local deleted = #DELETED
    NOW = NOW + 1
    JunkMate_DestroyOffered()
    check(#DELETED == deleted + 1 and not room:IsShown(), "the key binding destroys the offered item, even in a fight")
    room.__scripts.OnHide(room)
    Fire("BAG_UPDATE_DELAYED")
    check(LOOTED[#LOOTED] == 1, "and the quest item is looted")
    Fire("LOOT_CLOSED")
    BAGS[0][16] = Item(9001)
    BAGS[0][14] = Item(9002); BAGS[0][15] = Item(9022)
    Fire("PLAYER_REGEN_ENABLED")
    LOOTS = { { link = "item:9050", name = "Gnoll Collar", q = 1 } }
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    local looted = #LOOTED
    check(not room:IsShown() and ns.Restacking(), "(a restack was already under way)")
    RunTickers()
    RunAfters()
    check(not room:IsShown() and LOOTED[#LOOTED] == 1 and #LOOTED == looted + 1,
        "loot that will not fit while the bags are being restacked is looted once that has made room")
    for i = 1, 16 do if not BAGS[0][i] then BAGS[0][i] = Item(9022) end end
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(room:IsShown(), "(a quest-item offer, out of a fight)")
    Fire("PLAYER_REGEN_DISABLED")
    check(room:IsShown(), "a quest-item offer already open stays open when a fight starts")
    room:Hide(); room.__scripts.OnHide(room)
    Fire("PLAYER_REGEN_ENABLED")
    Fire("LOOT_CLOSED")
    LOOTS = {}

    -- Controller buttons while it is open.
    local bound = {}
    SetOverrideBinding = function(_, _, key, command) bound[key] = command end
    ClearOverrideBindings = function() bound = {} end
    room:Show(); room.__scripts.OnShow(room)
    check(bound.PAD1 == "CLICK JunkMateRoomDestroy:LeftButton" and bound.PAD3 == "CLICK JunkMateRoomNext:LeftButton"
        and bound.PAD4 == "CLICK JunkMateRoomKeep:LeftButton" and bound.PAD2 ~= nil, "A destroys, X skips, Y keeps and B closes")
    room:Hide(); room.__scripts.OnHide(room)
    check(next(bound) == nil, "and they go back once it closes")
    ns.db.makeRoom = false
    LOOTS = { { link = "item:9040", name = "Green Bracers", q = 2 } }
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(not room:IsShown(), "with the option off, nothing is offered")
    ns.db.makeRoom = true
end

-- At the bank (Bank.lua).
do
    ITEMS[2592] = { name = "Wool Cloth", q = 1, stack = 20, price = 33, class = 7, sub = 0 }
    local tickers = {}
    C_Timer.NewTicker = function(_, fn)
        local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
        tickers[#tickers + 1] = t
        return t
    end
    local function RunTickers(limit)
        local index = 1
        while tickers[index] do
            local t = tickers[index]
            for _ = 1, limit or 100 do if t.cancelled then break end; t.fn(t) end
            index = index + 1
        end
        tickers = {}
    end
    local function RunAfters()
        local timers = AFTERS; AFTERS = {}
        for _, fn in ipairs(timers) do fn() end
    end
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local function Bag(list, size)
        local bag = {}
        for i = 1, size do bag[i] = list[i] or false end
        return bag
    end
    local function Said() return PRINTED[#PRINTED] or "" end
    local function Setup()
        BAGS[-1] = Bag({ Item(2589, 15), Item(2589, 6), Item(2592, 20), Item(9010, 5) }, 24)
        for bag = 5, 11 do BAGS[bag] = {} end
        BAGS[0] = Bag({ Item(2589, 7), Item(2592, 4), Item(9010, 10), Item(2589, 3) }, 16)
        for bag = 1, 4 do BAGS[bag] = {} end
    end

    Setup()
    local ids = ns.BankContainers()
    check(ids[1] == -1 and ids[2] == 5 and #ids == 8, "the bank and its bags are found, never the player's own bags")
    check(ns.db.bankTidy, "tidying the bank starts on")
    Fire("BANKFRAME_OPENED")
    RunAfters()
    RunTickers()
    check(BAGS[-1][1].stackCount == 20 and BAGS[-1][2].stackCount == 11, "the bank's partial stacks are put together, then topped up from the bags")
    check(BAGS[0][1] == false and BAGS[0][4] == false, "the linen in the bags went into the bank's stack, freeing two bag slots")
    check(BAGS[0][2].stackCount == 4 and BAGS[-1][3].stackCount == 20, "wool stays in the bags: the bank's wool stack is already full")
    check(BAGS[0][3].stackCount == 10 and BAGS[-1][4].stackCount == 5, "food is never taken from the bags, only crafting materials")
    check(Said():find("At the bank: put partial bank stacks together; moved 10 items from your bags onto bank stacks (2 bag slots freed).", 1, true) ~= nil,
        "and it says what it did: " .. Said())
    SlashCmdList.JUNKMATE("bank")
    RunTickers()
    check(Said():find("already tidy", 1, true) ~= nil, "/junkmate bank with nothing to do says so")
    Fire("BANKFRAME_CLOSED")
    SlashCmdList.JUNKMATE("bank")
    check(Said() == "|cffd9a066JunkMate|r: Open your bank first.", "and with the bank closed, asks for it to be opened")

    Setup()
    SHIFT = true
    Fire("BANKFRAME_OPENED")
    RunAfters()
    check(#tickers == 0 and BAGS[-1][1].stackCount == 15, "holding Shift at the bank leaves it alone")
    SHIFT = false
    Fire("BANKFRAME_CLOSED")

    ns.db.bankTidy = false
    Fire("BANKFRAME_OPENED")
    RunAfters()
    check(#tickers == 0, "with the option off, the bank is left alone")
    ns.db.bankTidy = true
    Fire("BANKFRAME_CLOSED")

    Fire("BANKFRAME_OPENED")
    RunAfters()
    tickers[1].fn(tickers[1]); tickers[1].fn(tickers[1])
    Fire("BANKFRAME_CLOSED")
    RunTickers()
    check(Said():find("closed before JunkMate was done", 1, true) ~= nil and BAGS[0][1] ~= false, "closing the bank stops it part way, and it says so")
    BAGS[-1] = {}
    for bag = 5, 11 do BAGS[bag] = nil end
end

-- Audit fixes.
do
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local function RunAfters()
        local timers = AFTERS; AFTERS = {}
        for _, fn in ipairs(timers) do fn() end
    end
    local room = JunkMateRoom
    for bag = 1, 4 do BAGS[bag] = {} end
    -- A stack that grew after it was offered is not destroyed.
    local list = {}
    for i = 1, 14 do list[i] = Item(9020) end
    list[15] = Item(9011, 4)   -- better food, so the jerky is outgrown
    list[16] = Item(9010, 3)
    BAGS[0] = list
    LOOTS = {}
    Fire("PLAYER_REGEN_ENABLED")
    SlashCmdList.JUNKMATE("room")
    check(room:IsShown() and room.what:GetText():find("x3", 1, true), "(jerky x3 on offer)")
    BAGS[0][16].stackCount = 8
    NOW = NOW + 2
    local deleted = #DELETED
    room.destroy.__scripts.OnClick(room.destroy)
    check(#DELETED == deleted and room.what:GetText():find("x8", 1, true), "a stack that grew after it was offered is offered again at its new size, not destroyed")
    room:Hide(); room.__scripts.OnHide(room)

    -- Loot that fails with room in the bags is tried once, not forever.
    BAGS[0][16] = false
    LOOTS = { { link = "item:9040", name = "Green Bracers", q = 2 } }
    local looted = #LOOTED
    for _ = 1, 3 do
        Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
        RunAfters()
    end
    check(#LOOTED == looted + 1, "with room in the bags, a failed loot is tried again once, not over and over")
    Fire("LOOT_CLOSED")
    room:Hide(); room.__scripts.OnHide(room)
    LOOTS = {}

    -- Selling one by one checks each slot again before selling.
    local sellAll = C_MerchantFrame.SellAllJunkItems
    C_MerchantFrame.SellAllJunkItems = nil
    BAGS[0] = { { quality = 0 }, { quality = 0 } }
    USED = {}
    local made
    C_Timer.NewTicker = function(_, fn) made = fn end
    Fire("MERCHANT_SHOW")
    BAGS[0][2] = { quality = 3 }
    local fake = { Cancel = function(self) self.cancelled = true end }
    for _ = 1, 4 do if not fake.cancelled then made(fake) end end
    check(table.concat(USED, " ") == "0:1", "an item swapped in while selling is not sold")
    Fire("MERCHANT_CLOSED")
    C_MerchantFrame.SellAllJunkItems = sellAll

    -- The bank's bags on a client whose names for them are different.
    Enum.BagIndex = { Backpack = 0, Bank = -1, ReagentBag = 5 }
    local ids = ns.BankContainers()
    local seen = {}
    for _, id in ipairs(ids) do seen[id] = true end
    check(seen[-1] and seen[6] and not seen[5] and not seen[0], "bank bags found by number when not by name, never the reagent bag")
    Enum.BagIndex = nil
end

-- Protecting kept gear, selling extras at a vendor, and the tooltip line.
do
    ITEMS[9070] = { name = "Green Gloves", q = 2, ilvl = 8, loc = "INVTYPE_HAND", price = 40, class = 4, sub = 1 }
    ITEMS[9071] = { name = "Riding Gloves", q = 2, ilvl = 5, loc = "INVTYPE_HAND", price = 30, class = 4, sub = 1 }
    ITEMS[9072] = { name = "Fire Mitts", q = 1, ilvl = 5, loc = "INVTYPE_HAND", price = 9, class = 4, sub = 1 }
    ITEMS[9073] = { name = "Fishing Mitts", q = 1, ilvl = 6, loc = "INVTYPE_HAND", price = 7, class = 4, sub = 1 }
    local TIPS = { [9071] = "Equip: Increases mount speed by 4%.", [9014] = "Use: If you spend at least 10 seconds eating you will become well fed." }
    C_TooltipInfo.GetBagItem = function(bag, slot)
        local item = BAGS[bag][slot]
        local tip = item and TIPS[item.itemID]
        return { lines = tip and { { leftText = tip } } or {} }
    end
    C_Item.GetItemStats = function(link)
        if tostring(link):find("item:9072", 1, true) then return { ITEM_MOD_FIRE_RESISTANCE_SHORT = 10 } end
        return {}
    end
    C_EquipmentSet = { GetEquipmentSetIDs = function() return { 1 } end, GetItemIDs = function() return { [10] = 9073 } end }
    local function Item(id, count, bound)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1,
            isBound = bound ~= false }
    end
    for bag = 1, 4 do BAGS[bag] = {} end
    BAGS[0] = { Item(9010, 3), Item(9011, 4), Item(9021), Item(9022), Item(9070, 1, false), Item(9071), Item(9072), Item(9073) }
    Fire("BAG_UPDATE_DELAYED")

    local names = {}
    for _, item in ipairs(ns.RoomCandidates()) do names[#names + 1] = item.name end
    check(table.concat(names, ",") == "Tough Jerky,Cloth Gloves,Mail Chest", "never offered: equipment-set gear, special effects, resistances, bind-on-equip greens: " .. table.concat(names, ","))
    local reasons = ns.Survey(true).bySlot
    check(reasons["0:5"].reason:find("bind on equip", 1, true) and reasons["0:6"].reason == "it has a special effect"
        and reasons["0:7"].reason == "it has a special effect" and reasons["0:8"].reason == "in an equipment set",
        "each kept for its own reason")

    -- The tooltip line.
    local owner = { GetBagID = function() return 0 end, GetID = function() return 1 end }
    local said = {}
    rawset(GameTooltip, "GetOwner", function() return owner end)
    rawset(GameTooltip, "AddLine", function(_, text) said[#said + 1] = text end)
    local function Why(slot, id)
        said = {}
        owner.GetID = function() return slot end
        ns.AddWhyLine(GameTooltip, { id = id })
        return said[1] or ""
    end
    check(Why(1, 9010) == "JunkMate: sold at vendors; 1st to go if your bags fill (outgrown food or drink)", "outgrown food says it is sold and goes first: " .. Why(1, 9010))
    check(Why(4, 9022) == "JunkMate: 2nd to go if your bags fill (gear that's no upgrade)", "wearable gear that's no upgrade is not sold, only offered: " .. Why(4, 9022))
    check(Why(3, 9021) == "JunkMate: sold at vendors; 3rd to go if your bags fill (gear you can't use)", "gear this class can't use is sold: " .. Why(3, 9021))
    check(Why(2, 9011) == "JunkMate keeps this: your best food or drink for your level", "kept items say why: " .. Why(2, 9011))
    check(Why(6, 9071) == "JunkMate keeps this: it has a special effect", "Riding Gloves are kept for their effect")
    check(Why(6, 9999) == "", "nothing is said if the item there is not the one on the tooltip")
    owner.GetBagID = function() return 7 end
    check(Why(1, 9010) == "", "nor for anything that is not in the bags")
    owner.GetBagID = function() return 0 end
    ns.db.whyTooltip = false
    check(Why(1, 9010) == "", "and nothing with the option off")
    ns.db.whyTooltip = true

    -- Selling extras at a vendor.
    local ticks = {}
    C_Timer.NewTicker = function(_, fn)
        local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
        ticks[#ticks + 1] = t
        return t
    end
    USED = {}
    Fire("MERCHANT_SHOW")
    local timers = AFTERS; AFTERS = {}
    for _, fn in ipairs(timers) do fn() end
    check(#ticks == 1, "a vendor visit sells the extras after the junk")
    for _ = 1, 10 do if not ticks[1].cancelled then ticks[1].fn(ticks[1]) end end
    check(table.concat(USED, " ") == "0:1 0:3", "outgrown food and gear this class can't use are sold, nothing else: " .. table.concat(USED, " "))
    check(PRINTED[#PRINTED]:find("Also sold 2 outgrown or unusable items for 1s 26c.", 1, true) ~= nil, "and it says so: " .. PRINTED[#PRINTED])
    Fire("MERCHANT_CLOSED")

    ns.db.sellExtras = false
    ticks, USED = {}, {}
    Fire("MERCHANT_SHOW")
    timers = AFTERS; AFTERS = {}
    for _, fn in ipairs(timers) do fn() end
    check(#ticks == 0, "with the option off, only junk is sold")
    Fire("MERCHANT_CLOSED")
    ns.db.sellExtras = true

    local many = {}
    for i = 1, 16 do many[i] = Item(9021) end
    BAGS[0] = many
    Fire("BAG_UPDATE_DELAYED")
    ticks, USED = {}, {}
    Fire("MERCHANT_SHOW")
    timers = AFTERS; AFTERS = {}
    for _, fn in ipairs(timers) do fn() end
    for _ = 1, 30 do if not ticks[1].cancelled then ticks[1].fn(ticks[1]) end end
    check(#USED == 12, "never more than 12 a visit, so everything sold can be bought back")
    Fire("MERCHANT_CLOSED")
    C_EquipmentSet = nil
end

-- Two items on a corpse, bags full: after room is made for the first, the
-- second gets its own offer.
do
    ITEMS[9042] = { name = "Broken Boar Tusk", q = 0, price = 6, class = 15, sub = 0 }
    ITEMS[9043] = { name = "Chunk of Boar Meat", q = 1, stack = 20, price = 4, class = 7, sub = 8 }
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local function RunAfters()
        for _ = 1, 5 do
            local timers = AFTERS; AFTERS = {}
            for _, fn in ipairs(timers) do fn() end
        end
    end
    local room = JunkMateRoom
    room:Hide(); room.__scripts.OnHide(room)
    Fire("LOOT_CLOSED")
    local list = {}
    for i = 1, 13 do list[i] = Item(9020) end
    list[14], list[15], list[16] = Item(9001), Item(9001), Item(9022)
    BAGS[0] = list
    for bag = 1, 4 do BAGS[bag] = {} end
    LOOTS = { { link = "item:9043", name = "Chunk of Boar Meat", q = 1 }, { link = "item:9042", name = "Broken Boar Tusk", q = 0 } }
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(room:IsShown() and room.why:GetText():find("item:9043", 1, true), "(an offer for the boar meat first)")
    NOW = NOW + 2
    room.destroy.__scripts.OnClick(room.destroy)
    room.__scripts.OnHide(room)
    BAGS[0][14] = Item(9043)   -- the meat arrives in the freed slot
    local looted = #LOOTED
    Fire("BAG_UPDATE_DELAYED")
    RunAfters()
    check(room.why:GetText() == "To make room for item:9042 (worth 6c).", "the offer says what the loot is worth: " .. tostring(room.why:GetText()))
    check(LOOTED[looted + 1] == 1 and room:IsShown() and room.why:GetText():find("item:9042", 1, true),
        "after the meat is looted, the tusk left on the corpse gets its own offer: " .. tostring(room.why:GetText()))
    room:Hide(); room.__scripts.OnHide(room)
    -- With nothing cheaper than the tusk left, it says so instead.
    BAGS[0][15] = Item(9022)
    LOOTS[1].link, LOOTS[1].name = nil, nil
    Fire("BAG_UPDATE_DELAYED")
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(not room:IsShown() and PRINTED[#PRINTED]:find("item:9042 is worth less than", 1, true), "a tusk worth less than anything on offer is left, and chat says so")
    Fire("LOOT_CLOSED")
    LOOTS = {}
end

-- A quest reward that will not fit.
do
    ITEMS[9080] = { name = "Goretusk Liver Pie", q = 1, min = 5, stack = 20, price = 25, class = 0, sub = 5 }
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local function RunAfters()
        for _ = 1, 5 do
            local timers = AFTERS; AFTERS = {}
            for _, fn in ipairs(timers) do fn() end
        end
    end
    local room = JunkMateRoom
    room:Hide(); room.__scripts.OnHide(room)
    local function FullBags()
        local list = {}
        for i = 1, 13 do list[i] = Item(9020) end
        list[14], list[15], list[16] = Item(9001), Item(9001), Item(9022)
        BAGS[0] = list
        for bag = 1, 4 do BAGS[bag] = {} end
    end
    REWARDS, CHOICES, HANDED = { "item:9080" }, 0, {}
    GetNumQuestRewards = function() return #REWARDS end
    GetNumQuestChoices = function() return CHOICES end
    GetQuestItemInfo = function() return "Goretusk Liver Pie", "icon", 5 end
    GetQuestItemLink = function(_, index) return REWARDS[index] end
    GetTitleText = function() return "Goretusk Liver Pie" end
    GetQuestReward = function(choice) HANDED[#HANDED + 1] = choice end

    -- The reward window opens with full bags: offered at once.
    FullBags()
    Fire("QUEST_COMPLETE")
    check(room:IsShown() and room.title:GetText():find("quest reward", 1, true)
        and room.why:GetText():find("To make room for the reward from Goretusk Liver Pie.", 1, true)
        and room.why:GetText():find("Or clear your bags at a vendor first and come back.", 1, true), "full bags at a quest's reward window: room is offered at once: " .. tostring(room.why:GetText()))
    NOW = NOW + 2
    room.destroy.__scripts.OnClick(room.destroy)
    room.__scripts.OnHide(room)
    Fire("BAG_UPDATE_DELAYED")
    RunAfters()
    check(#HANDED == 1 and HANDED[1] == 0, "once there's room, the quest is handed in")
    Fire("QUEST_FINISHED")

    -- The hand-in failed and the window closed (as the game does).
    FullBags()
    Fire("QUEST_COMPLETE")
    room:Hide(); room.__scripts.OnHide(room)
    Fire("QUEST_FINISHED")
    Fire("CHAT_MSG_SYSTEM", "Goretusk Liver Pie failed: Inventory is full.")
    Fire("CHAT_MSG_SYSTEM", "Goretusk Liver Pie failed: Inventory is full.")
    RunAfters()
    check(room:IsShown() and room.why:GetText():find("Goretusk Liver Pie", 1, true), "'<quest> failed: Inventory is full.' brings up the offer")
    NOW = NOW + 2
    room.destroy.__scripts.OnClick(room.destroy)
    room.__scripts.OnHide(room)
    Fire("BAG_UPDATE_DELAYED")
    RunAfters()
    check(#HANDED == 1 and PRINTED[#PRINTED]:find("talk to the quest giver again", 1, true), "with the quest window gone, it says to talk to the quest giver again: " .. PRINTED[#PRINTED])

    -- A reward that stacks onto one carried needs no room.
    FullBags()
    BAGS[0][16] = Item(9080, 3)
    Fire("QUEST_COMPLETE")
    check(not room:IsShown(), "a reward that stacks onto one you carry needs no room")
    Fire("QUEST_FINISHED")

    -- A choice of rewards: room is made, but the choice is yours.
    FullBags()
    REWARDS, CHOICES = {}, 3
    Fire("QUEST_COMPLETE")
    NOW = NOW + 2
    room.destroy.__scripts.OnClick(room.destroy)
    room.__scripts.OnHide(room)
    Fire("BAG_UPDATE_DELAYED")
    RunAfters()
    check(#HANDED == 1 and PRINTED[#PRINTED]:find("pick it and complete the quest", 1, true), "with a reward to choose, it never chooses: it says to pick it")
    Fire("QUEST_FINISHED")
    GetNumQuestRewards, GetNumQuestChoices = nil, nil
end

-- Bags full of things normally kept, at a quest turn-in.
do
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local function RunAfters()
        for _ = 1, 5 do
            local timers = AFTERS; AFTERS = {}
            for _, fn in ipairs(timers) do fn() end
        end
    end
    local room = JunkMateRoom
    room:Hide(); room.__scripts.OnHide(room)
    Fire("QUEST_FINISHED")
    -- Linen (crafting material), potions, a quest item, the hearthstone.
    local list = {}
    for i = 1, 12 do list[i] = Item(9003) end
    list[13], list[14], list[15], list[16] = Item(2589, 20), Item(2589, 20), Item(858, 5), Item(6948)
    BAGS[0] = list
    for bag = 1, 4 do BAGS[bag] = {} end
    REWARDS, CHOICES = { "item:9080" }, 0
    GetNumQuestRewards = function() return #REWARDS end
    GetNumQuestChoices = function() return CHOICES end
    Fire("QUEST_COMPLETE")
    check(room:IsShown() and room.what:GetText():find("item:858", 1, true)
        and room.why:GetText():find("Normally kept: a potion or other consumable.", 1, true),
        "nothing junk left: for a quest reward, the cheapest everyday thing normally kept is offered, marked so: "
        .. tostring(room.what:GetText()) .. " / " .. tostring(room.why:GetText()))
    NOW = NOW + 2
    room.next.__scripts.OnClick(room.next)
    check(room.what:GetText():find("item:2589", 1, true) and room.why:GetText():find("Normally kept: a crafting material.", 1, true),
        "Not this one moves on to the next (a crafting material)")
    room:Hide(); room.__scripts.OnHide(room)
    Fire("QUEST_FINISHED")

    -- Only quest items and the hearthstone: nothing is offered, and chat says what to do.
    for i = 13, 15 do list[i] = Item(9003) end
    Fire("QUEST_COMPLETE")
    check(not room:IsShown() and PRINTED[#PRINTED]:find("There's no room for the reward from Goretusk Liver Pie", 1, true)
        and PRINTED[#PRINTED]:find("vendor or the bank first and come back", 1, true),
        "with only untouchable things in the bags, chat says to clear them at a vendor or the bank: " .. PRINTED[#PRINTED])
    Fire("QUEST_FINISHED")

    -- Ordinary loot never reaches into the things normally kept.
    list[13], list[14] = Item(2589, 20), Item(2589, 20)
    LOOTS = { { link = "item:9043", name = "Chunk of Boar Meat", q = 1 } }
    Fire("UI_ERROR_MESSAGE", 3, "Inventory is full.")
    RunAfters()
    check(not room:IsShown(), "ordinary loot never offers anything normally kept")
    Fire("LOOT_CLOSED")
    LOOTS = {}
    GetNumQuestRewards, GetNumQuestChoices = nil, nil
end

-- Opening clams and other things that open (Open.lua).
do
    ITEMS[9090] = { name = "Small Barnacled Clam", q = 1, price = 0, class = 15, sub = 0 }
    ITEMS[9091] = { name = "Battered Junkbox", q = 1, price = 0, class = 15, sub = 0 }
    ITEMS[9092] = { name = "Clam Meat", q = 1, stack = 20, price = 2, class = 7, sub = 8 }
    local function Item(id, count, opens)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1,
            isBound = true, hasLoot = opens or nil }
    end
    local ticks = {}
    C_Timer.NewTicker = function(_, fn)
        local t = { fn = fn, Cancel = function(self) self.cancelled = true end }
        ticks[#ticks + 1] = t
        return t
    end
    local locked = {}
    C_TooltipInfo.GetBagItem = function(bag, slot)
        local item = BAGS[bag][slot]
        return { lines = (item and locked[item.itemID]) and { { leftText = "Locked" } } or {} }
    end
    local room = JunkMateRoom
    room:Hide(); room.__scripts.OnHide(room)
    ns.merchantOpen, ns.bankOpen = false, false
    LOOTS = {}
    USED, LOOTED = {}, {}
    local function Bags()
        local list = {}
        for i = 1, 12 do list[i] = Item(9022) end
        list[13], list[14], list[15] = Item(9090, 1, true), Item(9090, 1, true), Item(9090, 1, true)
        list[16] = false
        BAGS[0] = list
        for bag = 1, 4 do BAGS[bag] = {} end
    end
    -- One tick of the opener; if it just opened a clam, its meat is looted
    -- and the clam is gone.
    local function Tick()
        local t = ticks[#ticks]
        if not t or t.cancelled then return end
        local used = #USED
        t.fn(t)
        if #USED > used then
            local bag, slot = USED[#USED]:match("(%d+):(%d+)")
            LOOTS = { { link = "item:9092", name = "Clam Meat", q = 1 } }
            Fire("LOOT_READY")
            local meat
            for i = 1, 16 do if BAGS[0][i] and BAGS[0][i].itemID == 9092 then meat = BAGS[0][i] end end
            if meat then meat.stackCount = meat.stackCount + 1; BAGS[0][tonumber(slot)] = false
            else BAGS[0][tonumber(slot)] = Item(9092, 1) end
            LOOTS = {}
        end
    end

    Bags()
    NOW = NOW + 100
    local said = #PRINTED
    Fire("BAG_UPDATE_DELAYED")
    check(#ticks == 1 and #PRINTED == said, "down to the warning with clams in the bags: they are opened, before any warning")
    for _ = 1, 6 do Tick() end
    check(table.concat(USED, " ") == "0:13 0:14 0:15" and #LOOTED >= 3, "each clam is opened in turn, and what's inside taken")
    check(PRINTED[#PRINTED]:find("Opened 3 items (2 bag slots freed).", 1, true) ~= nil, "then it says what that freed: " .. PRINTED[#PRINTED])

    -- Never at a vendor, where opening would sell it.
    Bags(); USED = {}; ticks = {}
    ns.merchantOpen = true
    SlashCmdList.JUNKMATE("open")
    check(#ticks == 0 and PRINTED[#PRINTED]:find("won't open things at a vendor or the bank", 1, true), "never at a vendor, where 'opening' would sell it")
    ns.merchantOpen = false
    MailFrame = CreateFrame("Frame", "MailFrame"); MailFrame:Show()
    SlashCmdList.JUNKMATE("open")
    check(#ticks == 0 and PRINTED[#PRINTED]:find("with that window open", 1, true), "nor with the mailbox open")
    MailFrame:Hide()

    -- A vendor opened part way: it stops.
    SlashCmdList.JUNKMATE("open")
    Tick()
    ns.merchantOpen = true
    Tick()
    check(#USED == 1 and PRINTED[#PRINTED]:find("Stopped: at a vendor or the bank.", 1, true), "opening a vendor part way stops it: " .. PRINTED[#PRINTED])
    ns.merchantOpen = false

    -- Locked boxes are left alone; full bags can't take what's inside.
    Bags(); USED = {}; ticks = {}
    BAGS[0][13], BAGS[0][14], BAGS[0][15] = Item(9091, 1, true), Item(9022), Item(9022)
    locked[9091] = true
    SlashCmdList.JUNKMATE("open")
    check(#ticks == 0 and PRINTED[#PRINTED] == "|cffd9a066JunkMate|r: Nothing in your bags to open.", "a locked box is left alone")
    locked[9091] = nil
    BAGS[0][16] = Item(9022)
    SlashCmdList.JUNKMATE("open")
    check(#ticks == 0 and PRINTED[#PRINTED]:find("Free one slot first", 1, true), "with no free slot, it says one is needed first")
    Fire("BAG_UPDATE_DELAYED")
    local item = ns.Survey(true).bySlot["0:13"]
    check(item and item.reason == "it opens; JunkMate opens it when your bags get full", "the tooltip says it will be opened")
    ns.db.openContainers = false
    BAGS[0][16] = false
    NOW = NOW + 100
    Fire("BAG_UPDATE_DELAYED")
    check(#ticks == 0, "with the option off, nothing is opened")
    ns.db.openContainers = true
end

-- The window says why it offers this item, and what would go next.
do
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local room = JunkMateRoom
    room:Hide(); room.__scripts.OnHide(room)
    Fire("LOOT_CLOSED"); Fire("QUEST_FINISHED")
    LOOTS = {}
    local list = {}
    for i = 1, 10 do list[i] = Item(9020) end
    list[11], list[12] = Item(9002), Item(9001)          -- greys worth 50c and 5c
    list[13], list[14] = Item(9010, 3), Item(9011, 4)    -- jerky (level 5) and quail (level 15)
    list[15], list[16] = Item(9022), Item(9021)          -- cloth gloves (ilvl 5 vs 12 worn), mail chest
    BAGS[0] = list
    for bag = 1, 4 do BAGS[bag] = {} end
    local function Reason() return room.reason:GetText() or "" end
    SlashCmdList.JUNKMATE("room")
    check(Reason():find("Why this one: it's grey junk; the cheapest of 2 grey items.", 1, true)
        and Reason():find("Next in line: item:9002 (worth 50c).", 1, true), "a grey: why, and what's next: " .. Reason())
    NOW = NOW + 2
    NOW = NOW + 2; room.next.__scripts.OnClick(room.next)
    NOW = NOW + 2; room.next.__scripts.OnClick(room.next)
    check(Reason():find("Why this one: with no grey items to offer, it's food you've outgrown (level 5; you also carry level 15).", 1, true),
        "outgrown food says what better food you carry: " .. Reason())
    NOW = NOW + 2; room.next.__scripts.OnClick(room.next)
    check(Reason():find("it's no upgrade (item level 5; what you wear there is 12); the cheapest of 2 pieces of gear", 1, true),
        "gear that's no upgrade compares with what you wear: " .. Reason())
    NOW = NOW + 2; room.next.__scripts.OnClick(room.next)
    check(Reason():find("your class can't use mail", 1, true) and not Reason():find("Next in line", 1, true),
        "gear the class can't use says why, and the last one has nothing next: " .. Reason())
    room:Hide(); room.__scripts.OnHide(room)
end

-- Finding a repairer while gear is worn (Repair.lua).
do
    local notice = JunkMateDurabilityNotice
    ns.db.vendorGuide = false   -- this block is about repairers only
    GEAR = {}
    Fire("UPDATE_INVENTORY_DURABILITY")
    -- The minimap's tracking menu.
    local TRACK = { false, false }
    C_Minimap.GetNumTrackingTypes = function() return 2 end
    C_Minimap.GetTrackingInfo = function(i) return { name = i == 2 and "Repair" or "Find Herbs", active = TRACK[i] } end
    C_Minimap.SetTracking = function(i, on) TRACK[i] = on end

    -- Opening a repairer's shop remembers them.
    UNITS.npc = { name = "William MacGregor" }
    local player = PLAYER
    player.map, player.x, player.y = 1, 0.5, 0.5
    CAN_REPAIR, REPAIR_COST = true, 0
    Fire("MERCHANT_SHOW"); AFTERS = {}; Fire("MERCHANT_CLOSED")
    check(ns.db.repairers and ns.db.repairers["William MacGregor@1"], "opening a repairer's shop remembers them")
    UNITS.npc = { name = "Mike Miller" }
    CAN_REPAIR = false
    Fire("MERCHANT_SHOW"); AFTERS = {}; Fire("MERCHANT_CLOSED")
    check(not ns.db.repairers["Mike Miller@1"], "a vendor who doesn't repair is not")
    CAN_REPAIR = true

    -- Gear wears out, 180 yards away.
    player.x = 0.68
    GEAR[5] = { 18, 100 }
    Fire("UPDATE_INVENTORY_DURABILITY")
    local label
    for _, f in ipairs(Frames()) do
        if rawget(f, "__text") and f.__text:find("^Gear worn") then label = f end
    end
    check(label and label.__text:find("Nearest repair: William MacGregor, 180 yd", 1, true), "the worn-gear line names the nearest repairer: " .. tostring(label and label.__text))
    check(PRINTED[#PRINTED]:find("Nearest repair: William MacGregor, 180 yd.", 1, true), "and so does the chat line")
    check(TRACK[2] == true and TRACK[1] == false, "the minimap's repair tracking is switched on")
    notice.__scripts.OnMouseUp(notice, "LeftButton")   -- ends an earlier test's drag
    WAYPOINT, SUPERTRACKED = nil, false
    notice.__scripts.OnMouseUp(notice, "LeftButton")
    check(WAYPOINT and WAYPOINT[1] == 1 and math.abs(WAYPOINT[2] - 0.5) < 0.001 and SUPERTRACKED, "clicking the line puts a map pin on them")
    notice.__scripts.OnDragStart(notice); notice.__scripts.OnDragStop(notice)
    WAYPOINT = nil
    notice.__scripts.OnMouseUp(notice, "LeftButton")
    check(WAYPOINT == nil, "dragging the line moves it, without a pin")

    -- On their tooltip, and when targeted.
    local lines = {}
    rawset(GameTooltip, "AddLine", function(_, text) lines[#lines + 1] = text end)
    rawset(GameTooltip, "GetUnit", function() return "William MacGregor", "mouseover" end)
    UNITS.mouseover = { name = "William MacGregor" }
    ns.AddRepairLine(GameTooltip)
    check(lines[1] == "JunkMate: repairs here. Your gear is at 18%.", "a known repairer's tooltip says so: " .. tostring(lines[1]))
    UNITS.target = { name = "William MacGregor" }
    local said = #PRINTED
    Fire("PLAYER_TARGET_CHANGED")
    check(PRINTED[#PRINTED] == "|cffd9a066JunkMate|r: William MacGregor repairs, and your gear is at 18%.", "targeting them while worn says so")
    Fire("PLAYER_TARGET_CHANGED")
    check(#PRINTED == said + 1, "once, not every time")

    -- Repaired: tracking back off, since JunkMate turned it on.
    GEAR[5] = { 100, 100 }
    Fire("UPDATE_INVENTORY_DURABILITY")
    check(TRACK[2] == false, "once repaired, the tracking JunkMate turned on goes off again")
    lines = {}
    ns.AddRepairLine(GameTooltip)
    check(lines[1] == "JunkMate: repairs here", "the tooltip still says they repair")
    -- Tracking the player turned on themselves stays on.
    TRACK[2] = true
    GEAR[5] = { 10, 100 }
    Fire("UPDATE_INVENTORY_DURABILITY")
    GEAR[5] = { 100, 100 }
    Fire("UPDATE_INVENTORY_DURABILITY")
    check(TRACK[2] == true, "repair tracking you turned on yourself is left on")
    SlashCmdList.JUNKMATE("repairer")
    check(PRINTED[#PRINTED - 1]:find("JunkMate knows 1 repairer.", 1, true), "/junkmate repairer says how many it knows: " .. PRINTED[#PRINTED - 1])
    GEAR = {}
    Fire("UPDATE_INVENTORY_DURABILITY")
    UNITS.npc, UNITS.mouseover, UNITS.target = nil, nil, nil
    ns.db.vendorGuide = true
end

-- Finding a vendor whenever there is junk to sell (Vendor.lua).
do
    local function Item(id, count)
        return { itemID = id, stackCount = count or 1, quality = ITEMS[id].q, hyperlink = "item:" .. id, iconFileID = 1, isBound = true }
    end
    local player = PLAYER
    player.map, player.x, player.y = 1, 0.5, 0.5
    check(ns.db.vendors and ns.db.vendors["Mike Miller@1"] and ns.db.vendors["William MacGregor@1"],
        "every vendor is remembered when their shop opens, repairer or not")
    ns.db.vendors = {
        ["Mike Miller@1"] = { name = "Mike Miller", map = 1, x = 0.62, y = 0.5, faction = "Alliance" },
        ["Far Away@2"] = { name = "Far Away", map = 2, x = 0.5, y = 0.5, faction = "Alliance" },
        ["Horde Guy@1"] = { name = "Horde Guy", map = 1, x = 0.51, y = 0.5, faction = "Horde" },
    }
    check(JunkMateVendorNotice == nil, "there is no on-screen junk banner")
    local button = JunkMateMinimapButton
    local lines = {}
    rawset(GameTooltip, "AddLine", function(_, t) lines[#lines + 1] = t end)
    local function Hover()
        lines = {}
        button.__scripts.OnEnter(button)
        return table.concat(lines, " | ")
    end
    -- Junk in the bags: the coin, and the nearest vendor of your faction on this continent.
    local list = {}
    for i = 1, 6 do list[i] = Item(9020) end
    list[7] = Item(9001)
    BAGS[0] = list
    for i = 8, 16 do BAGS[0][i] = false end
    for bag = 1, 4 do BAGS[bag] = {} end
    Fire("BAG_UPDATE_DELAYED")
    check(ns.junkBadge:IsShown(), "junk to sell shows a coin on the minimap button")
    check(Hover():find("Junk to sell: 1 item (5c) | Nearest vendor: Mike Miller, 120 yd", 1, true)
        and Hover():find("Right-click: map pin on the nearest vendor", 1, true), "hovering the button says what it's worth and the nearest vendor: " .. Hover())
    WAYPOINT = nil
    button.__scripts.OnClick(button, "RightButton")
    check(WAYPOINT and math.abs(WAYPOINT[2] - 0.62) < 0.001, "right-clicking the button pins the vendor")
    -- No junk: no coin, nothing said.
    BAGS[0][7] = Item(9020)
    Fire("BAG_UPDATE_DELAYED")
    check(not ns.junkBadge:IsShown() and not Hover():find("Junk to sell", 1, true), "nothing to sell: no coin")
    BAGS[0][7] = Item(9001)
    Fire("BAG_UPDATE_DELAYED")
    -- Known vendors: tooltip and target.
    rawset(GameTooltip, "GetUnit", function() return "Mike Miller", "mouseover" end)
    UNITS.mouseover = { name = "Mike Miller" }
    lines = {}
    ns.AddVendorLine(GameTooltip)
    check(lines[1] == "JunkMate: buys your junk (1 item, 5c)", "a known vendor's tooltip says they'll buy it: " .. tostring(lines[1]))
    UNITS.target = { name = "Mike Miller" }
    Fire("PLAYER_TARGET_CHANGED")
    check(PRINTED[#PRINTED] == "|cffd9a066JunkMate|r: Mike Miller buys junk: you have 1 item to sell (5c).", "targeting one says so: " .. PRINTED[#PRINTED])
    -- Option off: the coin stays, the vendor naming goes.
    ns.db.vendorGuide = false
    check(ns.junkBadge:IsShown() and not Hover():find("Nearest vendor", 1, true), "with the option off the coin stays, but no vendor is named")
    ns.db.vendorGuide = true
    UNITS.npc, UNITS.mouseover, UNITS.target = nil, nil, nil
end
