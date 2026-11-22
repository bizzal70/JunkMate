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
check(notice.__shown and label.__text == "Gear worn: 18% left", "the most worn piece dropping below the level shows a line on screen")
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
check(#rows == 9, "the options have nine controls")
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
TooltipDataProcessor = { AddTooltipPostCall = function(kind, hook) if kind == "item" then priceHook = hook end end }
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
