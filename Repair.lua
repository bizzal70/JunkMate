local addonName, ns = ...

-- Finding a repairer while your gear is worn:
--   1. the minimap's own "Repair" tracking is switched on while gear is
--      worn (where the game has it), and off again once repaired, if
--      JunkMate was the one who switched it on;
--   2. every vendor who repairs is remembered when you open their shop, and
--      the worn-gear line names the nearest one ("Nearest repair: William
--      MacGregor, 180 yd"); click the line for a map pin on them;
--   3. a repairer JunkMate knows says so on their tooltip, and targeting
--      one while your gear is worn says so in chat.
-- The game doesn't tell addons which NPCs repair, so 2 and 3 only know the
-- repairers you have opened a shop with.

local GUIDE_REFRESH = 3      -- seconds between distance updates while worn
local TARGET_QUIET = 60      -- seconds before the same repairer is mentioned again

local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function Number(value)
    return Usable(value) and type(value) == "number" and value or nil
end

----------------------------------------------------------------------------
-- 1. Minimap tracking
----------------------------------------------------------------------------

-- The minimap's "Repair" tracking: its index and whether it is on.
local function RepairTracking()
    local minimap = C_Minimap
    if not (minimap and minimap.GetNumTrackingTypes and minimap.GetTrackingInfo and minimap.SetTracking) then return end
    local want = (type(MINIMAP_TRACKING_REPAIR) == "string" and MINIMAP_TRACKING_REPAIR or "Repair"):lower()
    local ok, count = pcall(minimap.GetNumTrackingTypes)
    for index = 1, ok and Number(count) or 0 do
        local found, a, _, c = pcall(minimap.GetTrackingInfo, index)
        if found then
            local name, active
            if type(a) == "table" then name, active = a.name, a.active else name, active = a, c end
            if Usable(name) and type(name) == "string" and name:lower() == want then return index, active and true or false end
        end
    end
end
ns.RepairTracking = RepairTracking

function ns.UpdateRepairTracking()
    local db = ns.db
    if not db then return end
    local index, active = RepairTracking()
    if not index then return end
    if ns.worn and db.repairTracking and not active then
        pcall(C_Minimap.SetTracking, index, true)
        db.trackingOnByUs = true
    elseif (not ns.worn or not db.repairTracking) and active and db.trackingOnByUs then
        pcall(C_Minimap.SetTracking, index, false)
        db.trackingOnByUs = nil
    end
end

----------------------------------------------------------------------------
-- 2. Remembered repairers
----------------------------------------------------------------------------

local function PlayerSpot()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local mapID = Number(C_Map.GetBestMapForUnit("player"))
    if not mapID then return end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return end
    local x, y = pos:GetXY()
    if not (Number(x) and Number(y)) then return end
    return mapID, x, y
end

-- Map coordinates to the continent's yards: instance, x, y.
local function World(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local ok, instance, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if not ok or not pos then return end
    local wx, wy = pos:GetXY()
    return instance, wx, wy
end

-- Every vendor is remembered when their shop opens (db.vendors), and those
-- who repair in db.repairers too.
function ns.RememberRepairer()
    local db = ns.db
    if not db then return end
    local name = UnitName and UnitName("npc")
    if not (Usable(name) and type(name) == "string" and name ~= "") then return end
    local mapID, x, y = PlayerSpot()
    if not mapID then return end
    local record = {
        name = name, map = mapID, x = x, y = y,
        faction = UnitFactionGroup and UnitFactionGroup("player") or nil, seen = time(),
    }
    db.vendors = db.vendors or {}
    db.vendors[name .. "@" .. mapID] = record
    if CanMerchantRepair and CanMerchantRepair() then
        db.repairers = db.repairers or {}
        db.repairers[name .. "@" .. mapID] = record
    end
end

-- The nearest of the remembered NPCs in `records`, on this continent and
-- for your faction: the record and the distance in yards.
function ns.NearestOf(records)
    if not records then return end
    local mapID, x, y = PlayerSpot()
    if not mapID then return end
    local here, px, py = World(mapID, x, y)
    if not here then return end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local best, bestDistance
    for _, record in pairs(records) do
        if not record.faction or record.faction == faction then
            local there, rx, ry = World(record.map, record.x, record.y)
            if there == here and rx then
                local distance = math.sqrt((rx - px) ^ 2 + (ry - py) ^ 2)
                if not bestDistance or distance < bestDistance then best, bestDistance = record, distance end
            end
        end
    end
    return best, bestDistance
end

function ns.NearestRepairer()
    return ns.NearestOf(ns.db and ns.db.repairers)
end

-- "William MacGregor, 180 yd" (with the zone, if another).
function ns.DescribeSpot(record, distance)
    local zone = ""
    local mapID = PlayerSpot()
    if record.map ~= mapID and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(record.map)
        if info and Usable(info.name) then zone = ", " .. info.name end
    end
    return ("%s%s, %d yd"):format(record.name, zone, math.floor(distance + 0.5))
end

-- A map pin and the arrow on a remembered NPC; `what` says why ("who repairs").
function ns.PinRecord(record, what)
    if not (C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(record.map) then
        ns.Print(("%s, but the map can't be pinned there."):format(record.name))
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(record.map, record.x, record.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    ns.Print(("Map pin set on %s, %s."):format(record.name, what))
end

-- "Nearest repair: William MacGregor, 180 yd" (with the zone, if another).
function ns.NearestRepairText()
    if not (ns.db and ns.db.repairGuide) then return end
    local record, distance = ns.NearestRepairer()
    if not record then return end
    return "Nearest repair: " .. ns.DescribeSpot(record, distance)
end

-- A map pin on the nearest repairer.
function ns.PinNearestRepairer()
    local record = ns.NearestRepairer()
    if not record then
        ns.Print("JunkMate doesn't know a repairer near here yet. It learns each one when you open their shop.")
        return
    end
    ns.PinRecord(record, "who repairs")
end

-- Clicking the worn-gear line (not dragging it) pins the nearest repairer.
local function HookNotice()
    local notice = ns.durabilityNotice
    if not notice or notice.repairHooked then return end
    notice.repairHooked = true
    local dragged = false
    notice:HookScript("OnDragStart", function() dragged = true end)
    notice:HookScript("OnMouseUp", function(_, button)
        if dragged then dragged = false return end
        if button == "LeftButton" then pcall(ns.PinNearestRepairer) end
    end)
end

----------------------------------------------------------------------------
-- 3. Known repairers on tooltips and when targeted
----------------------------------------------------------------------------

function ns.IsKnownIn(records, name)
    if not (records and Usable(name) and type(name) == "string") then return false end
    local mapID = PlayerSpot()
    if mapID and records[name .. "@" .. mapID] then return true end
    for _, record in pairs(records) do
        if record.name == name then return true end
    end
    return false
end

function ns.IsKnownRepairer(name)
    return ns.IsKnownIn(ns.db and ns.db.repairers, name)
end

function ns.AddRepairLine(tooltip)
    if not (ns.db and ns.db.repairGuide) or tooltip ~= GameTooltip then return end
    local ok, name, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or not unit or (UnitIsPlayer and UnitIsPlayer(unit)) then return end
    if not ns.IsKnownRepairer(name) then return end
    if ns.worn then
        tooltip:AddLine(("JunkMate: repairs here. Your gear is at %d%%."):format(ns.worn), 1, 0.65, 0.2)
    else
        tooltip:AddLine("JunkMate: repairs here", 0.85, 0.63, 0.40)
    end
    tooltip:Show()
end

local mentioned = {}
function ns.OnTargetChanged()
    if not (ns.worn and ns.db and ns.db.repairGuide) then return end
    local name = UnitName and UnitName("target")
    if not name or (UnitIsPlayer and UnitIsPlayer("target")) or not ns.IsKnownRepairer(name) then return end
    local now = GetTime()
    if mentioned[name] and now - mentioned[name] < TARGET_QUIET then return end
    mentioned[name] = now
    ns.Print(("%s repairs, and your gear is at %d%%."):format(name, ns.worn))
end

----------------------------------------------------------------------------

local guideTicker
-- Keeps the tracking and the "nearest repair" distance up to date.
function ns.UpdateRepairHelp()
    pcall(ns.UpdateRepairTracking)
    HookNotice()
    if ns.worn and ns.db and ns.db.repairGuide then
        if not guideTicker and C_Timer and C_Timer.NewTicker then
            guideTicker = C_Timer.NewTicker(GUIDE_REFRESH, function()
                if ns.worn then pcall(ns.UpdateDurability) end
            end)
        end
    elseif guideTicker then
        guideTicker:Cancel()
        guideTicker = nil
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "MERCHANT_SHOW" then
        pcall(ns.RememberRepairer)
    elseif event == "PLAYER_TARGET_CHANGED" then
        pcall(ns.OnTargetChanged)
    elseif event == "PLAYER_LOGIN" then
        HookNotice()
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
                and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
                pcall(ns.AddRepairLine, tooltip)
            end)
        end
    end
end)
for _, event in ipairs({ "MERCHANT_SHOW", "PLAYER_TARGET_CHANGED", "PLAYER_LOGIN" }) do
    pcall(events.RegisterEvent, events, event)
end
