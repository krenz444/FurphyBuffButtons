-- ====================================
-- \Modules\RoguePoisons.lua
-- ====================================
-- This module handles the display of Rogue poisons (Lethal and Non-Lethal).

local addonName, ns = ...

furphyBuffCache = furphyBuffCache or {}
furphyBuffCache.displayable = furphyBuffCache.displayable or {}

local CAT = "ROGUE_POISONS"
local TALENT_DOUBLE_PER_CAT = 381801

local function DB() return (ns.GetDB and ns.GetDB()) or _G.FurphyBuffButtonsDB or {} end
local function InCombat() return InCombatLockdown() end
local function IsDeadOrGhost() return UnitIsDeadOrGhost("player") end

-- Ensures the display category for rogue poisons exists.
local function ensureCat()
  furphyBuffCache.displayable[CAT] = furphyBuffCache.displayable[CAT] or {}
  return furphyBuffCache.displayable[CAT]
end

-- Clears the display category.
local function clearCat()
  if furphyBuffCache.displayable[CAT] then wipe(furphyBuffCache.displayable[CAT]) end
end

-- Checks if the player is a Rogue.
-- Returns cached value during combat.
local function isRogue()
  if InCombat() then return furphyBuffCache.playerInfo and furphyBuffCache.playerInfo.playerClassId == 4 end
  local cid = (furphyBuffCache.playerInfo and furphyBuffCache.playerInfo.playerClassId)
              or (type(getPlayerClass)=="function" and getPlayerClass()) or 0
  return cid == 4
end

-- Checks if a spell is known by the player.
local function knowSpell(id)
  return (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
         or (IsPlayerSpell and IsPlayerSpell(id)) or false
end

-- Calculates the threshold for showing the poison icon based on spell duration settings.
local function spellThresholdSecs()
  local db = (ns.GetDB and ns.GetDB()) or _G.FurphyBuffButtonsDB or {}
  local baseMin = db.spellThreshold or 15
  if ns.MPlus_GetEffectiveThresholdSecs then
    return ns.MPlus_GetEffectiveThresholdSecs("spell", baseMin)
  end
  return baseMin * 60
end

-- Checks remaining duration of a poison on the player.
local function auraRemOnPlayer(buffId)
  if not buffId then return nil end
  local i = 1
  while true do
    local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not a then break end

    local isSecret = false
    if issecretvalue and (issecretvalue(a.sourceUnit) or issecretvalue(a.name) or issecretvalue(a.spellId)) then
      isSecret = true
    end

    local isMine = false
    if not isSecret and a.sourceUnit then
      local ok, result = pcall(UnitIsUnit, a.sourceUnit, "player")
      if ok and result then
        isMine = true
      end
    end

    if not isSecret and a.spellId == buffId and isMine then
      local ex = a.expirationTime
      if ex and issecretvalue and issecretvalue(ex) then
        return math.huge
      elseif ex and ex > 0 then
        return ex - GetTime()
      else
        return math.huge
      end
    end
    i = i + 1
  end
  return nil
end

-- Counts active poisons in a category (Lethal/Non-Lethal) above the threshold.
local function countCatAbove(tbl, cat, tSec)
  local c = 0
  for _, row in pairs(tbl) do
    if type(row)=="table" and row.cat == cat and row.buffID and row.buffID[1] then
      local rem = auraRemOnPlayer(row.buffID[1])
      if rem and rem > tSec then
        c = c + 1
      end
    end
  end
  return c
end

-- Rebuilds the display list for rogue poisons.
-- Skipped during combat.
local function Build()
  if InCombat() or IsDeadOrGhost() then
    clearCat()
    return
  end
  if not isRogue() then
    clearCat()
    return
  end

  local tbl = FurphyBuffData and FurphyBuffData[CAT]
  if not tbl then
    clearCat()
    return
  end

  local out = ensureCat()
  wipe(out)

  local tSec    = spellThresholdSecs()
  local capPer  = knowSpell(TALENT_DOUBLE_PER_CAT) and 2 or 1

  local lethalAbove    = countCatAbove(tbl, "LETHAL", tSec)
  local nonLethalAbove = countCatAbove(tbl, "NONLETHAL", tSec)

  local lethalOrder, nonOrder = 10, 110

  for key, row in pairs(tbl) do
    repeat
      if type(row) ~= "table" or not row.spellID or not row.buffID or not row.buffID[1] then break end
      if not knowSpell(row.spellID) then break end

      local rem  = auraRemOnPlayer(row.buffID[1])
      local has  = rem and rem > 0
      local cap  = (row.cat == "LETHAL") and lethalAbove or nonLethalAbove
      local atCapStrict = cap >= capPer

      local shouldShow = (not atCapStrict and not has) or (has and rem <= tSec)
      if not shouldShow then break end

      local info = C_Spell.GetSpellInfo(row.spellID)
      local e = ns.copyItemData(row)
      e.category  = CAT
      e.spellID   = row.spellID
      e.macro     = "/use " .. ((info and info.name) or row.name or "")
      e.orderHint = (row.cat == "LETHAL") and (lethalOrder) or (nonOrder)

      if has and rem and rem > 0 and rem <= tSec then
        e.expireTime = GetTime() + rem
      end

      local outKey = string.format("%s:%d", row.cat or "POISON", row.spellID or key)
      out[outKey] = e

      if row.cat == "LETHAL" then lethalOrder = lethalOrder + 1 else nonOrder = nonOrder + 1 end
    until true
  end
end

-- Public API to rebuild the display list.
function ns.RoguePoisons_Rebuild()
  Build()
  if ns.RenderAll and not InCombat() and not IsDeadOrGhost() then
    ns.RenderAll()
  end
end

-- Watches for changes in threshold settings.
local _lastSpellThreshold = spellThresholdSecs()
local function EnsureThresholdWatcher()
  if ns._roguePoisonsThresholdWatcher then return end
  ns._roguePoisonsThresholdWatcher = C_Timer.NewTicker(0.5, function()
    local cur = spellThresholdSecs()
    if cur ~= _lastSpellThreshold then
      _lastSpellThreshold = cur
      if not InCombat() and not IsDeadOrGhost() then
        ns.RoguePoisons_Rebuild()
      end
    end
  end)
end
EnsureThresholdWatcher()

-- Event handlers
function ns.RoguePoisons_OnPEW()
  ns.RoguePoisons_Rebuild()
  return true
end

function ns.RoguePoisons_OnRegenDisabled()
  clearCat()
  return true
end

function ns.RoguePoisons_OnRegenEnabled()
  ns.RoguePoisons_Rebuild()
  return true
end

function ns.RoguePoisons_OnPlayerDead()
  clearCat()
  return true
end

function ns.RoguePoisons_OnPlayerUnghost()
  ns.RoguePoisons_Rebuild()
  return true
end

function ns.RoguePoisons_OnUnitAura(unit)
  if unit ~= "player" then return false end
  if InCombat() or IsDeadOrGhost() then return false end
  ns.RoguePoisons_Rebuild()
  return true
end

function ns.RoguePoisons_OnSpecializationChanged()
  if InCombat() or IsDeadOrGhost() then return false end
  ns.RoguePoisons_Rebuild()
  return true
end

function ns.RoguePoisons_OnSpellsChanged()
  if InCombat() or IsDeadOrGhost() then return false end
  ns.RoguePoisons_Rebuild()
  return true
end
