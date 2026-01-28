-- ====================================
-- \Core\RosterWatch.lua
-- ====================================
-- This file monitors roster changes and triggers updates when the group composition changes.

local addonName, ns = ...

local pending = false

-- Performs the refresh logic.
-- Skipped during combat.
local function DoRefresh()
    pending = false
    if InCombatLockdown() then return end
    if ns.RebuildRaidBuffWatch then ns.RebuildRaidBuffWatch() end
    if scanRaidBuffs then scanRaidBuffs() end
    if ns.RenderAll then ns.RenderAll() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        ns._inCombat = true
        pending = false
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns._inCombat = false
        DoRefresh()
        return
    end

    if InCombatLockdown() then return end

    if not pending then
        pending = true
        C_Timer.After(0.05, DoRefresh)
    end
end)
