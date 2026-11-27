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
                    noValue = info.hasNoValue and true or false, link = Usable(info.hyperlink) and info.hyperlink or nil,
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

-- Buff food says on its tooltip that you will become well fed.
local function IsBuffFood(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if Usable(text) and type(text) == "string" and text:lower():find("well fed", 1, true) then return true end
    end
    return false
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

-- Which items JunkMate would destroy to make room, in the order it would
-- offer them: a list of items with tier (1 grey, 2 outdated food or drink,
-- 3 gear), value (the whole stack's vendor price), name and link.
function ns.RoomCandidates()
    local context = Context()
    local keep = ns.db and ns.db.keep or {}
    local items, food = {}, {}
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

    local function Tier(item)
        local facts = item.facts
        if item.locked or keep[item.itemID] or not facts then return end
        if C_Container.GetContainerItemQuestInfo then
            local ok, quest = pcall(C_Container.GetContainerItemQuestInfo, item.bag, item.slot)
            if ok and type(quest) == "table" and (quest.isQuestItem or quest.questID) then return end
        end
        if facts.classID == 12 or TOOLS[item.itemID] or KEEP[item.itemID] then return end
        local quality = item.quality or facts.quality
        if quality == 0 then return 1 end
        if not quality or quality >= EPIC then return end
        if not facts.classID or KEEP_CLASSES[facts.classID] then return end
        if facts.classID == CONSUMABLE then
            -- Only plain food and drink outgrown by something better.
            if not item.food or item.buff or IsBestFood(item) then return end
            return 2
        end
        if facts.classID == WEAPON or facts.classID == ARMOR then
            if facts.classID == WEAPON and facts.subclassID == FISHING_POLE then return end
            if ns.IsUpgrade(facts, context) then return end
            return 3
        end
    end

    local list = {}
    for _, item in ipairs(items) do
        local tier = Tier(item)
        if tier then
            item.tier = tier
            item.value = item.noValue and 0 or item.facts.price * item.count
            item.name = item.facts.name
            item.link = item.link or item.facts.link or item.facts.name
            list[#list + 1] = item
        end
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.value ~= b.value then return a.value < b.value end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return list
end

----------------------------------------------------------------------------
-- The loot that would not fit
----------------------------------------------------------------------------

-- The most wanted item left in the open loot window: { slot, link, count,
-- score, value }. Quest items score 4, crafting materials 3, green or
-- better and upgrades 2, anything else 1.
function ns.LootWanted()
    if not (GetNumLootItems and GetLootSlotInfo and GetLootSlotLink) then return end
    local count = Number(GetNumLootItems()) or 0
    local context, best = Context(), nil
    for slot = 1, count do
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
    end
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
window:SetSize(380, 156)
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

local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("BOTTOMLEFT", 14, 11)
hint:SetText("Controller: A destroy, X not this one, Y keep always, B close")

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
ns.CloseWithPadB(window, { PAD1 = "JunkMateRoomDestroy", PAD3 = "JunkMateRoomNext", PAD4 = "JunkMateRoomKeep" })

local function Say(text, always)
    if said and not always then return end
    said = true
    ns.Print(text)
end

local function Amount(item)
    return item.count > 1 and (" x%d"):format(item.count) or ""
end

-- Puts the next thing JunkMate would destroy in the window, to make room
-- for `loot` (or just to free a slot). Returns whether it shows anything.
function ns.OfferRoom(loot, always)
    local pick
    for _, item in ipairs(ns.RoomCandidates()) do
        if not skipped[item.bag .. ":" .. item.slot] then
            pick = item
            break
        end
    end
    if not pick then
        window:Hide()
        Say("Your bags are full, and nothing in them is something JunkMate would throw away.", always)
        return false
    end
    if not ns.WorthIt(loot, pick) then
        window:Hide()
        Say(("Your bags are full. %s is worth less than %s, the cheapest thing JunkMate would throw away, so it stays on the ground.")
            :format(loot.link, pick.link), always)
        return false
    end
    current = { item = pick, loot = loot }
    window.icon.texture:SetTexture(pick.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    window.what:SetText(("Destroy %s%s (worth %s)?"):format(pick.link, Amount(pick), pick.value > 0 and ns.Money(pick.value) or "nothing"))
    if loot then
        window.why:SetText(("To make room for %s%s."):format(loot.link, loot.count > 1 and (" x%d"):format(loot.count) or ""))
    else
        window.why:SetText("To free a bag slot.")
    end
    armedAt = GetTime() + ARM_SECONDS
    if inFight then
        if not tucked then
            tucked = true
            window:Hide()
            ns.Print("Your bags are full. JunkMate will offer to make room once the fight is over.")
        end
        return true
    end
    window:Show()
    return true
end

-- Destroys the item on offer, after checking it is still where it was.
local function DestroyCurrent()
    if not current or GetTime() < armedAt then return end
    local item, loot = current.item, current.loot
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if type(info) ~= "table" or info.itemID ~= item.itemID or info.isLocked then
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
    window:Hide()
end

window.destroy:SetScript("OnClick", function()
    local ok, problem = pcall(DestroyCurrent)
    if not ok then
        if CursorHasItem and CursorHasItem() then pcall(ClearCursor) end
        ns.Print("Something went wrong, so nothing was destroyed: " .. tostring(problem))
    end
end)
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
    ns.Print(("JunkMate will never offer %s again. /junkmate keep lists what it keeps."):format(item.link))
    ns.OfferRoom(loot, true)
end)

----------------------------------------------------------------------------
-- When loot will not fit
----------------------------------------------------------------------------

local function LootOpen()
    return GetNumLootItems and (Number(GetNumLootItems()) or 0) > 0
end

local function OnBagsFull()
    if not (ns.db and ns.db.makeRoom) or restackTicker or window:IsShown() or not LootOpen() then return end
    local loot = ns.LootWanted()
    if not loot then return end
    -- Restacking loses nothing, so it always comes first.
    local _, freed = ns.RestackPlan()
    if freed > 0 then
        ns.Restack(function(slots)
            SayRestacked(slots)
            if LootOpen() and LootSlot then pcall(LootSlot, loot.slot) end
        end)
        return
    end
    ns.OfferRoom(loot)
end

-- /junkmate room: the same offer, by hand, for the loot window if open.
function ns.MakeRoomCommand()
    if ns.Restack(function(slots)
        SayRestacked(slots)
        if slots == 0 then ns.OfferRoom(LootOpen() and ns.LootWanted() or nil, true) end
    end) then
        return
    end
    ns.OfferRoom(LootOpen() and ns.LootWanted() or nil, true)
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
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, ...)
    if not ns.db then return end
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
        said, ns.pendingLoot = false, nil
        if current and current.loot then
            tucked = false
            window:Hide()
            current, skipped = nil, {}
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inFight = true
        if window:IsShown() then
            tucked = true
            window:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inFight = false
        if tucked then
            tucked = false
            if current then
                armedAt = GetTime() + ARM_SECONDS
                window:Show()
            end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        local slot = ns.pendingLoot
        ns.pendingLoot = nil
        if slot and LootOpen() and LootSlot then pcall(LootSlot, slot) end
    end
end)
for _, event in ipairs({ "UI_ERROR_MESSAGE", "LOOT_CLOSED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
