-- ====================================
-- \Core\Events.lua
-- ====================================
-- This file handles event registration and dispatching to various modules.

local addonName, ns = ...
ns = ns or {}

local debounce = 0.03
local f = CreateFrame("Frame")

-- Register events
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_UPDATE_RESTING")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MAXHEALTH")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("BAG_UPDATE_DELAYED")
f:RegisterEvent("BAG_UPDATE_COOLDOWN")
f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
f:RegisterEvent("SPELLS_CHANGED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("WEAPON_ENCHANT_CHANGED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
f:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
f:RegisterEvent("COMPANION_LEARNED")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("CHALLENGE_MODE_START")
f:RegisterEvent("CHALLENGE_MODE_RESET")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ENCOUNTER_START")
f:RegisterEvent("ENCOUNTER_END")
f:RegisterEvent("PET_STABLE_UPDATE")
f:RegisterEvent("UNIT_PET")
f:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
f:RegisterEvent("PLAYER_LOGIN")

-- Helper to trigger an update
local function poke()
  if type(ns.PokeUpdateBus) == "function" then ns.PokeUpdateBus() end
end

-- Helper to refresh cooldowns
local function refreshCooldowns()
  if type(ns.Cooldown_RefreshAll) == "function" then ns.Cooldown_RefreshAll() end
end

-- Checks if an encounter is in progress
local function inEncounter()
  if ns._inEncounter then return true end
  if IsEncounterInProgress and IsEncounterInProgress() then return true end
  return false
end

-- Checks if the player is dead or a ghost
local function isDead()
  if ns._isDead then return true end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return true end
  return false
end

-- Checks if the addon should be locked (no updates) due to combat or other states
local function locked()
  if ns._inCombat then return true end
  if InCombatLockdown and InCombatLockdown() then return true end
  if inEncounter() then return true end
  if isDead() then return true end
  return false
end

-- Runs various update functions after combat or other blocking states end
local function postCatchup()
  if type(ns.MarkGatesDirty)                     == "function" then ns.MarkGatesDirty()                     end
  if type(ns.MarkRosterDirty)                    == "function" then ns.MarkRosterDirty()                    end
  if type(ns.MarkBagsDirty)                      == "function" then ns.MarkBagsDirty()                      end
  if type(ns.MarkAurasDirty)                     == "function" then ns.MarkAurasDirty("player")             end
  if type(ns.RecomputeEatingState)               == "function" then ns.RecomputeEatingState()               end
  if type(ns.UpdateFlaskState)                   == "function" then ns.UpdateFlaskState()                   end
  if type(ns.Cosmetics_OnPlayerAura)             == "function" then ns.Cosmetics_OnPlayerAura("player")     end
  if type(ns.UpdateAugmentRunes)                 == "function" then ns.UpdateAugmentRunes()                 end
  if type(ns.RaidBuffTargeting_OnRosterChanged)  == "function" then ns.RaidBuffTargeting_OnRosterChanged()  end
  if type(ns.CastableWeaponEnchants_Rebuild)     == "function" then ns.CastableWeaponEnchants_Rebuild()     end
  if type(ns.DKWeaponEnchantCheck_Rebuild)       == "function" then ns.DKWeaponEnchantCheck_Rebuild()       end
  if type(ns.Durability_RefreshChosenMount)      == "function" then ns.Durability_RefreshChosenMount()      end
  if type(ns.Durability_Rebuild)                 == "function" then ns.Durability_Rebuild()                 end
  if type(ns.MythicPlus_Recompute)               == "function" then ns.MythicPlus_Recompute()               end
  if type(ns.Recuperate_Recompute)               == "function" then ns.Recuperate_Recompute()               end
  if type(ns.Delves_Recompute)                   == "function" then ns.Delves_Recompute()                   end

  refreshCooldowns()
  poke()
end

local pokeArmed, cdArmed
-- Debounced update trigger
local function armPoke(delay)
  if pokeArmed then return end
  pokeArmed = true
  C_Timer.After(delay or debounce, function()
    pokeArmed = false
    if not locked() then poke() end
  end)
end

-- Debounced cooldown refresh trigger
local function armCooldown(delay)
  if cdArmed then return end
  cdArmed = true
  C_Timer.After(delay or debounce, function()
    cdArmed = false
    if not locked() then refreshCooldowns() end
  end)
end

-- Checks if weapon enchants need updating
local function maybeUpdateWeaponEnchants()
  local fn = _G.updateWeaponEnchants
  if type(fn) == "function" then
    local tc, sc = fn()
    if tc or sc then armPoke(debounce) return true end
  end
  return false
end

local THROTTLE = 1.0

local auraBuf = { units = {}, pendingPlayer = nil, timer = nil, lastRun = 0 }
-- Processes a single UNIT_AURA event
local function process_UNIT_AURA(unit, updateInfo)
  if unit == "player" then
    if type(ns.FoodStatus_OnUnitAura)   == "function" then ns.FoodStatus_OnUnitAura(unit, updateInfo) end
    if type(ns.UpdateFlaskState)        == "function" then ns.UpdateFlaskState() end
    if type(ns.Cosmetics_OnPlayerAura)  == "function" then ns.Cosmetics_OnPlayerAura(unit, updateInfo) end
    if type(ns.AugmentRune_OnPlayerAura)== "function" then
      ns.AugmentRune_OnPlayerAura(unit, updateInfo)
    elseif type(ns.UpdateAugmentRunes) == "function" then
      ns.UpdateAugmentRunes()
    end
    if type(ns.MarkAurasDirty)          == "function" then ns.MarkAurasDirty(unit) end
    if type(ns.FixedTarget_OnUnitAura)  == "function" and ns.FixedTarget_OnUnitAura(unit, updateInfo) then armPoke(0) end
    if type(ns.RoguePoisons_OnUnitAura) == "function" and ns.RoguePoisons_OnUnitAura(unit, updateInfo) then armPoke(0) end
    if type(ns.ShamanShields_OnUnitAura)== "function" and ns.ShamanShields_OnUnitAura(unit, updateInfo) then armPoke(0) end
    if type(ns.Trinkets_OnUnitAura)     == "function" then ns.Trinkets_OnUnitAura(unit, updateInfo) end
    armPoke(0)
  else
    if type(ns.RaidBuffTargeting_OnUnitAura) == "function" then ns.RaidBuffTargeting_OnUnitAura(unit, updateInfo) end
    if type(ns.MarkAurasDirty)               == "function" then ns.MarkAurasDirty(unit) end
    if type(ns.FixedTarget_OnUnitAura)       == "function" and ns.FixedTarget_OnUnitAura(unit, updateInfo) then armPoke(0) end
    if type(ns.ShamanShields_OnUnitAura)     == "function" and ns.ShamanShields_OnUnitAura(unit, updateInfo) then armPoke(0) end
    if type(ns.Trinkets_OnUnitAura)          == "function" then ns.Trinkets_OnUnitAura(unit, updateInfo) end
    armPoke(0)
  end
end

-- Flushes buffered aura events
local function flushAuras()
  auraBuf.timer = nil
  local queuedPlayer = auraBuf.pendingPlayer
  if queuedPlayer then
    process_UNIT_AURA("player", queuedPlayer ~= true and queuedPlayer or nil)
  end
  for u, ui in pairs(auraBuf.units) do
    if type(u) == "string" then
      process_UNIT_AURA(u, ui ~= true and ui or nil)
    end
  end
  auraBuf.pendingPlayer = nil
  wipe(auraBuf.units)
  auraBuf.lastRun = GetTime()
end

-- Buffers UNIT_AURA events to avoid excessive processing
local function on_UNIT_AURA(unit, updateInfo)
  if unit == "player" then
    auraBuf.pendingPlayer = updateInfo or true
  else
    auraBuf.units[unit] = updateInfo or true
  end
  local now = GetTime()
  local dt = now - (auraBuf.lastRun or 0)
  if dt >= THROTTLE then
    flushAuras()
  elseif not auraBuf.timer then
    local delay = THROTTLE - dt
    auraBuf.timer = C_Timer.NewTimer(delay, function()
      if not locked() then flushAuras() else auraBuf.timer = C_Timer.NewTimer(0.05, flushAuras) end
    end)
  end
end

local cleuBuf = { pending = false, timer = nil, lastRun = 0 }
-- Flushes buffered CLEU events (currently unused as CLEU is disabled)
local function flushCLEU()
  cleuBuf.timer = nil
  if cleuBuf.pending then
    cleuBuf.pending = false
    local any = false
    if type(ns.Healthstone_OnCombatLogEventUnfiltered) == "function" then
      if ns.Healthstone_OnCombatLogEventUnfiltered() then any = true end
    end
    if type(ns.Trinkets_OnCombatLogEventUnfiltered) == "function" then
      if ns.Trinkets_OnCombatLogEventUnfiltered() then any = true end
    end
    if any then armPoke(0) end
    cleuBuf.lastRun = GetTime()
  end
end

-- Buffers CLEU events (currently unused)
local function on_CLEU()
  cleuBuf.pending = true
  local dt = GetTime() - (cleuBuf.lastRun or 0)
  if dt >= THROTTLE then
    flushCLEU()
  elseif not cleuBuf.timer then
    cleuBuf.timer = C_Timer.NewTimer(THROTTLE - dt, function()
      if not locked() then flushCLEU() else cleuBuf.timer = C_Timer.NewTimer(0.05, flushCLEU) end
    end)
  end
end

local uscsBuf = { events = {}, timer = nil, lastRun = 0 }
-- Flushes buffered UNIT_SPELLCAST_SUCCEEDED events
local function flushUSCS()
  uscsBuf.timer = nil
  local any = false
  if type(ns.Healthstone_OnUnitSpellcastSucceeded) == "function" then
    for i = 1, #uscsBuf.events do
      local e = uscsBuf.events[i]
      if ns.Healthstone_OnUnitSpellcastSucceeded(e.unit, e.castGUID, e.spellID) then any = true end
    end
  end
  wipe(uscsBuf.events)
  uscsBuf.lastRun = GetTime()
  if any then armPoke(0) end
end

-- Buffers UNIT_SPELLCAST_SUCCEEDED events
local function on_USCS(unit, castGUID, spellID)
  uscsBuf.events[#uscsBuf.events+1] = { unit = unit, castGUID = castGUID, spellID = spellID }
  local dt = GetTime() - (uscsBuf.lastRun or 0)
  if dt >= THROTTLE then
    flushUSCS()
  elseif not uscsBuf.timer then
    uscsBuf.timer = C_Timer.NewTimer(THROTTLE - dt, function()
      if not locked() then flushUSCS() else uscsBuf.timer = C_Timer.NewTimer(0.05, flushUSCS) end
    end)
  end
end

-- Bypasses event throttling (e.g., for immediate updates)
function ns.BypassEventThrottle()
  if auraBuf.timer then auraBuf.timer:Cancel(); auraBuf.timer = nil end
  if cleuBuf.timer then cleuBuf.timer:Cancel(); cleuBuf.timer = nil end
  if uscsBuf.timer then uscsBuf.timer:Cancel(); uscsBuf.timer = nil end
  if not locked() then
    if auraBuf.pendingPlayer or next(auraBuf.units) then flushAuras() end
    if cleuBuf.pending then flushCLEU() end
    if #uscsBuf.events > 0 then flushUSCS() end
  else
    C_Timer.After(0.05, ns.BypassEventThrottle)
  end
end

-- Main event handler
f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    return
  end

  if event == "PLAYER_REGEN_DISABLED" then
    ns._inCombat = true
    if type(ns.Healthstone_OnRegenDisabled) == "function" then if ns.Healthstone_OnRegenDisabled() then armPoke(debounce) end end
    if type(ns.Pets_OnRegenDisabled) == "function" then if ns.Pets_OnRegenDisabled() then armPoke(debounce) end end
    if type(ns.RoguePoisons_OnRegenDisabled) == "function" then if ns.RoguePoisons_OnRegenDisabled() then armPoke(debounce) end end
    return
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns._inCombat = false
    if type(ns.Healthstone_OnRegenEnabled) == "function" then if ns.Healthstone_OnRegenEnabled() then armPoke(debounce) end end
    if type(ns.Pets_OnRegenEnabled) == "function" then if ns.Pets_OnRegenEnabled() then armPoke(debounce) end end
    if type(ns.RoguePoisons_OnRegenEnabled) == "function" then if ns.RoguePoisons_OnRegenEnabled() then armPoke(debounce) end end
    if type(ns.ShamanShields_OnRegenEnabled) == "function" then if ns.ShamanShields_OnRegenEnabled() then armPoke(debounce) end end
    maybeUpdateWeaponEnchants()
    if not inEncounter() and not isDead() then postCatchup() end
    return
  elseif event == "ENCOUNTER_START" then
    ns._inEncounter = true
    return
  elseif event == "ENCOUNTER_END" then
    ns._inEncounter = false
    if type(ns.Healthstone_OnEncounterEnd) == "function" then if ns.Healthstone_OnEncounterEnd() then armPoke(debounce) end end
    if not isDead() then postCatchup() end
    return
  elseif event == "PLAYER_DEAD" then
    ns._isDead = true
    if type(ns.Healthstone_OnPlayerDead) == "function" then if ns.Healthstone_OnPlayerDead() then armPoke(debounce) end end
    if type(ns.RoguePoisons_OnPlayerDead) == "function" then if ns.RoguePoisons_OnPlayerDead() then armPoke(debounce) end end
    C_Timer.After(0.25, function()
      if type(ns.Durability_Rebuild) == "function" then ns.Durability_Rebuild() end
      if type(ns.Durability_RefreshChosenMount) == "function" then ns.Durability_RefreshChosenMount() end
    end)
    return
  elseif event == "PLAYER_UNGHOST" or event == "PLAYER_ALIVE" then
    ns._isDead = false
    if type(ns.Healthstone_OnPlayerUnghost) == "function" and event == "PLAYER_UNGHOST" then
      if ns.Healthstone_OnPlayerUnghost() then armPoke(debounce) end
    end
    if type(ns.RoguePoisons_OnPlayerUnghost) == "function" and event == "PLAYER_UNGHOST" then
      if ns.RoguePoisons_OnPlayerUnghost() then armPoke(debounce) end
    end
    if not inEncounter() and not ns._inCombat then postCatchup() end
    return
  end

  if locked() then return end

  if event == "PLAYER_ENTERING_WORLD" then
    if type(ns.Recuperate_Recompute) == "function" then ns.Recuperate_Recompute() end
    if type(ns.RecomputeEatingState) == "function" then ns.RecomputeEatingState() end
    if type(ns.UpdateFlaskState)     == "function" then ns.UpdateFlaskState()     end
    if type(ns.RaidBuffTargeting_OnPEW) == "function" then ns.RaidBuffTargeting_OnPEW() end
    if type(ns.MythicPlus_Recompute) == "function" then ns.MythicPlus_Recompute() end
    if type(ns.Delves_Recompute)                   == "function" then ns.Delves_Recompute()               end

    if type(ns.Durability_RefreshChosenMount) == "function" then ns.Durability_RefreshChosenMount() end
    if type(ns.Durability_Rebuild)   == "function" then ns.Durability_Rebuild()   end
    if type(ns.CastableWeaponEnchants_Rebuild) == "function" then ns.CastableWeaponEnchants_Rebuild() end
    if type(ns.DKWeaponEnchantCheck_Rebuild)   == "function" then ns.DKWeaponEnchantCheck_Rebuild()   end
    if type(ns.MarkGatesDirty)       == "function" then ns.MarkGatesDirty()       end
    if type(ns.MarkRosterDirty)      == "function" then ns.MarkRosterDirty()      end
    if type(ns.MarkBagsDirty)        == "function" then ns.MarkBagsDirty()        end
    if type(ns.MarkAurasDirty)       == "function" then ns.MarkAurasDirty("player") end
    if type(ns.FixedTarget_Init)     == "function" then
      if ns.FixedTarget_Init() then armPoke(debounce) end
    end
    if type(ns.Healthstone_OnPEW) == "function" then
      if ns.Healthstone_OnPEW() then armPoke(debounce) end
    end
    if type(ns.Pets_OnPEW) == "function" then
      if ns.Pets_OnPEW() then armPoke(debounce) end
    end
    if type(ns.RoguePoisons_OnPEW) == "function" then
      if ns.RoguePoisons_OnPEW() then armPoke(debounce) end
    end
    if type(ns.ShamanShields_OnPEW) == "function" then
      if ns.ShamanShields_OnPEW() then armPoke(debounce) end
    end
    if type(ns.InitRangeGate) == "function" then ns.InitRangeGate() end
    if type(ns.RangeGate_OnRosterOrSpellsChanged) == "function" then ns.RangeGate_OnRosterOrSpellsChanged() end
    if type(ns.Trinkets_Rebuild) == "function" then ns.Trinkets_Rebuild() end
    if type(ns.Trinkets_RebuildWatch) == "function" then ns.Trinkets_RebuildWatch() end
    if not ns._mergedScan then
      local orig = _G.scanRaidBuffs
      if type(orig) == "function" then
        _G.scanRaidBuffs = function(...)
          orig(...)
          if type(ns.Trinkets_Scan) == "function" then ns.Trinkets_Scan() end
        end
        ns._mergedScan = true
      end
    end
    maybeUpdateWeaponEnchants()
    refreshCooldowns()
    poke()
    return
  end

  if event == "PLAYER_LEVEL_UP" or event == "PLAYER_UPDATE_RESTING" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_DIFFICULTY_CHANGED" or event == "PLAYER_ENTERING_BATTLEGROUND" then
    if type(ns.Recuperate_Recompute) == "function" then ns.Recuperate_Recompute() end
    if type(ns.MarkGatesDirty) == "function" then ns.MarkGatesDirty() end
    if type(ns.MythicPlus_Recompute) == "function" then ns.MythicPlus_Recompute() end
    if type(ns.Delves_Recompute)                   == "function" then ns.Delves_Recompute()               end
    if event == "PLAYER_UPDATE_RESTING" then
      if type(ns.Healthstone_OnPlayerUpdateResting) == "function" then
        if ns.Healthstone_OnPlayerUpdateResting() then armPoke(debounce) end
      end
      if type(ns.ShamanShields_OnPlayerUpdateResting) == "function" then
        if ns.ShamanShields_OnPlayerUpdateResting() then armPoke(debounce) end
      end
    end
    if (event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_DIFFICULTY_CHANGED" or event == "PLAYER_ENTERING_BATTLEGROUND") and type(ns.Healthstone_OnZoneChanged) == "function" then
      if ns.Healthstone_OnZoneChanged() then armPoke(debounce) end
    end
    if type(ns.Trinkets_Rebuild) == "function" then ns.Trinkets_Rebuild() end
    armPoke(debounce)
    return
  end

  if event == "GROUP_ROSTER_UPDATE" then
    if type(ns.RaidBuffTargeting_OnRosterChanged) == "function" then ns.RaidBuffTargeting_OnRosterChanged() end
    if type(ns.MarkRosterDirty) == "function" then ns.MarkRosterDirty() end
    if type(ns.FixedTarget_OnRosterChanged) == "function" then
      if ns.FixedTarget_OnRosterChanged() then armPoke(debounce) end
    end
    if type(ns.Healthstone_OnGroupRosterUpdate) == "function" then
      if ns.Healthstone_OnGroupRosterUpdate() then armPoke(debounce) end
    end
    if type(ns.ShamanShields_OnGroupRosterUpdate) == "function" then
      if ns.ShamanShields_OnGroupRosterUpdate() then armPoke(debounce) end
    end
    if type(ns.Trinkets_OnGroupRosterUpdate) == "function" then
      if ns.Trinkets_OnGroupRosterUpdate() then armPoke(debounce) end
    end
    if type(ns.RangeGate_OnRosterOrSpellsChanged) == "function" then ns.RangeGate_OnRosterOrSpellsChanged() end
    if type(ns.Trinkets_Rebuild) == "function" then ns.Trinkets_Rebuild() end
    if type(ns.Trinkets_RebuildWatch) == "function" then ns.Trinkets_RebuildWatch() end
    armPoke(debounce)
    return
  end

  if event == "UNIT_AURA" then
    on_UNIT_AURA(...)
    return
  end

  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
    local unit = ...
    if unit == "player" then
      if ns._inCombat or (InCombatLockdown and InCombatLockdown()) then return end
      if type(ns.Recuperate_Recompute) == "function" then ns.Recuperate_Recompute() end
      armPoke(debounce)
    end
    return
  end

  if event == "UNIT_INVENTORY_CHANGED" then
    local unit = ...
    if unit == "player" then
      if type(ns.MarkEnchantsDirty) == "function" then ns.MarkEnchantsDirty() end
      if type(ns.MarkBagsDirty)     == "function" then ns.MarkBagsDirty()     end
      if type(ns.CastableWeaponEnchants_Rebuild) == "function" then ns.CastableWeaponEnchants_Rebuild() end
      if type(ns.DKWeaponEnchantCheck_Rebuild)   == "function" then ns.DKWeaponEnchantCheck_Rebuild()   end
      if type(ns.Durability_Rebuild)             == "function" then ns.Durability_Rebuild()             end
      if type(ns.Trinkets_Rebuild) == "function" then ns.Trinkets_Rebuild() end
      maybeUpdateWeaponEnchants()
      armPoke(debounce)
    end
    return
  end

  if event == "PLAYER_EQUIPMENT_CHANGED" then
    if type(ns.MarkEnchantsDirty) == "function" then ns.MarkEnchantsDirty() end
    if type(ns.CastableWeaponEnchants_Rebuild) == "function" then ns.CastableWeaponEnchants_Rebuild() end
    if type(ns.DKWeaponEnchantCheck_Rebuild)   == "function" then ns.DKWeaponEnchantCheck_Rebuild()   end
    if type(ns.Durability_Rebuild)             == "function" then ns.Durability_Rebuild()             end
    if type(ns.Trinkets_Rebuild) == "function" then ns.Trinkets_Rebuild() end
    maybeUpdateWeaponEnchants()
    armPoke(debounce)
    return
  end

  if event == "WEAPON_ENCHANT_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "SPELLS_CHANGED" then
    if type(ns.CastableWeaponEnchants_Rebuild) == "function" then ns.CastableWeaponEnchants_Rebuild() end
    if type(ns.DKWeaponEnchantCheck_Rebuild)   == "function" then ns.DKWeaponEnchantCheck_Rebuild()   end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
      if type(ns.RoguePoisons_OnSpecializationChanged) == "function" then
        if ns.RoguePoisons_OnSpecializationChanged() then armPoke(debounce) end
      end
    end
    if event == "WEAPON_ENCHANT_CHANGED" then
      maybeUpdateWeaponEnchants()
    end
    if event == "SPELLS_CHANGED" then
      if type(ns.Healthstone_OnSpellsChanged) == "function" then
        if ns.Healthstone_OnSpellsChanged() then armPoke(debounce) end
      end
      if type(ns.Pets_OnSpellsChanged) == "function" then
        if ns.Pets_OnSpellsChanged() then armPoke(debounce) end
      end
      if type(ns.RoguePoisons_OnSpellsChanged) == "function" then
        if ns.RoguePoisons_OnSpellsChanged() then armPoke(debounce) end
      end
      if type(ns.ShamanShields_OnSpellsChanged) == "function" then
        if ns.ShamanShields_OnSpellsChanged() then armPoke(debounce) end
      end
      if type(ns.RangeGate_OnRosterOrSpellsChanged) == "function" then ns.RangeGate_OnRosterOrSpellsChanged() end
      maybeUpdateWeaponEnchants()
    end
    armPoke(debounce)
    return
  end

  if event == "UPDATE_INVENTORY_DURABILITY" then
    if type(ns.Durability_Rebuild) == "function" then ns.Durability_Rebuild() end
    armPoke(debounce)
    return
  end

  if event == "MOUNT_JOURNAL_USABILITY_CHANGED" or event == "COMPANION_LEARNED" then
    if type(ns.Durability_RefreshChosenMount) == "function" then ns.Durability_RefreshChosenMount() end
    return
  end

  if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    if type(ns.Pets_OnMountDisplayChanged) == "function" then
      if ns.Pets_OnMountDisplayChanged() then armPoke(debounce) end
    end
    return
  end

  if event == "PET_STABLE_UPDATE" then
    if type(ns.Pets_OnPetStableUpdate) == "function" then
      if ns.Pets_OnPetStableUpdate() then armPoke(debounce) end
    end
    return
  end

  if event == "UNIT_PET" then
    if type(ns.Pets_OnUnitPet) == "function" then
      if ns.Pets_OnUnitPet(...) then armPoke(debounce) end
    end
    return
  end

  if event == "BAG_UPDATE" then
    if type(ns.MarkBagsDirty) == "function" then ns.MarkBagsDirty(...) end
    if type(ns.Healthstone_OnBagUpdate) == "function" then if ns.Healthstone_OnBagUpdate() then armPoke(debounce) end end
    return
  elseif event == "BAG_UPDATE_DELAYED" then
    if type(ns.UpdateAugmentRunes) == "function" then ns.UpdateAugmentRunes() end
    if type(ns.Healthstone_OnBagUpdateDelayed) == "function" then if ns.Healthstone_OnBagUpdateDelayed() then armPoke(debounce) end end
    armPoke(debounce)
    return
  end

  if event == "BAG_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
    if event == "SPELL_UPDATE_COOLDOWN" and type(ns.Pets_OnSpellUpdateCooldown) == "function" then
      if ns.Pets_OnSpellUpdateCooldown() then armPoke(debounce) end
    end
    armCooldown(debounce)
    return
  end

  if event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_RESET" or event == "CHALLENGE_MODE_COMPLETED" then
    if type(ns.MythicPlus_Recompute) == "function" then ns.MythicPlus_Recompute() end
    return
  end

  if event == "CHALLENGE_MODE_MAPS_UPDATE" then
    if type(ns.MythicPlus_OnMapsUpdate) == "function" then ns.MythicPlus_OnMapsUpdate() end
    return
  end

  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    on_CLEU()
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, castGUID, spellID = ...
    on_USCS(unit, castGUID, spellID)
    return
  end
end)
