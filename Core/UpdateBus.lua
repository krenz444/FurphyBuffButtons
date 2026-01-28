-- ====================================
-- \Core\UpdateBus.lua
-- ====================================
-- This file manages the central update loop for the addon, coordinating data refreshes and rendering.

local addonName, ns = ...
ns = ns or {}
_G[addonName] = ns

-- Flags to track what needs updating
local _flags = {
  bagsDirty      = false,
  rosterDirty    = false,
  enchantsDirty  = false,
  optionsDirty   = false,
  gatesDirty     = false,
}
local _aurasDirty = {}
local _dirtyBags  = {}

local _updateArmed   = false
local _renderPending = false
local _renderDelay   = 0.05
local _updateDelay   = 0.02

-- Functions to mark specific components as dirty
function ns.MarkBagsDirty(bagID)
  _flags.bagsDirty = true
  if type(bagID) == "number" then _dirtyBags[bagID] = true end
end
function ns.MarkRosterDirty()    _flags.rosterDirty   = true end
function ns.MarkEnchantsDirty()  _flags.enchantsDirty = true end
function ns.MarkOptionsDirty()   _flags.optionsDirty  = true end
function ns.MarkGatesDirty()     _flags.gatesDirty    = true end
function ns.MarkAurasDirty(unit)
  if unit and type(unit)=="string" then _aurasDirty[unit] = true end
end

-- Consumes the list of dirty bags and clears it.
function ns.ConsumeDirtyBags(out)
  if not _flags.bagsDirty then return 0 end
  local n = 0
  for b in pairs(_dirtyBags) do out[b] = true; _dirtyBags[b] = nil; n = n + 1 end
  return n
end

-- Calls the render function immediately.
-- Skipped during combat.
local function _callRenderNow()
  if InCombatLockdown() then return end
  if type(ns._RenderAllInner) == "function" then ns._RenderAllInner(); return end
  if type(ns.RenderAll) == "function" then ns.RenderAll() end
end

-- Schedules a render update.
function ns.PushRender()
  if _renderPending then return end
  _renderPending = true
  C_Timer.After(_renderDelay, function() _renderPending = false; _callRenderNow() end)
end

-- Hook RenderAll to use PushRender
if type(ns.RenderAll) == "function" and type(ns._RenderAllInner) ~= "function" then
  ns._RenderAllInner = ns.RenderAll
  ns.RenderAll = function() return ns.PushRender() end
end

-- Requests a full rebuild of the addon's data.
if type(ns.RequestRebuild) ~= "function" then
  function ns.RequestRebuild() ns.MarkOptionsDirty(); ns.PokeUpdateBus() end
end

-- Recomputes gating conditions (level, rested, instance).
-- Skipped during combat.
local function _recomputeGates()
  if InCombatLockdown() then return end
  if type(getPlayerLevel) == "function" then getPlayerLevel() end
  if type(restedXPGate) == "function" then
    restedXPGate()
  else
    clickableRaidBuffCache = clickableRaidBuffCache or { playerInfo = {} }
    clickableRaidBuffCache.playerInfo.restedXPArea = IsResting()
  end
  if type(instanceGate) == "function" then
    instanceGate()
  else
    clickableRaidBuffCache = clickableRaidBuffCache or { playerInfo = {} }
    local inInst = select(1, IsInInstance())
    clickableRaidBuffCache.playerInfo.inInstance = inInst and true or false
  end
end

-- Checks if consumables should be suppressed.
local function _isConsumablesSuppressed()
  if type(ns.MPlus_DisableConsumablesActive) == "function" and ns.MPlus_DisableConsumablesActive() then
    return true
  end
  local inInst = select(1, IsInInstance())
  if inInst then
    local _, _, diffID = GetInstanceInfo()
    if diffID == 8 then
      local ddb = (ns.GetDB and ns.GetDB()) or _G.ClickableRaidBuffsDB or {}
      if ddb and ddb.mplusDisableConsumables == true then return true end
    end
  end
  return false
end

-- Applies consumable suppression if active.
local function _applyConsumableSuppressionIfActive()
  if not _isConsumablesSuppressed() then return false end
  clickableRaidBuffCache = clickableRaidBuffCache or {}
  clickableRaidBuffCache.displayable = clickableRaidBuffCache.displayable or {}
  local d = clickableRaidBuffCache.displayable
  d.FOOD, d.FLASK, d.MAIN_HAND, d.OFF_HAND = {}, {}, {}, {}
  return true
end

-- The main update function that processes dirty flags.
-- Skipped during combat or encounters.
local function _runOnce()
  if ns and (ns._inCombat or (IsEncounterInProgress and IsEncounterInProgress()) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) or InCombatLockdown()) then
    _updateArmed = false
    return
  end

  _updateArmed = false

  local hadAuras = false
  for _ in pairs(_aurasDirty) do hadAuras = true; break end
  wipe(_aurasDirty)

  local doBags     = _flags.bagsDirty
  local doRoster   = _flags.rosterDirty
  local doEnchants = _flags.enchantsDirty
  local doOptions  = _flags.optionsDirty
  local doGates    = _flags.gatesDirty

  _flags.bagsDirty     = false
  _flags.rosterDirty   = false
  _flags.enchantsDirty = false
  _flags.optionsDirty  = false
  _flags.gatesDirty    = false

  _recomputeGates()

  local suppressed = _isConsumablesSuppressed()

  if not suppressed and doBags and type(_G.scanAllBags) == "function" then
    _G.scanAllBags()
  end

  if (hadAuras or doOptions) and type(ns.ReapplyBagThresholds) == "function" then
    ns.ReapplyBagThresholds()
  end

  if (doRoster or hadAuras or doGates) and type(_G.scanRaidBuffs) == "function" then
    _G.scanRaidBuffs()
  end

  if doOptions and type(ns.UpdateAugmentRunes) == "function" then
    ns.UpdateAugmentRunes()
  end

  if doOptions then
    if type(ns.RebuildDisplayables) == "function" then ns.RebuildDisplayables() end
    if type(ns.RefreshEverything)   == "function" then ns.RefreshEverything()   end
  end

  ns.PushRender()

  if ns.Timer_RecomputeSchedule then
    ns.Timer_RecomputeSchedule()
  end
end

-- Triggers the update loop.
function ns.PokeUpdateBus()
  if _updateArmed then return end
  _updateArmed = true
  C_Timer.After(_updateDelay, _runOnce)
end

-- Ensures RenderAll uses PushRender
do
  if not ns._render_wrapped and type(ns.PushRender) == "function" and type(ns.RenderAll) == "function" then
    local _orig = ns.RenderAll
    ns.RenderAll = function(...)
      return ns.PushRender(...)
    end
    ns._render_wrapped = true
  end
end
