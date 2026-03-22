-- ====================================
-- \Modules\FoodStatus.lua
-- ====================================
-- This module tracks the player's eating status and displays an icon if they are eating.
-- It also handles suppressing the eating icon if the player is already "Well Fed".

local addonName, ns = ...

local EATING_ICON = 132805
local AuraByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local AuraByInstance = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
local GetTime = GetTimePreciseSec

local eatingActive = false
local lastInstanceID = nil
local _suppressActive = false

local EATING_NAMES = {}
local WELLFED_NAMES = {}

local function DB()
  return (ns.GetDB and ns.GetDB()) or _G.FurphyBuffButtonsDB or {}
end

-- Calculates the threshold for showing the eating icon based on item duration settings.
local function itemThresholdSeconds()
  local baseMin = (DB().itemThreshold or 5)
  if ns.MPlus_GetEffectiveThresholdSecs then
    return ns.MPlus_GetEffectiveThresholdSecs("item", baseMin)
  end
  return baseMin * 60
end

-- Builds sets of localized names for eating and well-fed buffs.
function BuildNameSets()
  wipe(EATING_NAMES)
  wipe(WELLFED_NAMES)

  local srcE = FurphyBuffData and FurphyBuffData["EATING"]
  if type(srcE) == "table" then
    for _, id in pairs(srcE) do
      local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
      local name = info and info.name
      if name then
        EATING_NAMES[name] = true
      end
    end
  end

  local srcW = FurphyBuffData and FurphyBuffData["WELLFED"]
  if type(srcW) == "table" then
    for _, id in pairs(srcW) do
      local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
      local name = info and info.name
      if name then
        WELLFED_NAMES[name] = true
      end
    end
  end
end

BuildNameSets()

-- Ensures the display entry for eating exists.
local function EnsureEatingEntry()
  furphyBuffCache = furphyBuffCache or {}
  furphyBuffCache.displayable = furphyBuffCache.displayable or {}
  local cat = furphyBuffCache.displayable["EATING"]
  if not cat then
    cat = {}; furphyBuffCache.displayable["EATING"] = cat
  end
  local entry = cat["EATING"]
  if not entry then
    entry = { category="EATING", icon=EATING_ICON, itemID=nil, centerText="", cooldownStart=nil, cooldownDuration=nil }
    cat["EATING"] = entry
  end
  return entry
end

-- Clears the eating display entry.
local function ClearEatingEntry()
  if not furphyBuffCache or not furphyBuffCache.displayable then return end
  local cat = furphyBuffCache.displayable["EATING"]
  if cat then cat["EATING"] = nil end
end

-- Scans the player's auras to check if they are currently eating.
local function ScanPlayerEatingAura()
  local now = GetTime()
  for i=1, 40 do
    local aura = AuraByIndex and AuraByIndex("player", i, "HELPFUL")
    if not aura then break end
    if issecretvalue and (issecretvalue(aura.name) or issecretvalue(aura.spellId)) then
      -- skip secret auras
    elseif aura.name and EATING_NAMES[aura.name] then
      local exp = aura.expirationTime or 0
      local dur = aura.duration or 0
      if (not dur or dur <= 0) and exp and exp > 0 then
        dur = math.max(0, exp - now)
      end
      local start = (exp and dur and exp > 0 and dur > 0) and (exp - dur) or now
      return true, aura, exp or 0, dur or 0, start, aura.auraInstanceID
    end
  end
  return false
end

-- Checks if the player has a "Well Fed" buff with sufficient duration remaining.
local function HasWellFedOverThreshold(thresh)
  local now = GetTime()
  for i=1, 40 do
    local aura = AuraByIndex and AuraByIndex("player", i, "HELPFUL")
    if not aura then break end
    if issecretvalue and (issecretvalue(aura.name) or issecretvalue(aura.spellId)) then
      -- skip secret auras
    elseif aura.name and WELLFED_NAMES[aura.name] then
      local exp = aura.expirationTime
      if exp and exp > now and (exp - now) > thresh then
        return true
      end
    end
  end
  return false
end

-- Recomputes the eating state and updates the display.
-- Skipped during combat.
function ns.RecomputeEatingState()
  if InCombatLockdown() then return end
  local found, aura, exp, dur, start, instID = ScanPlayerEatingAura()
  local suppress = false
  if found then
    suppress = HasWellFedOverThreshold(itemThresholdSeconds())
  end
  _suppressActive = suppress

  if found and not suppress then
    eatingActive = true
    lastInstanceID = instID
    local e = EnsureEatingEntry()
    e.cooldownStart    = start
    e.cooldownDuration = dur
    e.centerText       = ""
    if ns.PushRender then ns.PushRender() else if ns.RenderAll then ns.RenderAll() end end
    if ns.Timer_RecomputeSchedule then ns.Timer_RecomputeSchedule() end
  else
    if eatingActive then
      eatingActive = false
      lastInstanceID = nil
      ClearEatingEntry()
      if ns.PushRender then ns.PushRender() else if ns.RenderAll then ns.RenderAll() end end
      if ns.Timer_RecomputeSchedule then ns.Timer_RecomputeSchedule() end
    end
  end
end

-- Handles UNIT_AURA events to update eating status.
-- Skipped during combat.
local function OnUnitAura(unit, updateInfo)
  if InCombatLockdown() then return end
  if unit ~= "player" then return end

  if not updateInfo or updateInfo.isFullUpdate then
    ns.RecomputeEatingState()
    return
  end

  local changed = false

  if updateInfo.addedAuras then
    for i = 1, #updateInfo.addedAuras do
      local a = updateInfo.addedAuras[i]
      local n = a and a.name
      -- Secret values cannot be used as table keys; fall back to full rescan
      if n and issecretvalue and issecretvalue(n) then
        changed = true
        break
      end
      if n and (EATING_NAMES[n] or WELLFED_NAMES[n]) then
        changed = true
        break
      end
    end
  end

  if not changed and updateInfo.updatedAuraInstanceIDs and AuraByInstance then
    for i = 1, #updateInfo.updatedAuraInstanceIDs do
      local id = updateInfo.updatedAuraInstanceIDs[i]
      if id == lastInstanceID then
        changed = true
        break
      end
      local a = AuraByInstance("player", id)
      if a then
        local n = a.name
        if n and issecretvalue and issecretvalue(n) then
          changed = true
          break
        end
        if n and (EATING_NAMES[n] or WELLFED_NAMES[n]) then
          changed = true
          break
        end
      end
    end
  end

  if not changed and updateInfo.removedAuraInstanceIDs then
    for i = 1, #updateInfo.removedAuraInstanceIDs do
      local id = updateInfo.removedAuraInstanceIDs[i]
      if id == lastInstanceID or _suppressActive then
        changed = true
        break
      end
    end
  end

  if changed then
    ns.RecomputeEatingState()
  end
end

-- Public handler for UNIT_AURA events.
function ns.FoodStatus_OnUnitAura(unit, updateInfo)
  OnUnitAura(unit, updateInfo)
  if ns.Timer_RecomputeSchedule then ns.Timer_RecomputeSchedule() end
end
