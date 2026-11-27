local addonName, ns = ...

-- A small options window, drawn from plain colours so it needs no texture
-- files. Everything here can also be set with /junkmate.

local ACCENT_R, ACCENT_G, ACCENT_B = 0.85, 0.63, 0.40

local window
local status, bagStatus
local controls = {}

local function Fill(frame, r, g, b, a)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function Outline(frame, alpha)
    local function Edge(point1, point2, isVertical)
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, alpha)
        edge:SetPoint(point1)
        edge:SetPoint(point2)
        if isVertical then edge:SetWidth(1) else edge:SetHeight(1) end
    end
    Edge("TOPLEFT", "TOPRIGHT", false)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", false)
    Edge("TOPLEFT", "BOTTOMLEFT", true)
    Edge("TOPRIGHT", "BOTTOMRIGHT", true)
end

-- A row that reads its text and tick from the saved settings each time it
-- is refreshed, and changes them when clicked.
ns.Fill, ns.Outline = Fill, Outline

local function CreateRow(parent, y, isCheckbox, getText, isTicked, onClick)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(300, 24)
    row:SetPoint("TOPLEFT", 14, y)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.07)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local tick
    if isCheckbox then
        local box = CreateFrame("Frame", nil, row)
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 2, 0)
        Fill(box, 0, 0, 0, 0.5)
        Outline(box, 0.7)
        tick = box:CreateTexture(nil, "ARTWORK")
        tick:SetPoint("TOPLEFT", 3, -3)
        tick:SetPoint("BOTTOMRIGHT", -3, 3)
        tick:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
        label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    else
        Fill(row, 1, 1, 1, 0.06)
        Outline(row, 0.35)
        label:SetPoint("CENTER")
    end

    function row.Refresh()
        label:SetText(getText())
        if tick then
            tick:SetShown(isTicked() and true or false)
        end
    end
    row:SetScript("OnClick", function()
        onClick()
        ns.UpdateDurability()
        if ns.UpdateBags then pcall(ns.UpdateBags) end
        ns.RefreshOptions()
    end)
    controls[#controls + 1] = row
    return row
end

local function CreateWindow()
    window = CreateFrame("Frame", addonName .. "Options", UIParent)
    window:SetSize(652, 512)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    Fill(window, 0.05, 0.05, 0.06, 0.97)
    Outline(window, 0.55)
    -- Lets Escape close the window.
    tinsert(UISpecialFrames, addonName .. "Options")
    ns.CloseWithPadB(window)

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("JunkMate")

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

    -- The gear's condition, so the minimap button's "!" has an answer here.
    status = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", 16, -40)
    status:SetWidth(620)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(true)
    -- And the bags' free slots, just under it.
    bagStatus = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bagStatus:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -4)
    bagStatus:SetWidth(620)
    bagStatus:SetJustifyH("LEFT")

    CreateRow(window, -100, true,
        function() return "Sell junk when a vendor opens" end,
        function() return ns.db.sellJunk end,
        function() ns.db.sellJunk = not ns.db.sellJunk end)
    CreateRow(window, -128, true,
        function() return "Repair when a vendor who can opens" end,
        function() return ns.db.repair end,
        function() ns.db.repair = not ns.db.repair end)
    CreateRow(window, -156, true,
        function() return "Say in chat what was sold and repaired" end,
        function() return ns.db.report end,
        function() ns.db.report = not ns.db.report end)
    CreateRow(window, -192, true,
        function() return "Warn on screen when gear is wearing out" end,
        function() return ns.db.durabilityWarn end,
        function() ns.db.durabilityWarn = not ns.db.durabilityWarn end)
    -- Cycles through the levels the warning can be set to.
    CreateRow(window, -222, false,
        function() return ("Warn below %d%% durability"):format(ns.db.durabilityLevel) end,
        nil,
        function()
            local levels = ns.DURABILITY_LEVELS
            local nextLevel = levels[1]
            for index, level in ipairs(levels) do
                if level == ns.db.durabilityLevel then
                    nextLevel = levels[index % #levels + 1]
                end
            end
            ns.db.durabilityLevel = nextLevel
        end)

    CreateRow(window, -254, true,
        function() return "Warn when your bags are nearly full" end,
        function() return ns.db.bagWarn end,
        function() ns.db.bagWarn = not ns.db.bagWarn end)
    -- Cycles through the numbers of free slots the warning can be set to.
    CreateRow(window, -284, false,
        function() return ("Warn at %d free bag slots or fewer"):format(ns.db.bagLevel) end,
        nil,
        function()
            local levels = ns.BAG_LEVELS
            local nextLevel = levels[1]
            for index, level in ipairs(levels) do
                if level == ns.db.bagLevel then
                    nextLevel = levels[index % #levels + 1]
                end
            end
            ns.db.bagLevel = nextLevel
        end)

    CreateRow(window, -316, true,
        function() return "Show vendor prices on item tooltips" end,
        function() return ns.db.priceTooltip end,
        function() ns.db.priceTooltip = not ns.db.priceTooltip end)
    CreateRow(window, -344, true,
        function() return "Show the minimap button" end,
        function() return ns.db.minimapButton end,
        function()
            ns.db.minimapButton = not ns.db.minimapButton
            ns.UpdateMinimapButton()
        end)

    CreateRow(window, -380, true,
        function() return "Offer to make room when loot won't fit" end,
        function() return ns.db.makeRoom end,
        function() ns.db.makeRoom = not ns.db.makeRoom end)
    CreateRow(window, -408, true,
        function() return "Restack when bags get nearly full" end,
        function() return ns.db.restack end,
        function() ns.db.restack = not ns.db.restack end)
    CreateRow(window, -436, true,
        function() return "Tidy the bank when it opens" end,
        function() return ns.db.bankTidy end,
        function() ns.db.bankTidy = not ns.db.bankTidy end)
    CreateRow(window, -464, true,
        function() return "Also sell outgrown food, unusable gear" end,
        function() return ns.db.sellExtras end,
        function() ns.db.sellExtras = not ns.db.sellExtras end)
    CreateRow(window, -492, true,
        function() return "Say on tooltips what JunkMate does" end,
        function() return ns.db.whyTooltip end,
        function() ns.db.whyTooltip = not ns.db.whyTooltip end)
    CreateRow(window, -520, true,
        function() return "Open clams and the like as bags fill" end,
        function() return ns.db.openContainers end,
        function() ns.db.openContainers = not ns.db.openContainers end)
    CreateRow(window, -548, true,
        function() return "Track repairers on the minimap when worn" end,
        function() return ns.db.repairTracking end,
        function()
            ns.db.repairTracking = not ns.db.repairTracking
            if ns.UpdateRepairTracking then pcall(ns.UpdateRepairTracking) end
        end)
    CreateRow(window, -576, true,
        function() return "Point to the nearest repairer when worn" end,
        function() return ns.db.repairGuide end,
        function() ns.db.repairGuide = not ns.db.repairGuide end)
    CreateRow(window, -604, true,
        function() return "Pin the nearest vendor when you have junk" end,
        function() return ns.db.vendorGuide end,
        function()
            ns.db.vendorGuide = not ns.db.vendorGuide
            if ns.UpdateVendorHelp then pcall(ns.UpdateVendorHelp) end
        end)

    CreateRow(window, 0, true,
        function() return "Show the worn-gear line on screen" end,
        function() return ns.db.wornBanner end,
        function()
            ns.db.wornBanner = not ns.db.wornBanner
            pcall(ns.UpdateDurability)
        end)

    CreateRow(window, 0, true,
        function() return "Show the junk-to-sell line on screen" end,
        function() return ns.db.junkBanner end,
        function()
            ns.db.junkBanner = not ns.db.junkBanner
            if ns.UpdateVendorHelp then pcall(ns.UpdateVendorHelp) end
        end)

    CreateRow(window, 0, true,
        function() return "Show vendors on the minimap when you have junk" end,
        function() return ns.db.vendorMinimap end,
        function()
            ns.db.vendorMinimap = not ns.db.vendorMinimap
            if ns.UpdateTracking then pcall(ns.UpdateTracking) end
            if ns.UpdateVendorHelp then pcall(ns.UpdateVendorHelp) end
        end)

    -- Two columns under headings. The rows were made in the order above
    -- (which /junkmate and the tests rely on); here is where each one goes.
    local LEFT, RIGHT = 14, 338
    local function Heading(text, x, y)
        local heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", x + 2, y)
        heading:SetText(text)
        heading:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B)
    end
    Heading("At a vendor", LEFT, -88)
    Heading("Worn gear", LEFT, -314)
    Heading("Bags", RIGHT, -88)
    Heading("Tooltips and minimap", RIGHT, -288)
    local PLACES = {
        [1] = { LEFT, -108 },   -- sell junk
        [13] = { LEFT, -136 },  -- also sell outgrown food, unusable gear
        [2] = { LEFT, -164 },   -- repair
        [3] = { LEFT, -192 },   -- say in chat
        [18] = { LEFT, -220 },  -- name the nearest vendor
        [20] = { LEFT, -248 },  -- the junk line on screen
        [21] = { LEFT, -276 },  -- vendors on the minimap
        [4] = { LEFT, -334 },   -- warn when gear is wearing out
        [19] = { LEFT, -362 },  -- the worn-gear line on screen
        [5] = { LEFT, -392 },   -- warn below N%
        [16] = { LEFT, -422 },  -- track repairers on the minimap
        [17] = { LEFT, -450 },  -- point to the nearest repairer
        [6] = { RIGHT, -108 },  -- warn when bags are nearly full
        [7] = { RIGHT, -136 },  -- warn at N free slots
        [10] = { RIGHT, -166 }, -- make room when loot won't fit
        [11] = { RIGHT, -194 }, -- restack
        [15] = { RIGHT, -222 }, -- open clams
        [12] = { RIGHT, -250 }, -- tidy the bank
        [8] = { RIGHT, -308 },  -- vendor prices on tooltips
        [14] = { RIGHT, -336 }, -- say on tooltips what JunkMate does
        [9] = { RIGHT, -364 },  -- the minimap button
    }
    for index, row in ipairs(controls) do
        local place = PLACES[index]
        if place then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", place[1], place[2])
        end
    end

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", 16, 12)
    hint:SetText("Hold Shift at a vendor or the bank to skip it. Drag the lines on screen to move them.")
end

function ns.RefreshOptions()
    -- Called on every bag and gear change: nothing to do while it is closed.
    if not (window and window:IsShown()) then return end
    for _, control in ipairs(controls) do
        control.Refresh()
    end
    if status then
        local text, r, g, b = ns.GearStatus()
        status:SetText(text)
        status:SetTextColor(r, g, b)
    end
    if bagStatus and ns.BagStatus then
        local text, r, g, b = ns.BagStatus()
        bagStatus:SetText(text)
        bagStatus:SetTextColor(r, g, b)
    end
end

function ns.ToggleOptions()
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
        ns.RefreshOptions()
    end
end
