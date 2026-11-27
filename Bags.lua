local addonName, ns = ...

-- Warns when the bags are nearly full: the minimap button's "!" lights up,
-- and one line in chat says so when the free slots first drop to the chosen
-- number, and again when the bags are completely full. Both reset once
-- there is room again.
--
-- Only ordinary bags count. A herb bag, mining bag or quiver holds just one
-- kind of thing, so its free slots do not help with other loot.

-- The backpack and the four bag slots.
local FIRST_BAG, LAST_BAG = 0, 4

-- The numbers of free slots the warning can be set to.
ns.BAG_LEVELS = { 2, 4, 8 }

local warnedLow, warnedFull = false, false

local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Free and total slots in the ordinary bags; nil if the game gives nothing.
function ns.FreeBagSlots()
    local container = C_Container
    if not container or not container.GetContainerNumSlots then return end
    local free, total = 0, 0
    for bag = FIRST_BAG, LAST_BAG do
        local slots = container.GetContainerNumSlots(bag)
        if Usable(slots) and slots > 0 then
            local open, family
            if container.GetContainerNumFreeSlots then
                open, family = container.GetContainerNumFreeSlots(bag)
            end
            if not Usable(open) then
                -- No count from the game: look at each slot instead.
                open = 0
                for slot = 1, slots do
                    if not container.GetContainerItemInfo(bag, slot) then open = open + 1 end
                end
            end
            if not Usable(family) or family == 0 then
                free, total = free + open, total + slots
            end
        end
    end
    if total == 0 then return end
    return free, total
end

-- One line on the bags for the options window: text and colour.
function ns.BagStatus()
    local ok, free, total = pcall(ns.FreeBagSlots)
    if not ok or not free then
        return "Bags: no bag slots found.", 0.6, 0.6, 0.6
    end
    local slots = ("%d of %d slot%s free"):format(free, total, total == 1 and "" or "s")
    if free == 0 then
        return "Bags full: " .. slots .. ". Sell, bank or mail something.", 1, 0.25, 0.25
    elseif ns.bagsLow then
        return "Bags nearly full: " .. slots .. ".", 1, 0.82, 0.2
    end
    return "Bags: " .. slots .. ".", 0.5, 0.9, 0.5
end

-- Updates the warning to match the bags.
function ns.UpdateBags()
    local db = ns.db
    if not db then return end
    local free = ns.FreeBagSlots()
    -- Nearly full: restack first, if that frees a slot. The warning waits
    -- to see how much room it made.
    if free and free <= db.bagLevel and ns.AutoOpen and ns.AutoOpen() then return end
    if free and free <= db.bagLevel and ns.AutoRestack and ns.AutoRestack() then return end
    if not db.bagWarn then free = nil end
    if not free or free > db.bagLevel then
        warnedLow, warnedFull = false, false
        ns.bagsLow = nil
        ns.ShowWorn()
        return
    end

    ns.bagsLow = free
    ns.ShowWorn()
    if free == 0 then
        if not warnedFull then
            warnedFull, warnedLow = true, true
            ns.Print("Your bags are full. Anything new you loot or gather won't fit.")
        end
    else
        warnedFull = false
        if not warnedLow then
            warnedLow = true
            ns.Print(("Only %d bag slot%s left."):format(free, free == 1 and "" or "s"))
        end
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function()
    if not ns.db then return end
    -- Reading the bags must never put an error on screen.
    pcall(ns.UpdateBags)
end)
frame:RegisterEvent("PLAYER_LOGIN")
-- Registering an event this client does not have throws.
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do
    pcall(frame.RegisterEvent, frame, event)
end
