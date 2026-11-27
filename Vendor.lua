local addonName, ns = ...

-- Junk to sell, and the nearest vendor to sell it to. While you carry
-- anything JunkMate would sell (grey items, and outgrown food and gear you
-- can't use, if that is switched on):
--   * a gold coin shows on the minimap button; hovering the button says
--     what the junk is worth and names the nearest vendor you have used,
--     and right-clicking it puts a map pin on them;
--   * a vendor JunkMate knows says on their tooltip that they'll buy it,
--     and targeting one says so in chat.
-- Every vendor is remembered when you open their shop (Repair.lua).

local TARGET_QUIET = 60

-- What JunkMate would sell at the next vendor: items and total worth.
function ns.JunkToSell()
    local db = ns.db
    local count, value = 0, 0
    if not db then return 0, 0 end
    local ok, survey = pcall(ns.Survey)
    if not ok or not survey then return 0, 0 end
    for _, item in ipairs(survey.list) do
        local sells = (item.tier == 1 and db.sellJunk and (item.value or 0) > 0)
            or (db.sellExtras and ns.IsExtraSale(item))
        if sells then count, value = count + 1, value + item.value end
    end
    return count, value
end

function ns.NearestVendor()
    return ns.NearestOf(ns.db and ns.db.vendors)
end

-- "Nearest vendor: Mike Miller, 120 yd", or nil.
function ns.NearestVendorText()
    if not (ns.db and ns.db.vendorGuide) then return end
    local record, distance = ns.NearestVendor()
    if record then return "Nearest vendor: " .. ns.DescribeSpot(record, distance) end
end

function ns.PinNearestVendor()
    local record = ns.NearestVendor()
    if not record then
        ns.Print("JunkMate doesn't know a vendor near here yet. It learns each one when you open their shop.")
        return
    end
    ns.PinRecord(record, "who buys your junk")
end

-- Counts the junk for the coin on the minimap button.
function ns.UpdateVendorHelp()
    if not ns.db then return end
    local count, value = ns.JunkToSell()
    if ns.junkCount ~= count or ns.junkValue ~= value then
        ns.junkCount, ns.junkValue = count, value
        if ns.UpdateMinimapButton then pcall(ns.UpdateMinimapButton) end
    end
end

----------------------------------------------------------------------------
-- Known vendors on tooltips and when targeted
----------------------------------------------------------------------------

function ns.AddVendorLine(tooltip)
    if not (ns.db and ns.db.vendorGuide) or tooltip ~= GameTooltip then return end
    local ok, name, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not unit or (UnitIsPlayer and UnitIsPlayer(unit)) then return end
    if not ns.IsKnownIn(ns.db.vendors, name) then return end
    local count, value = ns.JunkToSell()
    if count == 0 then return end
    tooltip:AddLine(("JunkMate: buys your junk (%d item%s, %s)"):format(count, count == 1 and "" or "s", ns.Money(value)), 1, 0.82, 0.2)
    tooltip:Show()
end

local mentioned = {}
function ns.OnVendorTargeted()
    if not (ns.db and ns.db.vendorGuide) then return end
    local name = UnitName and UnitName("target")
    if not name or (UnitIsPlayer and UnitIsPlayer("target")) or not ns.IsKnownIn(ns.db.vendors, name) then return end
    local count, value = ns.JunkToSell()
    if count == 0 then return end
    local now = GetTime()
    if mentioned[name] and now - mentioned[name] < TARGET_QUIET then return end
    mentioned[name] = now
    ns.Print(("%s buys junk: you have %d item%s to sell (%s)."):format(name, count, count == 1 and "" or "s", ns.Money(value)))
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_TARGET_CHANGED" then
        pcall(ns.OnVendorTargeted)
        return
    elseif event == "PLAYER_LOGIN" then
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
                and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
                pcall(ns.AddVendorLine, tooltip)
            end)
        end
    end
    pcall(ns.UpdateVendorHelp)
end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "MERCHANT_CLOSED",
        "PLAYER_TARGET_CHANGED", "PLAYER_LOGIN" }) do
    pcall(events.RegisterEvent, events, event)
end
