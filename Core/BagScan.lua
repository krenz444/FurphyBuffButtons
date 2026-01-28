-- ====================================
-- \Core\BagScan.lua
-- ====================================
-- This file handles scanning the player's bags for consumables (food, flasks, weapon enchants)
-- and updating the displayable list based on what is found and current buffs.

local addonName, ns = ...
clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.playerInfo = clickableRaidBuffCache.playerInfo or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}
clickableRaidBuffCache.functions   = clickableRaidBuffCache.functions   or {}

-- Helper to get the database
local function DB() return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {} end

-- Retrieves the list of spell IDs that count as "Well Fed".
local function GetWellFedIDs()
  local wf = ClickableRaidData and ClickableRaidData["WELLFED"]
  if type(wf) == "table" and #wf > 0 then return wf end
  return nil
end

-- Checks if the player has a "Well Fed" buff and returns its expiration time.
local function GetWellFedExpire()
  local wfIDs = GetWellFedIDs()
  if not wfIDs then return nil end
  return ns.GetPlayerBuffExpire and ns.GetPlayerBuffExpire(wfIDs, true, false) or nil
end

-- Checks if a weapon slot has a temporary enchant and returns its expiration time.
local function GetSlotExpire(hand)
  local hasMH, mhMs, _, _, hasOH, ohMs = GetWeaponEnchantInfo()
  local now = GetTime()
  if hand == "mainHand" then
    if hasMH and type(mhMs) == "number" and mhMs > 0 then return now + (mhMs / 1000) end
  else
    if hasOH and type(ohMs) == "number" and ohMs > 0 then return now + (ohMs / 1000) end
  end
  return nil
end

-- Checks if consumables should be suppressed (e.g., in Mythic+).
local function ConsumablesSuppressed()
  if ns.MPlus_DisableConsumablesActive and ns.MPlus_DisableConsumablesActive() then return true end
  local inInst = select(1, IsInInstance())
  if inInst then
    local _, _, diffID = GetInstanceInfo()
    if diffID == 8 then
      local db = DB()
      if db and db.mplusDisableConsumables == true then return true end
    end
  end
  return false
end

-- Object pooling for table reuse to reduce garbage collection.
local pools = { FOOD={}, FLASK={}, MAIN_HAND={}, OFF_HAND={} }

local function Acquire(cat, data)
  local p = pools[cat]
  local entry = p and table.remove(p) or {}
  setmetatable(entry, nil)
  if data then setmetatable(entry, { __index = data }) end
  return entry
end

