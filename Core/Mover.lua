-- ====================================
-- \Core\Mover.lua
-- ====================================
-- This file handles the positioning and movement of the main addon frame.

local addonName, ns = ...

-- Retrieves the saved position from the database.
local function GetPos()
    ClickableRaidBuffsDB = ClickableRaidBuffsDB or {}
    ClickableRaidBuffsDB.position = ClickableRaidBuffsDB.position or { x = 0, y = 0 }
    return ClickableRaidBuffsDB.position
end

-- Create the main parent frame for rendering icons.
local parent = CreateFrame("Frame", addonName .. "RenderParent", UIParent)
parent:SetFrameStrata("MEDIUM")
do
    local pos = GetPos()
    -- Defer positioning if in combat to avoid taint.
    if InCombatLockdown() or ns._combat_suspended then
        ns._pendingPos = { x = pos.x or 0, y = pos.y or 0 }
    else
        parent:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
    end
end
parent:SetMovable(true)
parent:SetClampedToScreen(true)
parent:EnableMouse(false)
ns.RenderParent = parent

-- Create an overlay frame (usage context unclear, possibly for blocking clicks or visual effects).
local overlay = CreateFrame("Frame", addonName .. "Overlay", UIParent, "BackdropTemplate")
overlay:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
overlay:SetBackdropColor(0,0,0,0)
overlay:SetFrameStrata("BACKGROUND")
overlay:Hide()
ns.Overlay = overlay

-- Create a hover frame (usage context unclear).
local hover = CreateFrame("Frame", addonName .. "OverlayHover", UIParent)
hover:SetFrameStrata("BACKGROUND")
hover:Hide()
ns.Hover = hover

-- Applies the saved position to the parent frame.
-- Skipped during combat.
local function ApplyPosition()
    local pos = GetPos()
    if InCombatLockdown() or ns._combat_suspended then
        ns._pendingPos = { x = pos.x or 0, y = pos.y or 0 }
        return
    end
    parent:ClearAllPoints()
    parent:SetPoint("CENTER", UIParent, "CENTER", pos.x or 0, pos.y or 0)
    if ns._mover then
        ns._mover:ClearAllPoints()
        ns._mover:SetPoint("CENTER", parent, "CENTER")
    end
end

-- Teleports the mover frame to specific coordinates.
local function TeleportMover(x, y)
    local pos = GetPos()
    pos.x, pos.y = x or 0, y or 0
    ApplyPosition()
end
ns.TeleportMover = TeleportMover

-- Nudges the mover frame by a delta.
local function NudgeMover(dx, dy)
    local pos = GetPos()
    pos.x, pos.y = (pos.x or 0) + dx, (pos.y or 0) + dy
    ApplyPosition()
end
ns.NudgeMover = NudgeMover

-- Updates the size of the mover frame to match the parent frame plus padding.
local function UpdateMoverSize()
    if not ns._mover or not parent then return end
    local w, h = parent:GetSize()
    local size = (ClickableRaidBuffsDB.iconSize or ns.BASE_ICON_SIZE or 50)
    local pad = size
    ns._mover:SetSize((w > 0 and w or 1) + pad*2, (h > 0 and h or 1) + pad*2)
end
ns.UpdateMoverSize = UpdateMoverSize

-- Safely triggers a render update.
-- Skipped during combat.
local function SafeRenderAll()
    if not ns.RenderAll then return end
    if InCombatLockdown() or ns._combat_suspended then
        ns._pendingRender = true
        return
    end
    ns.RenderAll()
end

