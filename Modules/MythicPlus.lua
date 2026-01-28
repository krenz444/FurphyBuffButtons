-- ====================================
-- \Modules\MythicPlus.lua
-- ====================================
-- This module handles Mythic+ specific settings, such as different thresholds and disabling consumables.

local addonName, ns = ...
local function DB()
  return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
end

-- Checks if the current keystone is a test keystone.
local function IsTestKeystone()
  local ok, val = pcall(function()
    if type(mPlusDifficultyID) == "function" then return mPlusDifficultyID() end
  end)
  return ok and val == 205
end

local DIFF_MYTHIC   = 23
local DIFF_KEYSTONE = 8

-- Checks if the player is in a real instance and returns difficulty info.
-- Skipped during combat.
local function InInstanceReal()
  if InCombatLockdown() then return false, 0, nil, 0, 0 end
  local inInst = select(1, IsInInstance())
  if not inInst then return false end
  local name, _, difficultyID, _, _, _, _, instanceMapID, lfgDungeonID = GetInstanceInfo()
  return true, difficultyID, name, instanceMapID, lfgDungeonID
end

local seasonByDungeonMapID = nil
-- Builds a lookup table for current season dungeon map IDs.
local function buildSeasonMapIDLookup()
  local byMapID = {}
  local maps = C_ChallengeMode and C_ChallengeMode.GetMapTable and C_ChallengeMode.GetMapTable()
  if type(maps) == "table" then
    for i = 1, #maps do
      local challengeID = maps[i]
      if challengeID then
        local name, _, _, _, _, dungeonMapID = C_ChallengeMode.GetMapUIInfo(challengeID)
        if dungeonMapID and name and name ~= "" then
          byMapID[dungeonMapID] = true
        end
      end
    end
  end
  seasonByDungeonMapID = byMapID
end

-- Checks if a map ID corresponds to a current season dungeon.
local function isCurrentSeasonDungeonByMapID(mapID)
  if not mapID then return false end
  if not seasonByDungeonMapID then buildSeasonMapIDLookup() end
  return seasonByDungeonMapID and seasonByDungeonMapID[mapID] == true
end

ns._mp_overridden          = ns._mp_overridden or false
ns._mp_setThresholdsHooked = ns._mp_setThresholdsHooked or false
ns._mp_origSetThresholds   = ns._mp_origSetThresholds
ns._mp_baseThresholds      = ns._mp_baseThresholds or nil

-- Helper to shallow copy a table.
local function shallowCopy(tbl)
  if not tbl then return nil end
  local out = {}
  for k, v in pairs(tbl) do out[k] = v end
  return out
end

-- Hooks SetThresholds to apply Mythic+ overrides.
local function EnsureHookSetThresholds()
  if ns._mp_setThresholdsHooked then return end
  if type(ns.SetThresholds) ~= "function" then return end

  ns._mp_origSetThresholds = ns.SetThresholds
  ns.SetThresholds = function(incoming)
    ns._mp_baseThresholds = shallowCopy(incoming)
    local eff = shallowCopy(incoming)
    if ns._mp_overridden then
      local m = tonumber(DB().mplusThreshold) or 45
      if eff.spell ~= nil then eff.spell = m end
      if eff.item  ~= nil then eff.item  = m end
    end
    return ns._mp_origSetThresholds(eff)
  end

  ns._mp_setThresholdsHooked = true
end

-- Recomputes thresholds immediately.
function ns.MythicPlus_RecomputeThresholdsNow()
  EnsureHookSetThresholds()
  local base = ns._mp_baseThresholds
  if not (base and ns._mp_origSetThresholds) then return end

  local eff = shallowCopy(base)
  if ns._mp_overridden then
    local m = tonumber(DB().mplusThreshold) or 45
    if eff.spell ~= nil then eff.spell = m end
    if eff.item  ~= nil then eff.item  = m end
  end
  ns._mp_origSetThresholds(eff)
end

ns._mp_disable  = ns._mp_disable or false
ns._mp_lastKey  = ns._mp_lastKey or ""

-- Checks if Mythic+ disable mode is active.
function mythicPlusDisableMode()
  return ns and ns._mp_disable == true