local function Release(cat, entry)
  if not entry then return end
  entry.quantity, entry.itemID, entry.category = nil, nil, nil
  entry.expireTime, entry.showAt = nil, nil
  entry.cooldownStart, entry.cooldownDuration = nil, nil
  entry.macro = nil
  setmetatable(entry, nil)
  local p = pools[cat]; if p then p[#p+1] = entry end
end

-- Updates cooldown information for an item entry.
local function applyItemCooldownFields(entry, itemID)
  local start, duration, enable = GetItemCooldown(itemID)
  if enable == 1 and duration and duration > 1.5 and start and start > 0 then
    entry.cooldownStart, entry.cooldownDuration = start, duration
  else
    entry.cooldownStart, entry.cooldownDuration = nil, nil
  end
end

-- Calculates the effective threshold for showing an item based on settings.
local function EffectiveItemThresholdSecs()
  local baseMin = DB().itemThreshold or 15
  return (ns.MPlus_GetEffectiveThresholdSecs and ns.MPlus_GetEffectiveThresholdSecs("item", baseMin)) or (baseMin * 60)
end

-- Determines if an item should be shown based on its expiration time and threshold.
local function applyThreshold(entry, expireAbs, thresholdSecs)
  local threshold = thresholdSecs or EffectiveItemThresholdSecs()
  entry.expireTime = expireAbs
  if not expireAbs then entry.showAt = nil; return true end
  if expireAbs == math.huge then entry.showAt = nil; return false end
  local showAt = expireAbs - threshold
  if GetTime() < showAt then entry.showAt = showAt; return false end
  entry.showAt = nil; return true
end

-- Checks if an item passes gating requirements (level, instance, rested).
local function passesGates(data, playerLevel, inInstance, rested)
  return ns.PassesGates(data, playerLevel, inInstance, rested)
end

-- Updates or inserts a food or flask entry into the displayable list.
local function UpsertFoodOrFlask(cat, itemID, data, qty, wellFedExpire, flaskExpire, playerLevel, inInstance, rested)
  if ns.IsExcluded and ns.IsExcluded(itemID) then
    local map = clickableRaidBuffCache.displayable[cat]
    if map and map[itemID] then Release(cat, map[itemID]); map[itemID] = nil end
    return
  end
  if qty <= 0 or not passesGates(data, playerLevel, inInstance, rested) then
    local map = clickableRaidBuffCache.displayable[cat]
    if map and map[itemID] then Release(cat, map[itemID]); map[itemID] = nil end
    return
  end

  local map = clickableRaidBuffCache.displayable[cat] or {}; clickableRaidBuffCache.displayable[cat] = map
  local entry = map[itemID]
  if not entry then entry = Acquire(cat, data); map[itemID] = entry else setmetatable(entry, nil); setmetatable(entry, { __index = data }) end

  entry.itemID, entry.category, entry.quantity = itemID, cat, qty
  applyItemCooldownFields(entry, itemID)

  local expire = (cat == "FOOD") and wellFedExpire or (cat == "FLASK" and flaskExpire or nil)
  local allow  = applyThreshold(entry, expire)
  if not allow then
    return
  end
end

-- Updates or inserts a weapon enchant entry into the displayable list.
local function UpsertWeaponEnchant(cat, itemID, data, hand, qty, playerLevel, inInstance, rested)
  local handType, enchantable = ns.WeaponEnchants_EquippedHandTypeAndEnchantable(hand)
  if not enchantable then
    local map = clickableRaidBuffCache.displayable[cat]; if map and map[itemID] then Release(cat, map[itemID]); map[itemID] = nil end
    return
  end
  local reqSlot = ns.WeaponEnchants_NormalizeSlotType(data and data.slotType)
  if reqSlot and handType and reqSlot ~= handType then
    local map = clickableRaidBuffCache.displayable[cat]; if map and map[itemID] then Release(cat, map[itemID]); map[itemID] = nil end
    return
  end

  local reqCat = data and data.weaponType
  if reqCat and not ns.WeaponEnchants_MatchesCategory(hand, reqCat) then
    local map = clickableRaidBuffCache.displayable[cat]; if map and map[itemID] then Release(cat, map[itemID]); map[itemID] = nil end
    return
  end

  if ns.IsExcluded and ns.IsExcluded(itemID) then
    local map = clickableRaidBuffCache.displayable[cat]; if map and map[itemID] then Release(cat, map[itemID]); map[itemID] = nil end
    return
  end
  if qty <= 0 or not passesGates(data, playerLevel, inInstance, rested) then
    local map = clickableRaidBuffCache.displayable[cat]; if map and map[itemID] then Release(cat, map[itemID]); map[itemID] = nil end
    return
  end

  local map = clickableRaidBuffCache.displayable[cat] or {}; clickableRaidBuffCache.displayable[cat] = map
  local entry = map[itemID]
  if not entry then entry = Acquire(cat, data); map[itemID] = entry else setmetatable(entry, nil); setmetatable(entry, { __index = data }) end

  entry.itemID, entry.category, entry.quantity = itemID, cat, qty
  applyItemCooldownFields(entry, itemID)

  local expire = GetSlotExpire(hand)
  local slot = (hand == "mainHand") and 16 or 17
  entry.macro = "/use item:"..tostring(itemID).."\n/use "..tostring(slot)

  local allow = applyThreshold(entry, expire)
  if not allow then
    map[itemID] = nil
    Release(cat, entry)
    return
  end
end

local _enchantNextAt
-- Schedules a check for when weapon enchants will expire.
function ScheduleEnchantThresholdCheck()
  local now = GetTime()

  if InCombatLockdown() then
    if _enchantNextAt and _enchantNextAt > now then
      C_Timer.After(0.30, ScheduleEnchantThresholdCheck)
    end
    return
  end

  local threshold = EffectiveItemThresholdSecs()

  local function nextCross(expire)
    if not expire or expire == math.huge then return nil end
    local t = expire - threshold
    if t and t > now then return t end
    return nil
  end

  local mhExpire = GetSlotExpire("mainHand")
  local ohExpire = GetSlotExpire("offHand")

  local tNext
  local t1 = nextCross(mhExpire); if t1 then tNext = t1 end
  local t2 = nextCross(ohExpire); if t2 and (not tNext or t2 < tNext) then tNext = t2 end

  if tNext and (not _enchantNextAt or tNext < _enchantNextAt - 0.01) then
    _enchantNextAt = tNext
    local delay = math.max(0.01, tNext - now)
    C_Timer.After(delay, function()
      if InCombatLockdown() then
        C_Timer.After(0.30, ScheduleEnchantThresholdCheck)
        return
      end

      _enchantNextAt = nil
      scanAllBags()
      if ns.PushRender then ns.PushRender() end
      ScheduleEnchantThresholdCheck()
    end)
  end
end

-- Re-evaluates thresholds for all bag items (food, flasks, enchants).
function ns.ReapplyBagThresholds()
  local pi   = clickableRaidBuffCache.playerInfo or {}
  local wf   = GetWellFedExpire()
  local flask= pi.flaskExpireTime
  local threshold = EffectiveItemThresholdSecs()

  local mapF = clickableRaidBuffCache.displayable.FOOD or {}
  for _, entry in pairs(mapF) do applyThreshold(entry, wf, threshold) end

  local mapPh = clickableRaidBuffCache.displayable.FLASK or {}
  for _, entry in pairs(mapPh) do applyThreshold(entry, flask, threshold) end

  local mhMap = clickableRaidBuffCache.displayable.MAIN_HAND or {}
  local ohMap = clickableRaidBuffCache.displayable.OFF_HAND  or {}

  local mhExpire = GetSlotExpire("mainHand")
  local ohExpire = GetSlotExpire("offHand")

  local purgeMH, purgeOH = {}, {}
  for itemID, entry in pairs(mhMap) do if not applyThreshold(entry, mhExpire, threshold) then purgeMH[#purgeMH+1]=itemID end end
  for itemID, entry in pairs(ohMap) do if not applyThreshold(entry, ohExpire, threshold) then purgeOH[#purgeOH+1]=itemID end end
  for i=1,#purgeMH do local id = purgeMH[i]; Release("MAIN_HAND", mhMap[id]); mhMap[id]=nil end
  for i=1,#purgeOH do local id = purgeOH[i]; Release("OFF_HAND",  ohMap[id]);  ohMap[id]=nil end

  ScheduleEnchantThresholdCheck()
end

-- Scans all bags for relevant items and updates the displayable list.
-- Skipped during combat.
function scanAllBags()
  if InCombatLockdown() then return end

  if ConsumablesSuppressed() then
    local d = clickableRaidBuffCache.displayable
    d.FOOD, d.FLASK, d.MAIN_HAND, d.OFF_HAND = {}, {}, {}, {}
    return
  end

  local playerLevel = clickableRaidBuffCache.playerInfo.playerLevel or UnitLevel("player") or 999
  local inInstance  = clickableRaidBuffCache.playerInfo.inInstance or select(1, IsInInstance())
  local rested      = clickableRaidBuffCache.playerInfo.restedXPArea or IsResting()

  local dirty, haveDirty = {}, false
  if ns.ConsumeDirtyBags then haveDirty = (ns.ConsumeDirtyBags(dirty) or 0) > 0 end
  if not haveDirty then for b=0, NUM_BAG_SLOTS do dirty[b] = true end end

  local seen = {}
  for bagID in pairs(dirty) do
    local numSlots = C_Container.GetContainerNumSlots(bagID)
    if numSlots and numSlots > 0 then
      for slot=1,numSlots do
        local itemID = C_Container.GetContainerItemID(bagID, slot)
        if itemID then seen[itemID] = true end
      end
    end
  end

  local count = {}
  for itemID in pairs(seen) do count[itemID] = C_Item.GetItemCount(itemID, false, false, false, false) or 0 end

  local wfExpire    = GetWellFedExpire()
  local flaskExpire = clickableRaidBuffCache.playerInfo.flaskExpireTime

  local FOOD   = ClickableRaidData and ClickableRaidData["FOOD"]      or nil
  local FLASK  = ClickableRaidData and ClickableRaidData["FLASK"]     or nil
  local MH     = ClickableRaidData and ClickableRaidData["MAIN_HAND"] or nil
  local OH     = ClickableRaidData and ClickableRaidData["OFF_HAND"]  or nil

  local touched = { FOOD = {}, FLASK = {}, MAIN_HAND = {}, OFF_HAND = {} }

  for itemID in pairs(seen) do
    local qty = count[itemID] or 0
    if FOOD and FOOD[itemID] then
      UpsertFoodOrFlask("FOOD", itemID, FOOD[itemID], qty, wfExpire, flaskExpire, playerLevel, inInstance, rested)
      touched.FOOD[itemID] = true
    end
    if FLASK and FLASK[itemID] then
      UpsertFoodOrFlask("FLASK", itemID, FLASK[itemID], qty, wfExpire, flaskExpire, playerLevel, inInstance, rested)
      touched.FLASK[itemID] = true
    end
    if MH and MH[itemID] then
      UpsertWeaponEnchant("MAIN_HAND", itemID, MH[itemID], "mainHand", qty, playerLevel, inInstance, rested)
      touched.MAIN_HAND[itemID] = true
    end
    if OH and OH[itemID] then
      UpsertWeaponEnchant("OFF_HAND", itemID, OH[itemID], "offHand", qty, playerLevel, inInstance, rested)
      touched.OFF_HAND[itemID] = true
    end
  end

  local disp = clickableRaidBuffCache.displayable
  for cat, mark in pairs(touched) do
    local map = disp[cat]
    if map then
      for itemID, entry in pairs(map) do
        if not mark[itemID] and not (ns.IsExcluded and ns.IsExcluded(itemID)) then
          local qty = count[itemID]; if qty == nil then qty = C_Item.GetItemCount(itemID, false, false, false, false) or 0 end
          if qty <= 0 then map[itemID] = nil; Release(cat, entry) end
        end
      end
    end
  end

  ScheduleEnchantThresholdCheck()
end

-- Marks a bag as dirty to be rescanned.
function markBagsForScan(bagID)
  if ns.MarkBagsDirty then ns.MarkBagsDirty(bagID) end
  if ns.PokeUpdateBus then ns.PokeUpdateBus() end
end

-- Processes pending bag scans.
function processPendingBags()
  scanAllBags()
end
