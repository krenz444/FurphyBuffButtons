-- ====================================
-- \Gates\Range_Gate.lua
-- ====================================
-- Complex gate that monitors spell range to raid members who are missing buffs.
-- Suppresses icons when no missing raid members are in range, shows them when targets
-- are available. Uses a 2-second ticker for efficient range checks and glow updates.

local addonName, ns = ...
ns = ns or {}

local function DB() return (ns.GetDB and ns.GetDB()) or ClickableRaidBuffsDB or {} end

local function GetSpellRange(spellID)
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
  if info and info.maxRange and info.maxRange > 0 then
    return info.maxRange, info.name
  end
  return 0, info and info.name or nil
end

local function UnitHasAnyBuffFromIDs(unit, ids)
  if not ids or not unit then return false end
  local found = false
  AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(a)
    if a and a.spellId and ids[a.spellId] then
      found = true
      return true
    end
  end, true)
  return found
end

local function GetGroupUnits()
  local out, n = {}, 0
  if IsInRaid() then
    for i=1,GetNumGroupMembers() do
      local u = "raid"..i
      if UnitExists(u) then n=n+1; out[n] = u end
    end
  elseif IsInGroup() then
    for i=1,GetNumSubgroupMembers() do
      local u = "party"..i
      if UnitExists(u) then n=n+1; out[n] = u end
    end
  end
  n=n+1; out[n] = "player"
  return out, n
end

local function ResolveBuffIDsForData(data)
  if not data then return {} end
  local list = data.buffID or data.buffIDs
  if not list then
    if data.spellID then
      local s = {}; s[data.spellID] = true; return s
    end
    return {}
  end
  local ids = {}
  if type(list) == "table" then
    for i = 1, #list do local v = list[i]; if v then ids[v] = true end end
  elseif type(list) == "number" then
    ids[list] = true
  end
  return ids
end

local RangeState = {
  ticker = nil,
  lastSummary = nil,
  inactivityTicks = 0,
}

function ns.IsRangeTickerRunning()
  return RangeState.ticker ~= nil
end

local function IsTickerEligible()
  if type(ns.locked) == "function" and ns.locked() then return false end
  if ns._inCombat or (InCombatLockdown and InCombatLockdown()) then return false end
  if ns._isDead   or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return false end
  if not (IsInGroup() or IsInRaid()) then return false end
  return true
end

local function StopTicker()
  if RangeState.ticker then
    RangeState.ticker:Cancel()
    RangeState.ticker = nil
  end
end

local function TickRangeGate()
  if not IsTickerEligible() then
    StopTicker()
    return
  end

  local spells = {}
  local anyMissing = false
  local anyGlowChanged = false

  if ns._rangeTracked and next(ns._rangeTracked) then
    local units = GetGroupUnits()
    for spellID, entry in pairs(ns._rangeTracked) do
      local maxRange, spellName = GetSpellRange(spellID)
      local ids = entry.ids or {}
      local miss = {}
      local anyMissingOutOfRange = false
      local foundInRange = false

      for i = 1, #units do
        local u = units[i]
        if not UnitHasAnyBuffFromIDs(u, ids) then
          local inRange = false
          if C_Spell and C_Spell.IsSpellInRange then
            local ret = C_Spell.IsSpellInRange(spellID, u)
            inRange = (ret == true)
          end
          miss[#miss+1] = { unit = u, name = UnitName(u), inRange = inRange }
          if inRange then
            foundInRange = true
            break
          else
            anyMissingOutOfRange = true
          end
        end
      end

      if #miss > 0 then anyMissing = true end

      local nowAllIn = (#miss > 0) and (foundInRange and not anyMissingOutOfRange) or false
      local desiredGlow = nowAllIn and "special" or nil

      if entry.desiredGlow ~= desiredGlow then
        entry.desiredGlow = desiredGlow
        anyGlowChanged = true
      end

      spells[#spells+1] = { spellID = spellID, name = spellName, maxRange = maxRange, missing = miss }
    end
  end

  RangeState.lastSummary = { spells = spells, anyMissing = anyMissing }

  if anyMissing then
    RangeState.inactivityTicks = 0
  else
    RangeState.inactivityTicks = RangeState.inactivityTicks + 1
    if RangeState.inactivityTicks >= 2 then
      StopTicker()
    end
  end

  if anyGlowChanged and type(ns.RequestRebuild) == "function" then
    ns.RequestRebuild()
  end
end

local function StartTicker()
  if RangeState.ticker or not IsTickerEligible() then return end
  RangeState.inactivityTicks = 0
  RangeState.ticker = C_Timer.NewTicker(2.0, TickRangeGate)
end

function ns.InitRangeGate()
  ns._rangeTracked = ns._rangeTracked or {}
  RangeState.lastSummary = nil
end

function ns.RangeGate_OnRosterOrSpellsChanged()
  if not ns._rangeTracked then return end

  local shouldRun = false
  if next(ns._rangeTracked) then
    local units = GetGroupUnits()
    for spellID, entry in pairs(ns._rangeTracked) do
      local ids = entry.ids or {}
      if UnitHasAnyBuffFromIDs("player", ids) then
        for i = 1, #units do
          local u = units[i]
          if u ~= "player" and not UnitHasAnyBuffFromIDs(u, ids) then
            shouldRun = true
            break
          end
        end
      end
      if shouldRun then break end
    end
  end

  if shouldRun then
    StartTicker()
  else
    StopTicker()
  end
end

local function EnsureTracked(spellID, ids)
  if not ns._rangeTracked then ns._rangeTracked = {} end
  local t = ns._rangeTracked[spellID]
  if not t then
    ns._rangeTracked[spellID] = { ids = ids }
  else
    t.ids = ids
  end
end

function ns.Gate_Range(ctx, data)
  if not data or not data.spellID then return true end

  local ids = ResolveBuffIDsForData(data)
  local spellID = data.spellID
  EnsureTracked(spellID, ids)

  local playerHas = UnitHasAnyBuffFromIDs("player", ids)
  if not playerHas then
    StopTicker()
    return true
  end

  local units = GetGroupUnits()
  local anyMissing = false
  local anyMissingInRange = false

  for i = 1, #units do
    local u = units[i]
    if u ~= "player" and not UnitHasAnyBuffFromIDs(u, ids) then
      anyMissing = true
      local inRange = false
      if C_Spell and C_Spell.IsSpellInRange then
        local ret = C_Spell.IsSpellInRange(spellID, u)
        inRange = (ret == true)
      end
      if inRange then
        anyMissingInRange = true
        break
      end
    end
  end

  if anyMissing then
    StartTicker()
  else
    StopTicker()
  end

  if not anyMissing then
    return true
  end

  if not anyMissingInRange then
    ctx.suppress = true
    return false
  end

  return true
end

ns.RegisterGate("range", function(ctx, data)
  return ns.Gate_Range(ctx, data)
end)
