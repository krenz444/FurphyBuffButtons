-- ====================================
-- \Modules\AugmentRune.lua
-- ====================================
-- This module handles the tracking and display of Augment Runes.

local addonName, ns = ...
ns = ns or {}

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

local GetItemCount = GetItemCount
local GetTime = GetTime
local AuraByIndex = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local AuraByInstance = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID

local function DB()
  return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
end

-- Calculates the threshold for showing the rune icon based on item duration settings.
local function itemThresholdSeconds()
  local db = DB()
  local baseMin = db.itemThreshold or 5
  if ns.MPlus_GetEffectiveThresholdSecs then
    return ns.MPlus_GetEffectiveThresholdSecs("item", baseMin)
  end
  return baseMin * 60
end

-- Retrieves Augment Rune data from the global data table.
local function RuneData()
  return (ClickableRaidData and ClickableRaidData["AUGMENT_RUNE"]) or {}
end

-- Checks if the rune passes gating requirements (instance, rested, group).
local function passesGates(gates)
  if not gates or #gates == 0 then return true end
  for i = 1, #gates do
    local g = gates[i]
    if g == "instance" then
      if not IsInInstance() then return false end
    elseif g == "rested" then
      if IsResting() then return false end
    elseif g == "group" then
      if ns.PassesGroupGate and not ns.PassesGroupGate() then return false end
      if not (IsInGroup() or IsInRaid()) then return false end
    end
  end
  return true
end

-- Gets the count of a specific item in the player's bags.
local function getCount(itemID)
  return GetItemCount(itemID, false) or 0
end

-- Checks if the player has any of the specified buffs and returns the expiration time.
local function GetExpireForIDs(ids)
  if ns.GetPlayerBuffExpire then
    return ns.GetPlayerBuffExpire(ids, false, false)
  end
  local best
  local i = 1
  while true do
    local a = AuraByIndex and AuraByIndex("player", i, "HELPFUL")
    if not a then break end
    if a.spellId and ids then
      for j = 1, #ids do
        if a.spellId == ids[j] then
          local ex = a.expirationTime
          if ex and ex > 0 and (not best or ex > best) then
            best = ex
          end
        end
      end
    end
    i = i + 1
  end
  return best
end

local _buffSet, _buffUnion
-- Initializes lookup tables for rune buffs.
local function ensureRuneBuffLookups()
  if _buffSet then return end
  local runes = RuneData()
  local set, list = {}, {}
  for _, data in pairs(runes) do
    local ids = data and data.buffID
    if ids then
      for i = 1, #ids do
        local id = ids[i]
        if id and not set[id] then
          set[id] = true
          list[#list+1] = id
        end
      end
    end
  end
  _buffSet = set
  _buffUnion = list
end

-- Rebuilds the Augment Rune display list.
-- Skipped during combat.
local function rebuildAugmentRune()
  if InCombatLockdown() then return end

  if mythicPlusDisableMode and mythicPlusDisableMode() then
    clickableRaidBuffCache.displayable.AUGMENT_RUNE = {}
    if ns.RenderAll then ns.RenderAll() end
    return
  end

  ensureRuneBuffLookups()

  local disp = clickableRaidBuffCache.displayable
  disp.AUGMENT_RUNE = {}

  local runes   = RuneData()
  local now     = GetTime()
  local threshS = itemThresholdSeconds()

  for itemID, data in pairs(runes) do
    repeat
      if not data then break end
      if not passesGates(data.gates) then break end
      local qty = getCount(itemID)
      if qty <= 0 then break end

      local expire = GetExpireForIDs(data.buffID)

      local entry  = ns.copyItemData and ns.copyItemData(data) or {}
      entry.category = "AUGMENT_RUNE"
      entry.itemID   = itemID
      entry.qty      = data.qty
      entry.quantity = (data.qty == false) and nil or qty
      if data.qty == false then entry.centerText = "" end

      if expire and expire ~= math.huge then
        local remaining = expire - now
        if remaining > 0 and remaining <= threshS then
          entry.expireTime = expire
          entry.showAt     = nil
          entry._buffTimer = true
          entry._buffUntil = expire
        else
          entry.expireTime = expire
          entry.showAt     = math.max(0, expire - threshS)
          entry._buffTimer = nil
          entry._buffUntil = nil
        end
      else
        entry.expireTime = nil
        entry.showAt     = nil
        entry._buffTimer = nil
        entry._buffUntil = nil
      end

      disp.AUGMENT_RUNE[itemID] = entry
    until true
  end

  if _buffUnion then
    local anyExpire = GetExpireForIDs(_buffUnion)
    ns._runeLastAnyExpire = anyExpire and true or false
  end

  if ns.RenderAll then ns.RenderAll() end
  if ns.Timer_RecomputeSchedule then ns.Timer_RecomputeSchedule() end
end

-- Handles UNIT_AURA events to update rune status.
-- Skipped during combat.
local function AugmentRune_OnPlayerAura(unit, updateInfo)
  if InCombatLockdown() then return end
  if unit ~= "player" then return end
  ensureRuneBuffLookups()

  if not updateInfo or updateInfo.isFullUpdate then
    if ns.UpdateAugmentRunes then ns.UpdateAugmentRunes() end
    return
  end

  local set = _buffSet

  local added = updateInfo.addedAuras
  if added then
    for i = 1, #added do
      local a = added[i]
      local id = a and a.spellId
      if id and set[id] then
        if ns.UpdateAugmentRunes then ns.UpdateAugmentRunes() end
        return
      end
    end
  end

  local updated = updateInfo.updatedAuraInstanceIDs
  if updated and AuraByInstance then
    for i = 1, #updated do
      local info = AuraByInstance("player", updated[i])
      local id = info and info.spellId
      if id and set[id] then
        if ns.UpdateAugmentRunes then ns.UpdateAugmentRunes() end
        return
      end
    end
  end

  local removed = updateInfo.removedAuraInstanceIDs
  if removed then
    local anyExpire = GetExpireForIDs(_buffUnion)
    local hasNow = anyExpire and true or false
    if hasNow ~= ns._runeLastAnyExpire then
      if ns.UpdateAugmentRunes then ns.UpdateAugmentRunes() end
      return
    end
  end
end

ns.UpdateAugmentRunes = rebuildAugmentRune
ns.AugmentRune_OnPlayerAura = AugmentRune_OnPlayerAura
