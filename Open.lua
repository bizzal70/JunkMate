local addonName, ns = ...

-- Opening clams and other "Right Click to Open" items, which frees bag
-- space: nine clams become one stack of clam meat and the odd pearl.
--
-- Runs on its own when the bags get down to the warning level, and with
-- /junkmate open. One item at a time: open it, take everything in it,
-- then the next. Never in a fight, never while a loot window is already
-- open, and never while a vendor, bank, mailbox, trade or auction window
-- is open, because there "opening" an item would sell, bank, mail or trade
-- it instead. Locked boxes are left alone. It stops if the bags are full,
-- since what is inside would have nowhere to go.

-- Pause between items, so each one's loot is taken before the next.
local OPEN_INTERVAL = 0.5
-- How long to wait for one item's loot window before giving up.
local MAX_WAITS = 16
-- Opening on its own (at the warning) at most this often, in seconds.
local AUTO_OPEN_GAP = 15

local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Windows where using an item does something else with it.
local BUSY_WINDOWS = {
    "MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "AuctionFrame", "AuctionHouseFrame",
    "GuildBankFrame", "SendMailFrame",
}

function ns.OpenBlocked()
    if InCombatLockdown and InCombatLockdown() then return "in a fight" end
    if ns.merchantOpen or ns.bankOpen then return "at a vendor or the bank" end
    for _, name in ipairs(BUSY_WINDOWS) do
        local frame = _G[name]
        if type(frame) == "table" and frame.IsShown and frame:IsShown() then return "with that window open" end
    end
    if GetNumLootItems and (tonumber(GetNumLootItems()) or 0) > 0 then return "while looting" end
end

-- A locked box says "Locked" on its tooltip; opening it needs a key or a rogue.
local function IsLockedBox(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    local word = LOCKED or "Locked"
    for _, line in ipairs(data.lines) do
        if Usable(line.leftText) and line.leftText == word then return true end
    end
    return false
end

-- Every item in the bags that opens, and isn't locked.
function ns.Openables()
    local list = {}
    for _, item in ipairs(ns.BagItems()) do
        local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if type(info) == "table" and info.hasLoot and not info.isLocked and not IsLockedBox(item.bag, item.slot) then
            list[#list + 1] = item
        end
    end
    return list
end

local function FreeSlots()
    local ok, free = pcall(ns.FreeBagSlots)
    return ok and free or 0
end

local openTicker
ns.openingNow = false

function ns.Opening()
    return openTicker ~= nil
end

-- Opens everything that opens, one at a time. byHand: from /junkmate open,
-- so it says why when it can't. Returns whether it started.
function ns.OpenContainers(byHand)
    if openTicker or (ns.Restacking and ns.Restacking()) then return true end
    local blocked = ns.OpenBlocked()
    if blocked then
        if byHand then ns.Print("JunkMate won't open things " .. blocked .. ".") end
        return false
    end
    local list = ns.Openables()
    if #list == 0 then
        if byHand then ns.Print("Nothing in your bags to open.") end
        return false
    end
    if FreeSlots() == 0 then
        if byHand then ns.Print("Your bags are full, so what's inside would have nowhere to go. Free one slot first.") end
        return false
    end
    local before = FreeSlots()
    local index, opened, waits = 0, 0, 0
    local function Finish(why)
        if openTicker then openTicker:Cancel() end
        openTicker, ns.openingNow = nil, false
        if opened > 0 then
            local gained = FreeSlots() - before
            ns.Print(("Opened %d item%s%s.%s"):format(opened, opened == 1 and "" or "s",
                gained > 0 and (" (%d bag slot%s freed)"):format(gained, gained == 1 and "" or "s") or "",
                why and (" Stopped: " .. why .. ".") or ""))
        end
    end
    openTicker = C_Timer.NewTicker(OPEN_INTERVAL, function()
        -- The last item's loot still on screen: wait for it to be taken.
        if GetNumLootItems and (tonumber(GetNumLootItems()) or 0) > 0 then
            waits = waits + 1
            if waits >= MAX_WAITS then Finish("its loot wasn't taken") end
            return
        end
        waits = 0
        local blockedNow = ns.OpenBlocked()
        if blockedNow then return Finish(blockedNow) end
        if FreeSlots() == 0 then return Finish("your bags are full") end
        index = index + 1
        local item = list[index]
        if not item then return Finish() end
        -- Still the same item, and still something that opens.
        local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
        if type(info) == "table" and info.itemID == item.itemID and info.hasLoot and not info.isLocked then
            ns.openingNow = true
            C_Container.UseContainerItem(item.bag, item.slot)
            opened = opened + 1
        end
    end)
    return true
end

-- At the warning: open things if there are any. Returns true while it does,
-- so the warning waits to see how much room it made.
local lastAuto
function ns.AutoOpen()
    if openTicker then return true end
    if not (ns.db and ns.db.openContainers) then return false end
    local now = GetTime()
    if lastAuto and now - lastAuto < AUTO_OPEN_GAP then return false end
    if ns.OpenBlocked() or FreeSlots() == 0 or #ns.Openables() == 0 then return false end
    lastAuto = now
    return ns.OpenContainers(false)
end

-- Take everything in an item JunkMate just opened, even with auto loot off.
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        if not (openTicker and ns.openingNow) then return end
        ns.openingNow = false
        for slot = 1, (tonumber(GetNumLootItems and GetNumLootItems()) or 0) do
            if LootSlot then pcall(LootSlot, slot) end
        end
    end
end)
for _, event in ipairs({ "LOOT_READY", "LOOT_OPENED" }) do
    pcall(events.RegisterEvent, events, event)
end
