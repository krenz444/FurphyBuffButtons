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
local EATING_IDS = {}
local WELLFED_IDS = {}

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
  wipe(EATING_IDS)
  wipe(WELLFED_IDS)

  local srcE = FurphyBuffData and FurphyBuffData["EATING"]
  if type(srcE) == "table" then
    for _, id in pairs(srcE) do
      EATING_IDS[id] = true
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
      WELLFED_IDS[id] = true
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

-- Checks if an aura matches eating buffs by name or spellId.
local function IsEatingAura(aura)
  local nameSecret = issecretvalue and aura.name and issecretvalue(aura.name)
  local idSecret   = issecretvalue and aura.spellId and issecretvalue(aura.spellId)
  if not nameSecret and aura.name and EATING_NAMES[aura.name] then return true end
  if not idSecret and aura.spellId and EATING_IDS[aura.spellId] then return true end
  return false
end

-- Checks if an aura matches well-fed buffs by name or spellId.
local function IsWellFedAura(aura)
  local nameSecret = issecretvalue and aura.name and issecretvalue(aura.name)
  local idSecret   = issecretvalue and aura.spellId and issecretvalue(aura.spellId)
  if not nameSecret and aura.name and WELLFED_NAMES[aura.name] then return true end
  if not idSecret and aura.spellId and WELLFED_IDS[aura.spellId] then return true end
  return false
end

-- Scans the player's auras to check if they are currently eating.
local function ScanPlayerEatingAura()
  local now = GetTime()
  for i=1, 40 do
    local aura = AuraByIndex and AuraByIndex("player", i, "HELPFUL")
    if not aura then break end
    if IsEatingAura(aura) then
      local exp = aura.expirationTime
      local dur = aura.duration
      -- Handle secret duration/expiration in M+
      local expSecret = issecretvalue and exp and issecretvalue(exp)
      local durSecret = issecretvalue and dur and issecretvalue(dur)
      if expSecret or durSecret then
        return true, aura, 0, 0, now, aura.auraInstanceID
      end
      exp = exp or 0
      dur = dur or 0
      if dur <= 0 and exp > 0 then
        dur = math.max(0, exp - now)
      end
      local start = (exp > 0 and dur > 0) and (exp - dur) or now
      return true, aura, exp, dur, start, aura.auraInstanceID
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
    if IsWellFedAura(aura) then
      local exp = aura.expirationTime
      -- If expiration is secret (M+/encounters), assume well fed is active
      if issecretvalue and exp and issecretvalue(exp) then
        return true
      end
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
      if a and (IsEatingAura(a) or IsWellFedAura(a)) then
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
      if a and (IsEatingAura(a) or IsWellFedAura(a)) then
        changed = true
        break
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
