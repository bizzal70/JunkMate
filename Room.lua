local addonName, ns = ...

-- Making room in the bags. Two parts:
--
-- Restacking merges partial stacks of the same item, which frees slots
-- without losing anything. It runs on its own when the bags get down to the
-- warning level, and first whenever loot will not fit.
--
-- Making room: when loot will not fit and restacking cannot help, a small
-- window offers to destroy the least valuable thing JunkMate is sure you do
-- not need, to make room for it. Nothing is ever destroyed without a press
-- of its button. Never offered: quest items, crafting materials, profession
-- tools, class reagents, keys, bags, ammo, potions and other consumables,
-- gear that would be an upgrade, anything epic or better, anything on the
-- keep list, anything the game has not described to JunkMate yet, all buff
-- food, and the best food and drink you carry for your level. Grey items go
-- first, then outdated food and drink, then gear, cheapest first.

local FIRST_BAG, LAST_BAG = 0, 4
-- Pause between two merges while restacking, so the game keeps up.
local MOVE_INTERVAL = 0.25
-- How often a merge may wait for a locked stack before it is given up.
local MAX_WAITS = 12
-- Restacking on its own (at the warning) at most this often, in seconds.
local AUTO_RESTACK_GAP = 10
-- The window ignores presses this long after it shows something new, so a
-- button already on its way down cannot destroy an item nobody has seen.
local ARM_SECONDS = 0.6
-- Longer when the window comes back by itself after a fight.
local RETURN_ARM_SECONDS = 1.5

local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function Number(value)
    return Usable(value) and type(value) == "number" and value or nil
end

----------------------------------------------------------------------------
-- What the game says about an item
----------------------------------------------------------------------------

-- Facts about an item (ID or link), or nil if the game has not loaded it.
function ns.ItemFacts(item)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo or item == nil then return end
    local ok, name, link, quality, itemLevel, minLevel, _, _, maxStack, equipLoc, _, price, classID, subclassID =
        pcall(getInfo, item)
    if not ok or not Usable(name) or name == nil then return end
    return {
        name = name, link = Usable(link) and link or nil,
        quality = Number(quality), itemLevel = Number(itemLevel), minLevel = Number(minLevel) or 0,
        maxStack = Number(maxStack) or 1, equipLoc = Usable(equipLoc) and equipLoc or nil,
        price = Number(price) or 0, classID = Number(classID), subclassID = Number(subclassID),
    }
end

-- Every item in the given containers (bag IDs).
function ns.ContainerItems(bags)
    local items = {}
    local container = C_Container
    if not (container and container.GetContainerNumSlots) then return items end
    for _, bag in ipairs(bags) do
        local ok, count = pcall(container.GetContainerNumSlots, bag)
        local slots = ok and Number(count) or 0
        for slot = 1, slots do
            local info = container.GetContainerItemInfo(bag, slot)
            if type(info) == "table" and Number(info.itemID) then
                items[#items + 1] = {
                    bag = bag, slot = slot, itemID = info.itemID, count = Number(info.stackCount) or 1,
                    quality = Number(info.quality), locked = info.isLocked and true or false,
                    noValue = info.hasNoValue and true or false, bound = info.isBound, opens = info.hasLoot and true or false, link = Usable(info.hyperlink) and info.hyperlink or nil,
                    icon = info.iconFileID,
                }
            end
        end
    end
    return items
end

