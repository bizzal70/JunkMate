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

----------------------------------------------------------------------------
-- The junk line on screen: off unless switched on (db.junkBanner)
----------------------------------------------------------------------------

local BANNER_TOP = -180
local notice = CreateFrame("Frame", "JunkMateJunkNotice", UIParent)
notice:SetSize(260, 26)
notice:SetPoint("TOP", UIParent, "TOP", 0, BANNER_TOP)
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
    if ns.db then ns.db.junkNoticePosition = { point, relativePoint, x, y } end
end)
notice:SetScript("OnMouseUp", function(_, button)
    if dragged then dragged = false return end
    if button == "LeftButton" then pcall(ns.PinNearestVendor) end
end)
notice:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("JunkMate: junk to sell", 1, 0.82, 0.2)
    GameTooltip:AddLine("Drag to move it. Click: map pin on the nearest vendor.", 1, 1, 1, true)
    GameTooltip:AddLine("/junkmate junkbanner hides it; /junkmate junkbanner reset puts it back.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end)
notice:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.ResetJunkBanner()
    if ns.db then ns.db.junkNoticePosition = nil end
    notice:ClearAllPoints()
    notice:SetPoint("TOP", UIParent, "TOP", 0, BANNER_TOP)
end

local placed = false
local function UpdateBanner(count, value)
    local db = ns.db
    if not placed then
        placed = true
        local saved = db.junkNoticePosition
        if type(saved) == "table" and saved[1] then
            notice:ClearAllPoints()
            notice:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
        end
    end
    if not db.junkBanner or ns.merchantOpen or count == 0 then
        notice:Hide()
        return
    end
    text:SetText(("Junk to sell: %d item%s (%s)"):format(count, count == 1 and "" or "s", ns.Money(value)))
    notice:SetWidth(math.max(260, (tonumber(text:GetStringWidth() or 0) or 0) + 30))
    notice:Show()
end

----------------------------------------------------------------------------
-- Vendors on the minimap while you carry junk (db.vendorMinimap): a gold
-- coin on each vendor you've used in this zone, within the minimap's view.
----------------------------------------------------------------------------

local PIN_SIZE = 14
local EDGE_INSET = 5
local holder = CreateFrame("Frame", nil, Minimap)
holder:SetAllPoints(Minimap)
holder:SetFrameLevel(((Minimap.GetFrameLevel and Minimap:GetFrameLevel()) or 1) + 6)
local pins = {}
ns.vendorPins = pins

local function AcquirePin(index)
    local pin = pins[index]
    if pin then return pin end
    pin = CreateFrame("Frame", nil, holder)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin.texture = pin:CreateTexture(nil, "ARTWORK")
    pin.texture:SetAllPoints()
    pin.texture:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    pin:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(self.vendorName or "Vendor", 1, 1, 1)
        GameTooltip:AddLine(("Buys your junk: %d item%s (%s)"):format(ns.junkCount or 0, (ns.junkCount or 0) == 1 and "" or "s",
            ns.Money(ns.junkValue or 0)), 1, 0.82, 0.2)
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Hover only, so clicks still reach the minimap underneath.
    if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(false) end
    pins[index] = pin
    return pin
end

-- How many yards the minimap shows from its centre to its edge.
local function ViewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local radius = C_Minimap.GetViewRadius()
        if type(radius) == "number" and radius > 0 then return radius end
    end
    return 233
end

-- With a rotating minimap, up is the way the player faces: the turn's
-- sine and cosine (0 and 1 when fixed).
local function Rotation()
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    if getCVar and getCVar("rotateMinimap") == "1" and GetPlayerFacing then
        local facing = GetPlayerFacing()
        if type(facing) == "number" then return math.sin(facing), math.cos(facing) end
    end
    return 0, 1
end

-- A map's size in yards: from the game where it says, else worked out from
-- the world positions of two corners.
local function MapSize(mapID)
    if C_Map.GetMapWorldSize then
        local ok, width, height = pcall(C_Map.GetMapWorldSize, mapID)
        if ok and type(width) == "number" and width > 0 and type(height) == "number" and height > 0 then return width, height end
    end
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
        local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
        if ok1 and ok2 and a and b then
            local ax, ay = a:GetXY()
            local bx, by = b:GetXY()
            return math.abs(bx - ax), math.abs(by - ay)
        end
    end
end

function ns.UpdateVendorPins()
    local used = 0
    local db = ns.db
    if db and db.vendorMinimap and (ns.junkCount or 0) > 0 and db.vendors
            and C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
        local width, height = MapSize(mapID)
        if mapID and ok and pos and type(width) == "number" and type(height) == "number" then
            local px, py = pos:GetXY()
            local halfWidth = Minimap:GetWidth() / 2
            local pixelsPerYard = halfWidth / ViewRadius()
            local edge = halfWidth - EDGE_INSET
            local sinF, cosF = Rotation()
            local faction = UnitFactionGroup and UnitFactionGroup("player")
            for _, record in pairs(db.vendors) do
                if record.map == mapID and (not record.faction or record.faction == faction) then
                    local east, north = (record.x - px) * width, -(record.y - py) * height
                    local x = (east * cosF + north * sinF) * pixelsPerYard
                    local y = (north * cosF - east * sinF) * pixelsPerYard
                    if math.sqrt(x * x + y * y) <= edge then
                        used = used + 1
                        local pin = AcquirePin(used)
                        pin.vendorName = record.name
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
                        pin:Show()
                    end
                end
            end
        end
    end
    for index = used + 1, #pins do pins[index]:Hide() end
end

-- Kept in place as you move, only while there is junk to show them for.
local elapsedSince = 0
local function FollowPlayer(_, elapsed)
    elapsedSince = elapsedSince + (elapsed or 0)
    if elapsedSince < 0.1 then return end
    elapsedSince = 0
    pcall(ns.UpdateVendorPins)
end

-- Counts the junk for the coin on the minimap button, the vendors on the
-- minimap, and the line on screen if that is switched on.
function ns.UpdateVendorHelp()
    if not ns.db then return end
    local count, value = ns.JunkToSell()
    if ns.junkCount ~= count or ns.junkValue ~= value then
        ns.junkCount, ns.junkValue = count, value
        if ns.UpdateMinimapButton then pcall(ns.UpdateMinimapButton) end
        if ns.UpdateTracking then pcall(ns.UpdateTracking) end
    end
    local showPins = ns.db.vendorMinimap and count > 0
    holder:SetScript("OnUpdate", showPins and FollowPlayer or nil)
    pcall(ns.UpdateVendorPins)
    UpdateBanner(count, value)
    pcall(ns.UpdateVendorWaypoint, count)
end

----------------------------------------------------------------------------
-- The map pin on the nearest vendor while there is junk (db.vendorGuide)
----------------------------------------------------------------------------

-- The map pin JunkMate placed: { name, map, x, y }, kept over a /reload.
-- A pin you placed yourself is never moved or removed; a JunkMate pin you
-- removed isn't put back on that vendor until the next time you have junk.

local function PinParts(point)
    if type(point) ~= "table" then return end
    if point.uiMapID and point.position then
        local x, y = point.position:GetXY()
        return point.uiMapID, x, y
    end
    return point[1], point[2], point[3]
end

local function PinIsOurs()
    local ours = ns.db and ns.db.vendorWaypoint
    if not ours or not (C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return false end
    local map, x, y = PinParts(C_Map.GetUserWaypoint())
    return map == ours.map and type(x) == "number" and math.abs(x - ours.x) < 0.0001 and math.abs(y - ours.y) < 0.0001
end

function ns.UpdateVendorWaypoint(count)
    local db = ns.db
    if not (db and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
    local ours = db.vendorWaypoint
    -- Our pin gone, though we didn't remove it: you took it off.
    if ours and not PinIsOurs() then
        if not (C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then db.vendorPinDismissed = ours.name end
        db.vendorWaypoint, ours = nil, nil
    end
    local record = db.vendorGuide and (count or 0) > 0 and ns.NearestVendor()
    if not record then
        if ours then C_Map.ClearUserWaypoint() end
        db.vendorWaypoint = nil
        if (count or 0) == 0 then db.vendorPinDismissed = nil end
        return
    end
    if ours and ours.name == record.name and ours.map == record.map then return end
    if record.name == db.vendorPinDismissed then return end
    -- Your own pin stays where you put it.
    if not ours and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(record.map) then return end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(record.map, record.x, record.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    db.vendorWaypoint = { name = record.name, map = record.map, x = record.x, y = record.y }
end

-- The distance on the line, kept up to date while it shows.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(3, function()
        -- While there's junk: the line's numbers and the nearest vendor's pin.
        if (ns.junkCount or 0) > 0 or notice:IsShown() then pcall(ns.UpdateVendorHelp) end
    end)
end

----------------------------------------------------------------------------
-- Learning vendors without visiting them
----------------------------------------------------------------------------

-- An NPC hovered over or targeted, close by, whose title under their name
-- says they sell things ("General Trade Goods Vendor", "Bowyer", "Trade
-- Supplies") is remembered as a vendor. The game doesn't say where an NPC
-- stands, only where you are, so only NPCs within about 10 yards are
-- learned, at your position. The title words are English, so on other
-- clients only opening a shop teaches JunkMate.
local SELLER_WORDS = {
    "vendor", "merchant", "supplies", "supplier", "goods", "trader", "trade", "provisioner",
    "bowyer", "armorer", "armorsmith", "weaponsmith", "gunsmith", "fletcher", "innkeeper",
    "food & drink", "baker", "butcher", "grocer", "bartender", "wine", "reagent", "poison",
    "tradesman", "outfitter", "quartermaster",
}
local NOT_SELLER_WORDS = { "trainer", "guard", "flight master", "gryphon master", "wind rider master",
    "hippogryph master", "bat handler", "stable master", "banker", "auctioneer", "battlemaster" }

-- The title under an NPC's name, from their tooltip, or nil.
local function UnitTitle(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return end
    local levelWord = (type(LEVEL) == "string" and LEVEL or "Level"):lower()
    for index = 2, math.min(3, #data.lines) do
        local text = data.lines[index].leftText
        if type(text) == "string" and not (issecretvalue and issecretvalue(text))
                and text ~= "" and not text:lower():find("^" .. levelWord) then
            return text
        end
    end
end

function ns.IsSellerTitle(title)
    if type(title) ~= "string" then return false end
    title = title:lower()
    for _, word in ipairs(NOT_SELLER_WORDS) do
        if title:find(word, 1, true) then return false end
    end
    for _, word in ipairs(SELLER_WORDS) do
        if title:find(word, 1, true) then return true end
    end
    return false
end

-- Whether `unit` is close enough to place at your position: true, false,
-- or nil when the game won't say (some clients restrict the check).
local function IsClose(unit)
    if not CheckInteractDistance then return nil end
    local ok, close = pcall(CheckInteractDistance, unit, 3)
    if not ok or (issecretvalue and issecretvalue(close)) then return nil end
    return close and true or false
end

-- Remembers `unit` as a vendor if it is one, close by. Returns whether it
-- did, and why not (for /junkmate learn).
function ns.LearnVendor(unit)
    local db = ns.db
    if not db then return false, "not loaded yet" end
    if InCombatLockdown and InCombatLockdown() then return false, "in a fight" end
    if not (UnitExists and UnitExists(unit)) then return false, "nobody there" end
    if (UnitIsPlayer and UnitIsPlayer(unit)) or (UnitPlayerControlled and UnitPlayerControlled(unit)) then
        return false, "a player or a pet"
    end
    if UnitCanAttack and UnitCanAttack("player", unit) then return false, "someone you could attack" end
    local title = UnitTitle(unit)
    if not ns.IsSellerTitle(title) then
        return false, title and ("their title (\"" .. title .. "\") isn't a seller's") or "no title found on their tooltip"
    end
    local close = IsClose(unit)
    if close == false then return false, "too far away to place (come within about 10 yards)" end
    -- The game won't say how close: only trust a target, chosen on purpose.
    if close == nil and unit ~= "target" then return false, "distance unknown here: target them instead" end
    local name = UnitName(unit)
    if type(name) ~= "string" or name == "" or (issecretvalue and issecretvalue(name)) then return false, "no name" end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not mapID then return false, "no map here" end
    local key = name .. "@" .. mapID
    db.vendors = db.vendors or {}
    -- A vendor whose shop you've opened is already in the right place.
    local known = db.vendors[key]
    if known and not known.learned then return false, "already known from their shop" end
    local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not okPos or not pos then return false, "your position isn't available here" end
    local x, y = pos:GetXY()
    db.vendors[key] = { name = name, map = mapID, x = x, y = y, learned = true,
        faction = UnitFactionGroup and UnitFactionGroup("player") or nil, seen = time() }
    if not known then
        ns.SayLearned(name)
        pcall(ns.UpdateVendorPins)
    end
    return true, close == nil and "learned (distance unknown, so at your position)" or "learned"
end

-- Said once, the first time any of your characters learns a vendor.
function ns.SayLearned(name)
    ns.Print(("Learned a vendor: %s. All your characters will know them now."):format(name))
end

-- /junkmate learn: try to learn the target, and say what happened.
function ns.LearnTargetCommand()
    local name = UnitName and UnitName("target") or "your target"
    local learned, why = ns.LearnVendor("target")
    ns.Print(("%s: %s."):format(type(name) == "string" and name or "Target", why or (learned and "learned" or "not learned")))
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
        pcall(ns.LearnVendor, "target")
        pcall(ns.OnVendorTargeted)
        return
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        pcall(ns.LearnVendor, "mouseover")
        return
    elseif event == "MERCHANT_SHOW" then
        notice:Hide()
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
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "MERCHANT_SHOW", "MERCHANT_CLOSED",
        "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_LOGIN" }) do
    pcall(events.RegisterEvent, events, event)
end
