local addonName, ns = ...

-- Vendor price on item tooltips: what an item sells for at a vendor, and
-- for a stack what the whole stack is worth, so deciding between vendor,
-- auction house and mailing to a bank alt takes one look. Items a vendor
-- will not buy say so. Where the game already shows its own "Sell Price"
-- line on the tooltip, JunkMate adds nothing, so the price never shows twice.
--
-- Uses the game's tooltip post-call (TooltipDataProcessor), the supported
-- way to add lines, and only on the main tooltip and a clicked link's.

local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Money with the game's coin icons where it offers them, else as text.
local function MoneyText(copper)
    local coins = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
    if coins then
        local ok, text = pcall(coins, copper)
        if ok and Usable(text) and type(text) == "string" then return text end
    end
    return ns.Money(copper)
end

-- What one of the item sells for, in copper; 0 if vendors will not buy it;
-- nil if the game has not loaded the item yet.
function ns.SellPrice(itemID)
    if not (C_Item and C_Item.GetItemInfo) then return nil end
    local result = { pcall(C_Item.GetItemInfo, itemID) }
    if not result[1] or result[2] == nil then return nil end
    local price = result[12]   -- the 11th value GetItemInfo returns
    if not Usable(price) or type(price) ~= "number" then return nil end
    return price
end

-- The tooltip line for an item, and a stack of `count` of it: text, or nil.
function ns.PriceLine(itemID, count)
    local price = ns.SellPrice(itemID)
    if price == nil then return nil end
    if price == 0 then return "Vendor: can't be sold", true end
    local text = "Vendor: " .. MoneyText(price) .. " each"
    if type(count) == "number" and count > 1 then
        text = text .. (", %d for %s"):format(count, MoneyText(price * count))
    end
    return text
end

-- How many are in the stack being looked at: the bag button under the
-- tooltip keeps its count.
local function StackCount(tooltip)
    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    local count = ok and type(owner) == "table" and rawget(owner, "count")
    return (Usable(count) and type(count) == "number") and count or 1
end

-- Whether the game's own tooltip already has a sell price on it.
local function GameShowsPrice(data)
    local kind = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SellPrice
    if not kind or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        if line.type == kind then return true end
    end
    return false
end

function ns.AddPrice(tooltip, data)
    if not ns.db or not ns.db.priceTooltip then return end
    local itemID = data and data.id
    if not Usable(itemID) or type(itemID) ~= "number" then return end
    if GameShowsPrice(data) then return end
    local text, unsellable = ns.PriceLine(itemID, StackCount(tooltip))
    if not text then return end
    if unsellable then
        tooltip:AddLine(text, 0.6, 0.6, 0.6)
    else
        tooltip:AddLine(text, 1, 1, 1)
    end
    tooltip:Show()
end

local function Wanted(tooltip)
    return tooltip == GameTooltip or (ItemRefTooltip and tooltip == ItemRefTooltip)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
            and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if Wanted(tooltip) then pcall(ns.AddPrice, tooltip, data) end
        end)
    end
end)
