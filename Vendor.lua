local addonName, ns = ...

-- Finding a vendor whenever you carry something JunkMate would sell (grey
-- items, and outgrown food and gear you can't use, if that is switched
-- on). Then:
--   * a line on screen says what the junk is worth and names the nearest
--     vendor you have used ("Nearest vendor: Mike Miller, 120 yd"); click
--     it for a map pin and the arrow (drag it to move it);
--   * a vendor JunkMate knows says on their tooltip that they'll buy it,
--     and targeting one says so in chat.
-- Every vendor is remembered when you open their shop (Repair.lua).

local GUIDE_REFRESH = 3
local TARGET_QUIET = 60

local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

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

----------------------------------------------------------------------------
-- The line on screen
----------------------------------------------------------------------------

local notice = CreateFrame("Frame", "JunkMateVendorNotice", UIParent)
notice:SetSize(260, 26)
notice:SetPoint("TOP", UIParent, "TOP", 0, -180)
notice:SetMovable(true)
notice:SetClampedToScreen(true)
notice:EnableMouse(true)
notice:RegisterForDrag("LeftButton")
notice:Hide()
local background = notice:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0, 0, 0, 0.55)
local text = notice:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER")
text:SetTextColor(1, 0.82, 0.2)

local dragged = false
notice:SetScript("OnDragStart", function(self)
    dragged = true
    self:StartMoving()
end)
notice:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    if ns.db then ns.db.vendorNoticePosition = { point, relativePoint, x, y } end
end)
notice:SetScript("OnMouseUp", function(_, button)
    if dragged then dragged = false return end
    if button == "LeftButton" then pcall(ns.PinNearestVendor) end
end)

function ns.PinNearestVendor()
    local record = ns.NearestVendor()
    if not record then
        ns.Print("JunkMate doesn't know a vendor near here yet. It learns each one when you open their shop.")
        return
    end
    ns.PinRecord(record, "who buys your junk")
end

local placed = false
local ticker

function ns.UpdateVendorHelp()
    local db = ns.db
    if not db then return end
    if not placed then
        placed = true
        local saved = db.vendorNoticePosition
        if type(saved) == "table" and saved[1] then
            notice:ClearAllPoints()
            notice:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
        end
    end
    -- The junk carried, for the coin on the minimap button too.
    local count, value = ns.JunkToSell()
    if ns.junkCount ~= count or ns.junkValue ~= value then
        ns.junkCount, ns.junkValue = count, value
        if ns.UpdateMinimapButton then pcall(ns.UpdateMinimapButton) end
    end
    if not db.vendorGuide or ns.merchantOpen then count = 0 end
    if count == 0 then
        notice:Hide()
        if ticker then ticker:Cancel(); ticker = nil end
        return
    end
    local record, distance = ns.NearestVendor()
    text:SetText(("Junk to sell: %d item%s (%s)"):format(count, count == 1 and "" or "s", ns.Money(value))
        .. (record and ("  |cffffffffNearest vendor: %s (click for a map pin)|r"):format(ns.DescribeSpot(record, distance)) or ""))
    notice:SetWidth(math.max(260, (tonumber(text:GetStringWidth() or 0) or 0) + 30))
    notice:Show()
    if not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(GUIDE_REFRESH, function() pcall(ns.UpdateVendorHelp) end)
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
    elseif event == "MERCHANT_SHOW" then
        notice:Hide()
        return
    end
    pcall(ns.UpdateVendorHelp)
end)
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "MERCHANT_SHOW", "MERCHANT_CLOSED",
        "PLAYER_TARGET_CHANGED", "PLAYER_LOGIN" }) do
    pcall(events.RegisterEvent, events, event)
end