-- Every item in the backpack and the four bags.
local BAG_IDS = {}
for bag = FIRST_BAG, LAST_BAG do BAG_IDS[#BAG_IDS + 1] = bag end
function ns.BagItems()
    return ns.ContainerItems(BAG_IDS)
end

----------------------------------------------------------------------------
-- Restacking
----------------------------------------------------------------------------

-- The merges that would tidy the bags (or the given items, such as the
-- bank's): a list of { itemID, from, to, amount, max }, and how many slots
-- they free. Fuller stacks are topped up from the smallest ones, so the
-- fewest stacks are left.
function ns.RestackPlan(items)
    local groups = {}
    for _, item in ipairs(items or ns.BagItems()) do
        if not item.locked then
            local facts = ns.ItemFacts(item.itemID)
            local max = facts and facts.maxStack or 1
            if max > 1 and item.count < max then
                local group = groups[item.itemID]
                if not group then
                    group = { max = max }
                    groups[item.itemID] = group
                end
                group[#group + 1] = item
            end
        end
    end
    local moves, freed = {}, 0
    for itemID, group in pairs(groups) do
        if #group >= 2 then
            table.sort(group, function(a, b)
                if a.count ~= b.count then return a.count > b.count end
                if a.bag ~= b.bag then return a.bag < b.bag end
                return a.slot < b.slot
            end)
            local counts = {}
            for index, item in ipairs(group) do counts[index] = item.count end
            local fill, take = 1, #group
            while fill < take do
                local room = group.max - counts[fill]
                if room <= 0 then
                    fill = fill + 1
                else
                    local amount = math.min(room, counts[take])
                    moves[#moves + 1] = { itemID = itemID, from = group[take], to = group[fill], amount = amount, max = group.max }
                    counts[fill], counts[take] = counts[fill] + amount, counts[take] - amount
                    if counts[take] == 0 then
                        freed = freed + 1
                        take = take - 1
                    end
                end
            end
        end
    end
    return moves, freed
end

-- One merge: "done", "wait" (try again shortly) or "skip" (things moved).
local function DoMove(move)
    if CursorHasItem and CursorHasItem() then return "wait" end
    local container = C_Container
    local from = container.GetContainerItemInfo(move.from.bag, move.from.slot)
    local to = container.GetContainerItemInfo(move.to.bag, move.to.slot)
    if type(from) ~= "table" or type(to) ~= "table" or from.itemID ~= move.itemID or to.itemID ~= move.itemID then
        return "skip"
    end
    if from.isLocked or to.isLocked then return "wait" end
    local amount = math.min(move.amount, from.stackCount or 0, move.max - (to.stackCount or move.max))
    if amount <= 0 then return "skip" end
    container.SplitContainerItem(move.from.bag, move.from.slot, amount)
    container.PickupContainerItem(move.to.bag, move.to.slot)
    -- Anything left in hand goes back where it came from.
    if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
    return "done"
end

local restackTicker

function ns.Restacking()
    return restackTicker ~= nil
end

-- Makes the moves one at a time, then onDone(finished). keepGoing, if
-- given, is asked before each move; once it says no, the rest are left and
-- onDone(false) is called. Returns false if moves are already under way.
function ns.RunMoves(moves, onDone, keepGoing)
    if restackTicker then return false end
    local index, waits = 1, 0
    restackTicker = C_Timer.NewTicker(MOVE_INTERVAL, function(ticker)
        local move = moves[index]
        local stop = move and keepGoing and not keepGoing()
        if not move or stop then
            ticker:Cancel()
            restackTicker = nil
            if onDone then pcall(onDone, not stop) end
            return
        end
        local ok, result = pcall(DoMove, move)
        if not ok then result = "skip" end
        if result == "wait" then
            waits = waits + 1
            if waits < MAX_WAITS then return end
        end
        waits, index = 0, index + 1
    end)
    return true
end

-- Restacks the bags, one merge at a time; onDone(slotsFreed) once finished.
-- Returns whether there was anything to do.
function ns.Restack(onDone)
    if restackTicker then return true end
    local moves, freed = ns.RestackPlan()
    if #moves == 0 then return false end
    return ns.RunMoves(moves, function() if onDone then onDone(freed) end end)
end

local function SayRestacked(freed)
    if freed > 0 then
        ns.Print(("Restacked your bags: %d slot%s freed."):format(freed, freed == 1 and "" or "s"))
    end
end

-- At the warning: restack if that frees a slot. Returns true while it does,
-- so the warning waits to see how much room it made.
local lastAuto
function ns.AutoRestack()
    if restackTicker then return true end
    if not (ns.db and ns.db.restack) then return false end
    local now = GetTime()
    if lastAuto and now - lastAuto < AUTO_RESTACK_GAP then return false end
    local _, freed = ns.RestackPlan()
    if freed == 0 then return false end
    lastAuto = now
    return ns.Restack(function(slots)
        SayRestacked(slots)
        if ns.UpdateBags then pcall(ns.UpdateBags) end
    end)
end

----------------------------------------------------------------------------
-- What must never be destroyed
----------------------------------------------------------------------------

local function Set(list)
    local set = {}
    for _, id in ipairs(list) do set[id] = true end
    return set
end

-- Profession tools.
local TOOLS = Set({
    7005, 12709, 19901,                                  -- skinning knives
    2901, 5956, 6219, 10498, 9149,                       -- mining pick, hammer, spanners, Philosopher's Stone
    6256, 6365, 6366, 6367, 12225, 19022, 19970,         -- fishing poles
    6217, 6218, 6339, 11130, 11145, 16207,               -- enchanting rods
})
-- The hearthstone, soul shards and class reagents.
local KEEP = Set({
    6948, 6265, 5060,
    17030, 17031, 17032, 17020, 17056, 17028, 17029, 17033, 21177,
    5140, 5530, 5565, 16583, 17021, 17026, 17034, 17035, 17036, 17037, 17038, 17057, 17058,
    5175, 5176, 5177, 5178,
})
-- Kinds of item never offered: bags, gems, reagents, ammo, crafting
-- materials, recipes, quivers, quest items, keys.
local KEEP_CLASSES = Set({ 1, 3, 5, 6, 7, 9, 11, 12, 13 })
local CONSUMABLE, WEAPON, ARMOR = 0, 2, 4
local FISHING_POLE = 20
local EPIC = 4

-- What eating or drinking an item casts.
local FOOD_SPELLS = { ["Food"] = "food", ["Drink"] = "drink", ["Food & Drink"] = "both", ["Refreshment"] = "both" }

local function FoodKind(itemID)
    local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not getSpell then return end
    local ok, spell = pcall(getSpell, itemID)
    if ok and Usable(spell) and type(spell) == "string" then return FOOD_SPELLS[spell] end
end

-- The text on a bag item's tooltip, line by line.
local function TooltipLines(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return {} end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return {} end
    local lines = {}
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if Usable(text) and type(text) == "string" then lines[#lines + 1] = text end
    end
    return lines
end

-- Buff food says on its tooltip that you will become well fed.
local function IsBuffFood(bag, slot)
    for _, text in ipairs(TooltipLines(bag, slot)) do
        if text:lower():find("well fed", 1, true) then return true end
    end
    return false
end

-- Gear with a special effect: a "Use:", "Equip:" or "Chance on hit:" line
-- (Riding Gloves, a Carrot on a Stick, a fishing hat), or resistances.
-- The game's own words for these, so it works in every language.
local function HasEffect(item)
    local triggers = {}
    for _, word in ipairs({ ITEM_SPELL_TRIGGER_ONUSE or "Use:", ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:",
            ITEM_SPELL_TRIGGER_ONPROC or "Chance on hit:" }) do
        if type(word) == "string" and word ~= "" then triggers[#triggers + 1] = word end
    end
    for _, text in ipairs(TooltipLines(item.bag, item.slot)) do
        for _, word in ipairs(triggers) do
            if text:sub(1, #word) == word then return true end
        end
    end
    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    if getStats and item.link then
        local ok, stats = pcall(getStats, item.link)
        if ok and type(stats) == "table" then
            for key in pairs(stats) do
                if type(key) == "string" and key:find("RESISTANCE", 1, true) then return true end
            end
        end
    end
    return false
end

-- Every item in the player's equipment sets.
local function SetItems()
    local ids, sets = {}, C_EquipmentSet
    if not (sets and sets.GetEquipmentSetIDs and sets.GetItemIDs) then return ids end
    local ok, list = pcall(sets.GetEquipmentSetIDs)
    for _, setID in ipairs(ok and type(list) == "table" and list or {}) do
        local found, items = pcall(sets.GetItemIDs, setID)
        if found and type(items) == "table" then
            for _, id in pairs(items) do
                if Number(id) then ids[id] = true end
            end
        end
    end
    return ids
end

-- Gear: which slots an item goes in, and who can wear it.
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
    INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}
-- The heaviest armour a class wears: from level 40, and before.
local ARMOR_TYPES = {
    WARRIOR = { 4, 3 }, PALADIN = { 4, 3 }, HUNTER = { 3, 2 }, SHAMAN = { 3, 2 },
    ROGUE = { 2, 2 }, DRUID = { 2, 2 }, MAGE = { 1, 1 }, PRIEST = { 1, 1 }, WARLOCK = { 1, 1 },
}
local SHIELDS = Set({ "WARRIOR", "PALADIN", "SHAMAN" })
-- Weapon kinds each class can learn: axes 0/1, bow 2, gun 3, maces 4/5,
-- polearm 6, swords 7/8, staff 10, fist 13, dagger 15, thrown 16,
-- crossbow 18, wand 19.
local WEAPONS = {
    WARRIOR = Set({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }),
    PALADIN = Set({ 0, 1, 4, 5, 6, 7, 8 }),
    HUNTER = Set({ 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }),
    ROGUE = Set({ 2, 3, 4, 7, 13, 15, 16, 18 }),
    PRIEST = Set({ 4, 10, 15, 19 }),
    SHAMAN = Set({ 0, 1, 4, 5, 10, 13, 15 }),
    MAGE = Set({ 7, 10, 15, 19 }),
    WARLOCK = Set({ 7, 10, 15, 19 }),
    DRUID = Set({ 4, 5, 10, 13, 15 }),
}

local function Context()
    local level = UnitLevel and Number(UnitLevel("player")) or 1
    local class
    if UnitClass then class = select(2, UnitClass("player")) end
    return { level = level, class = Usable(class) and class or nil }
end

function ns.CanWear(facts, context)
    local class, sub = context.class, facts.subclassID
    if facts.classID == ARMOR then
        if facts.equipLoc == "INVTYPE_CLOAK" or not sub or sub == 0 then return true end
        if sub == 6 then return class == nil or SHIELDS[class] == true end
        if sub >= 1 and sub <= 4 then
            local types = class and ARMOR_TYPES[class]
            if not types then return true end
            return sub <= (context.level >= 40 and types[1] or types[2])
        end
        return true
    elseif facts.classID == WEAPON then
        local allowed = class and WEAPONS[class]
        if not allowed or sub == 14 then return true end
        return allowed[sub] == true
    end
    return false
end

-- Gear this character can wear with a higher item level than what it has
-- on in that slot (for rings and trinkets, the weaker of the two).
function ns.IsUpgrade(facts, context)
    if facts.classID ~= ARMOR and facts.classID ~= WEAPON then return false end
    local slots = facts.equipLoc and SLOTS[facts.equipLoc]
    if not slots or not facts.itemLevel or not ns.CanWear(facts, context) then return false end
    local weakest
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local level = 0
        if link then
            local worn = ns.ItemFacts(link)
            -- What is worn cannot be read: assume it is better.
            level = worn and worn.itemLevel or math.huge
        end
        if not weakest or level < weakest then weakest = level end
    end
    return facts.itemLevel > (weakest or math.huge)
end

-- The item level of what is worn where gear would go (for rings and
-- trinkets, the weaker of the two), or nil.
local function WornLevel(facts)
    local slots = facts.equipLoc and SLOTS[facts.equipLoc]
    if not slots or not GetInventoryItemLink then return end
    local weakest
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        local worn = link and ns.ItemFacts(link)
        if worn and worn.itemLevel and (not weakest or worn.itemLevel < weakest) then weakest = worn.itemLevel end
    end
    return weakest
end

local ARMOR_NAMES = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate", [6] = "shields" }

-- Why a kind of item is always kept.
local CLASS_REASONS = {
    [1] = "a bag", [3] = "a gem", [5] = "a reagent", [6] = "ammo", [7] = "a crafting material",
    [9] = "a recipe", [11] = "a quiver", [12] = "a quest item", [13] = "a key",
}

local survey   -- the last look through the bags, for tooltips

-- Normally kept, but everyday enough to give up for a quest reward or a
-- quest item when nothing else could go.
local SPARE_REASONS = {
    ["a crafting material"] = true, ["a potion or other consumable"] = true,
    ["your best food or drink for your level"] = true, ["buff food"] = true,
}

function ns.InvalidateSurvey()
    survey = nil
end

-- A look through the bags: every item gets either a tier (1 grey, 2
-- outgrown food or drink, 3 gear) and a description, or the reason it is
-- kept. Returns { list = the items that could go, cheapest first, with
-- their rank; bySlot = every item by "bag:slot" }. Kept until the bags,
-- gear, level or equipment sets change; fresh = look again regardless.
function ns.Survey(fresh)
    if survey and not fresh then return survey end
    local context = Context()
    local keep = ns.db and ns.db.keep or {}
    local inSets = SetItems()
    local items = {}
    local best = { food = -1, drink = -1 }
    for _, item in ipairs(ns.BagItems()) do
        item.facts = ns.ItemFacts(item.itemID)
        items[#items + 1] = item
        local facts = item.facts
        if facts and facts.classID == CONSUMABLE and (item.quality or facts.quality or 1) > 0 then
            item.food = FoodKind(item.itemID)
            if item.food then
                item.buff = IsBuffFood(item.bag, item.slot)
                if not item.buff and facts.minLevel <= context.level then
                    for _, kind in ipairs({ "food", "drink" }) do
                        if item.food == kind or item.food == "both" then
                            best[kind] = math.max(best[kind], facts.minLevel)
                        end
                    end
                end
            end
        end
    end

    local function IsBestFood(item)
        local level = item.facts.minLevel
        if item.food == "both" then return level >= best.food or level >= best.drink end
        return level >= best[item.food]
    end

    -- tier and description, or nil and the reason it is kept.
    local function Judge(item)
        local facts = item.facts
        if not facts or item.locked then return end
        if keep[item.itemID] then return nil, "on your keep list" end
        if item.opens then return nil, "it opens; JunkMate opens it when your bags get full" end
        if C_Container.GetContainerItemQuestInfo then
            local ok, quest = pcall(C_Container.GetContainerItemQuestInfo, item.bag, item.slot)
            if ok and type(quest) == "table" and (quest.isQuestItem or quest.questID) then return nil, "a quest item" end
        end
        if facts.classID == 12 then return nil, "a quest item" end
        if TOOLS[item.itemID] then return nil, "a profession tool" end
        if KEEP[item.itemID] then return nil, "always kept" end
        local quality = item.quality or facts.quality
        if quality == 0 then
            item.detail = "it's grey junk"
            return 1, "a grey item"
        end
        if not quality then return end
        if quality >= EPIC then return nil, "epic or better" end
        if not facts.classID then return end
        if CLASS_REASONS[facts.classID] then return nil, CLASS_REASONS[facts.classID] end
        if facts.classID == CONSUMABLE then
            if not item.food then return nil, "a potion or other consumable" end
            if item.buff then return nil, "buff food" end
            if IsBestFood(item) then return nil, "your best food or drink for your level" end
            local better = item.food == "food" and best.food or item.food == "drink" and best.drink or math.max(best.food, best.drink)
            item.detail = ("it's %s you've outgrown (level %d; you also carry level %d)"):format(
                item.food == "drink" and "drink" or "food", facts.minLevel, better)
            return 2, "outgrown food or drink"
        end
        if facts.classID == WEAPON or facts.classID == ARMOR then
            if facts.classID == WEAPON and facts.subclassID == FISHING_POLE then return nil, "a profession tool" end
            if inSets[item.itemID] then return nil, "in an equipment set" end
            if quality >= 2 and item.bound ~= true then return nil, "bind on equip, worth more at the auction house" end
            if HasEffect(item) then return nil, "it has a special effect" end
            if ns.IsUpgrade(facts, context) then return nil, "an upgrade for you" end
            item.wearable = ns.CanWear(facts, context)
            if item.wearable then
                local worn = WornLevel(facts)
                item.detail = worn and ("it's no upgrade (item level %d; what you wear there is %d)"):format(facts.itemLevel or 0, worn)
                    or "it's no upgrade"
            else
                item.detail = ("your class can't use %s"):format(
                    facts.classID == ARMOR and ARMOR_NAMES[facts.subclassID] or "this kind of weapon")
            end
            return 3, item.wearable and "gear that's no upgrade" or "gear you can't use"
        end
        return nil, "not junk"
    end

    local list, bySlot, spare = {}, {}, {}
    for _, item in ipairs(items) do
        item.tier, item.reason = Judge(item)
        bySlot[item.bag .. ":" .. item.slot] = item
        if item.tier or SPARE_REASONS[item.reason] then
            item.value = item.noValue and 0 or item.facts.price * item.count
            item.name = item.facts.name
            item.link = item.link or item.facts.link or item.facts.name
            if item.tier then list[#list + 1] = item else spare[#spare + 1] = item end
        end
    end
    table.sort(spare, function(a, b)
        if a.value ~= b.value then return a.value < b.value end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.value ~= b.value then return a.value < b.value end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    for rank, item in ipairs(list) do item.rank = rank end
    survey = { list = list, bySlot = bySlot, spare = spare }
    return survey
end

-- Which items JunkMate would destroy to make room, in the order it would
-- offer them (see ns.Survey).
function ns.RoomCandidates()
    return ns.Survey(true).list
end

-- Sold at a vendor, besides junk: outgrown food and drink, and gear this
-- character can't use.
function ns.IsExtraSale(item)
    return (item.tier == 2 or (item.tier == 3 and item.wearable == false)) and (item.value or 0) > 0
end

----------------------------------------------------------------------------
-- Selling more than junk at a vendor
----------------------------------------------------------------------------

-- The vendor's Buyback tab holds 12 items, so never more than that a visit:
-- anything sold can still be bought back.
local MAX_EXTRA_SALES = 12
local EXTRA_SELL_INTERVAL = 0.2
local extraTicker

function ns.SellExtras()
    if extraTicker or not (ns.db and ns.db.sellExtras and ns.merchantOpen) then return end
    local list = {}
    for _, item in ipairs(ns.Survey(true).list) do
        if ns.IsExtraSale(item) and #list < MAX_EXTRA_SALES then list[#list + 1] = item end
    end
    if #list == 0 then return end
    local index, sold, earned = 0, 0, 0
    extraTicker = C_Timer.NewTicker(EXTRA_SELL_INTERVAL, function(ticker)
        index = index + 1
        local item = list[index]
        if not item or not ns.merchantOpen then
            ticker:Cancel()
            extraTicker = nil
            if sold > 0 and ns.db.report then
                ns.Print(("Also sold %d outgrown or unusable item%s for %s. Changed your mind? They're on the vendor's Buyback tab.")
                    :format(sold, sold == 1 and "" or "s", ns.Money(earned)))
            end
            return
        end
        -- Still the same item and amount, or it is left alone.
        local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if type(info) == "table" and info.itemID == item.itemID and (info.stackCount or 1) == item.count and not info.isLocked then
            C_Container.UseContainerItem(item.bag, item.slot)
            sold, earned = sold + 1, earned + item.value
        end
    end)
end

----------------------------------------------------------------------------
-- What JunkMate would do with an item, on its tooltip
----------------------------------------------------------------------------

local function Ordinal(n)
    local suffix = "th"
    if n % 100 < 11 or n % 100 > 13 then
        local last = n % 10
        suffix = last == 1 and "st" or last == 2 and "nd" or last == 3 and "rd" or "th"
    end
    return n .. suffix
end

-- The bag and slot of the bag button a tooltip belongs to.
local function BagSlotOf(tooltip)
    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    if not ok or type(owner) ~= "table" then return end
    local bag, slot
    if owner.GetBagID then
        local found, id = pcall(owner.GetBagID, owner)
        if found then bag = id end
    end
    if bag == nil and owner.GetParent then
        local found, parent = pcall(owner.GetParent, owner)
        if found and type(parent) == "table" and parent.GetID then bag = parent:GetID() end
    end
    if owner.GetID then slot = owner:GetID() end
    bag, slot = Number(bag), Number(slot)
    if bag and slot and bag >= FIRST_BAG and bag <= LAST_BAG and slot >= 1 then return bag, slot end
end

-- The tooltip line for the item in a bag slot, or nil.
function ns.WhyLine(bag, slot, itemID)
    local item = ns.Survey().bySlot[bag .. ":" .. slot]
    if not item or item.itemID ~= itemID then
        item = ns.Survey(true).bySlot[bag .. ":" .. slot]
        if not item or item.itemID ~= itemID then return end
    end
    if item.tier then
        local sold = (item.tier == 1 and ns.db.sellJunk) or (ns.db.sellExtras and ns.IsExtraSale(item))
        local text = ("%s to go if your bags fill (%s)"):format(Ordinal(item.rank), item.reason)
        return "JunkMate: " .. (sold and ("sold at vendors; " .. text) or text)
    elseif item.reason then
        return "JunkMate keeps this: " .. item.reason
    end
end

function ns.AddWhyLine(tooltip, data)
    if not (ns.db and ns.db.whyTooltip) or tooltip ~= GameTooltip then return end
    local itemID = data and data.id
    if not Number(itemID) then return end
    local bag, slot = BagSlotOf(tooltip)
    if not bag then return end
    local line = ns.WhyLine(bag, slot, itemID)
    if not line then return end
    tooltip:AddLine(line, 0.85, 0.63, 0.40, true)
    tooltip:Show()
end

----------------------------------------------------------------------------
-- The loot that would not fit
----------------------------------------------------------------------------

-- The most wanted item left in the open loot window: { slot, link, count,
-- score, value }. Quest items score 4, crafting materials 3, green or
-- better and upgrades 2, anything else 1.
function ns.LootWanted(skip)
    if not (GetNumLootItems and GetLootSlotInfo and GetLootSlotLink) then return end
    local count = Number(GetNumLootItems()) or 0
    local context, best = Context(), nil
    for slot = 1, count do if slot ~= skip then
        local ok, _, name, quantity, currencyID, quality, _, isQuestItem, questID = pcall(GetLootSlotInfo, slot)
        local okLink, link = pcall(GetLootSlotLink, slot)
        if ok and okLink and Usable(link) and type(link) == "string" and not Number(currencyID) then
            local facts = ns.ItemFacts(link)
            quality = Number(quality) or (facts and facts.quality) or 1
            local score = 1
            if isQuestItem or Number(questID) or (facts and facts.classID == 12) then
                score = 4
            elseif facts and facts.classID == 7 then
                score = 3
            elseif quality >= 2 or (facts and ns.IsUpgrade(facts, context)) then
                score = 2
            end
            local amount = Number(quantity) or 1
            local value = (facts and facts.price or 0) * amount
            if not best or score > best.score or (score == best.score and value > best.value) then
                best = { slot = slot, link = link, name = Usable(name) and name or link, count = amount, score = score, value = value }
            end
        end
    end end
    return best
end

-- Worth destroying `item` for `loot`: always for quest items, crafting
-- materials, green or better and upgrades; otherwise only if the loot is
-- worth more.
function ns.WorthIt(loot, item)
    if not loot then return true end
    if loot.score >= 2 then return true end
    return loot.value > item.value
end

----------------------------------------------------------------------------
-- The window
----------------------------------------------------------------------------

local current            -- { item, loot } on offer
local skipped = {}       -- bag:slot passed over with "Not this one"
local armedAt = 0
local said = false       -- a "nothing to destroy" line already said for this loot
ns.pendingLoot = nil     -- loot slot to take once the bags have room
ns.destroyed = {}        -- this session's destroyed items, for /junkmate destroyed

local window = CreateFrame("Frame", "JunkMateRoom", UIParent)
window:SetSize(380, 216)
-- Out of the middle of the screen: on the left, above the chat. Drag it
-- anywhere; it remembers.
local function PlaceWindow()
    window:ClearAllPoints()
    local saved = ns.db and ns.db.roomPoint
    if type(saved) == "table" and saved[1] then
        window:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        window:SetPoint("LEFT", UIParent, "LEFT", 30, 60)
    end
end
ns.PlaceRoomWindow = PlaceWindow
PlaceWindow()

-- Where to open for an offer: beside the loot window (or the quest window,
-- for a quest reward) while one is open, so it's where you're looking;
-- your own spot if you've dragged it; otherwise the usual place.
local function PositionForOffer(loot)
    if ns.db and type(ns.db.roomPoint) == "table" and ns.db.roomPoint[1] then
        PlaceWindow()
        return
    end
    local beside
    for _, name in ipairs(loot and loot.quest and { "QuestFrame", "GossipFrame" } or { "LootFrame" }) do
        local frame = _G[name]
        if type(frame) == "table" and frame.IsShown and frame:IsShown() then beside = frame break end
    end
    if not beside then
        PlaceWindow()
        return
    end
    window:ClearAllPoints()
    -- On whichever side has more room.
    local x = beside.GetCenter and beside:GetCenter()
    local middle = UIParent.GetWidth and (UIParent:GetWidth() or 0) / 2 or 0
    if type(x) == "number" and x > middle then
        window:SetPoint("TOPRIGHT", beside, "TOPLEFT", -10, 0)
    else
        window:SetPoint("TOPLEFT", beside, "TOPRIGHT", 10, 0)
    end
end
window:SetFrameStrata("DIALOG")
window:SetToplevel(true)
window:SetClampedToScreen(true)
window:EnableMouse(true)
window:SetMovable(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", window.StartMoving)
window:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    if ns.db then ns.db.roomPoint = { point, relativePoint, x, y } end
end)
window:Hide()
ns.Fill(window, 0.05, 0.05, 0.06, 0.97)
ns.Outline(window, 0.7)
tinsert(UISpecialFrames, "JunkMateRoom")

window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
window.title:SetPoint("TOPLEFT", 14, -12)
window.title:SetText("Make room?")

local close = CreateFrame("Button", nil, window)
close:SetSize(30, 30)
close:SetPoint("TOPRIGHT", -2, -2)
local closeHover = close:CreateTexture(nil, "HIGHLIGHT")
closeHover:SetAllPoints()
closeHover:SetColorTexture(0.9, 0.2, 0.2, 0.45)
local closeLabel = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
closeLabel:SetPoint("CENTER")
closeLabel:SetText("x")
close:SetScript("OnClick", function() window:Hide() end)

-- The item on offer: hover it for its tooltip.
window.icon = CreateFrame("Button", nil, window)
window.icon:SetSize(36, 36)
window.icon:SetPoint("TOPLEFT", 14, -42)
window.icon.texture = window.icon:CreateTexture(nil, "ARTWORK")
window.icon.texture:SetAllPoints()
window.icon:SetScript("OnEnter", function(self)
    if not current then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetBagItem, GameTooltip, current.item.bag, current.item.slot)
    GameTooltip:Show()
end)
window.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

window.what = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
window.what:SetPoint("TOPLEFT", window.icon, "TOPRIGHT", 10, 0)
window.what:SetPoint("RIGHT", -14, 0)
window.what:SetJustifyH("LEFT")
window.what:SetWordWrap(true)
window.why = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
window.why:SetPoint("TOPLEFT", window.what, "BOTTOMLEFT", 0, -4)
window.why:SetPoint("RIGHT", -14, 0)
window.why:SetJustifyH("LEFT")
window.why:SetWordWrap(true)
window.reason = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
window.reason:SetPoint("TOPLEFT", window.why, "BOTTOMLEFT", 0, -6)
window.reason:SetPoint("RIGHT", -14, 0)
window.reason:SetJustifyH("LEFT")
window.reason:SetWordWrap(true)
window.reason:SetTextColor(0.85, 0.63, 0.40)

local function Button(name, label, x)
    local button = CreateFrame("Button", name, window)
    button:SetSize(112, 26)
    button:SetPoint("BOTTOMLEFT", x, 30)
    ns.Fill(button, 1, 1, 1, 0.07)
    ns.Outline(button, 0.45)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.12)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("CENTER")
    button.label:SetText(label)
    return button
end
window.destroy = Button("JunkMateRoomDestroy", "|cffff6666Destroy|r", 14)
window.next = Button("JunkMateRoomNext", "Not this one", 134)
window.keep = Button("JunkMateRoomKeep", "Keep always", 254)
-- Shown when there are two or more grey items: one press for all of them.
window.greys = Button("JunkMateRoomGreys", "", 14)
window.greys:SetSize(352, 24)
window.greys:ClearAllPoints()
window.greys:SetPoint("BOTTOMLEFT", 14, 62)
window.greys:Hide()
local BASE_HEIGHT = 216

local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", 14, 11)
local PAD_HINT = "Controller: Y destroy, D-pad up all greys, RB next, LB keep, B close"
hint:SetText(PAD_HINT)

-- Tucked away during a fight: the offer waits, hidden, and comes back
-- once the fight is over.
local tucked = false
local inFight = false
window:HookScript("OnHide", function()
    if tucked then return end
    current = nil
    skipped = {}
end)
window:HookScript("OnShow", function()
    if not window.placed then
        PlaceWindow()
        window.placed = true
    end
end)
-- Not A, X or B's loot-window jobs (A loot, X loot all): Y destroys, the
-- shoulder buttons skip or keep.
ns.CloseWithPadB(window, { PAD4 = "JunkMateRoomDestroy", PADRSHOULDER = "JunkMateRoomNext", PADLSHOULDER = "JunkMateRoomKeep",
    PADDUP = "JunkMateRoomGreys" })

-- 2. The buttons stay dimmed for the short pause in which presses don't
-- count, then light up.
local function Arm(seconds)
    armedAt = GetTime() + seconds
    for _, button in ipairs({ window.destroy, window.next, window.keep, window.greys }) do
        button:SetAlpha(0.35)
        button.dimmed = true
    end
    C_Timer.After(seconds, function()
        if GetTime() < armedAt then return end
        for _, button in ipairs({ window.destroy, window.next, window.keep, window.greys }) do
            button:SetAlpha(1)
            button.dimmed = false
        end
    end)
end

-- A quest item that will not fit: offered at once, even in a fight.
function ns.IsEmergency(loot)
    return loot ~= nil and loot.score >= 4
end

local function Say(text, always)
    if said and not always then return end
    said = true
    ns.Print(text)
end

local function Amount(item)
    return item.count > 1 and (" x%d"):format(item.count) or ""
end

local GROUPS = { "grey items", "outgrown foods and drinks", "pieces of gear JunkMate would let go" }
local LEADS = { "", "with no grey items to offer, ", "with no grey items or outgrown food to offer, " }

-- Why JunkMate offers this item and not another, and what would go next.
local function Explain(pick, list, spareReason)
    local same, nextUp, seen = 0, nil, false
    for _, item in ipairs(list) do
        if not skipped[item.bag .. ":" .. item.slot] then
            if item == pick then
                seen = true
            elseif seen and not nextUp then
                nextUp = item
            end
            if item.tier and item.tier == pick.tier then same = same + 1 end
        end
    end
    local why
    if spareReason then
        why = "Why this one: nothing junk is left, and it's the cheapest everyday thing you could spare."
    else
        why = ("Why this one: %s%s%s."):format(LEADS[pick.tier] or "", pick.detail or pick.reason or "it could go",
            same > 1 and ("; the cheapest of %d %s"):format(same, GROUPS[pick.tier]) or "")
    end
    if nextUp then
        why = why .. ("\n|cffaaaaaaNext in line: %s%s (worth %s).|r"):format(nextUp.link, Amount(nextUp),
            nextUp.value > 0 and ns.Money(nextUp.value) or "nothing")
    end
    return why
end

-- Puts the next thing JunkMate would destroy in the window, to make room
-- for `loot` (or just to free a slot). Returns whether it shows anything.
function ns.OfferRoom(loot, always, force)
    local found = ns.Survey(true)
    local pick, spareReason
    for _, item in ipairs(found.list) do
        if not skipped[item.bag .. ":" .. item.slot] then
            pick = item
            break
        end
    end
    -- For a quest reward or a quest item, when nothing else could go: the
    -- cheapest everyday thing normally kept, marked as such.
    if not pick and loot and loot.score >= 4 then
        for _, item in ipairs(found.spare) do
            if not skipped[item.bag .. ":" .. item.slot] then
                pick, spareReason = item, item.reason
                break
            end
        end
    end
    if not pick then
        window:Hide()
        if loot and loot.quest then
            Say(("There's no room for the reward from %s, and nothing in your bags JunkMate could throw away. Clear your bags at a vendor or the bank first and come back.")
                :format(loot.link), always)
        else
            Say(loot and "Your bags are full, and nothing in them is something JunkMate would throw away."
                or "There is nothing in your bags JunkMate would throw away.", always)
        end
        return false
    end
    if not force and not ns.WorthIt(loot, pick) then
        window:Hide()
        Say(("Your bags are full. %s is worth less than %s, the cheapest thing JunkMate would throw away, so it stays on the ground. %s")
            :format(loot.link, pick.link, ns.ActionLink("room", "Make room anyway")), always)
        return false
    end
    current = { item = pick, loot = loot }
    -- Two or more grey items: offer them all at once.
    local greys, worth = {}, 0
    if not spareReason then
        for _, item in ipairs(found.list) do
            if item.tier == 1 and not skipped[item.bag .. ":" .. item.slot] then
                greys[#greys + 1] = item
                worth = worth + (item.value or 0)
            end
        end
    end
    current.greys = #greys >= 2 and greys or nil
    if current.greys then
        window.greys.label:SetText(("Destroy all %d grey items (worth %s)"):format(#greys, worth > 0 and ns.Money(worth) or "nothing"))
        window.greys:Show()
        window:SetHeight(BASE_HEIGHT + 30)
    else
        window.greys:Hide()
        window:SetHeight(BASE_HEIGHT)
    end
    window.reason:SetText(Explain(pick, spareReason and found.spare or found.list, spareReason))
    window.icon.texture:SetTexture(pick.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    window.what:SetText(("Destroy %s%s (worth %s)?"):format(pick.link, Amount(pick), pick.value > 0 and ns.Money(pick.value) or "nothing"))
    if loot and loot.quest then
        window.why:SetText(("To make room for the reward from %s.%s\n|cffaaaaaaOr clear your bags at a vendor first and come back.|r")
            :format(loot.link, spareReason and ("\n|cffff9933Normally kept: %s.|r"):format(spareReason) or ""))
    elseif loot then
        window.why:SetText(("To make room for %s%s%s.%s"):format(loot.link, loot.count > 1 and (" x%d"):format(loot.count) or "",
            loot.value > 0 and (" (worth %s)"):format(ns.Money(loot.value)) or "",
            spareReason and ("\n|cffff9933Normally kept: %s.|r"):format(spareReason) or ""))
    else
        window.why:SetText("To free a bag slot.")
    end
    Arm(ARM_SECONDS)
    local emergency = ns.IsEmergency(loot)
    window.title:SetText(loot and loot.quest and "|cffffd100Make room for your quest reward?|r"
        or emergency and "|cffffd100Make room for the quest item?|r" or "Make room?")
    hint:SetText(inFight and "In a fight: click Destroy, or press your JunkMate key binding" or PAD_HINT)
    if inFight and not emergency then
        if not tucked then
            tucked = true
            window:Hide()
            ns.Print("JunkMate will offer to make room once the fight is over.")
        end
        return true
    end
    PositionForOffer(loot)
    window:Show()
    return true
end

-- Destroys the item on offer, after checking it is still where it was.
local function DestroyCurrent()
    if not current or GetTime() < armedAt then return end
    local item, loot = current.item, current.loot
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    -- Still the same item and the same amount (a restack may have added to
    -- the stack since): otherwise look again, rather than destroy more than
    -- the window said.
    if type(info) ~= "table" or info.itemID ~= item.itemID or info.isLocked or (info.stackCount or 1) ~= item.count then
        ns.OfferRoom(loot, true)
        return
    end
    if CursorHasItem() then
        ns.Print("You are holding an item. Put it down first; nothing was destroyed.")
        return
    end
    C_Container.PickupContainerItem(item.bag, item.slot)
    local kind, held = GetCursorInfo()
    if kind ~= "item" or held ~= item.itemID then
        if CursorHasItem() then ClearCursor() end
        ns.Print("JunkMate could not pick that up, so nothing was destroyed.")
        return
    end
    pcall(DeleteCursorItem)
    if CursorHasItem() then
        ClearCursor()
        ns.Print("The game would not let JunkMate destroy that, so nothing was lost.")
        return
    end
    ns.destroyed[#ns.destroyed + 1] = { link = item.link, count = item.count, value = item.value }
    ns.Print(("Destroyed %s%s (worth %s) to make room."):format(item.link, Amount(item), ns.Money(item.value)))
    ns.pendingLoot = loot and loot.slot or nil
    ns.pendingQuest = loot and loot.quest or false
    window:Hide()
end

-- Destroys every grey item on offer, one after another, checking each is
-- still what it was. Stops at the first the game won't let go.
local function DestroyGreys()
    if not (current and current.greys) or GetTime() < armedAt then return end
    if CursorHasItem() then
        ns.Print("You are holding an item. Put it down first; nothing was destroyed.")
        return
    end
    local loot = current.loot
    local count, worth, stopped = 0, 0, nil
    for _, item in ipairs(current.greys) do
        local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if type(info) == "table" and info.itemID == item.itemID and not info.isLocked and (info.stackCount or 1) == item.count then
            C_Container.PickupContainerItem(item.bag, item.slot)
            local kind, held = GetCursorInfo()
            if kind ~= "item" or held ~= item.itemID then
                if CursorHasItem() then ClearCursor() end
                stopped = "JunkMate could not pick one up"
                break
            end
            pcall(DeleteCursorItem)
            if CursorHasItem() then
                ClearCursor()
                stopped = "the game wouldn't let JunkMate destroy more"
                break
            end
            ns.destroyed[#ns.destroyed + 1] = { link = item.link, count = item.count, value = item.value }
            count, worth = count + 1, worth + (item.value or 0)
        end
    end
    if count == 0 then
        ns.Print("Nothing was destroyed" .. (stopped and (": " .. stopped) or "") .. ".")
        ns.OfferRoom(loot, true)
        return
    end
    ns.Print(("Destroyed %d grey item%s (worth %s) to make room.%s"):format(count, count == 1 and "" or "s",
        ns.Money(worth), stopped and (" Stopped: " .. stopped .. ".") or ""))
    ns.pendingLoot = loot and loot.slot or nil
    ns.pendingQuest = loot and loot.quest or false
    window:Hide()
end

window.greys:SetScript("OnClick", function()
    local ok, problem = pcall(DestroyGreys)
    if not ok then
        if CursorHasItem and CursorHasItem() then pcall(ClearCursor) end
        ns.Print("Something went wrong, so nothing more was destroyed: " .. tostring(problem))
    end
end)

local function OnDestroy()
    local ok, problem = pcall(DestroyCurrent)
    if not ok then
        if CursorHasItem and CursorHasItem() then pcall(ClearCursor) end
        ns.Print("Something went wrong, so nothing was destroyed: " .. tostring(problem))
    end
end
window.destroy:SetScript("OnClick", OnDestroy)

-- The key binding (Key Bindings > AddOns > JunkMate), which works in a fight.
function JunkMate_DestroyOffered()
    if window:IsShown() then OnDestroy() end
end
window.next:SetScript("OnClick", function()
    if not current or GetTime() < armedAt then return end
    local item, loot = current.item, current.loot
    skipped[item.bag .. ":" .. item.slot] = true
    ns.OfferRoom(loot, true)
end)
window.keep:SetScript("OnClick", function()
    if not current or GetTime() < armedAt then return end
    local item, loot = current.item, current.loot
    ns.db.keep[item.itemID] = true
    ns.InvalidateSurvey()
    ns.Print(("JunkMate will never offer %s again. /junkmate keep lists what it keeps."):format(item.link))
    ns.OfferRoom(loot, true)
end)

----------------------------------------------------------------------------
-- When loot will not fit
----------------------------------------------------------------------------

local function LootOpen()
    return GetNumLootItems and (Number(GetNumLootItems()) or 0) > 0
end

local retried = {}     -- loot slots already tried again with room in the bags
local OnBagsFull

-- After room was made and `slot` looted: anything else on the corpse that
-- still won't fit gets its own offer, as if it had just failed to loot.
local function LootAndContinue(slot)
    if LootSlot then pcall(LootSlot, slot) end
    C_Timer.After(0.6, function()
        if not LootOpen() or window:IsShown() then return end
        local loot = ns.LootWanted(slot)
        if not loot then return end
        local ok, problem = pcall(OnBagsFull, slot)
        if not ok then ns.Print("Something went wrong making room: " .. tostring(problem)) end
    end)
end

function OnBagsFull(skip)
    if not (ns.db and ns.db.makeRoom) or window:IsShown() or not LootOpen() then return end
    if restackTicker then
        -- Already restacking: look again once that is done.
        C_Timer.After(0.5, function() pcall(OnBagsFull, skip) end)
        return
    end
    local loot = ns.LootWanted(skip)
    if not loot then return end
    -- Room already (a restack just finished, say): take it. Only once per
    -- item, so a loot that keeps failing cannot loop; destroying something
    -- would not help it either.
    local okFree, free = pcall(ns.FreeBagSlots)
    if okFree and free and free > 0 then
        if not retried[loot.slot] and LootSlot then
            retried[loot.slot] = true
            pcall(LootSlot, loot.slot)
        end
        return
    end
    -- Restacking loses nothing, so it comes first; but not for a quest item
    -- in a fight, where it would take too long.
    local _, freed = ns.RestackPlan()
    if freed > 0 and not (inFight and ns.IsEmergency(loot)) then
        ns.Restack(function(slots)
            SayRestacked(slots)
            if LootOpen() then LootAndContinue(loot.slot) end
        end)
        return
    end
    ns.OfferRoom(loot)
end

----------------------------------------------------------------------------
-- When a quest reward will not fit
----------------------------------------------------------------------------

-- Handing in a quest with full bags fails ("Goretusk Liver Pie failed:
-- Inventory is full.") and the quest window closes. When the reward window
-- opens, JunkMate notes how many bag slots the rewards need (a reward that
-- stacks onto one you carry needs none; a choice of rewards needs one). If
-- the bags are short, or the hand-in fails, it restacks or offers to make
-- room until there is enough. Then, if the quest window is still open and
-- there is no reward to choose, it hands the quest in; otherwise it says
-- to talk to the quest giver again. It never chooses a reward for you.

local questOpen = false
local lastQuest       -- { title, need, choices, seen } from the reward window
ns.pendingQuest = false

-- Bag slots the open quest's rewards need, and how many rewards there are
-- to choose from.
function ns.QuestRewardSlots()
    local rewards = GetNumQuestRewards and Number(GetNumQuestRewards()) or 0
    local choices = GetNumQuestChoices and Number(GetNumQuestChoices()) or 0
    local room = {}   -- itemID -> room left in the partial stacks carried
    for _, item in ipairs(ns.BagItems()) do
        local facts = ns.ItemFacts(item.itemID)
        if facts and facts.maxStack > item.count then
            room[item.itemID] = (room[item.itemID] or 0) + facts.maxStack - item.count
        end
    end
    local need = choices > 0 and 1 or 0
    for index = 1, rewards do
        local count = 1
        if GetQuestItemInfo then
            local ok, _, _, amount = pcall(GetQuestItemInfo, "reward", index)
            if ok and Number(amount) then count = amount end
        end
        local itemID
        if GetQuestItemLink then
            local ok, link = pcall(GetQuestItemLink, "reward", index)
            if ok and Usable(link) and type(link) == "string" then itemID = tonumber(link:match("item:(%d+)")) end
        end
        if itemID and (room[itemID] or 0) >= count then
            room[itemID] = room[itemID] - count
        else
            need = need + 1
        end
    end
    return need, choices
end

-- The game's "<quest> failed: Inventory is full." in this client's language.
local QUEST_FULL_PATTERN = "^" .. ((ERR_QUEST_FAILED_BAG_FULL_S or "%s failed: Inventory is full.")
    :gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", "(.+)")) .. "$"

function ns.QuestFailedFull(...)
    for index = 1, select("#", ...) do
        local text = select(index, ...)
        if Usable(text) and type(text) == "string" then
            local title = text:match(QUEST_FULL_PATTERN)
            if title then return title end
        end
    end
end

local function FreeSlots()
    local ok, free = pcall(ns.FreeBagSlots)
    return ok and free or 0
end

local function QuestAsLoot()
    return { quest = true, score = 4, value = 0, count = 1, link = lastQuest.title }
end

-- Is there room for the quest's rewards; if not, restack or offer to make
-- room. `handIn`: once there is room, hand it in (or say how).
local function OnQuestFull(handIn)
    if not (ns.db and ns.db.makeRoom) or not lastQuest or window:IsShown() then return end
    if restackTicker then
        C_Timer.After(0.5, function() pcall(OnQuestFull, handIn) end)
        return
    end
    if FreeSlots() >= lastQuest.need then
        if not handIn then return end
        if questOpen and lastQuest.choices == 0 and GetQuestReward then
            pcall(GetQuestReward, 0)
        elseif questOpen then
            ns.Print("There's room for your quest reward now: pick it and complete the quest.")
        else
            ns.Print(("There's room for the reward from %s now: talk to the quest giver again to hand it in."):format(lastQuest.title))
        end
        return
    end
    local _, freed = ns.RestackPlan()
    if freed > 0 then
        ns.Restack(function(slots)
            SayRestacked(slots)
            C_Timer.After(0.3, function() pcall(OnQuestFull, true) end)
        end)
        return
    end
    ns.OfferRoom(QuestAsLoot())
end
ns.OnQuestFull = OnQuestFull

function ns.OnQuestComplete()
    questOpen = true
    local title = GetTitleText and GetTitleText()
    local need, choices = ns.QuestRewardSlots()
    lastQuest = { title = Usable(title) and type(title) == "string" and title ~= "" and title or "this quest",
        need = need, choices = choices, seen = GetTime() }
    -- Short of room already: offer before the hand-in fails.
    if FreeSlots() < need then OnQuestFull(false) end
end

function ns.OnQuestFinished()
    questOpen = false
end

-- A hand-in failed: if the reward window was not seen (or was another
-- quest's), assume one slot is needed.
function ns.NoteFailedQuest(title)
    if not lastQuest or lastQuest.title ~= title then
        lastQuest = { title = title, need = 1, choices = 0, seen = GetTime() }
    end
end

-- /junkmate room: the same offer, by hand, for the loot window if open.
function ns.MakeRoomCommand()
    -- By hand: offered even when the loot is worth less ("make room anyway").
    if ns.Restack(function(slots)
        SayRestacked(slots)
        if slots == 0 then ns.OfferRoom(LootOpen() and ns.LootWanted() or nil, true, true) end
    end) then
        return
    end
    ns.OfferRoom(LootOpen() and ns.LootWanted() or nil, true, true)
end

-- What would go next if the bags filled: the item, and how many grey items
-- there are with what they're worth.
function ns.NextToGo()
    local list = ns.RoomCandidates()
    local greys, worth = 0, 0
    for _, item in ipairs(list) do
        if item.tier == 1 then greys, worth = greys + 1, worth + (item.value or 0) end
    end
    return list[1], greys, worth
end

-- /junkmate greys: the make-room window, with every grey item on offer.
function ns.GreysCommand()
    local _, greys = ns.NextToGo()
    if greys == 0 then
        ns.Print("No grey items in your bags.")
        return
    end
    ns.OfferRoom(LootOpen() and ns.LootWanted() or nil, true, true)
end

-- A clickable [text] in chat that runs /junkmate <action>, where the game
-- lets addons make their own links; otherwise the command to type.
local linkActions = { room = function() ns.MakeRoomCommand() end, greys = function() ns.GreysCommand() end }
local linksWork = false
if EventRegistry and EventRegistry.RegisterCallback then
    linksWork = pcall(EventRegistry.RegisterCallback, EventRegistry, "SetItemRef", function(_, link)
        local action = type(link) == "string" and link:match("^addon:JunkMate:(%a+)")
        if action and linkActions[action] then pcall(linkActions[action]) end
    end, ns)
end
function ns.ActionLink(action, text)
    if linksWork then
        return ("|cff66bbff|Haddon:JunkMate:%s|h[%s]|h|r"):format(action, text)
    end
    return ("(%s: /junkmate %s)"):format(text, action)
end

function ns.RestackCommand()
    if not ns.Restack(SayRestacked) then
        ns.Print("Nothing to restack: no partial stacks to put together.")
    end
end

local function IsBagsFullMessage(...)
    local full = ERR_INV_FULL or "Inventory is full."
    for index = 1, select("#", ...) do
        if select(index, ...) == full then return true end
    end
    return false
end

local waiting = false
local questWaiting = false
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if not ns.db then return end
    local failed = (event == "UI_ERROR_MESSAGE" or event == "CHAT_MSG_SYSTEM") and ns.QuestFailedFull(...)
    if failed then
        -- A quest hand-in failed for want of room (the game may say so twice).
        if questWaiting then return end
        questWaiting = true
        ns.NoteFailedQuest(failed)
        C_Timer.After(0.3, function()
            questWaiting = false
            local ok, problem = pcall(ns.OnQuestFull, true)
            if not ok then ns.Print("Something went wrong making room: " .. tostring(problem)) end
        end)
        return
    end
    if event == "CHAT_MSG_SYSTEM" then return end
    if event == "QUEST_COMPLETE" then
        local ok, problem = pcall(ns.OnQuestComplete)
        if not ok then ns.Print("Something went wrong making room: " .. tostring(problem)) end
        return
    elseif event == "QUEST_FINISHED" then
        ns.OnQuestFinished()
        return
    end
    if event == "UI_ERROR_MESSAGE" then
        if waiting or not IsBagsFullMessage(...) then return end
        -- Wait a moment: the loot window may still be opening.
        waiting = true
        C_Timer.After(0.3, function()
            waiting = false
            local ok, problem = pcall(OnBagsFull)
            if not ok then ns.Print("Something went wrong making room: " .. tostring(problem)) end
        end)
    elseif event == "LOOT_CLOSED" then
        said, ns.pendingLoot, retried = false, nil, {}
        if current and current.loot and not current.loot.quest then
            tucked = false
            window:Hide()
            current, skipped = nil, {}
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inFight = true
        -- A quest item on offer stays, so it can still be looted.
        if window:IsShown() and not (current and ns.IsEmergency(current.loot)) then
            tucked = true
            window:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inFight = false
        if tucked then
            tucked = false
            if current then
                -- Coming back on its own, while you may be running and
                -- jumping: a longer pause before A (or a click) counts.
                Arm(RETURN_ARM_SECONDS)
                PositionForOffer(current.loot)
                window:Show()
            end
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" or event == "EQUIPMENT_SETS_CHANGED" then
        ns.InvalidateSurvey()
    elseif event == "PLAYER_LOGIN" then
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
                and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
                pcall(ns.AddWhyLine, tooltip, data)
            end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.InvalidateSurvey()
        local slot = ns.pendingLoot
        ns.pendingLoot = nil
        if slot and LootOpen() then LootAndContinue(slot) end
        if ns.pendingQuest then
            ns.pendingQuest = false
            C_Timer.After(0.3, function() pcall(ns.OnQuestFull, true) end)
        end
    end
end)
for _, event in ipairs({ "UI_ERROR_MESSAGE", "LOOT_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "EQUIPMENT_SETS_CHANGED", "PLAYER_LOGIN",
        "CHAT_MSG_SYSTEM", "QUEST_COMPLETE", "QUEST_FINISHED" }) do
    pcall(events.RegisterEvent, events, event)
end
