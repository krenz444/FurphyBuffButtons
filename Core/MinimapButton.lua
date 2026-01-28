-- ====================================
-- \Core\MinimapButton.lua
-- ====================================
-- This file handles the creation and management of the minimap button using LibDataBroker and LibDBIcon.

local addonName, ns = ...

local ClickableRaidBuffs = LibStub("AceAddon-3.0"):NewAddon("ClickableRaidBuffs", "AceConsole-3.0")

-- Libs
local LDB = LibStub("LibDataBroker-1.1")
local LDI = LibStub("LibDBIcon-1.0", true)
local AceDB = LibStub("AceDB-3.0")

-- Create the data object for the minimap button
local miniButton = LDB:NewDataObject("ClickableRaidBuffs", {
    type = "data source",
    text = "CRB",
    icon = "Interface\\AddOns\\ClickableRaidBuffs\\Media\\furphyMinimapIcon",

    OnClick = function(_, btn)
        if InCombatLockdown() then
            print("|cFF00ccffCRB:|r Minimap menu is disabled during combat.")
            return
        end

        if btn == "LeftButton" then
            if ns and ns.OptionsFrame and ns.OptionsFrame:IsShown() then
                ns.OptionsFrame:Hide()
            elseif ns and ns.OpenOptions then
                ns.OpenOptions()
            elseif SlashCmdList and SlashCmdList["CLICKABLERAIDBUFFS"] then
                SlashCmdList["CLICKABLERAIDBUFFS"]("")
            end

        elseif btn == "RightButton" then
            if ns and ns._mover and ns._mover:IsShown() then
                if ns.ToggleMover then ns.ToggleMover(false) end
            else
                if ns.ToggleMover then ns.ToggleMover(true) end
            end
        end
    end,

    OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine("|cff00ccffClickable Raid Buffs|r")
        tooltip:AddLine(" ")
        tooltip:AddLine("Left-click: Open Settings")
        tooltip:AddLine("Right-click: Toggle Icon Frame Lock")
    end,
})

-- Refreshes the minimap icon state (show/hide) based on settings
function ClickableRaidBuffs:RefreshMinimapIcon()
    if not (LDI and self.minimapDB and self.minimapDB.profile) then return end
    local prof = self.minimapDB.profile
    prof.minimap = prof.minimap or { hide = false, minimapPos = 180 }

    LDI:Register("ClickableRaidBuffs", miniButton, prof.minimap)

    if prof.minimap.hide then
        LDI:Hide("ClickableRaidBuffs")
    else
        LDI:Show("ClickableRaidBuffs")
    end

    if ns and ns.InfoTab_UpdateMinimapCheckbox then
        ns.InfoTab_UpdateMinimapCheckbox(prof.minimap.hide)
    end
end

-- Initializes the minimap button and database
function ClickableRaidBuffs:OnInitialize()
    self.minimapDB = AceDB:New("ClickableRaidBuffsMinimapDB", {
        profile = {
            minimap = {
                hide = false,
                minimapPos = 180,
            },
        },
    }, true)

    if self.minimapDB.keys and self.minimapDB.keys.profile ~= "Default" then
        self.minimapDB:SetProfile("Default")
    end

    local legacy = nil
    local sv = _G.ClickableRaidBuffsDB
    if type(sv) == "table" and type(sv.profile) == "table" and type(sv.profile.minimap) == "table" then
        legacy = sv.profile.minimap
    end
    if legacy then
        local dst = self.minimapDB.profile.minimap
        if dst.hide == nil       and legacy.hide       ~= nil then dst.hide       = legacy.hide       end
        if dst.minimapPos == nil and legacy.minimapPos ~= nil then dst.minimapPos = legacy.minimapPos end
        if dst.lock == nil       and legacy.lock       ~= nil then dst.lock       = legacy.lock       end
    end

    self:RefreshMinimapIcon()

    self.minimapDB.RegisterCallback(self, "OnProfileChanged", "OnMinimapProfileChanged")
    self.minimapDB.RegisterCallback(self, "OnProfileCopied",  "OnMinimapProfileChanged")
    self.minimapDB.RegisterCallback(self, "OnProfileReset",   "OnMinimapProfileChanged")
end

function ClickableRaidBuffs:OnMinimapProfileChanged()
    self:RefreshMinimapIcon()
end

-- Toggles the visibility of the minimap button
function ClickableRaidBuffs:ToggleMinimapButton(state)
    if not (LDI and self.minimapDB and self.minimapDB.profile) then return end

    local prof = self.minimapDB.profile
    if state == nil then
        state = not (prof.minimap and prof.minimap.hide)
    end

    prof.minimap = prof.minimap or {}
    prof.minimap.hide = state and true or false

    if prof.minimap.hide then
        LDI:Hide("ClickableRaidBuffs")
    else
        LDI:Show("ClickableRaidBuffs")
    end

    if ns and ns.InfoTab_UpdateMinimapCheckbox then
        ns.InfoTab_UpdateMinimapCheckbox(prof.minimap.hide)
    end
end

-- Public API to toggle the minimap button
function ns.ToggleMinimapButton(state)
    if ClickableRaidBuffs and ClickableRaidBuffs.ToggleMinimapButton then
        ClickableRaidBuffs:ToggleMinimapButton(state)
    end
end
function ns.Minimap_Show()
    if ClickableRaidBuffs then ClickableRaidBuffs:ToggleMinimapButton(false) end
end
function ns.Minimap_Hide()
    if ClickableRaidBuffs then ClickableRaidBuffs:ToggleMinimapButton(true) end
end
function ns.Minimap_Toggle()
    if not (ClickableRaidBuffs and ClickableRaidBuffs.minimapDB and ClickableRaidBuffs.minimapDB.profile) then return end
    local hide = (ClickableRaidBuffs.minimapDB.profile.minimap and ClickableRaidBuffs.minimapDB.profile.minimap.hide) and true or false
    ClickableRaidBuffs:ToggleMinimapButton(not hide)
end
