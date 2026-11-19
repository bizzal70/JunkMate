local addonName, ns = ...

-- A button on the rim of the minimap that opens the options. While gear is
-- worn below the warning level, a red "!" pulses on it, and the window it
-- opens says which piece and how worn.

local button = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForDrag("LeftButton")
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
ns.wornBadge = badge

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
button:SetScript("OnClick", function() ns.ToggleOptions() end)
button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("JunkMate")
    if ns.worn then
        GameTooltip:AddLine(("Gear worn: %d%% left"):format(ns.worn), 1, 0.3, 0.25)
    end
    GameTooltip:AddLine("Click: options and gear condition", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Shows or hides the button as the setting says, with the "!" while gear
-- is worn.
function ns.UpdateMinimapButton()
    if not ns.db then return end
    if ns.db.minimapButton then
        Place()
        button:Show()
    else
        button:Hide()
    end
    if ns.worn then
        badge:Show()
        if not pulse:IsPlaying() then pulse:Play() end
    else
        pulse:Stop()
        badge:Hide()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function() ns.UpdateMinimapButton() end)
