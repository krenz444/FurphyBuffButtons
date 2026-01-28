-- ====================================
-- \Core\EncourageReset.lua
-- ====================================
-- This file handles prompting the user to reset settings when upgrading to a version that requires it.

local addonName, ns = ...

local function DB()
  return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {}
end

-- The version ID that triggers a reset prompt
local PUSH_RESET_ID = "6.2.0"
local POPUP_KEY = "CRB_RESET_REQUIRED"

-- Define the popup dialog
StaticPopupDialogs[POPUP_KEY] = {
  text = "Upgrading to this version of Clickable Raid Buffs requires that the settings be reset to default. Some elements may work incorrectly if you do not reset settings. Reset them now?",
  button1 = YES,
  button2 = NO,
  OnAccept = function()
    -- Clear saved variables
    _G.ClickableRaidBuffsDB = nil
    _G.ClickableRaidBuffsCharDB = nil
    -- Reset frame position
    local f = ns and ns.RenderParent
    if f and f.ClearUserPlaced then
      f:ClearUserPlaced()
    elseif f and f.SetUserPlaced then
      f:SetUserPlaced(false)
    end
    -- Reload UI
    if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

-- Retrieves the addon version from the TOC file
local function getTOCVersion()
  local v = (C_AddOns and C_AddOns.GetAddOnMetadata) and C_AddOns.GetAddOnMetadata(addonName, "Version") or nil
  if type(v) ~= "string" or v == "" then return nil end
  return v
end

-- Compares two version strings
local function cmpVer(a, b)
  if a == b then return 0 end
  if not a or a == "" then return -1 end
  if not b or b == "" then return 1 end
  local ai, bi = 1, 1
  while true do
    local as, ae = string.find(a, "(%d+)", ai)
    local bs, be = string.find(b, "(%d+)", bi)
    if not as and not bs then return 0 end
    if not as then return -1 end
    if not bs then return 1 end
    local av = tonumber(string.sub(a, as, ae)) or 0
    local bv = tonumber(string.sub(b, bs, be)) or 0
    if av ~= bv then return (av < bv) and -1 or 1 end
    ai = ae + 1
    bi = be + 1
  end
end

-- Check if a reset is needed on addon load
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, name)
  if event ~= "ADDON_LOADED" or name ~= addonName then return end

  local d = DB()
  local currentVersion = getTOCVersion() or "0"
  local prev = d.versionID
  local initial = (prev == nil)

  local cmpPrevPush = cmpVer(prev or "0", PUSH_RESET_ID)
  local cmpCurrPush = cmpVer(currentVersion, PUSH_RESET_ID)

  -- Show popup if upgrading from a version older than PUSH_RESET_ID
  if not initial and (cmpPrevPush < 0) and (cmpCurrPush >= 0) then
    StaticPopup_Show(POPUP_KEY)
  end

  d.versionID   = currentVersion
  d.pushResetID = PUSH_RESET_ID
end)
