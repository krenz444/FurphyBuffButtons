-- ====================================
-- \Modules\ShamanShields.lua
-- ====================================
-- This module handles the display of Shaman shields (Lightning Shield, Water Shield, Earth Shield).

local addonName, ns = ...

clickableRaidBuffCache = clickableRaidBuffCache or {}
clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end
DB().fixedTargets = DB().fixedTargets or {}

local CAT          = "SHAMAN_SHIELDS"
local ORBIT_TALENT = 383010
local TRUNC_N      = 6

local function InCombat() return InCombatLockdown() end

-- Checks if the player is a Shaman.
-- Returns cached value during combat.
local function isShaman()
  if InCombat() then return clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.playerClassId == 7 end
  local cid = (clickableRaidBuffCache.playerInfo and clickableRaidBuffCache.playerInfo.playerClassId)
              or (type(getPlayerClass)=="function" and getPlayerClass())
  return cid == 7
end

-- Checks if a spell is known by the player.
local function knowSpell(id)
  return (C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id))
         or (IsPlayerSpell and IsPlayerSpell(id)) or false
end

-- Calculates the threshold for showing the shield icon based on spell duration settings.
local function thresholdSecs()
  local db = (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
  local baseMin = db.spellThreshold or 15
  if ns.MPlus_GetEffectiveThresholdSecs then
    return ns.MPlus_GetEffectiveThresholdSecs("spell", baseMin)
  end
  return baseMin * 60
end

-- Ensures the display category for Shaman shields exists.
local function ensureCat()
  clickableRaidBuffCache.displayable[CAT] = clickableRaidBuffCache.displayable[CAT] or {}
  return clickableRaidBuffCache.displayable[CAT]
end

-- Clears the Shaman shields display category.
local function clearCat()
  if clickableRaidBuffCache.displayable[CAT] then wipe(clickableRaidBuffCache.displayable[CAT]) end
end

-- Gets a short name from a unit ID.
local function shortName(unit)
  local n = UnitName(unit)
  return (n and n ~= "") and n or nil
end

-- Truncates a name to a fixed length.
local function truncName(s)
  return (s and s:sub(1, TRUNC_N)) or s
end

-- Iterates over all group units.
local function IterateGroupUnits()
  local u = {}
  if IsInRaid() then
    for i=1, GetNumGroupMembers() do u[#u+1] = "raid"..i end
  elseif IsInGroup() then
    for i=1, GetNumSubgroupMembers() do u[#u+1] = "party"..i end
    u[#u+1] = "player"
  else
    u[#u+1] = "player"
  end
  return u
end

-- Checks remaining duration of an aura on a unit.
local function auraRem(unit, buffId, mineOnly)
  if not buffId then return nil end
  local i=1
  while true do
    local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
    if not a then break end
    if a.spellId == buffId then
      if not mineOnly or (a.sourceUnit and UnitIsUnit(a.sourceUnit, "player")) then
        if a.expirationTime and a.expirationTime > 0 then
          return a.expirationTime - GetTime()
        else
          return math.huge
        end
      end
    end
    i=i+1
  end
  return nil
end

-- Checks if an entry has a specific gate.
local function hasGate(entry, name)
  local g = entry and entry.gates
  if not g then return false end
  if g[name] == true then return true end
  local n = #g
  for i=1,n do if g[i] == name then return true end end
  return false
end

-- Counts active elemental shields on the player.
local function countSelfElementals(tbl, hasOrbit, mineOnlyES)
  local LS = tbl[192106]
  local WS = tbl[52127]
  local ES = tbl[974]

  local c = 0
  if LS and auraRem("player", LS.buffID and LS.buffID[1], true) then c=c+1 end
  if WS and auraRem("player", WS.buffID and WS.buffID[1], true) then c=c+1 end
  local selfESid = hasOrbit and (ES and ES.buffOnSelf) or (ES and ES.buffOnOthers)
  if selfESid and auraRem("player", selfESid, mineOnlyES) then c=c+1 end
  return c
end

-- Counts active elemental shields on the player with sufficient duration.
local function countSelfAbove(tbl, hasOrbit, tSec, mineOnlyES)
  local LS = tbl[192106]
  local WS = tbl[52127]
  local ES = tbl[974]

  local c = 0
  local r = LS and auraRem("player", LS.buffID and LS.buffID[1], true)
  if r and r > tSec then c=c+1 end
  r = WS and auraRem("player", WS.buffID and WS.buffID[1], true)
  if r and r > tSec then c=c+1 end
  local selfESid = hasOrbit and (ES and ES.buffOnSelf) or (ES and ES.buffOnOthers)
  r = selfESid and auraRem("player", selfESid, mineOnlyES)
  if r and r > tSec then c=c+1 end
  return c
end

-- Finds the soonest expiring Earth Shield on other group members.
local function soonestEarthOnOthers(ES, mineOnlyES)
  if not ES or not ES.buffOnOthers then return nil end
  local want = ES.buffOnOthers
  local best
  for _, u in ipairs(IterateGroupUnits()) do
    if u ~= "player" then
      local rem = auraRem(u, want, mineOnlyES)
      if rem and (not best or rem < best) then best = rem end
    end
  end
  return best
end

-- Finds the soonest expiring Earth Shield anywhere (no Orbit talent).
local function soonestEarthAnywhere_NoOrbit(ES, mineOnlyES)
  if not ES or not ES.buffOnOthers then return nil end
  local want = ES.buffOnOthers
  local best
  for _, u in ipairs(IterateGroupUnits()) do
    local rem = auraRem(u, want, mineOnlyES)
    if rem and (not best or rem < best) then best = rem end
  end
  return best
end

-- Checks if a name is in the group.
local function nameInGroup(short)
  if not short or short=="" then return false end
  for _, u in ipairs(IterateGroupUnits()) do
    if shortName(u) == short then return true end
  end
  return false
end

-- Updates the fixed target for Earth Shield if cast on a group member.
local function learnEarthFixedFrom(unit, ES)
  if not ES or not ES.buffOnOthers then return false end
  if not unit or unit=="player" then return false end
  if not (unit:match("^party%d") or unit:match("^raid%d")) then return false end

  local want = ES.buffOnOthers
  local i=1
  while true do
    local a = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
    if not a then break end
    if a.spellId == want and a.sourceUnit and UnitIsUnit(a.sourceUnit, "player") then
      local who = shortName(unit)
      local me  = shortName("player")
      if who and who ~= me and DB().fixedTargets[974] ~= who then
        DB().fixedTargets[974] = who
        return true
      end
    end
    i=i+1
  end
  return false
end

-- Checks if the player is in a rested area.
local function InRestedArea()
  return IsResting() or false
end

-- Rebuilds the Shaman shields display list.
-- Skipped during combat.
local function Build()
  if InCombat() then return end
  if not isShaman() then clearCat(); return end
  if InRestedArea() then clearCat(); return end

  local tbl = ClickableRaidData and ClickableRaidData[CAT]
  if not tbl then clearCat(); return end

  local out = ensureCat()
  wipe(out)

  local tSec      = thresholdSecs()
  local hasOrbit  = knowSpell(ORBIT_TALENT)
  local capSelf   = hasOrbit and 2 or 1

  local LS = tbl[192106]
  local WS = tbl[52127]
  local ES = tbl[974]

  local mineOnlyES = hasGate(ES, "mineOnly")

  local selfAbove   = countSelfAbove(tbl, hasOrbit, tSec, mineOnlyES)
  local atCapStrict = (selfAbove >= capSelf)

  local function addSelfIcon(row, orderHint, rem)
    if not row or not knowSpell(row.spellID) then return end
    local info = C_Spell.GetSpellInfo(row.spellID)
    local e = ns.copyItemData(row)
    e.category  = CAT
    e.spellID   = row.spellID
    e.macro     = "/use " .. (info and info.name or row.name or "")
    e.orderHint = orderHint
    if rem and rem > 0 and rem <= tSec then
      e.expireTime = GetTime() + rem
    end
    out["self:"..row.spellID] = e
  end

  if LS and knowSpell(LS.spellID) then
    local rem = auraRem("player", LS.buffID and LS.buffID[1], true)
    local has = rem and rem > 0
    if (not atCapStrict and not has) or (has and rem <= tSec) then
      addSelfIcon(LS, 1, rem)
    end
  end

  if WS and knowSpell(WS.spellID) then
    local rem = auraRem("player", WS.buffID and WS.buffID[1], true)
    local has = rem and rem > 0
    if (not atCapStrict and not has) or (has and rem <= tSec) then
      addSelfIcon(WS, 2, rem)
    end
  end

  if ES and knowSpell(ES.spellID) then
    local otherRem
    if hasOrbit then
      otherRem = soonestEarthOnOthers(ES, mineOnlyES)
    else
      otherRem = soonestEarthAnywhere_NoOrbit(ES, mineOnlyES)
    end

    local needShow
    if hasOrbit then
      local othersAbove = (otherRem ~= nil) and (otherRem > tSec)
      local selfESid = (ES and ES.buffOnSelf) or (ES and ES.buffOnOthers)
      if ES and ES.buffOnSelf then selfESid = ES.buffOnSelf end
      local selfESrem = selfESid and auraRem("player", selfESid, mineOnlyES) or nil
      local selfESAbove = (selfESrem ~= nil) and (selfESrem > tSec)
      local twoSelfAbove = (selfAbove >= 2)
      local hide = othersAbove and (twoSelfAbove or selfESAbove)
      needShow = not hide
    else
      needShow = (otherRem == nil) or (otherRem <= tSec)
    end

    if needShow then
      local spellName = (C_Spell.GetSpellInfo(ES.spellID) or {}).name or ES.name or "Earth Shield"

      do
        local e = ns.copyItemData(ES)
        e.category  = CAT
        e.spellID   = ES.spellID
        e.macro     = "/use [@target,help,nodead] " .. spellName
        e.orderHint = 10
        if otherRem and otherRem > 0 and otherRem <= tSec then
          e.expireTime = GetTime() + otherRem
        end
        out["es:target"] = e
      end

      do
        local who = DB().fixedTargets[974]
        local me  = shortName("player")
        if who and who ~= me and nameInGroup(who) then
          local e = ns.copyItemData(ES)
          e.category = CAT
          e.spellID  = ES.spellID
          e.isFixed  = true
          e.macro    = "/use [@" .. who .. "] " .. spellName
          e.btmLbl   = truncName(who)
          e.orderHint= 20
          if otherRem and otherRem > 0 and otherRem <= tSec then
            e.expireTime = GetTime() + otherRem
          end
          out["es:fixed"] = e
        end
      end
    end
  end
end

-- Public API to rebuild Shaman shields display.
function ns.ShamanShields_Rebuild()
  if InCombat() then return end
  Build()
  if ns.RenderAll and not InCombat() then ns.RenderAll() end
end

-- Event handlers
function ns.ShamanShields_OnPEW()
  ns.ShamanShields_Rebuild()
  return true
end

function ns.ShamanShields_OnRegenEnabled()
  ns.ShamanShields_Rebuild()
  return true
end

function ns.ShamanShields_OnSpellsChanged()
  ns.ShamanShields_Rebuild()
  return true
end

function ns.ShamanShields_OnPlayerUpdateResting()
  ns.ShamanShields_Rebuild()
  return true
end

function ns.ShamanShields_OnGroupRosterUpdate()
  local whoSaved = DB().fixedTargets[974]
  if whoSaved and not nameInGroup(whoSaved) then
    DB().fixedTargets[974] = nil
  end
  ns.ShamanShields_Rebuild()
  return true
end

function ns.ShamanShields_OnUnitAura(unit)
  if InCombat() then return false end
  local tbl = ClickableRaidData and ClickableRaidData[CAT]
  local ES  = tbl and tbl[974]
  if not ES then return false end
  if unit and (unit == "player" or unit:match("^party%d") or unit:match("^raid%d")) then
    local changed = learnEarthFixedFrom(unit, ES)
    if changed then
      ns.ShamanShields_Rebuild()
      return true
    end
    if unit == "player" then
      ns.ShamanShields_Rebuild()
      return true
    end
  end
  return false
end
