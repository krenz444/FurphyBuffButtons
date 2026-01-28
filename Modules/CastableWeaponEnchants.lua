-- ====================================
-- \Modules\CastableWeaponEnchants.lua
-- ====================================
-- This module handles weapon enchants that are cast as spells (e.g., Flametongue Weapon, Windfury Weapon).

local addonName, ns = ...

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

local CAT = "CASTABLE_WEAPON_ENCHANTS"

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
local function InCombat() return InCombatLockdown() end
local function IsDeadOrGhost() return UnitIsDeadOrGhost("player") end

-- Checks if debug mode is enabled for this module.
local function DebugOn()
  local d = DB()
  return (ns and ns.DEBUG_CWE) or (clickableRaidBuffCache and clickableRaidBuffCache.debugCWE) or (d and (d.debugCWE or d.debugAll or d.debug))
end

-- Logs debug messages.
local function Log(fmt, ...)
  if not DebugOn() then return end
  local msg = "[CWE] " .. string.format(fmt, ...)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(msg)
  else
    print(msg)
  end
end

-- Calculates the threshold for showing the enchant icon based on duration settings.
local function spellThresholdSecs()
  local m = DB().weaponThreshold or 15
  if ns.MPlus_GetEffectiveThresholdSecs then
    local eff = ns.MPlus_GetEffectiveThresholdSecs("weapon", m)
    Log("Threshold secs via M+: %s", tostring(eff))
    return eff
  end
  local secs = m * 60
  Log("Threshold secs: %s", tostring(secs))
  return secs
end

-- Ensures the display category for castable weapon enchants exists.
local function ensureCat()
  clickableRaidBuffCache.displayable[CAT] = clickableRaidBuffCache.displayable[CAT] or {}
  return clickableRaidBuffCache.displayable[CAT]
end

-- Clears the display category.
local function clearCat()
  if clickableRaidBuffCache.displayable[CAT] then wipe(clickableRaidBuffCache.displayable[CAT]) end
  Log("Cleared category displayables")
end

-- Checks if a spell is known by the player.
local function knowSpell(id)
  if not id or not C_SpellBook or not Enum or not Enum.SpellBookSpellBank then
    Log("knowSpell(%s) -> false (APIs/ID missing)", tostring(id))
    return false
  end
  local bank = Enum.SpellBookSpellBank.Player
  local ok = C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id, bank)
  Log("knowSpell(%s) -> %s", tostring(id), tostring(ok and true or false))
  return ok and true or false
end

-- Checks if a row passes gating requirements.
local function passesGates(row)
  local g = row and row.gates
  if not g then return true end
  for i = 1, #g do
    local gate = g[i]
    if gate == "rested" and IsResting() then
      Log("Gate blocked: rested true for %s", tostring(row.spellID or row.name))
      return false
    end
  end
  return true
end

-- Checks remaining duration of a weapon enchant on a specific slot.
local function SlotEnchantRemaining(slotid)
  local hasMH, mhMs, _, _, hasOH, ohMs = GetWeaponEnchantInfo()
  if slotid == 16 then
    if hasMH and type(mhMs) == "number" and mhMs > 0 then
      local v = mhMs / 1000
      Log("Slot 16 remaining: %.1f", v)
      return v
    end
  elseif slotid == 17 then
    if hasOH and type(ohMs) == "number" and ohMs > 0 then
      local v = ohMs / 1000
      Log("Slot 17 remaining: %.1f", v)
      return v
    end
  end
  Log("Slot %s remaining: nil", tostring(slotid))
  return nil
end

local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or LE_ITEM_CLASS_WEAPON or 2
local ARMOR_CLASS  = (Enum and Enum.ItemClass and Enum.ItemClass.Armor)  or LE_ITEM_CLASS_ARMOR  or 4
local ARMOR_SHIELD = (Enum and Enum.ItemArmorSubclass and Enum.ItemArmorSubclass.Shield) or LE_ITEM_ARMOR_SHIELD or 6

-- Checks if the item in a slot matches the required weapon type.
local function SlotMatchesType(slotid, wepType)
  local itemID = GetInventoryItemID("player", slotid)
  if not itemID then
    Log("Slot %s has no item", tostring(slotid))
    return false
  end
  local classID, subClassID = select(6, C_Item.GetItemInfoInstant(itemID))
  if wepType == "shield" then
    local ok = (classID == ARMOR_CLASS) and (subClassID == ARMOR_SHIELD)
    Log("Slot %s type=shield item=%s class=%s sub=%s ok=%s", tostring(slotid), tostring(itemID), tostring(classID), tostring(subClassID), tostring(ok))
    return ok
  else
    local ok = (classID == WEAPON_CLASS)
    Log("Slot %s type=weapon item=%s class=%s ok=%s", tostring(slotid), tostring(itemID), tostring(classID), tostring(ok))
    return ok
  end
