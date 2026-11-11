-- EquadisCharacter: standalone foundation for WoW 1.12 (Lua 5.0).
-- The stat calculator is extracted from ClassicOverhaul, under GPL-3.0-or-later.
EquadisCharacter = {}
EquadisCharacterAPI = {}
local M = EquadisCharacter
local A = EquadisCharacterAPI

function A.Round(n)
    if n >= 0 then return math.floor(n + 0.5) end
    return math.ceil(n - 0.5)
end

function A.ModuleEnabled() return true end

function A.NewText(parent, layer, template)
    return parent:CreateFontString(nil, layer, template)
end

function A.OwnTooltip(owner, anchor)
    if GameTooltip and GameTooltip.SetOwner then
        GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    end
end

-- The original stats scanner needs a dedicated tooltip with predictable line
-- names. Never use GameTooltip itself; it is also used for hovering stat rows.
function A.ScanTooltip()
    if not A.tooltip and UIParent and CreateFrame then
        A.tooltip = CreateFrame("GameTooltip", "EquadisCharacterScanTooltip",
            UIParent, "GameTooltipTemplate")
        A.tooltip:Hide()
    end
    return A.tooltip
end

function A.ScanLine(i)
    local text = getglobal("EquadisCharacterScanTooltipTextLeft" .. tostring(i))
    if text and text.GetText then return text:GetText() end
    return nil
end

function M:Config()
    return EquadisCharacterDB
end

local DEFAULTS = {
    statPanes = true,
    statFontSize = 10,
    leftGroup = "base",
    rightGroup = "melee",
    modelRotate = true,
    modelRotateSpeed = 0.010,
    panSensitivity = 10,
    rarityBorders = true,
    borderGlow = true,
    borderGlowAlpha = 0.55,
    zoomStep = 0.15,
    zoomMin = 0.6,
    zoomMax = 3.0,
}

function M:Print(message)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff74d9a2EquadisCharacter:|r " .. tostring(message))
    end
end

function M:Refresh()
    local doll = getglobal("PaperDollFrame")
    if doll and doll.IsShown and doll:IsShown() and self.ApplyStats then
        self:ApplyStats()
    end
    if doll and doll.IsShown and doll:IsShown()
            and self.RefreshPaperdollRarity then
        self:RefreshPaperdollRarity()
    end
    if self.InstallModelControls then self:InstallModelControls() end
end

function M:Initialize()
    if self.initialized then return end
    if type(EquadisCharacterDB) ~= "table" then EquadisCharacterDB = {} end
    -- One-time +2pt migration for users who already had an 8pt (or custom)
    -- font setting. New installs get the 10pt default without doubling it.
    if not EquadisCharacterDB.fontSizeRaised012 then
        if type(EquadisCharacterDB.statFontSize) == "number" then
            EquadisCharacterDB.statFontSize =
                math.min(14, EquadisCharacterDB.statFontSize + 2)
        end
        EquadisCharacterDB.fontSizeRaised012 = true
    end
    for key, value in pairs(DEFAULTS) do
        if EquadisCharacterDB[key] == nil then EquadisCharacterDB[key] = value end
    end
    self.initialized = true

    local doll = getglobal("PaperDollFrame")
    if doll and doll.GetScript and not doll.ecsHooked then
        doll.ecsHooked = true
        local previous = doll:GetScript("OnShow")
        doll:SetScript("OnShow", function()
            if previous then previous() end
            M:Refresh()
        end)
    end
    if self.InstallRarityHooks then self:InstallRarityHooks() end
    if self.RefreshRarity then self:RefreshRarity() end
    self:Refresh()
end

