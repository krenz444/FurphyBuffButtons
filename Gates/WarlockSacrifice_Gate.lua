-- ====================================
-- \Gates\WarlockSacrifice_Gate.lua
-- ====================================
-- Warlock-specific gates checking for Grimoire of Sacrifice spell/buff status.
-- "wl_sacrifice": passes only for warlocks with the spell known, pet present, and buff absent.
-- "wl_no_sacrifice": passes when the sacrifice buff is not active.

local addonName, ns = ...

local SACRIFICE_SPELL = 108503
local SACRIFICE_BUFF  = 196099
local WARLOCK_CLASSID = 9

local function PlayerClassID()
  local id = clickableRaidBuffCache and clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.playerClassId
  if id then return id end
  local _, _, cid = UnitClass("player")
  return cid
end

local function KnowSpell(id)
  if C_SpellBook and C_SpellBook.IsSpellKnown then
    local ok = C_SpellBook.IsSpellKnown(id)
    if ok ~= nil then return ok end
  end
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  if IsSpellKnown and IsSpellKnown(id) then return true end
  return false
end

local function HasSacBuff()
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    return C_UnitAuras.GetPlayerAuraBySpellID(SACRIFICE_BUFF) ~= nil
  end
  local i = 1
  while true do
    local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
    if not a then break end
    if a.spellId == SACRIFICE_BUFF then return true end
    i = i + 1
  end
  return false
end

function ns.Gate_WL_Sacrifice()
  if PlayerClassID() ~= WARLOCK_CLASSID then return false end
  if not KnowSpell(SACRIFICE_SPELL) then return false end
  if not UnitExists("pet") then return false end
  if HasSacBuff() then return false end
  return true
end

function ns.Gate_WL_NoSacrifice()
  return not HasSacBuff()
end

ns.RegisterGate("wl_sacrifice", function()
  return ns.Gate_WL_Sacrifice()
end)

ns.RegisterGate("wl_no_sacrifice", function()
  return ns.Gate_WL_NoSacrifice()
end)
