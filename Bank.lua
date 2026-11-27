local addonName, ns = ...

-- At the bank: when the bank opens, JunkMate
--   1. puts partial stacks in the bank together, freeing bank slots, then
--   2. tops up the bank's partial stacks of crafting materials from the
--      bags (15 Linen Cloth in the bank and 7 in the bags: 5 go in, making
--      20, and 2 stay in the bags).
-- Only crafting materials go from the bags to the bank, so food, potions,
-- ammo and reagents you carry are never taken. Nothing goes into an empty
-- bank slot, so your bags are never emptied into the bank. Holding Shift
-- while opening the bank skips it, as at a vendor.

local CRAFTING = 7
-- A moment after the bank opens, so the game has filled it in.
local OPEN_DELAY = 0.3

ns.bankOpen = false

local function Number(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value)) and type(value) == "number" and value or nil
end

-- The bank's containers: the bank itself and its bags, or its tabs on a
-- client that has bank tabs. Never the player's own bags.
function ns.BankContainers()
    local ids, seen = {}, {}
    local function Add(id)
        id = Number(id)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    local index = Enum and Enum.BagIndex
    if type(index) == "table" and next(index) then
        Add(index.Bank)
        for name, id in pairs(index) do
            if type(name) == "string" and (name:match("^BankBag_%d+$") or name:match("^CharacterBankTab_%d+$")) then
                Add(id)
            end
        end
    else
        Add(BANK_CONTAINER or -1)
        for bag = 5, 4 + (Number(NUM_BANKBAGSLOTS) or 7) do Add(bag) end
    end
    table.sort(ids)
    return ids
end

-- Moves that top up the bank's partial stacks of crafting materials from
-- the bags: moves, how many items go, and how many bag slots that frees.
-- The fullest bank stack is filled first, from the smallest bag stack.
function ns.BankFillPlan()
    local targets = {}
    for _, item in ipairs(ns.ContainerItems(ns.BankContainers())) do
        if not item.locked then
            local facts = ns.ItemFacts(item.itemID)
            if facts and facts.classID == CRAFTING and facts.maxStack > 1 and item.count < facts.maxStack then
                local list = targets[item.itemID]
                if not list then
                    list = { max = facts.maxStack }
                    targets[item.itemID] = list
                end
                list[#list + 1] = item
            end
        end
    end
    local sources = {}
    for _, item in ipairs(ns.BagItems()) do
        if targets[item.itemID] and not item.locked then
            local list = sources[item.itemID] or {}
            sources[item.itemID] = list
            list[#list + 1] = item
        end
    end
    local moves, moved, freed = {}, 0, 0
    for itemID, list in pairs(targets) do
        local from = sources[itemID]
        if from then
            table.sort(list, function(a, b) return a.count > b.count end)
            table.sort(from, function(a, b) return a.count < b.count end)
            local have, left = {}, {}
            for index, item in ipairs(list) do have[index] = item.count end
            for index, item in ipairs(from) do left[index] = item.count end
            local fill, take = 1, 1
            while fill <= #list and take <= #from do
                local room = list.max - have[fill]
                if room <= 0 then
                    fill = fill + 1
                else
                    local amount = math.min(room, left[take])
                    moves[#moves + 1] = { itemID = itemID, from = from[take], to = list[fill], amount = amount, max = list.max }
                    have[fill], left[take], moved = have[fill] + amount, left[take] - amount, moved + amount
                    if left[take] == 0 then
                        freed = freed + 1
                        take = take + 1
                    end
                end
            end
        end
    end
    return moves, moved, freed
end

local busy = false
local function BankStillOpen() return ns.bankOpen end

local function Plural(count, word)
    return ("%d %s%s"):format(count, word, count == 1 and "" or "s")
end

-- Tidies the bank (see the top of this file). byHand: from /junkmate bank,
-- so it says something even when there is nothing to do.
function ns.TidyBank(byHand)
    if busy or ns.Restacking() then return end
    if not ns.bankOpen then
        if byHand then ns.Print("Open your bank first.") end
        return
    end
    busy = true
    local said = {}
    local function Finish(finished)
        busy = false
        if finished == false then
            ns.Print("The bank closed before JunkMate was done tidying it.")
        elseif #said > 0 then
            ns.Print("At the bank: " .. table.concat(said, "; ") .. ".")
        elseif byHand then
            ns.Print("The bank is already tidy: no partial stacks to put together or top up.")
        end
    end
    local function Fill(finished)
        if finished == false then return Finish(false) end
        local moves, moved, freed = ns.BankFillPlan()
        if #moves == 0 then return Finish(true) end
        said[#said + 1] = ("moved %s from your bags onto bank stacks (%s freed)"):format(Plural(moved, "item"), Plural(freed, "bag slot"))
        if not ns.RunMoves(moves, Finish, BankStillOpen) then Finish(true) end
    end
    local moves, freed = ns.RestackPlan(ns.ContainerItems(ns.BankContainers()))
    if #moves == 0 then return Fill(true) end
    said[#said + 1] = "put partial bank stacks together" .. (freed > 0 and (" (%s freed)"):format(Plural(freed, "bank slot")) or "")
    if not ns.RunMoves(moves, Fill, BankStillOpen) then
        busy = false
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "BANKFRAME_OPENED" then
        ns.bankOpen = true
        if not (ns.db and ns.db.bankTidy) or (IsShiftKeyDown and IsShiftKeyDown()) then return end
        C_Timer.After(OPEN_DELAY, function()
            local ok, problem = pcall(ns.TidyBank)
            if not ok then
                busy = false
                ns.Print("Something went wrong tidying the bank, so it was left: " .. tostring(problem))
            end
        end)
    else
        ns.bankOpen = false
    end
end)
for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED" }) do
    pcall(events.RegisterEvent, events, event)
end
