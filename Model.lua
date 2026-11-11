-- Mouse manipulation of the paper-doll, inspect and dressing-room models.
-- Extracted from ClassicOverhaul/modules/qol.lua, with rotation direction
-- corrected and zoom/pan added for WoW 1.12 / Lua 5.0.
-- GPL-3.0-or-later.
local M = EquadisCharacter
local MODEL_FRAMES = { "CharacterModelFrame", "DressUpModel", "InspectModelFrame" }
local ARROWS = { "RotateLeftButton", "RotateRightButton" }

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function cursor()
    if type(GetCursorPosition) ~= "function" then return nil end
    return GetCursorPosition()
end

local function modelCoordsPerPixel()
    -- SetPosition coordinates are normalised to the display diagonal.
    -- This converts physical cursor pixels into model-position units.
    if type(GetScreenWidth) ~= "function"
            or type(GetScreenHeight) ~= "function" then return 0.001 end
    local scale = 1
    if UIParent and UIParent.GetEffectiveScale then
        scale = UIParent:GetEffectiveScale() or 1
    end
    local w = GetScreenWidth() * scale
    local h = GetScreenHeight() * scale
    local diagonal = math.sqrt(w * w + h * h)
    if diagonal <= 0 then return 0.001 end
    return 1 / diagonal
end

local function rememberBase(frame)
    if frame.ecsBaseScale == nil then
        local scale
        if frame.GetModelScale then
            local ok, result = pcall(frame.GetModelScale, frame)
            if ok and type(result) == "number" and result > 0 then
                scale = result
            end
        end
        frame.ecsBaseScale = scale or 1
        frame.ecsZoom = 1
    end
    if not frame.ecsBasePosition then
        local x, y, z
        if frame.GetPosition then
            local ok, a, b, c = pcall(frame.GetPosition, frame)
            if ok then x, y, z = a, b, c end
        end
        frame.ecsBasePosition = { x or 0, y or 0, z or 0 }
        frame.ecsPosition = { x or 0, y or 0, z or 0 }
    end
end

function M:MoveModel(frame, dx, dy)
    if not frame or not frame.SetPosition then return false end
    rememberBase(frame)
    local p = frame.ecsPosition
    local factor = modelCoordsPerPixel()
    -- On this 1.12 client the model camera looks along the X axis:
    -- X controls depth, Y controls on-screen horizontal, Z vertical.
    -- Keep X unchanged so right-drag cannot zoom the model.
    p[2] = p[2] + dx * factor
    p[3] = p[3] + dy * factor
    frame:SetPosition(p[1], p[2], p[3])
    return true
end

function M:ZoomModel(frame, delta)
    if not frame or not frame.SetModelScale or not delta or delta == 0 then
        return false
    end
    rememberBase(frame)
    local cfg = self:Config()
    local step = tonumber(cfg.zoomStep) or 0.15
    local nextZoom = clamp((frame.ecsZoom or 1) * (1 + step * delta),
        tonumber(cfg.zoomMin) or 0.6, tonumber(cfg.zoomMax) or 3.0)
    frame.ecsZoom = nextZoom
    frame:SetModelScale(frame.ecsBaseScale * nextZoom)
    return true
end

function M:RotateModel(frame, dx)
    if not frame or not frame.GetFacing or not frame.SetFacing then
        return false
    end
    local speed = tonumber(self:Config().modelRotateSpeed) or 0.010
    -- Positive facing is counterclockwise. Dragging right must increase it.
    frame:SetFacing((frame:GetFacing() or 0) + dx * speed)
    return true
end

function M:ResetModels()
    for i = 1, table.getn(MODEL_FRAMES) do
        local frame = getglobal(MODEL_FRAMES[i])
        if frame then
            if frame.ecsBaseScale and frame.SetModelScale then
                frame:SetModelScale(frame.ecsBaseScale)
            end
            if frame.ecsBasePosition and frame.SetPosition then
                local p = frame.ecsBasePosition
                frame:SetPosition(p[1], p[2], p[3])
            end
            frame.ecsZoom = 1
            if frame.ecsBasePosition then
                local p = frame.ecsBasePosition
                frame.ecsPosition = { p[1], p[2], p[3] }
            end
            frame.ecsDrag = nil
        end
    end
end

function M:UpdateModelArrows()
    local show = not self:Config().modelRotate
    for i = 1, table.getn(MODEL_FRAMES) do
        local name = MODEL_FRAMES[i]
        for j = 1, table.getn(ARROWS) do
            local button = getglobal(name .. ARROWS[j])
            if button then
                if show then button:Show() else button:Hide() end
            end
        end
    end
end

function M:InstallModelControls()
    for i = 1, table.getn(MODEL_FRAMES) do
        local frame = getglobal(MODEL_FRAMES[i])
        if frame and frame.GetFacing and frame.SetFacing and not frame.ecsModelHooked then
            frame.ecsModelHooked = true
            frame:EnableMouse(true)
            -- The original ClassicOverhaul rotation registered left drag.
            -- Restore this for the stock 1.12 model's mouse handling.
            if frame.RegisterForDrag then frame:RegisterForDrag("LeftButton") end
            if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end

            local oldDown = frame:GetScript("OnMouseDown")
            local oldUp = frame:GetScript("OnMouseUp")
            local oldUpdate = frame:GetScript("OnUpdate")
            local oldWheel = frame:GetScript("OnMouseWheel")
            local oldHide = frame:GetScript("OnHide")

            frame:SetScript("OnMouseDown", function()
                -- Older 1.12 handlers can omit arg1 for the primary button.
                -- Preserve the button before calling any inherited handler.
                local model, button = this, arg1 or "LeftButton"
                if oldDown then oldDown() end
                if not M:Config().modelRotate then return end
                if button ~= "LeftButton" and button ~= "RightButton" then return end
                local x, y = cursor()
                if not x then return end
                rememberBase(model)
                model.ecsDrag = { button = button, x = x, y = y }
            end)

            frame:SetScript("OnMouseUp", function()
                if oldUp then oldUp() end
                if this.ecsDrag and (not arg1 or arg1 == this.ecsDrag.button) then
                    this.ecsDrag = nil
                end
            end)

            frame:SetScript("OnUpdate", function()
                if oldUpdate then oldUpdate() end
                local drag = this.ecsDrag
                if not drag then return end
                if not M:Config().modelRotate then this.ecsDrag = nil; return end
                if type(IsMouseButtonDown) == "function"
                        and not IsMouseButtonDown(drag.button) then
                    this.ecsDrag = nil
                    return
                end

                local x, y = cursor()
                if not x then return end
                local dx, dy = x - drag.x, y - drag.y
                drag.x, drag.y = x, y
                if dx == 0 and dy == 0 then return end

                if drag.button == "LeftButton" then
                    M:RotateModel(this, dx)
                elseif drag.button == "RightButton" then
                    M:MoveModel(this, dx, dy)
                end
            end)

            frame:SetScript("OnMouseWheel", function()
                if M:Config().modelRotate and M:ZoomModel(this, arg1) then return end
                if oldWheel then oldWheel() end
            end)

            frame:SetScript("OnHide", function()
                this.ecsDrag = nil
                if oldHide then oldHide() end
            end)
        end
    end
    self:UpdateModelArrows()
end
