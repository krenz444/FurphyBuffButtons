-- ====================================
-- \Modules\Flask.lua
-- ====================================
-- This module handles the tracking and display of Flasks and Phials.

local addonName, ns = ...

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.playerInfo  = clickableRaidBuffCache.playerInfo  or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

local FALLBACK = { 432473, 432021, 431974, 431973, 431972, 431971 }
local FLASK_IDS, FLEETING_BY_BUFFID

-- Builds the set of flask IDs to track.
local function BuildSetsOnce()
  if FLASK_IDS then return end
  FLASK_IDS, FLEETING_BY_BUFFID = {}, {}
  local seen = {}
  local tbl = _G.ClickableRaidData and _G.ClickableRaidData["FLASK"]

  if type(tbl) == "table" then
    for _, row in pairs(tbl) do
      if type(row) == "table" and type(row.buffID) == "table" then
        for _, sid in ipairs(row.buffID) do
          if type(sid) == "number" and not seen[sid] then
            seen[sid] = true
            table.insert(FLASK_IDS, sid)
          end
          if row.fleeting and type(sid) == "number" then
            FLEETING_BY_BUFFID[sid] = true
          end
        end
      end
    end
  end

  if #FLASK_IDS == 0 then
    for _, sid in ipairs(FALLBACK) do table.insert(FLASK_IDS, sid) end
  end
end

-- Checks if the player has an active flask and returns its expiration time.
-- Skipped during combat.
local function GetFlaskExpire()
  if InCombatLockdown() then return nil end
  BuildSetsOnce()
  if not FLASK_IDS or #FLASK_IDS == 0 then return nil end
  return ns.GetPlayerBuffExpire(FLASK_IDS, false, false)
end

-- Checks if the active flask is a "fleeting" type (e.g., Alchemical Flavor Pocket).
-- Skipped during combat.
local function IsActiveFlaskFleeting()
  if InCombatLockdown() then return false end
  BuildSetsOnce()
  local i = 1
  while true do
    local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not a then break end
    if FLEETING_BY_BUFFID[a.spellId] then return true end
    i = i + 1
  end
  return false
end

-- Updates the cached flask state and triggers a refresh if needed.
-- Skipped during combat.
local function UpdateFlaskState()
  if InCombatLockdown() then return end
  local pi = clickableRaidBuffCache.playerInfo
  local newExpire = GetFlaskExpire()
  if pi.flaskExpireTime ~= newExpire then
    pi.flaskExpireTime = newExpire
    if type(_G.scanAllBags) == "function" then _G.scanAllBags() end
    if ns.RenderAll then ns.RenderAll() end
  end

  if ns.StartRefreshTicker then ns.StartRefreshTicker() end
  if ns.StartTimerUpdater then ns.StartTimerUpdater() end
end

-- Filters out non-fleeting flasks if a fleeting flask is active.
-- Skipped during combat.
local function ApplyFleetingGate()
  if InCombatLockdown() then return end
  local disp = clickableRaidBuffCache.displayable
  local cat = disp and disp.FLASK
  if type(cat) ~= "table" then return end

  local hasFleeting = false
  for _, e in pairs(cat) do if e and e.fleeting then hasFleeting = true; break end end
  if not hasFleeting then return end

  for k, e in pairs(cat) do
    if e and not e.fleeting then cat[k] = nil end
  end
end

-- Hooks RenderAll to apply fleeting flask logic.
do
  local wrapped
  local function EnsureHook()
    if wrapped then return end
    if type(ns.RenderAll) == "function" then
      local orig = ns.RenderAll
      ns.RenderAll = function(...)
        ApplyFleetingGate()
        return orig(...)
      end
      wrapped = true
    end
  end
  EnsureHook()
  C_Timer.After(0.05, EnsureHook)
  C_Timer.After(0.5,  EnsureHook)
end

-- Public API to update flask state.
function ns.UpdateFlaskState()
  if type(UpdateFlaskState) == "function" then
    UpdateFlaskState()
  end
end

-- Event handler for UNIT_AURA.
function ns.Flask_OnUnitAura(unit, updateInfo)
  if unit ~= "player" then return end
  if type(UpdateFlaskState) == "function" then
    UpdateFlaskState()
  end
end
