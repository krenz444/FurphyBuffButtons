-- ====================================
-- \Modules\Delves.lua
-- ====================================
-- This module handles Delve-specific settings, such as disabling consumables.

local addonName, ns = ...

local function DB()
  return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
end

local DIFF_DELVE = 208

-- Checks if the player is in a Delve instance.
-- Skipped during combat.
local function InInstanceDiff()
  if InCombatLockdown() then return false, 0 end
  local inInst = select(1, IsInInstance())
  if not inInst then return false end
  local _, _, difficultyID = GetInstanceInfo()
  return true, difficultyID
end

ns._delves_disable = ns._delves_disable or false
ns._delves_lastKey = ns._delves_lastKey or ""
ns._delves_renderHooked = ns._delves_renderHooked or false
ns._delves_origRenderAll = ns._delves_origRenderAll

-- Checks if an Augment Rune ID is consumable.
local function isConsumableAugmentRuneByID(id)
  local data = _G.ClickableRaidData and _G.ClickableRaidData.AUGMENT_RUNE
  if type(data) ~= "table" then return false end
  local rec = data[id]
  if type(rec) ~= "table" then return false end
  if rec.consumable ~= nil then return rec.consumable and true or false end
  return false
end

-- Checks if a rune entry is consumable.
local function isConsumableRuneEntry(entry, key)
  if type(entry) == "table" then
    if entry.consumable ~= nil then return entry.consumable and true or false end
    local id = tonumber(entry.itemID or entry.spellID or key)
    if id then return isConsumableAugmentRuneByID(id) end
  else
    local id = tonumber(entry or key)
    if id then return isConsumableAugmentRuneByID(id) end
  end
  return false
end

-- Filters out consumable Augment Runes from a table.
local function filterAugmentRunes(tbl)
  if type(tbl) ~= "table" then return {} end
  local isArray = tbl[1] ~= nil
  if isArray then
    local out = {}
    for i, v in ipairs(tbl) do
      if not isConsumableRuneEntry(v, i) then out[#out+1] = v end
    end
    return out
  else
    local out = {}
    for k, v in pairs(tbl) do
      if not isConsumableRuneEntry(v, k) then out[k] = v end
    end
    return out
  end
end

-- Suppresses consumable items (food, flasks, etc.) from display.
local function SuppressConsumables()
  _G.clickableRaidBuffCache = _G.clickableRaidBuffCache or {}
  _G.clickableRaidBuffCache.displayable = _G.clickableRaidBuffCache.displayable or {}
  local d = _G.clickableRaidBuffCache.displayable
  d.FOOD, d.FLASK, d.MAIN_HAND, d.OFF_HAND = {}, {}, {}, {}
  d.AUGMENT_RUNE = filterAugmentRunes(d.AUGMENT_RUNE)
end

-- Checks if consumable suppression is active for Delves.
function ns.Delves_DisableConsumablesActive()
  local inInst, difficultyID = InInstanceDiff()
  if not inInst then return false end
  if difficultyID ~= DIFF_DELVE then return false end
  local d = DB()
  return d.delvesDisableConsumables and true or false
end

-- Hooks RenderAll to apply Delve-specific logic.
local function EnsureHookRenderAll()
  if ns._delves_renderHooked then return end
  if type(ns.RenderAll) ~= "function" then return end
  ns._delves_origRenderAll = ns.RenderAll
  ns.RenderAll = function(...)
    if ns.Delves_DisableConsumablesActive and ns.Delves_DisableConsumablesActive() then
      SuppressConsumables()
    end
    return ns._delves_origRenderAll(...)
  end
  ns._delves_renderHooked = true
end

-- Recomputes Delve state and updates display.
-- Skipped during combat.
local function recompute()
  if InCombatLockdown() then return end
  EnsureHookRenderAll()
  local disableNow = ns.Delves_DisableConsumablesActive()
  ns._delves_disable = disableNow
  local key = disableNow and "1" or "0"
  if key ~= ns._delves_lastKey then
    ns._delves_lastKey = key
    if disableNow then
      SuppressConsumables()
      if ns.RenderAll then ns.RenderAll() end
    else
      if ns.RequestRebuild then ns.RequestRebuild() end
      if ns.RenderAll then ns.RenderAll() end
    end
  else
    if disableNow then
      SuppressConsumables()
      if ns.RenderAll then ns.RenderAll() end
    end
  end
end

-- Public API to recompute Delve state.
function ns.Delves_Recompute()
  recompute()
end
