local addonName, ns = ...

-- A button on the rim of the minimap that opens the options. While gear is
-- worn below the warning level, a blacksmith's hammer pulses in its corner,
-- and the window it opens says which piece and how worn. While the bags are
-- getting full it shows how many slots are left, in yellow, and a flashing
-- red "!" once they are full.

local button = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForDrag("LeftButton")
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide()

local background = button:CreateTexture(nil, "BACKGROUND")
background:SetSize(24, 24)
background:SetPoint("CENTER")
background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetSize(18, 18)
icon:SetPoint("CENTER")
icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local border = button:CreateTexture(nil, "OVERLAY")
border:SetSize(50, 50)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

-- The "!" for worn gear, on its own frame so it draws above the border.
local badge = CreateFrame("Frame", nil, button)
badge:SetAllPoints()
badge:SetFrameLevel(button:GetFrameLevel() + 2)
badge:Hide()
local mark = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
mark:SetPoint("CENTER", button, "CENTER", 9, 7)
pcall(mark.SetFont, mark, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 22, "THICKOUTLINE")
mark:SetTextColor(1, 0.15, 0.1)
mark:SetText("!")
ns.bagBadge = badge
ns.badgeMark = mark

-- Worn gear has its own sign, so it never looks like the bag warning: a
-- blacksmith's hammer in the bottom-left corner, pulsing.
local hammer = CreateFrame("Frame", nil, button)
hammer:SetSize(15, 15)
hammer:SetPoint("CENTER", button, "CENTER", -9, -8)
hammer:SetFrameLevel(button:GetFrameLevel() + 3)
hammer:Hide()
local hammerBack = hammer:CreateTexture(nil, "BACKGROUND")
hammerBack:SetPoint("TOPLEFT", -1, 1)
hammerBack:SetPoint("BOTTOMRIGHT", 1, -1)
hammerBack:SetColorTexture(0.85, 0.1, 0.05, 1)
local hammerIcon = hammer:CreateTexture(nil, "ARTWORK")
hammerIcon:SetAllPoints()
hammerIcon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
hammerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
ns.wornBadge = hammer

-- A gold coin in the bottom-right corner while you carry junk JunkMate
-- would sell (Vendor.lua counts it).
local junk = CreateFrame("Frame", nil, button)
junk:SetSize(13, 13)
junk:SetPoint("CENTER", button, "CENTER", 9, -8)
junk:SetFrameLevel(button:GetFrameLevel() + 3)
junk:Hide()
local junkIcon = junk:CreateTexture(nil, "ARTWORK")
junkIcon:SetAllPoints()
junkIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
ns.junkBadge = junk
local hammerPulse = hammer:CreateAnimationGroup()
hammerPulse:SetLooping("BOUNCE")
local hammerFade = hammerPulse:CreateAnimation("Alpha")
hammerFade:SetFromAlpha(1)
hammerFade:SetToAlpha(0.3)
hammerFade:SetDuration(0.6)

-- A slow pulse, so the mark catches the eye without flashing.
local pulse = badge:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.35)
fade:SetDuration(0.8)

local function Place()
    local angle = ns.db.minimapAngle
    local radius = Minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Dragging slides the button around the rim of the minimap.
local function FollowCursor(self)
    -- Stop as soon as the mouse button is up, even if the game never sent
    -- OnDragStop (it can go missing when two buttons overlap).
    if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
        self:SetScript("OnUpdate", nil)
        return
    end
    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimapAngle = math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)
    Place()
end

button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", FollowCursor) end)
button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
button:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
-- Left-click: the options. Right-click: a map pin on the nearest vendor.
button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
        if ns.PinNearestVendor then pcall(ns.PinNearestVendor) end
    else
        ns.ToggleOptions()
    end
end)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("JunkMate")
    if ns.worn then
        GameTooltip:AddLine(("Gear worn: %d%% left"):format(ns.worn), 1, 0.3, 0.25)
    end
    if ns.bagsLow then
        if ns.bagsLow == 0 then
            GameTooltip:AddLine("Bags full", 1, 0.3, 0.25)
        else
            GameTooltip:AddLine(("Bags nearly full: %d slot%s left"):format(ns.bagsLow, ns.bagsLow == 1 and "" or "s"), 1, 0.82, 0.2)
        end
    end
    if ns.junkCount and ns.junkCount > 0 then
        GameTooltip:AddLine(("Junk to sell: %d item%s (%s)"):format(ns.junkCount, ns.junkCount == 1 and "" or "s",
            ns.Money(ns.junkValue or 0)), 1, 0.82, 0.2)
        local nearest = ns.NearestVendorText and ns.NearestVendorText()
        if nearest then GameTooltip:AddLine(nearest, 1, 1, 1) end
    end
    GameTooltip:AddLine("Click: options, gear and bags", 1, 1, 1)
    if ns.junkCount and ns.junkCount > 0 then
        GameTooltip:AddLine("Right-click: map pin on the nearest vendor", 1, 1, 1)
    end
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Shows or hides the button as the setting says, with the "!" while gear
-- is worn (red) or the bags are nearly full (yellow; red once full).
function ns.UpdateMinimapButton()
    if not ns.db then return end
    if ns.db.minimapButton then
        Place()
        button:Show()
    else
        button:Hide()
    end
    -- Worn gear: the pulsing hammer.
    if ns.worn then
        hammer:Show()
        if not hammerPulse:IsPlaying() then hammerPulse:Play() end
    else
        hammerPulse:Stop()
        hammer:Hide()
    end
    -- Full bags: a flashing red "!". Bags getting low: how many slots are
    -- left, in yellow, steady.
    junk:SetShown((ns.junkCount or 0) > 0)
    if ns.bagsLow == 0 then
        mark:SetText("!")
        mark:SetTextColor(1, 0.15, 0.1)
        badge:Show()
        if not pulse:IsPlaying() then pulse:Play() end
    elseif ns.bagsLow then
        pulse:Stop()
        badge:SetAlpha(1)
        mark:SetText(tostring(ns.bagsLow))
        mark:SetTextColor(1, 0.82, 0.1)
        badge:Show()
    else
        pulse:Stop()
        badge:Hide()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function() ns.UpdateMinimapButton() end)