end

-- Determines the effective slot for a spell (e.g., Flametongue depends on spec).
local function EffectiveSlotForRow(row)
  if not row then return nil end
  if row.spellID == 318038 then
    local spec = GetSpecialization and GetSpecialization()
    local s = (spec == 2) and 17 or 16
    Log("Effective slot for Flametongue: %s (spec=%s)", tostring(s), tostring(spec))
    return s
  end
  Log("Effective slot for %s is data slot %s", tostring(row.spellID), tostring(row.slotid))
  return row.slotid
end

-- Rebuilds the display list for castable weapon enchants.
-- Skipped during combat.
local function Build(fromRender)
  if InCombat() or IsDeadOrGhost() then
    clearCat()
    if not fromRender and ns.RenderAll and not InCombat() then ns.RenderAll() end
    return
  end

  local tbl = ClickableRaidData and ClickableRaidData[CAT]
  if not tbl then
    clearCat()
    if not fromRender and ns.RenderAll and not InCombat() then ns.RenderAll() end
    return
  end

  local out = ensureCat()
  wipe(out)

  local tSec = spellThresholdSecs()

  local function effectiveSlotForRow(row)
    if not row then return nil end
    if row.spellID == 318038 then
      local spec = GetSpecialization and GetSpecialization()
      return (spec == 2) and 17 or 16
    end
    return row.slotid
  end

  local function safeCopy(row)
    local e = (ns.copyItemData and ns.copyItemData(row)) or {}
    for k, v in pairs(row) do if e[k] == nil then e[k] = v end end
    return e
  end

  for _, row in pairs(tbl) do
    repeat
      if type(row) ~= "table" or not row.spellID then break end

      local slotid = effectiveSlotForRow(row)
      if slotid ~= 16 and slotid ~= 17 then break end

      if not knowSpell(row.spellID) then break end
      if not passesGates(row) then break end
      if not SlotMatchesType(slotid, row.wepType) then break end

      local rem = SlotEnchantRemaining(slotid)
      local show = (rem == nil) or (rem and rem <= tSec)
      if not show then break end

      local e = safeCopy(row)
      e.category = CAT
      e.isItem  = false
      e.spellID = row.spellID
      e.icon    = e.icon or (C_Spell and C_Spell.GetSpellInfo and (C_Spell.GetSpellInfo(row.spellID) or {}).iconID) or e.icon

      local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(row.spellID) or nil
      e.macro = "/use " .. ((info and info.name) or row.name or "")

      if rem and rem > 0 and rem <= tSec then
        e.expireTime = GetTime() + rem
      end

      e.orderHint = ((slotid == 16) and 100000 or 200000) + (row.spellID or 0)

      local key = "cwe:" .. tostring(slotid) .. ":" .. tostring(row.spellID)
      out[key] = e
    until true
  end

  if not fromRender and ns.RenderAll and not InCombat() then ns.RenderAll() end
end

-- Public API to rebuild the display list.
function ns.CastableWeaponEnchants_Rebuild()
  Log("API: CastableWeaponEnchants_Rebuild")
  Build(false)
end

-- Hooks GetCategoryOrder to ensure this category is included.
local function EnsureOrderHook()
  if ns._cwe_order_wrapped then return end
  if type(ns.GetCategoryOrder) ~= "function" then return end
  local orig = ns.GetCategoryOrder
  ns.GetCategoryOrder = function(...)
    local list = orig(...) or {}
    local have = false
    for i = 1, #list do if list[i] == CAT then have = true; break end end
    if have then return list end
    local disp = _G.clickableRaidBuffCache and _G.clickableRaidBuffCache.displayable
    if disp and disp[CAT] and next(disp[CAT]) then
      local out = {}
      for i = 1, #list do out[i] = list[i] end
      out[#out+1] = CAT
      Log("Order hook appended category")
      return out
    end
    return list
  end
  ns._cwe_order_wrapped = true
  Log("Order hook installed")
end

-- Hooks RenderAll to ensure this module is updated before rendering.
local function EnsureRenderHook()
  if ns._cwe_render_wrapped then return end
  if type(ns.RenderAll) == "function" then
    local orig = ns.RenderAll
    ns.RenderAll = function(...)
      Log("Render hook: pre-build")
      Build(true)
      return orig(...)
    end
    ns._cwe_render_wrapped = true
    Log("Render hook installed")
  end
end

EnsureOrderHook()
EnsureRenderHook()
C_Timer.After(0.05, EnsureOrderHook)
C_Timer.After(0.05, EnsureRenderHook)
C_Timer.After(0.5, EnsureOrderHook)
C_Timer.After(0.5, EnsureRenderHook)
