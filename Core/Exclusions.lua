-- ====================================
-- \Core\Exclusions.lua
-- ====================================
-- This file handles the logic for excluding specific buffs or items from being displayed.

local addonName, ns = ...
ns.Exclusions = ns.Exclusions or {}
local M = ns.Exclusions

-- Categories that are treated as raid-like for exclusion purposes
local RAIDLIKE = {
  RAID_BUFFS                = true,
  CLASS_ABILITIES           = true,
  TRINKET_RB                = true,
  RAID_TRINKETS             = true,
  ROGUE_POISONS             = true,
  CASTABLE_WEAPON_ENCHANTS  = true,
  SHAMAN_SHIELDS            = true,
  HEALTHSTONE               = true,
}

-- Spell IDs for hunter pets
local HUNTER_PET_SPELLS = {
  [883]   = true,
  [83242] = true,
  [83243] = true,
  [83244] = true,
  [83245] = true,
}
local HUNTER_PETS_PSEUDO_ID = -7001

-- Helper to get the database
local function DB()
  return (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
end

-- Internal state for caching exclusion sets
local state = {
  dirty = true,
  ai = nil,
  ri = nil,
  a_ptr = nil, r_ptr = nil,
}

-- Retrieves the exclusion sets from the database
local function getSets()
  local d = DB()
  d.exclusions = d.exclusions or {}
  d.raidBuffExclusions = d.raidBuffExclusions or {}
  return d.exclusions, d.raidBuffExclusions
end

-- Rebuilds the internal cache of exclusions
local function rebuild()
  local a, r = getSets()

  local ai, ri = {}, {}
  for id, v in pairs(a) do if v then ai[tonumber(id) or id] = true end end
  for id, v in pairs(r) do if v then ri[tonumber(id) or id] = true end end

  state.ai, state.ri = ai, ri
  state.a_ptr, state.r_ptr = a, r
  state.dirty = false
end

-- Marks the exclusion cache as dirty, forcing a rebuild on next access
function M.MarkDirty()
  state.dirty = true
end

-- Ensures the exclusion cache is up to date
local function ensure()
  if state.dirty then rebuild(); return end
  local a, r = getSets()
  if a ~= state.a_ptr or r ~= state.r_ptr then rebuild() end
end

-- Checks if a specific entry is excluded based on its category and ID
-- @param cat: Category name (e.g., "RAID_BUFFS", "FLASK", "CASTABLE_WEAPON_ENCHANTS")
-- @param entry: Entry table containing identification fields (spellID, itemID, id, _exKey, etc.)
-- @return: true if excluded, false otherwise
function M.IsExcluded(cat, entry)
  if not entry then return false end

  -- Determine which exclusion set to use based on category
  local d = (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
  local set = (RAIDLIKE and RAIDLIKE[cat]) and (d.raidBuffExclusions or {}) or (d.exclusions or {})
  if not set then return false end

  -- Try to find the entry's key from various possible key fields
  local key = entry._exKey or entry._tableKey or entry._rowKey or entry._raidKey or entry._k

  -- Weak-keyed cache to avoid repeated lookups through displayable tables
  ns._ExKeyCache = ns._ExKeyCache or setmetatable({}, { __mode = "k" })
  if not key then
    -- Search displayable cache to find this entry's key
    local disp = _G.clickableRaidBuffCache and _G.clickableRaidBuffCache.displayable and _G.clickableRaidBuffCache.displayable[cat]
    if type(disp) == "table" then
      for k, v in pairs(disp) do
        if v == entry then key = k; break end
      end
    end
    ns._ExKeyCache[entry] = key or false
  elseif key == false then
    key = nil
  end

  -- Build list of all possible identifiers for this entry
  local candidates = {}
  if key then candidates[#candidates+1] = key end
  if entry.spellID then candidates[#candidates+1] = entry.spellID end
  if entry.itemID then candidates[#candidates+1] = entry.itemID end
  if entry.id      then candidates[#candidates+1] = entry.id end

  -- Special handling for castable weapon enchants to clean up stale keys
  -- Migrates old display keys (cwe:*) to stable spell/item IDs
  if cat == "CASTABLE_WEAPON_ENCHANTS" and key and type(key) == "string" and key:sub(1,4) == "cwe:" then
    local hasDisplayKey = set[key] and true or false
    local hasStableKey  = (entry.spellID and set[entry.spellID]) or (entry.id and set[entry.id]) or false
    if hasDisplayKey and not hasStableKey then
      set[key] = nil
      if ns.Exclusions and ns.Exclusions.MarkDirty then ns.Exclusions.MarkDirty() end
    end
  end

  -- Check if any candidate ID is in the exclusion set
  for i = 1, #candidates do
    local k = candidates[i]
    if k ~= nil and set[k] then
      return true
    end
  end

  -- Check dedupe IDs (for entries with multiple equivalent spell IDs)
  if entry._dedupeIDs then
    for i = 1, #entry._dedupeIDs do
      local k = entry._dedupeIDs[i]
      if set[k] then
        return true
      end
    end
  end

  return false
end

-- Public API to check if a displayable entry is excluded
function ns.IsDisplayableExcluded(cat, entry)
  return M.IsExcluded(cat, entry)
end
