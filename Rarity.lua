-- EqCharacterStats :: rarity borders, ported from the original ECO QoL module.
-- Original source: Equadis/ClassicOverhaul/modules/qol.lua (RARITY section).
-- GPL-3.0-or-later. Uses stock WoW 1.12 slot art and quality colours.
local M = EquadisCharacter
local RARITY_FLOOR = 2 -- 0 Poor, 1 Common: leave their borders unchanged.

-- Stock inventory slot ID -> suffix of Character/Inspect frame names.
local PAPERDOLL_SLOTS = {
    [0] = "AmmoSlot", "HeadSlot", "NeckSlot", "ShoulderSlot",
    "ShirtSlot", "ChestSlot", "WaistSlot", "LegsSlot",
    "FeetSlot", "WristSlot", "HandsSlot", "Finger0Slot",
    "Finger1Slot", "Trinket0Slot", "Trinket1Slot", "BackSlot",
    "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "TabardSlot",
}

local function qualityFromLink(link)
    if not link or type(GetItemInfo) ~= "function" then return nil end

    -- ECO's ItemQuery strips the numeric item ID before asking GetItemInfo;
    -- this matters for older 1.12 clients that do not accept full hyperlinks.
    local _, _, itemID = string.find(link, "item:(%d+)")
    if itemID then
        local _, _, quality = GetItemInfo(tonumber(itemID))
        if type(quality) == "number" then return quality end
    end

    local _, _, fallback = GetItemInfo(link)
    if type(fallback) == "number" then return fallback end
    return nil
end

local function inventoryQuality(unit, slot)
    local quality
    if type(GetInventoryItemQuality) == "function" then
        local ok, result = pcall(GetInventoryItemQuality, unit, slot)
        if ok and type(result) == "number" then quality = result end
    end
    if quality == nil and type(GetInventoryItemLink) == "function" then
        quality = qualityFromLink(GetInventoryItemLink(unit, slot))
    end
    return quality
end

function M:PaintRarityGlow(button, r, g, b)
    local cfg = self:Config()
    local glow = button.ecsRarityGlow

    if not r or not cfg.borderGlow then
        if glow then glow:Hide() end
        return false
    end

    if not glow then
        glow = button:CreateTexture(nil, "OVERLAY")
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        glow:SetBlendMode("ADD")
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)

        -- Same size and alpha as ECO; match the actual equipped-slot button.
        local size = (button.GetWidth and button:GetWidth() or 36) * 1.7
        glow:SetWidth(size)
        glow:SetHeight(size)
        button.ecsRarityGlow = glow
    end

    glow:SetVertexColor(r, g, b, tonumber(cfg.borderGlowAlpha) or 0.55)
    glow:Show()
    return true
end

function M:PaintRarity(button, quality)
    if not button or not button.GetNormalTexture then return false end
    local ring = button:GetNormalTexture()
    if not ring or not ring.SetVertexColor then return false end

    local cfg = self:Config()
    if not cfg.rarityBorders or type(quality) ~= "number"
            or quality < RARITY_FLOOR
            or type(GetItemQualityColor) ~= "function" then
        ring:SetVertexColor(1, 1, 1)
        self:PaintRarityGlow(button, nil)
        return false
    end

    local r, g, b = GetItemQualityColor(quality)
    if not r then
        ring:SetVertexColor(1, 1, 1)
        self:PaintRarityGlow(button, nil)
        return false
    end

    -- Reuse Blizzard's metal item-frame ring rather than adding a new frame.
    ring:SetVertexColor(r, g, b)
    self:PaintRarityGlow(button, r, g, b)
    return true
end

function M:RefreshPaperdollRarity()
    for slot, suffix in pairs(PAPERDOLL_SLOTS) do
        local button = getglobal("Character" .. suffix)
        if button then self:PaintRarity(button, inventoryQuality("player", slot)) end
    end
    return true
end

function M:RefreshInspectRarity(button)
    local frame = getglobal("InspectFrame")
    if not frame then return false end
    local unit = frame.unit or "target"

    if button and button.GetID then
        self:PaintRarity(button, inventoryQuality(unit, button:GetID()))
    else
        for slot, suffix in pairs(PAPERDOLL_SLOTS) do
            local item = getglobal("Inspect" .. suffix)
            if item then self:PaintRarity(item, inventoryQuality(unit, slot)) end
        end
    end
    return true
end

function M:RefreshBagRarity()
    if type(GetContainerItemLink) ~= "function" then return false end
    local per = MAX_CONTAINER_ITEMS or 20
    for bag = 1, 12 do
        local frame = getglobal("ContainerFrame" .. bag)
        if frame and frame.GetID then
            local bagID = frame:GetID()
            for index = 1, per do
                local button = getglobal("ContainerFrame" .. bag .. "Item" .. index)
                if button then
                    -- Buttons are displayed in reverse order to their bag slot.
                    -- Always use GetID, not the visual index.
                    local slot = (button.GetID and button:GetID()) or index
                    local link = GetContainerItemLink(bagID, slot)
                    self:PaintRarity(button, qualityFromLink(link))
                end
            end
        end
    end
    return true
end

function M:RefreshBankRarity()
    if type(GetContainerItemLink) ~= "function" then return false end
    for slot = 1, 28 do
        local button = getglobal("BankFrameItem" .. slot)
        if button then
            self:PaintRarity(button,
                qualityFromLink(GetContainerItemLink(-1, slot)))
        end
    end
    return true
end

function M:RefreshRarity()
    self:RefreshPaperdollRarity()
    self:RefreshInspectRarity()
    self:RefreshBagRarity()
    self:RefreshBankRarity()
end

-- Install once. The Inspect UI is load-on-demand, so this is called again
-- after other addons load and by the existing slow installer in Core.lua.
function M:InstallRarityHooks()
    if not self.ecsRarityBagHook
            and type(ContainerFrame_OnShow) == "function" then
        self.ecsRarityBagHook = true
        local old = ContainerFrame_OnShow
        ContainerFrame_OnShow = function()
            old()
            M:RefreshBagRarity()
        end
    end

    local bank = getglobal("BankFrame")
    if bank and not bank.ecsRarityHook then
        bank.ecsRarityHook = true
        local old = bank:GetScript("OnShow")
        bank:SetScript("OnShow", function()
            if old then old() end
            M:RefreshBankRarity()
        end)
    end

    local inspect = getglobal("InspectFrame")
    if inspect and not inspect.ecsRarityHook then
        inspect.ecsRarityHook = true

        -- The inspect window can appear before its inventory data arrives.
        -- The stock update routine runs whenever each slot is populated;
        -- refresh the updated slot, without repainting all slots per call.
        if type(InspectPaperDollItemSlotButton_Update) == "function" then
            local original = InspectPaperDollItemSlotButton_Update
            InspectPaperDollItemSlotButton_Update = function(button)
                local result = original(button)
                M:RefreshInspectRarity(button)
                return result
            end
        end

        local old = inspect:GetScript("OnShow")
        inspect:SetScript("OnShow", function()
            if old then old() end
            M:RefreshInspectRarity()
        end)
        self:RefreshInspectRarity()
    end
end