end

-- Recomputes the Mythic+ state (overrides and disable mode).
-- Skipped during combat.
local function recomputeState()
  if InCombatLockdown() then return end
  EnsureHookSetThresholds()

  local d = DB()
  local inInst, difficultyID, _, instanceMapID = InInstanceReal()
  local seasonal = inInst and isCurrentSeasonDungeonByMapID(instanceMapID) or false

  local enableOverride = (d.mplusThresholdEnabled ~= false)

  local wantOverride = (inInst and difficultyID == DIFF_MYTHIC and seasonal and enableOverride) or false
  if wantOverride ~= ns._mp_overridden then
    ns._mp_overridden = wantOverride
    ns.MythicPlus_RecomputeThresholdsNow()
  end

  local disableNow = (inInst and (difficultyID == DIFF_KEYSTONE or IsTestKeystone()) and seasonal and d.mplusDisableConsumables == true) or false
  ns._mp_disable = disableNow

  local key = (ns._mp_overridden and 1 or 0) .. ":" .. (disableNow and 1 or 0)
  if key ~= ns._mp_lastKey then
    ns._mp_lastKey = key
    if ns.RequestRebuild then ns.RequestRebuild() end
    if ns.RenderAll    then ns.RenderAll()    end
  end
end

-- Public API to recompute Mythic+ state.
function ns.MythicPlus_Recompute()
  recomputeState()
end

-- Checks if we are in a context where Mythic+ overrides apply.
local function IsMPlusOverrideContext()
  local inInst, difficultyID, _, instanceMapID = InInstanceReal()
  if not inInst then return false end
  if not isCurrentSeasonDungeonByMapID(instanceMapID) then return false end
  return difficultyID == DIFF_MYTHIC
end

-- Checks if Mythic+ overrides are enabled in settings.
local function IsMPlusOverrideEnabled()
  local d = DB()
  if d.mplusThresholdEnabled == nil then return true end
  return d.mplusThresholdEnabled and true or false
end

-- Gets the spell threshold seconds, applying overrides if necessary.
function ns.MPlus_GetSpellThresholdSecs(baseMinutes)
  if IsMPlusOverrideContext() and IsMPlusOverrideEnabled() then
    local m = tonumber(DB().mplusThreshold) or 45
    return m * 60
  end
  return (tonumber(baseMinutes) or 15) * 60
end

-- Gets the item threshold seconds, applying overrides if necessary.
function ns.MPlus_GetItemThresholdSecs(baseMinutes)
  if IsMPlusOverrideContext() and IsMPlusOverrideEnabled() then
    local m = tonumber(DB().mplusThreshold) or 45
    return m * 60
  end
  return (tonumber(baseMinutes) or 5) * 60
end

-- Checks if consumables should be disabled due to Mythic+ settings.
function ns.MPlus_DisableConsumablesActive()
  local inInst, difficultyID, _, instanceMapID = InInstanceReal()
  if not inInst then return false end
  if not isCurrentSeasonDungeonByMapID(instanceMapID) then return false end
  if not (difficultyID == DIFF_KEYSTONE or IsTestKeystone()) then return false end
  local d = DB()
  return d.mplusDisableConsumables and true or false
end

-- Gets the effective threshold seconds for a given kind (spell/item/weapon).
function ns.MPlus_GetEffectiveThresholdSecs(kind, baseMinutes)
  local base = tonumber(baseMinutes) or 0
  local inInst, difficultyID, _, instanceMapID = InInstanceReal()
  if not inInst then return base * 60 end
  if isCurrentSeasonDungeonByMapID(instanceMapID) and difficultyID == DIFF_MYTHIC then
    local d = (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
    if d.mplusThresholdEnabled ~= false then
      local m = tonumber(d.mplusThreshold) or 45
      return m * 60
    end
  end
  return base * 60
end

-- Event handler for map updates.
function ns.MythicPlus_OnMapsUpdate()
  if type(buildSeasonMapIDLookup) == "function" then
    buildSeasonMapIDLookup()
  end
  if type(recomputeState) == "function" then
    recomputeState()
  end
end
