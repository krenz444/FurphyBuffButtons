-- ====================================
-- \Core\Order.lua
-- ====================================
-- This file manages the display order of different buff categories and items.

local addonName, ns = ...

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end

-- Default order of categories
local DEFAULT_ORDER = {
  "EATING",
  "FOOD",
  "FLASK",
  "MAIN_HAND",
  "OFF_HAND",
  "CASTABLE_WEAPON_ENCHANTS",
  "DK_WEAPON_ENCHANTS",
  "ROGUE_POISONS",
  "AUGMENT_RUNE",
  "RAID_BUFFS",
  "TRINKETS",
  "SHAMAN_SHIELDS",
  "PETS",
  "DURABILITY",
  "HEALTHSTONE",
  "COSMETIC",
}

local allowed = {}
for i = 1, #DEFAULT_ORDER do allowed[DEFAULT_ORDER[i]] = true end

-- Returns the default category order
function ns.GetCategoryOrderDefaults()
  local out = {}
  for i = 1, #DEFAULT_ORDER do out[i] = DEFAULT_ORDER[i] end
  return out
end

-- Calculates the effective order, merging saved preferences with defaults
local function EffectiveOrder()
  local saved = DB().categoryOrder
  if type(saved) ~= "table" then return DEFAULT_ORDER end
  local seen, out = {}, {}
  for i = 1, #saved do
    local c = tostring(saved[i])
    if allowed[c] and not seen[c] then seen[c] = true out[#out+1] = c end
  end
  for i = 1, #DEFAULT_ORDER do
    local c = DEFAULT_ORDER[i]
    if not seen[c] then seen[c] = true out[#out+1] = c end
  end
  return out
end

-- Public API to get the current category order
function ns.GetCategoryOrder()
  return EffectiveOrder()
end

-- Public API to set the category order
function ns.SetCategoryOrder(order)
  local d = (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {}
  if type(order) ~= "table" then
    if ns.DebugPrint then ns.DebugPrint("SetCategoryOrder ignored: expected table, got "..type(order)) end
    return
  end
  d.categoryOrder = order
  if ns.RenderAll then ns.RenderAll() end
end

-- Generates a stable sort key for an entry
local function EntryStableKey(entry)
  if entry and entry.category == "PETS" then
    local h = tonumber(entry.orderHint) or 1e9
    if h < 0 then h = 0 end
    if h > 999 then h = 999 end
    local hint = string.format("%03d", h)
    if entry.itemID then return "p:" .. hint .. ":i:" .. entry.itemID end
    if entry.spellID then return "p:" .. hint .. ":s:" .. entry.spellID end
    return "p:" .. hint .. ":n:" .. tostring(entry.name or "")
  end

  if entry.itemID then return "i:" .. entry.itemID end
  if entry.spellID then return "s:" .. entry.spellID end
  return "n:" .. tostring(entry.name or "")
end

-- Gets the index of a category in the current order
function ns.GetOrderIndex(cat)
  local ord = EffectiveOrder()
  for i = 1, #ord do
    if ord[i] == cat then return i end
  end
  return 999
end

-- Sorts a list of display entries based on category order and other criteria
function ns.SortEntries(items)
  table.sort(items, function(a, b)
    local ai = ns.GetOrderIndex(a.category)
    local bi = ns.GetOrderIndex(b.category)
    if ai ~= bi then return ai < bi end

    if a.category == "PETS" then
      local ah = tonumber(a.orderHint) or 1e9
      local bh = tonumber(b.orderHint) or 1e9
      if ah ~= bh then return ah < bh end
    end

    local sa = (a.spellID or a.baseSpellID)
    local sb = (b.spellID or b.baseSpellID)
    if sa and sb and sa == sb then
      local af = (a.isFixed and 1 or 0)
      local bf = (b.isFixed and 1 or 0)
      if af ~= bf then return af < bf end
    end
    return EntryStableKey(a) < EntryStableKey(b)
  end)
end
