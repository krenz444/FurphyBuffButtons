-- ====================================
-- \Options\Controls.lua
-- ====================================
-- This file handles slash commands and general control functions for the addon.

local addonName, ns = ...
local O = ns.Options

local function DB()
  return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {}
end

-- Syncs option UI elements with current database values.
function ns.SyncOptions()
  local db = DB()
  local sSpell = _G["CRB_Threshold_spellThreshold"]; if sSpell then sSpell:SetValue(db.spellThreshold or O.DEFAULTS.spellThreshold or 15) end
  local sItem  = _G["CRB_Threshold_itemThreshold"];  if sItem  then sItem:SetValue(db.itemThreshold  or O.DEFAULTS.itemThreshold  or 15) end
  local sDura  = _G["CRB_Threshold_durabilityThreshold"]; if sDura then sDura:SetValue(db.durabilityThreshold or O.DEFAULTS.durabilityThreshold or 25) end
  local sIcon  = _G["CRB_IconSize_Slider"]; if sIcon then sIcon:SetValue(db.iconSize or (ns.BASE_ICON_SIZE or 50)) end
  if ns.Options and ns.Options.SyncGlowColor    then ns.Options.SyncGlowColor()    end
  if ns.Options and ns.Options.SyncFontControls then ns.Options.SyncFontControls() end
end

-- Safely closes the options panel.
local function SafeCloseOptions()
  if ns.OptionsFrame and ns.OptionsFrame:IsShown() then
    SettingsPanel:Hide()
  end
end

local reopenAfterCombat = false
-- Requests to unlock the mover frame.
-- Handles combat restrictions by deferring the action.
function ns.RequestUnlock()
  if InCombatLockdown() then
    print("|cFF00ccffCRB:|r Cannot unlock during combat. Will unlock after combat ends.")
    reopenAfterCombat = true
    if ns.ToggleMover then ns.ToggleMover(false) end
    SafeCloseOptions()
  else
    if ns.ToggleMover then ns.ToggleMover(true) end
  end
end

-- Popup dialog for resetting settings.
StaticPopupDialogs["CRB_RESET_CONFIRM"] = {
  text = "Are you sure you want to reset Clickable Raid Buffs to default? This action cannot be undone.",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    _G.ClickableRaidBuffsDB = nil
    _G.ClickableRaidBuffsCharDB = nil
    local f = ns.RenderParent
    if f and f.ClearUserPlaced then
      f:ClearUserPlaced()
    elseif f and f.SetUserPlaced then
      f:SetUserPlaced(false)
    end
    if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- Triggers the reset confirmation popup.
function ns.ResetToDefaults()
  StaticPopup_Show("CRB_RESET_CONFIRM")
end

-- Handles combat events to manage frame locking/unlocking.
local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
combatFrame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" then
    if reopenAfterCombat then
      reopenAfterCombat = false
      C_Timer.After(0.1, function()
        if ns.ToggleMover then ns.ToggleMover(true) end
      end)
    end
  else
    if ns.ToggleMover then ns.ToggleMover(false) end
    SafeCloseOptions()
  end
end)

-- Slash commands registration.
SLASH_CLICKABLERAIDBUFFS1 = "/crb"
SLASH_CLICKABLERAIDBUFFS2 = "/buff"
SLASH_CLICKABLERAIDBUFFS3 = "/furphy"

SlashCmdList["CLICKABLERAIDBUFFS"] = function(msg)
  msg = (msg and msg:lower() or ""):match("^%s*(.-)%s*$")

  if msg == "unlock" or msg == "move" or msg == "lock" then
    if InCombatLockdown() then
      print("|cFF00ccffCRB:|r Cannot unlock during combat. Will unlock after combat ends.")
      reopenAfterCombat = true
      if ns.ToggleMover then ns.ToggleMover(false) end
      SafeCloseOptions()
    else
      local showing = ns._mover and ns._mover:IsShown()
      local newState = not showing
      if ns.ToggleMover then ns.ToggleMover(newState) end
      if newState then
        print("|cFF00ccffCRB:|r Frame unlocked. Drag to reposition, then /crb lock.")
      else
        print("|cFF00ccffCRB:|r Frame locked.")
      end
    end

  elseif msg == "minimap" then
    local addon = LibStub("AceAddon-3.0"):GetAddon("ClickableRaidBuffs", true)
    if addon and addon.ToggleMinimapButton then
      local hidden = addon.db and addon.db.profile and addon.db.profile.minimap and addon.db.profile.minimap.hide
      local newState = not hidden
      addon:ToggleMinimapButton(newState)
      if newState then
        print("|cFF00ccffCRB:|r Minimap button hidden. Type /crb minimap to show again.")
      else
        print("|cFF00ccffCRB:|r Minimap button shown. Type /crb minimap to hide again.")
      end
    end

  elseif msg == "reset" then
    ns.ResetToDefaults()

  elseif msg == "" then
    if ns.OpenOptions then
      if ns.OptionsFrame and ns.OptionsFrame:IsShown() then
        ns.OptionsFrame:Hide()
      else
        ns.OpenOptions()
      end
    end

  else
    print("|cFF00ccffCRB:|r Commands:")
    print("  /crb unlock    - Toggle lock/unlock the icon frame")
    print("  /crb lock      - Toggle lock/unlock the icon frame")
    print("  /crb minimap   - Toggle showing the minimap button")
    print("  /crb reset     - Reset settings to default and reload UI")
    print("  /crb           - Open/close the options panel")
  end
end