-- Toggles the visibility of the mover frame (unlock/lock).
-- Skipped during combat.
function ns.ToggleMover(show)
    if InCombatLockdown() or ns._combat_suspended then
        ns._pendingToggleMover = show and true or false
        return
    end

    if show then
        if not ns._mover then
            -- Create the mover frame if it doesn't exist
            local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            ns._mover = mover
            mover:SetFrameStrata("DIALOG")
            mover:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1
            })
            mover:SetBackdropColor(0,0.25,0.60,0.08)
            mover:SetBackdropBorderColor(0.2,0.65,1,1)
            mover:EnableMouse(true)
            mover:SetClampedToScreen(true)
            mover:SetPoint("CENTER", parent, "CENTER", 0, 0)

            -- Dragging logic
            mover:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                    self.isDragging = true
                    self.startCursorX, self.startCursorY = GetCursorPosition()
                    local scale = UIParent:GetEffectiveScale()
                    self.startCursorX, self.startCursorY = self.startCursorX/scale, self.startCursorY/scale
                    self.startParentX, self.startParentY = parent:GetCenter()
                    self:SetScript("OnUpdate", function()
                        if self.isDragging then
                            local cx, cy = GetCursorPosition()
                            local scale = UIParent:GetEffectiveScale()
                            cx, cy = cx/scale, cy/scale
                            local dx, dy = cx - self.startCursorX, cy - self.startCursorY
                            local newX, newY = self.startParentX + dx, self.startParentY + dy
                            local pos = GetPos()
                            pos.x, pos.y = math.floor(newX - UIParent:GetWidth()/2 + 0.5),
                                           math.floor(newY - UIParent:GetHeight()/2 + 0.5)
                            ApplyPosition()
                        end
                    end)
                end
            end)

            mover:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" and self.isDragging then
                    self.isDragging = false
                    self:SetScript("OnUpdate", nil)
                end
            end)

            local panelFont = (ns.Options and ns.Options.ResolvePanelFont and ns.Options.ResolvePanelFont())
                              or "Fonts\\FRIZQT__.TTF"

            local function layoutTextWidth(b)
                if not b or not b.GetFontString then return end
                local fs = b:GetFontString()
                if not fs then return end
                local w = fs:GetStringWidth() or 0
                if w < 1 then
                    local txt = fs:GetText() or ""
                    w = (txt ~= "" and (#txt * 7)) or 32
                end
                b:SetWidth(w + 12)
                b:SetHeight(20)
            end

            -- Helper to create text buttons on the mover frame
            local function makeTextButton(prev, label, onClick)
                local b = CreateFrame("Button", nil, mover, "BackdropTemplate")
                b:SetHeight(20)
                if prev then
                    b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
                else
                    b:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 6, 6)
                end
                b:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1
                })
                b:SetBackdropColor(0.12,0.18,0.28,0.9)
                b:SetBackdropBorderColor(0.20,0.32,0.50,1)
                local fs = b:CreateFontString(nil, "ARTWORK")
                fs:SetFont(panelFont, 12, "")
                fs:SetPoint("CENTER")
                fs:SetText(label)
                b:SetFontString(fs)

                layoutTextWidth(b)
                C_Timer.After(0, function()
                    if b:IsShown() then layoutTextWidth(b) end
                end)

                b:SetScript("OnClick", onClick)
                return b
            end

            local lockBtn = makeTextButton(nil, "Lock", function()
                ns._force_min_icons = nil
                SafeRenderAll()
                ns.ToggleMover(false)
            end)

            local centerHBtn = makeTextButton(lockBtn, "Center Horizontal", function()
                local pos = GetPos()
                TeleportMover(0, pos.y or 0)
            end)

            local centerVBtn = makeTextButton(centerHBtn, "Center Vertical", function()
                local pos = GetPos()
                TeleportMover(pos.x or 0, 0)
            end)

            -- Helper to create arrow buttons for nudging
            local function makeArrow(prev, dx, dy, angle)
                local b = CreateFrame("Button", nil, mover)
                b:SetSize(20, 20)
                b:SetPoint("LEFT", prev, "RIGHT", 6, 0)

                local tex = b:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints()
                tex:SetAtlas("uitools-icon-chevron-down")
                tex:SetRotation(math.rad(angle))
                b.tex = tex

                b:SetScript("OnEnter", function() tex:SetVertexColor(1,1,0) end)
                b:SetScript("OnLeave", function() tex:SetVertexColor(1,1,1) end)
                b:SetScript("OnClick", function() ns.NudgeMover(dx, dy) end)

                return b
            end

            local leftBtn  = makeArrow(centerVBtn, -1,  0, -90)
            local upBtn    = makeArrow(leftBtn,    0,  1, 180)
            local downBtn  = makeArrow(upBtn,      0, -1,   0)
            local rightBtn = makeArrow(downBtn,    1,  0,  90)

            local resetBtn = CreateFrame("Button", nil, mover)
            resetBtn:SetSize(18, 18)
            resetBtn:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", -6, 6)
            local rtex = resetBtn:CreateTexture(nil, "ARTWORK")
            rtex:SetAllPoints(resetBtn)
            rtex:SetAtlas("common-icon-undo", true)
            resetBtn:SetScript("OnClick", function()
                local KEY = "CRB_MOVER_RESET_CONFIRM"
                if not StaticPopupDialogs[KEY] then
                    StaticPopupDialogs[KEY] = {
                        text = "Reset position to default?",
                        button1 = YES,
                        button2 = NO,
                        OnAccept = function() TeleportMover(0, 0) end,
                        timeout = 0, whileDead = 1,
                        hideOnEscape = 1, preferredIndex = 3,
                    }
                end
                StaticPopup_Show(KEY)
            end)

            mover:HookScript("OnShow", function()
                local buttons = { lockBtn, centerHBtn, centerVBtn }
                for i = 1, #buttons do layoutTextWidth(buttons[i]) end
                C_Timer.After(0, function()
                    if mover:IsShown() then
                        for i = 1, #buttons do layoutTextWidth(buttons[i]) end
                    end
                end)
            end)
        end

        ns._force_min_icons = 10
        SafeRenderAll()
        UpdateMoverSize()
        ns._mover:Show()
    else
        ns._force_min_icons = nil
        SafeRenderAll()
        if ns._mover then ns._mover:Hide() end
    end

    if ns.InfoTab_UpdateUnlockCheckbox then
        ns.InfoTab_UpdateUnlockCheckbox(show)
    end
end

parent:HookScript("OnSizeChanged", function() ns.UpdateMoverSize() end)

-- Debugging tools
function CRB_AddDBToDevTool()
    if not DevTool then
        print("|cffff0000DevTool not loaded.|r")
        return
    end
    if not ClickableRaidBuffsDB then
        print("|cffff0000ClickableRaidBuffsDB not ready yet.|r")
        return
    end
    DevTool:AddData(ClickableRaidBuffsDB, "ClickableRaidBuffsDB")
    print("|cff00ccffCRB:|r DB added to DevTool.")
end

function CRB_DebugPos()
    local pos = GetPos()
    print("|cff00ccffCRB:|r Current pos:", pos.x, pos.y)
end

local function ReapplyPosition()
    ApplyPosition()
end

-- Event handler for position updates
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if ns._pendingToggleMover ~= nil then
            local want = ns._pendingToggleMover
            ns._pendingToggleMover = nil
            ns.ToggleMover(want)
        end
        if ns._pendingPos then
            local p = ns._pendingPos
            ns._pendingPos = nil
            local pos = GetPos()
            pos.x, pos.y = p.x or 0, p.y or 0
            ApplyPosition()
        end
        if ns._pendingRender then
            ns._pendingRender = false
            SafeRenderAll()
        end
        return
    end
    ReapplyPosition()
end)