local driver = CreateFrame("Frame", "EquadisCharacterDriver")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("UNIT_INVENTORY_CHANGED")
driver:RegisterEvent("BAG_UPDATE")
driver:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
driver:RegisterEvent("BANKFRAME_OPENED")
driver:RegisterEvent("PLAYER_AURAS_CHANGED")
driver:RegisterEvent("UNIT_AURA")
driver:RegisterEvent("PLAYER_LEVEL_UP")
driver:RegisterEvent("CHARACTER_POINTS_CHANGED")
driver:RegisterEvent("SPELLS_CHANGED")
driver:RegisterEvent("LEARNED_SPELL_IN_TAB")
driver:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
driver:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" then
        if arg1 == "EqCharacterStats" then M:Initialize() end
        if M.initialized and M.InstallModelControls then M:InstallModelControls() end
        if M.initialized and M.InstallRarityHooks then M:InstallRarityHooks() end
        return
    end
    if not M.initialized then M:Initialize() end
    if (event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_AURA")
            and arg1 and arg1 ~= "player" then return end
    if event == "BAG_UPDATE" then
        if M.RefreshBagRarity then M:RefreshBagRarity() end
        return
    end
    if event == "PLAYERBANKSLOTS_CHANGED" or event == "BANKFRAME_OPENED" then
        if M.RefreshBankRarity then M:RefreshBankRarity() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" and M.RefreshRarity then
        M:RefreshRarity()
    end
    if M.initialized then
        M.gearAt, M.talentsAt, M.aurasAt = nil, nil, nil
        M:Refresh()
    end
end)

-- Inspect and dressing-room models can load after the base UI; retry at a
-- slow cadence without scanning or repainting the stat sheet each frame.
driver:SetScript("OnUpdate", function()
    if not M.initialized then return end
    M.installElapsed = (M.installElapsed or 0) + (arg1 or 0)
    if M.installElapsed >= 2 then
        M.installElapsed = 0
        if M.InstallModelControls then M:InstallModelControls() end
        if M.InstallRarityHooks then M:InstallRarityHooks() end
    end
end)

SLASH_EQUADISCHARACTER1 = "/ecs"
SLASH_EQUADISCHARACTER2 = "/equadischaracter"
SlashCmdList["EQUADISCHARACTER"] = function(msg)
    if not M.initialized then M:Initialize() end
    local _, _, command, value = string.find(msg or "", "^(%S+)%s*(.-)%s*$")
    command = command and string.lower(command) or ""
    value = value and string.lower(value) or ""
    local db = M:Config()

    if command == "stats" and (value == "on" or value == "off") then
        db.statPanes = (value == "on")
        M:ApplyStats()
        M:Print("Stats " .. value)
    elseif command == "model" and (value == "on" or value == "off") then
        db.modelRotate = (value == "on")
        if M.UpdateModelArrows then M:UpdateModelArrows() end
        M:Print("Model controls " .. value)
    elseif command == "rarity" and (value == "on" or value == "off") then
        db.rarityBorders = (value == "on")
        if M.RefreshRarity then M:RefreshRarity() end
        M:Print("Rarity borders " .. value)
    elseif command == "glow" and (value == "on" or value == "off") then
        db.borderGlow = (value == "on")
        if M.RefreshRarity then M:RefreshRarity() end
        M:Print("Rarity glow " .. value)
    elseif command == "glowalpha" and tonumber(value) then
        local n = tonumber(value)
        if n >= 0 and n <= 1 then
            db.borderGlowAlpha = n
            if M.RefreshRarity then M:RefreshRarity() end
            M:Print("Glow opacity: " .. tostring(n))
        else
            M:Print("Glow opacity must be 0-1.")
        end
    elseif command == "font" and tonumber(value) then
        local n = tonumber(value)
        if n >= 6 and n <= 14 then
            db.statFontSize = n
            M:Refresh()
        else
            M:Print("Font size must be 6-14.")
        end
    elseif command == "pan" and tonumber(value) then
        local n = tonumber(value)
        if n >= 1 and n <= 30 then
            db.panSensitivity = n
            M:Print("Pan sensitivity: " .. tostring(n))
        else
            M:Print("Pan sensitivity must be 1-30.")
        end
    elseif command == "left" or command == "right" then
        local selected
        if M.statGroups then
            for i = 1, table.getn(M.statGroups) do
                if M.statGroups[i].id == value then selected = true end
            end
        end
        if selected then
            M:SetPaneGroup(command, value)
        else
            M:Print("Unknown group. Use base, melee, meleeboss, ranged, spell, schools, defense, defenseboss or resist.")
        end
    elseif command == "reset" then
        if M.ResetModels then M:ResetModels() end
        M:Print("Model zoom and position reset.")
    else
        M:Print("/ecs stats on|off; model on|off; rarity on|off; glow on|off; glowalpha 0-1; left|right <group>; font 6-14; pan 1-30; reset")
    end
end
